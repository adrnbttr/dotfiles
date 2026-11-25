# Modèle de fichier de feature

Un projet range ses features dans `roadmap/<version>/<feature>.md` (ex. `roadmap/v1/export-csv.md`), versionné
dans le dépôt, **une feature par fichier**. `<feature>` : minuscules, chiffres, tirets. C'est l'entrée de
`deck-plan` : il découpe la feature en N campagnes d'une nuit, écrites dans `.deck/` (non versionné), **sans modifier ce
fichier ni committer**. Ensuite, seule la livraison de chaque campagne le fait vivre (et Adrien, pour le cadrage).

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

<!-- Vide à la création : en-tête seul. Une ligne par campagne livrée, ajoutée par l'étape de livraison
de cette campagne dans son commit unique. `id` = `<feature>-<NN>`. Statut : livrée. Tag : tag réel posé
par la livraison. Les campagnes à venir vivent dans `.deck/<feature>-<NN>/00-plan.md`, pas ici. -->

| id | Objectif | Statut | Tag |
|---|---|---|---|

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
  campagne est `<feature>-<NN>` (`NN` sur deux chiffres, ordre d'exécution). Avant livraison, l'ordre et les tags visés
  vivent dans `.deck/<feature>-<NN>/00-plan.md` ; le tableau ne liste que les campagnes livrées.
- **Livraison** : la dernière étape de chaque campagne coche les critères désormais satisfaits, ajoute la
  ligne de la campagne au tableau (`id | objectif | livrée | vX.Y.Z`, tag réel) si elle est absente, sinon la
  met à jour, et ajoute une ligne au journal (id, date, tag, fait, reste), le tout dans le commit unique de la
  campagne.
- **Dernière campagne avec corrections** : si la relecture de la dernière campagne trouve des corrections,
  `deck-challenge` crée une campagne de correction dans `.deck/` (niveau correctif) ; sa ligne entre au tableau à sa
  livraison.
- **Pas de commit de planification** : `deck-plan` n'écrit que dans `.deck/` ; le tableau « Découpage » se remplit
  à la livraison de chaque campagne (ligne ajoutée si absente), dans le commit unique de la campagne.
- **Lien roadmap globale** : la dernière campagne de la roadmap v1 a le niveau `1.0.0` (politique de version :
  `campagne.md`).
