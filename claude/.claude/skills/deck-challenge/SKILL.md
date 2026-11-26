---
name: deck-challenge
description: "À utiliser quand Adrien demande de juger la nuit deck (« deck-challenge », « challenge la campagne d'hier », « relis la nuit », « prépare la suivante »). Trouve la dernière campagne passée (`deck status --json`) ; si elle n'est pas terminée, rend son état (motif de refus de livraison si `ready`) et propose la conduite adaptée, rien d'autre ; sinon relit le commit livré sur la base (tag), lance les tests, écrit `revue.md` dans le dossier de la campagne, réécrit la campagne suivante de la feature (étape 01 de corrections, suite recalibrée pour une nuit de 6 à 8 h, surplus reporté en cascade jusqu'à la dernière campagne, voire une campagne créée), crée une campagne de correction si c'était la dernière, valide avec `deck check --format`. N'écrit que dans `.deck/` (non versionné) : ni fichier de feature, ni commit. Lecture seule sur le code."
---

# Challenger la campagne de la veille

Tu juges et tu replanifies, tu ne codes pas. Tu es indépendant de l'agent qui a exécuté la nuit (`agent:` du
manifeste de la campagne) : ne lui fais pas confiance sur parole, relis le code et rejoue les tests.

**Lecture seule sur le projet.** Seul `<projet>/.deck/` (non versionné) reçoit des écritures : le `revue.md` de
la campagne jugée et les dossiers des campagnes suivantes. **Tu ne modifies jamais le fichier de feature et tu ne
fais aucun commit** (même règle que `deck-plan`) : la feature ne change que par Adrien ou par l'étape de livraison
d'une campagne. Tu ne corriges aucun défaut dans le code, tu ne touches ni au checkout principal ni aux branches,
et tu ne lances jamais `deck run`, `git push`, `gh`.

**Horaires** : si l'`AGENTS.md` du projet restreint les heures d'écriture ou de planification, respecte-les ;
hors de ces heures, arrête-toi avant d'écrire et dis-le.

