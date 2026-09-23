# Amorçage en une commande sous Windows (PowerShell) :
#
#   irm https://raw.githubusercontent.com/adrnbttr/dotfiles/master/script/get.ps1 | iex
#
# Fait, dans l'ordre :
#   1. vérifie winget et les droits ;
#   2. installe WezTerm et la police MesloLGS NF ;
#   3. installe WSL + Ubuntu s'ils manquent (redémarrage éventuel) ;
#   4. lance l'installation Linux DANS WSL (script/get) ;
#   5. pointe WEZTERM_CONFIG_FILE sur la config du dépôt cloné dans WSL.
#
# Réexécutable sans risque : chaque étape est ignorée si elle est déjà faite.

$ErrorActionPreference = "Stop"
$ProgressPreference = "SilentlyContinue"

$Repo = if ($env:DOTFILES_REPO) { $env:DOTFILES_REPO } else { "https://github.com/adrnbttr/dotfiles.git" }
$Distro = if ($env:DOTFILES_WSL_DISTRO) { $env:DOTFILES_WSL_DISTRO } else { "Ubuntu" }
$steps = @()
$index = 0
$total = 5

function Step($label, $block) {
    $script:index++
    $bar = ("█" * [math]::Floor($script:index * 16 / $total)).PadRight(16, "·")
    Write-Host ("  [{0}] {1}" -f $bar, $label.PadRight(28)) -NoNewline
    try {
        $result = & $block
        if ($result -eq "skip") {
            Write-Host " ✓ déjà là" -ForegroundColor Green
            $script:steps += @{ name = $label; state = "déjà là" }
        } else {
            Write-Host " ✓" -ForegroundColor Green
            $script:steps += @{ name = $label; state = "installé" }
        }
    } catch {
        Write-Host " ✗ échec" -ForegroundColor Red
        Write-Host ("      " + $_.Exception.Message) -ForegroundColor DarkGray
        $script:steps += @{ name = $label; state = "échec" }
    }
}

Write-Host ""
Write-Host "❯ dotfiles · installation Windows" -ForegroundColor White
Write-Host ""

