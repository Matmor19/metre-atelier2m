# Construit l'extension a2m_metre.rbz à partir de a2m_extraction.rb et balises.rb
import os, zipfile, shutil
ici = os.path.dirname(os.path.abspath(__file__))
s = open(os.path.join(ici, 'a2m_extraction.rb'), encoding='utf-8').read().rstrip()
assert s.endswith('A2M::Extraction.lancer')
s = s[:-len('A2M::Extraction.lancer')].replace("require 'json'", "require 'json'\nrequire 'sketchup.rb'", 1)
s += r'''
%w[panneau balises hachures planelles profils pointage palette suivi maj bibliotheque import_objet vues tableau nomenclature phases plan2d miniplan coupes couverture zinguerie gardecorps escalier charpente calage reglementaire export_cao fiche_piece releve variantes cartouches feuille dossier_client dessin_murs dessin_sols ouvertures portes_int menu_contextuel cotation_auto styles mes_elements plinthes controle toiture pieces_auto fondations electricite envoi ngf textures tapee objets_menuiseries].each { |f| require File.join(File.dirname(__FILE__), f) }

# Menus : Extensions > Métré Atelier 2M, clic droit, barre d'outils
unless file_loaded?(__FILE__)
  ACTIONS_A2M = [
    # [icône, titre, bulle (barre d'état), action, séparateur après]
    ['balises',     'Créer les balises du métré',          'Crée les balises A2M_ du métré (dossier « Métré A2M »), sans toucher à celles qui existent', -> { A2M::Balises.creer }, false],
    ['baliser',     'Baliser la sélection',                'Met la balise choisie sur les groupes, composants, faces ou lignes sélectionnés', -> { A2M::Balises.baliser_selection }, false],
    ['pieces',      'Baliser et nommer les pièces',        'Met A2M_PIECE sur les groupes de sol sélectionnés et demande le nom de chaque pièce', -> { A2M::Balises.nommer_pieces }, false],
    ['pieces_auto', 'Pièces automatiques',                 'Trouve les pièces fermées entre murs et cloisons, crée leur revêtement et demande leur nom', -> { A2M::PiecesAuto.lancer }, false],
    ['tableau',     'Tableau de bord du modèle',           'Contrôle du modèle et métré en direct dans une seule fenêtre : points à vérifier cliquables, surfaces, linéaires et menuiseries par pièce, envoi au métré', -> { A2M::Tableau.ouvrir }, false],
    ['controle',    'Contrôle du modèle',                  'Vérifie balises, solides, chevauchements, pièces et menuiseries avant l\'extraction', -> { A2M::Controle.lancer }, true],
    ['mur',         'Dessiner un mur',                     'Mur, doublage ou cloison : hauteur, épaisseur et tracé (axe ou face), posé sur sa balise', -> { A2M::DessinMurs.lancer }, false],
    ['compose',     'Dessiner un mur composé',             'Plusieurs couches en une fois (mur, isolant, plaque…), chacune sur sa balise', -> { A2M::DessinMurs.lancer_compose }, false],
    ['sol',         'Dessiner un sol ou un plafond',       'Dalle, plancher, isolant de sol, chape, revêtement, terrasse, allée ou plafond', -> { A2M::DessinSols.lancer }, false],
    ['toiture',     'Créer la toiture',                    'Toiture 2 pans, 4 pans ou monopente sur les murs sélectionnés : pente, débord et épaisseur', -> { A2M::Toiture.lancer }, false],
    ['planelle',    'Poser les planelles en rive de dalle', 'Planelles sur tout le pourtour de la dalle : votre profil dessiné (en L…, avec isolant), un profil de la bibliothèque ou un rectangle ; dans l\'épaisseur (dalle recoupée) ou à l\'extérieur', -> { A2M::Planelles.lancer }, false],
    ['hachures',    'Hachures de coupe par couche',        'Une hachure par type de couche (mur, isolant, plaque, cloison, chape…), posée automatiquement en dessinant ; peut aussi l\'appliquer au modèle déjà dessiné', -> { A2M::Hachures.regler }, false],
    ['textures',    'Textures extérieures',                'Enduits, RAL des menuiseries, tuiles, zinguerie, appuis… : texture visuelle d\'un élément pour la présentation client (hors métré)', -> { A2M::Textures.ouvrir }, false],
    ['fondation',   'Créer les semelles',                  'Semelles filantes sous les murs sélectionnés : largeur et hauteur', -> { A2M::Fondations.lancer }, true],
    ['axes',        'Axes verrouillés / tracé libre',      'Par défaut les murs, sols et tracés suivent l\'axe rouge ou vert. Cette commande (ou la touche Ctrl, ou le clic droit, pendant le tracé ; vous pouvez aussi lui donner votre propre raccourci) passe en tracé libre et revient', -> { A2M::Pointeur.basculer }, false],
    ['ouverture',   'Créer une ouverture',                 'Largeur et hauteur suffisent : porte ou fenêtre reconnue, menuiserie et appui ou seuil proposés ; perce toutes les couches, suit la menuiserie déplacée', -> { A2M::Ouvertures.lancer }, false],
    ['porte',       'Poser une porte intérieure',          'Bloc-porte de passage (63 à 103 × 204) dans une cloison ou un refend : réservation, toute l\'épaisseur, centré, sens au Tab, choix du configurateur', -> { A2M::PortesInt.lancer }, false],
    ['plinthe',     'Poser les plinthes',                  'Plinthes le long du revêtement sélectionné, avec votre profil ou un profil de la bibliothèque, coupées aux portes', -> { A2M::Plinthes.lancer }, false],
    ['objet',       'Paramétrer un objet pour la bibliothèque', 'Menuiserie, porte, appui, seuil, façade de placard, plinthe, mobilier… : objet dessiné, éclaté ou composant dynamique (gardé entier), rangé dans la bibliothèque', -> { A2M::Bibliotheque.parametrer }, false],
    ['profils',     'Bibliothèque de profils',             'Vos profils (plinthe, planelle, couvertine, appui, bandeau…) : rangés depuis un dessin ou créés par leurs cotes, balayés le long d\'un tracé, utilisés par Plinthes et Planelles', -> { A2M::Profils.gerer }, false],
    ['importer',    'Importer un objet (3D Warehouse)',    'Cherche un objet sur la 3D Warehouse ou prend un fichier .skp, le nettoie puis le range dans la bibliothèque avec sa vignette', -> { A2M::ImportObjet.ouvrir }, false],
    ['vues',        'Vues prêtes à l\'emploi',             'Plan, façades Nord/Sud/Est/Ouest et perspective créés en scènes en un clic', -> { A2M::Vues.ouvrir }, false],
    ['nomenclature','Nomenclature des menuiseries',       'Tableau des fenêtres et portes (repères, dimensions, caractéristiques, pièces, quantités) : Excel ou page imprimable pour devis, DCE et commande', -> { A2M::Nomenclature.ouvrir }, false],
    ['phases',      'Phases : existant, démolition, construction', 'Marque les éléments à conserver (gris), à démolir (rouge) ou à construire (bleu), et affiche l\'état existant, la démolition ou le projet fini', -> { A2M::Phases.ouvrir }, false],
    ['plan2d',      'Plan 2D automatique',                 'Le plan 2D se déduit du 3D : coupe à hauteur choisie, murs en poché, arc et battant des portes, nom et surface de chaque pièce, scène prête pour LayOut', -> { A2M::Plan2D.ouvrir }, false],
    ['coupes',      'Coupes automatiques',                 'Coupe longitudinale ou transversale en un clic, ou tracée en 2 clics : scène prête, murs en poché, niveaux et cotes de hauteur automatiques, repère de coupe sur le plan 2D ; le plan de coupe se déplace ensuite avec l\'outil Déplacer', -> { A2M::Coupes.ouvrir }, false],
    ['couverture',  'Couverture (ardoise, tuiles, zinc)', 'Pose ardoise, tuile mécanique ou plate, zinc à joints debout ou bac acier sur les pans de la toiture : rangs, joints décalés, nervures, teintes variées, surface au métré', -> { A2M::Couverture.ouvrir }, false],
    ['zinguerie',   'Zinguerie (gouttières, descentes)',   'Gouttières demi-rondes ou nantaises sur tous les égouts de la toiture, descentes d\'eaux pluviales jusqu\'au sol, linéaires pour le métré', -> { A2M::Zinguerie.ouvrir }, false],
    ['calage',      'Caler un plan existant',              'Importe l\'image d\'un plan (PNG, JPG), puis deux clics sur une longueur connue et sa vraie valeur : le plan est mis à l\'échelle, et si vous voulez d\'équerre', -> { A2M::Calage.importer }, false],
    ['reglementaire','Surfaces réglementaires',           'Emprise au sol, surface de plancher (estimation), hauteur au faîtage et à l\'égout, reculs par rapport aux limites de propriété : les chiffres du permis, calculés depuis le 3D', -> { A2M::Reglementaire.ouvrir }, false],
    ['export_cao',  'Exporter pour ZWCAD (DWG / DXF)',     'Exporte le modèle en DWG ou DXF dans Documents/Atelier 2M/Export CAO : chaque balise Métré A2M devient un calque pour ZWCAD', -> { A2M::ExportCAO.lancer }, false],
    ['charpente',   'Charpente (chevrons, liteaux)',       'Chevrons à l\'entraxe choisi, contre-liteaux, liteaux au pas de la couverture, faîtière et sablière sous chaque pan, avec les linéaires pour le métré', -> { A2M::Charpente.ouvrir }, false],
    ['cotation',    'Cotation automatique',                'Cotes de chaque pièce côté par côté et cotes hors tout du bâtiment, posées en un clic sur leur propre balise (masquable)', -> { A2M::CotationAuto.ouvrir }, false],
    ['styles',      'Styles de vue',                       'Intérieur, plan technique, coupe grise, construire et démolir, tracé sur plan : un clic change l\'aspect de la vue, avec vos favoris', -> { A2M::Styles.ouvrir }, false],
    ['mes_elements','Mes éléments',                        'Votre bibliothèque personnelle (tuiles, zinc, menuiseries, mobilier) : ajoutez la sélection en un clic, posez-la au clic dans le modèle', -> { A2M::MesElements.ouvrir }, false],
    ['escalier',    'Escalier',                            'Escalier droit, quart tournant ou demi-tournant : marches, contremarches, limons, loi de Blondel, côté mur', -> { A2M::Escalier.ouvrir }, false],
    ['gardecorps',  'Garde-corps',                         'Poteaux, main courante et remplissage (barreaux, câbles, verre, lisses, plein) le long d\'un tracé ou d\'un escalier', -> { A2M::GardeCorps.ouvrir }, false],
    ['releve',      'Relevé de côtes',                     'Tapez les mesures prises sur place (deux côtes, ou côté par côté avec les angles) : la pièce se dessine, nommée et balisée, avec sa surface', -> { A2M::Releve.ouvrir }, false],
    ['fiche',       'Fiche pièce',                         'Cliquez dans une pièce : surface, périmètre, murs à peindre, plinthes, menuiseries, portes et appareillage de la pièce, avec envoi au métré', -> { A2M::FichePiece.lancer }, false],
    ['variantes',   'Variantes client A / B / C',          'Trois versions du même projet dans un seul fichier : choisissez où chaque élément apparaît, puis un clic sur A, B ou C change tout ; une scène par variante pour présenter', -> { A2M::Variantes.ouvrir }, false],
    ['cartouches',  'Cartouches et charte',                'Votre logo, vos coordonnées, vos couleurs et les champs de vos cartouches : autant de modèles que voulu, utilisés par le dossier client et les feuilles de présentation', -> { A2M::Cartouches.ouvrir }, false],
    ['feuille',     'Feuille de présentation LayOut',      'Crée une feuille LayOut avec les vues choisies et le cartouche de votre charte, prête à compléter (cotes, annotations, échelle) dans LayOut', -> { A2M::Feuille.ouvrir }, false],
    ['dossier',     'Dossier de présentation client',      'Vues du modèle, surfaces par pièce, menuiseries et synthèse en un document aux couleurs d\'Atelier 2M, prêt à imprimer ou à enregistrer en PDF', -> { A2M::DossierClient.ouvrir }, false],
    ['biblio',      'Bibliothèque d\'objets',              'Poser un objet de la bibliothèque à la taille voulue (profils inchangés), ouvrir ou changer le dossier', -> { A2M::Bibliotheque.gerer }, false],
    ['elec',        'Poser l\'appareillage électrique',    'Prises, points lumineux, interrupteurs… posés au clic et comptés pièce par pièce', -> { A2M::Electricite.lancer }, true],
    ['extraire',    'Extraire pour le configurateur',      'Enregistre le fichier .json à importer dans le configurateur du métré', -> { A2M::Extraction.lancer }, false],
    ['envoi',       'Envoyer au métré',                    'Envoie l\'extraction directement au métré : bouton « Récupérer depuis SketchUp » dans le configurateur', -> { A2M::Envoi.lancer }, false],
    ['aide',        'Aide : balises reconnues',            'Liste des balises du métré et de leur usage', -> { A2M::Balises.aide }, true],
    ['palette',     'Palette Atelier 2M',                  'Ouvre la palette flottante : boutons espacés, animés au survol, rangés par étape, avec leur explication', -> { A2M::Palette.ouvrir }, false]
  ]
  menu = UI.menu('Extensions').add_submenu('Métré Atelier 2M')
  ACTIONS_A2M.each do |_ic, titre, _b, action, sep|
    menu.add_item(titre + '…') { action.call }
    menu.add_separator if sep
  end
  menu.add_item('Poser une menuiserie de la bibliothèque sur l\'ouverture sélectionnée…') { A2M::Suivi.poser_sur }
  menu.add_item('Réglages de l\'outil Ouverture…') { A2M::Ouvertures.regler }
  menu.add_item('Réglages de l\'envoi au métré…') { A2M::Envoi.reglages }
  menu.add_separator
  menu.add_item('Recaler le NGF (altitude du modèle)…') { A2M::Ngf.recaler }
  menu.add_item('Poser une cote NGF au point cliqué…') { A2M::Ngf.poser_cotes }
  menu.add_item('Textures extérieures (enduits, RAL, tuiles…)…') { A2M::Textures.ouvrir }
  menu.add_item('Créer les menuiseries types (2 porte-fenêtres, porte d\'entrée)…') { A2M::ObjetsMenuiseries.creer }
  menu.add_separator
  menu.add_item('Hachures de coupe par couche…') { A2M::Hachures.regler }
  menu.add_item('Appliquer les hachures au modèle') { A2M::Hachures.appliquer }
  menu.add_separator
  menu.add_item('Rechercher une mise à jour…') { A2M::MiseAJour.verifier(true) }
  menu.add_item('Dossier du fichier .rbz pour les mises à jour…') { A2M::MiseAJour.choisir_dossier }
  UI.add_context_menu_handler do |cm|
    next if Sketchup.active_model.selection.empty?
    # Les menus de Windows ne se colorent pas : un repère ◆ devant le nom pour le trouver d'un coup d'œil
    sm = cm.add_submenu('◆ Métré Atelier 2M')
    sm.add_item('Baliser la sélection…') { A2M::Balises.baliser_selection }
    sm.add_item('Baliser et nommer comme pièce(s)…') { A2M::Balises.nommer_pieces }
    sm.add_item('Poser les plinthes…') { A2M::Plinthes.lancer }
    sm.add_item('Paramétrer pour la bibliothèque…') { A2M::Bibliotheque.parametrer }
    sm.add_item('Poser une menuiserie de la bibliothèque sur l\'ouverture…') { A2M::Suivi.poser_sur }
    sm.add_item('Recaler l\'ouverture sur la menuiserie') { A2M::Suivi.recaler }
    sm.add_item('Créer la toiture sur ces murs…') { A2M::Toiture.lancer }
    sm.add_item('Créer les semelles sous ces murs…') { A2M::Fondations.lancer }
    sm.add_item('Pièces automatiques avec ces murs…') { A2M::PiecesAuto.lancer }
  end
  # Barre d'outils aux couleurs d'Atelier 2M : un pictogramme par bouton, une bulle d'aide au survol
  ico = File.join(File.dirname(__FILE__), 'icones')
  ext = Sketchup.platform == :platform_win ? '.svg' : '.pdf'
  ext = '.png' if Sketchup.version.to_i < 16
  tb = UI::Toolbar.new('Métré Atelier 2M')
  ACTIONS_A2M.each do |nom, titre, bulle, action, sep|
    cmd = UI::Command.new(titre) { action.call }
    cmd.tooltip = "#{titre} — #{bulle}"   # bulle au survol : le nom de l'outil et ce qu'il fait
    cmd.status_bar_text = bulle
    # Icônes de la barre : version avec marge (boutons aérés)
    cmd.small_icon = File.join(ico, "tb_#{nom}#{ext == '.png' ? '_16.png' : ext}")
    cmd.large_icon = File.join(ico, "tb_#{nom}#{ext == '.png' ? '_24.png' : ext}")
    tb.add_item(cmd)
    tb.add_separator if sep
  end
  tb.restore
  A2M::Palette.au_demarrage
  A2M::Suivi.demarrer
  A2M::MiseAJour.au_demarrage
  file_loaded(__FILE__)
end
'''
chargeur = open(os.path.join(ici, 'a2m_metre_chargeur.rb'), encoding='utf-8').read()
dest = os.path.join(ici, 'a2m_metre.rbz')
with zipfile.ZipFile(dest, 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr('a2m_metre.rb', chargeur)
    z.writestr('a2m_metre/main.rb', s)
    z.write(os.path.join(ici, 'menu_contextuel.rb'), 'a2m_metre/menu_contextuel.rb')
    z.write(os.path.join(ici, 'cotation_auto.rb'), 'a2m_metre/cotation_auto.rb')
    z.write(os.path.join(ici, 'styles.rb'), 'a2m_metre/styles.rb')
    z.write(os.path.join(ici, 'mes_elements.rb'), 'a2m_metre/mes_elements.rb')
    z.write(os.path.join(ici, 'balises.rb'), 'a2m_metre/balises.rb')
    z.write(os.path.join(ici, 'bibliotheque.rb'), 'a2m_metre/bibliotheque.rb')
    z.write(os.path.join(ici, 'dessin_murs.rb'), 'a2m_metre/dessin_murs.rb')
    z.write(os.path.join(ici, 'dessin_sols.rb'), 'a2m_metre/dessin_sols.rb')
    z.write(os.path.join(ici, 'ouvertures.rb'), 'a2m_metre/ouvertures.rb')
    z.write(os.path.join(ici, 'panneau.rb'), 'a2m_metre/panneau.rb')
    z.write(os.path.join(ici, 'import_objet.rb'), 'a2m_metre/import_objet.rb')
    z.write(os.path.join(ici, 'vues.rb'), 'a2m_metre/vues.rb')
    z.write(os.path.join(ici, 'tableau.rb'), 'a2m_metre/tableau.rb')
    z.write(os.path.join(ici, 'phases.rb'), 'a2m_metre/phases.rb')
    z.write(os.path.join(ici, 'fiche_piece.rb'), 'a2m_metre/fiche_piece.rb')
    z.write(os.path.join(ici, 'variantes.rb'), 'a2m_metre/variantes.rb')
    z.write(os.path.join(ici, 'releve.rb'), 'a2m_metre/releve.rb')
    z.write(os.path.join(ici, 'plan2d.rb'), 'a2m_metre/plan2d.rb')
    z.write(os.path.join(ici, 'gardecorps.rb'), 'a2m_metre/gardecorps.rb')
    z.write(os.path.join(ici, 'escalier.rb'), 'a2m_metre/escalier.rb')
    z.write(os.path.join(ici, 'charpente.rb'), 'a2m_metre/charpente.rb')
    z.write(os.path.join(ici, 'export_cao.rb'), 'a2m_metre/export_cao.rb')
    z.write(os.path.join(ici, 'reglementaire.rb'), 'a2m_metre/reglementaire.rb')
    z.write(os.path.join(ici, 'calage.rb'), 'a2m_metre/calage.rb')
    z.write(os.path.join(ici, 'couverture.rb'), 'a2m_metre/couverture.rb')
    z.write(os.path.join(ici, 'zinguerie.rb'), 'a2m_metre/zinguerie.rb')
    z.write(os.path.join(ici, 'coupes.rb'), 'a2m_metre/coupes.rb')
    z.write(os.path.join(ici, 'miniplan.rb'), 'a2m_metre/miniplan.rb')
    z.write(os.path.join(ici, 'cartouches.rb'), 'a2m_metre/cartouches.rb')
    z.write(os.path.join(ici, 'feuille.rb'), 'a2m_metre/feuille.rb')
    z.write(os.path.join(ici, 'dossier_client.rb'), 'a2m_metre/dossier_client.rb')
    z.write(os.path.join(ici, 'nomenclature.rb'), 'a2m_metre/nomenclature.rb')
    z.write(os.path.join(ici, 'plinthes.rb'), 'a2m_metre/plinthes.rb')
    for f in ('pointage', 'palette', 'suivi', 'maj', 'portes_int', 'hachures', 'hachures_moteur', 'hachures_fr', 'hachures_onde', 'planelles', 'profils'):
        z.write(os.path.join(ici, f + '.rb'), 'a2m_metre/' + f + '.rb')
    for f in ('controle', 'toiture', 'pieces_auto', 'fondations', 'electricite', 'envoi', 'ngf', 'textures', 'tapee', 'objets_menuiseries'):
        z.write(os.path.join(ici, f + '.rb'), 'a2m_metre/' + f + '.rb')
    for f in sorted(os.listdir(os.path.join(ici, 'hachures'))):
        z.write(os.path.join(ici, 'hachures', f), 'a2m_metre/hachures/' + f)
    # Bibliothèque de textures extérieures (JPG + miniatures) pour le panneau
    for racine, _dirs, fichiers in os.walk(os.path.join(ici, 'textures')):
        if '__pycache__' in racine:
            continue
        for f in fichiers:
            if f.endswith('.jpg'):
                chemin = os.path.join(racine, f)
                z.write(chemin, 'a2m_metre/textures/' + os.path.relpath(chemin, os.path.join(ici, 'textures')).replace(os.sep, '/'))
    dico = os.path.join(ici, 'icones')
    # Icônes de la barre d'outils avec une marge transparente autour de la tuile : boutons plus aérés
    import re, cairosvg
    for f in sorted(os.listdir(dico)):
        if f.endswith('.svg') and not f.startswith('tb_'):
            src = open(os.path.join(dico, f), encoding='utf-8').read()
            corps = re.sub(r'^.*?<svg[^>]*>|</svg>\s*$', '', src, flags=re.S)
            tb = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24"><g transform="translate(2.6 2.6) scale(0.783)">' + corps + '</g></svg>'
            n = f[:-4]
            z.writestr('a2m_metre/icones/tb_' + f, tb)
            z.writestr('a2m_metre/icones/tb_' + n + '.pdf', cairosvg.svg2pdf(bytestring=tb.encode()))
            for t in (16, 24):
                z.writestr('a2m_metre/icones/tb_%s_%d.png' % (n, t), cairosvg.svg2png(bytestring=tb.encode(), output_width=t, output_height=t))
    for f in sorted(os.listdir(dico)):
        if f.endswith(('.svg', '.pdf', '.png')):
            z.write(os.path.join(dico, f), 'a2m_metre/icones/' + f)
import json, re as _re
ver = _re.search(r"EXT.version = '([^']+)'", chargeur).group(1)
notes = json.load(open(os.path.join(ici, 'nouveautes.json'), encoding='utf-8'))
json.dump({'version': ver, 'notes': notes}, open(os.path.join(ici, 'version.json'), 'w', encoding='utf-8'), ensure_ascii=False, indent=1)
print('ok', dest, ver)
