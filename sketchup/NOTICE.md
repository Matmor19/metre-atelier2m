# Métré Atelier 2M — notice d'utilisation (version 2.110.0)

Notice générée automatiquement à chaque version : chaque bouton de la palette y figure, avec son rôle et, quand il est détaillé, la marche à suivre.


## Préparer

### Tableau de bord du modèle
Contrôle du modèle et métré en direct dans une seule fenêtre : points à vérifier cliquables, surfaces, linéaires et menuiseries par pièce, envoi au métré

### Niveaux du bâtiment
Liste des niveaux (code, nom, altitude) avec un schéma en coupe : le dessous de la dalle est le zéro, ce qui est dessous est négatif ; ajoutez, modifiez ou supprimez les niveaux, tracez-les dans le modèle ou calez le zéro sur un point cliqué

- La liste commence par des niveaux types (haut des murs, plafond, fini du sol, dessus et dessous de la dalle, semelles) : changez les noms, les codes et les altitudes dans le tableau.
- Le bouton « + Ajouter un niveau » en ajoute un ; la croix à droite d'une ligne le supprime. Le schéma en coupe à droite suit chaque frappe, sans bouton « Appliquer ».
- Le zéro est le dessous de la dalle : en dessous, les altitudes sont négatives (−0,60) ; au-dessus, positives (+0,15).
- « Tracer les niveaux dans le modèle » dessine un cadre en lignes de construction et une étiquette par niveau, dans un groupe « Niveaux (A2M) » sur la balise A2M_NIVEAUX, que l'on masque en un clic.
- « Caler le zéro sur un point cliqué » : cliquez le dessous de la dalle ; le modèle est déplacé en hauteur pour que ce point devienne 0 (l'altitude NGF de l'origine suit si elle est connue).

### Créer les balises du métré
Crée les balises A2M_ du métré (dossier « Métré A2M »), sans toucher à celles qui existent

### Baliser la sélection
Met la balise choisie sur les groupes, composants, faces ou lignes sélectionnés

### Pièce en un clic
Cliquez dans une pièce fermée : sol (épaisseur, revêtement), plinthes, nom (liste et précision libre), surface et périmètre en ml, en une seule fois

- Cliquez dans une pièce fermée : sol (épaisseur, revêtement), plinthes, nom, surface et périmètre, en une seule fois.

### Séparateur de pièce
Tracez une ligne entre deux murs : elle sépare une pièce ouverte en deux pour « Pièce en un clic » et « Pièces automatiques ». Invisible dans les scènes, à l'impression et à l'export

### Afficher / masquer les séparateurs
Montre les séparateurs en orange pour les retrouver ou les supprimer, ou les cache de nouveau (ils sont masqués par défaut)

### Pièces automatiques
Trouve toutes les pièces fermées entre murs et cloisons et vous les présente une par une (en surbrillance) : nom, sol en texture, plinthes, plafond, surface et ml ; scènes 2D et 3D à la fin

### Caler un plan existant
Importe l'image d'un plan (PNG, JPG), puis deux clics sur une longueur connue et sa vraie valeur : le plan est mis à l'échelle, et si vous voulez d'équerre

### Relevé de côtes
Tapez les mesures prises sur place (deux côtes, ou côté par côté avec les angles) : la pièce se dessine, nommée et balisée, avec sa surface

### Fiche pièce
Cliquez dans une pièce : surface, périmètre, murs à peindre, plinthes, menuiseries, portes et appareillage de la pièce, avec envoi au métré

### Vues prêtes à l'emploi
Plan, façades Nord/Sud/Est/Ouest et perspective créés en scènes en un clic

### Plan 2D automatique
Le plan 2D se déduit du 3D : coupe à hauteur choisie, murs en poché, arc et battant des portes, nom et surface de chaque pièce, scène prête pour LayOut

- Crée le plan 2D d'un niveau : portes avec arc, noms et surfaces de pièces, cotes, images 2D des objets de la bibliothèque. Une scène « A2M – Plan 2D … » est créée.
- Ensuite il se met à jour tout seul 2 secondes après chaque modification du modèle (réglage « mise à jour automatique »).

