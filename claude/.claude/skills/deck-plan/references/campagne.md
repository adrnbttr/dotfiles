# Règles communes d'écriture d'une campagne deck

Valables pour `deck-plan` (écriture) et `deck-challenge` (réécriture de la suite). Le modèle officiel reste
copié dans `references/modele-campagne/` (`README.md`, `00-plan.md`, `01-etape-type.md`, `02-livraison.md`) :
le copier, ne rien inventer. Ce fichier ne dit que ce qui s'y ajoute pour le flux
feature → campagnes.

## Identité et nommage

- Une campagne = un `id` = `<feature>-<NN>` (ex. `export-csv-02`) : minuscules, chiffres, tirets
  (`^[a-z0-9]+(-[a-z0-9]+)*$`), 64 caractères au plus.
- Dossier `<projet>/.deck/<id>/`, **sans date**. Branche `deck/<id>` (défaut, ne pas écrire `branch`). `.deck/`
  est ignoré par git et ne contient que des campagnes (pas de notes ; `revue.md` n'est écrit que par
  `deck-challenge`, jamais par `deck-plan`).
- Les dates de planification et de passage sont notées dans le **corps** de `00-plan.md` (le frontmatter refuse
  tout champ inconnu : pas de champ `date`).
- Étapes : `NN-slug.md`, `NN` de `01` à `99`, ordre = `NN`. Aucun autre `.md` commençant par un chiffre.

## Frontmatter

- `00-plan.md` : champs du modèle seulement : `deck: 1`, `id`, `repo` (chemin absolu), `base` (branche locale,
  le checkout principal doit être dessus), `agent`, `scenario: dev`, `stale_after`, `max_duration`,
  `delivery: local`, `setup` si utile. Pas de section `pr` avec `delivery: local`. Pas de `model` : le
  manifeste n'a pas ce champ (refusé par `deck check --format`).
- Étape (`NN-slug.md`), facultatif : `title`, `agent`, `model`, `stale_after`, `max_duration`.
- **Valeurs texte entre guillemets doubles** (`title` des étapes, toute valeur qui peut contenir `:` ou ` #`) :
  `title: "Export CSV : commande"`. Sans guillemets, `:` est refusé et ` #` tronque sans bruit. Pas de `\`
  dans ces valeurs.
- `agent` : celui qui **exécute**, indépendant de celui qui planifie ou challenge. Défaut proposé : `opencode`
  (Adrien peut choisir `claude`). **Si l'`AGENTS.md` du projet dit que le code est produit par OpenCode,
  `agent: opencode` est obligatoire** (jamais `claude`, ni au manifeste ni en surcharge d'étape, sans poser la
  question) ; cela vaut pour toute campagne écrite, réécrite ou créée.
- `model` : facultatif avec `opencode`, et se met dans le frontmatter de **chaque étape** concernée (jamais dans
  le manifeste). Absent : le modèle vient de la config OpenCode (`agents.build.model`, `jq` requis) ; présent
  (ex. `provider/modèle`), il est imposé et passé tel quel. Ne le mettre que si Adrien veut un modèle précis.
  Attention : deck force `default_agent: "build"` dans la config injectée. Le `default_agent` de la config
  d'Adrien (ex. `plan`) et les autres agents primaires ne jouent donc **pas** la nuit : `build` orchestre l'étape
  (son modèle est `agents.build.model` sans `model`) et délègue à des sous-agents (`implementer`, `chore`,
  `explore`, `challenger`) qui gardent leur propre modèle de la config OpenCode. Le dire à Adrien quand il croit
  qu'un autre agent orchestre.

## Briefs d'étape autonomes

L'agent d'une étape ne voit ni la conversation ni les autres étapes : seulement `00-plan.md`, son fichier, le
dépôt (fichier de feature compris, il est versionné) et, en lecture seule, les fichiers que son brief cite par
chemin absolu (ex. `revue.md`, hors du worktree). Chaque étape donne donc : objectif observable, contexte à lire
(chemins précis), fichiers à créer ou modifier, contraintes, hors périmètre, **commande de test exacte** (code 0),
critère de fin. Si une décision de la feature compte, la recopier dans l'étape (ou `00-plan.md`), pas un renvoi
vers « ce qu'on a dit ».
Personne ne répond pendant la nuit : un brief ne laisse aucune décision ouverte, et un blocage fait conclure
l'étape par `deck done --status failed` avec le motif.

- **Conventions du projet** : quand plusieurs étapes partagent des décisions (arborescence, noms de modules et de
  classes, connexions, style, commandes), les écrire une fois dans une section « Conventions du projet » du
  `00-plan.md` (chaque étape le lit) plutôt que dans chaque brief ; l'étape ne recopie que ce qui lui est propre.
- **Campagnes précédentes** : avec plusieurs campagnes, chaque `00-plan.md` liste ce que les campagnes
  précédentes ont livré (modules, fixtures), pour que l'agent s'appuie dessus au lieu de le réécrire.

Pièges vus à l'usage :
- La commande de test d'une étape tourne **avant** son commit de sauvegarde : pas de `test -z "$(git status
  --short)"` dedans (il échouerait sur le travail non commité). Il est recommandé en critère de fin, **après** le
  commit : `deck done` ne refuse que les fichiers suivis modifiés et un index non vide, il ignore les fichiers non
  suivis ; ce contrôle attrape un fichier oublié, qui sinon ne bloquerait qu'à la livraison. Même chose pour la
  livraison : au point 7, les fichiers des points 3 à 6 sont encore modifiés.
