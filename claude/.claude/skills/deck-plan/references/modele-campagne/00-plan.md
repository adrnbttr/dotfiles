---
# ATTENTION : tant que le jalon J7 (adaptateur OpenCode) n'est pas fusionné, `deck run` échoue avec
# `agent: opencode`. En attendant, mettre `agent: claude` ci-dessous.
#
# Manifeste de campagne deck (ADR 0004, 0011, 0023). Les commentaires `#` sont acceptés par le
# lecteur YAML (serde-saphyr) : ils peuvent rester dans le fichier réel. Un `#` de commentaire doit
# être précédé d'une espace. Tout champ inconnu est refusé (faute de frappe = erreur de `deck check`).
# Les noms de champs et les valeurs ci-dessous sont ceux que lit `crates/deck-domain/src/manifest.rs`.

# OBLIGATOIRE. Version du format. Seule la valeur 1 est connue.
deck: 1

# OBLIGATOIRE. Identifiant de la campagne : minuscules, chiffres et tirets (`^[a-z0-9]+(-[a-z0-9]+)*$`),
# 64 caractères au plus. Unique parmi les campagnes non terminées du même dépôt.
# Doit être le nom du dossier `.deck/<id>/`. Campagne issue d'une feature : `<feature>-<NN>`
# (ex. `export-csv-02`) ; sinon slug libre. A REMPLACER.
id: exemple-campagne

# OBLIGATOIRE. Dépôt cible : chaîne brute, `~` accepté (deck le développe et canonise le chemin).
# `deck check` vérifie que c'est un dépôt git. VALEUR D'EXEMPLE, A REMPLACER par le dépôt réel.
repo: ~/Documents/github/perso/mon-projet

# OBLIGATOIRE. Branche de départ. Elle doit exister. En `delivery: local`, c'est aussi la branche que
# deck avance à la fin (ADR 0023 D6) : le checkout principal doit alors être dessus, et `base` doit
# être un nom de branche locale (pas `refs/…`, pas `origin/…`).
base: main

# OPTIONNEL. Branche de campagne. Défaut : `deck/<id>`. Elle ne doit pas exister avant `deck run`.
# branch: deck/exemple-campagne

# OPTIONNEL. Remote. Défaut : `origin`. Inutilisé en `delivery: local` (rien n'est jamais poussé).
# remote: origin

# OBLIGATOIRE. Agent d'exécution : `claude` ou `opencode`. Une étape peut le surcharger.
# Boucle jour/nuit : `opencode` (cible). Tant que J7 n'est pas fusionné : `claude`.
agent: opencode

# OBLIGATOIRE. Scénario : `dev` ou `factory`. Enregistré, sans effet pour l'instant.
scenario: dev

# OBLIGATOIRE. Délai sans événement, en `running`, avant de signaler `stale`. Durée : entier en
# chiffres puis `s`, `m` ou `h`, UN SEUL groupe, strictement positif (`90m`, pas `1h30m`).
stale_after: 30m

# OPTIONNEL. Durée d'une tentative avant de signaler `overdue` (même grammaire). Défaut : aucune.
max_duration: 2h

# OPTIONNEL. Mode de livraison : `pr` (défaut) ou `local` (ADR 0023 D2).
# - `local` : l'agent regroupe et tague dans sa branche (étape 02), deck avance `base` en avance
#   rapide, puis retire branche et worktree. Rien n'est poussé. La section `pr` est INTERDITE.
# - `pr` : push et PR en brouillon sur geste d'Adrien ; la section `pr.title` devient OBLIGATOIRE.
delivery: local

# OPTIONNEL. Commandes lancées une fois dans le worktree avant la première étape, rejouées en entier
# par `deck retry` : elles doivent être idempotentes. Une commande vide est refusée. Défaut : liste vide.
# Chaque entrée est une chaîne ; ici, deux exemples à adapter ou à supprimer.
# ATTENTION : un fichier copié dans le worktree (ici `.env`) doit être IGNORÉ par le projet
# (`.gitignore`). Sinon il est non suivi et non ignoré, et bloque la livraison (ADR 0023 D6 (f)).
setup:
  - cp ~/Documents/github/perso/mon-projet/.env .env
  - npm ci

# Section `pr` : NE PAS L'ÉCRIRE avec `delivery: local` (erreur de `deck check`). Avec `delivery: pr` :
# pr:
#   title: "Titre de la PR"   # OBLIGATOIRE dans ce mode
#   draft: true               # OPTIONNEL ; `false` est refusé, la PR est toujours en brouillon
---

# Objectif de la campagne

<!-- A REMPLACER. Deux à cinq phrases : ce que la campagne livre, pourquoi, et pour quel utilisateur.
Chaque session d'étape lit ce fichier : rien ici ne doit supposer qu'on a la conversation du jour. -->

Exemple : ajouter l'export CSV des rapports à `mon-projet`, accessible par la commande
`mon-projet export --format csv`, sans changer le format JSON existant.

Feature : `roadmap/<version>/<feature>.md`

<!-- A REMPLACER par le chemin du fichier de feature dont la campagne est une tranche, relatif à la racine
du dépôt cible. Supprimer la ligne si la campagne ne découle d'aucune feature. L'étape de livraison met ce
fichier à jour. Ne pas en faire une clé du frontmatter : le domaine valide le frontmatter. -->

# Contraintes communes

Valables pour toutes les étapes :

- On travaille uniquement dans le worktree fourni par deck, jamais dans le checkout principal.
- Chaque étape fait ce que son fichier demande, rien de plus (pas de refactor au passage).
- Jamais de `git push`, jamais de `gh` : ils sont interdits et bloqués. Livrer ne se fait pas depuis la
  session (voir l'étape de livraison).
- Chaque étape finit par un commit de sauvegarde `wip(étape NN): <titre de l'étape>` (NN sur deux
  chiffres), arbre propre et index vide, puis par `deck done` (voir chaque étape).
- Aucune commande qui touche la production, des données réelles ou un service externe.
- <!-- Contraintes propres au projet : langue des commentaires, style, dépendances interdites, etc. -->

# Définition de « fini »

La campagne est finie quand :

- toutes les étapes sont `done` ;
- la suite de tests complète du projet passe (commande : voir l'étape de livraison) ;
- la version semver est à jour dans le fichier de version, le CHANGELOG (s'il existe) décrit le
  changement et la roadmap est cochée ;
- la branche de campagne porte **un seul commit** au-dessus de `base`, avec le tag annoté `vX.Y.Z`
  posé dessus ;
- <!-- critères propres à la campagne, vérifiables -->

La suite (avance de `base`, suppression de la branche et du worktree) est faite par deck, pas par
les étapes.

# Étapes

Les étapes sont les fichiers `NN-slug.md` voisins de celui-ci, exécutés dans l'ordre de `NN`.
La dernière (ici `02-livraison.md`) prépare la livraison et doit rester la dernière : la livraison est
la dernière étape par position (ADR 0023 D3). Quand on ajoute des étapes, renuméroter l'étape de
livraison (par ex. `07-livraison.md`) pour qu'elle garde le plus grand `NN`, et faire suivre ses
références à « l'étape 02 » dans le plan et le texte.
