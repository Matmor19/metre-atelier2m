# encoding: UTF-8
# Métré Atelier 2M : contrôle du modèle avant l'extraction
require 'sketchup.rb'

module A2M
  module Controle
    SOLIDES = %w[A2M_MUR_PERI A2M_MUR_SOUB A2M_MUR_REFEND A2M_MUR_PIGNON A2M_DOUBLAGE A2M_ISOLANT_DOUBLAGE A2M_CLOISON]
    MENUIS = %w[A2M_FENETRE A2M_PORTE_FENETRE A2M_PORTE_ENTREE A2M_PORTE_INT]

    # Tous les groupes et composants du modèle, avec leur transformation et leur balise effective
    def self.objets
      res = []
      fouiller = lambda do |ents, tr, prof|
        ents.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          next if e.hidden?
          t2 = tr * e.transformation
          res << [e, t2, prof]
          sous = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          fouiller.call(sous, t2, prof + 1) if prof < 4 && !(e.layer && e.layer.name.start_with?('A2M_'))
        end
      end
      fouiller.call(Sketchup.active_model.entities, Geom::Transformation.new, 0)
      res
    end

    def self.dessus_poly(e, tr)
      ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
      f = ents.grep(Sketchup::Face).select { |x| (tr * x.normal).z > 0.99 }.max_by { |x| x.area }
      f && f.outer_loop.vertices.map { |v| q = tr * v.position; [q.x.to_f, q.y.to_f] }
    end

    def self.aire(p) p.each_with_index.sum { |(x1, y1), i| x2, y2 = p[(i + 1) % p.size]; x1 * y2 - x2 * y1 } / 2.0 end
    def self.convexe?(p)
      s = nil
      p.each_with_index do |(x1, y1), i|
        x2, y2 = p[(i + 1) % p.size]; x3, y3 = p[(i + 2) % p.size]
        c = (x2 - x1) * (y3 - y2) - (y2 - y1) * (x3 - x2)
        next if c.abs < 1e-6
        s ||= c > 0
        return false if (c > 0) != s
      end
      true
    end
    # Aire commune de deux polygones convexes (Sutherland-Hodgman)
    def self.inter_convexe(a, b)
      a = a.reverse if aire(a) < 0; b = b.reverse if aire(b) < 0
      out = a
      b.each_with_index do |(x1, y1), i|
        x2, y2 = b[(i + 1) % b.size]
        inp = out; out = []
        break if inp.empty?
        dedans = ->(p) { (x2 - x1) * (p[1] - y1) - (y2 - y1) * (p[0] - x1) >= -1e-9 }
        coupe = lambda do |p, q|
          a1 = y2 - y1; b1 = x1 - x2; c1 = a1 * x1 + b1 * y1
          a2 = q[1] - p[1]; b2 = p[0] - q[0]; c2 = a2 * p[0] + b2 * p[1]
          d = a1 * b2 - a2 * b1
          d.abs < 1e-12 ? q : [(b2 * c1 - b1 * c2) / d, (a1 * c2 - a2 * c1) / d]
        end
        inp.each_with_index do |p, k|
          q = inp[k - 1]
          if dedans.call(p)
            out << coupe.call(q, p) unless dedans.call(q)
            out << p
          elsif dedans.call(q)
            out << coupe.call(q, p)
          end
        end
      end
      out.size >= 3 ? aire(out).abs : 0.0
    end

    def self.lancer
      model = Sketchup.active_model
      obs = objets
      pb = []   # [message, entité]
      # 1. Groupes et composants de premier niveau sans balise A2M_ (ni contenu balisé)
      sans = obs.select { |e, _, prof| prof == 0 && !(e.layer && e.layer.name.start_with?('A2M_')) }
      sans.reject! do |e, _, _|
        ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
        tagged = false
        f = lambda { |es, d| es.each { |x| tagged ||= x.respond_to?(:layer) && x.layer && x.layer.name.start_with?('A2M_'); f.call(x.is_a?(Sketchup::Group) ? x.entities : x.definition.entities, d + 1) if d < 3 && (x.is_a?(Sketchup::Group) || x.is_a?(Sketchup::ComponentInstance)) } }
        f.call(ents, 0); tagged
      end
      sans.each { |e, _, _| pb << ["Sans balise du métré : « #{e.name.to_s.empty? ? (e.respond_to?(:definition) ? e.definition.name : 'groupe') : e.name} »", e] }
      # 2. Murs, doublages, cloisons qui ne sont pas des solides (le perçage et la mesure en ont besoin)
      murs = obs.select { |e, _, _| e.layer && SOLIDES.include?(e.layer.name) }
      murs.each { |e, _, _| pb << ["Pas un solide (volume ouvert) : « #{e.name} » (#{e.layer.name})", e] unless e.manifold? }
      # 3. Chevauchements entre murs de même balise (angles comptés deux fois)
      polys = murs.map { |e, tr, _| [e, dessus_poly(e, tr)] }.select { |_, p| p && p.size >= 3 && convexe?(p) }
      polys.combination(2).each do |(e1, p1), (e2, p2)|
        next unless e1.layer == e2.layer
        a = inter_convexe(p1, p2)
        pb << ["Murs qui se chevauchent (#{(a * 0.00064516).round(3)} m²) : « #{e1.name} » et « #{e2.name} »", e1] if a * 0.00064516 > 0.0005
      end
      # 4. Pièces
      pieces = obs.select { |e, _, _| e.layer && e.layer.name == 'A2M_PIECE' }
      pieces.each { |e, _, _| pb << ['Pièce sans nom (groupe A2M_PIECE)', e] if e.name.to_s.strip.empty? }
      pieces.group_by { |e, _, _| e.name.to_s.strip.downcase }.each { |n, l| pb << ["Plusieurs pièces portent le même nom : « #{l[0][0].name} » (#{l.size})", l[1][0]] if !n.empty? && l.size > 1 }
      # 5. Menuiseries loin de toute pièce et sans pièce choisie
      ppoly = pieces.map { |e, tr, _| dessus_poly(e, tr) }.compact
      obs.select { |e, _, _| e.layer && MENUIS.include?(e.layer.name) }.each do |e, tr, _|
        next if e.get_attribute('a2m', 'piece')
        c = tr * e.definition.bounds.center rescue (e.bounds.center)
        dmin = ppoly.map { |p| p.map { |x, y| Math.hypot(x - c.x, y - c.y) }.min }.min
        pb << ["Menuiserie sans pièce proche (plus d'1 m) : « #{e.name} »", e] if dmin.nil? || dmin > 1.m
      end
      # 6. Toitures sans face vers le haut
      obs.select { |e, _, _| e.layer && e.layer.name.start_with?('A2M_TOITURE') }.each do |e, tr, _|
        ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
        pb << ["Toiture sans pan lisible (aucune face tournée vers le haut) : « #{e.name} »", e] unless ents.grep(Sketchup::Face).any? { |f| (tr * f.normal).z > 0.05 }
      end
      if pb.empty?
        UI.messagebox("Contrôle du modèle : aucun problème trouvé.\n\n#{murs.size} mur(s) ou doublage(s), #{pieces.size} pièce(s). Vous pouvez extraire.")
        return
      end
      txt = pb.first(40).map { |m, _| '- ' + m }.join("\n")
      txt += "\n… et #{pb.size - 40} autre(s)" if pb.size > 40
      if UI.messagebox("Contrôle du modèle : #{pb.size} point(s) à vérifier.\n\n#{txt}\n\nSélectionner les éléments en cause ?", MB_YESNO) == IDYES
        model.selection.clear
        pb.each { |_, e| model.selection.add(e) if e && e.valid? && e.parent == model.active_entities.parent rescue nil }
      end
    end
  end
end
