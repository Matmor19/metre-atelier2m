# encoding: UTF-8
# Métré Atelier 2M : séparateur de pièce. Une ligne tracée entre deux murs (ou deux cloisons) sépare une pièce ouverte en deux :
# « Pièce en un clic » et « Pièces automatiques » la prennent pour une cloison sans épaisseur.
# Le séparateur est sur sa propre balise, masquée dès la fin du tracé : il n'apparaît ni dans les scènes, ni à l'impression, ni à l'export.
require 'sketchup.rb'

module A2M
  module Separateur
    TAG = 'A2M_SEPARATEUR'
    PROLONGE = 20.cm   # chaque bout est prolongé de 20 cm à la détection (un clic un peu court dans la pièce suffit ; le dessin n'est pas modifié)

    def self.balise(model)
      l, nouveau = A2M::Balises.balise(model, TAG, [224, 120, 56])
      model.pages.each { |p| p.set_visibility(l, false) } if nouveau
      l
    end

    def self.visible?(model) l = model.layers[TAG]; !l.nil? && l.visible? end

    # Montre ou cache les séparateurs (scènes comprises) ; caché par défaut
    def self.regler(model, voir)
      l = balise(model)
      l.visible = voir
      model.pages.each { |p| p.set_visibility(l, voir) } unless voir
    end

    def self.basculer
      model = Sketchup.active_model
      voir = !visible?(model)
      model.start_operation(voir ? 'Afficher les séparateurs' : 'Masquer les séparateurs', true)
      regler(model, voir)
      model.commit_operation
      Sketchup.status_text = voir ? 'Séparateurs affichés (orange). Cliquez de nouveau pour les masquer avant d\'imprimer.' : 'Séparateurs masqués : invisibles dans les scènes et à l\'impression.'
    end

    # Segments [[x, y], [x, y]] (pouces, repère du modèle) de tous les séparateurs
    def self.segments(model)
      res = []
      model.entities.each do |g|
        next unless g.is_a?(Sketchup::Group) && g.valid? && g.layer && g.layer.name == TAG
        t = g.transformation
        g.entities.grep(Sketchup::Edge).each do |e|
          a = t * e.start.position; b = t * e.end.position
          res << [[a.x.to_f, a.y.to_f], [b.x.to_f, b.y.to_f]]
        end
      end
      res
    end

    # Ajoute les séparateurs (prolongés) au groupe temporaire de détection, à la hauteur z
    def self.ajouter_a(te, z, model)
      segments(model).each do |(ax, ay), (bx, by)|
        d = Math.hypot(bx - ax, by - ay)
        next if d < 1e-6
        ux = (bx - ax) / d; uy = (by - ay) / d
        p = PROLONGE.to_f
        te.add_line(Geom::Point3d.new(ax - ux * p, ay - uy * p, z), Geom::Point3d.new(bx + ux * p, by + uy * p, z))
      end
    end

    def self.creer(pts, model = Sketchup.active_model)
      l = balise(model)
      n = model.entities.grep(Sketchup::Group).count { |g| g.layer == l } + 1
      g = model.entities.add_group
      g.entities.add_edges(pts)
      g.name = "Séparateur #{n}"
      g.layer = l
      g
    end

    class Outil
      def initialize; @pts = []; @ip = Sketchup::InputPoint.new; @libre = false; @souris = nil end

      def activate
        model = Sketchup.active_model
        ms = A2M::PiecesAuto.murs(model)
        @z = ms.empty? ? 0.0 : ms.map { |g| g.bounds.min.z }.min
        model.start_operation('Afficher les séparateurs', true)
        A2M::Separateur.regler(model, true)
        model.commit_operation
        statut
      end

      def deactivate(view)
        model = Sketchup.active_model
        model.start_operation('Masquer les séparateurs', true)
        A2M::Separateur.regler(model, false)
        model.commit_operation
        view.invalidate
      end

      def statut
        Sketchup.status_text = 'Séparateur : cliquez le début (dans un mur), puis la fin dans le mur d\'en face ; double-clic ou Entrée pour finir, Échap pour annuler. ' \
                               "Axes #{@libre ? 'libres' : 'verrouillés'} (Ctrl pour changer). Tapez une longueur puis Entrée si besoin."
        Sketchup.vcb_label = 'Longueur'
      end

      def onSetCursor() UI.set_cursor(632) end

      def point(view, x, y)
        @ip.pick(view, x, y)
        p = @ip.position.clone
        p.z = @z
        if !@libre && (d = @pts.last)
          dx = p.x - d.x; dy = p.y - d.y
          dx.abs >= dy.abs ? p.y = d.y : p.x = d.x
        end
        p
      end

      def onMouseMove(_f, x, y, view)
        @souris = point(view, x, y)
        Sketchup.vcb_value = @pts.last.distance(@souris).to_l.to_s if @pts.last
        view.invalidate
      end

      def onKeyDown(key, _r, _f, view)
        if key == 17 then @libre = !@libre; statut; view.invalidate end
      end

      def onLButtonDown(_f, x, y, view)
        p = point(view, x, y)
        @pts << p unless @pts.last && @pts.last.distance(p) < 0.1.cm
        view.invalidate
      end

      def onLButtonDoubleClick(_f, _x, _y, view) terminer(view) end
      def onReturn(view) terminer(view) end

      def onUserText(text, view)
        d = text.to_l rescue nil
        return UI.beep unless d && @pts.last && @souris
        v = @souris - @pts.last
        return UI.beep if v.length < 1e-6
        v.length = d
        @pts << @pts.last.offset(v)
        view.invalidate
      end

      def onCancel(_r, view)
        if @pts.empty? then Sketchup.active_model.select_tool(nil)
        else @pts.clear; view.invalidate; statut end
      end

      def terminer(view)
        if @pts.size >= 2
          model = Sketchup.active_model
          model.start_operation('Séparateur de pièce', true)
          A2M::Separateur.creer(@pts, model)
          model.commit_operation
          Sketchup.status_text = 'Séparateur posé : cliquez maintenant dans chaque moitié avec « Pièce en un clic ».'
        end
        @pts.clear
        view.invalidate
      end

      def draw(view)
        pts = @pts + (@souris && !@pts.empty? ? [@souris] : [])
        return if pts.size < 2
        view.drawing_color = Sketchup::Color.new(224, 120, 56)
        view.line_width = 3
        view.line_stipple = '-'
        view.draw_polyline(pts)
      end
    end

    def self.lancer
      Sketchup.active_model.select_tool(Outil.new)
    end
  end
end
