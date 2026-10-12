# Référence des points validés — métré Atelier 2M

À relire avant chaque modification. Tout changement doit laisser ces points intacts.
Lancer les tests : `python3 tests/regression.py` (doit afficher « TOUT EST OK »).

## Configurateur → métré
- **Installation de chantier** (lot en tête) : eau OUV-0485, électricité OUV-0486, base vie OUV-0484, grue OUV-0492, benne gravats OUV-0487 (u = bennes), benne triée OUV-0488 (u = bennesTri).
- **Terrassement** : fouille en tranchée OUV-0008 (rigole) et massif OUV-0010 ; décapage OUV-0007 ; réseaux OUV-0018 (eau), OUV-0016 (EU), OUV-0524 (EP), OUV-0879 (élec).
- **Gros œuvre lié** : chaque fouille crée sa semelle (OUV-0040 filante, OUV-0041 isolée), même quantité, suit les modifications, disparaît avec la fouille. Plateforme exclue. Rigole = champ rigLin uniquement.
- **Clôture (OUV-0004)** : jamais créée automatiquement. Ajout uniquement à la main depuis la bibliothèque.
- **Lots** : ordre de la bibliothèque, installation de chantier en premier.

## Surbrillance (écran seulement, jamais à l'impression)
- Pas de couleur : lignes produites directement par le configurateur (décapage, réseaux, installation…).
- **Mauve** : ligne ajoutée à cause d'une autre ligne (semelle liée à une fouille ; ligne de bibliothèque reliée à une case).
- **Ambre** : saisie à la main.

## Saisie à la main d'un ouvrage déjà produit par le configurateur
- Une confirmation est demandée. OK = la saisie remplace la ligne du configurateur (une seule ligne, en ambre), et le configurateur ne la recrée plus. Annuler = rien n'est ajouté.

## Synchronisation
- Messages : un par chantier affiché ; chantiers supprimés masqués.
- À l'ouverture : silencieuse (pas de message, pas de dialogue).
- Bouton manuel : barre d'avancement en % avec bande verte, qui avance à chaque requête, masquée 1,5 s après la fin.
- Conflit (clic explicite seulement) : 1) « Garder la version de ce téléphone » ; 2) si refusé, « Reprendre la version de Drive » ; 3) si refusé, le conflit reste.
- « Synchroniser le métré » (en haut de la vue Tableau) : met à jour le configurateur puis synchronise.

## Points ouverts (pas encore validés)
- Doublon de clôture sur « Test configurateur » : à supprimer à la main, puis à vérifier avec le nouveau remplacement.
- Lignes de clôture déjà présentes avec l'ancien libellé de décapage : sans importance, chantier de test.

## Configurateur de pièces
- **Bloc A (ancien configurateur de pièces)** : EN VEILLE (`PIECES_ANCIEN_VEILLE = true` dans app.js). Ses données sont conservées, il ne produit plus aucune ligne, et la synchronisation ne retire rien. Pour le réactiver : passer le drapeau à `false`, puis relancer les tests.
- **Bloc C (nouveau configurateur de pièces)** : par pièce, surface au sol et revêtement, portes fin de chantier 83×204, menuiseries extérieures (fenêtre), appareillage de la pièce (prises, RJ45, interrupteurs, points lumineux). Bouton « Ajouter au métré » : régénère les lignes de la pièce (elles portent `pieceNv`, sans surbrillance) sans jamais les doubler.
- Non encore câblé : les plâtreries liées au revêtement, et les plinthes.