### Coupes automatiques
Coupe longitudinale ou transversale en un clic, ou tracée en 2 clics : scène prête, murs en poché, niveaux et cotes de hauteur automatiques, repère de coupe sur le plan 2D ; le plan de coupe se déplace ensuite avec l'outil Déplacer

- Coupes automatiques : plans de coupe nommés « A2M Coupe … », scènes élévation (2D) et/ou coupe 3D au choix par coupe, nom modifiable (Entrée), « Inverser toutes les coupes ».
- Les hachures de coupe viennent de « Hachures de coupe par couche ».

### Cotation automatique
Cotes de chaque pièce côté par côté et cotes hors tout du bâtiment, posées en un clic sur leur propre balise (masquable)

### Styles de vue
Intérieur, plan technique, coupe grise, construire et démolir, tracé sur plan : un clic change l'aspect de la vue, avec vos favoris

### Variantes client A / B / C
Trois versions du même projet dans un seul fichier : choisissez où chaque élément apparaît, puis un clic sur A, B ou C change tout ; une scène par variante pour présenter


## Dessiner

### Axes verrouillés / tracé libre
Par défaut les murs, sols et tracés suivent l'axe rouge ou vert. Cette commande (ou la touche Ctrl, ou le clic droit, pendant le tracé ; vous pouvez aussi lui donner votre propre raccourci) passe en tracé libre et revient

- Bascule entre axes verrouillés (par défaut pour les murs et tracés) et tracé libre. Les touches X et N sont déjà prises par vos raccourcis.

### Dessiner un mur
Mur, doublage ou cloison : hauteur, épaisseur et tracé (axe ou face), posé sur sa balise

### Dessiner un mur composé
Plusieurs couches en une fois (mur, isolant, plaque…), chacune sur sa balise

- Dessine un mur de 1 à 5 couches (enduit, mur, isolant, plaque de plâtre…), chaque couche étant un objet sur sa propre balise.
- 1. Choisissez le nombre de couches, puis le type, l'épaisseur et la hauteur de chacune (de l'extérieur vers l'intérieur).
- 2. Couche d'insertion (★, en surbrillance) : c'est elle que vous tracez. Par défaut le mur périphérique. Le tracé en est la face extérieure ; l'enduit se place à l'extérieur du tracé, les doublages à l'intérieur. L'aperçu en coupe montre le tracé en orange.
- 3. Choisissez le côté (intérieur à droite ou à gauche du tracé, ou tracé dans l'axe de la couche d'insertion) puis « Dessiner le mur » : cliquez les points ; Tab change de côté, Entrée termine.
- Dernière colonne de chaque couche : « descend plus bas (cm) ». Exemple : 30 pour l'enduit = il descend 30 cm sous le pied du mur (même sommet, plus haut de 30 cm). 0 = au niveau du tracé. Réglable aussi dans « Modifier un mur ».
- Cloisons : une cloison dessinée contre une autre cloison de même type et même épaisseur fusionne avec elle automatiquement ; « Modifier le tracé » affiche alors tous les tracés réunis.

### Dessiner une cloison
Cloison à vos couches : plaque + ossature (rail, montant) + plaque, par exemple 13 + 48 + 13 = 74 mm, chacune sur sa balise

