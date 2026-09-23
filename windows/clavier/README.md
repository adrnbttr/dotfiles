# Clavier ThinkPad : Belge + BÉPO

Deux dispositions, on passe de l'une à l'autre avec **`Win+Espace`** :

| Disposition | Pour quoi |
|---|---|
| **Belge** (défaut) | ce qui est imprimé sur les touches ; pour quelqu'un d'autre, ou pour chercher un symbole des yeux |
| **BÉPO** | la BÉPO de Windows, alignée sur la BÉPO Linux (`fr bepo`) : les mêmes réflexes que sur le TypeMatrix |

## En une commande

Ouvre **PowerShell** (pas besoin d'administrateur) et colle :

```powershell
irm https://raw.githubusercontent.com/adrnbttr/dotfiles/master/windows/clavier/get.ps1 | iex
```

Depuis WSL :

```bash
powershell.exe -NoProfile -c "irm https://raw.githubusercontent.com/adrnbttr/dotfiles/master/windows/clavier/get.ps1 | iex"
```

La commande ajoute la BÉPO à côté du Belge, retire l'ancien « BÉPO hybride »
s'il était installé, installe AutoHotkey v2 et lance les correctifs (voir
plus bas) au démarrage de session. Réexécutable sans risque.
Retrait : `desinstaller.ps1` (le Belge reste).

## Pourquoi la BÉPO native, et plus l'hybride

La première version gardait les symboles belges imprimés et ne remappait que
les lettres. À l'usage, ce n'est pas la BÉPO : la rangée des chiffres restait
`& é " ' ( § è ! ç à`, la couche AltGr était belge, et les raccourcis
`Ctrl+lettre` restaient aux positions AZERTY. Tous les réflexes du TypeMatrix
tombaient à côté.

Windows (10 1903 et plus) fournit **« Français (Standard, BÉPO) »**, une
vraie disposition : pas de script pour les lettres, elle marche partout (y
compris dans les applications administrateur et à l'écran de connexion), les
accents morts sont natifs, et **`Ctrl+lettre` suit la lettre BÉPO**, comme
sous Linux (`Ctrl+C` sur la touche `c` BÉPO, `<C-w>`, `<C-d>`… dans nvim).

Comparée touche par touche à `fr bepo` (xkb) : lettres, chiffres, symboles de
la rangée du haut et symboles AltGr de programmation sont **identiques**.

## Les écarts avec Linux, et les correctifs

Windows suit la norme AFNOR ; Linux, par défaut, la BÉPO historique.
`bepo-correctifs.ahk` (actif **uniquement** quand la fenêtre est en BÉPO)
aligne ce qui gêne pour coder :

| Touche | Linux | Windows seul | avec les correctifs |
|---|---|---|---|
| à droite du `k` | `'` | `’` | `'` |
| `AltGr+,` | `’` | `'` | `’` |
| `AltGr+Espace` | `_` | `_`, mais volé par les raccourcis globaux `Ctrl+Alt+Espace` (Claude Desktop…) | `_` |

Pour `AltGr+Espace` : sous Windows, AltGr vaut `Ctrl+Alt`. Le correctif
intercepte `AltGr+Espace` avant ces raccourcis ; `Ctrl` gauche + `Alt` gauche
+ `Espace` reste disponible pour eux. Il relâche aussi AltGr le temps d'écrire,
sinon WezTerm lit `Ctrl+Alt+_` comme une combinaison et n'écrit rien.

Écarts restants, sans incidence pour le code (niveau AltGr des lettres) :
`AltGr+d` `ð`→`∞`, `AltGr+t` `þ`→`ᵉ`, `AltGr+c` `©`→cédille morte,
`AltGr+r` `®`→brève morte, `AltGr+z` `ə`→`-` mort, `AltGr+h` `†`→point souscrit.
Sur le niveau AltGr+Shift, `≤ ≥` deviennent `⩽ ⩾`.

## Vérifier

`test-clavier.ahk` passe sa propre fenêtre en BÉPO, tape chaque touche par
code de scan et compare à la BÉPO Linux : 25 cas (lettres, chiffres,
symboles AltGr, accents morts, correctifs, positions des raccourcis Ctrl).
Les correctifs doivent tourner.

```powershell
& "$env:LOCALAPPDATA\Programs\AutoHotkey\v2\AutoHotkey64.exe" .\test-clavier.ahk
```

Rapport dans la fenêtre et dans `resultat-test.txt`. `Échap` ferme.

## Le clavier est belge, pas français

Le clavier du ThinkPad T14 est un **AZERTY belge (fr-BE)** : `³ ²` à gauche
du `1`, `é 2 @`, `§ 6 ^`, `¨ ^ [` et `* $ ]` à droite du `P`. En
« Français (France) », tous les symboles tombent à côté (`AltGr+2` ne donne
pas `@`). D'où le clavier **Belge** comme disposition par défaut.

## Lien avec le dotfiles

WezTerm affiche des lettres pour sauter d'un split à l'autre (`Ctrl+Alt+Shift+a`
sous Windows). Pour qu'elles tombent sur la rangée de repos BÉPO
(`a u i e t s r n`), écrire `bepo` dans `%USERPROFILE%\.config\wezterm\keyboard`
(l'installeur le fait s'il n'existe pas).
