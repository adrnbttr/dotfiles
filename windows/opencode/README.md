# OpenCode Desktop (Windows) — config

Config de l'app **OpenCode Desktop (V2)** sous Windows. Elle vit dans
`%USERPROFILE%\.config\opencode\` :

- `opencode.json` — modèle par défaut, MCP Playwright, redimensionnement d'images
- `agents/*.md` — subagents `visual`, `implementer`, `chore` (Markdown V2)

## Modèles (tout via l'abonnement OpenCode Zen / Console)

| Rôle | Modèle |
| --- | --- |
| Défaut (chat desktop) | `opencode/step-5-preview-free` (gratuit) |
| Implémentation | `opencode/glm-5.3-flash` |
| Visual | `opencode/space-bunny-free` |
| Chore | `opencode/ling-3.0-flash-fin-free` |

> Le desktop sert au chat/问答 ; le code se fait via le CLI OpenCode dans le WSL
> (paquet `opencode-state/`).

## Installation

Copier les fichiers dans `%USERPROFILE%\.config\opencode\`, ou :

```powershell
irm https://raw.githubusercontent.com/adrnbttr/dotfiles/master/windows/opencode/get.ps1 | iex
```

Puis connecter le fournisseur **OpenCode** (Settings → Providers) et redémarrer l'app.
