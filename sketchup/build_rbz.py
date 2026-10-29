# Construit l'extension a2m_metre.rbz à partir de a2m_extraction.rb et balises.rb
import os, zipfile, shutil
ici = os.path.dirname(os.path.abspath(__file__))
s = open(os.path.join(ici, 'a2m_extraction.rb'), encoding='utf-8').read().rstrip()
assert s.endswith('A2M::Extraction.lancer')
s = s[:-len('A2M::Extraction.lancer')].replace("require 'json'", "require 'json'\nrequire 'sketchup.rb'", 1)
s += r'''
%w[balises bibliotheque dessin_murs dessin_sols ouvertures plinthes controle toiture pieces_auto fondations electricite envoi].each { |f| require File.join(File.dirname(__FILE__), f) }

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
    ['toiture',     'Créer la toiture',                    'Toiture 2 pans, 4 pans ou monopente sur les murs sélectionnés : pente et débord', -> { A2M::Toiture.lancer }, false],
    ['fondation',   'Créer les semelles',                  'Semelles filantes sous les murs sélectionnés : largeur et hauteur', -> { A2M::Fondations.lancer }, true],
    ['ouverture',   'Créer une ouverture',                 'Perce le mur et ses doublages, pose la menuiserie (choix du configurateur) et recoupe les plinthes', -> { A2M::Ouvertures.lancer }, false],
    ['plinthe',     'Poser les plinthes',                  'Plinthes le long du revêtement sélectionné, avec votre profil ou un profil de la bibliothèque, coupées aux portes', -> { A2M::Plinthes.lancer }, false],
    ['objet',       'Paramétrer un objet pour la bibliothèque', 'Fenêtre, porte, coulissant ou plinthe déjà dessiné (ou éclaté) : repère, lignes d\'étirement, choix du configurateur, rangé dans la bibliothèque', -> { A2M::Bibliotheque.parametrer }, false],
    ['biblio',      'Bibliothèque d\'objets',              'Poser un objet de la bibliothèque à la taille voulue (profils inchangés), ouvrir ou changer le dossier', -> { A2M::Bibliotheque.gerer }, false],
    ['elec',        'Poser l\'appareillage électrique',    'Prises, points lumineux, interrupteurs… posés au clic et comptés pièce par pièce', -> { A2M::Electricite.lancer }, true],
    ['extraire',    'Extraire pour le configurateur',      'Enregistre le fichier .json à importer dans le configurateur du métré', -> { A2M::Extraction.lancer }, false],
    ['envoi',       'Envoyer au métré',                    'Envoie l\'extraction directement au métré : bouton « Récupérer depuis SketchUp » dans le configurateur', -> { A2M::Envoi.lancer }, false],
    ['aide',        'Aide : balises reconnues',            'Liste des balises du métré et de leur usage', -> { A2M::Balises.aide }, false]
  ]
  menu = UI.menu('Extensions').add_submenu('Métré Atelier 2M')
  ACTIONS_A2M.each do |_ic, titre, _b, action, sep|
    menu.add_item(titre + '…') { action.call }
    menu.add_separator if sep
  end
  menu.add_item('Réglages de l\'envoi au métré…') { A2M::Envoi.reglages }
  UI.add_context_menu_handler do |cm|
    next if Sketchup.active_model.selection.empty?
    sm = cm.add_submenu('Métré Atelier 2M')
    sm.add_item('Baliser la sélection…') { A2M::Balises.baliser_selection }
    sm.add_item('Baliser et nommer comme pièce(s)…') { A2M::Balises.nommer_pieces }
    sm.add_item('Poser les plinthes…') { A2M::Plinthes.lancer }
    sm.add_item('Paramétrer pour la bibliothèque…') { A2M::Bibliotheque.parametrer }
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
    cmd.tooltip = titre
    cmd.status_bar_text = bulle
    cmd.small_icon = File.join(ico, "#{nom}#{ext == '.png' ? '_16.png' : ext}")
    cmd.large_icon = File.join(ico, "#{nom}#{ext == '.png' ? '_24.png' : ext}")
    tb.add_item(cmd)
    tb.add_separator if sep
  end
  tb.restore
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
    for f in ('controle', 'toiture', 'pieces_auto', 'fondations', 'electricite', 'envoi'):
        z.write(os.path.join(ici, f + '.rb'), 'a2m_metre/' + f + '.rb')
    dico = os.path.join(ici, 'icones')
    for f in sorted(os.listdir(dico)):
        if f.endswith(('.svg', '.pdf', '.png')):
            z.write(os.path.join(dico, f), 'a2m_metre/icones/' + f)
print('ok', dest)