Références (chemins relatifs au skill, partagées avec `deck-plan`, à lire avant d'écrire) :
- `../deck-plan/references/feature.md` : modèle de la feature (critères, tableau « Découpage », journal) ;
- `../deck-plan/references/campagne.md` : règles d'écriture d'une campagne (nommage, frontmatter, guillemets
  YAML, agent, `model`, briefs autonomes et leurs pièges, `wip`, livraison, niveau de version, budget de nuit,
  contrôle et relecture adverse) ;
- `../deck-plan/references/controles.md` : contrôles communs (checkout propre, aucun commit, outils contrôlés
  par `deck check`) ;
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
   Coût : `cost_micro_usd` et `cost_tokens` ne comptent que la session principale de l'étape ; avec OpenCode,
   les sous-sessions (sous-agents délégués) n'y sont pas incluses (ADR 0020 D10). Ne présente pas ces champs
   comme le coût total de la nuit, et dis-le dans la revue si tu les cites.
2. Garde les campagnes dont `repo` est le projet. Demande à Adrien l'`id` si le projet n'est pas évident. La
   campagne de la veille est la plus récente (`created_at`) de ces campagnes qui appartient à la feature
   (`id` = `<feature>-<NN>`). Dis laquelle tu retiens et pourquoi ; en cas de doute, demande.
3. Aucune campagne trouvée : arrête-toi (rien n'a tourné, rien à juger) et dis-le.
4. Contrôles sur le projet : « Checkout propre » de `../deck-plan/references/controles.md`.

## Phase 1 : la campagne est-elle terminée ?

**Terminée** = `state` `completed` ou `aborted`. Une campagne `completed` a `delivery.delivered_sha` non nul
(en mode `local`).

**Non terminée** (`setup`, `running`, `paused`, `ready`) : tu ne juges pas et tu ne réécris rien. Rends l'état en
quelques lignes (étapes `done`/`failed`/`crashed`, `pause`, `summary` des étapes en échec) puis, selon l'état :

- **`setup`, `running`, `paused`** : propose seulement deux issues à Adrien, commandes à lui donner sans les
  lancer :
  - **reprendre** : `deck resume <id> <NN>` (étape en attente après un échec ou un plantage), ou
    `deck retry <id> <NN>` (relancer l'étape en échec ou plantée) ; `deck attach <id> <NN>` pour regarder la
    session d'abord ;
  - **abandonner** : `deck abort <id>` (la campagne s'arrête, worktree et commits restent), puis relancer le
    challenge.
- **`ready`** (toutes les étapes faites, livraison en attente) : affiche `delivery.refusal` tel quel (motif du
  refus de livraison). deck reprend seul la livraison dès que la cause disparaît : il n'y a rien à relancer
  (`resume` et `retry` ne s'appliquent pas à `ready`) et `abort` n'est pas la première issue. Renvoie Adrien à
  la conduite du modèle, `../deck-plan/references/modele-campagne/02-livraison.md`, sections « Ce qui se passe
  ensuite » et « Si `<base>` a avancé » : checkout principal à remettre propre et sur `<base>` ;
  `git worktree prune` pour une branche extraite dans un worktree supprimé ; si `<base>` a avancé, rebase de la
  branche de campagne sur `<base>` puis tag « à nous » reposé sur la nouvelle tête. Dis lequel de ces cas le
  motif désigne ; tu ne fais aucun de ces gestes toi-même. `abort` seulement si Adrien renonce à livrer.

Rien d'autre : pas de revue, pas de réécriture, pas de commit. Termine ici.

**`aborted`** : même sortie que « non terminée » si Adrien n'a pas encore tranché ; s'il a abandonné
volontairement, juge ce qui a été commité (le cas échéant, rien n'est livré : `delivered_sha` nul, pas de tag)
et reporte tout le travail non livré dans la suite (phase 4).

## Phase 2 : relire la livraison

La livraison locale a avancé la base d'un commit unique et posé un tag `v<semver>`.

1. Retrouve le commit : `delivery.delivered_sha`, sinon le tag le plus récent sur la base
   (`git -C <projet> describe --tags --abbrev=0 <base>`). `git show --stat <sha>` : fichiers touchés, message ;
   `git show <tag>` : tag annoté présent et sur ce commit, version cohérente avec le niveau écrit au point 2 de
   l'étape de livraison (mineure, correctif ou `1.0.0`) appliqué à la version précédente de la base (dernier
   tag avant celui-ci). Tu constates, tu ne recalcules aucune version pour la suite.
2. Lis le diff (`git show <sha>`), contre `00-plan.md` (objectif, « fini »), contre chaque étape (`dir`) et
   contre les résumés (`summary`). Cherche : ce que l'étape promettait et que le code ne fait pas ; hors
   périmètre ; tests absents ou factices ; régression visible ; fichiers de version, `CHANGELOG`,
   `docs/roadmap.md` oubliés ou en désaccord avec le tag.
3. Feature mise à jour par la livraison : critères cochés **à raison** (chaque case cochée est vérifiable),
   ligne de la campagne présente au tableau en `livrée` avec le tag réel, ligne de journal ajoutée. Une case
   cochée à tort, une ligne fausse ou absente : c'est un **constat de `revue.md`** et une **correction dans l'étape 01**
   de la campagne suivante, dont la livraison corrige la feature (décoche la case, corrige la ligne). Tu ne
   modifies pas la feature toi-même.
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

La campagne suivante est le dossier `<projet>/.deck/<feature>-<NN+1>/` écrit par `deck-plan` (son `00-plan.md`
porte la ligne « Feature : `roadmap/<version>/<feature>.md` ») ; le tableau de la feature ne liste que les campagnes
livrées. Lis ses fichiers. N'écris sur aucune campagne déjà
passée. Tu écris sur la suivante et, pour le report en cascade (point 2), sur les campagnes d'après de la même
feature jusqu'à la dernière, plus une campagne créée au besoin ; sur aucune autre.

1. **Étape 01 = corrections** (`01-corrections.md`) : une étape par correction ou un seul brief si elles
   touchent les mêmes fichiers (deux étapes qui touchent les mêmes fichiers se suivent). Brief autonome : le
   constat recopié (chemin, ligne, attendu, observé), la commande de test qui le prouve, le chemin de
   `revue.md` en contexte à lire. Aucune correction : pas d'étape 01 de ce type, dis-le.
2. **Suite recalibrée** : reprends les étapes prévues, renumérotées derrière les corrections, à jour du code
   réel (chemins, noms, décisions de la nuit). Réestime chaque étape (`campagne.md`, « Budget de nuit ») et fais
   tenir l'ensemble en **6 à 8 h** livraison comprise (5 à 10 étapes de 30 à 90 min). Ce qui dépasse **glisse
   vers la campagne d'après** : ajoute-le en tête de ses étapes (renumérote, même règle de budget) ; si elle
   déborde à son tour, son surplus glisse vers la suivante, et ainsi de suite jusqu'à la dernière campagne de
   la feature. Si la dernière déborde, crée une campagne `<feature>-<NN>` de plus (numéro suivant, dossier
   complet dans `.deck/`, niveau mineure ; si l'ancienne dernière portait le niveau `1.0.0`, il passe à la
   nouvelle dernière et l'ancienne redevient mineure). Une campagne qui se vide est supprimée du disque, avec l'accord d'Adrien.
3. **Livraison** : régénère l'étape de livraison (plus grand `NN`) de chaque campagne réécrite pour que les numéros
   d'étapes, le niveau de version (point 2), le fichier de version et la mise à jour de la feature restent
   exacts. Niveau : celui du plan ; **correctif** si la campagne ne contient plus que des corrections. Jamais de
   numéro de version : la livraison le calcule au moment de livrer. Elle porte aussi les corrections de la feature relevées en phase 2.3 (case à
   décocher, ligne du tableau à corriger ou ajouter), chacune avec le chemin de `revue.md`.
4. **`00-plan.md`** : objectif, liste des étapes et critères visés à jour ; date de replanification ajoutée dans
   le corps ; frontmatter inchangé (règles de `campagne.md`, « Frontmatter »). Chaque `00-plan.md` des
   campagnes réécrites ou créées porte son `id`, son objectif et la ligne
   « Feature : `roadmap/<version>/<feature>.md` ». Leur ligne du tableau « Découpage » n'est **pas** écrite par le
   challenge : la livraison de chaque campagne l'ajoute si elle est absente.
   Briefs des campagnes réécrites ou créées : `../deck-plan/references/campagne.md`, « Briefs d'étape autonomes » ;
   aligne sur le commit livré réel, dans le `00-plan.md` des campagnes suivantes, la liste « ce que les campagnes
   précédentes ont livré » et les « Conventions du projet ».
   **Agent** : règle de `campagne.md`, « Frontmatter » (cas où l'agent est imposé) ; sinon garde l'agent de la
   campagne.
5. **Dernière campagne passée avec des corrections** (aucun dossier `.deck/<feature>-<NN+1>/`) : crée une
   campagne de correction `<feature>-<NN+1>` (étapes de correction, livraison, niveau **correctif**) ; sa
   livraison ajoutera sa ligne au tableau. Aucune correction et aucune campagne suivante : la feature est
   livrée ; vérifie que tous les critères sont cochés et dis-le (aucune campagne à écrire). Critère encore non
   coché sans campagne pour le couvrir : propose une campagne.
6. **Fichier de feature** : tu n'y touches pas. L'objectif des campagnes réécrites vit dans leur
   `00-plan.md`, le niveau de version au point 2 de leur livraison ; critères, tableau et journal sont écrits
   par les livraisons.

**Montre à Adrien** le diagnostic (bloquants, corrections), la nouvelle liste d'étapes avec durées et ce qui a
glissé, puis **demande l'accord** avant d'écrire les dossiers.

## Phase 5 : validation, aucun commit

1. Pour chaque campagne écrite ou réécrite : `deck check --format <id>` depuis la racine du projet. Code 0
   attendu ; sinon corrige jusqu'au vert, les erreurs sont toutes listées. `--format` ne contrôle que le
   manifeste et les étapes : le `deck check` complet se fait le soir, juste avant `deck run`. « outil absent du
   PATH » ou démon d'une version antérieure qui ignore `--format` : `../deck-plan/references/controles.md`.
2. **Relecture adverse**, toujours, sauf si aucune campagne n'a été écrite ou réécrite, des campagnes réécrites
   ou créées : `../deck-plan/references/campagne.md`, « Contrôle » (sous-agent `challenger`, correction, puis
   `deck check --format` relancé).
3. « Vérification finale : aucun commit » de `../deck-plan/references/controles.md`.

Termine par un récapitulatif court : campagne jugée (`id`, tag, sha), verdict (bloquants, corrections), tests
lancés et résultat, campagnes réécrites ou créées (durée estimée, ce qui a glissé), décisions techniques que ni
la feature ni la nuit ne tranchaient et que tes réécritures ont fixées (à valider par Adrien), décisions modifiées
depuis l'accord (`campagne.md`, « Contrôle »), confirmation qu'aucun commit n'a été fait, ce qui n'a pas été
vérifié, et la commande du soir, **sans la lancer** :

```
cd <projet> && deck check <id suivant>
cd <projet> && deck run <id suivant>
```
