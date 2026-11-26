# OpenCode Desktop (Windows) — config

Config de l'app **OpenCode Desktop (V2)** sous Windows. Elle vit dans
`%USERPROFILE%\.config\opencode\` :

- `opencode.json` — modèle par défaut, small_model, effort de raisonnement, redimensionnement d'images
- `agents/*.md` — subagents `implementer`, `chore` (Markdown V2)

## Modèles (tout via le forfait Z.ai GLM Coding Plan)

| Rôle | Modèle | Prix |
| --- | --- | --- |
| Défaut (chat desktop) | `zai-coding-plan/glm-5.4#high` | forfait |
| Titres / résumés | `zai-coding-plan/glm-5.3-flash` | forfait |
| Implémentation | `zai-coding-plan/glm-5.3-flash` | forfait |
| Chore | `zai-coding-plan/glm-5.3-flash` | forfait |

Le quota de 5 h du forfait est partagé avec le WSL : une grosse session côté
CLI entame aussi le quota du desktop, et inversement.

> Le desktop sert au chat ; le code se fait via le CLI OpenCode dans le WSL
> (paquet `opencode-state/`), qui a la config complète (agents visual,
> explore sur glm-5.3-flash, workflow plan/lots, dictée).

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

Puis connecter le fournisseur **Z.ai Coding Plan** (Settings → Providers, ou
`opencode auth login`) avec la clé Z.ai (jamais commitée) et redémarrer l'app.
