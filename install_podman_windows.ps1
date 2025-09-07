#Requires -RunAsAdministrator
Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Log([string]$msg) { Write-Host "[INFO] $msg" -ForegroundColor Cyan }
function Ok([string]$msg)  { Write-Host "[ OK ] $msg" -ForegroundColor Green }
function Warn([string]$msg){ Write-Host "[WARN] $msg" -ForegroundColor Yellow }

# 0) Ensure winget (Windows 10/11 with App Installer)
if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Throw "winget not found. Install 'App Installer' from Microsoft Store, then re-run."
}

# 1) Install Podman CLI
Log "Installing/Upgrading Podman CLI via winget"
# RedHat.Podman is the official CLI package. If this ID ever changes, search: winget search podman
try {
  winget install --id RedHat.Podman -e --accept-source-agreements --accept-package-agreements
} catch {
  Warn "winget install may have failed or Podman is already installed. Continuing..."
}

# 2) (Optional) Podman Desktop (GUI). Comment out if you don't want it.
Log "Installing/Upgrading Podman Desktop (optional)"
try {
  winget install --id Podman-Desktop.Podman-Desktop -e --accept-source-agreements --accept-package-agreements
} catch {
  Warn "winget install may have failed or Desktop already installed. Continuing..."
}

# Re-open PATH for this session if needed
$env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
            [System.Environment]::GetEnvironmentVariable("PATH","User")

# 3) Verify CLI is available
if (-not (Get-Command podman -ErrorAction SilentlyContinue)) {
  Throw "Podman CLI not found on PATH after install. Close and reopen PowerShell, then re-run."
}

# 4) Ensure a Podman machine exists (uses WSL2/VM backend under the hood)
try {
  podman machine inspect default | Out-Null
  Ok "Podman machine 'default' already exists"
} catch {
  Log "Creating podman machine 'default' (rootful)"
  podman machine init --rootful
}

# 5) Start machine
Log "Starting podman machine"
podman machine start

# 6) Basic verification
Log "Verifying Podman"
podman --version
podman info | Select-Object -First 20 | Out-String | Write-Host
Ok "Podman setup complete on Windows 🎉"

# Set-ExecutionPolicy -Scope Process -ExecutionPolicy Bypass -Force
# .\install_podman_windows.ps1
