# OpenCode Desktop (Windows) — config

Config de l'app **OpenCode Desktop (V2)** sous Windows. Elle vit dans
`%USERPROFILE%\.config\opencode\` :

- `opencode.json` — modèle par défaut, small_model, effort de raisonnement, redimensionnement d'images
- `agents/*.md` — subagents `implementer`, `chore` (Markdown V2)

## Modèles (tout via l'abonnement OpenCode Zen)

| Rôle | Modèle | Prix $/M |
| --- | --- | --- |
| Défaut (chat desktop) | `opencode/claude-sonnet-5-5#high` | 2 / 10 |
| Titres / résumés | `opencode/deepseek-v4.1-flash` | 0.14 / 0.28 |
| Implémentation | `opencode/glm-5.3-flash` | 0.15 / 0.5 |
| Chore | `opencode/glm-5.3-flash` | 0.15 / 0.5 |

> Le desktop sert au chat ; le code se fait via le CLI OpenCode dans le WSL
> (paquet `opencode-state/`), qui a la config complète (agents visual,
> explore sur haiku, workflow plan/lots, dictée).

## Pourquoi pas de MCP Playwright ici ?

Le MCP `playwright` se lance via `npx`, et **node/npm n'est pas installé côté
Windows** : le serveur ne démarrait jamais (« Connection closed » / spawn
NotFound). Playwright reste disponible côté WSL via le paquet `opencode-state/`
(nvm + navigateur). Si tu installes node sur Windows un jour, tu pourras
rajouter le bloc `mcp` identique à celui du WSL.

## Installation

Copier les fichiers dans `%USERPROFILE%\.config\opencode\`, ou :

```powershell
irm https://raw.githubusercontent.com/adrnbttr/dotfiles/master/windows/opencode/get.ps1 | iex
```

Puis connecter le fournisseur **OpenCode** (Settings → Providers) et redémarrer l'app.
