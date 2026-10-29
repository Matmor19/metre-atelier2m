# Construit l'extension a2m_metre.rbz à partir de a2m_extraction.rb et balises.rb
import os, zipfile, shutil
ici = os.path.dirname(os.path.abspath(__file__))
s = open(os.path.join(ici, 'a2m_extraction.rb'), encoding='utf-8').read().rstrip()
assert s.endswith('A2M::Extraction.lancer')
s = s[:-len('A2M::Extraction.lancer')].replace("require 'json'", "require 'json'\nrequire 'sketchup.rb'", 1)
s += r'''
require File.join(File.dirname(__FILE__), 'balises')
require File.join(File.dirname(__FILE__), 'dessin_murs')
require File.join(File.dirname(__FILE__), 'dessin_sols')
require File.join(File.dirname(__FILE__), 'ouvertures')
require File.join(File.dirname(__FILE__), 'plinthes')

# Menus : Extensions > Métré Atelier 2M, et clic droit sur la sélection
unless file_loaded?(__FILE__)
  menu = UI.menu('Extensions').add_submenu('Métré Atelier 2M')
  menu.add_item('1. Créer les balises du métré') { A2M::Balises.creer }
  menu.add_item('2. Baliser la sélection…') { A2M::Balises.baliser_selection }
  menu.add_item('3. Baliser et nommer les pièces sélectionnées…') { A2M::Balises.nommer_pieces }
  menu.add_item('Dessiner un mur, un doublage ou une cloison…') { A2M::DessinMurs.lancer }
  menu.add_item('Dessiner un mur composé (plusieurs couches)…') { A2M::DessinMurs.lancer_compose }
  menu.add_item('Dessiner une dalle, un plancher, un sol ou un plafond…') { A2M::DessinSols.lancer }
  menu.add_item('Créer une ouverture dans les murs…') { A2M::Ouvertures.lancer }
  menu.add_item('Poser les plinthes de la pièce sélectionnée…') { A2M::Plinthes.lancer }
  menu.add_separator
  menu.add_item('4. Extraire pour le configurateur…') { A2M::Extraction.lancer }
  menu.add_separator
  menu.add_item('Aide : balises reconnues') { A2M::Balises.aide }
  UI.add_context_menu_handler do |cm|
    next if Sketchup.active_model.selection.empty?
    sm = cm.add_submenu('Métré Atelier 2M')
    sm.add_item('Baliser la sélection…') { A2M::Balises.baliser_selection }
    sm.add_item('Baliser et nommer comme pièce(s)…') { A2M::Balises.nommer_pieces }
    sm.add_item('Poser les plinthes…') { A2M::Plinthes.lancer }
  end
  # Barre d'outils aux couleurs d'Atelier 2M : un pictogramme par bouton, une bulle d'aide au survol
  ico = File.join(File.dirname(__FILE__), 'icones')
  ext = Sketchup.platform == :platform_win ? '.svg' : '.pdf'
  ext = '.png' if Sketchup.version.to_i < 16
  tb = UI::Toolbar.new('Métré Atelier 2M')
  [
    ['balises',   'Créer les balises du métré',           'Crée les balises A2M_ du métré (dossier « Métré A2M »), sans toucher à celles qui existent', -> { A2M::Balises.creer }],
    ['baliser',   'Baliser la sélection',                 'Met la balise choisie sur les groupes, composants, faces ou lignes sélectionnés', -> { A2M::Balises.baliser_selection }],
    ['pieces',    'Baliser et nommer les pièces',         'Met A2M_PIECE sur les groupes de sol sélectionnés et demande le nom de chaque pièce', -> { A2M::Balises.nommer_pieces }],
    ['mur',       'Dessiner un mur',                      'Mur, doublage ou cloison : hauteur, épaisseur et tracé (axe ou face), posé sur sa balise', -> { A2M::DessinMurs.lancer }],
    ['compose',   'Dessiner un mur composé',              'Plusieurs couches en une fois (mur, isolant, plaque…), chacune sur sa balise', -> { A2M::DessinMurs.lancer_compose }],
    ['sol',       'Dessiner un sol ou un plafond',        'Dalle, plancher, isolant de sol, chape, revêtement (pièce) ou plafond, avec épaisseur et hauteur de pose', -> { A2M::DessinSols.lancer }],
    ['ouverture', 'Créer une ouverture',                  'Perce le mur et ses doublages (largeur, hauteur, linteau, distance), pose la menuiserie de réservation et recoupe les plinthes', -> { A2M::Ouvertures.lancer }],
    ['plinthe',   'Poser les plinthes',                   'Plinthes le long du revêtement sélectionné, avec votre profil, coupées aux portes', -> { A2M::Plinthes.lancer }],
    ['extraire',  'Extraire pour le configurateur',       'Enregistre le fichier .json à importer dans le configurateur du métré', -> { A2M::Extraction.lancer }],
    ['aide',      'Aide : balises reconnues',             'Liste des balises du métré et de leur usage', -> { A2M::Balises.aide }]
  ].each do |nom, titre, bulle, action|
    cmd = UI::Command.new(titre) { action.call }
    cmd.tooltip = titre
    cmd.status_bar_text = bulle
    cmd.small_icon = File.join(ico, "#{nom}#{ext == '.png' ? '_16.png' : ext}")
    cmd.large_icon = File.join(ico, "#{nom}#{ext == '.png' ? '_24.png' : ext}")
    tb.add_item(cmd)
    tb.add_separator if %w[pieces plinthe].include?(nom)
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
    z.write(os.path.join(ici, 'dessin_murs.rb'), 'a2m_metre/dessin_murs.rb')
    z.write(os.path.join(ici, 'dessin_sols.rb'), 'a2m_metre/dessin_sols.rb')
    z.write(os.path.join(ici, 'ouvertures.rb'), 'a2m_metre/ouvertures.rb')
    z.write(os.path.join(ici, 'plinthes.rb'), 'a2m_metre/plinthes.rb')
    dico = os.path.join(ici, 'icones')
    for f in sorted(os.listdir(dico)):
        if f.endswith(('.svg', '.pdf', '.png')):
            z.write(os.path.join(dico, f), 'a2m_metre/icones/' + f)
print('ok', dest)