- Cliquez « Dessiner une cloison » : choisissez le nombre de couches (jusqu'à 5) et, pour chacune, son type et son épaisseur.
- Par défaut : plaque de plâtre 1,3 cm + ossature (type « Cloison ») 4,8 cm + plaque 1,3 cm = 7,4 cm. Changez-les à volonté (isolant dans l'ossature, double plaque…).
- Le tracé suit par défaut l'axe de la couche choisie (la Tab change de côté). Cliquez les points puis Entrée.
- Chaque couche est sur sa balise : plaques = A2M_DOUBLAGE, ossature = A2M_CLOISON.
- Les cloisons composées reliées fusionnent entre elles ; tout se rouvre avec « Modifier ce que j'ai dessiné ».
- Placer un point à une distance d'un repère : pendant le tracé, appuyez sur la flèche haut (ou clic droit > Partir d'un repère), cliquez le point de référence, visez la direction (flèche droite = axe rouge, flèche gauche = axe vert), tapez la distance puis Entrée. Le point est posé là (premier point compris). Échap annule le repère. Pareil avec l'outil mur.

### Dalle, chape, plafond depuis les murs
Sélectionnez les murs : dalle béton sous l'emprise, isolant, chape et plafond dans chaque pièce fermée, posés d'un coup avec leurs épaisseurs

- Génère dalle, chape, isolant et plafond à partir des murs sélectionnés (les murs de soubassement sont acceptés : la dalle se pose alors sur leur dessus).
- Sélectionnez les murs périphériques, lancez l'outil, choisissez les couches. Fusionnez un mur central après avoir posé la dalle.

### Dessiner un sol ou un plafond
Dalle, plancher, isolant de sol, chape, revêtement, terrasse, allée ou plafond : tracé au clic, ou en un clic sur les murs sélectionnés

### Poser les planelles en rive de dalle
Planelles sur tout le pourtour de la dalle : votre profil dessiné (en L…, avec isolant), un profil de la bibliothèque ou un rectangle ; dans l'épaisseur (dalle recoupée) ou à l'extérieur

- Chaîne dalle + planelles : 1. dessinez le soubassement ; 2. « Dalle, chape, plafond depuis les murs » sur les murs sélectionnés (soubassement compris) ; 3. « Poser les planelles en rive de dalle ».
- La planelle se pose sur le soubassement, la dalle monte au niveau de son haut et suit son profil. La planelle est un seul objet (tag A2M_PLANELLE) ; sa coque, ses vides et son isolant ne sont que des textures.
- Le profil vient de « Bibliothèque de profils » : dessiné par vous, respecté tel quel.

### Créer la toiture
Toiture 2 pans, 4 pans, monopente ou « Suit les murs » (épouse exactement le contour des murs, y compris en L ou en T) : pente, débord et épaisseur

- Sélectionnez les murs (groupes), puis lancez « Créer la toiture ».
- Choisissez le type : 2 pans, 4 pans, Monopente (sur le rectangle des murs) ou « Suit les murs » (la toiture épouse exactement le contour, par exemple une maison en L).
- Réglez la pente, le débord et l'épaisseur : tous les pans ont la même pente. « Faîtage parallèle » et « côté haut » ne servent pas pour « Suit les murs ».
- Faîtages et arêtiers sont posés avec vos objets de la bibliothèque (Toiture : « Tuile faitière canal », « About de faitière canal Gauche » et « Droite »). Les tuiles sont réparties de bout en bout au pas de 48,5 cm au plus, l'axe de la tuile sur la ligne ; les abouts ferment le faîtage aux deux bouts, sauf là où un arêtier arrive.

### Charpente (chevrons, liteaux)
Chevrons à l'entraxe choisi, contre-liteaux, liteaux au pas de la couverture, faîtière et sablière sous chaque pan, avec les linéaires pour le métré

- Charpente sous les pans de la toiture : chevrons, contre-liteaux, liteaux, faîtière et sablière.
- La fenêtre montre la coupe d'un pan à l'échelle ; entraxe des chevrons, pas des liteaux, section et éléments se règlent en direct, sans bouton « Appliquer ».
- Le bilan donne les mètres de chaque pièce et le volume de bois en m³ (hors chutes), repris dans le métré.
- Pour changer plus tard : « Modifier ce que j'ai dessiné ».

### Couverture (ardoise, tuiles, zinc)
Pose ardoise, tuile mécanique ou plate, zinc à joints debout ou bac acier sur les pans de la toiture : rangs, joints décalés, nervures, teintes variées, surface au métré

### Zinguerie (gouttières, descentes)
Gouttières (zinc dév. 25 et 33, nantaise, alu) avec crochets sur les égouts ; descente placée au clic sur l'égout et réglée sur une coupe : coudes, tuyau horizontal contre le mur, colliers répartis, regard en pied ; linéaires pour le métré

### Escalier
Escalier droit, quart tournant ou demi-tournant : marches, contremarches, limons, loi de Blondel, côté mur

- Escalier droit, quart ou demi-tournant calculé avec la loi de Blondel, avec vue de dessus et coupe, réglable en direct après la pose (2 clics).
- Option « Structure béton + ferraillage » : marches et paillasse inclinée en un seul bloc (épaisseur 10 à 25 cm), barres principales suivant la pente (Ø et espacement au choix), barres de répartition Ø8 tous les 25 cm, grille dans le palier. Les mètres et kilos par diamètre sont repris dans le métré.
- Pour changer plus tard : « Modifier ce que j'ai dessiné ».
- Structure au choix : bois (limons pleins), limons crémaillère (les marches reposent dans les crans), limon central métal (poutre au centre, marches en console) ou béton armé (avec ferraillage).
- Quart tournant : option « Marches balancées » pour remplacer le palier par 3 marches triangulaires (angles de 30°).
- L'épaisseur des marches et le nez de marche se règlent en direct.

### Garde-corps
Poteaux, fixations (platine, rosace, chant, scellé), main courante et remplissage (barreaux, câbles, verre, pinces, profilé, grille, lisses, plein) le long d'un tracé ou d'un escalier

- Choisir le remplissage : barreaux, câbles inox, verre, verre sur pinces, verre en profilé (sans poteaux intermédiaires), grille, lisses ou panneau plein.
- Choisir la fixation des poteaux : platine carrée, rosace ronde, fixation en chant (platine verticale sur le nez de dalle ou le limon ; choisir le côté du poteau), scellé avec collerette, ou posé directement.
- Choisir la main courante (tube, plat bois, sans), la matière et le profil rond ou carré ; tout se règle en direct.
- Les nombres de fixations et de pinces sont envoyés au métré.

### Créer les semelles
Semelles filantes sous les murs sélectionnés : largeur et hauteur

- Semelles filantes sous les murs sélectionnés : largeur et hauteur de la semelle, et béton de propreté (5 cm par défaut, 0 = aucun) posé dessous, 5 cm plus large de chaque côté.
- Sélectionnez les murs porteurs, cliquez l'outil, réglez les trois valeurs. Pour changer plus tard : « Modifier ce que j'ai dessiné ».
- Pour dessiner les armatures des semelles : sélectionnez-les puis utilisez l'outil Ferraillage (type « Semelle filante »).

### Ferraillage (barres et cadres en 3D)
Sélectionnez un béton (dalle, semelle, linteau, poutre, poteau) : les barres et les cadres se dessinent en 3D, avec les mètres et les kilos par diamètre, réglés en direct par des curseurs ; repris par l'extraction du métré

- Pour dessiner les armatures (barres et cadres) d'un béton déjà modélisé : dalle, semelle, semelle filante, linteau, poutre ou poteau.
- 1. Sélectionnez le groupe de béton. 2. Cliquez l'outil : la fenêtre s'ouvre et le ferraillage est posé tout de suite, selon la forme devinée du béton. Un béton déjà ferraillé est repris, pas doublé.
- 3. Réglez avec les curseurs (enrobage, diamètres, nombre de barres, espacement) : le modèle se refait en direct. Poutre et poteau : les cadres sont resserrés (espacement ÷ 2) sur les deux bouts, sur le plus grand de : grand côté, longueur ÷ 6, 45 cm.
- Semelle filante : les barres longitudinales suivent le contour du béton (tracé des semelles créées par l'outil Semelles), les barres transversales sont posées en travers à l'espacement choisi.
- Le tableau donne les mètres et les kilos par diamètre (kg/m = π × Ø² / 4 × 7850). Le total est repris dans l'extraction du métré (ligne « ferraillage » des infos).
- Limites : dalle, poutre et poteau sont lus par leur boîte rectangulaire alignée sur les axes ; les ancrages et recouvrements ne sont pas ajoutés ; le dimensionnement reste à vérifier par le bureau d'études.

### Liste des aciers
Tous les ferraillages du modèle par ouvrage et par diamètre, avec les barres de 12 m à commander ; enregistrable en CSV

- Récapitulatif de tous les ferraillages du modèle (dalles, semelles, poutres, poteaux, escaliers béton).
- Un tableau par ouvrage et par diamètre, puis le total à commander : mètres, kilos et nombre de barres de 12 m.
- Le bouton « Enregistrer en CSV » crée un fichier qui s'ouvre dans Excel ; « Actualiser » reprend le modèle après une modification.

### Détail / Présentation
Bascule le même modèle : en « détail », les barres du ferraillage sont visibles et le béton est transparent ; en « présentation », le ferraillage est masqué et le béton est plein. Rien n'est supprimé

- Un seul bouton pour passer du travail de détail à la présentation, sur le même modèle.
- Mode détail : les barres du ferraillage (balise A2M_FERRAILLAGE) sont affichées et le béton est en transparence (rayons X) pour voir à l'intérieur.
- Mode présentation : le ferraillage est masqué et le béton redevient plein. Rien n'est supprimé : on rebascule quand on veut.

### Hachures de coupe par couche
Une hachure par type de couche (mur, isolant, plaque, cloison, chape…), posée automatiquement en dessinant ; peut aussi l'appliquer au modèle déjà dessiné

- Choisit, par couche (balise), la hachure ou la couleur unie vue en coupe. Liste en français ; une couleur = trait d'opacité 0 + fond coloré. « Appliquer » ne touche que les objets portant la balise ; une nouvelle pose utilise les réglages du moment.
- Planelle : « Planelles en rive de dalle » = la coque, « Isolant dans la planelle » = les vides.
- Votre propre dessin : dessinez la cellule (rectangle de 14 cm de large + traits/courbes, hauteur au choix, haut et bas qui se raccordent), sélectionnez-la, puis « Hachure depuis ma sélection… » : elle est rangée dans le groupe « Mes dessins » et s'applique comme les autres motifs (se répète à la verticale et à l'horizontale). Les traits du bord du rectangle ne sont pas retenus ; le fond de couleur se règle dans la fenêtre.
- Pour une hachure « Mes dessins » : les curseurs « Déplacer » décalent la cellule dans le mur (gauche-droite et haut-bas, en cm) ; cliquez « Appliquer » pour voir l'effet dans SketchUp.
- Les réglages s'appliquent tout seuls dans SketchUp dès que vous bougez un curseur ou changez une valeur (le bouton « Appliquer » sert encore à tout reposer d'un coup).

