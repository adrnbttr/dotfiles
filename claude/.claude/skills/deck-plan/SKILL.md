---
name: deck-plan
description: "À utiliser quand Adrien demande de planifier une feature deck (« deck-plan roadmap/v1/<feature>.md », « prépare la nuit », « planifie la feature »). Prend un fichier de feature, lit le projet, propose un découpage en N campagnes de 6 à 8 h, le fait valider, écrit les N dossiers `<projet>/.deck/<feature>-<NN>/` (00-plan.md, étapes, livraison), remplit la section « Découpage en campagnes » de la feature, la committe sur la base, valide la première avec `deck check` et donne la commande `deck run` sans la lancer. Ne code jamais."
---

# Planifier une feature en campagnes deck

Tu planifies, tu ne codes pas : tu écris des briefs que d'autres sessions exécuteront (`deck-step`). Ne lance
jamais `deck run`, `git push`, `gh`. Seuls reçoivent des écritures : `<projet>/.deck/` et le fichier de la
feature (section « Découpage en campagnes »), que tu committes seul.

Le jugement de la campagne de la veille et la réécriture de la suivante sont le rôle de `deck-challenge` (à
venir) : `deck-plan` n'écrit ni `revue.md`, ni relecture de livraison.

Références, à lire avant d'écrire (chemins relatifs au skill) :
- `references/feature.md` : modèle du fichier de feature et règles d'usage ;
- `references/campagne.md` : règles communes (nommage, frontmatter, commits, tag, budget, contrôle) ;
- `references/modele-campagne/` : modèle commenté (`README.md`, `00-plan.md`, `01-etape-type.md`,
  `02-livraison.md`). Copie issue de deck `docs/specs/modele-campagne/` au 2026-11-23 ; à resynchroniser si le
  modèle change.

Entrée : le chemin d'un fichier `roadmap/<version>/<feature>.md` (demande-le s'il manque). Le projet est le
dépôt git qui le contient ; appelle-le `<projet>`. `<feature>` = nom du fichier sans `.md`.

## Phase 0 : contrôles préalables

- Fichier de feature conforme à `references/feature.md`, avec des critères d'acceptation cochables. Sinon
  arrête-toi et dis ce qui manque.
- Checkout principal propre et sur la base (`git status --short`, `git branch --show-current`). Sinon signale-le.
- Purge : liste `<projet>/.deck/*/` (`deck status --json`, par `id`). Propose de supprimer les campagnes de plus
  de 14 jours **terminées ou abandonnées**, jamais sans accord explicite, jamais une campagne en cours
  (`running`, `waiting`, `ready`, `stale`…) ni la dernière livrée. Rien à purger : une ligne et continue.
- Une seule campagne non terminée par dépôt : s'il en existe une, dis-le et demande si tu planifies quand même
  (les nouvelles ne seront lancées qu'après).

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
Demande aussi l'**agent** : défaut `claude` tant que J7 (OpenCode) n'est pas livré, car `deck check` refuse
`agent: opencode` ; n'essaie `opencode` que si Adrien le demande, et si `deck check` le refuse repasse à
`claude` en le disant.

**Pose la question explicite et attends l'accord d'Adrien** sur estimation et découpage. Aucune écriture avant.

## Phase 3 : écriture des N dossiers `<projet>/.deck/<feature>-<NN>/`

Vérifie que `.deck/` est ignoré : `git -C <projet> check-ignore -v .deck/<id>`. S'il ne l'est PAS, ne modifie pas
le projet sans accord : signale-le et propose d'ajouter `.deck/` au `.gitignore` du projet ou à l'ignore global.
Continue seulement avec son accord (sinon la livraison locale peut refuser un checkout non propre).

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
2. Montre le diff et demande l'accord d'Adrien, puis committe sur la base, ce seul fichier :
   `git -C <projet> add <fichier de la feature>` puis
   `git -C <projet> commit -m "docs(roadmap): <feature>, découpage en campagnes"` (en français, sans
   `Co-Authored-By` ni attribution). Le checkout doit rester propre : la livraison locale le refuse sale.

## Phase 5 : validation

`deck check <projet>/.deck/<feature>-01` : code 0 attendu ; sinon corrige jusqu'au vert, les erreurs sont toutes
listées, les « avertissement : » se traitent. Tant que `deck check <id>` / `--format` n'existent pas, seule la
première campagne passe `deck check` ; relis les suivantes à la main contre le modèle. « outil absent du PATH :
deck » : `deck` n'est pas dans le PATH du démon ; dis-le à Adrien, ne modifie pas les fichiers.

Termine par un récapitulatif court : feature, liste des `id` avec objectif, durée et tag, agent, hash du commit de
la feature, ce qui n'a pas été vérifié, et la commande du soir, **sans la lancer** :

```
deck run <chemin absolu de <projet>/.deck/<feature>-01>
```
