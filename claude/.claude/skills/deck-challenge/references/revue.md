# Modèle de `revue.md`

Écrit par `deck-challenge` dans le dossier de la campagne jugée (`.deck/<id>/revue.md`, champ `dir` de
`deck status --json`). Ce dossier ne contient aucun autre fichier écrit par le challenger. Le nom ne commence
pas par un chiffre : deck ne le lit pas comme une étape. Court, factuel, chaque constat avec chemin et ligne.

```markdown
# Revue de <id>

- Jugée le : <date> par <agent qui challenge> (campagne exécutée par <agent du manifeste>)
- Commit : <sha court> sur <base>, tag <vX.Y.Z> (cohérent avec le niveau de la livraison : oui/non, pourquoi)
- Verdict : <livrée conforme | livrée avec corrections | livrée avec bloquants | abandonnée>

## Tests rejoués

| Commande | Code | Lignes utiles |
|---|---|---|
| `<commande exacte>` | 0 | <ex. « 42 passed »> |

Non lancé : <ce qui n'a pas pu l'être, et pourquoi>

## Critères de la feature

| Critère | Coché par la livraison | Vérifié | Note |
|---|---|---|---|
| <critère> | oui | oui | <observation, commande> |

## Constats

### Bloquants
- `<chemin>:<ligne>` : <attendu> / <observé>. Preuve : `<commande>`.

### Corrections (reprises en étape 01 de <id suivant>)
- `<chemin>:<ligne>` : <attendu> / <observé>.

### Remarques (aucune action)
- <observation>

## Étapes

| NN | État | Résumé de l'agent | Jugement |
|---|---|---|---|
| 01 | done | <summary> | <conforme / écart> |

## Replanification

- Campagne réécrite : <id suivant> : <étapes ajoutées, étapes reportées, durée estimée>.
- Glissé vers <id d'après> : <étapes>.
- Campagne créée : <id> (correction, niveau correctif) ou « aucune ».
```
