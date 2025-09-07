#!/usr/bin/env bash
set -euo pipefail

log() { printf "\033[1;36m[INFO]\033[0m %s\n" "$*"; }
ok()  { printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }

# 0) Ensure Homebrew
if ! command -v brew >/dev/null 2>&1; then
  log "Homebrew not found, installing..."
  /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
  # Add brew to PATH for this session
  if [[ -d "/opt/homebrew/bin" ]]; then
    eval "$(/opt/homebrew/bin/brew shellenv)"
  elif [[ -d "/usr/local/bin" ]]; then
    eval "$(/usr/local/bin/brew shellenv)"
  fi
fi

# 1) Install Podman (CLI)
log "Installing/Upgrading Podman CLI via Homebrew"
brew install podman || brew upgrade podman || true
ok "Podman CLI installed"

# 2) (Optional) Podman Desktop (GUI). Comment this out if you don't want it.
log "Installing/Upgrading Podman Desktop (optional)"
brew install --cask podman-desktop || brew upgrade --cask podman-desktop || true
ok "Podman Desktop installed (optional)"

# 3) Ensure a Podman machine exists
if ! podman machine inspect default >/dev/null 2>&1; then
  log "Creating podman machine 'default' (rootful)"
  podman machine init --rootful
else
  ok "Podman machine 'default' already exists"
fi

# 4) Start machine
log "Starting podman machine"
podman machine start

# 5) Basic verification
log "Verifying Podman"
podman --version
podman info | sed -n '1,20p'
ok "Podman setup complete on macOS 🎉"
