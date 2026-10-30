# encoding: UTF-8
# Métré Atelier 2M : pièces trouvées toutes seules entre les murs et les cloisons, revêtement créé et nommé
require 'sketchup.rb'

module A2M
  module PiecesAuto
    MURS = %w[A2M_MUR_PERI A2M_MUR_REFEND A2M_CLOISON A2M_DOUBLAGE A2M_ISOLANT_DOUBLAGE A2M_MUR_PIGNON]

    def self.murs(model)
      sel = model.selection.to_a.select { |e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.layer && MURS.include?(e.layer.name) }
      return sel unless sel.empty?
      model.active_entities.to_a.select { |e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && !e.hidden? && e.layer && MURS.include?(e.layer.name) }
    end

    # Dessus de chaque mur (les baies ne coupent pas le dessus) : contours extérieurs et trous, en coordonnées du modèle
    def self.empreintes(murs)
      murs.flat_map do |g|
        ents = g.is_a?(Sketchup::Group) ? g.entities : g.definition.entities
        tr = g.transformation
        ents.grep(Sketchup::Face).select { |f| (tr * f.normal).z > 0.99 }.map do |f|
          f.loops.map { |lp| lp.vertices.map { |v| q = tr * v.position; [q.x.to_f, q.y.to_f] } }
        end
      end
    end

    def self.dedans(px, py, poly)
      d = false; j = poly.size - 1
      poly.each_with_index { |(xi, yi), i| xj, yj = poly[j]; d = !d if ((yi > py) != (yj > py)) && (px < (xj - xi) * (py - yi) / (yj - yi + 1e-12) + xi); j = i }
      d
    end

    def self.dans_un_mur(x, y, emp)
      emp.any? { |loops| dedans(x, y, loops[0]) && loops[1..-1].none? { |t| dedans(x, y, t) } }
    end

    def self.lancer
      model = Sketchup.active_model
      ms = murs(model)
      if ms.empty?
        UI.messagebox('Aucun mur, cloison ou doublage balisé trouvé (sélectionnez-les, ou laissez la sélection vide pour prendre tous ceux du modèle).')
        return
      end
      rep = UI.inputbox(['Épaisseur du revêtement de sol (cm)', 'Surface minimale d\'une pièce (m²)'], ['1', '1'], 'Pièces automatiques (Métré Atelier 2M)')
      return unless rep
      ep = rep[0].tr(',', '.').to_f; smin = rep[1].tr(',', '.').to_f
      emp = empreintes(ms)
      z = ms.map { |g| g.bounds.min.z }.min
      bb = Geom::BoundingBox.new; ms.each { |g| bb.add(g.bounds) }
      marge = 1.m
      x0, y0, x1, y1 = bb.min.x - marge, bb.min.y - marge, bb.max.x + marge, bb.max.y + marge
      model.start_operation('Pièces automatiques (métré)', true)
      tmp = model.active_entities.add_group
      begin
        te = tmp.entities
        te.add_face([[x0, y0, z], [x1, y0, z], [x1, y1, z], [x0, y1, z]].map { |a| Geom::Point3d.new(*a) })
        emp.each { |loops| loops.each { |lp| te.add_edges((lp + [lp[0]]).map { |x, y| Geom::Point3d.new(x, y, z) }) } }
        te.intersect_with(false, Geom::Transformation.new, te, Geom::Transformation.new, true, te.to_a)
        te.grep(Sketchup::Edge).each { |e| e.find_faces if e.valid? }
        bord = ->(f) { f.vertices.any? { |v| p = v.position; (p.x - x0).abs < 0.1 || (p.x - x1).abs < 0.1 || (p.y - y0).abs < 0.1 || (p.y - y1).abs < 0.1 } }
        salles = te.grep(Sketchup::Face).select do |f|
          next false if bord.call(f)
          m = f.mesh; pts = m.polygon_points_at(1) rescue nil
          next false unless pts
          cx = pts.sum(&:x) / 3.0; cy = pts.sum(&:y) / 3.0
          !dans_un_mur(cx, cy, emp) && f.area * 0.00064516 >= smin
        end
        contours = salles.map { |f| [f.outer_loop.vertices.map(&:position), f.loops.reject(&:outer?).map { |lp| lp.vertices.map(&:position) }, f.area * 0.00064516] }
        tmp.erase!
        if contours.empty?
          model.abort_operation
          UI.messagebox('Aucune pièce fermée trouvée. Vérifiez que les murs et cloisons se touchent (pas d\'espace entre eux).')
          return
        end
        lb, _ = A2M::Balises.balise(model, 'A2M_PIECE', [120, 200, 120])
        crees = []
        contours.each_with_index do |(ext, trous, aire), i|
          g = model.active_entities.add_group
          f = g.entities.add_face(ext)
          trous.each { |t| h = g.entities.add_face(t); h.erase! if h && h.valid? }
          f = g.entities.grep(Sketchup::Face).max_by(&:area)
          f.reverse! if f.normal.z < 0
          f.pushpull((ep / 100.0).m) if ep > 0
          g.layer = lb
          A2M::Hachures.poser(g, model)
          model.selection.clear; model.selection.add(g)
          rp = UI.inputbox(['Nom de la pièce (vide = « Pièce n »)'], [''], "Pièce #{i + 1} / #{contours.size} : #{aire.round(2)} m² (en surbrillance)")
          g.name = rp && !rp[0].to_s.strip.empty? ? rp[0].to_s.strip : "Pièce #{i + 1}"
          crees << "#{g.name} : #{aire.round(2)} m²"
        end
        model.selection.clear
        model.commit_operation
        UI.messagebox("#{crees.size} pièce(s) créée(s) sur la balise A2M_PIECE :\n" + crees.join("\n"))
      rescue StandardError => ex
        tmp.erase! if tmp && tmp.valid?
        model.abort_operation
        UI.messagebox("Les pièces n'ont pas pu être créées (#{ex.message}).")
      end
    end
  end
end
