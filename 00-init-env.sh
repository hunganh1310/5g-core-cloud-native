#!/usr/bin/env bash

set -euo pipefail

log() {
  printf '[init-env] %s\n' "$1"
}

require_cmd() {
  command -v "$1" >/dev/null 2>&1
}

SUDO=""
if [[ ${EUID:-$(id -u)} -ne 0 ]]; then
  SUDO=sudo
fi

install_git_and_curl() {
  if require_cmd git && require_cmd curl; then
    log "git and curl are already installed"
    return
  fi

  log "Installing git and curl via apt"
  $SUDO apt-get update
  $SUDO apt-get install -y ca-certificates git curl
}

install_kubectl() {
  if require_cmd kubectl; then
    log "kubectl is already installed"
    return
  fi

  local kubectl_version
  kubectl_version="${KUBECTL_VERSION:-$(curl -fsSL https://dl.k8s.io/release/stable.txt)}"

  log "Installing kubectl ${kubectl_version}"
  curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${kubectl_version}/bin/linux/amd64/kubectl"
  $SUDO install -m 0755 /tmp/kubectl /usr/local/bin/kubectl
  rm -f /tmp/kubectl
}

install_helm() {
  if require_cmd helm; then
    log "helm is already installed"
    return
  fi

  log "Installing helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
}

install_k3d() {
  if require_cmd k3d; then
    log "k3d is already installed"
    return
  fi

  log "Installing k3d"
  curl -fsSL https://raw.githubusercontent.com/k3d-io/k3d/main/install.sh | TAG="${K3D_VERSION:-v5.8.3}" bash
}

verify_tools() {
  local tools=(git curl kubectl helm k3d docker)
  local missing=()

  for tool in "${tools[@]}"; do
    if ! require_cmd "$tool"; then
      missing+=("$tool")
      continue
    fi
    printf '%s: %s\n' "$tool" "$($tool --version 2>/dev/null | head -n 1 || true)"
  done

  if ((${#missing[@]} > 0)); then
    printf 'Missing tools: %s\n' "${missing[*]}" >&2
    exit 1
  fi

  docker info >/dev/null 2>&1 || { log "docker is installed but not reachable; ensure Docker Desktop WSL integration is running"; exit 1; }
  log "Environment initialization checks passed"
}

main() {
  install_git_and_curl
  install_kubectl
  install_helm
  install_k3d
  verify_tools
}

main "$@"
