# Reprise après la perte du 24 novembre 2026

## Ce qui s'est passé
Une restauration du système Windows (écran bleu > Dépannage > Restauration) a effacé le dossier de travail local et l'historique de la session Claude Code « Diagnostic Métré Atelier 2M ». Les versions **2.112 à 2.117.1** de l'extension n'avaient **jamais été publiées sur GitHub** : elles sont perdues. Dernière version publiée : **2.111.12** (commit f63bcb4).

## Récupération tentée (Windows File Recovery)
- Par nom (mode regular) : le fichier `a2m_metre.rbz` est retrouvé mais son contenu est écrasé (inutilisable).
- Par signature ZIP : 167 copies valides du plugin, de la 2.1.1 à la 2.111.12 — rien au-delà.
- Dossier du plugin installé dans SketchUp : fichiers `.rb` retrouvés mais contenu écrasé.
- Dossier `Documents\ATELIER 2M\Hachures` : ne contient que l'ancien état (`reglages.json` du 9 novembre). La « Base A2M » de la 2.117 n'existe plus.

## Ce qui reste pour reconstruire
- `session-2-113-a-2-117.txt` : le texte de la conversation (descriptions et décisions de Mathieu de la 2.113.2 à la 2.117.1). **Il ne contient pas le code.** Le début (2.112 → 2.113.1) manque.
- `reglages_hachures_2026-11-09.json` : réglages de hachures de coupe (12 couches) avant la 2.116.

## À refaire, dans l'ordre (un push GitHub après chaque version)
- 2.112 (mal connue) : palette en cartes avec pictogrammes ; ferraillages FSR10 / ST25C ; chaînages horizontaux ; cage LIB C10104T10E15 (4 HA10, 10×10, cadres HA5 tous les 15 cm, 6 m) ; Liste des aciers.
- 2.113 : ferraillage en rouge rouille (matière `A2M_Acier` de Mathieu si elle existe, sinon `A2M_Acier rouille` RGB 158,58,30) ; hachure unie « A2M Acier plein » pour que les fers soient pleins en coupe ; mise à jour automatique à l'ouverture de Ferraillage et au passage en Détail.
- 2.114 : outil « Chaînages verticaux » (`chainages_v.rb`) : murs porteurs dessinés (angles, T, extrémités, des deux côtés des baies ≥ 1,80 m, à 10 cm du tableau), cage au milieu de la couche porteuse, du bas du mur au haut moins 3 cm, 2 attentes HA10 en L (50 cm + retour 20 cm), comptage des cages de 6 m avec réutilisation des chutes, curseurs, rouille, plein en coupe, calque A2M_FERRAILLAGE, rouvrable. Mode Présentation : ferraillage conservé (masqué par le béton) pour que les fers coupés apparaissent pochés en rouille.
- 2.115 : bouton « Cadres en coupe » (copie du cadre le plus proche du plan de coupe, à moins de 10 cm, dans le plan ; hors métré).
- 2.116 : hachures — « Béton de propreté » dans la liste ; « Mes couches » (+ Couche depuis ma sélection, règle balise + matière, priorité sur la couche de la balise, + sélection, Supprimer) enregistrées dans `reglages.json`.
- 2.117 : « Mémoriser les A2M_ du modèle » / « Restaurer ma base » (Documents\ATELIER 2M\Hachures\Base A2M : matières A2M_ avec couleur, transparence, image et taille ; hachures A2M ; usages balise + matière → hachure). 2.117.1 : matière lue sur les faces des murs ; « Restaurer » reconstruit chaque hachure depuis ses réglages.

## Règle pour la suite
Pousser sur GitHub après chaque version, pas seulement à la fin de la journée.
