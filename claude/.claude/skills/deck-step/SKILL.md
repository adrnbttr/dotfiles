---
name: deck-step
description: "À utiliser dès que le prompt commence par « Tu exécutes l'étape … de la campagne … » (prompt envoyé par deck dans tmux) : exécute UNE étape d'une campagne deck dans le worktree courant (manifeste et fichier d'étape, exécution, commit), puis termine toujours par `deck done`. Arguments optionnels : [<00-plan.md> <NN-étape.md>]."
argument-hint: "[<00-plan.md> <NN-étape.md>]"
---

# Étape d'une campagne deck

Tu exécutes UNE étape d'une campagne orchestrée par deck. Arguments : `$ARGUMENTS`

- `$0` : le manifeste (`00-plan.md`). `$1` : le fichier d'étape (`NN-étape.md`).
- Sans argument, le fichier d'étape est celui cité dans le prompt de deck :
  « Lis d'abord le fichier d'étape : <chemin> ». Le manifeste est alors `00-plan.md`, dans le même dossier.

## Cadre

- Les variables `DECK_*` sont déjà dans l'environnement. Ne les invente jamais, ne les modifie jamais.
- Reste dans ce worktree. N'en sors pas, ne touche aucun autre dépôt ni checkout.
- La boucle `--autonome` de `/lead` (hook `Stop` qui relance) n'est PAS utilisée. Elle empêcherait de t'arrêter pour poser une question.
- Ne termine jamais l'étape sans avoir lancé `deck done` (ok ou failed). Une question à Adrien n'est pas une fin d'étape : tu t'arrêtes pour attendre la réponse (deck voit `waiting`), puis tu reprends l'étape jusqu'à `deck done`.

## Séquence

1. **Lire** le manifeste puis le fichier d'étape. L'étape est le plan validé : ne demande aucune validation, ne contrôle pas le modèle. Réalise exactement ce qu'elle demande.
2. **Exécuter** selon la doctrine habituelle :
   - délègue le code et les tests aux sous-agents `worker` (sous OpenCode : `implementer`, ou `chore` si mécanique) ;
   - exploration : `scout` (sous OpenCode : `explore`) ;
   - lance toi-même les tests finaux ;
   - fais relire par `reviewer` (sous OpenCode : `challenger`) avant de conclure, et corrige ses défauts.
3. **Commiter** sur la branche courante (étape ordinaire ; pour l'étape de livraison, voir plus bas).
   - Commit de sauvegarde `wip(étape NN): <titre de l'étape>` (`NN` sur deux chiffres), message en français,
     sans `Co-Authored-By` ni attribution (outil, agent, modèle).
   - Fichiers ajoutés par leur chemin (`git add <fichier>…`), jamais `git add -A`, `git add .` ni
     `git commit -a` : seulement les fichiers de l'étape. Un fichier non suivi inattendu : ne pas l'ajouter,
     le signaler dans le summary de `deck done`.
   - Rien à committer (étape sans modification) : ne pas créer de commit vide et le dire dans le summary.
     `deck done --status ok` exige au moins un commit non vide depuis le début de la tentative (refus code 1
     sinon, `guard.rs:59-75`) : si aucun commit n'existe, conclure `failed` avec ce motif, sauf si un commit
     de la tentative précédente (reprise) couvre déjà l'étape.
   - Jamais de `git push`, jamais de PR.
4. **Terminer** par la commande :
   `deck done --status ok --summary "<fait / non vérifié / restes>"`
5. **Traiter le code de sortie de `deck done`.**
   - `0` : accepté. Tu as fini.
   - `1` : refus (garde-fou git, contexte absent). Lis le motif sur stderr, corrige (arbre sale, commit manquant…), puis relance `deck done`.
   - `2` : démon injoignable ou muet. La commande a pu être appliquée : relance-la une fois, lis stderr.
   - Si le motif n'est pas corrigeable : pose la question à Adrien et attends sa réponse (voir 6), puis reprends.
6. **Blocage ou décision à prendre** : pose la question et arrête-toi pour attendre la réponse. deck voit alors l'état `waiting`. Ne lance pas `deck done` pour cette pause : ce n'est pas une fin d'étape. Une fois la réponse reçue, reprends l'étape et termine par `deck done` (4 ou 7).
7. **Étape impossible** : `deck done --status failed --summary "<motif>"`. Traite son code de sortie comme en 5.

## Étape de livraison (la dernière)

- Reconnaissance : deck ne la distingue pas (pas de champ `role`, ADR 0023 D3). C'est l'étape dont le `NN` est le
  plus grand parmi les `NN-*.md` du dossier du manifeste (règle de `deck-plan`, `references/campagne.md`).
- Pour elle, **son fichier fait foi, à la lettre** (copie de `02-livraison.md` du modèle) : version, CHANGELOG,
  roadmap, fichier de feature (critères cochés, ligne du tableau, ligne de journal), tests complets, regroupement
  en **un seul commit** au-dessus de `base` (`git reset --soft $(git merge-base <base> HEAD)` puis `git commit`),
  tag annoté `vX.Y.Z`, contrôle, puis `deck done`. Le commit `wip(étape NN)` générique de 3 est remplacé par la
  procédure du fichier (qui fait son propre commit `wip` avant de regrouper) ; ne pas committer en plus après le
  regroupement : la branche doit porter exactement un commit.
- Ce que tu ne fais PAS : fusionner `base`, supprimer la branche ou le worktree, `checkout`/`merge`/`reset`/`commit`
  sur `base` ou dans le checkout principal. deck avance `base` en avance rapide, retire le worktree et la branche,
  une fois la campagne `ready` (ADR 0023 D6). Le tag, lui, est posé par toi (D4, point 4).
- Tests complets en échec : ne pas regrouper, ne pas taguer, annuler les modifications de version, puis
  `deck done --status failed` (section « Si les tests échouent » du fichier d'étape).
