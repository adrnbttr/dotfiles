---
name: deck-challenge
description: "À utiliser le matin, quand Adrien demande de juger la nuit deck (« deck-challenge », « challenge la campagne d'hier », « relis la nuit », « prépare la suivante »). Trouve la dernière campagne passée (`deck status --json`) ; si elle n'est pas terminée, propose de la reprendre ou de l'abandonner, rien d'autre ; sinon relit le commit livré sur la base (tag), lance les tests, écrit `revue.md` dans le dossier de la campagne, réécrit la campagne suivante de la feature (étape 01 de corrections, suite recalibrée pour une nuit de 6 à 8 h, surplus reporté), crée une campagne de correction si c'était la dernière, valide avec `deck check --format` et committe la feature avec l'accord d'Adrien. Lecture seule sur le code."
---

# Challenger la campagne de la veille

Tu juges et tu replanifies, tu ne codes pas. Tu es indépendant de l'agent qui a exécuté la nuit (`agent:` du
manifeste de la campagne) : ne lui fais pas confiance sur parole, relis le code et rejoue les tests.

**Lecture seule sur le code du projet.** Les seules écritures permises : `<projet>/.deck/` (le `revue.md` de la
campagne jugée, les dossiers des campagnes suivantes) et le fichier de feature `roadmap/<version>/<feature>.md`.
Tu ne corriges aucun défaut dans le code, tu ne touches ni au checkout principal ni aux branches, et tu ne lances
jamais `deck run`, `git push`, `gh`. Le commit de la feature n'est fait qu'après l'accord explicite d'Adrien.

