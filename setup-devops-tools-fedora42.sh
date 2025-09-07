#!/usr/bin/env bash
# setup-devops-tools.sh
# Installs: kubectl, eksctl, Terraform, Ansible, Helm, Azure CLI, gcloud, AWS CLI v2
# Target: Fedora 42
set -euo pipefail

# ---------- Helpers ----------
log()  { printf "\n\033[1;36m[INFO]\033[0m %s\n" "$*"; }
ok()   { printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
warn() { printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err()  { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*"; }

ARCH="$(uname -m)"              # x86_64 or aarch64
OS="$(uname -s)"                # Linux
BIN_DIR="/usr/local/bin"

need_cmd() {
  command -v "$1" >/dev/null 2>&1
}

ensure_base_tools() {
  log "Updating system & installing base packages"
  sudo dnf update -y || true
  sudo dnf install -y curl wget unzip tar git jq xz gzip ca-certificates python3 python3-pip which findutils coreutils || true
  ok "Base packages ready"
}

# ---------- kubectl ----------
install_kubectl() {
  if need_cmd kubectl; then ok "kubectl already installed: $(kubectl version --client --short 2>/dev/null || echo)"; return; fi

  log "Installing kubectl"
  STABLE="$(curl -fsSL https://dl.k8s.io/release/stable.txt)"
  case "$ARCH" in
    x86_64)   KARCH="amd64" ;;
    aarch64)  KARCH="arm64" ;;
    *)        err "Unsupported arch for kubectl: $ARCH"; return 1 ;;
  esac

  curl -fsSLo /tmp/kubectl "https://dl.k8s.io/release/${STABLE}/bin/linux/${KARCH}/kubectl"
  chmod +x /tmp/kubectl
  sudo mv /tmp/kubectl "${BIN_DIR}/kubectl"
  ok "kubectl $(kubectl version --client --short)"
}

# ---------- eksctl ----------
install_eksctl() {
  if need_cmd eksctl; then ok "eksctl already installed: $(eksctl version 2>/dev/null || echo)"; return; fi

  log "Installing eksctl"
  case "$ARCH" in
    x86_64)  EARCH="amd64" ;;
    aarch64) EARCH="arm64" ;;
    *)       err "Unsupported arch for eksctl: $ARCH"; return 1 ;;
  esac

  TMPDIR="$(mktemp -d)"
  curl -fsSL "https://github.com/eksctl-io/eksctl/releases/latest/download/eksctl_${OS}_${EARCH}.tar.gz" \
    | tar xz -C "$TMPDIR"
  sudo mv "$TMPDIR/eksctl" "${BIN_DIR}/eksctl"
  rm -rf "$TMPDIR"
  ok "eksctl $(eksctl version)"
}

# ---------- Terraform (repo + fallback) ----------
add_hashicorp_repo() {
  log "Adding HashiCorp repo (Fedora 42)"
  sudo tee /etc/yum.repos.d/hashicorp.repo >/dev/null <<EOF
[hashicorp]
name=HashiCorp Stable - Fedora 42
baseurl=https://rpm.releases.hashicorp.com/fedora/42/x86_64/stable
enabled=1
gpgcheck=1
gpgkey=https://rpm.releases.hashicorp.com/gpg
EOF
  sudo dnf clean all
  sudo dnf makecache || true
}

install_terraform() {
  if need_cmd terraform; then ok "Terraform already installed: $(terraform -version | head -n1)"; return; fi

  log "Installing Terraform via DNF"
  add_hashicorp_repo || true
  if sudo dnf install -y terraform; then
    ok "Terraform installed: $(terraform -version | head -n1)"
    return
  else
    warn "DNF install failed — falling back to official binary"
  fi

  case "$ARCH" in
    x86_64)  TARCH="amd64" ;;
    aarch64) TARCH="arm64" ;;
    *)       err "Unsupported arch for Terraform: $ARCH"; return 1 ;;
  esac

  VER="$(curl -fsSL https://checkpoint-api.hashicorp.com/v1/check/terraform | jq -r '.current_version')"
  curl -fsSLo /tmp/terraform.zip "https://releases.hashicorp.com/terraform/${VER}/terraform_${VER}_linux_${TARCH}.zip"
  unzip -o /tmp/terraform.zip -d /tmp
  sudo mv /tmp/terraform "${BIN_DIR}/terraform"
  rm -f /tmp/terraform.zip
  ok "Terraform $(terraform -version | head -n1)"
}

# ---------- Ansible ----------
install_ansible() {
  if need_cmd ansible; then ok "Ansible already installed: $(ansible --version | head -n1)"; return; fi
  log "Installing Ansible from Fedora repo"
  sudo dnf install -y ansible
  ok "Ansible $(ansible --version | head -n1)"
}

