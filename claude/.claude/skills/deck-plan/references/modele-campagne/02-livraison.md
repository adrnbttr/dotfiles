---
title: Préparer la livraison locale
---

# Étape 02 : préparer la livraison

Cette étape est la dernière de la campagne (ADR 0023 D3, D4). Elle ne développe rien : elle met à jour
la version, lance tous les tests, regroupe le travail en **un seul commit**, pose un tag annoté, puis
déclare la fin. Seul le travail dans cette branche et ce worktree est de ton ressort ; la suite est
faite par deck.

## Objectif

La branche de campagne porte exactement un commit au-dessus de `<base>`, avec la version à jour et le
tag annoté `vX.Y.Z` posé sur ce commit, tests complets au vert.

`<base>` est le champ `base` de `00-plan.md` (ici `main`).

## Interdits

- Jamais `git push` (ni `git push .`), jamais `gh`.
- Ne pas toucher au checkout principal du dépôt, ni à la branche `<base>` : aucun `checkout`, `merge`,
  `reset` ou `commit` dessus ; reste dans ce worktree.
- Ne pas supprimer la branche de campagne ni le worktree (`git branch -d`, `git worktree remove` :
  c'est deck qui le fait, ADR 0023 D6).
- Pas de `git reset --hard`, pas de `--force`.

## Déroulé

Dans l'ordre. Si une vérification échoue, voir « Si les tests échouent ».

1. **Vérifier l'état.** `git status --porcelain` doit être vide au départ. Lire `00-plan.md` pour
   `<base>` et les critères de « fini ».

   Un fichier **non suivi et non ignoré** dans le worktree bloquerait la livraison (ADR 0023 D6,
   précondition (f) : deck ne retire jamais un worktree avec `--force`). Pour chacun : le supprimer
   s'il a été produit par une étape (artefact, fichier temporaire) ; ou l'ajouter au `.gitignore`
   s'il est légitime (fichier local copié par `setup`, sortie d'outil), en le justifiant dans le
   message de commit ; sinon, `deck done --status failed` avec le motif.

   **Reprise.** Si cette étape a déjà été menée (nouvelle tentative) et que `HEAD` est déjà un commit
   unique au-dessus de `git merge-base <base> HEAD` (décompte `1`, voir le point 10) portant un tag
   `v*` « à nous » (règle du point 9), **refaire le regroupement pour produire un nouveau commit** :

   ```
   git reset --soft $(git merge-base <base> HEAD)
   sleep 1     # horodatage différent : sans cela le SHA pourrait rester identique
   git commit -C ORIG_HEAD --reset-author
   git tag -d vX.Y.Z      # le tag à nous, sur l'ancien commit
   git tag -a vX.Y.Z -m "vX.Y.Z : <objectif de la campagne en une ligne>"
   ```

   puis le contrôle final (point 10) et `deck done` (point 11). Pourquoi : après `deck retry`, le
   garde-fou de `done ok` exige au moins un commit non vide depuis le début de la tentative
   (`start_ref..HEAD`) ; avec `--keep`, la nouvelle `start_ref` est le `HEAD` actuel, donc « ne rien
   refaire » ferait refuser `done ok`. Avec `--reset`, `HEAD` revient avant le regroupement et le
   tag de la tentative précédente est resté (contenu par la sauvegarde `deck/backup/<id>/…` de
   l'ancienne tête) : il est « à nous » (point 9), on le supprime et on le repose au point 9.

2. **Choisir le numéro de version `X.Y.Z`** en appliquant la politique de version (règle de
   `references/campagne.md` du skill `deck-plan`), à partir de la version actuelle du fichier de
   version. En bref :
   - une campagne livre une version **mineure** : `0.N.0` (`0.N+1.0` depuis la précédente) ;
   - une campagne de **pure correction** (aucune nouveauté, aucune rupture) livre un **correctif**
     `0.N.P+1` ;
   - la dernière campagne de la roadmap v1 livre `v1.0.0` ; ensuite, `1.N.0` par campagne ;
   - **majeur** (`X+1.0.0`) seulement pour une rupture de compatibilité une fois `X` ≥ 1 ; tant que
     `X` vaut 0, une rupture compte comme mineur ;
   - en cas de doute entre deux niveaux, prendre le plus haut.

3. **Mettre à jour la version** dans le fichier de version du projet (`<Cargo.toml / package.json /
   pyproject.toml / VERSION… : à préciser par le plan>`). S'il y a un fichier de verrouillage qui
   porte la version du projet, le régénérer avec l'outil du projet, sans changer les dépendances.

4. **CHANGELOG, s'il existe** (`CHANGELOG.md` à la racine) : ajouter une entrée `X.Y.Z` datée du jour,
   dans le format déjà utilisé par le fichier, qui résume les changements de la campagne. S'il
   n'existe pas, ne pas en créer.

5. **Roadmap** : si le projet en a une (`docs/roadmap.md` ou équivalent), cocher les éléments que la
   campagne a réalisés, sans en cocher d'autres.

6. **Fichier de feature**, si `00-plan.md` en désigne un (ligne « Feature : `roadmap/<version>/<feature>.md` »
   dans le corps ; sinon, passer au point suivant) : dans ce fichier,
   - cocher dans « Critères d'acceptation » ceux que la campagne atteint, sans en cocher d'autres ;
   - dans « Découpage », passer la ligne de la campagne à `livrée` et y inscrire le tag réel
     `vX.Y.Z` choisi au point 2 ;
   - ajouter au « Journal » une ligne `id | date du jour | vX.Y.Z | fait | reste` : `fait` résume ce
     que la campagne a livré, `reste` ce qui manque encore à la feature (ou `rien`).

   Respecter le format du fichier (`references/feature.md`) ; ne pas toucher aux autres lignes.

7. **Tests complets** : la suite entière, pas seulement celle d'une étape :

   ```
   <commande de test complète exacte, par ex. cargo test --workspace && cargo clippy --workspace -- -D warnings>
   ```

   Elle doit réussir (code 0). Sinon, passer à « Si les tests échouent » et s'arrêter là.

8. **Regrouper en un commit.** D'abord, commiter les modifications des points 3 à 6, par chemin (jamais
   `git add -A`, `git add .` ni `git commit -a` : ils embarqueraient un fichier non suivi, et le
   garde-fou de deck ne les regarde pas) :

   ```
   git add <fichier de version> <CHANGELOG.md si modifié> <roadmap si modifiée> <fichier de feature si modifié> <fichier de verrouillage si régénéré>
   git status --short     # ni modification suivie non indexée, ni fichier non suivi inattendu
   git commit -m "wip(étape 02): version vX.Y.Z"
   ```

   Un fichier non suivi inattendu : ne pas l'ajouter, le signaler dans le résumé de `deck done`.
   Puis regrouper : l'index après `reset --soft` contient déjà tout le travail de la campagne, il ne
   faut pas de nouvel `add` :

   ```
   git reset --soft $(git merge-base <base> HEAD)
   git commit -F - <<'MSG'
   <type>(<portée>): <objectif de la campagne en une ligne> (vX.Y.Z)

   <deux à six lignes : ce qui change pour l'utilisateur, les décisions notables>

   Étapes : <liste courte des titres d'étapes, séparés par des points-virgules>
   MSG
   ```

   - `<type>` : `feat`, `fix`, `refactor`, `docs`… selon le contenu dominant ; `<portée>` : le module
     ou l'identifiant de la campagne.
   - Message en français ; la ligne de titre fait 72 caractères ou moins.
   - Ne mentionner ni agent, ni outil, ni `Co-Authored-By`.

