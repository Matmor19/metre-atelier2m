# Construit l'extension a2m_metre.rbz à partir de a2m_extraction.rb et balises.rb
import os, zipfile, shutil
ici = os.path.dirname(os.path.abspath(__file__))
s = open(os.path.join(ici, 'a2m_extraction.rb'), encoding='utf-8').read().rstrip()
assert s.endswith('A2M::Extraction.lancer')
s = s[:-len('A2M::Extraction.lancer')].replace("require 'json'", "require 'json'\nrequire 'sketchup.rb'", 1)
s += r'''
require File.join(File.dirname(__FILE__), 'balises')

# Menus : Extensions > Métré Atelier 2M, et clic droit sur la sélection
unless file_loaded?(__FILE__)
  menu = UI.menu('Extensions').add_submenu('Métré Atelier 2M')
  menu.add_item('1. Créer les balises du métré') { A2M::Balises.creer }
  menu.add_item('2. Baliser la sélection…') { A2M::Balises.baliser_selection }
  menu.add_item('3. Baliser et nommer les pièces sélectionnées…') { A2M::Balises.nommer_pieces }
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
  file_loaded(__FILE__)
end
'''
chargeur = open(os.path.join(ici, 'a2m_metre_chargeur.rb'), encoding='utf-8').read()
dest = os.path.join(ici, 'a2m_metre.rbz')
with zipfile.ZipFile(dest, 'w', zipfile.ZIP_DEFLATED) as z:
    z.writestr('a2m_metre.rb', chargeur)
    z.writestr('a2m_metre/main.rb', s)
    z.write(os.path.join(ici, 'balises.rb'), 'a2m_metre/balises.rb')
print('ok', dest)
