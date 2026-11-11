# Prompt de reprise — extension SketchUp « Métré Atelier 2M »

Copie tout ce qui suit dans une nouvelle conversation (ouverte depuis l'application Claude de bureau, sur l'ordinateur où est SketchUp).

---

Tu reprends le développement de mon extension SketchUp « **Métré Atelier 2M** ». Lis d'abord ce message en entier, puis `sketchup/REPRISE.md`, `sketchup/NOTICE.md` et `sketchup/PROMPT_REPRISE.md` dans le dépôt, avant de toucher à quoi que ce soit.

## 1. Qui je suis, comment travailler avec moi
- Je m'appelle Mathieu, dessinateur modeleur 3D en architecture (Atelier 2M, Brive-la-Gaillarde). Je suis **débutant en programmation** et j'ai du mal avec l'anglais : réponds **en français**, de façon pédagogique, avec des mots simples, tous les libellés des outils en français.
- **Une seule question à la fois.** Agis sur les réponses claires sans demander de confirmation superflue. Je te fais entièrement confiance pour faire évoluer l'extension : avance sans me demander à chaque étape, envoie-moi des captures d'écran pour que je voie l'évolution.
- **Pousse sur GitHub à chaque modification** (dépôt `Matmor19/metre-atelier2m`, dossier `sketchup/`, branche `main`), sans demander « publier ? ». Chaque modification : `ruby -c`, monter `EXT.version` dans `a2m_metre_chargeur.rb` (obligatoire à chaque reconstruction, sinon la mise à jour n'est pas proposée), ajouter la nouveauté dans `nouveautes.json`, lancer `python3 build_rbz.py` (régénère aussi `NOTICE.md`/`notice.html`), commit avec les lignes d'attribution, push.
- **Notice à jour à chaque modification** (`notice_details.json`, clé = nom d'icône), et la republier en artefact quand je le demande.
- **Une mise à jour doit s'utiliser tout de suite, sans fermer/rouvrir SketchUp.** Les réglages (curseurs) s'appliquent instantanément, sans bouton « Appliquer ».
- **Pas d'outil qui fonctionne à moitié.** Si tu n'arrives pas à égaler le plugin e-sketch sur une fonction, dis-le franchement.
- Simplicité et rapidité : le moins de paramètres possible (déduis ce qui peut l'être), tout en restant très facile à modifier. Le côté ludique compte, j'aime la technicité.
- Tout ce que je dessine avec les outils doit pouvoir être **rouvert** (« Modifier ce que j'ai dessiné »). Les outils de dessin (toiture, escalier, garde-corps, zinguerie…) ont une **fenêtre avec coupe et/ou vue de dessus à l'échelle**, tout se règle avec curseurs et cases.
- **Les profils et objets que je dessine dans ma bibliothèque sont utilisés tels quels** (je les dessine exactement comme le produit vendu). Je prépare moi-même les matières nommées `A2M_…` et leur échelle : tu les conserves. Un objet réel = un seul tag.
- **Les tuiles ne sont pas modélisées une par une** : seuls les faîtages et arêtiers sont gérés, avec mes objets.
- Rien d'automatique dans les choix d'ouvrages du métré ; une case vide = rien au métré ; codes couleur jaune (rempli) / blanc (à choisir) / bleu pâle (aucun).
- Phases : à démolir en rouge, à construire en bleu, existant conservé en gris. Altitudes : le dessous de la dalle est le niveau 0, ce qui est dessiné dessous est en négatif.
- Mes touches X et N sont déjà prises par mes raccourcis SketchUp. Pour les tracés, axes bloqués automatiquement avec déverrouillage en un clic ou raccourci.

## 2. Comment te connecter à mon SketchUp
- Ouvre la conversation depuis l'application Claude de bureau sur mon PC et choisis « Lier à cet ordinateur ». Tu as alors les outils `mcp__remote-devices__*` (fichiers, shell, contrôle de l'écran).
- Demande l'accès à l'application **SketchUp 2027** (computer_resolve_access puis computer_request_access ; l'accès expire au bout d'environ 30 min, redemande-le). SketchUp est sur l'écran « **Odyssey G95SC** » (computer_switch_display) ; l'écran principal « LG IPS FULLHD » est un autre écran.
- Dossier de travail sur mon PC : `C:\Users\ateli\Documents\ATELIER 2M` (monté en `~/mnt/ATELIER 2M`). La bibliothèque est dans `Bibliothèque SketchUp/` (fichier `index.json`, dossiers Toiture, Zinguerie…). La suppression de fichiers y demande l'autorisation (`device_request_delete_permission`, chemin Windows complet).
- Le dépôt GitHub est à cloner avec `add_repo` (Matmor19/metre-atelier2m).
- Je t'ai donné **l'autorisation totale d'utiliser mon SketchUp**, MAIS : ne touche jamais à mes modèles de travail (ex. « CLOCHE SKETCHUP »). Pour tester, travaille dans un **modèle neuf** et ferme-le sans enregistrer (File > Nouveau ; Ctrl+N / Ctrl+W ne sont pas fiables). Ne ferme pas SketchUp : il demande d'enregistrer mes modèles.
- **Mettre à jour mon extension** : Extensions > Métré Atelier 2M > « Rechercher une mise à jour » → Oui → Oui (installation) → OK. La version installée s'affiche dans la barre d'état en bas.
- **Tester du code Ruby sans console** (la console Ruby est difficile à piloter) : ajouter temporairement dans le plugin un bloc exécuté au chargement via `UI.start_timer(2,false)` déclenché par un **fichier-drapeau** déposé dans `Documents/ATELIER 2M`, qui crée un modèle neuf (`Sketchup.file_new`), construit l'objet à tester et écrit un rapport texte dans le même dossier, que tu lis avec `device_bash`. Le drapeau doit exister **avant** la mise à jour (le code ne s'exécute qu'au chargement). **Retire ce bloc ensuite** (nouvelle version) et supprime tes fichiers d'essai.
- Pour voir un résultat : captures d'écran, zoom avec la molette sur l'objet.
- Pièges SketchUp 2027 déjà rencontrés : voir `REPRISE.md` (read_default qui évalue le texte, Dir.glob et antislashs, transform_by_vectors qui abîme les arcs, composants dynamiques, hachures…). Autres : `BoundingBox#width/height/depth` = X/Y/Z en pouces ; `Transformation.axes` garde l'axe Z donné ; la bounding box d'une instance est la boîte transformée (pas serrée).

## 3. Version et état actuel
Version installée chez moi et poussée : **2.97.76** (dernier commit « retrait de l'essai temporaire, notice faîtage et arêtiers »). Le `REPRISE.md` du dépôt date de la 2.18 : il faut le mettre à jour.

### Ce qui est en place (travail récent)
**Zinguerie (`zinguerie.rb`)** — gouttière zinc demi-ronde 25 avec **mes objets de bibliothèque** : profil « Goutière Zinc », « Crochet goutière Dev 25 », « Naissance Dev 25 », « Colier descente zinc », « Regard béton pied de descente ».
- Gouttière construite par segments (suivi de profil), coupée de part et d'autre de chaque naissance ; crochets posés avec mon objet (pas sous une naissance) ; la gouttière se refait automatiquement quand on ajoute/modifie/supprime une descente (`refaire_gouttiere`).
- Descente Ø80 : naissance, tuyau, colliers (mon objet), regard en pied. Les autres types (demi 33, nantaise, profil alu, descentes autres que d80, coudes) utilisent encore des **formes provisoires**.
- Géométrie de calage mesurée sur mes objets : voir les commentaires de `zinguerie.rb` (cx, xg, z0…).

**Toiture (`toiture.rb`)** — 2 pans, 3 pans, 4 pans, monopente, « Suit les murs ».
- **Faîtage avec mes objets** « Tuile faitière canal », « About de faitière canal Gauche » et « Droite » : tuiles réparties de bout en bout (pas ≤ 48,5 cm, recouvrement de l'about 6,6 cm, about qui dépasse de 1 cm à chaque bout, bas de l'about 10,11 cm sous la ligne). Pas d'about là où un arêtier arrive. Règles relevées sur ma simulation.
- **About droit** : mes deux abouts sont dessinés dans le même sens (axe Y le long du faîtage, plaque du bout côté Y mini pour le gauche, Y maxi pour le droit) ; le droit est posé comme le gauche, décalé de sa longueur (corrigé en 2.97.74, validé par moi).
- **Arêtiers** : tuile faîtière posée de l'égout vers le faîtage, pas ≤ 48,5 cm, axe de la tuile = bissectrice des deux pans, **pas d'about** (je n'en ai pas dessiné).
- **Tuile faîtière = cône** : son axe dérive de 1,64 cm sur 49,6 cm (≈1,9°) ; on la tourne de cet angle pour que son **axe** (et non son bord droit) soit sur la ligne de faîtage / d'arêtier (2.97.75). À vérifier sur ma toiture réelle.
- Fenêtre de toiture avec coupe et plan à l'échelle (`toiture_fenetre.rb`), outil « Modifier la toiture », murs pignons.

**Autres** (voir `NOTICE.md`, 55 outils) : murs, ouvertures/menuiseries, hachures (fenêtre + moteur PNG), balises, niveaux, NGF, textures extérieures, cartouches, export CAO, bibliothèque, etc.

## 4. Points à VÉRIFIER (je te dirai ce qui ne va pas, un point à la fois)
1. **Faîtage et arêtiers sur mes vraies toitures** : tuile bien centrée sur son axe (faîtage ET arêtiers), 3 pans, monopente, « Suit les murs » (en L/T), faîtage non parallèle aux axes, pans de pentes différentes ; extrémités d'arêtier (égout et jonction avec le faîtage).
2. **Zinguerie** : gouttière+crochets+naissance+colliers+regard sur plusieurs bâtiments ; modification/suppression d'une descente ; gouttière sur arête inclinée ou en angle.
3. Outils jamais testés à fond : fenêtres/ouvertures, escalier, garde-corps, pose de portes.
4. **Blocage connu** : clic « Interagir » qui fige SketchUp sur les portes 63/83/73.
5. À retirer : surcharge temporaire `EntretienPortes` et menus « (provisoire) » de diagnostic dans Extensions (`portes_int.rb`, `import_objet.rb`, `MENU_DIAG`, `diagnostic`).
6. Fichiers de diagnostic anciens dans `Documents/ATELIER 2M` : `diag_portes.txt`, `diag_portes_chauvat.txt` (pas de moi cette session ; demande-moi avant de les supprimer).

## 5. Points à AMÉLIORER (dans l'ordre que je validerai)
1. **Arêtiers** : about/finition d'arêtier (je dessinerai l'objet), tuile de départ à l'égout.
2. **Zinguerie, suite** : coudes (objets à venir), autres gouttières/descentes (demi 33, nantaise, alu), vue de dessus des descentes.
3. **Ardoise** : profil extrudé (objet à dessiner par moi), couverture zinc.
4. **Lucarnes** : je dessine moi-même les objets (capucine, jacobine, rampante…) ; l'outil les pose sur un pan en s'adaptant (pente du pan et de la lucarne, hauteur de joues, largeur réglable symétrique = largeur de menuiserie + 2 jambages, percement de la couverture, noues). Fenêtre avec vue de dessus + coupe. Visuel seulement, métré inchangé.
5. **Feuille de route des fenêtres à coupe / vue de dessus** (`REPRISE.md`, 11 outils : toiture, escalier, garde-corps, ouverture, fondations, charpente, couverture, parois et sols, relevé de côtes, porte intérieure/électricité, zinguerie). Commence par extraire le socle commun (champ curseur+case, échelle SVG, envoi différé) dans `panneau.rb`.
6. Mettre à jour `REPRISE.md`, republier la notice en artefact, tester les outils non vérifiés, nettoyer les menus provisoires.

## 6. Pour démarrer
Sans me poser de question : lis les fichiers du dépôt, clone-le, vérifie que tu es lié à mon ordinateur et à SketchUp, regarde la version installée (barre d'état de SketchUp) et compare avec `EXT.version`. Puis résume-moi en quelques lignes où on en est et propose-moi le premier point à vérifier (le faîtage et les arêtiers sur une toiture de mon modèle).
