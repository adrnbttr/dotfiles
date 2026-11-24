---
name: deck-plan
description: "À utiliser quand Adrien demande de planifier une feature deck (« deck-plan roadmap/v1/<feature>.md », « prépare la nuit », « planifie la feature »). Prend un fichier de feature, lit le projet, propose un découpage en N campagnes de 6 à 8 h, le fait valider, écrit les N dossiers `<projet>/.deck/<feature>-<NN>/` (00-plan.md, étapes, livraison), remplit la section « Découpage en campagnes » de la feature, la committe sur la base, valide toutes les campagnes par `deck check --format <id>` et la première par `deck check <id>`, et donne la commande `deck run <id>` sans la lancer. Ne code jamais."
---

# Planifier une feature en campagnes deck

Tu planifies, tu ne codes pas : tu écris des briefs que d'autres sessions exécuteront (`deck-step`). Ne lance
jamais `deck run`, `git push`, `gh`. Seuls reçoivent des écritures : `<projet>/.deck/`, le fichier de la
feature (section « Découpage en campagnes ») et, avec l'accord d'Adrien, le `.gitignore` du projet (ajout de
`.deck/`) ; tu ne committes que ces deux fichiers, par pathspec.

Le jugement de la campagne de la veille et la réécriture de la suivante sont le rôle de `deck-challenge` (à
venir) : `deck-plan` n'écrit ni `revue.md`, ni relecture de livraison.

Références, à lire avant d'écrire (chemins relatifs au skill) :
- `references/feature.md` : modèle du fichier de feature et règles d'usage ;
- `references/campagne.md` : règles communes (nommage, frontmatter, commits, tag, budget, contrôle) ;
- `references/modele-campagne/` : modèle commenté (`README.md`, `00-plan.md`, `01-etape-type.md`,
  `02-livraison.md`). Copie issue de deck `docs/specs/modele-campagne/` au 2026-11-23 ; à resynchroniser si le
  modèle change. Les liens relatifs (`../../adr/…`) et chemins (`cp docs/specs/modele-campagne/…`) du `README.md`
  de la copie ne valent que dans le dépôt deck : ne les suis pas depuis un autre projet.

Entrée : le chemin d'un fichier `roadmap/<version>/<feature>.md` (demande-le s'il manque). Le projet est le
dépôt git qui le contient ; appelle-le `<projet>`. `<feature>` = nom du fichier sans `.md`.

## Phase 0 : contrôles préalables

- Fichier de feature conforme à `references/feature.md`, avec des critères d'acceptation cochables. Sinon
  arrête-toi et dis ce qui manque.
- Checkout principal sur la branche de base **avant d'écrire quoi que ce soit** (`git branch --show-current`),
  sans fichier modifié ni indexé (`git status --short` vide, hors `.deck/` ignoré). Sinon arrête-toi et dis ce
  qui ne va pas : tu ne changes pas de branche et tu ne nettoies pas à la place d'Adrien.
- Purge : liste `<projet>/.deck/*/` (`deck status --json`, par `id`). Propose de supprimer les campagnes de plus
  de 14 jours **terminées ou abandonnées**, jamais sans accord explicite, jamais une campagne en cours
  (`running`, `waiting`, `ready`, `stale`…) ni la dernière livrée. Rien à purger : une ligne et continue.
- Une seule campagne active par dépôt : s'il en existe une non terminée (`running`, `waiting`, `ready`,
  `stale`…), arrête-toi, dis laquelle et n'écris rien. Raison : committer sur la base la ferait diverger de
  `deck/<id>` (livraison impossible) et `deck check` refuse un dépôt occupé. Reprends quand elle est livrée ou
  abandonnée.

## Phase 1 : lecture du projet

Lis la feature en entier, puis ce qu'elle cite : ADR liés, `README`, `CLAUDE.md`/`AGENTS.md`, code existant utile,
fichier de version, `CHANGELOG`, **commandes de test** (Makefile, `package.json`, CI). Note : branche de base,
version actuelle, commande de tests complète exacte, `setup` utile (dépendances à installer dans le worktree).

## Phase 2 : estimation et découpage proposés (aucune écriture)

Estime le travail de la feature (voir « Budget de nuit » dans `campagne.md`) et propose dans la conversation N
campagnes de 6 à 8 h, chacune : `id` (`<feature>-<NN>`), objectif en une ligne, étapes (titres, durée), critères
d'acceptation de la feature qu'elle satisfait, tag visé (politique de `campagne.md`). Chaque campagne a 5 à 10
étapes de 30 à 90 min plus la livraison, dernière. Chaque étape a un résultat observable et une commande de test ;
deux étapes qui touchent les mêmes fichiers se suivent. Tous les critères de la feature doivent être couverts.
Demande aussi l'**agent** : propose `opencode` par défaut (Adrien peut choisir `claude`). Avec `opencode`,
précise `model` : sans `model` dans le frontmatter d'une étape, le modèle est lu dans la config OpenCode
(`agents.build.model`, `jq` requis) ; avec `model` (ex. `provider/modèle`), il est imposé et passé tel quel. Ne
mets `model` que si Adrien veut un modèle précis pour la campagne ou une étape ; sinon laisse-le absent.

