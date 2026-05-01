5G Core Cloud-Native Infrastructure

![lab-badge](https://img.shields.io/badge/lab-5G%20Core-blue) ![python-badge](https://img.shields.io/badge/python-3.12-blue?logo=python) ![wsl2-badge](https://img.shields.io/badge/WSL2-required-4A86E8) ![docker-badge](https://img.shields.io/badge/docker-required-2496ED?logo=docker) ![k3d-badge](https://img.shields.io/badge/k3d-recommended-2b90d9)

Lightweight lab demonstrating dual-network Kubernetes pods (control-plane + data-plane) using k3d, Multus CNI, and a dummy UPF-style workload.

## Quick Overview

- Control plane: default Kubernetes pod network (`eth0`) for management and API access.
- Data plane: Multus-attached secondary interface (e.g. `net1`) to simulate user-plane traffic.
- App: exposes an HTTP endpoint that enumerates interfaces from inside the container for verification.

## Repo Layout

See the important top-level items:

- `00-init-env.sh` — install toolchain (kubectl, helm, k3d)
- `01-setup-cluster.sh` — create a k3d cluster
- `02-setup-multus.sh` — install Multus and apply the NetworkAttachmentDefinition
- `03-deploy-app.sh` — build image and deploy Helm chart
- `04-test-network.sh` — validate data-plane connectivity between pods
- `app/` — application sources, `Dockerfile`, and dependencies
- `charts/dummy-upf-chart/` — Helm chart used to deploy the app
- `k8s/multus/network-attachment-definition.yaml` — Multus bridge configuration

## Requirements

- Windows with WSL2 (Ubuntu 22.04 recommended)
- Docker Desktop with WSL2 integration enabled (must be running)
- `bash`, `kubectl`, `helm`, `k3d`

> Important: Ensure your WSL distro is running as WSL2 and Docker Desktop has enabled integration for it. Run these in an elevated PowerShell on Windows if you need to convert a distro:

```powershell
wsl --list --verbose
wsl --set-default-version 2
wsl --set-version <YourDistroName> 2
```

## Quick Start

1. Initialize host tools:

```bash
bash ./00-init-env.sh
```

2. Create the cluster:

```bash
bash ./01-setup-cluster.sh
```

3. Install Multus and data-plane network:

```bash
bash ./02-setup-multus.sh
```

4. Build and deploy the app (Helm):

```bash
bash ./03-deploy-app.sh
```

5. Verify data-plane connectivity between pods:

```bash
bash ./04-test-network.sh
```

## Application Endpoints

- `GET /interfaces` — JSON list of interfaces, addresses, hostname and timestamp
- `GET /healthz` — simple health check (`ok`)

Example local test (port-forward the service):

```bash
kubectl port-forward -n lab4 svc/dummy-upf 8080:8080 &
curl http://localhost:8080/interfaces | jq .
curl http://localhost:8080/healthz
```

## Multus Network (k8s/multus/network-attachment-definition.yaml)

- Bridge-based network `lab4-dataplane` (example subnet `172.30.10.0/24`) — pods annotated with `k8s.v1.cni.cncf.io/networks: lab4-dataplane` will receive a secondary interface.

## Notes & Troubleshooting

- If `bash ./01-setup-cluster.sh` prints `docker is installed but not reachable`, ensure Docker Desktop is running and WSL integration is enabled for your distro.
- If pods do not show the secondary interface, check `kubectl get network-attachment-definitions -A` and `kubectl describe pod <pod>` for `network-status` annotations.

## Development & Local Testing (without k3d)

You can run the Python app locally for quick checks (requires Python 3 and `pip`):

```bash
python3 -m venv .venv
source .venv/bin/activate
pip install -r app/requirements.txt
python app/main.py
# then visit http://localhost:8080/interfaces
```

## License & Contributing

This lab is for educational purposes. Contributions and improvements are welcome — open a PR with concise changes.

---

Enjoy testing the dual-network pod pattern. If you'd like, I can also add a README badge for build status or CI once you have a pipeline set up.


This script scales the deployment to at least two replicas, extracts the secondary interface IPs from pod annotations, and pings one pod from the other across the Multus-attached interface.

## Application Access

The application exposes:

- `GET /healthz` for readiness and liveness checks
- `GET /` and `GET /interfaces` for the interface inventory

Example:

```bash
kubectl port-forward -n lab4 svc/dummy-upf 8080:80
curl http://127.0.0.1:8080/interfaces
```

## Manual Debugging

Use these commands when you want to inspect the pod directly and confirm the Multus attachment by hand.

```bash
kubectl get pods -n lab4 -o wide
kubectl exec -n lab4 deploy/dummy-upf -- sh
ip a
ip route
```

To inspect a specific pod and the secondary interface:

```bash
POD_1=$(kubectl get pod -n lab4 -l app.kubernetes.io/name=dummy-upf -o jsonpath='{.items[0].metadata.name}')
POD_2=$(kubectl get pod -n lab4 -l app.kubernetes.io/name=dummy-upf -o jsonpath='{.items[1].metadata.name}')

kubectl exec -n lab4 "$POD_1" -- sh
kubectl exec -n lab4 "$POD_1" -- ip a
kubectl exec -n lab4 "$POD_1" -- ip route
```

To manually ping the other pod over the data-plane interface, use the interface name reported by Multus, typically `net1`:

```bash
TARGET_IP=$(kubectl get pod -n lab4 "$POD_2" -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status}' | python3 -c 'import json, sys
status = json.loads(sys.stdin.read())
for entry in status:
    if entry.get("interface") and entry.get("interface") != "eth0" and entry.get("ips"):
        print(entry["ips"][0])
        break')

kubectl exec -n lab4 "$POD_1" -- ping -c 3 -I net1 "$TARGET_IP"
```

## Notes on Multus in Telco Deployments

Multus is a common fit for telco workloads because it allows:

- a clean split between operational access and user-plane traffic
- attachment of multiple L2/L3 domains to the same workload
- a more realistic UPF-style pod model without sacrificing Kubernetes scheduling and lifecycle management

In a production telco environment, the data-plane network would usually be backed by dedicated NICs, SR-IOV, macvlan, or other high-performance attachment methods. This lab uses a bridge-based NAD so it works cleanly in a local k3d environment.

## Cleanup

```bash
helm uninstall dummy-upf -n lab4
kubectl delete -f k8s/multus/network-attachment-definition.yaml
k3d cluster delete lab4-5g-core
```
