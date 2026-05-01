#!/usr/bin/env bash

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-lab4-5g-core}"

log() {
  printf '[cluster] %s\n' "$1"
}

if ! command -v docker >/dev/null 2>&1; then
  log "docker is required but was not found"
  exit 1
fi

if ! docker info >/dev/null 2>&1; then
  log "docker is installed but not reachable; start Docker Desktop with WSL integration"
  exit 1
fi

if k3d cluster list 2>/dev/null | awk 'NR>1 {print $1}' | grep -qx "${CLUSTER_NAME}"; then
  log "Cluster ${CLUSTER_NAME} already exists"
else
  log "Creating k3d cluster ${CLUSTER_NAME} with one server and one agent"
  k3d cluster create "${CLUSTER_NAME}" \
    --servers 1 \
    --agents 1 \
    --wait \
    --timeout 180s \
    --k3s-arg '--disable=traefik@server:0'
fi

log "Cluster nodes"
kubectl get nodes -o wide

log "Cluster info"
kubectl cluster-info
