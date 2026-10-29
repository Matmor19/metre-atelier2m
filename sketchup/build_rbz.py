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
  menu.add_separator
  menu.add_item('4. Extraire pour le configurateur…') { A2M::Extraction.lancer }
  menu.add_separator
  menu.add_item('Aide : balises reconnues') do
    UI.messagebox("Balises du métré :\n\n" + A2M::Balises::LISTE.map { |n, u, _| "#{n} : #{u}" }.join("\n") +
      "\n\nLa toiture (faîtage, rives, noues, arêtiers, égouts) est reconnue toute seule à partir des pans : les balises de lignes ne servent qu'à forcer un type.")
  end
  UI.add_context_menu_handler do |cm|
    next if Sketchup.active_model.selection.empty?
    sm = cm.add_submenu('Métré Atelier 2M')
    sm.add_item('Baliser la sélection…') { A2M::Balises.baliser_selection }
    sm.add_item('Baliser et nommer comme pièce(s)…') { A2M::Balises.nommer_pieces }
  end
  # Barre d'outils : un bouton « Mur » pour lancer le dessin sans passer par le menu
  tb = UI::Toolbar.new('Métré Atelier 2M')
  cmd = UI::Command.new('Dessiner un mur (métré)') { A2M::DessinMurs.lancer }
  cmd.tooltip = 'Dessiner un mur, un doublage ou une cloison sur la bonne balise du métré'
  cmd.status_bar_text = cmd.tooltip
  cmd.menu_text = 'Mur'
  ico = File.join(File.dirname(__FILE__), 'icones')
  cmd.small_icon = File.join(ico, 'mur_16.png')
  cmd.large_icon = File.join(ico, 'mur_24.png')
  tb.add_item(cmd)
  cmdc = UI::Command.new('Dessiner un mur composé (métré)') { A2M::DessinMurs.lancer_compose }
  cmdc.tooltip = 'Mur composé : mur, isolant, plaque… en une seule fois, chaque couche sur sa balise'
  cmdc.status_bar_text = cmdc.tooltip
  cmdc.menu_text = 'Mur composé'
  cmdc.small_icon = File.join(ico, 'compose_16.png')
  cmdc.large_icon = File.join(ico, 'compose_24.png')
  tb.add_item(cmdc)
  cmd2 = UI::Command.new('Dessiner un sol ou un plafond (métré)') { A2M::DessinSols.lancer }
  cmd2.tooltip = 'Dessiner une dalle, un plancher, un isolant de sol, une chape, un revêtement ou un plafond sur la bonne balise'
  cmd2.status_bar_text = cmd2.tooltip
  cmd2.menu_text = 'Sol'
  cmd2.small_icon = File.join(ico, 'sol_16.png')
  cmd2.large_icon = File.join(ico, 'sol_24.png')
  tb.add_item(cmd2)
  cmd3 = UI::Command.new('Créer une ouverture (métré)') { A2M::Ouvertures.lancer }
  cmd3.tooltip = 'Percer une ouverture dans le mur et ses doublages, avec une menuiserie de réservation balisée'
  cmd3.status_bar_text = cmd3.tooltip
  cmd3.menu_text = 'Ouverture'
  cmd3.small_icon = File.join(ico, 'ouv_16.png')
  cmd3.large_icon = File.join(ico, 'ouv_24.png')
  tb.add_item(cmd3)
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
    for t in (16, 24, 32):
        z.write(os.path.join(ici, f'mur_{t}.png'), f'a2m_metre/icones/mur_{t}.png')
        z.write(os.path.join(ici, f'sol_{t}.png'), f'a2m_metre/icones/sol_{t}.png')
        z.write(os.path.join(ici, f'ouv_{t}.png'), f'a2m_metre/icones/ouv_{t}.png')
        z.write(os.path.join(ici, f'compose_{t}.png'), f'a2m_metre/icones/compose_{t}.png')
print('ok', dest)
