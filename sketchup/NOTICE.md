# Métré Atelier 2M — notice d'utilisation (version 2.82.3)

Notice générée automatiquement à chaque version : chaque bouton de la palette y figure, avec son rôle et, quand il est détaillé, la marche à suivre.


## Préparer

### Tableau de bord du modèle
Contrôle du modèle et métré en direct dans une seule fenêtre : points à vérifier cliquables, surfaces, linéaires et menuiseries par pièce, envoi au métré

### Créer les balises du métré
Crée les balises A2M_ du métré (dossier « Métré A2M »), sans toucher à celles qui existent

### Baliser la sélection
Met la balise choisie sur les groupes, composants, faces ou lignes sélectionnés

### Baliser et nommer les pièces
Met A2M_PIECE sur les groupes de sol sélectionnés et demande le nom de chaque pièce

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

### Contrôle du modèle
Vérifie balises, solides, chevauchements, pièces et menuiseries avant l'extraction

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
Toiture 2 pans, 4 pans ou monopente sur les murs sélectionnés : pente, débord et épaisseur

### Charpente (chevrons, liteaux)
Chevrons à l'entraxe choisi, contre-liteaux, liteaux au pas de la couverture, faîtière et sablière sous chaque pan, avec les linéaires pour le métré

### Couverture (ardoise, tuiles, zinc)
Pose ardoise, tuile mécanique ou plate, zinc à joints debout ou bac acier sur les pans de la toiture : rangs, joints décalés, nervures, teintes variées, surface au métré

### Zinguerie (gouttières, descentes)
Gouttières demi-rondes ou nantaises sur tous les égouts de la toiture, descentes d'eaux pluviales jusqu'au sol, linéaires pour le métré

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

### Textures extérieures
Enduits, RAL des menuiseries, tuiles, zinguerie, appuis… : texture visuelle d'un élément pour la présentation client (hors métré)

### Textures A2M_ automatiques
Pose sur les éléments dessinés (murs de soubassement, semelles…) les matières A2M_ de leur type, sur les murs existants ou la sélection

- Applique automatiquement vos matières A2M_ selon la balise de chaque objet. Vos matières et la taille de leurs motifs ne sont jamais modifiées.

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

### Extraire pour le configurateur
Enregistre le fichier .json à importer dans le configurateur du métré

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

### Palette Atelier 2M
Ouvre la palette flottante : boutons espacés, animés au survol, rangés par étape, avec leur explication


## Dernières nouveautés

- Hachure depuis un dessin : deux curseurs « Déplacer » (gauche-droite et haut-bas, en cm) pour caler la cellule dans le mur
- Hachure depuis un dessin : les courbes qui frôlent le bord de la cellule ne perdent plus de trait (à recréer depuis ta sélection) ; meilleur centrage de la cellule sur tous les murs d'un même groupe
- Hachure depuis un dessin : sur les murs, la cellule est maintenant posée objet par objet, centrée sur l'épaisseur de chaque mur (comme l'isolant ondulé), à sa vraie largeur (14 cm) et sans coupure d'un mur à l'autre
- Hachures de coupe : nouveau bouton « Hachure depuis ma sélection… ». Tu dessines une cellule (rectangle de 14 cm de large avec ses traits et courbes), tu la sélectionnes, et elle devient une vraie hachure (groupe « Mes dessins »), utilisable sur « Doublage : isolant ». Couleurs, épaisseur et taille réglables comme les autres.
- Hachures de coupe : les fichiers de hachures SketchUp (.skh) placés dans « Dossier des motifs » ou dans un dossier ajouté sont maintenant repris dans la liste, comme les .pat
- Hachures de coupe : tes propres hachures SketchUp (ex. « A2M_Isolant 140 », créées après la première ouverture, ou présentes dans le modèle) apparaissent maintenant dans la liste, groupe « SketchUp » ; la liste se met à jour à chaque ouverture
- Mur composé : nouvelle fenêtre avec couche d'insertion (★, en surbrillance, par défaut le mur périphérique). Le tracé est la face extérieure de cette couche ; l'enduit extérieur se place de l'autre côté du tracé, les doublages à l'intérieur. Aperçu en coupe dans la fenêtre. Même choix dans la bibliothèque de compositions
- Plan 2D : chaque objet de la bibliothèque a maintenant son image 2D indépendante ; clic droit sur l'image (sur le plan) ou sur l'objet : « Version couleur / Version blanche » pour cet objet seulement
- Bibliothèque : « Poser » ne dépose plus l'objet à l'origine : il suit la souris (emprise orange), un clic le pose, ← → le pivotent de 90°, Échap annule. Sur le Plan 2D, l'image 2D de l'objet (couleur) apparaît toute seule à sa place et le suit quand on le déplace ; clic droit sur l'objet : « image 2D du plan » en version couleur ou blanche (ou sur le groupe des symboles : tous les objets d'un coup)
- Ranger un objet dans la bibliothèque : nouvelle fenêtre « Ranger » (nom, dossier existant avec son nombre d'objets ou « + Nouveau dossier », pièce) à la place de la longue liste de questions. Les détails de menuiserie (vantaux, matériau, vitrage…) ne sont demandés que pour les fenêtres et portes
- Nouveau bouton « Contrôler et préparer un objet » (Bibliothèque) : pour un objet déjà dans le modèle, il le réunit en un composant, retire les éléments parasites, retourne les faces à l'envers, vérifie la taille (propose la mise à l'échelle si elle est douteuse), le poids et le nom, purge le modèle, puis propose de le ranger dans la bibliothèque avec ses images 2D
- Bibliothèque d'objets : nouveau bouton « Poser l'image 2D » (dessus ou face, couleur ou blanc) qui place l'image de l'objet sur le plan, à l'échelle de la largeur/hauteur indiquée, sur le tag A2M_SYMBOLES_2D. Les objets rangés avant cette version voient leurs images recréées automatiquement au premier usage
- Vues 2D d'un objet : en plus des images aux couleurs d'origine (dessus et face), la même image en version blanche (fichiers « …_blanc.png »), créée en même temps au rangement dans la bibliothèque
- Coupes automatiques : chaque coupe a maintenant son nom modifiable (Entrée), ses boutons 2D et 3D (scène élévation et/ou scène coupe 3D, au choix par coupe) et le bouton « Inverser toutes les coupes »
- Renommé : « Isolant derrière les planelles » devient « Isolant dans la planelle » (c'est la partie à l'intérieur de la planelle)
- Hachures de coupe : la dalle béton (rez-de-chaussée) et le plancher d'étage sont maintenant dans la liste des couches, pour leur donner une hachure de coupe comme aux autres
- Correction : planelles — retrait du nettoyage d'arêtes (pouvait vider la planelle) ; en cas d'erreur, le message indique l'endroit précis
- Planelles : la coque est refaite creuse, comme ton dessin — les cavités du profil sont des trous de l'anneau au lieu d'être posées sur une coque pleine (plus de traits en trop ni de faces superposées) ; la dalle est coupée avec la coque pleine puis la coque creuse la remplace
- Planelles : la planelle est maintenant UN SEUL objet (groupe A2M_PLANELLE contenant la coque et l'isolant, chacun avec sa texture) ; les traits inutiles du profil (points alignés, arêtes dans le même plan) sont supprimés à la pose sans modifier la forme ; les textures et hachures de chaque rôle sont posées sans recréer le tag « Isolant de planelle »
- Correction : « Dessiner un sol » sur les murs sélectionnés — les murs de soubassement sont maintenant reconnus (message « Aucun mur balisé trouvé ») ; avec « Au-dessus du tracé », la dalle repose sur le dessus des murs sélectionnés
