# Installe la config OpenCode Desktop (V2) dans %USERPROFILE%\.config\opencode
$ErrorActionPreference = 'Stop'
$base = 'https://raw.githubusercontent.com/adrnbttr/dotfiles/master/windows/opencode'
$dest = Join-Path $env:USERPROFILE '.config\opencode'
$agentsDir = Join-Path $dest 'agents'
New-Item -ItemType Directory -Force -Path $agentsDir | Out-Null

Invoke-WebRequest "$base/opencode.json" -OutFile (Join-Path $dest 'opencode.json')
foreach ($a in @('implementer', 'chore')) {
  Invoke-WebRequest "$base/agents/$a.md" -OutFile (Join-Path $agentsDir "$a.md")
}

Write-Host "Config OpenCode Desktop installee dans $dest"
Write-Host "Connecte le fournisseur OpenCode (Settings > Providers), puis redemarre l'app."
