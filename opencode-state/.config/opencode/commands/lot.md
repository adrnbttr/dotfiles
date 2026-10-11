---
description: Exécute UN seul lot du plan .opencode/plans/ dans cette session
---

Tu exécutes UN lot de travail. Arguments : $ARGUMENTS

Protocole — à suivre à la lettre :

1. Ouvre le dossier `.opencode/plans/` et prends le plan demandé ($1 = numéro du lot, défaut 1 si vide ; précise le fichier en argument si plusieurs plans existent).
2. Lis UNIQUEMENT la section du lot concerné. Ne lis pas les autres lots : le contexte doit rester petit.
3. Pour chaque tâche `- [ ]` du lot : délègue au sous-agent indiqué entre crochets via l'outil `subagent`. Brief complet et autosuffisant (objectif, fichiers, contraintes) — pas de renvoi au plan entier si le lot suffit.
4. Applique les règles de routage et d'économie de AGENTS.md : pas de `challenger` sur du trivial, `chore` dès que c'est mécanique.
5. Après chaque tâche réussie, coche-la dans le fichier de plan (`[x]`).
6. En fin de lot : si le lot est non trivial, lance `challenger` sur le résultat, puis commite le travail du lot.
7. Ne traite JAMAIS plusieurs lots dans la même session.
8. Termine OBLIGATOIREMENT par ces deux lignes, dans cet ordre :

> **Lot $1 terminé.** Efface cette session (`/clear`, ou ferme-la et ouvre une session neuve) avant de continuer.
> Lot suivant : `/lot <N+1>` — à exécuter dans une session NEUVE, sans l'historique de celle-ci.

Rappel : le nettoyage de session entre deux lots est ce qui garde le contexte petit. Ne le saute jamais.
