#!/usr/bin/env bash

set -euo pipefail

ROOT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
NAMESPACE="${NAMESPACE:-lab4}"
RELEASE_NAME="${RELEASE_NAME:-dummy-upf}"
CHART_DIR="${CHART_DIR:-${ROOT_DIR}/charts/dummy-upf-chart}"
IMAGE_NAME="${IMAGE_NAME:-dummy-upf}"
INITIAL_TAG="${INITIAL_TAG:-0.1.0}"
UPGRADE_TAG="${UPGRADE_TAG:-0.2.0}"

log() {
  printf '[deploy] %s\n' "$1"
}

ensure_namespace() {
  kubectl get namespace "${NAMESPACE}" >/dev/null 2>&1 || kubectl create namespace "${NAMESPACE}"
}

build_image() {
  local tag="$1"
  log "Building Docker image ${IMAGE_NAME}:${tag}"
  docker build -f "${ROOT_DIR}/app/Dockerfile" -t "${IMAGE_NAME}:${tag}" "${ROOT_DIR}/app"
}

import_image() {
  local tag="$1"
  log "Importing ${IMAGE_NAME}:${tag} into k3d cluster"
  k3d image import "${IMAGE_NAME}:${tag}" -c "${CLUSTER_NAME:-lab4-5g-core}"
}

helm_install_or_upgrade() {
  local tag="$1"
  helm upgrade --install "${RELEASE_NAME}" "${CHART_DIR}" \
    --namespace "${NAMESPACE}" \
    --create-namespace \
    --set image.repository="${IMAGE_NAME}" \
    --set image.tag="${tag}" \
    --set multus.networks[0]="${MULTUS_NETWORK:-lab4-dataplane}"
}

wait_for_rollout() {
  kubectl rollout status deployment/"${RELEASE_NAME}" -n "${NAMESPACE}" --timeout=180s
}

main() {
  ensure_namespace

  build_image "${INITIAL_TAG}"
  import_image "${INITIAL_TAG}"
  log "Installing release ${RELEASE_NAME} with image tag ${INITIAL_TAG}"
  helm_install_or_upgrade "${INITIAL_TAG}"
  wait_for_rollout
  helm history "${RELEASE_NAME}" -n "${NAMESPACE}"

  build_image "${UPGRADE_TAG}"
  import_image "${UPGRADE_TAG}"
  log "Upgrading release ${RELEASE_NAME} to image tag ${UPGRADE_TAG}"
  helm_install_or_upgrade "${UPGRADE_TAG}"
  wait_for_rollout
  helm history "${RELEASE_NAME}" -n "${NAMESPACE}"

  log "Rolling back release ${RELEASE_NAME} to revision 1"
  helm rollback "${RELEASE_NAME}" 1 -n "${NAMESPACE}"
  wait_for_rollout
  helm history "${RELEASE_NAME}" -n "${NAMESPACE}"
}

main "$@"