# --- Vérifications -------------------------------------------------------------
Write-Host "vérifications"
if (-not (Get-Command winget.exe -ErrorAction SilentlyContinue)) {
    Write-Host "  ✗ winget introuvable : installe « App Installer » depuis le Microsoft Store" -ForegroundColor Red
    return
}
Write-Host "  ✓ winget"
$admin = ([Security.Principal.WindowsPrincipal] [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
if ($admin) { Write-Host "  ✓ droits administrateur (installation de WSL possible)" }
else { Write-Host "  ! sans droits administrateur : WSL devra être installé à part" -ForegroundColor Yellow }
try {
    Invoke-WebRequest -UseBasicParsing -Uri "https://github.com" -TimeoutSec 8 | Out-Null
    Write-Host "  ✓ accès réseau (github.com)"
} catch {
    Write-Host "  ✗ pas d'accès à github.com" -ForegroundColor Red
    return
}
Write-Host ""

# --- 1. WezTerm ----------------------------------------------------------------
Step "WezTerm" {
    if (Get-Command wezterm.exe -ErrorAction SilentlyContinue) { return "skip" }
    winget install --id wez.wezterm --exact --silent --accept-package-agreements --accept-source-agreements | Out-Null
}

# --- 2. Police MesloLGS NF (par utilisateur, sans admin) -----------------------
Step "police MesloLGS NF" {
    $fontDir = Join-Path $env:LOCALAPPDATA "Microsoft\Windows\Fonts"
    $fontReg = "HKCU:\Software\Microsoft\Windows NT\CurrentVersion\Fonts"
    New-Item -ItemType Directory -Force -Path $fontDir | Out-Null
    # Surtout pas de New-Item -Force sur la clé : elle serait recréée vide.
    if (-not (Test-Path $fontReg)) { New-Item -Path $fontReg | Out-Null }
    $base = "https://github.com/romkatv/powerlevel10k-media/raw/master"
    $installed = 0
    foreach ($style in @("Regular", "Bold", "Italic", "Bold Italic")) {
        $file = "MesloLGS NF $style.ttf"
        $dest = Join-Path $fontDir $file
        if (Test-Path $dest) { continue }
        Invoke-WebRequest -UseBasicParsing -Uri "$base/$([uri]::EscapeDataString($file))" -OutFile $dest
        New-ItemProperty -Force -Path $fontReg -Name "MesloLGS NF $style (TrueType)" -Value $dest | Out-Null
        $installed++
    }
    if ($installed -eq 0) { return "skip" }
}

# --- 3. WSL + distribution -----------------------------------------------------
Step "WSL + $Distro" {
    if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
        if (-not $admin) { throw 'WSL absent : relance PowerShell en administrateur, ou installe-le avec « wsl --install »' }
        wsl.exe --install --no-launch | Out-Null
        throw 'WSL vient d''être activé : redémarre Windows, puis relance cette commande'
    }
    $installed = (wsl.exe --list --quiet) -replace "`0", "" | Where-Object { $_ -ne "" }
    if ($installed -contains $Distro) { return "skip" }
    if (-not $admin) { throw "$Distro absente : relance en administrateur, ou « wsl --install -d $Distro »" }
    wsl.exe --install -d $Distro --no-launch | Out-Null
    throw "$Distro vient d'être installée : ouvre-la une fois pour créer ton utilisateur, puis relance cette commande"
}

# --- 4. Installation côté WSL --------------------------------------------------
Step "dotfiles dans WSL" {
    $user = (wsl.exe -d $Distro -- whoami).Trim()
    if (-not $user) { throw "$Distro pas encore configurée : ouvre-la une fois pour créer ton utilisateur" }
    Write-Host ""
    Write-Host "      (l'installation Linux prend la main dans WSL)" -ForegroundColor DarkGray
    wsl.exe -d $Distro -- bash -lc "curl -fsSL https://raw.githubusercontent.com/adrnbttr/dotfiles/master/script/get | bash"
    if ($LASTEXITCODE -ne 0) { throw "l'installation dans WSL a échoué (voir ci-dessus)" }
}

# --- 5. Config WezTerm ---------------------------------------------------------
Step "config WezTerm" {
    $user = (wsl.exe -d $Distro -- whoami).Trim()
    $path = "\\wsl$\$Distro\home\$user\Documents\github\perso\dotfiles\config\.config\wezterm\wezterm.lua"
    if (-not (Test-Path $path)) { throw "config introuvable : $path" }
    if ([Environment]::GetEnvironmentVariable("WEZTERM_CONFIG_FILE", "User") -eq $path) { return "skip" }
    [Environment]::SetEnvironmentVariable("WEZTERM_CONFIG_FILE", $path, "User")
}

# --- Résumé --------------------------------------------------------------------
$failed = @($steps | Where-Object { $_.state -eq "échec" })
Write-Host ""
Write-Host "─────────────────────────────────────────────" -ForegroundColor DarkGray
Write-Host ("installation Windows : {0} installées · {1} déjà là · {2} en échec" -f
    @($steps | Where-Object { $_.state -eq "installé" }).Count,
    @($steps | Where-Object { $_.state -eq "déjà là" }).Count,
    $failed.Count)
if ($failed.Count -gt 0) {
    Write-Host ("Étapes en échec : " + ($failed.name -join ", ")) -ForegroundColor Red
    Write-Host "Corrige le point signalé puis relance la même commande."
} else {
    Write-Host ""
    Write-Host "Prochaine étape : ouvre WezTerm (menu Démarrer)." -ForegroundColor White
    Write-Host "  · F1 : aide-mémoire · ctrl+shift+s : workspaces"
}
