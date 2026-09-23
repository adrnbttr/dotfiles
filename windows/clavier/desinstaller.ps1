# Retire la BÉPO et ses correctifs ; le clavier Belge reste seul.
#
#   powershell -ExecutionPolicy Bypass -File .\desinstaller.ps1
#
# Ne désinstalle pas AutoHotkey (d'autres scripts peuvent s'en servir).

$ErrorActionPreference = "Continue"

$startupDir = [Environment]::GetFolderPath("Startup")

Write-Host ""
Write-Host "❯ retrait de la BÉPO" -ForegroundColor White

Get-CimInstance Win32_Process -Filter "Name like 'AutoHotkey%'" |
    Where-Object { $_.CommandLine -like "*bepo-correctifs*" -or $_.CommandLine -like "*bepo-belge*" } |
    ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
Write-Host "  ✓ correctifs arrêtés"

Unregister-ScheduledTask -TaskName "bepo-correctifs" -Confirm:$false -ErrorAction SilentlyContinue
foreach ($f in @("bepo-correctifs.lnk", "bepo-belge.lnk")) {
    Remove-Item (Join-Path $startupDir $f) -Force -ErrorAction SilentlyContinue
}
foreach ($d in @("bepo", "bepo-belge")) {
    Remove-Item (Join-Path $env:LOCALAPPDATA $d) -Recurse -Force -ErrorAction SilentlyContinue
}
Write-Host "  ✓ démarrage automatique et fichiers retirés"

$list = Get-WinUserLanguageList
$changed = $false
foreach ($lang in $list) {
    foreach ($tip in @($lang.InputMethodTips | Where-Object { $_ -like "*:0002040C" })) {
        [void]$lang.InputMethodTips.Remove($tip)
        $changed = $true
    }
}
if ($changed) {
    Set-WinUserLanguageList $list -Force -WarningAction SilentlyContinue
    Write-Host "  ✓ clavier BÉPO retiré de la liste"
} else {
    Write-Host "  · pas de clavier BÉPO dans la liste"
}

Write-Host ""
Write-Host "Il reste le clavier Belge, conforme aux touches imprimées." -ForegroundColor White
Write-Host "AutoHotkey reste installé (winget uninstall AutoHotkey.AutoHotkey pour le retirer)."
