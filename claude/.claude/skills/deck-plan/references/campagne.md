# Règles communes d'écriture d'une campagne deck

Valables pour `deck-plan` (écriture) et `deck-challenge` (réécriture de la suivante). Le modèle officiel reste
copié dans `references/modele-campagne/` (`README.md`, `00-plan.md`, `01-etape-type.md`, `02-livraison.md`) :
le copier, ne rien inventer. Ce fichier ne dit que ce qui s'y ajoute pour le flux
feature → campagnes.

## Identité et nommage

- Une campagne = un `id` = `<feature>-<NN>` (ex. `export-csv-02`) : minuscules, chiffres, tirets
  (`^[a-z0-9]+(-[a-z0-9]+)*$`), 64 caractères au plus.
- Dossier `<projet>/.deck/<id>/`, **sans date** (le modèle suggère `<date>-<slug>` : écart voulu, l'`id` reste
  valide). Branche `deck/<id>` (défaut, ne pas écrire `branch`). `.deck/` est ignoré par git et ne contient
  que des campagnes (pas de notes ; `revue.md` n'est écrit que par `deck-challenge`, jamais par `deck-plan`).
- Les dates de planification et de passage sont notées dans le **corps** de `00-plan.md` (le frontmatter refuse
  tout champ inconnu : pas de champ `date`).
- Étapes : `NN-slug.md`, `NN` de `01` à `99`, ordre = `NN`. Aucun autre `.md` commençant par un chiffre.

## Frontmatter de `00-plan.md`

- Champs du modèle seulement : `deck: 1`, `id`, `repo` (chemin absolu), `base` (branche locale, le checkout
  principal doit être dessus), `agent`, `scenario: dev`, `stale_after`, `max_duration`, `delivery: local`,
  `setup` si utile. Pas de section `pr` avec `delivery: local`.
- **Valeurs texte entre guillemets doubles** (`title`, tout ce qui peut contenir `:` ou ` #`) :
  `title: "Export CSV : commande"`. Sans guillemets, `:` est refusé et ` #` tronque sans bruit. Pas de `\`
  dans ces valeurs.
- `agent` : celui qui **exécute**, indépendant de celui qui planifie ou challenge. Défaut `claude` tant que
  l'adaptateur OpenCode (J7) n'est pas livré (`deck check` refuse `opencode`), puis `opencode`.

## Briefs d'étape autonomes

L'agent d'une étape ne voit ni la conversation, ni la feature, ni les autres étapes : seulement `00-plan.md`,
son fichier et le dépôt. Chaque étape donne donc : objectif observable, contexte à lire (chemins précis), fichiers
à créer ou modifier, contraintes, hors périmètre, **commande de test exacte** (code 0), critère de fin. Si une
décision de la feature compte, la recopier dans l'étape (ou `00-plan.md`), pas un renvoi vers « ce qu'on a dit ».

## Commits et livraison

- Pendant la nuit : un commit de sauvegarde `wip(étape NN): <titre>` par étape, avec `git add` de fichiers
  nommés (jamais `-A`, `.`, `-a`), puis `deck done --status ok|failed`.
- **Dernière étape = livraison** (plus grand `NN`, copie de `02-livraison.md` renumérotée). Elle ajoute, avant le
  regroupement : cocher dans le fichier de feature (`roadmap/<version>/<feature>.md`) les critères satisfaits,
  mettre à jour la ligne du tableau (statut, tag) et ajouter la ligne de journal (id, date, tag, fait, reste).
  Puis un **commit unique** au-dessus de `base` et un tag annoté `vX.Y.Z`. Le fichier de feature est déjà sur
  `base` (committé à la planification), donc présent dans le worktree.
- **Tag obligatoire à chaque campagne** : version mineure par campagne (`0.N.0`) ; patch (`0.N.P`) pour une
  campagne de pure correction ; `v1.0.0` à la fin de la roadmap v1, puis `1.N.0` pendant la v2. Écrire la
  version visée en clair dans la livraison (le modèle laisse l'agent la déduire : ici la politique la fixe).
- La fusion de `base` (avance rapide), le retrait du worktree et de la branche sont faits par deck, pas par
  les étapes.

## Budget de nuit

6 à 8 h par campagne : 5 à 10 étapes de 30 à 90 min, livraison comprise (comptée ~30 min). Estimer par étape :
nombre de fichiers touchés, présence de tests à écrire, durée de la commande de test, risque d'itération ; en
cas de doute, prendre la borne haute. Une étape trop grosse se coupe ; deux étapes qui touchent les mêmes
fichiers se suivent. Ce qui dépasse 8 h glisse à la campagne suivante (le tableau de la feature en garde trace).
`max_duration` borne une tentative d'étape, pas la nuit : le régler au-dessus de la plus longue étape.

## Contrôle

- `deck check <dossier>` : code 0 attendu, toutes les erreurs sont listées ; les « avertissement : » (ex.
  `.deck/` non ignoré) se traitent, pas se taisent.
- **À venir (pas encore codé)** : `deck check <id>` et `deck check --format` (contrôle du contenu seul,
  sans l'état du dépôt : utile aux campagnes futures, car une seule campagne non terminée par dépôt). En
  attendant, contrôler la seule première campagne, `deck check <dossier>`, et relire les suivantes à la main
  contre le modèle. De même `deck run <id>` n'existe pas encore : `deck run <dossier>`.
- Donner la commande `deck run`, ne jamais la lancer depuis le skill.

## Ce qu'une campagne ne fait jamais

`git push`, `gh`, PR, toucher au checkout principal ou à `base` hors livraison par deck, commande sur la
production, des données réelles ou un service externe, `git reset --hard` ou `--force`, ajout de fichiers non
suivis non ignorés. Hors code, elle ne modifie que le fichier de la feature (cases, tableau, journal) et les fichiers de la
livraison du modèle (`02-livraison.md`, points 3 à 5 : fichier de version, `CHANGELOG`, `docs/roadmap.md`).
