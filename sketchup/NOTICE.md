# Métré Atelier 2M — notice d'utilisation (version 2.97.55)

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

### Charpente (chevrons, liteaux)
Chevrons à l'entraxe choisi, contre-liteaux, liteaux au pas de la couverture, faîtière et sablière sous chaque pan, avec les linéaires pour le métré

### Couverture (ardoise, tuiles, zinc)
Pose ardoise, tuile mécanique ou plate, zinc à joints debout ou bac acier sur les pans de la toiture : rangs, joints décalés, nervures, teintes variées, surface au métré

### Zinguerie (gouttières, descentes)
Gouttières (zinc dév. 25 et 33, nantaise, alu) avec crochets sur les égouts ; descente placée au clic sur l'égout et réglée sur une coupe : coudes, tuyau horizontal contre le mur, colliers répartis, regard en pied ; linéaires pour le métré

### Escalier
Escalier droit, quart tournant ou demi-tournant : marches, contremarches, limons, loi de Blondel, côté mur

### Garde-corps
Poteaux, main courante et remplissage (barreaux, câbles, verre, lisses, plein) le long d'un tracé ou d'un escalier

### Créer les semelles
Semelles filantes sous les murs sélectionnés : largeur et hauteur

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
- Il réunit les morceaux en un composant, retire les éléments parasites, retourne les faces à l'envers, vérifie la taille (propose la mise à l'échelle si elle est douteuse), le poids et le nom, puis purge le modèle.
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

- Configurateur d'ouverture : plus de modèle « Fixe » pour les portes-fenêtres ; pour « Coulissante », choix du nombre de vantaux (2, 3 ou 4) et du galandage (aucun, d'un côté, des deux côtés), dessiné dans l'aperçu et repris dans la fiche menuiserie
- Configurateur d'ouverture : la fenêtre oscillo-battant montre maintenant son symbole (battant et oscillant en pointillés) aussi dans le grand aperçu, comme les autres modèles
- Toiture, murs pignons : choix du type de mur : brique, parpaing (épaisseur réglable) ou mur composé pris dans vos compositions de murs (une pièce par couche, balises conservées, structure sur la balise Mur pignon)
- Toiture : case « Murs pignons » (2 pans et monopente). Elle crée les deux murs pignons aux extrémités du faîtage, jusqu'à la sous-face de la toiture, avec l'épaisseur réglable ; ils sont sur la balise Mur pignon et se refont avec la toiture
- Garde-corps : nouvelle fenêtre avec élévation d'une travée (barreaux, câbles, lisses, verre, plein : vide entre barreaux contrôlé à 11 cm, hauteur à 100 cm) et vue de dessus du tracé avec les poteaux. Hauteur, entraxe, section des poteaux, vide sous le remplissage, espacement des barreaux, écart des câbles et nombre de lisses se règlent en direct une fois le garde-corps posé
- Escalier : nouvelle fenêtre avec vue de dessus et coupe à l'échelle, qui se dessinent à mesure des réglages (forme, hauteur, largeur, giron, nombre de marches, loi de Blondel). Une fois l'escalier posé en 2 clics, chaque réglage le refait en direct dans le modèle ; il se rouvre avec « Modifier ce que j'ai dessiné »
- Toiture : nouvelle fenêtre avec vue de dessus et coupe à l'échelle (pans, faîtage et arêtiers, sens de la pente, murs). Type, pente, débord, épaisseur, sens du faîtage et numéro se règlent avec des curseurs et la toiture du modèle suit en direct. S'ouvre avec « Créer la toiture » et « Modifier la toiture » (ancienne fenêtre gardée en réserve)
- Zinguerie refaite : choix de la gouttière (zinc dév. 25, dév. 33, nantaise, alu) avec crochets, et descente placée au clic sur l'égout. Une coupe dans la fenêtre règle tout en direct : distance au mur, coudes, tuyau horizontal, colliers de départ et d'arrivée répartis régulièrement, regard en pied. Rouvrable avec « Modifier ce que j'ai dessiné ». Pièces provisoires en attendant vos objets (coudes, colliers, crochets, naissances, regard)
- Toiture 3D : faîtages et arêtiers posés automatiquement le long des arêtes entre pans (visuel seulement, pas de tuiles). Balises A2M_FAITAGE_3D et A2M_ARETIER_3D, ignorées par le métré qui reste au mètre linéaire. Ils suivent « Modifier la toiture »
- Outil provisoire : refait les portes Chauvat 63 et 83 de la bibliothèque à partir de la 73 (battant fermé, quincaillerie complète)
- Outil provisoire d'entretien des portes Chauvat de la bibliothèque (relevé de leur structure)
- Niveaux : « Caler le zéro sur un point cliqué » ne plante plus SketchUp au deuxième recalage. Le déplacement du modèle se fait maintenant après la fin du clic et la fermeture de l'outil, plus pendant l'événement du clic
- Suivi des ouvertures : quand un mur ne peut pas être rebouché (mur non solide), le rebouchage est ignoré et noté au journal, au lieu de provoquer une erreur « reference to deleted Group » qui pouvait déstabiliser SketchUp
- Niveaux : « Caler le zéro sur un point cliqué » ne casse plus les murs percés (des bouchons apparaissaient au-dessus des portes). Le suivi des ouvertures est suspendu pendant le déplacement et leurs altitudes mémorisées sont décalées du même montant
- Bibliothèque : bouton « Vignette (vue actuelle) ». Pose l'objet dans le modèle, règle ta vue, sélectionne-le, clique le bouton : la vignette de la bibliothèque est refaite avec cette vue (objet isolé, fond transparent) puis le modèle est remis comme avant
- Fenêtre de la bibliothèque : les réglages de l'image 2D sont repliés (un clic pour les ouvrir), ce qui laisse plus de place aux vignettes
- Bibliothèque : portes triées dans l'ordre naturel (63, 73, 83, 93, 103), vignettes plus grandes et alignées en rangées régulières dans la fenêtre de la bibliothèque et dans le choix de la porte ; l'ancienne version non animée des portes 83, 93 et 103 est mise de côté et les versions animées portent le nom propre « B.P 83x204 Chauvat »
- Rangement d'un objet dans la bibliothèque : un composant dynamique (ex. panneau de porte qui s'ouvre au clic) n'est plus éclaté à la préparation, il garde son animation une fois rangé (c'était la cause de la porte 73 qui ne s'ouvrait plus après rangement)
- Bibliothèque : un objet enregistré à nouveau (ex. une porte rendue dynamique) est rechargé à la pose au lieu de réutiliser son ancienne version gardée dans le modèle
- Portes dont le panneau est déjà dynamique : l'animation automatique ne fait plus de copie de la porte (elle cassait l'ouverture au clic de la 73)
