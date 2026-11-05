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

    def self.installer
      return if @ok
      @ok = true
      UI.add_context_menu_handler do |menu|
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
