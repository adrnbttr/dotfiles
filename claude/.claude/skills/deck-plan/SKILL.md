---
name: deck-plan
description: "À utiliser quand Adrien demande de planifier une campagne deck depuis un projet (« deck-plan », « prépare la nuit », « planifie une campagne »). Lit le projet, challenge la livraison précédente, propose un découpage de 6 à 8 h, écrit `<projet>/.deck/<AAAA-MM-JJ>-<slug>/` (00-plan.md, étapes, livraison), le valide avec `deck check` et donne la commande `deck run` sans la lancer. Ne code jamais."
---

# Planifier une campagne deck

Tu planifies, tu ne codes pas : tu écris des briefs que d'autres sessions exécuteront (`deck-step`). Ne modifie
aucun fichier du projet : seuls `<projet>/.deck/` et `revue.md` reçoivent des écritures. Ne lance jamais
`deck run`, `git push`, `gh`.

Références (à lire avant d'écrire) :
- modèle commenté : `~/Documents/github/perso/deck/docs/specs/modele-campagne/` (`README.md`, `00-plan.md`,
  `01-etape-type.md`, `02-livraison.md`). Si ce dossier manque, arrête-toi et dis-le.
- format exact : `~/Documents/github/perso/deck/docs/adr/0004-format-campagne-et-etape.md`.

Le projet est le dossier courant (racine du dépôt git ; sinon demande-le). Appelle-le `<projet>`.

## Phase 0 : purge proposée

Liste `<projet>/.deck/*/` avec la date du dossier et l'état (`deck status --json`, par `id`). Propose de supprimer
les plans de plus de 14 jours **terminés ou abandonnés**. Jamais sans accord explicite, jamais un plan en cours
(`running`, `waiting`, `ready`, `stale`…), jamais le dernier plan livré (nécessaire au challenge). Rien à purger :
dis-le en une ligne et continue.

## Phase 1 : lecture du projet

Lis, dans l'ordre où ils existent : `docs/roadmap.md` (ou équivalent), les ADR (`docs/adr/`), l'architecture,
`README`, `CLAUDE.md`/`AGENTS.md`, le fichier de version, le `CHANGELOG`, et **les commandes de test** (Makefile,
`package.json`, CI). Note : branche de base (`git branch --show-current`, en général `main`), version actuelle,
commande de tests complète exacte, présence de `setup` utile (dépendances à installer dans le worktree).
Le checkout principal doit être propre et sur la base à la livraison : signale-le s'il ne l'est pas
(`git status --short`).

## Phase 2 : challenge de la livraison précédente (lecture seule)

1. Dernier tag (`git describe --tags --abbrev=0`), `git log --oneline -n 10`, diff du dernier tag au précédent
   (`git diff --stat <tag-1>..<tag>`), tests sur la base (commande de la phase 1, sans rien modifier).
2. Plans et étapes de la veille dans `.deck/` : relis les `summary` (`deck status --json`).
3. **Campagne de la veille non livrée** (état autre que livrée/terminée, branche `deck/<id>` encore là) : demande
   à Adrien de choisir entre reprendre (`deck retry`/`resume`, pas un nouveau plan), abandonner (`deck abort`, à lui
   de le lancer) ou refaire. Une seule campagne non terminée par dépôt : n'en planifie pas une deuxième par-dessus.
4. Écris `.deck/<AAAA-MM-JJ>-<slug>/revue.md` (créé à la phase 4 si le dossier n'existe pas encore) : trois
   rubriques **Bien / À corriger / À améliorer**, chaque point avec gravité, `fichier:ligne`, pourquoi, correctif
   précis. Le nom ne commence pas par un chiffre : deck l'ignore.

Première campagne du projet (aucun tag, aucun plan) : écris « premier plan, rien à challenger » dans `revue.md`.

## Phase 3 : découpage proposé, ajusté avec Adrien

Dans la conversation, propose la liste numérotée avant d'écrire quoi que ce soit :
1. les « À corriger » de `revue.md` (premières étapes) ; les « À améliorer » au cas par cas ;
2. la suite de la roadmap ;
3. la **livraison**, toujours dernière, générée d'office.

Cible : 6 à 8 h au total, 5 à 10 étapes de 30 à 90 min plus la livraison. Chaque étape a un résultat observable
et une commande de test ; trop grosse, elle se coupe ; deux étapes qui touchent les mêmes fichiers se suivent.
Demande aussi : **l'agent** (`claude` ou `opencode`), le `slug` (minuscules, chiffres, tirets, 64 max) et la
version visée si elle compte. Agent : défaut `claude`, car l'adaptateur OpenCode n'est pas encore branché et
`deck check` refuse `agent: opencode`. N'essaie `opencode` que si Adrien le demande ; si `deck check` le refuse,
repasse à `claude` et dis-le. Attends son accord sur le découpage.

## Phase 4 : écriture de `<projet>/.deck/<AAAA-MM-JJ>-<slug>/`

La date est celle du jour. Vérifie que `.deck/` est ignoré : `git -C <projet> check-ignore -v .deck/<dossier>`.
S'il ne l'est PAS, ne modifie pas le projet : signale-le à Adrien et propose d'ajouter `.deck/` au `.gitignore`
du projet ou à l'ignore global. Continue seulement avec son accord (sinon la livraison locale peut refuser un
checkout non propre ; `deck check` l'avertit aussi).

**Valeurs texte du frontmatter YAML** (`title`, et toute valeur pouvant contenir `:` ou ` #`) : toujours entre
guillemets doubles, ex. `title: "Export CSV : commande"`. Sans guillemets, `title: Export CSV : commande` est
refusé (« : inattendu ») et `title: ticket #42` est tronqué sans bruit (` #` ouvre un commentaire YAML). Dans les
guillemets, `\` est un échappement : pas de `\` dans ces valeurs.

**`00-plan.md`** : pars du modèle. Frontmatter, rien d'inventé (tout champ inconnu est refusé) :
- `deck: 1`, `id: <slug>`, `repo: <chemin absolu du projet>`, `base: <branche>`, `agent`, `scenario: dev`,
  `stale_after: 30m` (durée = entier + `s|m|h`, un seul groupe), `max_duration: 2h` (optionnel),
  `delivery: local`. **Pas de section `pr`** avec `delivery: local`. `setup:` seulement si nécessaire
  (commandes idempotentes ; un fichier copié doit être ignoré par le projet).
- `base` : branche locale, le checkout principal doit être dessus.
- Corps : objectif (2 à 5 phrases, sans supposer la conversation du jour), contraintes communes, définition de
  « fini », liste des étapes. Garde les contraintes du modèle (worktree seul, pas de `git push`/`gh`, commit
  `wip(étape NN): <titre>`, `deck done`).

**`NN-slug.md`** (une étape par fichier, `NN` de `01` à `99`, ordre = `NN`, `slug` en `^[a-z0-9]+(-[a-z0-9]+)*$`) :
copie `01-etape-type.md` et remplis chaque rubrique. Chaque étape est un **brief autonome** : la session n'a ni la
conversation, ni les autres étapes, seulement `00-plan.md`, son fichier et le dépôt. Donc : objectif observable,
contexte à lire (chemins précis), fichiers à créer ou modifier, contraintes, hors périmètre, **commande de test
exacte** (code 0 attendu), critère de fin, commit `wip(étape NN): <titre>` avec `git add` nommant les fichiers,
`deck done --status ok|failed`. Frontmatter d'étape facultatif : `title`, `agent`, `model`, `stale_after`,
`max_duration` seulement. Le corps ne doit pas être vide.

**Livraison** : copie `02-livraison.md` sous le **plus grand `NN`** (ex. `07-livraison.md`) et fais suivre les
références à « étape 02 » (commit `wip(étape NN): version vX.Y.Z`, plan, texte). Remplace les `<...>` : `<base>`,
fichier de version du projet, commande de tests complète exacte, et la version semver visée si elle est connue.
Renseigne l'`id` de la campagne là où le modèle écrit `<id>`.

N'écris aucun autre fichier `.md` commençant par un chiffre (un nom qui n'est pas de la forme `NN-slug.md` est
refusé). `revue.md` reste.

## Phase 5 : validation

```
deck check <projet>/.deck/<AAAA-MM-JJ>-<slug>
```

Code 0 attendu. Sinon lis les erreurs (elles sont toutes listées), corrige les fichiers, relance, jusqu'au vert.
Si seul `agent: opencode` est refusé, passe à `claude`. « outil absent du PATH : deck » : `deck` n'est pas dans le
PATH du démon qui répond (`deck check` passe par lui) ; ce n'est pas une erreur de campagne : dis-le à Adrien
(`deck` dans le PATH, puis `deck daemon` à redémarrer), ne modifie pas les fichiers. Quand c'est vert, **donne** la commande, sans la lancer :

```
deck run <projet>/.deck/<AAAA-MM-JJ>-<slug>
```

Finis par un récapitulatif court : dossier, agent, nombre d'étapes et durée estimée, points de `revue.md`
retenus ou reportés, ce qui n'a pas pu être vérifié (tests lancés sur la base ou non).
