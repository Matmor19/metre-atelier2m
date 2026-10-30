# encoding: UTF-8
# Métré Atelier 2M : isolant ondulé centré (une seule ligne de laine au milieu de chaque couche, en coupe verticale)
# SketchUp cale les hachures sur l'origine du modèle : chaque groupe reçoit donc sa propre hachure, dont le pas
# est choisi pour que l'onde tombe au milieu de tous ses murs (murs parallèles aux axes rouge et vert).
module A2M
  module Onde
    ID = 'Atelier 2M|onde|Isolant ondulé centré'
    MOTIF = { 'id' => ID, 'nom' => 'Isolant ondulé centré', 'groupe' => 'Atelier 2M', 'onde' => true, 'ref' => 1.0, 'familles' => [],
              'description' => "Isolant ondulé centré (une ligne de laine au milieu de la couche, en coupe)" }
    PAS = 0.75  # longueur d'une boucle, en part de la largeur de l'onde
    BOUCLE = 2.0 # taille des boucles (rapport du cycloïde allongé)

    # Bandes d'épaisseur d'un groupe, en cm, dans le repère du modèle : [[centre, largeur], …]
    # (mur le long de l'axe rouge : bande en y ; le long de l'axe vert : bande en x)
    def self.bandes(g)
      tr = g.transformation
      faces = { 0 => [], 1 => [] }
      g.entities.grep(Sketchup::Face).each do |f|
        n = f.normal.transform(tr).normalize
        ax = n.x.abs > 0.999 ? 0 : (n.y.abs > 0.999 ? 1 : nil)
        next unless ax
        pts = f.outer_loop.vertices.map { |v| tr * v.position }
        long = (pts.map { |p| ax == 0 ? p.y : p.x }.minmax.reduce(:-)).abs.to_f * 2.54   # longueur du parement
        c = (ax == 0 ? pts[0].x : pts[0].y).to_f * 2.54
        faces[ax] << [c, (ax == 0 ? n.x : n.y) > 0 ? 1 : -1, long]
      end
      res = []
      faces.each_value do |fs|
        fs.select { |_, s, _| s < 0 }.each do |a, _, la|
          b = fs.select { |c, s, _| s > 0 && c > a + 0.5 && c - a < 60 }.min_by(&:first)
          next unless b
          w = b[0] - a
          next if la < 2 * w && b[2] < 2 * w                  # tableaux d'ouverture, pas un mur
          res << [(a + b[0]) / 2.0, w]
        end
      end
      res.uniq { |c, w| [(c * 10).round, (w * 10).round] }
    end

    # Pas du motif (cm) pour que tous les centres tombent sur l'onde : [pas, décalage (0 ou 0,5), écart max (cm)]
    def self.pas(bandes)
      t = bandes.map(&:last).max
      cs = bandes.map(&:first)
      meilleur = nil
      p = t
      while p <= 2.5 * t
        [0.0, 0.5].each do |phi|
          e = cs.map { |c| d = (c / p - phi) % 1.0; [d, 1 - d].min * p }.max
          meilleur = [p, phi, e] if meilleur.nil? || e < meilleur[2] - 1e-9
        end
        p += 0.005
      end
      meilleur
    end

    # Image du motif : largeur = pas (en travers du mur), hauteur = une boucle ; onde centrée sur le décalage
    def self.png(pas_cm, phi, largeur_cm, o)
      boucle = [largeur_cm * PAS, 0.5].max
      k = [512.0 / pas_cm, 256.0 / boucle].min
      w = [(pas_cm * k).round, 4].max; h = [(boucle * k).round, 4].max
      sx = w / pas_cm; sy = h / boucle
      cov = Array.new(w * h, 0.0)
      r = [o['ep'].to_f / 100.0 * largeur_cm * sx / 2.0, 0.7].max
      a = largeur_cm / 2.0                                   # demi-largeur de l'onde
      rr = boucle / (2 * Math::PI); bb = BOUCLE * rr         # cycloïde allongé : avance rr·s, recul bb·sin s
      cx = phi * pas_cm
      [-1, 0, 1].each do |ox|
        [-1, 0, 1].each do |oy|
          prec = nil
          0.step(2 * Math::PI, 2 * Math::PI / 160) do |s|
            u = cx + ox * pas_cm + a * Math.cos(s)
            v = oy * boucle + rr * s - bb * Math.sin(s)
            q = [u * sx, (boucle - v) * sy]
            A2M::MotifPat.trait(cov, w, h, prec[0], prec[1], q[0], q[1], r) if prec
            prec = q
          end
        end
      end
      lc = A2M::MotifPat.hex(o['trait']); la = o['trait_op'].to_f / 100.0
      fc = A2M::MotifPat.hex(o['fond']); fa = o['fond_op'].to_f / 100.0
      brut = Array.new(h) do |y|
        rang = "\0".b
        w.times do |x|
          c = cov[y * w + x] * la
          al = c + fa * (1 - c)
          if al <= 0 then rang << "\0\0\0\0".b
          else
            px = (0..2).map { |i| ((lc[i] * c + fc[i] * fa * (1 - c)) / al).round.clamp(0, 255) }
            rang << [px[0], px[1], px[2], (al * 255).round].pack('C4')
          end
        end
        rang
      end.join
      [A2M::MotifPat.encoder(w, h, brut), boucle]
    end
  end
end
