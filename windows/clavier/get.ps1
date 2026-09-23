# Clavier BÉPO hybride — installation en une commande (PowerShell) :
#
#   irm https://raw.githubusercontent.com/adrnbttr/dotfiles/master/windows/clavier/get.ps1 | iex
#
# Depuis WSL, la même chose :
#
#   powershell.exe -NoProfile -c "irm https://raw.githubusercontent.com/adrnbttr/dotfiles/master/windows/clavier/get.ps1 | iex"
#
# Fait, dans l'ordre :
#   1. vérifie Windows et l'accès réseau ;
#   2. télécharge le script BÉPO et son installeur ;
#   3. passe la main à installer.ps1 (disposition belge, AutoHotkey v2,
#      copie, démarrage automatique).
#
# Aucun droit administrateur nécessaire. Réexécutable sans risque.

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Base = if ($env:DOTFILES_RAW) { $env:DOTFILES_RAW }
        else { "https://raw.githubusercontent.com/adrnbttr/dotfiles/master" }
$dir = Join-Path $env:TEMP "bepo-belge-setup"

Write-Host ""
Write-Host "❯ clavier BÉPO hybride · téléchargement" -ForegroundColor White
Write-Host ""

if ($PSVersionTable.Platform -eq "Unix") {
    Write-Host "  ✗ à lancer depuis Windows (PowerShell), pas depuis Linux" -ForegroundColor Red
    return
}

try {
    Invoke-WebRequest -UseBasicParsing -Uri "https://github.com" -TimeoutSec 8 | Out-Null
    Write-Host "  ✓ accès réseau (github.com)"
} catch {
    Write-Host "  ✗ pas d'accès à github.com" -ForegroundColor Red
    return
}

New-Item -ItemType Directory -Force -Path $dir | Out-Null
foreach ($file in @("bepo-belge.ahk", "installer.ps1", "desinstaller.ps1",
                    "test-clavier.ahk", "README.md")) {
    try {
        Invoke-WebRequest -UseBasicParsing -Uri "$Base/windows/clavier/$file" `
            -OutFile (Join-Path $dir $file)
        Write-Host "  ✓ $file"
    } catch {
        Write-Host "  ✗ $file : $($_.Exception.Message)" -ForegroundColor Red
        return
    }
}

# Sous-processus avec -ExecutionPolicy Bypass : la commande fonctionne même si
# la stratégie d'exécution interdit les scripts téléchargés.
$ps = (Get-Process -Id $PID).Path
if (-not $ps) { $ps = "powershell.exe" }
& $ps -NoProfile -ExecutionPolicy Bypass -File (Join-Path $dir "installer.ps1")

Write-Host ""
Write-Host ("Les fichiers restent dans {0}" -f $dir) -ForegroundColor DarkGray
Write-Host "  · README.md        ce que tape chaque touche"
Write-Host "  · test-clavier.ahk vérifie les 37 cas tout seul"
Write-Host "  · desinstaller.ps1 pour tout retirer"
