# encoding: UTF-8
# Métré Atelier 2M : création des balises A2M_ et balisage de la sélection
require 'sketchup.rb'

module A2M
  module Balises
    DOSSIER = 'Métré A2M'
    # [nom, usage, couleur RVB]
    LISTE = [
      ['A2M_MUR_PERI',         'Murs périphériques (groupe)',                      [224, 123, 26]],
      ['A2M_MUR_SOUB',         'Murs de soubassement (groupe)',                    [150, 90, 40]],
      ['A2M_MUR_REFEND',       'Murs de refend (groupe)',                          [240, 170, 90]],
      ['A2M_MUR_PIGNON',       'Murs pignons (groupe)',                            [200, 100, 60]],
      ['A2M_DOUBLAGE',         'Doublage : plaque de plâtre (groupe)',             [235, 235, 235]],
      ['A2M_ISOLANT_DOUBLAGE', 'Doublage : isolant (groupe)',                      [250, 220, 90]],
      ['A2M_CLOISON',          'Cloisons (groupe)',                                [200, 200, 210]],
      ['A2M_FENETRE',          'Fenêtres (composant)',                             [80, 150, 220]],
      ['A2M_PORTE_FENETRE',    'Portes-fenêtres et baies (composant)',             [60, 120, 200]],
      ['A2M_PORTE_ENTREE',     'Portes d\'entrée (composant)',                     [30, 80, 160]],
      ['A2M_PORTE_INT',        'Portes intérieures (composant)',                   [140, 100, 200]],
      ['A2M_PIECE',            'Sol de pièce (groupe nommé « Séjour », « Chambre 1 »…)', [120, 200, 120]],
      ['A2M_TERRAIN',          'Terrain (face)',                                   [110, 170, 80]],
      ['A2M_DECAPAGE',         'Surface à décaper (face)',                         [160, 130, 90]],
      ['A2M_DALLAGE',          'Dallage du RDC (face)',                            [170, 170, 170]],
      ['A2M_PLANCHER_ETAGE',   'Plancher de l\'étage (face)',                      [190, 160, 120]],
      ['A2M_PLAFOND',          'Plafonds (face)',                                  [245, 245, 220]],
      ['A2M_TOITURE',          'Toiture 1 : pans (groupe)',                        [180, 60, 40]],
      ['A2M_TOITURE_2',        'Toiture 2 : pans (groupe)',                        [190, 80, 60]],
      ['A2M_TOITURE_3',        'Toiture 3 : pans (groupe)',                        [200, 100, 80]],
      ['A2M_TOITURE_4',        'Toiture 4 : pans (groupe)',                        [210, 120, 100]],
      ['A2M_RIGOLE',           'Fouilles en rigoles (lignes)',                     [120, 80, 40]],
      ['A2M_FAITAGE',          'Faîtage forcé (lignes, facultatif)',               [255, 0, 0]],
      ['A2M_RIVE',             'Rive forcée (lignes, facultatif)',                 [255, 120, 0]],
      ['A2M_NOUE',             'Noue forcée (lignes, facultatif)',                 [0, 150, 255]],
      ['A2M_ARETIER',          'Arêtier forcé (lignes, facultatif)',               [160, 0, 200]],
      ['A2M_EGOUT',            'Égout forcé (lignes, facultatif)',                 [0, 180, 120]]
    ]

    def self.dossier(model)
      layers = model.layers
      return nil unless layers.respond_to?(:add_folder)   # SketchUp 2021 et suivants
      layers.folders.find { |f| f.name == DOSSIER } || layers.add_folder(DOSSIER)
    rescue StandardError
      nil
    end

    def self.balise(model, nom, couleur = nil)
      l = model.layers[nom]
      nouveau = l.nil?
      l ||= model.layers.add(nom)
      begin
        l.color = Sketchup::Color.new(*couleur) if nouveau && couleur
        d = dossier(model)
        l.folder = d if d && l.respond_to?(:folder=) && l.folder != d
      rescue StandardError
      end
      [l, nouveau]
    end

    # Crée toutes les balises qui manquent (celles qui existent déjà ne sont pas touchées)
    def self.creer
      model = Sketchup.active_model
      model.start_operation('Créer les balises du métré', true)
      crees = LISTE.count { |nom, _u, c| balise(model, nom, c)[1] }
      model.commit_operation
      UI.messagebox(crees.zero? ? "Toutes les balises du métré existent déjà (dossier « #{DOSSIER} »)." :
                    "#{crees} balise(s) créée(s) dans le dossier « #{DOSSIER} ».\nLes balises déjà présentes n'ont pas été modifiées.")
    end

    # Met la balise choisie sur les groupes et composants sélectionnés (ou sur les faces et lignes sélectionnées)
    def self.baliser_selection
      model = Sketchup.active_model
      sel = model.selection.to_a.select { |e| e.respond_to?(:layer=) }
      if sel.empty?
        UI.messagebox('Sélectionnez d\'abord un ou plusieurs groupes, composants, faces ou lignes.')
        return
      end
      libelles = LISTE.map { |n, u, _| "#{n} — #{u}" }
      rep = UI.inputbox(['Balise à appliquer'], [libelles[0]], [libelles.join('|')], "Baliser la sélection (#{sel.size} élément(s))")
      return unless rep
      nom = rep[0].split(' — ').first
      couleur = (LISTE.find { |n, _, _| n == nom } || [])[2]
      model.start_operation('Baliser pour le métré', true)
      l, _ = balise(model, nom, couleur)
      sel.each { |e| e.layer = l }
      model.commit_operation
      Sketchup.status_text = "#{sel.size} élément(s) balisé(s) #{nom}"
    end

    # Pièces : met A2M_PIECE sur les groupes sélectionnés et demande leur nom s'il manque
    def self.nommer_pieces
      model = Sketchup.active_model
      grp = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      if grp.empty?
        UI.messagebox('Sélectionnez le ou les groupes qui contiennent le sol de chaque pièce.')
        return
      end
      model.start_operation('Pièces du métré', true)
      l, _ = balise(model, 'A2M_PIECE', [120, 200, 120])
      grp.each_with_index do |g, i|
        g.layer = l
        next unless g.name.to_s.strip.empty?
        model.selection.clear; model.selection.add(g)
        rep = UI.inputbox(['Nom de la pièce (ex. Séjour, Chambre 1)'], [''], "Pièce #{i + 1} / #{grp.size}")
        g.name = rep[0].to_s.strip if rep && !rep[0].to_s.strip.empty?
      end
      model.commit_operation
      Sketchup.status_text = "#{grp.size} pièce(s) balisée(s) A2M_PIECE"
    end
  end
end