- Le worktree disparaît à la livraison : tout état durable hors du worktree (base de données, conteneur, cache)
  ne doit pas pointer vers des fichiers du worktree, sinon la campagne suivante trouve des références mortes.
  Les ressources partagées (base, ports, noms de conteneurs) se nomment pour coexister entre worktrees.
- Une étape n'utilise que ce qu'une étape précédente (ou une campagne livrée) a créé : vérifier l'ordre des
  dépendances entre briefs, signatures comprises.

## Commits et livraison

- Pendant la nuit : un commit de sauvegarde `wip(étape NN): <titre>` par étape, avec `git add` de fichiers
  nommés (jamais `-A`, `.`, `-a`), puis `deck done --status ok|failed`.
- **Dernière étape = livraison** (plus grand `NN`, copie de `02-livraison.md` renumérotée). Elle ajoute, avant le
  regroupement : cocher dans le fichier de feature (`roadmap/<version>/<feature>.md`) les critères satisfaits,
  **ajouter** la ligne de la campagne au tableau « Découpage » si elle est absente (sinon la mettre à jour) et
  ajouter la ligne de journal (id, date, tag, fait, reste). Puis un **commit unique** au-dessus de `base` et un
  tag annoté `vX.Y.Z`. Le fichier de feature est sur `base` (versionné avec la roadmap, jamais modifié par
  `deck-plan` ni par `deck-challenge`).
- **Tag obligatoire à chaque campagne.** Le plan ne fixe que le **niveau** de version, écrit en clair au point 2
  de l'étape de livraison :
  - **mineure** : cas général, une campagne qui apporte du nouveau (`0.N.0`, puis `1.N.0` après la v1) ;
  - **correctif** : campagne de pure correction, sans nouveauté (`0.N.P`) ;
  - **`1.0.0`** : dernière campagne de la roadmap v1.
  En cas de doute entre mineure et correctif, mineure. La version exacte `X.Y.Z` n'est **jamais** écrite par le
  plan ni par le challenge : l'étape de livraison la calcule au moment de livrer, à partir du dernier tag et du
  fichier de version de `base` (une autre campagne a pu livrer entre-temps).
- La fusion de `base` (avance rapide), le retrait du worktree et de la branche sont faits par deck, pas par
  les étapes.

## Budget de nuit

6 à 8 h par campagne : 5 à 10 étapes de 30 à 90 min, livraison comprise (comptée ~30 min). Estimer par étape :
nombre de fichiers touchés, présence de tests à écrire, durée de la commande de test, risque d'itération ; en
cas de doute, prendre la borne haute. Une étape trop grosse se coupe ; deux étapes qui touchent les mêmes
fichiers se suivent. Ce qui dépasse 8 h glisse à la campagne suivante (le `00-plan.md` de chaque campagne en garde trace).
`max_duration` borne une tentative d'étape, pas la nuit : le régler au-dessus de la plus longue étape.

## Contrôle

- `deck check --format <id>` : format du manifeste et des étapes seulement, utilisable pour une campagne
  future quand la précédente occupe le dépôt ; code 0 attendu pour **chaque** campagne écrite.
- `deck check <id>` : contrôle complet, code 0 attendu, à faire sur la première campagne ; toutes les erreurs
  sont listées ; les « avertissement : » (ex. `.deck/` non ignoré) se traitent, pas se taisent. `<id>` se
  résout depuis la racine git du cwd en `.deck/<id>/` (un dossier reste accepté). Outils contrôlés et
  « outil absent du PATH » : `controles.md`.
- **Relecture adverse des briefs**, toujours (sauf si aucune campagne n'a été écrite ou réécrite), après ces
  contrôles : un sous-agent `challenger` (Opus). Il reçoit, et rien d'autre : les chemins de la feature, le
  fichier d'instructions du projet (`AGENTS.md`, sinon `CLAUDE.md`), les dossiers `.deck/<id>/` concernés et la
  règle « chaque étape voit `00-plan.md`, son fichier, le dépôt et, en lecture seule, les fichiers que son brief
  cite par chemin absolu ; personne ne répond la nuit ». Depuis `deck-challenge`, il reçoit en plus le `revue.md`
  de la campagne jugée et le tag ou sha livré. Jamais ton raisonnement ni tes conclusions. Il cherche les
  critères non couverts, les contradictions entre plan et étapes, les décisions ouvertes, les instructions
  techniquement fausses, les étapes trop grosses. Corrige ce qui est fondé, puis relance : `deck-plan`, `--format`
  sur toutes les campagnes et le contrôle complet sur la première ; `deck-challenge`, `--format` seulement (le
  contrôle complet se fait le soir).
- **Décision modifiée après l'accord** : si une correction issue de la relecture touche le découpage ou une
  décision déjà validée par Adrien, la signaler dans le récapitulatif final (décision, ancienne valeur, nouvelle
  valeur, raison). Si elle change le découpage (nombre ou périmètre des campagnes), redemander l'accord avant de
  terminer.
- Donner la commande `cd <projet> && deck run <id>`, ne jamais la lancer depuis le skill.

## Ce qu'une campagne ne fait jamais

`git push`, `gh`, PR, toucher au checkout principal ou à `base` hors livraison par deck, commande sur la
production, des données réelles ou un service externe, `git reset --hard` ou `--force`, ajout de fichiers non
suivis non ignorés. Hors code, elle ne modifie que le fichier de la feature (cases, tableau, journal), le
`.gitignore` du projet (fichier non suivi légitime, raison dans le message de commit : `01-etape-type.md`,
« Commit de sauvegarde », et point 1 de `02-livraison.md`) et les fichiers de la livraison du modèle
(`02-livraison.md`, points 3 à 5 : fichier de version, `CHANGELOG`, `docs/roadmap.md`).
