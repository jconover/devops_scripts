#!/usr/bin/env bash
# setup-dev-tools-ubuntu2504.sh
# Installs: kubectl, eksctl, Terraform, Ansible, Helm, Azure CLI, gcloud, AWS CLI v2
# Target: Ubuntu 25.04 (idempotent; includes fallbacks)
set -euo pipefail

log()  { printf "\n\033[1;36m[INFO]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*"; }
need() { command -v "$1" >/dev/null 2>&1; }

ARCH="$(dpkg --print-architecture)" # amd64 | arm64
BIN_DIR="/usr/local/bin"

ensure_base() {
  log "Updating apt & installing base packages"
  export DEBIAN_FRONTEND=noninteractive
  apt-get update -y
  apt-get install -y --no-install-recommends \
    ca-certificates curl wget unzip tar jq gnupg git \
    apt-transport-https lsb-release software-properties-common
  ok "Base packages ready"
}

# ---------------- kubectl (Kubernetes CLI) ----------------
# Uses the new pkgs.k8s.io repo (stable v1.30 line).
install_kubectl() {
  if need kubectl; then ok "kubectl already installed: $(kubectl version --client --short 2>/dev/null || true)"; return; fi
  log "Installing kubectl from pkgs.k8s.io (stable v1.30)"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://pkgs.k8s.io/core:/stable:/v1.30/deb/Release.key \
    | gpg --dearmor -o /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  chmod 0644 /etc/apt/keyrings/kubernetes-apt-keyring.gpg
  echo "deb [signed-by=/etc/apt/keyrings/kubernetes-apt-keyring.gpg] https://pkgs.k8s.io/core:/stable:/v1.30/deb/ /" \
    > /etc/apt/sources.list.d/kubernetes.list
  apt-get update -y
  apt-get install -y kubectl
  ok "kubectl $(kubectl version --client --short)"
}

# ---------------- eksctl (EKS CLI) ----------------
install_eksctl() {
  if need eksctl; then ok "eksctl already installed: $(eksctl version 2>/dev/null || true)"; return; fi
  log "Installing eksctl"
  case "$ARCH" in
    amd64) EARCH="amd64" ;;
    arm64) EARCH="arm64" ;;
    *)     err "Unsupported arch for eksctl: $ARCH"; return 1 ;;
  esac
  TMP="$(mktemp -d)"
  curl -fsSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_Linux_${EARCH}.tar.gz" \
    | tar -xz -C "$TMP"
  mv "$TMP/eksctl" "$BIN_DIR/eksctl"
  chmod +x "$BIN_DIR/eksctl"
  rm -rf "$TMP"
  ok "eksctl $(eksctl version)"
}

# ---------------- Terraform (APT with binary fallback) ----------------
add_hashicorp_repo() {
  log "Adding HashiCorp apt repo (may not yet recognize this Ubuntu codename; fallback is handled)"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://apt.releases.hashicorp.com/gpg | gpg --dearmor -o /etc/apt/keyrings/hashicorp.gpg
  chmod 0644 /etc/apt/keyrings/hashicorp.gpg
  CODENAME="$(lsb_release -cs || echo noble)"
  echo "deb [signed-by=/etc/apt/keyrings/hashicorp.gpg] https://apt.releases.hashicorp.com $(echo "$CODENAME") main" \
    > /etc/apt/sources.list.d/hashicorp.list
  apt-get update -y || true
}

install_terraform() {
  if need terraform; then ok "Terraform already installed: $(terraform -version | head -n1)"; return; fi
  add_hashicorp_repo || true
  if apt-get install -y terraform; then
    ok "Terraform $(terraform -version | head -n1)"
    return
  fi
  warn "APT install failed — falling back to official binary"
  case "$ARCH" in
    amd64) TARCH="amd64" ;;
    arm64) TARCH="arm64" ;;
    *)     err "Unsupported arch for Terraform: $ARCH"; return 1 ;;
  esac
  VER="$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r .current_version)"
  curl -fsSL "https://releases.hashicorp.com/terraform/${VER}/terraform_${VER}_linux_${TARCH}.zip" -o /tmp/terraform.zip
  unzip -o /tmp/terraform.zip -d /tmp
  mv /tmp/terraform "$BIN_DIR/terraform"
  chmod +x "$BIN_DIR/terraform"
  rm -f /tmp/terraform.zip
  ok "Terraform $(terraform -version | head -n1)"
}

