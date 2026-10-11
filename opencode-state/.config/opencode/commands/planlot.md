---
description: Écrit un plan par lots + tâches dans .opencode/plans/ (une session par lot)
agent: plan
---

Tu écris un plan de travail par lots pour la demande suivante :

$ARGUMENTS

Règles de découpage — OBLIGATOIRES :

1. Le plan est écrit dans `.opencode/plans/<slug-court>.md` (crée le dossier si besoin). Jamais seulement dans la conversation. Les plans terminés sont archivés dans `.opencode/plans/done/` — ne prends jamais `done/` comme plan actif.
2. Un LOT = une session de travail autonome à contexte faible (moins de ~20k tokens), avec un objectif vérifiable. Entre 2 et 6 lots maximum.
3. Chaque lot contient des TÂCHES atomiques : une tâche = une délégation à un sous-agent. L'agent recommandé est noté entre crochets : [implementer], [chore], [challenger], [visual] ou [explore]. Chaque tâche porte une **recette** : la ou les commandes de test EXACTES qui valident la tâche, vérifiées comme disponibles dans l'environnement (ex : `python3`, pas `python`, si c'est le binaire réel).
4. Format STRICT du fichier :

```md
---
status: todo
---
# Plan: <titre>

## Lot 1 — <titre>
- [ ] 1.1 <tâche> [<agent>]
- [ ] 1.2 <tâche> [<agent>]

## Lot 2 — <titre>
- [ ] 2.1 <tâche> [<agent>]
```

5. Tu n'implémentes RIEN : tu produis UNIQUEMENT le fichier de plan, que tu ÉCRIS réellement sur le disque (outil write). Ne te contente jamais de l'afficher dans la conversation.
6. Termine en listant les lots (une ligne chacun) et la commande à lancer pour démarrer : `/lot 1`.