### Textures extérieures
Enduits, RAL des menuiseries, tuiles, zinguerie, appuis… : texture visuelle d'un élément pour la présentation client (hors métré)

- À gauche, choisissez la couche (mur périphérique, enduit, doublage…) ; à droite, cliquez la texture : elle est posée sur tous les objets de cette couche et sur ceux que vous dessinerez ensuite. « Retirer la texture de cette couche » l'enlève. Sans couche (« Sélection »), la texture va sur la sélection ou sur les éléments balisés de la catégorie. L'onglet « Mes textures » montre vos matières A2M_ (rangées dans Mes éléments > Textures, ou présentes dans le modèle).
- Ranger une de vos textures : dans l'onglet « Mes textures », la liste sous chaque matière permet de la ranger dans une catégorie (Enduits, Isolants…) ; elle apparaît alors dans cette catégorie. Quand vous enregistrez de nouvelles textures A2M_ dans Mes éléments, la catégorie vous est proposée.
- « Réappliquer les textures des couches » (colonne de gauche) repose sur tous les objets la texture choisie pour chaque couche ; il remplace l'ancien bouton « Textures A2M_ automatiques ».

### Phases : existant, démolition, construction
Marque les éléments à conserver (gris), à démolir (rouge) ou à construire (bleu), et affiche l'état existant, la démolition ou le projet fini


