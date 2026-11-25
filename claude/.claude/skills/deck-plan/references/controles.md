# Contrôles communs à `deck-plan` et `deck-challenge`

Blocs repris tels quels par les deux skills. Ils ne touchent qu'au projet (`<projet>`), jamais à une campagne
en cours.

## Checkout propre (phase 0, avant toute écriture)

- Checkout principal sur la branche de base (`git -C <projet> branch --show-current`), sans fichier modifié ni
  indexé (`git -C <projet> status --short` vide, hors `.deck/` ignoré).
- Sinon arrête-toi et dis ce qui ne va pas : tu ne changes pas de branche et tu ne nettoies rien à la place
  d'Adrien.
- Note `git -C <projet> log -1 --format=%H` : il sert à la vérification finale.

## Vérification finale : aucun commit

- `git -C <projet> status --short` est vide (hors `.deck/` ignoré) et `git -C <projet> log -1 --format=%H` n'a
  pas bougé depuis la phase 0.
- Sinon arrête-toi et signale-le, sans réécrire l'historique.

## Outils contrôlés par `deck check` et « outil absent du PATH »

- `deck check <id>` (contrôle complet) exige dans le `PATH` du démon : `tmux`, `nvim-agent`, `deck`, plus `jq`
  si une étape `opencode` n'a pas de `model` dans son frontmatter (le modèle est alors lu dans la config
  OpenCode). Il ne contrôle pas `opencode` lui-même : il avertit seulement si sa version n'est pas celle de la
  recette ou est illisible.
- `deck check --format <id>` ne contrôle que le manifeste et les étapes : aucun outil.
- « outil absent du PATH : <outil> » : l'outil n'est pas dans le `PATH` du démon (le démon garde
  l'environnement de son premier lancement). Dis-le à Adrien (remède : l'installer, puis `deck daemon stop` ;
  le démon redémarre à la commande suivante), ne modifie pas les fichiers de la campagne pour autant. Même
  conduite si le démon est d'une version antérieure qui ignore `--format`.
