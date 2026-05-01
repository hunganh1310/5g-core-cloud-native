#!/usr/bin/env bash

set -euo pipefail

NAMESPACE="${NAMESPACE:-lab4}"
MULTUS_MANIFEST_URL="${MULTUS_MANIFEST_URL:-https://raw.githubusercontent.com/k8snetworkplumbingwg/multus-cni/master/deployments/multus-daemonset-thick.yml}"
NAD_MANIFEST="${NAD_MANIFEST:-k8s/multus/network-attachment-definition.yaml}"

log() {
  printf '[multus] %s\n' "$1"
}

log "Ensuring namespace ${NAMESPACE} exists"
kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"

log "Installing Multus from ${MULTUS_MANIFEST_URL}"
kubectl apply -f "${MULTUS_MANIFEST_URL}"

log "Waiting for Multus DaemonSet to become ready"
kubectl rollout status daemonset/kube-multus-ds -n kube-system --timeout=180s

log "Applying NetworkAttachmentDefinition from ${NAD_MANIFEST}"
kubectl apply -f "${NAD_MANIFEST}"

log "Multus installation complete"
kubectl get pods -n kube-system -l app=multus -o wide || true
