#!/usr/bin/env bash
set -euo pipefail

log() { printf "\033[1;36m[INFO]\033[0m %s\n" "$*"; }
ok()  { printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }

# 0) Update & base tools
log "Updating system and installing Podman"
sudo dnf -y update || true
sudo dnf -y install podman podman-docker buildah skopeo

# 1) Optional: enable the Podman API socket (Docker-compatible API in many tools)
if systemctl list-unit-files | grep -q '^podman.socket'; then
  log "Enabling Podman API socket (optional)"
  sudo systemctl enable --now podman.socket || warn "Could not enable podman.socket (continuing)"
fi

# 2) Basic verification
log "Verifying Podman"
podman --version
podman info | sed -n '1,20p' || true

# 3) Smoke test
log "Running hello container (quay.io/podman/hello)"
podman run --rm quay.io/podman/hello:latest || warn "hello test failed (network or policy?)"

ok "Podman setup complete on Fedora 42 🎉"
