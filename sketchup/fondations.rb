# encoding: UTF-8
# Métré Atelier 2M : semelles filantes générées sous les murs sélectionnés
require 'sketchup.rb'

module A2M
  module Fondations
    @r = {}

    def self.aire(p) p.each_with_index.sum { |(x1, y1), i| x2, y2 = p[(i + 1) % p.size]; x1 * y2 - x2 * y1 } / 2.0 end

    # Empreinte de semelle d'un contour de mur : extérieur agrandi de d, trous réduits de d (débord de chaque côté du mur)
    def self.elargir(loops, d)
      loops.each_with_index.map do |lp, i|
        pts = lp.dup; pts.reverse! if aire(pts) < 0
        pp = pts.map { |x, y| Geom::Point3d.new(x, y, 0) }
        A2M::DessinMurs.decale(pp, i.zero? ? -d : d, true)
      end
    end

    def self.lancer
      model = Sketchup.active_model
      murs = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      if murs.empty?
        UI.messagebox('Sélectionnez les murs porteurs (groupes) sous lesquels créer les semelles.')
        return
      end
      rep = UI.inputbox(['Largeur de la semelle (cm)', 'Hauteur de la semelle (cm)'], [(@r[:l] || 50).to_s, (@r[:h] || 35).to_s], 'Semelles filantes (Métré Atelier 2M)')
      return unless rep
      lc = rep[0].tr(',', '.').to_f; hc = rep[1].tr(',', '.').to_f
      return UI.messagebox('Largeur et hauteur supérieures à 0.') if lc <= 0 || hc <= 0
      @r = { l: lc, h: hc }
      construire(murs, lc, hc)
    end

    # Rouvre des semelles posées : largeur et hauteur ; elles sont refaites sous les mêmes murs (ou sous les murs sélectionnés avec elles)
    def self.modifier(grp, d)
      return UI.messagebox('Ces semelles n\'ont pas gardé leurs murs : refaites-les une fois.') unless d && d['murs']
      model = Sketchup.active_model
      rep = UI.inputbox(['Largeur de la semelle (cm)', 'Hauteur de la semelle (cm)'], [d['l'].to_s, d['h'].to_s], "Modifier : #{grp.name}")
      return unless rep
      lc = rep[0].tr(',', '.').to_f; hc = rep[1].tr(',', '.').to_f
      return UI.messagebox('Largeur et hauteur supérieures à 0.') if lc <= 0 || hc <= 0
      murs = d['murs'].map { |pid| model.find_entity_by_persistent_id(pid) }.compact.select { |e| e.valid? && (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e != grp }
      sel = model.selection.to_a.select { |e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e != grp }
      murs = sel unless sel.empty?
      return UI.messagebox('Les murs de ces semelles ne sont plus dans le modèle : sélectionnez les murs avec les semelles, puis relancez.') if murs.empty?
      construire(murs, lc, hc, grp)
    end

    def self.construire(murs, lc, hc, ancien = nil)
      model = Sketchup.active_model
      model.start_operation('Semelles filantes (métré)', true)
      begin
        zbas = murs.map { |g| g.bounds.min.z }.min
        grp = model.active_entities.add_group
        te = grp.entities
        manque = []
        murs.each do |g|
          ents = g.is_a?(Sketchup::Group) ? g.entities : g.definition.entities
          tr = g.transformation
          dessus = ents.grep(Sketchup::Face).select { |f| (tr * f.normal).z > 0.99 }
          if dessus.empty? then manque << g.name; next end
          dessus.each do |f|
            loops = f.loops.map { |lp| lp.vertices.map { |v| q = tr * v.position; [q.x.to_f, q.y.to_f] } }
            # Épaisseur du mur : surface du dessus ÷ linéaire (même calcul que l'extraction)
            ext = f.outer_loop.edges.sum { |e| (tr * e.start.position).distance(tr * e.end.position) }
            int = f.loops.reject(&:outer?).sum { |lp| lp.edges.sum { |e| (tr * e.start.position).distance(tr * e.end.position) } }
            a = f.area(tr)
            lin, ep = A2M::Extraction.empreinte(a, ext, int)
            d = [((lc / 100.0).m - ep) / 2.0, 0].max
            el = elargir(loops, d)
            fc = te.add_face(el[0].map { |x, y| Geom::Point3d.new(x, y, zbas) })
            el[1..-1].each { |t| h = te.add_face(t.map { |x, y| Geom::Point3d.new(x, y, zbas) }); h.erase! if h && h.valid? }
          end
        end
        # Semelles qui se rejoignent : une seule empreinte (les angles ne sont pas comptés deux fois)
        te.intersect_with(false, Geom::Transformation.new, te, Geom::Transformation.new, true, te.to_a)
        te.grep(Sketchup::Edge).select { |e| e.valid? && e.faces.size == 2 }.each(&:erase!)
        te.grep(Sketchup::Face).each { |f| f.reverse! if f.normal.z > 0 }
        te.grep(Sketchup::Face).to_a.each { |f| f.pushpull((hc / 100.0).m) if f.valid? && f.normal.z < -0.99 }
        lb, _ = A2M::Balises.balise(model, 'A2M_SEMELLE', [130, 130, 130])
        grp.layer = lb
        A2M::Hachures.poser(grp, model)
        grp.name = "Semelles filantes #{lc.round} × #{hc.round}"
        ancien.erase! if ancien && ancien.valid?
        A2M::Modif.noter(grp, 'semelle', { 'l' => lc, 'h' => hc, 'murs' => murs.map(&:persistent_id) })
        model.commit_operation
        msg = "#{grp.name} créées sous #{murs.size - manque.size} mur(s), balise A2M_SEMELLE."
        msg += "\nSans dessus lisible : #{manque.join(', ')}" if manque.any?
        UI.messagebox(msg)
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Les semelles n'ont pas pu être créées (#{ex.message}).")
      end
    end
  end
end
