---
name: deck-plan
description: "À utiliser quand Adrien demande de planifier une feature deck (« deck-plan roadmap/v1/<feature>.md », « prépare la nuit », « planifie la feature »). Prend un fichier de feature, lit le projet, propose un découpage en N campagnes de 6 à 8 h, le fait valider, écrit les N dossiers `<projet>/.deck/<feature>-<NN>/` (00-plan.md, étapes, livraison), sans toucher au fichier de feature ni committer (tout reste dans `.deck/`, non versionné), valide toutes les campagnes par `deck check --format <id>` et la première par `deck check <id>`, et donne la commande `cd <projet> && deck run <id>` sans la lancer. Ne code jamais."
---

# Planifier une feature en campagnes deck

Tu planifies, tu ne codes pas : tu écris des briefs que d'autres sessions exécuteront (`deck-step`). Ne lance
jamais `deck run`, `git push`, `gh`. Seul `<projet>/.deck/` (non versionné) reçoit
des écritures. **Tu ne modifies jamais le fichier de feature et tu ne fais aucun commit** : la feature ne change
que par Adrien (cadrage) ou par l'étape de livraison d'une campagne (critères, ligne du tableau, journal).

Le jugement de la campagne de la veille et la réécriture de la suite sont le rôle de `deck-challenge` :
`deck-plan` n'écrit ni `revue.md`, ni relecture de livraison.

Références, à lire avant d'écrire (chemins relatifs au skill) :
- `references/feature.md` : modèle du fichier de feature et règles d'usage ;
- `references/campagne.md` : règles communes (nommage, frontmatter, guillemets YAML, agent, `model`, commits,
  niveau de version, budget, contrôle) ;
- `references/controles.md` : contrôles communs avec `deck-challenge` (checkout propre, aucun commit, outils
  contrôlés par `deck check`) ;
- `references/modele-campagne/` : modèle commenté (`README.md`, `00-plan.md`, `01-etape-type.md`,
  `02-livraison.md`). Copie de deck `docs/specs/modele-campagne/`, à garder identique. Les liens relatifs (`../../adr/…`) et chemins (`cp docs/specs/modele-campagne/…`) du `README.md`
  de la copie ne valent que dans le dépôt deck : ne les suis pas depuis un autre projet.

Entrée : le chemin d'un fichier `roadmap/<version>/<feature>.md` (demande-le s'il manque). Le projet est le
dépôt git qui le contient ; appelle-le `<projet>`. `<feature>` = nom du fichier sans `.md`.

## Phase 0 : contrôles préalables

- Fichier de feature conforme à `references/feature.md`, avec des critères d'acceptation cochables. Sinon
  arrête-toi et dis ce qui manque.
- **Avant d'écrire quoi que ce soit** : « Checkout propre » de `references/controles.md`.
- États de campagne (`state` de `deck status --json`) : `setup`, `running`, `paused`, `ready`, `completed`,
  `aborted`. Terminée = `completed` ou `aborted`.
- Purge : liste `<projet>/.deck/*/` (`deck status --json`, par `id`). Propose de supprimer les campagnes de plus
  de 14 jours dont le `state` est `completed` ou `aborted`, jamais sans accord explicite, jamais une campagne dans un autre
  état, ni la dernière livrée. Rien à purger : une ligne et continue.
- Une seule campagne active par dépôt : s'il existe pour ce `repo` une campagne dont le `state` n'est pas
  `completed`/`aborted`, arrête-toi, dis laquelle et n'écris rien. Raison : `deck check` refuse un dépôt occupé, et une
  base modifiée pendant une campagne empêche sa livraison. Reprends quand elle est livrée ou
  abandonnée.

## Phase 1 : lecture du projet

Lis la feature en entier, puis ce qu'elle cite : ADR liés, `README`, `CLAUDE.md`/`AGENTS.md`, code existant utile,
fichier de version, `CHANGELOG`, **commandes de test** (Makefile, `package.json`, CI). Note : branche de base,
version actuelle, commande de tests complète exacte, `setup` utile (dépendances à installer dans le worktree).

## Phase 2 : estimation et découpage proposés (aucune écriture)

Estime le travail de la feature (voir « Budget de nuit » dans `campagne.md`) et propose dans la conversation N
campagnes de 6 à 8 h, chacune : `id` (`<feature>-<NN>`), objectif en une ligne, étapes (titres, durée), critères
d'acceptation de la feature qu'elle satisfait, niveau de version (mineure, correctif ou `1.0.0` : politique de
`campagne.md` ; jamais de numéro, calculé à la livraison). Chaque campagne a 5 à 10
étapes de 30 à 90 min plus la livraison, dernière. Chaque étape a un résultat observable et une commande de test ;
deux étapes qui touchent les mêmes fichiers se suivent. Tous les critères de la feature doivent être couverts.
Demande aussi l'**agent** et l'éventuel `model` en appliquant `campagne.md`, « Frontmatter » (défaut proposé,
cas où l'agent est imposé sans poser la question, place de `model` : frontmatter de chaque étape, jamais le
manifeste).