**Pose la question explicite et attends l'accord d'Adrien** sur estimation et découpage. Aucune écriture avant.

## Phase 3 : écriture des N dossiers `<projet>/.deck/<feature>-<NN>/`

Vérifie que `.deck/` est ignoré : `git -C <projet> check-ignore -v .deck/<id>`. S'il ne l'est PAS, ne modifie pas
le projet sans accord : signale-le et propose d'ajouter `.deck/` au `.gitignore` du projet ou à l'ignore global.
Continue seulement avec son accord (sinon la livraison locale peut refuser un checkout non propre). S'il
accepte l'ajout au `.gitignore` du projet, ce fichier entre dans le commit de la phase 4 ; s'il choisit l'ignore
global, rien n'est à committer pour cela.

Écris les N campagnes d'avance, d'après le modèle, en respectant `campagne.md` (dossier sans date, `id`, branche
par défaut). Dans chacune :

**Valeurs texte du frontmatter YAML** (`title`, toute valeur pouvant contenir `:` ou ` #`) : toujours entre
guillemets doubles, ex. `title: "Export CSV : commande"`. Sans guillemets, `:` est refusé et ` #` tronque sans
bruit. Pas de `\` dedans.

**`00-plan.md`** : frontmatter sans champ inventé : `deck: 1`, `id`, `repo` (chemin absolu du projet), `base`,
`agent`, `scenario: dev`, `stale_after: 30m` (entier + `s|m|h`, un seul groupe), `max_duration` (au-dessus de
la plus longue étape), `delivery: local`, pas de section `pr`, `setup:` seulement si nécessaire (idempotent ;
fichier copié = ignoré par le projet). Corps : objectif (2 à 5 phrases, sans la conversation du jour), lien vers la
feature et critères visés, contraintes communes du modèle, définition de « fini », liste des étapes, date de
planification.

**`NN-slug.md`** (`NN` de `01` à `99`, slug `^[a-z0-9]+(-[a-z0-9]+)*$`) : copie de `01-etape-type.md`, brief
**autonome** (objectif observable, contexte à lire, fichiers, contraintes, hors périmètre, **commande de test
exacte**, critère de fin, commit `wip(étape NN): <titre>` avec `git add` de fichiers nommés, `deck done`).
Décisions de la feature recopiées, pas renvoyées. Frontmatter d'étape facultatif : `title`, `agent`, `model`,
`stale_after`, `max_duration`. Corps non vide.

**Livraison** : copie de `02-livraison.md` sous le plus grand `NN`, références « étape 02 » renumérotées,
`<base>`, fichier de version, commande de tests complète, version visée en clair, `<id>` remplis, plus la mise à
jour de la feature (critères, tableau, journal) décrite dans `campagne.md`.

Aucun autre `.md` commençant par un chiffre.

## Phase 4 : la feature, puis le commit

1. Remplis la section « Découpage en campagnes » de la feature : une ligne par campagne (`id`, objectif, statut
   `planifiée`, tag visé). Ne touche ni aux critères, ni au journal.
2. Montre le diff et demande l'accord d'Adrien, puis committe sur la base (vérifie d'abord que tu y es encore),
   uniquement les fichiers du skill, par pathspec, sans passer par l'index :
   `git -C <projet> commit -m "docs(roadmap): <feature>, découpage en campagnes" -- <fichier de la feature> [.gitignore]`
   (`.gitignore` seulement s'il a été modifié ; si un fichier est non suivi, `git add -N <fichier>` d'abord ;
   message en français, sans `Co-Authored-By` ni attribution).
3. Vérifie : `git -C <projet> show --name-only --format= HEAD` ne liste que ces fichiers, et
   `git -C <projet> status --short` est vide. Sinon arrête-toi et signale-le, sans réécrire l'historique.
   Le checkout doit rester propre : la livraison locale le refuse sale.

## Phase 5 : validation

Les commandes prennent l'`id` : `deck` résout `<racine git du cwd>/.deck/<id>/`, lance-les donc depuis le
projet.

1. **Toutes** les campagnes écrites : `deck check --format <feature>-<NN>` (format du manifeste et des étapes
   seulement, valable même quand une autre campagne occupe le dépôt) : code 0 attendu pour chacune.
2. La **première** : `deck check <feature>-01` complet (outils, `opencode`, skill, dépôt, base…), code 0 attendu.
   Les campagnes suivantes ne passent le contrôle complet que le soir de leur lancement.

Corrige jusqu'au vert : les erreurs sont toutes listées, les « avertissement : » se traitent. « outil absent du
PATH : deck » (ou `opencode`, `jq`) : l'outil n'est pas dans le PATH du démon ; dis-le à Adrien, ne modifie pas les
fichiers.

Termine par un récapitulatif court : feature, liste des `id` avec objectif, durée et tag, agent (et `model` éventuel), hash du commit de
la feature, ce qui n'a pas été vérifié, et la commande du soir, **sans la lancer** :

```
cd <projet> && deck run <feature>-01
```
