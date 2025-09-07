#Requires -RunAsAdministrator
<#
  setup-devops-tools.ps1
  Windows DevOps tools via WinGet (no Ansible).
  Core: kubectl, eksctl, Terraform, Helm, Azure CLI, Google Cloud SDK, AWS CLI v2
  Optional: Docker Desktop, k9s, GKE auth plugin
  Ops: -Upgrade to update; -Uninstall to remove.
#>

param(
  [switch]$IncludeDockerDesktop,
  [switch]$IncludeK9s,
  [switch]$IncludeGkeAuth,
  [switch]$Upgrade,
  [switch]$Uninstall
)

Set-StrictMode -Version Latest
$ErrorActionPreference = "Stop"

function Log([string]$m){ Write-Host "[INFO] $m" -ForegroundColor Cyan }
function Ok([string]$m){ Write-Host "[ OK ] $m" -ForegroundColor Green }
function Warn([string]$m){ Write-Host "[WARN] $m" -ForegroundColor Yellow }
function Err([string]$m){ Write-Host "[ERR ] $m" -ForegroundColor Red }

if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
  Err "WinGet not found. Install 'App Installer' from Microsoft Store, then re-run."
  exit 1
}

# Exact WinGet IDs (stable as of 2025-09)
$PACKAGES_CORE = @(
  @{ Id = "Kubernetes.kubectl";      Name = "kubectl"      }
  @{ Id = "eksctl.eksctl";           Name = "eksctl"       }
  @{ Id = "Hashicorp.Terraform";     Name = "Terraform"    }
  @{ Id = "Helm.Helm";               Name = "Helm"         }
  @{ Id = "Microsoft.AzureCLI";      Name = "Azure CLI"    }
  @{ Id = "Google.CloudSDK";         Name = "Google Cloud SDK" }
  @{ Id = "Amazon.AWSCLI";           Name = "AWS CLI v2"   }
)

$PACKAGES_OPTIONAL = @()

if ($IncludeDockerDesktop) {
  $PACKAGES_OPTIONAL += @{ Id = "Docker.DockerDesktop"; Name = "Docker Desktop" }
}
if ($IncludeK9s) {
  $PACKAGES_OPTIONAL += @{ Id = "Derailed.k9s"; Name = "k9s" }
}

# Helpers -------------
function Refresh-Path {
  $env:PATH = [System.Environment]::GetEnvironmentVariable("PATH","Machine") + ";" +
              [System.Environment]::GetEnvironmentVariable("PATH","User")
}

function Is-Installed([string]$Id) {
  try {
    $null -ne (winget list --id $Id -e 2>$null | Select-String -SimpleMatch $Id)
  } catch { $false }
}

function Install-WinGet([string]$Id, [string]$Display) {
  if (Is-Installed $Id) { Ok "$Display already installed"; return }
  Log "Installing $Display ($Id)"
  try {
    winget install --id $Id -e --accept-source-agreements --accept-package-agreements --silent
  } catch {
    Warn "Silent install failed for $Display; retrying interactive"
    winget install --id $Id -e --accept-source-agreements --accept-package-agreements
  }
  Start-Sleep -Seconds 2
  if (-not (Is-Installed $Id)) { Err "Failed to install $Display"; exit 1 }
  Ok "$Display installed"
}

function Upgrade-WinGet([string]$Id, [string]$Display) {
  if (-not (Is-Installed $Id)) { Warn "$Display not installed; skipping upgrade"; return }
  Log "Upgrading $Display ($Id)"
  try {
    winget upgrade --id $Id -e --accept-source-agreements --accept-package-agreements --silent
  } catch {
    Warn "Silent upgrade failed for $Display; retrying interactive"
    winget upgrade --id $Id -e --accept-source-agreements --accept-package-agreements
  }
  Ok "$Display upgraded (or already latest)"
}

function Uninstall-WinGet([string]$Id, [string]$Display) {
  if (-not (Is-Installed $Id)) { Ok "$Display not installed"; return }
  Log "Uninstalling $Display ($Id)"
  try {
    winget uninstall --id $Id -e --silent
  } catch {
    Warn "Silent uninstall failed for $Display; retrying interactive"
    winget uninstall --id $Id -e
  }
  Ok "$Display removed (you may need to close open shells)"
}

# GKE auth plugin via gcloud components (optional)
function Ensure-GkeAuthPlugin {
  if (-not $IncludeGkeAuth) { return }
  if (-not (Get-Command gcloud -ErrorAction SilentlyContinue)) {
    Warn "gcloud not found; skipping GKE auth plugin. (Install Google Cloud SDK first.)"
    return
  }
  Log "Installing GKE auth plugin via gcloud components"
  try {
    & gcloud components install gke-gcloud-auth-plugin -q
    Ok "GKE auth plugin installed"
  } catch {
    Warn "Could not install GKE auth plugin. Ensure gcloud is the bundled installer and not restricted by policy."
  }
}

# Main modes -------------
Refresh-Path

if ($Uninstall) {
  Log "Uninstall mode selected"
  foreach ($p in $PACKAGES_OPTIONAL + $PACKAGES_CORE) { Uninstall-WinGet $p.Id $p.Name }
  Write-Host ""
  Ok "Uninstall complete."
  return
}

if ($Upgrade) {
  Log "Upgrade mode selected"
  foreach ($p in $PACKAGES_CORE)   { Upgrade-WinGet $p.Id $p.Name }
  foreach ($p in $PACKAGES_OPTIONAL){ Upgrade-WinGet $p.Id $p.Name }
  Ensure-GkeAuthPlugin
  Write-Host ""
  Ok "Upgrade complete."
  return
}

# Install mode (default)
Log "Installing core DevOps tools"
foreach ($p in $PACKAGES_CORE) { Install-WinGet $p.Id $p.Name }

if ($PACKAGES_OPTIONAL.Count -gt 0) {
  Log "Installing optional extras"
  foreach ($p in $PACKAGES_OPTIONAL) { Install-WinGet $p.Id $p.Name }
}

Refresh-Path
Ensure-GkeAuthPlugin

# Verify versions
Write-Host ""
Log "Verifying tool versions"
try { kubectl version --client --short } catch { Warn "kubectl not on PATH yet; open a new shell and recheck" }
try { eksctl version } catch { Warn "eksctl not on PATH yet" }
try { terraform -version | Select-Object -First 1 } catch { Warn "terraform not on PATH yet" }
try { helm version --short } catch { Warn "helm not on PATH yet" }
try { az version | Out-String | Select-String -Pattern 'azure-cli' | ForEach-Object { $_.ToString().Trim() } } catch { Warn "az not on PATH yet" }
try { gcloud version | Select-Object -First 2 } catch { Warn "gcloud not on PATH yet" }
try { aws --version } catch { Warn "aws not on PATH yet" }
if ($IncludeK9s) { try { k9s version } catch { Warn "k9s not on PATH yet" } }

Ok "All requested tools installed."
Write-Host "`nTip: If a command isn't found immediately, close and reopen PowerShell."


# Quick reference

# Install core only:
# Set-ExecutionPolicy -Scope Process Bypass -Force
# .\setup-devops-tools.ps1

# Install core + all extras:
# Set-ExecutionPolicy -Scope Process Bypass -Force
# .\setup-devops-tools.ps1 -IncludeDockerDesktop -IncludeK9s -IncludeGkeAuth

# Upgrade later:
# Set-ExecutionPolicy -Scope Process Bypass -Force
# .\setup-devops-tools.ps1 -Upgrade

# Uninstall later:
# Set-ExecutionPolicy -Scope Process Bypass -Force
# .\setup-devops-tools.ps1 -Uninstall