Liste aussi les **décisions techniques que la feature ne tranche pas** et que les briefs vont fixer (noms,
signatures, formats, règles de calcul, rôle des variables d'environnement…) : personne ne répond la nuit, un brief
ne laisse rien d'ouvert, et ces choix font partie de l'accord.

**Pose la question explicite et attends l'accord d'Adrien** sur estimation, découpage et décisions. Aucune écriture
avant.

## Phase 3 : écriture des N dossiers `<projet>/.deck/<feature>-<NN>/`

Vérifie que `.deck/` est ignoré : `git -C <projet> check-ignore -v .deck/<id>`. S'il ne l'est PAS, arrête-toi sans
rien écrire : demande à Adrien d'ajouter `.deck/` à l'ignore global (`~/.config/git/ignore`) ou au `.gitignore` du
projet, par **son propre commit** (tu ne committes pas). Reprends quand `check-ignore` répond.

Écris les N campagnes d'avance, d'après le modèle, en respectant `campagne.md` (dossier sans date, `id`, branche
par défaut ; frontmatter : champs, guillemets doubles, agent, `model`, selon « Frontmatter »). Dans chacune :

**`00-plan.md`** : frontmatter sans champ inventé : `deck: 1`, `id`, `repo` (chemin absolu du projet), `base`,
`agent`, `scenario: dev`, `stale_after: 30m` (entier + `s|m|h`, un seul groupe), `max_duration` (au-dessus de
la plus longue étape), `delivery: local`, pas de section `pr`, pas de `model`, `setup:` seulement si nécessaire (idempotent ;
fichier copié = ignoré par le projet). Corps : objectif (2 à 5 phrases, sans la conversation du jour), lien vers la
feature et critères visés, contraintes communes du modèle, définition de « fini », liste des étapes, date de
planification.

**`NN-slug.md`** (`NN` de `01` à `99`, slug `^[a-z0-9]+(-[a-z0-9]+)*$`) : copie de `01-etape-type.md`, brief
**autonome** (objectif observable, contexte à lire, fichiers, contraintes, hors périmètre, **commande de test
exacte**, critère de fin, commit `wip(étape NN): <titre>` avec `git add` de fichiers nommés, `deck done`).
Décisions de la feature recopiées, pas renvoyées. Frontmatter d'étape facultatif : `title`, `agent`, `model`,
`stale_after`, `max_duration`. Corps non vide.

Section « Conventions du projet » du `00-plan.md`, liste de ce que les campagnes précédentes ont livré, décisions
fermées et pièges à éviter : `references/campagne.md`, « Briefs d'étape autonomes ».

**Livraison** : copie de `02-livraison.md` sous le plus grand `NN`, références « étape 02 » renumérotées,
`<base>`, fichier de version, commande de tests complète, **niveau** de version au point 2 (mineure, correctif
ou `1.0.0` ; pas de numéro : la livraison le calcule), `<id>` remplis, plus la mise à
jour de la feature (critères, tableau, journal) décrite dans `campagne.md`.

Aucun autre `.md` commençant par un chiffre.

## Phase 4 : aucun commit, checkout propre

1. Le découpage vit **uniquement dans `.deck/`** : chaque `00-plan.md` porte son `id`, son objectif et la
   ligne « Feature : `roadmap/<version>/<feature>.md` » ; le niveau de version est au point 2 de sa livraison. Le fichier de feature n'est pas modifié.
2. Dans l'étape de livraison de chaque campagne, le point « Fichier de feature » demande d'**ajouter** la ligne de la
   campagne au tableau « Découpage » si elle est absente (`id | objectif | livrée | vX.Y.Z`), sinon de la mettre à jour.
3. « Vérification finale : aucun commit » : à la fin de la phase 5, après la relecture adverse.

## Phase 5 : validation

Les commandes prennent l'`id` : `deck` résout `<racine git du cwd>/.deck/<id>/`, lance-les donc depuis le
projet.

1. **Toutes** les campagnes écrites : `deck check --format <feature>-<NN>` (format du manifeste et des étapes
   seulement, valable même quand une autre campagne occupe le dépôt) : code 0 attendu pour chacune.
2. La **première** : `deck check <feature>-01` complet (outils, skill, version d'OpenCode en avertissement, dépôt,
   base…), code 0 attendu.
   Les campagnes suivantes ne passent le contrôle complet que le soir de leur lancement.

Corrige jusqu'au vert : les erreurs sont toutes listées, les « avertissement : » se traitent. Outils contrôlés
et « outil absent du PATH » : `references/controles.md`.

3. **Relecture adverse des briefs**, toujours, avant le récapitulatif : `references/campagne.md`, « Contrôle »
   (sous-agent `challenger`, correction, puis contrôles 1 et 2 relancés). Elle porte sur toutes les campagnes
   écrites.
4. « Vérification finale : aucun commit » de `references/controles.md`.

Termine par un récapitulatif court : feature, liste des `id` avec objectif, durée et niveau de version, agent
(et `model` éventuel), décisions modifiées depuis l'accord (`campagne.md`, « Contrôle »), confirmation qu'aucun
commit n'a été fait, ce qui n'a pas été vérifié, et la commande du soir, **sans la lancer** :

```
cd <projet> && deck run <feature>-01
```
