# Clavier ThinkPad : AZERTY belge, et BÉPO hybride par-dessus

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

Une fois la disposition belge en place, `bepo-belge.ahk` remplace **uniquement
les trois rangées de lettres** par le BÉPO. Tout le reste ne bouge pas :
chiffres, `AltGr` (`@ # { } [ ] | € ~`…), ponctuation de droite, touches de
fonction, Ctrl/Alt et tous les raccourcis restent ceux imprimés sur les touches.

Autrement dit : tu apprends les lettres en BÉPO, et quand tu cherches un
caractère spécial, tu le lis sur le clavier comme aujourd'hui.

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
- `^` est un accent mort : `^` puis `a` donne `â` ; `^` puis espace donne `^`.
- `;` `:` `?` `!` sont sur Shift des touches `,` `.` `'` `^`, comme en BÉPO.
- Verr. Maj fonctionne sur les lettres remappées.

### Ce qui ne change pas

- `AltGr+2` = `@`, `AltGr+9` = `{`, `AltGr+0` = `}`, `AltGr+6` = `^`,
  `AltGr+1` = `|`, `AltGr+E` = `€` : exactement ce qui est imprimé.
- La rangée des chiffres (`&é"'(§è!çà`), les touches `¨^[`, `*$]`, `%ù`, `£µ`.
- **Les raccourcis restent aux positions AZERTY** : `Ctrl+C`, `Ctrl+V`,
  `Ctrl+Z` gardent leur place habituelle sous les doigts.

## Installation

```powershell
powershell -ExecutionPolicy Bypass -File .\installer.ps1
```

Le script règle la disposition belge, installe AutoHotkey v2 (winget), copie
le script dans `%LOCALAPPDATA%\bepo-belge`, le lance et l'ajoute au démarrage
de session. Il est réexécutable sans risque.

| Raccourci | Effet |
|---|---|
| `Ctrl+Alt+Shift+B` | active / désactive le BÉPO (retour à l'AZERTY belge) |
| `Ctrl+Alt+Shift+Q` | quitte le script |

Pour tout retirer : `powershell -ExecutionPolicy Bypass -File .\desinstaller.ps1`.
La disposition belge, elle, reste en place : c'est elle qui rend le clavier
cohérent avec ce qui est imprimé.

## Vérifier que tout fonctionne

Ouvre le Bloc-notes et tape :

| Tu tapes | Attendu |
|---|---|
| les touches `A S D F` | `a u i e` |
| les touches `Q W E R` (rangée du haut) | `b é p o` |
| `AltGr+2`, `AltGr+9`, `AltGr+0` | `@`, `{`, `}` |
| `^` puis `a` | `â` |
| `Shift+,` puis `Shift+.` | `;` puis `:` |
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
