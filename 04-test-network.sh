#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-lab4}"
RELEASE_NAME="${RELEASE_NAME:-dummy-upf}"
MIN_REPLICAS="${MIN_REPLICAS:-2}"

log() {
  printf '[test-network] %s\n' "$1"
}

extract_secondary_attachment() {
  local pod_name="$1"
  kubectl get pod "${pod_name}" -n "${NAMESPACE}" -o jsonpath='{.metadata.annotations.k8s\.v1\.cni\.cncf\.io/network-status}' |
    python3 -c 'import json, sys
status = json.loads(sys.stdin.read())
for entry in status:
    interface = entry.get("interface")
    ips = entry.get("ips") or []
    if interface and interface != "eth0" and ips:
        print(f"{interface}|{ips[0]}")
        raise SystemExit(0)
raise SystemExit(1)'
}

main() {
  log "Ensuring deployment ${RELEASE_NAME} has at least ${MIN_REPLICAS} replicas"
  kubectl scale deployment/"${RELEASE_NAME}" -n "${NAMESPACE}" --replicas="${MIN_REPLICAS}" >/dev/null
  kubectl rollout status deployment/"${RELEASE_NAME}" -n "${NAMESPACE}" --timeout=180s

  mapfile -t pods < <(kubectl get pods -n "${NAMESPACE}" -l app.kubernetes.io/name=dummy-upf -o jsonpath='{range .items[*]}{.metadata.name}{"\n"}{end}' | sort)

  if ((${#pods[@]} < 2)); then
    log "Need at least two running pods, found ${#pods[@]}"
    exit 1
  fi

  source_pod="${pods[0]}"
  target_pod="${pods[1]}"

  read -r source_iface source_ip < <(extract_secondary_attachment "${source_pod}" | tr '|' ' ')
  read -r target_iface target_ip < <(extract_secondary_attachment "${target_pod}" | tr '|' ' ')

  log "Source pod ${source_pod}: ${source_iface} ${source_ip}"
  log "Target pod ${target_pod}: ${target_iface} ${target_ip}"

  log "Pinging ${target_ip} from ${source_pod} via ${source_iface}"
  kubectl exec -n "${NAMESPACE}" "${source_pod}" -- ping -c 3 -I "${source_iface}" "${target_ip}"

  log "Multus data-plane verification passed"
}

main "$@"
