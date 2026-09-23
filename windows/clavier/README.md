# Clavier ThinkPad : AZERTY belge, et BÉPO hybride par-dessus

## En une commande

Ouvre **PowerShell** (menu Démarrer → « PowerShell », pas besoin
d'administrateur) et colle :

```powershell
irm https://raw.githubusercontent.com/adrnbttr/dotfiles/master/windows/clavier/get.ps1 | iex
```

Depuis un terminal **WSL**, la même chose :

```bash
powershell.exe -NoProfile -c "irm https://raw.githubusercontent.com/adrnbttr/dotfiles/master/windows/clavier/get.ps1 | iex"
```

La commande fait tout : disposition Windows en *Français (Belgique)*,
installation d'**AutoHotkey v2** (winget, ou téléchargement direct s'il manque),
copie du script, lancement immédiat et démarrage automatique à l'ouverture de
session. Elle est réexécutable sans risque.

| Raccourci | Effet |
|---|---|
| `Ctrl+Alt+Shift+B` | active / désactive le BÉPO (retour à l'AZERTY belge) |
| `Ctrl+Alt+Shift+Q` | quitte le script |

Pour tout retirer : `& "$env:TEMP\bepo-belge-setup\desinstaller.ps1"`.

## Le diagnostic

Le clavier du ThinkPad T14 est un **AZERTY belge (fr-BE)**, pas un AZERTY
français. Il n'a pas été bricolé : c'est une machine du marché belge. Les
touches imprimées le prouvent :

| Touche | Ce clavier (belge) | AZERTY français |
|---|---|---|
| à gauche du `1` | `³ ²` | `²` |
| `2` | `é 2 @` | `é 2 ~` |
| `6` | `§ 6 ^` | `- 6 \|` |
| `8` | `! 8` | `_ 8` |
| dernière du haut | `- _` | `= +` |
| à droite de `P` | `¨ ^ [` puis `* $ ]` | `^ ¨` puis `$ £` |
| rangée du bas | `?,` `;.` `/:` `+=~` | `,?` `;.` `:/` `!§` |

En sélectionnant « Français (France) » dans Windows, tous les caractères
spéciaux tombent à côté — d'où `AltGr+2` qui ne donne pas `@`.

**Correctif immédiat, sans rien installer :** Paramètres → Heure et langue →
Langue et région → Français → Options → ajouter le clavier **Belge (période)**
/ « Français (Belgique) », puis retirer le clavier français. `installer.ps1`
le fait aussi tout seul.

## Le BÉPO hybride

Une fois la disposition belge en place, `bepo-belge.ahk` met **les lettres en
BÉPO** et laisse **les caractères spéciaux là où ils sont imprimés**. Tu tapes
les lettres les yeux fermés, et quand tu cherches un symbole, tu le lis sur la
touche comme aujourd'hui.

Il y a une contrainte physique : le BÉPO compte 35 lettres pour 26 touches
marquées A-Z. Neuf lettres (`z w m ç ê q g h f`) débordent donc sur les touches
à symboles qui entourent le bloc — `^` `$` `ù` `µ` `<` `?,` `;.` `:/` `+=`.
Leurs symboles ne sont pas perdus pour autant : **ils reviennent sur leur propre
touche, avec `AltGr` ou `AltGr+Shift`.**

### Ce que tapent les touches

```
Rangée du haut (touches A Z E R T Y U I O P ^ $) :
   b  é  p  o  è  ^  v  d  l  j  z  w          Shift : B É P O È !  V D L J Z W

Rangée de repos (touches Q S D F G H J K L M ù µ) :
   a  u  i  e  ,  c  t  s  r  n  m  ç          Shift : A U I E ;  C T S R N M Ç

Rangée du bas (touches < W X C V B N ? ; / +) :
   ê  à  y  x  .  k  '  q  g  h  f             Shift : Ê À Y X :  K ? Q G H F
```

- `é è à ç ê` s'obtiennent directement, sans la rangée du haut.
- `^` et `¨` sont des accents morts : `^` puis `a` → `â`, `¨` puis `e` → `ë`,
  suivis d'espace ils s'écrivent seuls.
- `,` `;` `.` `:` `?` `!` sont là où le BÉPO les met (touches `G` `V` `N` `Y`).
- Verr. Maj fonctionne sur les lettres remappées.

### Les symboles des touches recouvertes

Sur ces neuf touches, la règle est simple : **`AltGr` donne la légende de droite
(inchangée), `AltGr+Shift` rend la légende recouverte.**

| Touche imprimée | `AltGr` | `AltGr+Shift` |
|---|---|---|
| `^ ¨ [` | `[` | `¨` |
| `$ * ]` | `]` | `$` |
| `ù %` | `ù` | `%` |
| `µ £` | `` ` `` | `µ` |
| `< > \` | `<` | `>` |
| `? ,` | — | `?` |
| `; .` | — | `;` |
| `: /` | — | `/` |
| `= + ~` | `~` | `=` |

Deux légendes `AltGr` ont laissé la place (`´` et `\`) parce qu'elles existent
déjà ailleurs sur le clavier belge : `´` sur `AltGr+M`, `\` sur `AltGr+)`.

En prime, les symboles de programmation les plus fréquents sont aussi sur la
rangée des chiffres en `AltGr+Shift`, **à leur position BÉPO** — celle que tes
doigts connaissent déjà sous Linux :

| `AltGr+Shift+7` | `AltGr+Shift+9` | `AltGr+Shift+0` | `AltGr+Shift+)` | `AltGr+Shift+-` |
|---|---|---|---|---|
| `+` | `/` | `*` | `=` | `%` |

### Ce qui ne change pas

- Toute la rangée des chiffres : `& é " ' ( § è ! ç à ) -`, les chiffres sur
  Shift, et `AltGr` (`| @ # { [ { } \ ^`…).