# ---------- Helm ----------
install_helm() {
  if need_cmd helm; then ok "Helm already installed: $(helm version --short 2>/dev/null || echo)"; return; fi
  log "Installing Helm"
  # Official helper script handles arch/platform
  curl -fsSL https://raw.githubusercontent.com/helm/helm/main/scripts/get-helm-3 | bash
  ok "Helm $(helm version --short)"
}

# ---------- Azure CLI ----------
install_azure_cli() {
  if need_cmd az; then ok "Azure CLI already installed: $(az version 2>/dev/null | jq -r '."azure-cli"' 2>/dev/null || echo)"; return; fi
  log "Installing Azure CLI (packages.microsoft.com repo)"
  sudo rpm --import https://packages.microsoft.com/keys/microsoft.asc
  sudo tee /etc/yum.repos.d/azure-cli.repo >/dev/null <<'EOF'
[azure-cli]
name=Azure CLI
baseurl=https://packages.microsoft.com/yumrepos/azure-cli
enabled=1
gpgcheck=1
gpgkey=https://packages.microsoft.com/keys/microsoft.asc
EOF
  sudo dnf clean all
  sudo dnf makecache || true
  sudo dnf install -y azure-cli
  ok "Azure CLI $(az version 2>/dev/null | jq -r '."azure-cli"' 2>/dev/null || echo 'installed')"
}

# ---------- Google Cloud SDK ----------
install_gcloud() {
  if need_cmd gcloud; then ok "gcloud already installed: $(gcloud version | head -n1)"; return; fi
  log "Installing Google Cloud SDK (EL9 repo works on Fedora 42)"
  sudo tee /etc/yum.repos.d/google-cloud-sdk.repo >/dev/null <<'EOF'
[google-cloud-sdk]
name=Google Cloud SDK
baseurl=https://packages.cloud.google.com/yum/repos/cloud-sdk-el9-x86_64
enabled=1
gpgcheck=1
repo_gpgcheck=0
gpgkey=https://packages.cloud.google.com/yum/doc/yum-key.gpg
       https://packages.cloud.google.com/yum/doc/rpm-package-key.gpg
EOF
  sudo dnf clean all
  sudo dnf makecache || true
  if ! sudo dnf install -y google-cloud-sdk; then
    warn "Repo install failed — falling back to official installer script"
    curl -fsSL https://sdk.cloud.google.com | bash || {
      err "gcloud install failed"; return 1;
    }
    # Add to PATH (for this shell and future shells via /etc/profile.d)
    if [ -d "$HOME/google-cloud-sdk/bin" ]; then
      echo 'export PATH="$PATH:$HOME/google-cloud-sdk/bin"' | sudo tee /etc/profile.d/google-cloud-sdk.sh >/dev/null
      # shellcheck disable=SC1090
      source /etc/profile.d/google-cloud-sdk.sh || true
    fi
  fi
  ok "gcloud $(gcloud version | head -n1)"
}

# ---------- AWS CLI v2 ----------
install_awscli() {
  if need_cmd aws; then ok "AWS CLI already installed: $(aws --version 2>&1)"; return; fi
  log "Installing AWS CLI v2"
  TMPDIR="$(mktemp -d)"
  case "$ARCH" in
    x86_64)  AWSURL="https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" ;;
     aarch64) AWSURL="https://awscli.amazonaws.com/awscli-exe-linux-aarch64.zip" ;;
    *)       err "Unsupported arch for AWS CLI: $ARCH"; return 1 ;;
  esac
  curl -fsSLo "$TMPDIR/awscliv2.zip" "$AWSURL"
  unzip -q "$TMPDIR/awscliv2.zip" -d "$TMPDIR"
  sudo "$TMPDIR/aws/install" || sudo "$TMPDIR/aws/install" --update
  rm -rf "$TMPDIR"
  ok "AWS CLI $(aws --version 2>&1)"
}

# ---------- Main ----------
main() {
  ensure_base_tools

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
  echo "  kubectl      -> $(command -v kubectl || echo 'not found')"
  echo "  eksctl       -> $(command -v eksctl || echo 'not found')"
  echo "  terraform    -> $(command -v terraform || echo 'not found')"
  echo "  ansible      -> $(command -v ansible || echo 'not found')"
  echo "  helm         -> $(command -v helm || echo 'not found')"
  echo "  az (Azure)   -> $(command -v az || echo 'not found')"
  echo "  gcloud       -> $(command -v gcloud || echo 'not found')"
  echo "  aws          -> $(command -v aws || echo 'not found')"
  echo
  echo "Tip: if 'gcloud' was installed via the Google installer, log out/in or run:"
  echo '  source /etc/profile.d/google-cloud-sdk.sh'
}

main "$@"