# ---------------- Ansible ----------------
install_ansible() {
  if need ansible; then ok "Ansible already installed: $(ansible --version | head -n1)"; return; fi
  log "Installing Ansible (Ubuntu repo)"
  apt-get install -y ansible
  ok "Ansible $(ansible --version | head -n1)"
}

# ---------------- Helm ----------------
install_helm() {
  if need helm; then ok "Helm already installed: $(helm version --short 2>/dev/null || true)"; return; fi
  log "Installing Helm"
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  ok "Helm $(helm version --short)"
}

# ---------------- Azure CLI ----------------
install_azure_cli() {
  if need az; then ok "Azure CLI already installed"; return; fi
  log "Installing Azure CLI"
  install -m 0755 -d /etc/apt/keyrings
  curl -fsSL https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor -o /etc/apt/keyrings/microsoft.gpg
  chmod 0644 /etc/apt/keyrings/microsoft.gpg
  echo "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/microsoft.gpg] https://packages.microsoft.com/repos/azure-cli/ stable main" \
    > /etc/apt/sources.list.d/azure-cli.list
  apt-get update -y
  apt-get install -y azure-cli
  ok "Azure CLI installed"
}

# ---------------- Google Cloud SDK ----------------
install_gcloud() {
  if need gcloud; then ok "gcloud already installed: $(gcloud version | head -n1)"; return; fi
  log "Installing Google Cloud SDK"
  install -m 0755 -d /usr/share/keyrings
  curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg
  echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
    > /etc/apt/sources.list.d/google-cloud-sdk.list
  apt-get update -y
  apt-get install -y google-cloud-sdk
  ok "gcloud $(gcloud version | head -n1)"
}

# ---------------- AWS CLI v2 ----------------
install_awscli() {
  if need aws; then ok "AWS CLI already installed: $(aws --version 2>&1)"; return; fi
  log "Installing AWS CLI v2"
  TMP="$(mktemp -d)"
  case "$ARCH" in
    amd64) URL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" ;;
    arm64) URL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" ;;
    *)     err "Unsupported arch for AWS CLI: $ARCH"; return 1 ;;
  esac
  curl -fsSL "$URL" -o "$TMP/awscliv2.zip"
  unzip -q "$TMP/awscliv2.zip" -d "$TMP"
  "$TMP/aws/install" || "$TMP/aws/install" --update
  rm -rf "$TMP"
  ok "AWS CLI $(aws --version 2>&1)"
}

main() {
  if [ "$(id -u)" -ne 0 ]; then
    err "Please run as root (use: sudo $0)"; exit 1
  fi

  ensure_base

  install_kubectl
  install_eksctl
  install_terraform
  install_ansible
  install_helm
  install_azure_cli
  install_gcloud
  install_awscli

  log "All done ✅"
  echo
  echo "Verify versions:"
  echo "  kubectl  -> $(command -v kubectl || echo 'not found')"
  echo "  eksctl   -> $(command -v eksctl || echo 'not found')"
  echo "  terraform-> $(command -v terraform || echo 'not found')"
  echo "  ansible  -> $(command -v ansible || echo 'not found')"
  echo "  helm     -> $(command -v helm || echo 'not found')"
  echo "  az       -> $(command -v az || echo 'not found')"
  echo "  gcloud   -> $(command -v gcloud || echo 'not found')"
  echo "  aws      -> $(command -v aws || echo 'not found')"
}

main "$@"
