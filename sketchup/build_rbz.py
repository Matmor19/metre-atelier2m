# Construit l'extension a2m_metre.rbz à partir de a2m_extraction.rb et balises.rb
import os, zipfile, shutil
ici = os.path.dirname(os.path.abspath(__file__))
s = open(os.path.join(ici, 'a2m_extraction.rb'), encoding='utf-8').read().rstrip()
assert s.endswith('A2M::Extraction.lancer')
s = s[:-len('A2M::Extraction.lancer')].replace("require 'json'", "require 'json'\nrequire 'sketchup.rb'", 1)
s += r'''
%w[balises hachures planelles profils pointage palette suivi maj bibliotheque dessin_murs dessin_sols ouvertures portes_int plinthes controle toiture pieces_auto fondations electricite envoi].each { |f| require File.join(File.dirname(__FILE__), f) }

# Menus : Extensions > Métré Atelier 2M, clic droit, barre d'outils
unless file_loaded?(__FILE__)
  ACTIONS_A2M = [
    # [icône, titre, bulle (barre d'état), action, séparateur après]
    ['balises',     'Créer les balises du métré',          'Crée les balises A2M_ du métré (dossier « Métré A2M »), sans toucher à celles qui existent', -> { A2M::Balises.creer }, false],
    ['baliser',     'Baliser la sélection',                'Met la balise choisie sur les groupes, composants, faces ou lignes sélectionnés', -> { A2M::Balises.baliser_selection }, false],
    ['pieces',      'Baliser et nommer les pièces',        'Met A2M_PIECE sur les groupes de sol sélectionnés et demande le nom de chaque pièce', -> { A2M::Balises.nommer_pieces }, false],
    ['pieces_auto', 'Pièces automatiques',                 'Trouve les pièces fermées entre murs et cloisons, crée leur revêtement et demande leur nom', -> { A2M::PiecesAuto.lancer }, false],
    ['controle',    'Contrôle du modèle',                  'Vérifie balises, solides, chevauchements, pièces et menuiseries avant l\'extraction', -> { A2M::Controle.lancer }, true],
    ['mur',         'Dessiner un mur',                     'Mur, doublage ou cloison : hauteur, épaisseur et tracé (axe ou face), posé sur sa balise', -> { A2M::DessinMurs.lancer }, false],
    ['compose',     'Dessiner un mur composé',             'Plusieurs couches en une fois (mur, isolant, plaque…), chacune sur sa balise', -> { A2M::DessinMurs.lancer_compose }, false],
    ['sol',         'Dessiner un sol ou un plafond',       'Dalle, plancher, isolant de sol, chape, revêtement, terrasse, allée ou plafond', -> { A2M::DessinSols.lancer }, false],
    ['toiture',     'Créer la toiture',                    'Toiture 2 pans, 4 pans ou monopente sur les murs sélectionnés : pente, débord et épaisseur', -> { A2M::Toiture.lancer }, false],
    ['planelle',    'Poser les planelles en rive de dalle', 'Planelles sur tout le pourtour de la dalle : votre profil dessiné (en L…, avec isolant), un profil de la bibliothèque ou un rectangle ; dans l\'épaisseur (dalle recoupée) ou à l\'extérieur', -> { A2M::Planelles.lancer }, false],
    ['hachures',    'Hachures de coupe par couche',        'Une hachure par type de couche (mur, isolant, plaque, cloison, chape…), posée automatiquement en dessinant ; peut aussi l\'appliquer au modèle déjà dessiné', -> { A2M::Hachures.regler }, false],
    ['fondation',   'Créer les semelles',                  'Semelles filantes sous les murs sélectionnés : largeur et hauteur', -> { A2M::Fondations.lancer }, true],
    ['ouverture',   'Créer une ouverture',                 'Largeur et hauteur suffisent : porte ou fenêtre reconnue, menuiserie et appui ou seuil proposés ; perce toutes les couches, suit la menuiserie déplacée', -> { A2M::Ouvertures.lancer }, false],
    ['porte',       'Poser une porte intérieure',          'Bloc-porte de passage (63 à 103 × 204) dans une cloison ou un refend : réservation, toute l\'épaisseur, centré, sens au Tab, choix du configurateur', -> { A2M::PortesInt.lancer }, false],
    ['plinthe',     'Poser les plinthes',                  'Plinthes le long du revêtement sélectionné, avec votre profil ou un profil de la bibliothèque, coupées aux portes', -> { A2M::Plinthes.lancer }, false],
    ['objet',       'Paramétrer un objet pour la bibliothèque', 'Menuiserie, porte, appui, seuil, façade de placard, plinthe, mobilier… : objet dessiné, éclaté ou composant dynamique (gardé entier), rangé dans la bibliothèque', -> { A2M::Bibliotheque.parametrer }, false],
    ['profils',     'Bibliothèque de profils',             'Vos profils (plinthe, planelle, couvertine, appui, bandeau…) : rangés depuis un dessin ou créés par leurs cotes, balayés le long d\'un tracé, utilisés par Plinthes et Planelles', -> { A2M::Profils.gerer }, false],
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
    z.write(os.path.join(ici, 'balises.rb'), 'a2m_metre/balises.rb')
    z.write(os.path.join(ici, 'bibliotheque.rb'), 'a2m_metre/bibliotheque.rb')
    z.write(os.path.join(ici, 'dessin_murs.rb'), 'a2m_metre/dessin_murs.rb')
    z.write(os.path.join(ici, 'dessin_sols.rb'), 'a2m_metre/dessin_sols.rb')
    z.write(os.path.join(ici, 'ouvertures.rb'), 'a2m_metre/ouvertures.rb')
    z.write(os.path.join(ici, 'plinthes.rb'), 'a2m_metre/plinthes.rb')
    for f in ('pointage', 'palette', 'suivi', 'maj', 'portes_int', 'hachures', 'hachures_moteur', 'planelles', 'profils'):
        z.write(os.path.join(ici, f + '.rb'), 'a2m_metre/' + f + '.rb')
    for f in ('controle', 'toiture', 'pieces_auto', 'fondations', 'electricite', 'envoi'):
        z.write(os.path.join(ici, f + '.rb'), 'a2m_metre/' + f + '.rb')
    for f in sorted(os.listdir(os.path.join(ici, 'hachures'))):
        z.write(os.path.join(ici, 'hachures', f), 'a2m_metre/hachures/' + f)
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
