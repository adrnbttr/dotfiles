# Installe le clavier « BÉPO hybride » sur le ThinkPad (clavier AZERTY belge).
#
#   powershell -ExecutionPolicy Bypass -File .\installer.ps1
#
# Fait, dans l'ordre :
#   1. règle la disposition Windows sur Français (Belgique) — indispensable
#      pour que les caractères imprimés sur les touches fonctionnent ;
#   2. installe AutoHotkey v2 (winget) ;
#   3. copie bepo-belge.ahk dans %LOCALAPPDATA%\bepo-belge ;
#   4. le lance et l'ajoute au démarrage de session ;
#   5. propose un test rapide.
#
# Réexécutable sans risque. Pour tout retirer : .\desinstaller.ps1

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$dest = Join-Path $env:LOCALAPPDATA "bepo-belge"
$script = Join-Path $dest "bepo-belge.ahk"
$startup = Join-Path ([Environment]::GetFolderPath("Startup")) "bepo-belge.lnk"
$index = 0
$total = 4
$results = @()

function Step($label, $block) {
    $script:index++
    $bar = ("█" * [math]::Floor($script:index * 12 / $total)).PadRight(12, "·")
    Write-Host ("  [{0}] {1}" -f $bar, $label.PadRight(30)) -NoNewline
    try {
        $r = & $block
        if ($r -eq "skip") { Write-Host " ✓ déjà là" -ForegroundColor Green; $script:results += "déjà là" }
        else { Write-Host " ✓" -ForegroundColor Green; $script:results += "fait" }
    } catch {
        Write-Host " ✗ échec" -ForegroundColor Red
        Write-Host ("      " + $_.Exception.Message) -ForegroundColor DarkGray
        $script:results += "échec"
    }
}

Write-Host ""
Write-Host "❯ clavier BÉPO hybride · ThinkPad AZERTY belge" -ForegroundColor White
Write-Host ""

# 1. Disposition belge ---------------------------------------------------------
Step "disposition Français (Belgique)" {
    $list = Get-WinUserLanguageList
    $fr = $list | Where-Object { $_.LanguageTag -like "fr*" } | Select-Object -First 1
    if (-not $fr) {
        $list.Add("fr-BE")
        $fr = $list | Where-Object { $_.LanguageTag -eq "fr-BE" }
    }
    # 0813:0000080C = clavier belge (période française) ; 080C = belge francophone
    if ($fr.InputMethodTips -contains "080C:0000080C") { return "skip" }
    $fr.InputMethodTips.Clear()
    $fr.InputMethodTips.Add("080C:0000080C")
    Set-WinUserLanguageList $list -Force
}

# 2. AutoHotkey v2 -------------------------------------------------------------
Step "AutoHotkey v2" {
    $ahk = Get-Command AutoHotkey64.exe, AutoHotkey.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($ahk) { return "skip" }
    if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
        throw "winget introuvable : installe AutoHotkey v2 depuis https://www.autohotkey.com"
    }
    winget install --id AutoHotkey.AutoHotkey --exact --silent `
        --accept-package-agreements --accept-source-agreements | Out-Null
}

# 3. Copie du script -----------------------------------------------------------
Step "script BÉPO" {
    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    $source = Join-Path $PSScriptRoot "bepo-belge.ahk"
    if (-not (Test-Path $source)) { throw "bepo-belge.ahk introuvable à côté de ce script" }
    if ((Test-Path $script) -and ((Get-FileHash $source).Hash -eq (Get-FileHash $script).Hash)) {
        return "skip"
    }
    Copy-Item $source $script -Force
}

# 4. Démarrage automatique + lancement -----------------------------------------
Step "démarrage automatique" {
    $exe = (Get-Command AutoHotkey64.exe, AutoHotkey.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1).Source
    if (-not $exe) {
        $exe = @(
            "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
            "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe"
        ) | Where-Object { Test-Path $_ } | Select-Object -First 1
    }
    if (-not $exe) { throw "AutoHotkey v2 introuvable : rouvre un terminal et relance ce script" }

    Get-Process AutoHotkey64, AutoHotkey -ErrorAction SilentlyContinue |
        Where-Object { $_.Path -eq $exe } | Stop-Process -Force -ErrorAction SilentlyContinue

    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($startup)
    $lnk.TargetPath = $exe
    $lnk.Arguments = '"' + $script + '"'
    $lnk.WorkingDirectory = $dest
    $lnk.Description = "BÉPO hybride sur clavier belge"
    $lnk.Save()

    Start-Process $exe -ArgumentList "`"$script`""
}

# Résumé ------------------------------------------------------------------------
Write-Host ""
Write-Host "─────────────────────────────────────────────" -ForegroundColor DarkGray
if ($results -contains "échec") {
    Write-Host "Des étapes ont échoué : corrige le point signalé puis relance." -ForegroundColor Red
    return
}
Write-Host "Le BÉPO hybride est actif." -ForegroundColor White
Write-Host ""
Write-Host "  Ctrl+Alt+Shift+B   activer / désactiver (retour au belge normal)"
Write-Host "  Ctrl+Alt+Shift+Q   quitter le script"
Write-Host "  .\desinstaller.ps1 tout retirer"
Write-Host ""
Write-Host "Test rapide (ouvre le Bloc-notes et tape) :" -ForegroundColor White
Write-Host "  · les touches A S D F G H J K L donnent : a u i e , c t s r"
Write-Host "  · AltGr+2 donne @ · AltGr+9 donne { · AltGr+0 donne }"
Write-Host "  · ^ puis a donne â · Shift+, donne ; · Shift+. donne :"
