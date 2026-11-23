# Modèle de campagne deck

Ce dossier est le modèle de référence d'une campagne (ADR [0004](../../adr/0004-format-campagne-et-etape.md),
section « Conséquences »). Il sert de point de départ à Adrien et au skill `deck-plan` pour écrire une
campagne de la boucle jour/nuit : planifiée le jour, exécutée la nuit avec `agent: opencode` et
`delivery: local`, livrée sans push (ADR [0023](../../adr/0023-livraison-locale.md)).

> **Attention** : tant que le jalon J7 (adaptateur OpenCode) n'est pas fusionné, `deck run` échoue
> avec `agent: opencode`. Utiliser `agent: claude` en attendant.

## Contenu

| Fichier | Rôle |
|---|---|
| `00-plan.md` | Manifeste : frontmatter YAML commenté (chaque champ : obligatoire ou non, valeurs, défaut), puis objectif, contraintes communes et définition de « fini ». |
| `01-etape-type.md` | Une étape type, brief autonome : objectif, fichiers, contraintes, hors périmètre, test, critère de fin, commit `wip(étape NN): …`, `deck done`. |
| `02-livraison.md` | Dernière étape : version semver, CHANGELOG, roadmap, fichier de feature, tests complets, regroupement en un commit, tag annoté `vX.Y.Z`, `deck done`. |

## Journée type

- **Soir** : Adrien lance `deck run <id>` sur la campagne planifiée le jour.
- **Nuit** : les étapes s'exécutent dans l'ordre, puis l'étape de livraison : commit unique et tag
  annoté `vX.Y.Z`, puis deck avance `main` en avance rapide (livraison locale, rien n'est poussé).
  L'étape de livraison met aussi à jour le fichier de feature (critères cochés, statut, tag, journal).
- **Matin** : `deck-challenge` juge la campagne livrée et réécrit la campagne suivante.
- **Journée** : Adrien relit le résultat, corrige ou relance, puis planifie la suite.

## Copier le modèle

```
mkdir -p <projet>/.deck/<id>
cp docs/specs/modele-campagne/0*.md <projet>/.deck/<id>/
```

- `<id>` : nom du dossier, sans date, identique au `id` du manifeste. Pour une campagne issue d'une
  feature, `<feature>-<NN>` (ex. `export-csv-02`) ; sinon un slug libre (minuscules, chiffres, tirets).
  Les dates de planification et de passage se notent dans le corps de `00-plan.md`, pas dans le nom.
- `deck run <id>` et `deck check <id>` résolvent `<racine git>/.deck/<id>/` ; `deck check --format <id>`
  ne contrôle que le format (ADR 0029).
- Ne pas copier ce `README.md` : il serait ignoré (voir plus bas) mais n'a rien à faire dans une campagne.
- Remplacer dans `00-plan.md` : `id`, `repo` (valeur d'exemple, à remplacer), `base`, `setup`, puis le
  corps. Supprimer les commentaires `#` devenus inutiles (ils sont permis, pas obligatoires).
- Dupliquer `01-etape-type.md` pour chaque étape de développement, avec un numéro et un slug propres.
  La livraison est la dernière étape par position (ADR 0023 D3) : quand on ajoute des étapes,
  renuméroter l'étape de livraison (par ex. `07-livraison.md`) pour qu'elle garde le plus grand `NN`,
  et faire suivre ses références à « l'étape 02 » dans le plan et le texte.
- Lancer `deck check <dossier>` avant `deck run` : il valide le frontmatter, les noms et les corps.

## Règles de nommage des étapes

- `NN-slug.md`, `NN` sur deux chiffres de `01` à `99` (`00` est réservé au manifeste `00-plan.md`).
- `slug` : `^[a-z0-9]+(-[a-z0-9]+)*$`, 64 caractères au plus (pas d'accent, pas de majuscule, pas de `_`).
- L'ordre d'exécution suit `NN` ; les trous sont permis ; deux fichiers de même `NN` sont refusés.
- Le corps ne doit pas être vide (frontmatter exclu).
- Le message du commit de chaque étape est `wip(étape NN): <titre>`. Convention portée par le
  brief de l'étape (ADR 0023 D1) ; deck ne la vérifie pas.

## Fichiers ignorés par la découverte

La découverte ne retient que les fichiers `.md` dont le nom commence par un chiffre, hors `00-plan.md`
(`is_step_candidate`, `crates/deck-adapters/src/manifest/mod.rs`). Donc :

- `README.md`, `notes.md`, `revue.md` sont ignorés. Un fichier `revue.md` (compte rendu de la revue du
  matin, notes de planification) peut cohabiter avec les étapes sans être exécuté. Ne pas lui donner
  un nom qui commence par un chiffre.
- Attention à l'inverse : un `.md` qui commence par un chiffre et qui n'est pas de la forme `NN-slug.md`
  (`1-x.md`, `100-x.md`, `00-x.md`) est refusé par `deck check`, pas ignoré.

## Pour aller plus loin

- [ADR 0004](../../adr/0004-format-campagne-et-etape.md) : format de la campagne et de l'étape.
- [ADR 0006](../../adr/0006-git-et-pr.md) : worktree, commits, ce que l'agent a le droit de faire
  (jamais de push ; `gh` interdit), amendée par 0023 pour `delivery: local`.
- [ADR 0023](../../adr/0023-livraison-locale.md) : livraison locale (D2 : champ `delivery`, section
  `pr` interdite ; D3 : la dernière étape prépare la livraison ; D4 : gestes de l'agent ; D6 : gestes de deck).
