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

# Chemin de l'exécutable AutoHotkey v2, où qu'il ait été installé.
function Trouve-AutoHotkey {
    $cmd = Get-Command AutoHotkey64.exe, AutoHotkey.exe -ErrorAction SilentlyContinue |
        Select-Object -First 1
    if ($cmd) { return $cmd.Source }
    return @(
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey32.exe",
        "${env:ProgramFiles(x86)}\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe",
        "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey32.exe"
    ) | Where-Object { Test-Path $_ } | Select-Object -First 1
}

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
    if (Trouve-AutoHotkey) { return "skip" }

    if (Get-Command winget.exe -ErrorAction SilentlyContinue) {
        winget install --id AutoHotkey.AutoHotkey --exact --silent `
            --accept-package-agreements --accept-source-agreements | Out-Null
        if (Trouve-AutoHotkey) { return }
    }

    # Pas de winget (ou installation muette refusée) : téléchargement direct,
    # dans le dossier de l'utilisateur, sans droits administrateur.
    $setup = Join-Path $env:TEMP "ahk-v2-setup.exe"
    Invoke-WebRequest -UseBasicParsing -Uri "https://www.autohotkey.com/download/ahk-v2.exe" `
        -OutFile $setup
    $cible = Join-Path $env:LOCALAPPDATA "Programs\AutoHotkey"
    Start-Process $setup -ArgumentList "/silent", "/installto", "`"$cible`"" -Wait
    Remove-Item $setup -Force -ErrorAction SilentlyContinue
    if (-not (Trouve-AutoHotkey)) {
        throw "AutoHotkey v2 n'a pas pu être installé : télécharge-le depuis https://www.autohotkey.com"
    }
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
    $exe = Trouve-AutoHotkey
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
Write-Host "  · AltGr+2 donne @ · AltGr+9 donne { · AltGr+E donne €"
Write-Host "  · ^ puis a donne â · AltGr+Shift+^ puis e donne ë"
Write-Host ""
Write-Host "Les symboles recouverts par les lettres BÉPO reviennent sur leur touche :" -ForegroundColor White
Write-Host "  · AltGr = la légende de droite · AltGr+Shift = la légende recouverte"
Write-Host "  · exemples : AltGr+Shift sur « =+~ » donne = · sur « :/ » donne /"
Write-Host "  · rangée des chiffres, AltGr+Shift : 7=+  9=/  0=*  )==  -=%"