## Ouvertures, finitions

### Créer une ouverture
Largeur et hauteur suffisent : porte ou fenêtre reconnue, menuiserie et appui ou seuil proposés ; perce toutes les couches, suit la menuiserie déplacée

### Poser une porte intérieure
Bloc-porte de passage (63 à 103 × 204) dans une cloison ou un refend : réservation, toute l'épaisseur, centré, sens au Tab, choix du configurateur

### Poser les plinthes
Plinthes le long du revêtement sélectionné, avec votre profil ou un profil de la bibliothèque, coupées aux portes

### Poser l'appareillage électrique
Prises, points lumineux, interrupteurs… posés au clic et comptés pièce par pièce


## Bibliothèque

### Importer un objet (3D Warehouse)
Cherche un objet sur la 3D Warehouse ou prend un fichier .skp, le nettoie puis le range dans la bibliothèque avec sa vignette

- Pour un objet qui n'est PAS encore dans SketchUp (fichier .skp téléchargé ou 3D Warehouse).
- Ouvrez l'outil, tapez ce que vous cherchez puis « Chercher sur la 3D Warehouse » : le site s'ouvre, téléchargez le .skp.
- Revenez dans la fenêtre : « dernier téléchargement » ou « Choisir un fichier .skp ». Les 5 pastilles de nettoyage (toutes actives) s'appliquent à l'import.
- Placez l'axe (deux clics sur le bord bas de la face avant) puis rangez l'objet dans la bibliothèque.

