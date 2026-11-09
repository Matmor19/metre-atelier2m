# encoding: UTF-8
# Métré Atelier 2M : menu clic droit sur les portes (charnière gauche ↔ droite, ouvrir de l'autre côté du mur)
require 'sketchup.rb'
require 'json'

module A2M
  module MenuContextuel
    TAGS = %w[A2M_PORTE_INT A2M_PORTE_ENTREE A2M_PORTE_FENETRE].freeze

    def self.portes(sel)
      sel.select { |e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && TAGS.include?(e.layer.name) }
    end

    def self.sens(e)
      s = (JSON.parse(e.get_attribute('a2m', 'sens').to_s) rescue nil)
      s.is_a?(Array) && s.size == 2 ? s : ['ici', 'gauche']
    end

    # Axe horizontal de la largeur de la porte (le plus long) et centre, en repère du parent
    def self.axes(e)
      bb = e.bounds
      c = bb.center
      t = e.transformation
      # Porte de la bibliothèque posée par l'outil : l'origine de l'objet est le milieu du CORPS du cadre (dans la largeur et l'épaisseur
      # de la cloison). La boîte englobante, elle, compte la poignée d'un seul côté : pivoter ou retourner autour d'elle décalerait la porte.
      c = Geom::Point3d.new(t.origin.x, t.origin.y, c.z) if e.get_attribute('a2m_biblio', 'fichier')
      bl = (e.is_a?(Sketchup::Group) ? e.entities.parent : e.definition).bounds
      wx = bl.width * t.xscale; wy = bl.height * t.yscale
      ax = wx >= wy ? t.xaxis : t.yaxis
      ax = Geom::Vector3d.new(ax.x, ax.y, 0)
      ax = ax.length > 0.001 ? ax.normalize : Geom::Vector3d.new(1, 0, 0)
      [c, ax]
    end

    def self.miroir(e)
      c, n = axes(e)
      m = [1 - 2 * n.x * n.x, -2 * n.y * n.x, 0, 0,
           -2 * n.x * n.y, 1 - 2 * n.y * n.y, 0, 0,
           0, 0, 1, 0, 0, 0, 0, 1]
      d = n.x * c.x + n.y * c.y
      m[12] = 2 * d * n.x; m[13] = 2 * d * n.y
      e.transform!(Geom::Transformation.new(m))
    end

    def self.tourner(e)
      c, _ = axes(e)
      e.transform!(Geom::Transformation.rotation(Geom::Point3d.new(c.x, c.y, 0), Z_AXIS, Math::PI))
    end

    def self.maj_nom(e, s)
      bp = (JSON.parse(e.get_attribute('a2m', 'bp').to_s) rescue nil)
      return unless bp.is_a?(Hash)
      bp['pousse'] = "poussant #{s[1] == 'droite' ? 'droit' : 'gauche'}"
      e.set_attribute('a2m', 'bp', JSON.generate(bp))
      e.name = e.name.sub(/poussant (droit|gauche)/, bp['pousse'])
    end

    def self.agir(quoi)
      model = Sketchup.active_model
      lst = portes(model.selection.to_a)
      return if lst.empty?
      model.start_operation(quoi == :charniere ? 'Charnière de l’autre côté' : 'Ouvrir de l’autre côté du mur', true)
      begin
        lst.each do |e|
          s = sens(e)
          if quoi == :charniere
            miroir(e)
            s[1] = s[1] == 'droite' ? 'gauche' : 'droite'
          else
            tourner(e)
            s[0] = s[0] == 'ici' ? 'la' : 'ici'
          end
          e.set_attribute('a2m', 'sens', JSON.generate([s[0], s[1]]))
          maj_nom(e, s)
        end
        A2M::Plan2D.rafraichir rescue nil
        model.commit_operation
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Modification impossible : #{ex.message}")
      end
    end

    # Objets de la bibliothèque (ou leur image 2D sur le plan) : choix de l'image 2D du plan (couleur ou blanche)
    def self.objets_biblio(sel)
      m = Sketchup.active_model
      sel.map do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        # image 2D du plan : on agit sur l'objet qu'elle représente
        e = m.find_entity_by_persistent_id(e.get_attribute('a2m_biblio', 'source').to_i) if e.get_attribute('a2m_biblio', 'jumeau')
        e if e && e.valid? && e.get_attribute('a2m_biblio', 'fichier')
      end.compact.uniq
    end

    def self.choisir_2d(lst, version)
      model = Sketchup.active_model
      model.start_operation('Image 2D de l\'objet', true)
      begin
        lst.each { |e| e.set_attribute('a2m_biblio', 'vue2d', version) }
        A2M::Plan2D.rafraichir rescue nil
        model.commit_operation
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Modification impossible : #{ex.message}")
      end
    end

    def self.installer
      return if @ok
      @ok = true
      UI.add_context_menu_handler do |menu|
        mur = Sketchup.active_model.selection.to_a.find { |e| e.respond_to?(:get_attribute) && e.get_attribute('a2m_mur', 'id') }
        if mur
          menu.add_separator
          menu.add_item('Atelier 2M : modifier ce mur') { A2M::DessinMurs.modifier(mur) }
        end
        ouv = Sketchup.active_model.selection.to_a.find { |e| A2M::Suivi.suivie?(e) }
        if ouv
          menu.add_separator
          menu.add_item('Atelier 2M : modifier cette ouverture') { A2M::Ouvertures.modifier(ouv) }
        end
        autre = Sketchup.active_model.selection.to_a.find { |e| %i[sol solmur escalier garde_corps couverture charpente zinguerie semelle].include?(A2M::Modif.genre(e)) }
        if autre
          menu.add_separator
          menu.add_item('Atelier 2M : modifier cet objet') { A2M::Modif.modifier(autre) }
        end
        toit = Sketchup.active_model.selection.to_a.find { |e| e.respond_to?(:get_attribute) && e.get_attribute('a2m_toiture', 'base') }
        if toit
          menu.add_separator
          menu.add_item('Atelier 2M : modifier cette toiture') { A2M::Toiture.modifier(toit) }
        end
        ob = objets_biblio(Sketchup.active_model.selection.to_a)
        unless ob.empty?
          menu.add_separator
          sous = menu.add_submenu('Atelier 2M : image 2D du plan')
          actuel = ob.map { |e| e.get_attribute('a2m_biblio', 'vue2d') == 'blanc' ? 'blanc' : 'couleur' }.uniq
          sous.add_item((actuel == ['couleur'] ? '✓ ' : '') + 'Version couleur') { choisir_2d(ob, 'couleur') }
          sous.add_item((actuel == ['blanc'] ? '✓ ' : '') + 'Version blanche') { choisir_2d(ob, 'blanc') }
        end
        # Sur le plan, l'image couvre l'objet : un clic droit tombe sur le groupe des symboles 2D → toutes les images d'un coup
        if Sketchup.active_model.selection.any? { |e| e.is_a?(Sketchup::Group) && e.name.to_s.start_with?('Symboles 2D') }
          tous = []
          A2M::Plan2D.parcourir(Sketchup.active_model.entities, Geom::Transformation.new) { |e, _t| tous << e if e.get_attribute('a2m_biblio', 'fichier') }
          unless tous.empty?
            menu.add_separator
            sous = menu.add_submenu('Atelier 2M : objets sur le plan')
            sous.add_item('Tous en version couleur') { choisir_2d(tous, 'couleur') }
            sous.add_item('Tous en version blanche') { choisir_2d(tous, 'blanc') }
          end
        end
        lst = portes(Sketchup.active_model.selection.to_a)
        next if lst.empty?
        menu.add_separator
        sous = menu.add_submenu('Atelier 2M : porte')
        sous.add_item('Charnière gauche ↔ droite') { agir(:charniere) }
        sous.add_item('Ouvrir de l’autre côté du mur') { agir(:cote) }
      end
    end
  end
end
A2M::MenuContextuel.installer
