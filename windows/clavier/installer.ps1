# Deux dispositions sur le ThinkPad (clavier AZERTY belge) :
#   · Belge  : ce qui est imprimé sur les touches (inchangé) ;
#   · BÉPO   : la BÉPO native de Windows, alignée sur la BÉPO Linux.
# On passe de l'une à l'autre avec Win+Espace.
#
#   powershell -ExecutionPolicy Bypass -File .\installer.ps1
#
# Fait, dans l'ordre :
#   1. deux claviers sous la langue française : Belge, puis BÉPO ;
#   2. retire l'ancien « BÉPO hybride » s'il est là ;
#   3. installe AutoHotkey v2 (winget, sinon téléchargement) ;
#   4. copie bepo-correctifs.ahk, le lance et l'ajoute au démarrage.
#
# Aucun droit administrateur. Réexécutable sans risque. Retrait : .\desinstaller.ps1

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$BELGE = "080C:0000080C"   # clavier Belge (période)
$BEPO = "080C:0002040C"    # clavier Français (Standard, BÉPO)

$dest = Join-Path $env:LOCALAPPDATA "bepo"
$script = Join-Path $dest "bepo-correctifs.ahk"
$startupDir = [Environment]::GetFolderPath("Startup")
$startup = Join-Path $startupDir "bepo-correctifs.lnk"
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
Write-Host "❯ clavier · Belge + BÉPO (ThinkPad AZERTY belge)" -ForegroundColor White
Write-Host ""

# 1. Dispositions --------------------------------------------------------------
# Belge en premier (défaut, ce qui est imprimé), BÉPO en second, rangés sous la
# langue française déjà présente (fr-FR quand Windows est affiché en français
# de France : sinon Windows rajoute la langue d'affichage et ses claviers dans
# la liste de la barre des tâches). Les autres langues ne sont pas touchées.
Step "claviers Belge + BÉPO" {
    if (-not (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\0002040C")) {
        throw "cette version de Windows n'a pas la BÉPO native (Windows 10 1903 ou plus récent requis)"
    }
    $list = Get-WinUserLanguageList
    $fr = $list | Where-Object { $_.LanguageTag -like "fr*" } | Select-Object -First 1
    if (-not $fr) {
        $list.Insert(0, "fr-FR")
        $fr = $list | Where-Object { $_.LanguageTag -eq "fr-FR" }
    }
    # Le préfixe d'un clavier est l'identifiant de sa langue (fr-FR 040C, fr-BE 080C).
    $lcid = "{0:X4}" -f [Globalization.CultureInfo]::GetCultureInfo($fr.LanguageTag).LCID
    $tips = @("${lcid}:$($BELGE.Split(':')[1])", "${lcid}:$($BEPO.Split(':')[1])")
    if (($fr.InputMethodTips -join ",") -eq ($tips -join ",")) { return "skip" }
    $fr.InputMethodTips.Clear()
    foreach ($t in $tips) { $fr.InputMethodTips.Add($t) }
    Set-WinUserLanguageList $list -Force -WarningAction SilentlyContinue
}

# 2. Ancien « BÉPO hybride » (lettres BÉPO sur symboles belges) -----------------
Step "retrait de l'ancien hybride" {
    $old = Join-Path $env:LOCALAPPDATA "bepo-belge"
    $oldLnk = Join-Path $startupDir "bepo-belge.lnk"
    if (-not (Test-Path $old) -and -not (Test-Path $oldLnk)) { return "skip" }
    Get-CimInstance Win32_Process -Filter "Name like 'AutoHotkey%'" |
        Where-Object { $_.CommandLine -like "*bepo-belge*" } |
        ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
    Remove-Item $oldLnk -Force -ErrorAction SilentlyContinue
    Remove-Item $old -Recurse -Force -ErrorAction SilentlyContinue
}

# 3. AutoHotkey v2 -------------------------------------------------------------
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

# 4. Correctifs BÉPO : copie, démarrage automatique, lancement ------------------
Step "correctifs BÉPO" {
    $exe = Trouve-AutoHotkey
    if (-not $exe) { throw "AutoHotkey v2 introuvable : rouvre un terminal et relance ce script" }
    $source = Join-Path $PSScriptRoot "bepo-correctifs.ahk"
    if (-not (Test-Path $source)) { throw "bepo-correctifs.ahk introuvable à côté de ce script" }

    New-Item -ItemType Directory -Force -Path $dest | Out-Null
    Copy-Item $source $script -Force

    $shell = New-Object -ComObject WScript.Shell
    $lnk = $shell.CreateShortcut($startup)
    $lnk.TargetPath = $exe
    $lnk.Arguments = '"' + $script + '"'
    $lnk.WorkingDirectory = $dest
    $lnk.Description = "BÉPO : correctifs pour taper comme sous Linux"
    $lnk.Save()

    # #SingleInstance Force : relancer remplace la version qui tourne.
    Start-Process $exe -ArgumentList "`"$script`""

    # WezTerm : lettres de saut entre splits sur la rangée de repos BÉPO.
    $kb = Join-Path $HOME ".config\wezterm\keyboard"
    if (-not (Test-Path $kb)) {
        New-Item -ItemType Directory -Force -Path (Split-Path $kb) | Out-Null
        [IO.File]::WriteAllText($kb, "bepo`n")
    }
}

# Résumé ------------------------------------------------------------------------
Write-Host ""
Write-Host "─────────────────────────────────────────────" -ForegroundColor DarkGray
if ($results -contains "échec") {
    Write-Host "Des étapes ont échoué : corrige le point signalé puis relance." -ForegroundColor Red
    return
}
Write-Host "Belge + BÉPO en place." -ForegroundColor White
Write-Host ""
Write-Host "  Win+Espace         passer du Belge à la BÉPO (et retour)"
Write-Host "  en BÉPO            tout comme sous Linux : chiffres, AltGr, Ctrl+lettre"
Write-Host "  test-clavier.ahk   vérifie 25 cas tout seul"
Write-Host ""
Write-Host "Si la BÉPO n'apparaît pas dans Win+Espace : ferme la session et rouvre-la." -ForegroundColor DarkGray
