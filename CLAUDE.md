# Métré Atelier 2M — consignes permanentes

## Qui, comment
- Mathieu (Atelier 2M, Brive), dessinateur 3D, débutant en programmation : réponses **en français**, pédagogiques, mots simples, **une question à la fois**. Libellés des outils en français.
- Cycle : demande → j'analyse le code → je propose → **accord de Mathieu** → je modifie → Mathieu teste lui-même dans SketchUp → corrections.
- **Je ne pilote jamais SketchUp** (pas de contrôle d'écran, pas de fichier-drapeau). Je ne touche pas aux modèles ni à la bibliothèque de Mathieu (`Documents\ATELIER 2M\…`).
- Bibliothèque d'objets du plugin (portes, menuiseries, profils, objets ; `index.json`) : `Documents\ATELIER 2M\BIBLIOTHEQUE A2M` (par défaut depuis la 2.111.6 ; `Bibliotheque.dossier`). L'ancien `Bibliothèque SketchUp` est une copie conservée. `02_BIBLIOTHEQUES\BIBLIOTHEQUE SKETCHUP` est la bibliothèque générale de Mathieu : le plugin ne l'utilise pas.
- Aucune installation, aucun push, aucune suppression sans accord explicite.

## Dépôt
- Espace de travail : `PLUGIN A2M\` (pas un dépôt). Seul dépôt Git : `PLUGIN A2M\metre-atelier2m` (GitHub `Matmor19/metre-atelier2m`, branche `main`). Git toujours lancé depuis là. Ne jamais créer d'autre dépôt ni déplacer de fichiers.
- `sketchup/` = **plugin SketchUp** (Ruby). Racine (`index.html`, `app.js`, `sw.js`, `tableau.html`, `metre_apps_script.gs`, `tests/`) = **application web du métré**, à ne pas confondre. Seul lien : le JSON d'extraction (`a2m_extraction.rb` ↔ `app.js` « Import SketchUp ») et l'action `deposer_sketchup` du script Google (`envoi.rb`).

## Architecture du plugin
- `a2m_metre_chargeur.rb` : déclare l'extension, **seule source de la version** (`EXT.version`).
- `main.rb` **n'existe pas dans le dépôt** : `build_rbz.py` le génère (extraction + liste `%w[...]` des modules + `ACTIONS_A2M` + menus/barre). **Nouveau module = l'ajouter à la liste `%w[...]` ET aux `z.write` de `build_rbz.py`.** Nouvel outil = ligne dans `ACTIONS_A2M`, id dans `Palette::GROUPES` (`palette.rb`), icône `icones/<id>.svg`, entrée dans `notice_details.json`.
- Code dans `module A2M::<Nom>`, méthodes `self.`, opérations `start_operation`/`commit_operation`, réglages d'un objet dans ses attributs `a2m…` (pour « Modifier ce que j'ai dessiné »).

## Construire (Windows) — seulement à la demande
Depuis `metre-atelier2m` :
`$env:Path = 'C:\msys64\ucrt64\bin;' + $env:Path; & '..\.venv\Scripts\python.exe' sketchup\build_rbz.py`
(le PATH n'est modifié que pour la commande). Régénère `a2m_metre.rbz`, `version.json`, `NOTICE.md`, `notice.html`.
Après chaque construction : **copier** `sketchup\a2m_metre.rbz` dans `C:\Users\ateli\Documents\ATELIER 2M\02_BIBLIOTHEQUES\SKETCHUP\a2m_metre.rbz` (remplace la copie précédente ; ne rien toucher d'autre dans ce dossier, qui contient les autres extensions et des modèles de Mathieu). Mathieu installe depuis ce fichier (Gestionnaire d'extensions, ou détection automatique si ce dossier est choisi dans « Dossier du fichier .rbz pour les mises à jour… ») puis redémarre SketchUp.

## Publier = distribuer
- `maj.rb` propose la mise à jour à tous dès que `version.json` sur `main` est plus récent. **Pas de push sans accord.**
- Test avant publication : Mathieu dépose le `.rbz` dans Téléchargements (détecté au démarrage) ou l'installe par le Gestionnaire d'extensions.
- Livraison validée : monter `EXT.version`, ajouter la nouveauté en tête de `nouveautes.json`, notice (`notice_details.json`), construire, commit (attribution), push après accord.
- Fichiers non rechargés à chaud (redémarrage requis) : `menu_contextuel palette plan2d suivi tableau variantes`, et `squelette.rb`.

## Pièges SketchUp 2027
- `Sketchup.read_default` évalue le texte : réglages complexes en fichiers JSON (`Documents\Atelier 2M\…`).
- `Dir.glob` : chemins avec `/` (`.tr('\\','/')`).
- `transform_by_vectors` abîme les arcs (`explode_curve` avant).
- Composants dynamiques : lenx/lenz parfois ignorés → échelle de l'instance puis `redraw`.
- `BoundingBox#width/height/depth` = X/Y/Z en pouces ; la bounding box d'une instance n'est pas serrée.
- Hachures calées sur l'origine du modèle.

## Vérifications
- Ruby : `ruby -c` sur chaque fichier modifié, avec `C:\msys64\ucrt64\bin\ruby.exe -c <fichier>` (Ruby 4.0 de MSYS2, plus récent que celui de SketchUp : ne détecte que la syntaxe).
- Pas de test automatique du plugin : la validation se fait dans SketchUp par Mathieu.
- En cas de problème dans SketchUp : lire `Documents\Atelier 2M\journal_erreurs.txt` (module `journal_erreurs.rb` : copie de la Console Ruby + erreurs rattrapées dans nos fichiers) et `journal_ouvertures.txt`. La Console Ruby de Mathieu s'ouvre hors de ses écrans visibles.
- `tests/regression.py` ne concerne que l'application web.

## Documents
- `sketchup/REPRISE.md` et `PROMPT_REPRISE.md` sont **anciens** (2.18 / 2.97.76) : vérifier dans le code avant de les croire.
