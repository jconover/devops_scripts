#!/usr/bin/env bash
set -euo pipefail

log() { printf "\033[1;36m[INFO]\033[0m %s\n" "$*"; }
ok()  { printf "\033[1;32m[ OK ]\033[0m %s\n" "$*"; }
warn(){ printf "\033[1;33m[WARN]\033[0m %s\n" "$*"; }
err() { printf "\033[1;31m[ERR ]\033[0m %s\n" "$*"; }

USER_NAME="${SUDO_USER:-$USER}"

# 0) Update & install
log "Updating apt and installing Podman + rootless deps"
sudo apt-get update -y
sudo apt-get install -y podman podman-docker uidmap slirp4netns fuse-overlayfs buildah skopeo

# 1) Ensure user namespaces allowed (usually true)
if [ -f /proc/sys/kernel/unprivileged_userns_clone ]; then
  VAL="$(cat /proc/sys/kernel/unprivileged_userns_clone)"
  if [ "$VAL" != "1" ]; then
    log "Enabling unprivileged user namespaces"
    echo 'kernel.unprivileged_userns_clone=1' | sudo tee /etc/sysctl.d/99-podman-unprivileged-userns.conf >/dev/null
    sudo sysctl --system >/dev/null
  fi
fi

# 2) Ensure subuid/subgid ranges for rootless
needs_subuid_subgid_fix=false
if ! grep -q "^${USER_NAME}:" /etc/subuid; then
  echo "${USER_NAME}:100000:65536" | sudo tee -a /etc/subuid >/dev/null
  needs_subuid_subgid_fix=true
fi
if ! grep -q "^${USER_NAME}:" /etc/subgid; then
  echo "${USER_NAME}:100000:65536" | sudo tee -a /etc/subgid >/dev/null
  needs_subuid_subgid_fix=true
fi
$needs_subuid_subgid_fix && warn "Added subuid/subgid ranges for ${USER_NAME}. You may need to re-login for changes to take effect."

# 3) Storage driver hint (fuse-overlayfs for rootless)
if ! grep -q "mount_program" "${HOME}/.config/containers/storage.conf" 2>/dev/null; then
  log "Ensuring fuse-overlayfs is used for rootless"
  mkdir -p "${HOME}/.config/containers"
  cat > "${HOME}/.config/containers/storage.conf" <<'EOF'
[storage]
driver = "overlay"
runroot = "/run/user/1000/containers"
graphroot = "~/.local/share/containers/storage"
[storage.options]
mount_program = "/usr/bin/fuse-overlayfs"
EOF
fi

# 4) Basic verification
log "Verifying Podman"
podman --version
podman info | sed -n '1,20p' || true

# 5) Smoke test (rootless)
log "Running hello container (quay.io/podman/hello) as ${USER_NAME}"
sudo -u "${USER_NAME}" -E bash -lc 'podman run --rm quay.io/podman/hello:latest' || warn "hello test failed (often just a network or loginctl linger issue)"

ok "Podman setup complete on Ubuntu 25.04 🎉"
echo "If rootless pulls fail after subuid/subgid changes, log out/in or run: loginctl enable-linger ${USER_NAME}"