Références (chemins relatifs au skill, partagées avec `deck-plan`, à lire avant d'écrire) :
- `../deck-plan/references/feature.md` : modèle de la feature (critères, tableau « Découpage », journal) ;
- `../deck-plan/references/campagne.md` : règles d'écriture d'une campagne (nommage, frontmatter, guillemets
  YAML, briefs autonomes, `wip`, livraison, tag, budget de nuit, contrôle) ;
- `../deck-plan/references/modele-campagne/` : modèle commenté (`00-plan.md`, `01-etape-type.md`, `02-livraison.md`) ;
- `references/revue.md` : modèle de `revue.md`.

## Phase 0 : trouver la campagne de la veille

1. `deck status --json` (lecture directe de la base). Schéma `v: 1`.
   Si la commande échoue avec « la base est en version N, ce binaire attend la version M : le démon doit la
   migrer » : ne lance pas de démon toi-même sans le dire. Explique à Adrien que `deck check <id>` (ou tout
   démarrage du démon) migre la base, et demande-lui avant de le faire. Une fois sa réponse reçue, il le fait
   ou te laisse le faire ; arrête ensuite le démon que tu as lancé (`deck daemon stop`). Champs lus :
   - campagne : `id`, `state` (`setup`, `running`, `paused`, `ready`, `completed`, `aborted`), `pause`,
     `dir` (dossier `.deck/<id>/`, absolu), `repo`, `branch`, `created_at`, `delivery`
     (`{ mode, delivered_sha, refusal }`, `refusal` = motif de refus de livraison si `ready`), `steps` ;
   - étape : `no`, `slug`, `title`, `state` (`pending`, `running`, `waiting`, `done`, `failed`, `crashed`,
     `skipped`), `attempt`, `summary` (résumé du `done`, ou du `done failed`), `ended_at` (secondes Unix UTC,
     étapes `done` ou `skipped`), `file_changed`, `cost_micro_usd`, `cost_tokens`, `stale`, `overdue`.
   Le champ `delivery_refusal` (racine de la campagne) double `delivery.refusal` ; lis `delivery.refusal`.
2. Garde les campagnes dont `repo` est le projet. Demande à Adrien l'`id` si le projet n'est pas évident. La
   campagne de la veille est la plus récente (`created_at`) de ces campagnes qui appartient à la feature
   (`id` = `<feature>-<NN>`). Dis laquelle tu retiens et pourquoi ; en cas de doute, demande.
3. Aucune campagne trouvée : arrête-toi (rien n'a tourné, rien à juger) et dis-le.
4. Contrôles sur le projet : checkout principal sur la base (`git branch --show-current`), `git status --short`
   vide. Sinon arrête-toi et dis ce qui ne va pas ; tu ne changes pas de branche et tu ne nettoies rien.

## Phase 1 : la campagne est-elle terminée ?

**Terminée** = `state` `completed` ou `aborted`. Une campagne `completed` a `delivery.delivered_sha` non nul
(en mode `local`).

**Non terminée** (`setup`, `running`, `paused`, `ready`) : tu ne juges pas et tu ne réécris rien. Rends l'état en
quelques lignes (étapes `done`/`failed`/`crashed`, `pause`, `summary` des étapes en échec, `delivery.refusal`
si `ready`) et propose seulement deux issues à Adrien, commandes à lui donner sans les lancer :
- **reprendre** : `deck resume <id> <NN>` (étape en attente après un échec ou un plantage), ou
  `deck retry <id> <NN>` (relancer l'étape en échec ou plantée) ; `deck attach <id> <NN>` pour regarder la
  session d'abord ;
- **abandonner** : `deck abort <id>` (la campagne s'arrête, worktree et commits restent), puis relancer le
  challenge.
Rien d'autre : pas de revue, pas de réécriture, pas de commit. Termine ici.

**`aborted`** : même sortie que « non terminée » si Adrien n'a pas encore tranché ; s'il a abandonné
volontairement, juge ce qui a été commité (le cas échéant, rien n'est livré : `delivered_sha` nul, pas de tag)
et reporte tout le travail non livré dans la suite (phase 4).

## Phase 2 : relire la livraison

La livraison locale a avancé la base d'un commit unique et posé un tag `v<semver>`.

1. Retrouve le commit : `delivery.delivered_sha`, sinon le tag le plus récent sur la base
   (`git -C <projet> describe --tags --abbrev=0 <base>`). `git show --stat <sha>` : fichiers touchés, message ;
   `git show <tag>` : tag annoté présent et sur ce commit, version conforme à la politique de
   `campagne.md` (mineure par campagne, patch pour une pure correction).
2. Lis le diff (`git show <sha>`), contre `00-plan.md` (objectif, « fini »), contre chaque étape (`dir`) et
   contre les résumés (`summary`). Cherche : ce que l'étape promettait et que le code ne fait pas ; hors
   périmètre ; tests absents ou factices ; régression visible ; fichiers de version, `CHANGELOG`,
   `docs/roadmap.md` oubliés ou en désaccord avec le tag.
3. Feature mise à jour par la livraison : critères cochés **à raison** (chaque case cochée est vérifiable),
   ligne du tableau passée à `livrée` avec le tag réel, ligne de journal ajoutée. Une case cochée à tort se
   décoche dans ta réécriture (c'est une correction) : seule exception permise sur les critères, notée dans
   `revue.md` et visible dans le diff montré à Adrien. Tu ne coches jamais rien toi-même.
4. **Tests**, depuis le checkout principal sur la base (lecture seule : ne rien installer ni modifier ;
   si une commande écrit des artefacts ignorés par git, ça va, sinon arrête-toi) : lance la commande de test
   complète de la livraison, plus celle des étapes dont le résumé te paraît faible. Note le code de retour et
   les lignes utiles. Tests impossibles à lancer : dis-le dans la revue, ne conclus pas à « tout passe ».
5. Classe chaque constat : **bloquant** (critère de la feature faux, régression, test rouge), **correction**
   (à faire dans la prochaine nuit, 01), **remarque** (pas d'action). Décris-les avec chemin et ligne.

## Phase 3 : `revue.md`

Écris `<dir>/revue.md` (le `dir` de la campagne jugée) d'après `references/revue.md`. C'est le seul fichier que
tu écris dans ce dossier. Fais-le avant la réécriture, car les étapes de correction s'y réfèrent par chemin.

## Phase 4 : réécrire la campagne suivante

Lis le tableau « Découpage en campagnes » de la feature : la suivante est la première ligne `planifiée` après
la campagne jugée. Lis ses fichiers `<projet>/.deck/<feature>-<NN+1>/`. N'écris sur aucune campagne déjà
passée, ni sur d'autres que la suivante (et, pour le report, celle d'après ; voir ci-dessous).

1. **Étape 01 = corrections** (`01-corrections.md`) : une étape par correction ou un seul brief si elles
   touchent les mêmes fichiers (deux étapes qui touchent les mêmes fichiers se suivent). Brief autonome : le
   constat recopié (chemin, ligne, attendu, observé), la commande de test qui le prouve, le chemin de
   `revue.md` en contexte à lire. Aucune correction : pas d'étape 01 de ce type, dis-le.
2. **Suite recalibrée** : reprends les étapes prévues, renumérotées derrière les corrections, à jour du code
   réel (chemins, noms, décisions de la nuit). Réestime chaque étape (`campagne.md`, « Budget de nuit ») et fais
   tenir l'ensemble en **6 à 8 h** livraison comprise (5 à 10 étapes de 30 à 90 min). Ce qui dépasse **glisse
   vers la campagne d'après** : ajoute-le en tête de ses étapes (renumérote, même règle de budget, répète
   jusqu'à la dernière). S'il n'y a pas d'après, ajoute une campagne `<feature>-<NN+2>` (dossier complet, ligne
   au tableau). Une campagne qui se vide est supprimée du tableau et du disque, avec l'accord d'Adrien.
3. **Livraison** : régénère l'étape de livraison (plus grand `NN`) pour que numéros, version visée, fichier de
   version et mise à jour de la feature restent exacts. Version visée : mineure ; si la campagne ne contient
   que des corrections, patch.
4. **`00-plan.md`** : objectif, liste des étapes et critères visés à jour ; date de replanification ajoutée dans
   le corps ; frontmatter inchangé (champs du modèle seulement, valeurs texte entre guillemets doubles).
5. **Dernière campagne passée avec des corrections** (aucune campagne `planifiée` après elle) : crée une
   campagne de correction `<feature>-<NN+1>` (étapes de correction, livraison, version en **patch**), ajoute sa
   ligne au tableau (`planifiée`, tag patch). Aucune correction et aucune campagne suivante : la feature est
   livrée ; vérifie que tous les critères sont cochés et dis-le (aucune campagne à écrire). Critère encore non
   coché sans campagne pour le couvrir : propose une campagne.
6. **Tableau de la feature** : mets à jour les lignes des campagnes réécrites (objectif, tag visé). Ne touche
   ni aux critères (sauf décocher une case cochée à tort, phase 2.3), ni au journal, ni à la ligne de la campagne jugée (c'est la livraison qui les a écrits ; si
   elle les a mal écrits, dis-le dans la revue plutôt que de les corriger en silence).

**Montre à Adrien** le diagnostic (bloquants, corrections), la nouvelle liste d'étapes avec durées et ce qui a
glissé, puis **demande l'accord** avant d'écrire les dossiers.

## Phase 5 : validation et commit

1. Pour chaque campagne écrite ou réécrite : `deck check --format <projet>/.deck/<id>` (ou `deck check
   --format <id>` depuis la racine du projet). Code 0 attendu ; sinon corrige jusqu'au vert, les erreurs sont
   toutes listées. `--format` ne contrôle que le manifeste et les étapes : le `deck check` complet se fait le
   soir, juste avant `deck run`. « outil absent du PATH : deck » ou démon d'une version antérieure qui ignore
   `--format` : dis-le à Adrien, ne modifie pas les fichiers pour autant.
2. Montre le diff de la feature (`git -C <projet> diff -- <feature>`) et **demande l'accord d'Adrien**. Alors,
   sur la base (vérifie que tu y es), par pathspec, sans passer par l'index :
   `git -C <projet> commit -m "docs(roadmap): <feature>, campagne <id> relue, suite recalibrée" -- <fichier de la feature>`
   (message en français, sans `Co-Authored-By` ni attribution). Pas d'accord : laisse le fichier modifié et
   dis-le (la livraison locale refuse un checkout sale ; Adrien doit le savoir avant `deck run`).
3. Vérifie : `git -C <projet> show --name-only --format= HEAD` ne liste que la feature, `git status --short`
   vide. Sinon arrête-toi et signale-le, sans réécrire l'historique.

Termine par un récapitulatif court : campagne jugée (`id`, tag, sha), verdict (bloquants, corrections), tests
lancés et résultat, campagnes réécrites ou créées (durée estimée, ce qui a glissé), hash du commit de la feature,
ce qui n'a pas été vérifié, et la commande du soir, **sans la lancer** :

```
deck check <id suivant>
deck run <id suivant>
```
