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
   - délègue le code et les tests aux sous-agents `worker` ;
   - exploration : `scout` ;
   - lance toi-même les tests finaux ;
   - fais relire par `reviewer` avant de conclure, et corrige ses défauts.
3. **Commiter** sur la branche courante. Jamais de `git push`, jamais de PR.
4. **Terminer** par la commande :
   `deck done --status ok --summary "<fait / non vérifié / restes>"`
5. **Traiter le code de sortie de `deck done`.**
   - `0` : accepté. Tu as fini.
   - `1` : refus (garde-fou git, contexte absent). Lis le motif sur stderr, corrige (arbre sale, commit manquant…), puis relance `deck done`.
   - `2` : démon injoignable ou muet. La commande a pu être appliquée : relance-la une fois, lis stderr.
   - Si le motif n'est pas corrigeable : pose la question à Adrien et attends sa réponse (voir 6), puis reprends.
6. **Blocage ou décision à prendre** : pose la question et arrête-toi pour attendre la réponse. deck voit alors l'état `waiting`. Ne lance pas `deck done` pour cette pause : ce n'est pas une fin d'étape. Une fois la réponse reçue, reprends l'étape et termine par `deck done` (4 ou 7).
7. **Étape impossible** : `deck done --status failed --summary "<motif>"`. Traite son code de sortie comme en 5.