- `AltGr+E` = `€`, `AltGr+2` = `@`, `AltGr+9` = `{`, `AltGr+0` = `}` :
  exactement ce qui est imprimé.
- **Les raccourcis restent aux positions AZERTY** : `Ctrl+C`, `Ctrl+V`,
  `Ctrl+Z` gardent leur place habituelle sous les doigts.

> Vérifié caractère par caractère contre la définition officielle du clavier
> belge : **aucun des 79 symboles imprimés n'est devenu injoignable.**

## Installation à la main (si tu as le dépôt en local)

```powershell
powershell -ExecutionPolicy Bypass -File .\installer.ps1
```

Même chose que la commande unique, sans le téléchargement. Le script règle la
disposition belge, installe AutoHotkey v2, copie le script dans
`%LOCALAPPDATA%\bepo-belge`, le lance et l'ajoute au démarrage de session.

Pour tout retirer : `powershell -ExecutionPolicy Bypass -File .\desinstaller.ps1`.
La disposition belge, elle, reste en place : c'est elle qui rend le clavier
cohérent avec ce qui est imprimé.

## Vérifier que tout fonctionne

### Sans rien taper : `test-clavier.ahk`

Le script `bepo-belge.ahk` doit tourner (icône dans la zone de notification) ;
lance ensuite le harnais :

```powershell
& "$env:ProgramFiles\AutoHotkey\v2\AutoHotkey64.exe" .\test-clavier.ahk
# si AutoHotkey est installé dans le profil utilisateur :
& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" .\test-clavier.ahk
```

Il appuie lui-même sur chaque touche **par code de scan**, dans sa propre zone
de texte, et compare ce qui en sort à l'attendu : 37 cas couvrant les 35
lettres, les majuscules, les accents morts, les symboles rendus sur `AltGr` /
`AltGr+Shift`, et ceux qui ne doivent pas bouger. Le récapitulatif s'affiche
dans la fenêtre et part dans `resultat-test.txt`, à côté du script. `Échap`
ferme.

C'est l'outil à relancer après chaque retouche du mapping.

### À la main

Ouvre le Bloc-notes et tape :

| Tu tapes | Attendu |
|---|---|
| les touches `A S D F` | `a u i e` |
| les touches `Q W E R` (rangée du haut) | `b é p o` |
| `AltGr+2`, `AltGr+9`, `AltGr+0`, `AltGr+E` | `@`, `{`, `}`, `€` |
| `^` puis `a` · `AltGr+Shift+^` puis `e` | `â` · `ë` |
| `Shift+G` puis `Shift+V` (BÉPO) | `;` puis `:` |
| `AltGr+Shift` sur les touches `=+~`, `:/`, `ù%` | `=`, `/`, `%` |
| `AltGr` puis `AltGr+Shift` sur la touche `<>\` | `<` puis `>` |
| `AltGr+Shift+7`, `+9`, `+0` | `+`, `/`, `*` |
| `Ctrl+Alt+Shift+B` puis les touches `A S D F` | `q s d f` (BÉPO désactivé) |

## Et si le BÉPO ne te convient pas

`Ctrl+Alt+Shift+B` suffit pour revenir à l'AZERTY belge le temps d'une tâche,
et `desinstaller.ps1` retire tout. Si au contraire le BÉPO te plaît et que tu
veux aller au bout, l'étape suivante est une **vraie disposition Windows**
(fichier `.klc` compilé avec Microsoft Keyboard Layout Creator) : elle
fonctionne aussi dans les applications lancées en administrateur et sur
l'écran de connexion, sans script en arrière-plan. On la fera à partir de ce
même plan si tu valides l'hybride.

## Lien avec le dotfiles

WezTerm choisit les lettres du saut entre splits selon la disposition. Sous
Windows il suppose AZERTY ; avec le BÉPO hybride, écris `bepo` dans
`~/.config/wezterm/keyboard` (côté WSL) pour retrouver `a u i e t s r n`.
