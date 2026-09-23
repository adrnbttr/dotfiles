# Retire le clavier « BÉPO hybride » et revient à l'AZERTY belge d'origine.
#
#   powershell -ExecutionPolicy Bypass -File .\desinstaller.ps1
#
# Ne désinstalle pas AutoHotkey (d'autres scripts peuvent s'en servir) et ne
# touche pas à la disposition Windows, qui reste en Français (Belgique) :
# c'est elle qui fait correspondre les touches imprimées.

$ErrorActionPreference = "Continue"

$dest = Join-Path $env:LOCALAPPDATA "bepo-belge"
$startup = Join-Path ([Environment]::GetFolderPath("Startup")) "bepo-belge.lnk"

Write-Host ""
Write-Host "❯ retrait du BÉPO hybride" -ForegroundColor White

Get-Process AutoHotkey64, AutoHotkey -ErrorAction SilentlyContinue | ForEach-Object {
    try {
        if ($_.CommandLine -like "*bepo-belge*" -or $_.Path -like "*AutoHotkey*") {
            $_ | Stop-Process -Force -ErrorAction SilentlyContinue
        }
    } catch {}
}
Write-Host "  ✓ script arrêté"

if (Test-Path $startup) { Remove-Item $startup -Force; Write-Host "  ✓ démarrage automatique retiré" }
else { Write-Host "  · pas de démarrage automatique" }

if (Test-Path $dest) { Remove-Item $dest -Recurse -Force; Write-Host "  ✓ fichiers supprimés" }
else { Write-Host "  · rien à supprimer" }

Write-Host ""
Write-Host "Le clavier est redevenu un AZERTY belge classique." -ForegroundColor White
Write-Host "AutoHotkey reste installé (winget uninstall AutoHotkey.AutoHotkey pour le retirer)."