## Appareillage par pièce (bloc C, mise à jour)
- Repères par défaut d'après le fichier « appareillage » fourni par Mathieu (et non le texte officiel) :
  - Séjour : prises 5 (moins de 28 m²) ou 7 ; RJ45 2 (coin TV) ; prise TV 1.
  - Chambre : prises 3 ; RJ45 1.
  - Bureau : prises 3 ; RJ45 1.
  - Cuisine : prises 3 (4 m² ou moins) ou 6 (plus de 4 m², dont 4 au-dessus du plan de travail) ; RJ45 1 ; prise hotte 1 (à 1,80 m) ; circuits spécialisés plaque de cuisson 32 A, four 16 A, lave-vaisselle 16 A (1 chacun).
  - Salle de bains et salle d'eau : prise 1 + prise rasoir 1 (transformateur 20-50 VA, hors volume de sécurité) ; WC : 0 (la prise est dans le couloir).
  - Buanderie / cellier : prises 1 si plus de 4 m² ; circuits spécialisés lave-linge 16 A, sèche-linge 16 A, chauffe-eau 20 A (1 chacun).
  - Entrée / dégagement (couloir) : prises 1, et 2 si plus de 4 m² ; points lumineux 1 ; interrupteurs 1.
  - Autres pièces : prises 1 si plus de 4 m² ; points lumineux 1 ; interrupteurs 1.
