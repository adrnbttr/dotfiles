---
# Frontmatter d'étape : OPTIONNEL en entier. Il ne sert qu'à surcharger le manifeste pour cette étape.
# Champs connus (tout autre champ est refusé) : title, agent, model, stale_after, max_duration.

# OPTIONNEL. Titre lisible, chaîne non vide. Absent : le slug du fichier sert de repère.
# Le même texte sert dans le message du commit de sauvegarde.
title: "Étape type (à remplacer)"

# OPTIONNEL. `claude` ou `opencode`. Défaut : l'agent du manifeste.
# agent: opencode

# OPTIONNEL. Modèle, chaîne non vide, sans autre contrôle. Défaut : celui de l'agent. Il se met ici,
# étape par étape : le manifeste n'a pas de champ `model`.
# model: mon-fournisseur/mon-modele

# OPTIONNEL. Surcharge de `stale_after` (entier + s|m|h, un seul groupe). Défaut : manifeste.
# stale_after: 45m

# OPTIONNEL. Surcharge de `max_duration` (même grammaire). Défaut : manifeste, sinon aucune.
# max_duration: 90m
---

# Étape 01 : <titre de l'étape>

<!-- Ce fichier est un brief autonome : la session qui l'exécute n'a ni la conversation du jour ni la
mémoire des autres étapes, seulement `00-plan.md`, ce fichier et le dépôt. Tout ce dont elle a besoin
doit y être, ou être indiqué par un chemin précis. Remplacer chaque <...> ; supprimer les commentaires. -->

## Objectif

<Une à trois phrases : le résultat attendu, observable. Exemple : « `mon-projet export --format csv`
écrit un CSV valide sur la sortie standard pour un rapport donné. »>

## Contexte à lire d'abord

- `00-plan.md` (objectif, contraintes communes, définition de « fini »).
- <chemins précis du code existant à lire, avec ce qu'on y cherche>

## Fichiers

À créer ou modifier :

- `<chemin/relatif/fichier-1>` : <quoi>
- `<chemin/relatif/test-1>` : <quoi>

Ne rien modifier en dehors de cette liste sans raison écrite dans le résumé final.

## Contraintes

- <règle technique propre à l'étape : API à respecter, compatibilité, dépendances autorisées>
- Rester dans le worktree courant.
- Jamais `git push`, jamais `gh`.

## Hors périmètre

- <ce qui est tentant mais appartient à une autre étape ou à personne>
- Pas de refactor, pas de renommage, pas de montée de version : la version est traitée à l'étape de
  livraison.

## Test

Commande exacte, à lancer depuis la racine du worktree et qui doit réussir (code de sortie 0) :

```
<commande de test exacte, par ex. cargo test -p mon-crate ou npm test -- export>
```

## Critère de fin

L'étape est finie quand tout est vrai :

- la commande de test ci-dessus réussit ;
- <critère vérifiable 2, par ex. « `git diff --stat` ne montre que les fichiers listés »> ;
- après le commit, `git status --short` ne montre aucun fichier suivi modifié ni rien d'indexé ; tout fichier non suivi inattendu est traité comme dit dans « Commit de sauvegarde » (il bloquerait la livraison, ADR 0023 D6 (f)).

## Commit de sauvegarde (obligatoire)

Avant de déclarer la fin, commiter tout le travail de l'étape, avec exactement ce format de message :

```
git add <fichiers modifiés ou créés par l'étape, nommés explicitement>
git status --short
git commit -m "wip(étape 01): <titre de l'étape>"
```

Ne jamais utiliser `git add -A`, `git add .` ni `git commit -a` : ils embarqueraient un fichier non
suivi (fichier local, secret, artefact non ignoré), et le garde-fou de deck ne regarde pas les fichiers
non suivis. Après le `git add`, `git status --short` ne doit montrer ni modification suivie non
indexée ni fichier non suivi inattendu. Un fichier non suivi et non ignoré bloquerait la livraison
(ADR 0023 D6 (f)) : s'il est produit par l'étape, le supprimer ; s'il est légitime, l'ajouter au
`.gitignore` (commité, avec la raison dans le message de commit) ; sinon `deck done --status failed`
avec le motif. Ne jamais l'ajouter au commit de l'étape.

`NN` est le numéro de ce fichier sur deux chiffres. Il faut au moins un commit non vide dans l'étape
et un arbre propre, sinon deck refuse `deck done`. Ne pas pousser.

## Fin

Succès :

```
deck done --status ok --summary "<ce qui a été fait, en une ou deux phrases>"
```

Impossible de finir (test qui échoue après essais raisonnables, information manquante, brief
contradictoire, décision à prendre) : ne pas inventer, ne pas contourner, et ne pas poser de question
(personne ne répond pendant la nuit : l'étape resterait en `waiting`). Commiter si utile pour garder la
trace, puis

```
deck done --status failed --summary "<motif précis : quoi, où, ce qui a été essayé>"
```

Ne pas s'arrêter sans avoir lancé l'une des deux commandes.
