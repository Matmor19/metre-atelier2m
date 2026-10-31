# Reprise du travail — extension SketchUp « Métré Atelier 2M »

État au 31/10/2026 : version **2.18.0** publiée et installée chez Mathieu (SketchUp 2027, Windows).

## Méthode de travail (à respecter)
- Répondre en français, ton pédagogique, niveau débutant. Une seule question à la fois.
- Après chaque modification : `ruby -c`, monter la version dans `a2m_metre_chargeur.rb`, mettre les nouveautés dans `nouveautes.json`, `python3 build_rbz.py`, commit (avec les lignes d'attribution), push sur `main`. Ne pas demander « publier ? ».
- Outils SketchUp : simplicité et rapidité, le moins de paramètres possible (déduire ce qui peut l'être).
- Libellés en français (Mathieu a du mal avec l'anglais).
- Rien d'automatique dans le choix des ouvrages ; case vide = rien au métré ; chaque liste a son crayon ; couleurs jaune / blanc / bleu pâle.
- Mise à jour chez Mathieu : `A2M::MiseAJour.verifier(true)` dans la console Ruby (Extensions › Développeur › Console Ruby), puis redémarrer SketchUp. Pour tester sans redémarrer : `D=File.join(Sketchup.find_support_file('Plugins'),'a2m_metre'); load File.join(D,'fichier.rb')`.
- Prise en main de son PC : la console Ruby est sur l'écran « LG IPS FULLHD » (saisie vers (375,541)) ; SketchUp sur « Odyssey G95SC ». Ne pas interrompre s'il est en train de dessiner.

## Pièges SketchUp 2027 déjà rencontrés
- `Sketchup.read_default` évalue le texte (JSON cassé) : les réglages sont stockés dans des fichiers JSON (`Documents\Atelier 2M\Hachures\reglages.json`).
- `Dir.glob` ne marche pas avec des antislashs : toujours `.tr('\\', '/')` ; chemins Windows comparés sans tenir compte des majuscules.
- `transform_by_vectors` abîme les arcs : `explode_curve` avant.
- Composants dynamiques qui ignorent lenx/lenz : mise à l'échelle de l'instance puis `redraw` (le composant absorbe l'échelle).
- Hachures : calées sur l'**origine du modèle** (pas sur le groupe). `set_uv_scale(s)` : un carreau = s pouces. Coupe verticale : axe u du motif = horizontale du plan (y pour un plan x=cte, x pour un plan y=cte). Une hachure est par groupe/composant.
- Hachure en texture (`set_fill_texture_image_and_file_name`) : les zones transparentes laissent voir la couleur de la couche. Une hachure .pat n'a ni couleur de trait ni transparence.
- Bibliothèque de hachures SketchUp : `C:/ProgramData/SketchUp/SketchUp 2027/SketchUp/HatchPatterns` (.skh = zip). `save_fill_pattern_to_file` écrit le .pat sans ligne `*NOM`.

## Ce qui a été fait dans cette session (2.13.6 → 2.15.0)
- **Ouvertures** : toutes les couches collées sont percées (face d'entrée de la couche suivante confondue) ; face retournée → normale côté caméra ; menuiseries dynamiques mises à la taille par échelle si lenx/lenz ignorés.
- **Appuis / seuils** : longueur réelle gardée (un appui « 100 » fait 106 cm : 3 cm d'encastrement de chaque côté), centrés, coupés seulement si la longueur de la gamme dépasse. Même règle de choix que le configurateur (`decoupeEgale`). Le métré de l'application ne dépend pas de SketchUp.
- **Hachures** (fichiers `hachures.rb`, `hachures_moteur.rb`, `hachures_fr.rb`, `hachures_onde.rb`, `hachures/fenetre.html`, `hachures/a2m.pat`) :
  - fenêtre : couches à gauche, galerie à droite (aperçus dessinés en direct), recherche, filtre par provenance ;
  - réglages par couche : trait (couleur, opacité), épaisseur, fond (couleur, opacité), écartement en cm, angle ; aperçu puis bouton **Appliquer la hachure** ;
  - l'extension dessine elle-même le motif .pat en image PNG qui se répète (carreau périodique calculé) ;
  - sources : 23 motifs Atelier 2M, 83 de SketchUp (convertis), ZWCAD du poste (ZWCADISO 157 + zwcadusr), AutoCAD si présent, internet (65 de draftsperson.net, bouton Télécharger), dossiers ajoutés par Mathieu (bouton « Ajouter un dossier de hachures… », ex. `Documents\ATELIER 2M\02_BIBLIOTHEQUES\SKETCHUP\Texture PAT`) ;
  - noms traduits en français (dictionnaire + traduction mot à mot) ;
  - **Isolant ondulé centré** : ligne de laine en boucles au milieu de chaque couche en coupe verticale, largeur en % de l'épaisseur ; une hachure par groupe, pas choisi pour centrer tous les murs (écart ≈ 7 mm sur son doublage) ; à réappliquer après déplacement d'un mur.

## Session du 31/10/2026 (2.16.0)
- **NGF** (`ngf.rb`) : menu Extensions > Métré Atelier 2M > « Recaler le NGF » (une saisie : altitude NGF de l'origine du modèle, stockée dans les attributs du modèle, géométrie non déplacée) ; « Poser une cote NGF au point cliqué » écrit la cote sur coupe ou plan de masse. Pas de bouton de barre d'outils : pas encore d'icône.
- À tester chez Mathieu : recalage, cote sur une coupe réelle, et vérifier que l'origine correspond bien à 0,00 au modèle importé.

## Textures extérieures (2.17.0)
- Dossier `sketchup/textures/` : enduits, parements, bardages, RAL (menuiseries), vitrages, tuiles, zinguerie, appuis et seuils. Images JPG 512 px + miniatures 160 px (`textures/miniatures/`). Générées par `generer_textures.py` (pas de téléchargement).
- Panneau : menu Extensions > Métré Atelier 2M > « Textures extérieures… » (`textures.rb`). Sans sélection : s'applique aux balises du métré (murs, menuiseries, toiture). Avec sélection : à la sélection (zinguerie, appuis, seuils).
- 2.18.0 : six familles ajoutées (gros œuvre, isolants, panneaux, bois brut, sols, extérieurs), sans balise (sélection seulement). Vitrage détecté dans les menuiseries balisées (2.17.1).
- En attente de Mathieu : équivalences RAL réelles (noms de fichiers à mettre à jour dans `ral/`), puis test d'affichage dans SketchUp 2027.
- Pas encore fait : vitrage sur la seule partie vitrée d'une menuiserie (aujourd'hui, la menuiserie entière prend une couleur RAL ou un vitrage par sélection).

## En attente
- Retour de Mathieu sur les cotes NGF (recalage, lisibilité de la cote sur la coupe).
- Retour de Mathieu sur l'isolant ondulé en vraie coupe (taille des boucles, épaisseur du trait).
- Vérifier l'écartement réel en cm et le sens de l'angle des hachures ordinaires.
- Anciennes propositions sans réponse : ligne de métré pour les planelles ; recul du sol quand une porte intérieure est déplacée.
- archweb.com : ses .pat demandent un compte → Mathieu les télécharge et les met dans son dossier Texture PAT.
