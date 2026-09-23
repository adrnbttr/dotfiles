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
$startup = Join-Path $startupDir "bepo-correctifs.lnk"   # ancien démarrage, retiré
$task = "bepo-correctifs"
$index = 0
$total = 5
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
# langue d'affichage de Windows si elle est française. Windows ajoute d'office
# la langue d'affichage (et ses claviers) à la liste de la barre des tâches :
# ranger les claviers ailleurs (fr-BE sous un Windows en fr-FR) les doublait.
# Les autres langues gardent leurs claviers, sauf ces deux-là ; une langue qui
# n'avait qu'eux disparaît.
Step "claviers Belge + BÉPO" {
    if (-not (Test-Path "HKLM:\SYSTEM\CurrentControlSet\Control\Keyboard Layouts\0002040C")) {
        throw "cette version de Windows n'a pas la BÉPO native (Windows 10 1903 ou plus récent requis)"
    }
    $list = Get-WinUserLanguageList
    $affichage = (Get-WinUILanguageOverride).Name
    if (-not $affichage) { $affichage = (Get-UICulture).Name }
    $tag = if ($affichage -like "fr*") { $affichage }
           elseif ($f = $list | Where-Object { $_.LanguageTag -like "fr*" } | Select-Object -First 1) { $f.LanguageTag }
           else { "fr-FR" }

    # Le préfixe d'un clavier est l'identifiant de sa langue (fr-FR 040C, fr-BE 080C).
    $lcid = "{0:X4}" -f [Globalization.CultureInfo]::GetCultureInfo($tag).LCID
    $tips = @("${lcid}:$($BELGE.Split(':')[1])", "${lcid}:$($BEPO.Split(':')[1])")
    $nos = { param($t) $t -like "*:0000080C" -or $t -like "*:0002040C" }

    $cible = $list | Where-Object { $_.LanguageTag -eq $tag } | Select-Object -First 1
    $autres = @($list | Where-Object { $_.LanguageTag -ne $tag })
    $doublons = @($autres | Where-Object { @($_.InputMethodTips | Where-Object { & $nos $_ }).Count })
    if ($cible -and ($cible.InputMethodTips -join ",") -eq ($tips -join ",") -and -not $doublons) { return "skip" }

    $nouvelle = New-WinUserLanguageList $tag
    $nouvelle[0].InputMethodTips.Clear()
    foreach ($t in $tips) { $nouvelle[0].InputMethodTips.Add($t) }
    foreach ($lang in $autres) {
        $garde = @($lang.InputMethodTips | Where-Object { -not (& $nos $_) })
        if (-not $garde) { continue }
        $nouvelle.Add($lang.LanguageTag)
        $l = $nouvelle[$nouvelle.Count - 1]
        $l.InputMethodTips.Clear()
        foreach ($t in $garde) { $l.InputMethodTips.Add($t) }
    }
    Set-WinUserLanguageList $nouvelle -Force -WarningAction SilentlyContinue
}

# Cache de la barre de langue : les langues retirées (tchèque, anglais…) y
# restent et réapparaissent dans la liste de la barre des tâches. On ne garde
# que celles de la liste actuelle.
Step "cache de la barre de langue" {
    $gardees = Get-WinUserLanguageList | ForEach-Object {
        "0x{0:x8}" -f [Globalization.CultureInfo]::GetCultureInfo($_.LanguageTag).LCID
    }
    $cache = "HKCU:\Software\Microsoft\CTF\SortOrder\AssemblyItem"
    $vieux = @(Get-ChildItem $cache -ErrorAction SilentlyContinue |
        Where-Object { $gardees -notcontains $_.PSChildName.ToLower() })
    if (-not $vieux) { return "skip" }
    $vieux | Remove-Item -Recurse -Force
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

    # Démarrage : tâche planifiée plutôt qu'un raccourci dans Démarrage. À
    # l'ouverture de session, le fichier peut être brièvement illisible (analyse
    # antivirus) : AutoHotkey affichait alors « Script file not found » et
    # restait bloqué. Ici : 10 s de délai, et /ErrorStdOut fait quitter
    # AutoHotkey en échec (sans boîte) pour que la tâche le relance.
    Remove-Item $startup -Force -ErrorAction SilentlyContinue
    $user = "$env:USERDOMAIN\$env:USERNAME"
    $action = New-ScheduledTaskAction -Execute $exe -Argument "/ErrorStdOut `"$script`"" -WorkingDirectory $dest
    $trigger = New-ScheduledTaskTrigger -AtLogOn -User $user
    $trigger.Delay = "PT10S"
    $settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries `
        -ExecutionTimeLimit ([TimeSpan]::Zero) -RestartCount 3 -RestartInterval (New-TimeSpan -Minutes 1) `
        -MultipleInstances IgnoreNew
    $principal = New-ScheduledTaskPrincipal -UserId $user -LogonType Interactive -RunLevel Limited
    Register-ScheduledTask -TaskName $task -TaskPath "\" -Action $action -Trigger $trigger `
        -Settings $settings -Principal $principal -Force `
        -Description "BÉPO : correctifs pour taper comme sous Linux (dotfiles/windows/clavier)" | Out-Null

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