### Contrôler et préparer un objet
Vérifie l'objet sélectionné (taille, faces à l'envers, éléments parasites, poids, nom), le nettoie et le prépare, puis propose de le ranger dans la bibliothèque avec ses images 2D

- Pour un objet DÉJÀ dans SketchUp (téléchargé, copié d'un autre modèle…).
- 1. Sélectionnez l'objet. 2. Cliquez l'outil.
- Il réunit les morceaux en un composant, retire les éléments parasites, referme les petits trous (faces manquantes), met toutes les faces dans le même sens (vers l'extérieur), sans jamais effacer les arêtes masquées d'une forme courbe, vérifie la taille (propose la mise à l'échelle si elle est douteuse), le poids et le nom, puis purge le modèle.
- Un rapport s'affiche et propose de ranger l'objet dans la bibliothèque : répondez Oui.

### Vue 2D de l'objet sélectionné
Dessus et face de l'objet (meuble, menuiserie importée…) en projection parallèle, avec sa vraie géométrie et ses couleurs et textures d'origine, en PNG à fond transparent

- Crée les images 2D (dessus et face) de l'objet sélectionné, en couleurs d'origine et en version blanche (fichiers « …_blanc.png »), dans Documents\Atelier 2M\Vues 2D. Le modèle, la caméra et le style ne changent pas.

### Paramétrer un objet pour la bibliothèque
Menuiserie, porte, appui, seuil, façade de placard, plinthe, mobilier… : objet dessiné, éclaté ou composant dynamique (gardé entier), rangé dans la bibliothèque

- Range l'objet sélectionné dans la bibliothèque, avec sa vignette et ses 4 images 2D (dessus et face, couleur et blanc).
- 1. Sélectionnez l'objet (idéalement après « Contrôler et préparer un objet »).
- 2. Fenêtre « Ranger » : vérifiez le nom, choisissez le dossier (ou « + Nouveau dossier ») et la pièce, puis « Ranger ».
- 3. Pour une fenêtre ou une porte : les détails (vantaux, matériau, vitrage…) sont demandés ensuite. Pour du mobilier : rien de plus.
- 4. « Lignes d'étirement » : pour un meuble ou une chaise, videz les deux champs, OK, puis « Oui » (taille fixe).

### Bibliothèque d'objets
Poser un objet de la bibliothèque à la taille voulue (profils inchangés), ouvrir ou changer le dossier

- Fenêtre de la bibliothèque : vignettes rangées par dossier, recherche rapide (nom, dossier, pièce), pose à la taille voulue.
- Poser : cliquez un objet, réglez largeur et hauteur, puis « Poser ». L'objet suit la souris (emprise orange) : un clic le pose, ← → le pivotent de 90°, Échap annule.
- Sur le Plan 2D, l'image 2D de l'objet apparaît toute seule à sa place (le Plan 2D doit avoir été créé une fois). Clic droit sur l'image ou sur l'objet : « image 2D du plan » en version couleur ou blanche, objet par objet.
- « Poser l'image 2D » (en bas de la fenêtre) : dépose l'image seule (dessus ou face, couleur ou blanc) à l'échelle voulue sur le tag A2M_SYMBOLES_2D.
- « Gérer la bibliothèque » : ouvrir ou changer le dossier, corriger le type d'un objet. Le dossier par défaut est Documents\Atelier 2M\Bibliothèque SketchUp (copie à sauvegarder vous-même).

### Bibliothèque de profils
Vos profils (plinthe, planelle, couvertine, appui, bandeau…) : rangés depuis un dessin ou créés par leurs cotes, balayés le long d'un tracé, utilisés par Plinthes et Planelles

- Bibliothèque de vos profils dessinés (plinthe, planelle, couvertine, appui, bandeau…). « Ranger le profil dessiné » enregistre aussi ses textures. Les profils sont respectés tels que vous les avez dessinés.


## Métré

### Cartouches et charte
Votre logo, vos coordonnées, vos couleurs et les champs de vos cartouches : autant de modèles que voulu, utilisés par le dossier client et les feuilles de présentation

### Feuille de présentation LayOut
Crée une feuille LayOut avec les vues choisies et le cartouche de votre charte, prête à compléter (cotes, annotations, échelle) dans LayOut

### Exporter pour ZWCAD (DWG / DXF)
Exporte le modèle en DWG ou DXF dans Documents/Atelier 2M/Export CAO : chaque balise Métré A2M devient un calque pour ZWCAD

### Dossier de présentation client
Vues du modèle, surfaces par pièce, menuiseries et synthèse en un document aux couleurs d'Atelier 2M, prêt à imprimer ou à enregistrer en PDF

### Envoyer au métré
Envoie l'extraction directement au métré : bouton « Récupérer depuis SketchUp » dans le configurateur

### Aide : balises reconnues
Liste des balises du métré et de leur usage


## fenêtre(s)


## porte(s)-fenêtre


## porte(s) int.


## pièce(s)


## mur(s)


## Autres commandes (menu Extensions)

### Baliser et nommer les pièces
Met A2M_PIECE sur les groupes de sol sélectionnés et demande le nom de chaque pièce

### Contrôle du modèle
Vérifie balises, solides, chevauchements, pièces et menuiseries avant l'extraction

### Textures A2M_ automatiques
Pose sur les éléments dessinés (murs de soubassement, semelles…) les matières A2M_ de leur type, sur les murs existants ou la sélection

### Extraire pour le configurateur
Enregistre le fichier .json à importer dans le configurateur du métré

### Palette Atelier 2M
Ouvre la palette flottante : boutons espacés, animés au survol, rangés par étape, avec leur explication


## Dernières nouveautés

- Garde-corps : assemblage repris — le dessus de la main courante est exactement à la hauteur réglée (les poteaux s'arrêtent dessous, les barreaux montent jusqu'à son dessous) et, aux angles, les tronçons de main courante se rejoignent au lieu de laisser un vide
- Escalier : choix de la structure (bois à limons pleins, limons crémaillère, limon central métal, béton armé), marches balancées pour le quart tournant (3 marches triangulaires à la place du palier), épaisseur des marches et nez de marche réglables, contremarches posées sur la marche d'en dessous et palier avec sa contremarche, l'escalier posé en altitude garde la bonne hauteur, garde-corps possible sur le côté extérieur des marches balancées
- Garde-corps en verre (et panneau plein) : les panneaux suivent maintenant la pente d'un escalier (parallélogrammes parallèles à la main courante) ; les pinces suivent aussi
- Garde-corps : 5 systèmes de fixation des poteaux (platine carrée, rosace ronde, fixation en chant sur nez de dalle ou limon, scellé avec collerette, posé directement) avec boulons dessinés ; 3 nouveaux remplissages (verre sur pinces, verre en profilé au sol sans poteaux intermédiaires, grille métallique) ; main courante au choix (tube, plat bois, sans) ; le verre est maintenant transparent ; les fixations et pinces sont comptées pour le métré
- Garde-corps : pièces rondes (poteaux, main courante Ø 4,2 cm, barreaux) ou carrées au choix, et poteaux de départ et d'arrivée renforcés (plus gros et plus hauts), réglables en direct
- Ferraillage : les crochets aux extrémités des barres sont maintenant dessinés en 3D sur les dalles et semelles (vers le haut pour la nappe basse, vers le bas pour la haute), en plus d'être comptés dans les kilos
- Liste des aciers (nouveau, dans « Dessiner ») : tous les ferraillages du modèle par ouvrage et par diamètre, avec mètres, kilos et nombre de barres de 12 m à commander ; enregistrable en CSV. Nécessite de redémarrer SketchUp une fois
- Pictogrammes : textures, hachures, phases, charpente, zinguerie, couverture, planelle et axes redessinés en perspective
- Pictogrammes : porte, ouverture (fenêtre), plinthe, sol et cloison redessinés en perspective
- Ferraillage : nouveau réglage « Crochets aux extrémités » : les crochets (10 Ø à chaque bout, 7 cm minimum) sont comptés dans les mètres et les kilos des barres (ils ne sont pas dessinés)
- Charpente : la coupe de la fenêtre montre mieux la sablière et la faîtière (épaisseurs agrandies, contrastes renforcés)
- Charpente : nouvelle fenêtre avec coupe d'un pan à l'échelle (chevron, liteaux, sablière, faîtière) et curseurs en direct (entraxe, pas des liteaux) ; la charpente se refait sous tous les pans à chaque réglage, avec le bilan en mètres et en m³. Nécessite de redémarrer SketchUp une fois
- Charpente : la sablière et la faîtière sont maintenant comptées en mètres dans le métré, et le message final donne le volume de bois en m³ (sections choisies, hors chutes)
- Détail / Présentation (nouveau, bouton dans « Dessiner ») : un clic bascule le même modèle entre le mode détail (barres du ferraillage visibles, béton transparent) et le mode présentation (ferraillage masqué, béton plein) ; rien n'est supprimé. Nécessite de redémarrer SketchUp une fois
- Ferraillage : les barres de plus de 12 m sont coupées en barres de 12 m avec un recouvrement de 40 Ø, ajouté aux mètres et aux kilos (le nombre de jonctions est affiché)
- Pictogrammes : escalier, fondation, ferraillage, toiture et garde-corps redessinés en perspective pour qu'on reconnaisse l'objet au premier coup d'œil
- Escalier : nouvelle option « Structure béton + ferraillage » : marches et paillasse inclinée coulées d'un bloc (épaisseur réglable), barres principales suivant la pente et barres de répartition en 3D, grille dans le palier, mètres et kilos par diamètre repris dans le métré ; réglable en direct comme le reste de l'escalier
- Semelles : nouveau champ « Béton de propreté (cm) » : une couche de béton de propreté, 5 cm plus large de chaque côté, est posée sous la semelle (balise A2M_BETON_PROPRETE), et se refait avec « Modifier ce que j'ai dessiné »
- Ferraillage : nouveau type « Semelle filante (suit le tracé) » : barres longitudinales basses et hautes qui suivent le contour du béton (angles compris) et barres transversales à l'espacement choisi, avec mètres et kilos par diamètre ; un béton déjà ferraillé est repris et non doublé
- Mise à jour : le fichier du Ferraillage est enfin dans le paquet d'installation (la 2.98.0 ne se chargeait pas)