9. **Poser le tag annoté** sur ce commit (il faut `-a`, un tag léger est refusé par deck) :

   ```
   git tag -a vX.Y.Z -m "vX.Y.Z : <objectif de la campagne en une ligne>"
   ```

   Les tags sont communs à tout le dépôt (tous les worktrees). Si `vX.Y.Z` existe déjà, `git tag`
   refuse. Règle « tag à nous » : `vX.Y.Z` est réputé posé par **cette campagne** si les deux
   contrôles suivants sont vrais :

   ```
   git merge-base --is-ancestor vX.Y.Z <base>                            # doit ÉCHOUER (code 1) : le tag n'est pas dans <base>
   git branch --contains vX.Y.Z --format='%(refname:short)' | grep -v -e '^deck/<id>$' -e '^deck/backup/<id>/'   # ne doit RIEN afficher
   ```

   Le second contrôle admet seulement la branche de la campagne (`deck/<id>`) et ses sauvegardes
   (`deck/backup/<id>/…`, créées par `deck retry --reset` sur l'ancienne tête, qui contiennent donc
   le tag) ; toute autre branche qui le contient (`deck/autre`, `deck/backup/autre/…`, `main`…) rend
   le tag étranger. Un tel tag (reste d'une tentative précédente) peut être supprimé (`git tag -d vX.Y.Z`) et reposé.
   Tout autre tag existant (dans `<base>`, ou contenu par une autre branche que `deck/<id>` et
   `deck/backup/<id>/…` : autre campagne, déjà livrée) n'est pas à toi : ne pas le supprimer, ne pas inventer un autre numéro. Annuler les
   modifications de version non commitées (`git restore`) puis
   `deck done --status failed --summary "Tag vX.Y.Z déjà présent dans le dépôt : <motif>"`.

10. **Contrôler** (tout doit être vrai) :

   ```
   git status --short                                  # aucune modification suivie ni indexée ; pas de non suivi inattendu
   git rev-list --count $(git merge-base <base> HEAD)..HEAD   # 1
   git for-each-ref --format='%(objecttype) %(*objectname)' refs/tags/vX.Y.Z   # "tag <sha de HEAD>"
   git rev-parse HEAD
   ```

   Si le décompte n'est pas 1, regrouper de nouveau (point 8). Si le tag ne désigne pas `HEAD` et
   qu'il est « à nous » (point 9), le supprimer (`git tag -d vX.Y.Z`) puis le reposer sur `HEAD`.
   Ne jamais supprimer un tag qui n'est pas « à nous ».

11. **Déclarer la fin** :

    ```
    deck done --status ok --summary "Livraison prête : vX.Y.Z, un commit <sha court> sur deck/<id>, tests complets verts."
    ```

## Si les tests échouent

Ne pas regrouper : l'historique des commits `wip(étape NN)` reste intact pour qu'Adrien (ou un
`deck retry`) puisse diagnostiquer. Ne pas poser de tag. Si des modifications de version ont déjà
été faites, les annuler (`git restore` sur ces fichiers) pour laisser l'arbre propre. Puis :

```
deck done --status failed --summary "Tests complets en échec : <commande>, <test ou message d'erreur principal>"
```

## Ce qui se passe ensuite (rien à faire pour toi)

Après `deck done --status ok`, la campagne est `ready`. deck vérifie alors que le checkout principal
est propre et sur `<base>`, que `<base>` est ancêtre de la branche, qu'elle porte exactement un
commit et qu'un tag annoté `vX.Y.Z` est sur sa tête. Si tout est bon, il avance `<base>` en avance
rapide, retire le worktree, supprime la branche et passe la campagne en `completed`. Il vérifie aussi
que le worktree est propre, fichiers non suivis compris (précondition (f)) : d'où la consigne du point
1 sur les fichiers non suivis. Si une condition manque (checkout principal sale ou pas sur `<base>`,
branche divergée, worktree contenant des commits absents de `<base>`, branche extraite dans un
worktree enregistré mais supprimé : `git worktree prune` règle ce cas…), ou si un geste git échoue
(le message d'erreur de git devient le motif affiché), la campagne attend avec un motif visible dans `deck status` et la TUI, et
reprend d'elle-même quand la cause disparaît. Dans tous les cas, la session n'a plus rien à faire
après `deck done`. En `delivery: local`, `base` doit être un nom de branche locale (pas `refs/…`,
pas `origin/…`) : `deck check` le refuse sinon.

## Si `<base>` a avancé (branche divergée)

Si Adrien rebase la branche à la main sur la nouvelle `<base>` (hors de cette session), la tête
change : le tag posé sur l'ancienne tête ne désigne plus la tête et deck refuse la livraison. Il faut
alors reposer le tag sur la nouvelle tête. Le tag de l'ancienne tête est « à nous » (point 9) :
le supprimer (`git tag -d vX.Y.Z`) puis le reposer est permis, comme pour une reprise.
