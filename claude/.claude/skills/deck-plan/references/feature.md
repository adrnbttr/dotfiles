# Modèle de fichier de feature

Un projet range ses features dans `roadmap/<version>/<feature>.md` (ex. `roadmap/v1/export-csv.md`), versionné
dans le dépôt, **une feature par fichier**. `<feature>` : minuscules, chiffres, tirets. C'est l'entrée de
`deck-plan` : il découpe la feature en N campagnes d'une nuit, écrites dans `.deck/` (non versionné), **sans modifier ce
fichier ni committer**. Ensuite, la livraison de chaque campagne (et `deck-challenge`) le font vivre.

Recopier le modèle ci-dessous ; supprimer les commentaires `<!-- -->` une fois remplis. Le fichier est lu par
des sessions sans la conversation du jour : rien ne doit supposer un contexte oral.

```markdown
# <Titre de la feature>

## Objectif

<!-- 2 à 5 phrases : ce que la feature apporte, pour qui, ce qui change pour l'utilisateur. Observable. -->

## Contexte et ADR liés

<!-- Pourquoi maintenant. Liens précis : ADR (`docs/adr/NNNN-titre.md`), code existant à connaître
(`chemin/fichier`), contraintes (compatibilité, performances), décisions déjà prises. -->

## Critères d'acceptation

<!-- Vérifiables un par un, par une commande ou une observation. Cochés par la livraison de la campagne
qui les satisfait, jamais avant. -->

- [ ] <critère 1>
- [ ] <critère 2>

## Découpage en campagnes

<!-- Rempli par `deck-plan`, une ligne par campagne, toutes écrites d'avance. `id` = `<feature>-<NN>`.
Statut : planifiée, livrée, à refaire. Tag : version visée (`v0.N.0`), mise à jour à la livraison.
`deck-challenge` réécrit la ligne de la campagne suivante (corrections d'abord, surplus reporté). -->

| id | Objectif | Statut | Tag |
|---|---|---|---|
| `<feature>-01` | <objectif en une ligne> | planifiée | v0.N.0 |
| `<feature>-02` | <objectif en une ligne> | planifiée | v0.N+1.0 |

## Hors périmètre

<!-- Ce qui est tentant mais n'est pas dans cette feature : autre feature, version suivante, jamais. -->

- <élément>

## Journal

<!-- Une ligne par campagne livrée, ajoutée par la livraison dans son commit unique. Ne pas la remplir
à la planification. -->

| id | Date | Tag | Fait | Reste |
|---|---|---|---|---|
```

## Règles d'usage

- **Critères** : formulés comme des faits testables (« `mon-projet export --format csv` écrit un CSV valide »),
  pas comme des tâches. Une feature sans critère cochable ne se planifie pas : le demander à Adrien.
- **Découpage** : N campagnes de 6 à 8 h chacune (budget et estimation : `campagne.md`). L'`id` de chaque
  campagne est `<feature>-<NN>` (`NN` sur deux chiffres, ordre d'exécution). Le tableau est la source de vérité
  de l'ordre et des tags visés.
- **Livraison** : la dernière étape de chaque campagne coche les critères désormais satisfaits, passe le
  statut de la ligne à « livrée », fixe le tag réel et ajoute une ligne au journal (id, date, tag, fait, reste),
  le tout dans le commit unique de la campagne.
- **Dernière campagne avec corrections** : si la relecture de la dernière campagne trouve des corrections,
  `deck-challenge` ajoute une campagne de correction au tableau (tag en patch).
- **Pas de commit de planification** : `deck-plan` n'écrit que dans `.deck/` ; le tableau « Découpage » se remplit
  à la livraison de chaque campagne (ligne ajoutée si absente), dans le commit unique de la campagne.
- **Lien roadmap globale** : à la fin de la v1 (dernière feature livrée), la politique de tag fait passer à
  `v1.0.0` (voir `campagne.md`).
