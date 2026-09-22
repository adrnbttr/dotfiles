# Installe WezTerm côté Windows avec la même config que sous Linux.
#
# Le shell (zsh, oh-my-zsh, nvim, sessions de-session...) vit dans WSL :
# lancer ensuite ./script/install DANS WSL pour l'installer.
#
# Usage (PowerShell, utilisateur normal, pas besoin d'admin) :
#   powershell -ExecutionPolicy Bypass -File .\script\install-windows.ps1
# Le dépôt peut être cloné côté Windows ou dans WSL (\\wsl$\Ubuntu\home\...).

$ErrorActionPreference = "Stop"

$repoRoot = Split-Path -Parent $PSScriptRoot
$weztermConfig = Join-Path $repoRoot "config\.config\wezterm\wezterm.lua"

function Info($msg) { Write-Host $msg }
function Warn($msg) { Write-Warning $msg }

# --- WezTerm -------------------------------------------------------------------
if (Get-Command wezterm.exe -ErrorAction SilentlyContinue) {
  Info "wezterm déjà installé ($(wezterm.exe --version))"
} elseif (Get-Command winget.exe -ErrorAction SilentlyContinue) {
  Info "installation de WezTerm (winget)"
  winget install --id wez.wezterm --exact --silent --accept-package-agreements --accept-source-agreements
} else {
  Warn "winget introuvable : installer WezTerm depuis https://wezterm.org/install/windows.html"
}

# --- Police MesloLGS NF (celle de kitty.conf / wezterm.lua) ---------------------
# Installation par utilisateur (sans admin) : fichier dans %LOCALAPPDATA% et
# enregistrement dans HKCU.
$fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
$fontReg = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
# Surtout pas de New-Item -Force ici : sur une clé existante, il la recrée
# vide et efface les polices déjà enregistrées.
if (-not (Test-Path $fontReg)) {
  New-Item -Path $fontReg | Out-Null
}

$fontBase = "https://github.com/romkatv/powerlevel10k-media/raw/master"
foreach ($style in @("Regular", "Bold", "Italic", "Bold Italic")) {
  $file = "MesloLGS NF $style.ttf"
  $dest = Join-Path $fontDir $file
  if (Test-Path $dest) {
    continue
  }
  Info "installation de la police $file"
  try {
    Invoke-WebRequest -UseBasicParsing -Uri "$fontBase/$([uri]::EscapeDataString($file))" -OutFile $dest
    New-ItemProperty -Force -Path $fontReg -Name "MesloLGS NF $style (TrueType)" -Value $dest | Out-Null
  } catch {
    Warn "échec du téléchargement de $file : $_"
  }
}

# --- Config ---------------------------------------------------------------------
# WEZTERM_CONFIG_FILE pointe directement sur le fichier du dépôt : pas de lien
# symbolique (qui exigerait le mode développeur ou l'admin), et ça marche aussi
# avec un dépôt cloné dans WSL (chemin \\wsl$\...).
if (-not (Test-Path $weztermConfig)) {
  throw "config introuvable : $weztermConfig"
}
[Environment]::SetEnvironmentVariable("WEZTERM_CONFIG_FILE", $weztermConfig, "User")
Info "WEZTERM_CONFIG_FILE = $weztermConfig"

# --- WSL ------------------------------------------------------------------------
$distros = @()
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
  $distros = (wsl.exe --list --quiet) -replace "`0", "" | Where-Object { $_ -ne "" }
}
if ($distros.Count -eq 0) {
  Warn "aucune distribution WSL : WezTerm ouvrira PowerShell. Pour le workflow complet : wsl --install -d Ubuntu"
} else {
  Info "distributions WSL : $($distros -join ', ') (Ubuntu utilisée en priorité)"
}

Info ""
Info "Terminé. Étapes suivantes :"
Info "  1. Dans WSL : cloner le dépôt puis lancer ./script/install"
Info "  2. Relancer WezTerm (la variable WEZTERM_CONFIG_FILE est lue au démarrage)"
