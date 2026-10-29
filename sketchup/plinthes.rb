# encoding: UTF-8
# Métré Atelier 2M : plinthes posées le long du revêtement de sol d'une pièce, coupées au droit des ouvertures
require 'sketchup.rb'
require 'json'

module A2M
  module Plinthes
    TOL = 0.3937   # 1 cm en pouces
    BALISE = 'A2M_PLINTHE'

    # ---- Ouvertures enregistrées dans le modèle (empreinte au sol et genre : porte, libre, fenetre) ----
    def self.ouvertures(model = Sketchup.active_model)
      JSON.parse(model.get_attribute('a2m', 'ouvertures', '[]')) rescue []
    end

    def self.enregistrer(rect, genre, model = Sketchup.active_model, id = nil)
      liste = ouvertures(model)
      liste << { 'pts' => rect.map { |q| [q.x.to_f, q.y.to_f] }, 'z' => rect[0].z.to_f, 'genre' => genre, 'id' => id }
      model.set_attribute('a2m', 'ouvertures', JSON.generate(liste))
    end

    # Ouverture rebouchée ou déplacée : son empreinte est retirée de la liste
    def self.retirer(id, model = Sketchup.active_model)
      return unless id
      liste = ouvertures(model)
      reste = liste.reject { |o| o['id'] == id }
      model.set_attribute('a2m', 'ouvertures', JSON.generate(reste)) if reste.size != liste.size
    end

    # ---- Profil : face dessinée dans un plan vertical ; dos de la plinthe = sa plus longue arête verticale ----
    def self.profil_depuis(face, tr)
      n = (tr * face.normal).normalize
      return nil if n.z.abs > 0.1
      hx = Z_AXIS.cross(n).normalize
      p0 = tr * face.outer_loop.vertices[0].position
      pts = face.outer_loop.vertices.map { |v| q = tr * v.position; d = q - p0; [d.dot(hx), d.dot(Z_AXIS)] }
      wmin = pts.map(&:first).min; hmin = pts.map(&:last).min
      pts = pts.map { |w, h| [w - wmin, h - hmin] }
      wmax = pts.map(&:first).max
      # Plus longue arête verticale : c'est le dos, contre le mur
      dos = nil; long = 0
      pts.each_with_index do |(w1, h1), i|
        w2, h2 = pts[(i + 1) % pts.size]
        next unless (w1 - w2).abs < 0.04
        if (h1 - h2).abs > long then long = (h1 - h2).abs; dos = w1 end
      end
      pts = pts.map { |w, h| [wmax - w, h] } if dos && (dos - wmax).abs < (dos - 0).abs
      pts
    end

    def self.profil_rectangle(h_cm, e_cm)
      h = (h_cm / 100.0).m; e = (e_cm / 100.0).m
      [[0, 0], [e, 0], [e, h], [0, h]]
    end

    # ---- Géométrie 2D ----
    def self.aire(poly) poly.each_with_index.sum { |(x1, y1), i| x2, y2 = poly[(i + 1) % poly.size]; x1 * y2 - x2 * y1 } / 2.0 end

    # Rectangle (4 points dans l'ordre) agrandi (> 0) ou réduit (< 0) : du le long du mur, dv dans l'épaisseur
    def self.ajuste(rect, du, dv = du)
      cx = rect.sum { |x, _| x } / 4.0; cy = rect.sum { |_, y| y } / 4.0
      u = [rect[1][0] - rect[0][0], rect[1][1] - rect[0][1]]; lu = Math.hypot(*u); u = u.map { |c| c / lu }
      v = [rect[3][0] - rect[0][0], rect[3][1] - rect[0][1]]; lv = Math.hypot(*v); v = v.map { |c| c / lv }
      a = lu / 2.0 + du; b = lv / 2.0 + dv
      return nil if a <= 0 || b <= 0
      [[-1, -1], [1, -1], [1, 1], [-1, 1]].map { |su, sv| [cx + su * a * u[0] + sv * b * v[0], cy + su * a * u[1] + sv * b * v[1]] }
    end

    # Partie [t0, t1] du segment AB à l'intérieur d'un polygone convexe (méthode de Cyrus-Beck), ou nil
    def self.clip(a, b, poly)
      s = aire(poly) > 0 ? 1 : -1
      t0, t1 = 0.0, 1.0
      dx, dy = b[0] - a[0], b[1] - a[1]
      poly.each_with_index do |(x1, y1), i|
        x2, y2 = poly[(i + 1) % poly.size]
        nx, ny = -(y2 - y1) * s, (x2 - x1) * s      # normale intérieure
        num = nx * (a[0] - x1) + ny * (a[1] - y1)
        den = nx * dx + ny * dy
        if den.abs < 1e-12
          return nil if num < 0
        else
          t = -num / den
          den > 0 ? (t0 = [t0, t].max) : (t1 = [t1, t].min)
          return nil if t0 > t1
        end
      end
      [t0, t1]
    end

    # Contour du revêtement (dessus) en coordonnées du modèle, sens trigonométrique, et hauteur du dessus
    def self.contour(g, tr)
      hs = g.entities.grep(Sketchup::Face).select { |f| f.normal.z > 0.99 }
      return nil if hs.empty?
      top = hs.max_by { |f| [f.vertices[0].position.z, f.area] }
      pts = top.outer_loop.vertices.map { |v| tr * v.position }
      z = pts[0].z
      xy = pts.map { |q| [q.x.to_f, q.y.to_f] }
      xy.reverse! if aire(xy) < 0
      [xy, z]
    end

    # Morceaux du contour gardés pour les plinthes : coupés aux portes (passage et tableaux) ; ouverture libre : seulement le passage
    def self.troncons(xy, ouvs)
      zones = ouvs.map do |o|
        next nil if o['genre'] == 'fenetre'
        # Le long du mur : 1 mm (coupe exacte au droit des tableaux) ; dans l'épaisseur : 1 cm
        r = o['genre'] == 'libre' ? ajuste(o['pts'], -TOL / 10.0, -TOL) : ajuste(o['pts'], TOL / 10.0, TOL)
        r
      end.compact
      morceaux = []
      n = xy.size
      n.times do |i|
        a = xy[i]; b = xy[(i + 1) % n]
        coupes = zones.map { |z| clip(a, b, z) }.compact.sort
        t = 0.0
        coupes.each do |c0, c1|
          morceaux << [a, b, t, c0] if c0 > t + 1e-6
          t = [t, c1].max
        end
        morceaux << [a, b, t, 1.0] if t < 1.0 - 1e-6
      end
      # Morceaux bout à bout réunis en chaînes continues
      pt = ->(a, b, t) { [a[0] + (b[0] - a[0]) * t, a[1] + (b[1] - a[1]) * t] }
      chaines = []
      morceaux.each do |a, b, t0, t1|
        p0 = pt.call(a, b, t0); p1 = pt.call(a, b, t1)
        if chaines.any? && Math.hypot(chaines[-1][-1][0] - p0[0], chaines[-1][-1][1] - p0[1]) < 0.01
          chaines[-1] << p1
        else
          chaines << [p0, p1]
        end
      end
      # Contour fermé sans coupure : une seule chaîne qui revient au départ
      if chaines.size > 1 && Math.hypot(chaines[-1][-1][0] - chaines[0][0][0], chaines[-1][-1][1] - chaines[0][0][1]) < 0.01
        chaines[0] = chaines.pop + chaines[0][1..-1]
      end
      chaines
    end

    # Crée (ou recrée) les plinthes d'une pièce
    def self.generer(g, tr, profil, model = Sketchup.active_model)
      ct = contour(g, tr)
      return 0 unless ct
      xy, z = ct
      pid = g.persistent_id
      model.active_entities.grep(Sketchup::Group).select { |p| p.get_attribute('a2m', 'plinthe_de') == pid }.each(&:erase!)
      chaines = troncons(xy, ouvertures(model))
      return 0 if chaines.empty?
      grp = model.active_entities.add_group
      grp.transformation = Geom::Transformation.new
      ents = grp.entities
      ferme = ->(c) { Math.hypot(c[-1][0] - c[0][0], c[-1][1] - c[0][1]) < 0.01 }
      lineaire = 0.0
      chaines.each do |c|
        next if c.size < 2
        p3 = c.map { |x, y| Geom::Point3d.new(x, y, z) }
        lineaire += p3.each_cons(2).sum { |a, b| a.distance(b) }
        d = (p3[1] - p3[0]).normalize
        m = Z_AXIS.cross(d).normalize   # contour trigonométrique : l'intérieur de la pièce est à gauche
        prof = profil.map { |w, h| p3[0].offset(m, w).offset(Z_AXIS, h) }
        face = ents.add_face(prof)
        next unless face
        chemin = ents.add_edges(p3)
        face.followme(chemin)
      end
      l, _ = A2M::Balises.balise(model, BALISE, [255, 255, 255])
      grp.layer = l
      grp.name = "Plinthes – #{g.name}"
      grp.set_attribute('a2m', 'plinthe_de', pid)
      g.set_attribute('a2m', 'plinthe_profil', JSON.generate(profil.map { |w, h| [w.to_f, h.to_f] }))
      lineaire.to_m
    end

    # Recalcule les plinthes des pièces proches d'une ouverture qui vient d'être créée
    def self.regenerer_autour(rect)
      model = Sketchup.active_model
      cx = rect.sum(&:x) / 4.0; cy = rect.sum(&:y) / 4.0
      faites = []
      A2M::Ouvertures.pieces_monde.each do |g, tr|
        prof = g.get_attribute('a2m', 'plinthe_profil')
        next unless prof
        ct = contour(g, tr); next unless ct
        xy, _z = ct
        dmin = xy.map { |x, y| Math.hypot(x - cx, y - cy) }.min
        bb = g.bounds
        next unless dmin < 5.m || (cx.between?(bb.min.x - 1.m, bb.max.x + 1.m) && cy.between?(bb.min.y - 1.m, bb.max.y + 1.m))
        generer(g, tr, JSON.parse(prof), model)
        faites << g.name
      end
      faites
    end

    # Commande : sélection = revêtement(s) de sol (groupes A2M_PIECE) et, si vous en avez dessiné un, le profil (une face verticale)
    def self.lancer
      model = Sketchup.active_model
      sel = model.selection.to_a
      pieces = sel.select { |e| e.is_a?(Sketchup::Group) && e.layer && e.layer.name == 'A2M_PIECE' }
      if pieces.empty?
        UI.messagebox("Sélectionnez le revêtement de sol de la ou des pièces (groupes A2M_PIECE).\nAjoutez à la sélection la face de votre profil de plinthe si vous en avez dessiné une.")
        return
      end
      faces = sel.grep(Sketchup::Face)
      profil = nil
      if (f = faces.find { |x| x.normal.z.abs < 0.1 })
        profil = profil_depuis(f, Geom::Transformation.new)
      else
        grp_profil = sel.find { |e| e.is_a?(Sketchup::Group) && !pieces.include?(e) }
        if grp_profil && (fp = grp_profil.entities.grep(Sketchup::Face).find { |x| (grp_profil.transformation * x.normal).z.abs < 0.1 })
          profil = profil_depuis(fp, grp_profil.transformation)
        end
      end
      unless profil
        # Pas de profil sélectionné : un profil de la bibliothèque, ou un rectangle
        rect = 'Profil rectangulaire (cotes ci-dessous)'
        bib = (A2M::Bibliotheque.plinthes rescue [])
        noms = [rect] + bib.map { |o| o['nom'] }
        rep = UI.inputbox(['Profil', 'Hauteur si rectangulaire (cm)', 'Épaisseur si rectangulaire (cm)'], [@profil && noms.include?(@profil) ? @profil : noms[-1], '10', '1.2'],
                          [noms.join('|'), '', ''], 'Plinthes : choix du profil')
        return unless rep
        @profil = rep[0]
        o = bib.find { |x| x['nom'] == rep[0] }
        profil = o ? o['profil'] : profil_rectangle(rep[1].tr(',', '.').to_f, rep[2].tr(',', '.').to_f)
      end
      model.start_operation('Poser les plinthes (métré)', true)
      begin
        tot = []
        pieces.each do |g|
          ml = generer(g, Geom::Transformation.new, profil, model)
          tot << "#{g.name} : #{(ml * 100).round / 100.0} ml"
        end
        model.commit_operation
        UI.messagebox("Plinthes posées :\n" + tot.join("\n") + "\n\nElles seront recoupées automatiquement aux prochaines portes et ouvertures libres créées avec l'outil Ouverture.")
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Les plinthes n'ont pas pu être posées (#{ex.message}).")
      end
    end
  end
end