- Une valeur saisie à la main prime toujours.
- Lignes de bibliothèque ajoutées : OUV-0882 à OUV-0888 (circuits spécialisés et prise hotte).
- Tests : cuisine (3 circuits + hotte), cellier (3 circuits), 27 lignes au total pour le jeu de test.
- Capture Google (tableau prises/éclairage/TV) utilisée pour corriger : cuisine selon la surface, séjour sans prise en plus (les 2 sont des RJ45), prise rasoir en salle de bains. Ligne ajoutée : OUV-0889 (prise rasoir).
- Séjour : 5 ou 7 prises, sans prise supplémentaire (décision de Mathieu).
- Interrupteurs (décision de Mathieu) : couloir, chambre, séjour en va-et-vient (1 point chacun) ; cuisine : 1 simple allumage et 1 va-et-vient ; dressing, salle de bains, salle d'eau, WC : simple allumage. Une ligne « point » par interrupteur ou va-et-vient (OUV-0364 / OUV-0365).
- Cuisine de 9 m² : 9 lignes au total (vv ajouté). Le jeu de test donne 28 lignes.
- Doublons électricité : 14 ouvrages marqués « supprimé » (identifiants conservés, rien d'effacé) : OUV-0619, 0229, 0622, 0212, 0366, 0367, 0612, 0610, 0215, 0613, 0368, 0210, 0620, 0222. On garde : OUV-0226 (visiophone), 0623 (borne 7 kW), 0220 (prise de terre piquet et ruban), 0611 (prise 16 A), 0213 (prise double 16 A), 0364 et 0365 (simple et va-et-vient), 0217 (prise TV), 0216 (RJ45), 0614 (point lumineux plafonnier), 0219 (gaine ICTA), 0618 (détecteur autonome de fumée).
- Règle de surface : les prises qui dépendent de la surface (séjour, cuisine, entrée, autres pièces) restent vides tant que la surface n'est pas saisie ; chambre, bureau, salle de bains et WC ont des valeurs fixes.
- Façades de placard (configurateur de pièces) : liste par pièce, choix OUV-0755 (coulissant) ou OUV-0880 (battant), largeur et hauteur en cm, nombre. Surface = largeur × hauteur × nombre. Leur largeur est retirée du linéaire de plinthes. L'ancien champ « Façade placard ml » est remplacé.
- Autres pièces (repères proposés et validés par Mathieu) : garage 2 prises, 1 point lumineux, 1 simple allumage ; cave et mezzanine 1 prise, 1 point lumineux, 1 simple allumage ; cage d'escalier 1 point lumineux en va-et-vient, sans prise ; terrasse extérieure 1 prise extérieure étanche (OUV-0615), 1 éclairage extérieur (OUV-0223), 1 interrupteur à voyant témoin (OUV-0893).
- Bloc D « Plâtrerie et isolation » (séparé du configurateur de pièces, données dans c.platNv) : hauteur sous plafond (m), linéaire de cloisonnement (ml) et linéaire de doublage (ml), avec le type d'ouvrage choisi dans la bibliothèque (cloisons : lot doublages-cloisons-plafonds, unité m²). Surface = linéaire × hauteur. Les lignes portent platNv et sont remplacées à chaque ajout. L'ancien bloc de plâtrerie (c.plat) n'est pas modifié.
- Plafond (bloc D) : surface saisie directement en m² et type d'ouvrage (plafonds de la bibliothèque, unité m²). Pas de hauteur demandée.
- Doublage (bloc D) : surface = linéaire × hauteur, moins les menuiseries extérieures saisies dans les pièces (fenêtres, portes-fenêtres, baies, portes d'entrée) d'au moins 1,50 m² chacune (égal ou supérieur à 1,50 m²). Les plus petites ne sont pas déduites. Le cloisonnement n'est pas déduit. Le total des menuiseries déduites s'affiche sous le doublage.
- Cloisonnement (bloc D) : surface = linéaire × hauteur, moins les portes de passage (hauteur 2,04 m × largeur 83 ou 73 cm × nombre) et les façades de placard (largeur × hauteur × nombre) qui font au moins 1,50 m² chacune (égal ou supérieur). Une porte de 73 cm (1,49 m²) n'est donc pas déduite, une porte de 83 cm (1,69 m²) l'est. Le test donne 25 − 6,49 = 18,51 m².
- Bloc E « Peinture » (séparé, données dans c.peinture, lignes peiNv) : hauteur sous plafond (vide = celle du bloc plâtrerie) ; murs = linéaire × hauteur moins les menuiseries extérieures, portes de passage et façades de placard d'au moins 1,50 m² ; plafond saisi en m². Ouvrages par défaut : OUV-0689 (murs deux couches) et OUV-0690 (plafond deux couches). Le test donne murs 14,73 m² et plafond 12 m².
- Bloc E peinture, murs : linéaire = somme des linéaires saisis dans chaque pièce du configurateur de pièces (hauteur propre au bloc peinture). Le test (15,5 ml × 2,50 m, moins 10,27 m² d'ouvertures) donne 28,48 m².
- Bloc E peinture, murs (règle finale) : linéaire = somme des linéaires de chaque pièce × hauteur saisie dans le bloc peinture. Aucune déduction (ni portes, ni passages, ni ouvertures). Sans hauteur dans le bloc peinture, pas de ligne murs : la hauteur de la plâtrerie n'est jamais reprise. Le test (15,5 ml × 2,50 m) donne 38,75 m².
- Bloc E peinture, portes et façades : surface brute de toutes les portes de passage (hauteur 2,04 m × largeur × nombre) et de toutes les façades de placard (largeur × hauteur × nombre), sans seuil, × 2 (deux faces). Ouvrage par défaut OUV-0691 « Peinture boiseries et menuiseries ». Le test (6,49 m² × 2) donne 12,99 m².
- Bloc E peinture, murs (règle finale 2) : surface des murs = linéaire des pièces × hauteur du bloc, moins le total des portes et façades peintes (surface × 2). Le test (38,75 m² − 12,99 m²) donne 25,76 m².
- Bloc E peinture, menuiseries : surface totale de toutes les menuiseries extérieures (sans seuil de 1,50 m²), affichée et déduite des murs à peindre. Ce n'est pas une ligne peinture. Le test (38,75 − 12,99 − 4,78) donne murs 20,98 m².
- Configurateur de pièces : case « Passage libre sans porte (ml) » par pièce. Elle sert seulement à réduire le linéaire de plinthes de la pièce ; aucune ligne au métré, aucune porte ajoutée, et pas de déduction du cloisonnement ni des murs à peindre (calculés à part). Le test (15,5 − 1 ml) donne plinthes 9,87 m.
- Bouton « Générer le métré depuis le configurateur » (vConfig) : relance pièces, plâtrerie et peinture. Chaque bloc retire ses anciennes lignes et ne remet que ce qui est encore saisi ; une hauteur vide retire les lignes murs/cloisons/doublages. Les lignes saisies à la main ne sont pas touchées. Le plafond de plâtrerie ne dépend pas de la hauteur et reste.
- Bouton « Remise à zéro » (configurateur) : vide toutes les cases remplies (vertes) de #vConfig, après confirmation. Chaque case vidée passe par son gestionnaire « change » ; puis les lignes générées sont retirées (pièces, plâtrerie, peinture). Les lignes saisies à la main restent. Les lignes de pièces (lignes du tableau) restent, avec leurs champs vides.
- Remise à zéro totale : efface aussi toutes les pièces du configurateur (tableau des pièces), la plâtrerie et la peinture, ainsi que leurs lignes au métré. Les lignes saisies à la main restent.

- Portes de passage (configurateur de pièces) : tailles 63, 73, 83, 93 et 103 × 204, chacune reliée à son ouvrage « Bloc-porte fin de chantier … × 204 » (OUV-0192, OUV-0191, OUV-0190, OUV-0896, OUV-0897). Menu « Sens d'ouverture » : poussant à droite / poussant à gauche, enregistré avec la porte mais sans effet sur les lignes du métré.
- Spots encastrés (électricité) : OUV-0211 « Spot encastré LED » pour les pièces courantes, OUV-0898 « Spot encastré LED étanche IP65 (salle de bain) ». Nombre de spots par pièce non encore branché au configurateur.
- Éclairage du plafond par pièce (configurateur) : par défaut point lumineux plafonnier (OUV-0614). Option « Spots encastrés » : nombre de spots = ⌈surface × lux ÷ 450 lm⌉, lux retenus : entrée 150, chambre/séjour 200, cuisine 300, bureau 350, salle de bains et salle d'eau 400, WC et buanderie/cellier 150. Ouvrage OUV-0211, ou OUV-0898 (IP65) en salle de bains et salle d'eau. Le point lumineux n'est alors pas généré.
- Option sous « Spots encastrés » : « Plafonnier en plus, commandé par va-et-vient » = Oui ajoute 1 point lumineux plafonnier (OUV-0614) et 1 interrupteur va-et-vient (point) en plus des spots. Par défaut : Non.
- Couleurs du configurateur : tout ce qui vient de la norme NF C 15-100 est figé et reste sans couleur. Les options ajoutées en plus (plafonnier + va-et-vient sous les spots) sont en bleu dans le métré (ligne-option), avec la légende « option ajoutée en plus de la norme NF C 15-100 », et le sélecteur de l'option est bleu quand il est sur Oui.
- Équipements de la maison (hors pièces, norme) : tableau calculé selon les pièces saisies (circuits éclairage 8 points max, prises 8 max, 1 par appareil spécialisé, 1 VMC ; différentiels 30 mA : au moins 2, puis 1 pour 8 circuits ; modules = (circuits + 2 × différentiels + 2) × 1,2, puis 12, 24, 36 ou 48 modules, ou 4 rangées au-delà). Détecteurs de fumée : 1 pour 100 m² de surface totale, hors terrasse, arrondi au supérieur. Lignes sans couleur (norme).
- Plâtrerie (bloc D) : cloisonnement et doublage peuvent être saisis en linéaire (ml, × hauteur sous plafond) ou directement en surface (m²), au choix. Si les deux sont saisis, le linéaire prime. Les déductions (portes et placards de 1,50 m² et plus ; menuiseries extérieures de 1,50 m² et plus) s'appliquent dans les deux cas.
- Cloisons (bibliothèque, révision 57) : cloisons gardées : OUV-0751 cloison 74 mm (rail et montants 48, BA13 deux faces), OUV-0752 cloison 96 mm, OUV-0753 cloison 124 mm, OUV-0148 cloisons en carreaux de plâtre. Retirées (marquées « supprimé ») : OUV-0570 cloison hydrofuge et OUV-0758 cloison coupe-feu (demande de Mathieu), OUV-0577 cloison en briques de plâtre (demande de Mathieu). Retirées aussi (demande de Mathieu) : OUV-0754 (cloison 124 mm phonique), OUV-0756 (cloison 90 mm phonique), OUV-0757 (cloison 120 mm phonique) et OUV-0759 (cloison vitrée intérieure), OUV-0145 et OUV-0569 (doublons de 0751), OUV-0571 (doublon de 0757), OUV-0576 (doublon de 0148), OUV-0146 (cloison avec isolant 45 mm) et OUV-0156 (isolant seul pour cloisons), pour retirer l'isolant des cloisons.
