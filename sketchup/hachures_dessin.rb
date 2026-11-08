# encoding: UTF-8
# Métré Atelier 2M : hachure fabriquée à partir d'un dessin (cellule rectangulaire de traits, courbes comprises)
# Le dessin sélectionné (groupe ou arêtes) est lu, rangé dans Motifs/Mes dessins puis utilisé comme n'importe quelle hachure.
module A2M
  module Dessin
    REF = 10.0 # même valeur que la taille par défaut : à 100 % la cellule garde sa taille réelle (en cm)

    def self.dossier
      File.join(A2M::Hachures.dossier, 'Motifs', 'Mes dessins').tr('\\', '/')
    end

    # Toutes les arêtes de la sélection, en centimètres, dans le repère du modèle : [[x1,y1,z1,x2,y2,z2], …]
    def self.aretes(ents, tr = Geom::Transformation.new, res = [])
      ents.each do |e|
        case e
        when Sketchup::Edge
          a = tr * e.start.position; b = tr * e.end.position
          res << [a.x, a.y, a.z, b.x, b.y, b.z].map { |v| v.to_f * 2.54 }
        when Sketchup::Group
          aretes(e.entities, tr * e.transformation, res)
        when Sketchup::ComponentInstance
          aretes(e.definition.entities, tr * e.transformation, res)
        end
      end
      res
    end

    # Lit la sélection : { 'nom', 'l', 'h', 'segments' => [[ua,va,ub,vb]…] } (cm, origine en bas à gauche)
    def self.lire(sel, largeur = 14.0)
      ar = aretes(sel)
      raise 'Sélectionnez d’abord votre dessin (le groupe de l’isolant).' if ar.empty?
      xs = ar.flat_map { |a| [a[0], a[3]] }; ys = ar.flat_map { |a| [a[1], a[4]] }; zs = ar.flat_map { |a| [a[2], a[5]] }
      d = { 'x' => xs.minmax, 'y' => ys.minmax, 'z' => zs.minmax }
      fin = d.min_by { |_, v| v[1] - v[0] }.first
      i, j = { 'z' => [0, 1], 'y' => [0, 2], 'x' => [1, 2] }[fin]
      lu = ar.flat_map { |a| [a[i], a[3 + i]] }.minmax; lv = ar.flat_map { |a| [a[j], a[3 + j]] }.minmax
      wu = lu[1] - lu[0]; wv = lv[1] - lv[0]
      if (wu - largeur).abs <= 0.5 then permute = false
      elsif (wv - largeur).abs <= 0.5 then permute = true
      else
        raise format('Votre dessin mesure %.1f × %.1f cm : je ne trouve pas la largeur de %.0f cm.', wu, wv, largeur)
      end
      u0, u1 = permute ? lv : lu
      v0, v1 = permute ? lu : lv
      segs = ar.map do |a|
        p = permute ? [a[j], a[i], a[3 + j], a[3 + i]] : [a[i], a[j], a[3 + i], a[3 + j]]
        [p[0] - u0, p[1] - v0, p[2] - u0, p[3] - v0]
      end
      l = u1 - u0; h = v1 - v0
      e = 0.02
      # Seuls les côtés du rectangle (traits droits sur toute la longueur d'un bord) sont écartés ; les courbes qui frôlent le bord restent
      segs.reject! do |s|
        long = Math.hypot(s[2] - s[0], s[3] - s[1])
        (long < 1e-6) ||
          ((s[0] < e && s[2] < e || s[0] > l - e && s[2] > l - e) && long > 0.5 * h) ||
          ((s[1] < e && s[3] < e || s[1] > h - e && s[3] > h - e) && long > 0.5 * l)
      end
      raise 'Je ne trouve aucun trait à l’intérieur du rectangle.' if segs.empty?
      { 'l' => l.round(3), 'h' => h.round(3), 'segments' => segs.map { |s| s.map { |v| v.round(3) } } }
    end

    def self.enregistrer(nom, d)
      FileUtils.mkdir_p(dossier)
      f = File.join(dossier, "#{nom.gsub(%r{[\\/:*?"<>|]}, '_')}.dessin.json")
      File.write(f, JSON.generate(d.merge('nom' => nom)))
      f
    end

    def self.motif(f)
      d = JSON.parse(File.read(f, encoding: 'UTF-8'))
      nom = d['nom'] || File.basename(f, '.dessin.json')
      id = "Mes dessins|#{File.basename(f)}|#{nom}"
      { 'id' => id, 'nom' => nom, 'groupe' => 'Mes dessins', 'ref' => REF, 'familles' => [], 'dessin' => d,
        'description' => format('Dessin « %s » (%.1f × %.1f cm)', nom, d['l'], d['h']), 'origine' => 'dessin', 'ajout' => nil }
    end

    def self.tous
      Dir.glob(File.join(dossier, '*.dessin.json')).sort.map { |f| motif(f) rescue nil }.compact
    end

    # Image de la cellule : [png, largeur_cm, hauteur_cm]
    def self.png(m, o)
      d = m['dessin']
      l = d['l'].to_f; h = d['h'].to_f
      s = [700.0 / [l, h].max, 40.0].min
      w = [(l * s).round, 4].max; hh = [(h * s).round, 4].max
      sx = w / l; sy = hh / h
      cov = Array.new(w * hh, 0.0)
      r = [o["ep"].to_f / 100.0 * l * sx / 4.0, 0.7].max
      [-1, 0, 1].each do |ox|
        [-1, 0, 1].each do |oy|
          d['segments'].each do |a, b, c, e|
            A2M::MotifPat.trait(cov, w, hh, (a + ox * l) * sx, (h - (b + oy * h)) * sy, (c + ox * l) * sx, (h - (e + oy * h)) * sy, r)
          end
        end
      end
      lc = A2M::MotifPat.hex(o['trait']); la = o['trait_op'].to_f / 100.0
      fc = A2M::MotifPat.hex(o['fond']); fa = o['fond_op'].to_f / 100.0
      brut = Array.new(hh) do |y|
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
      [A2M::MotifPat.encoder(w, hh, brut), l, h]
    end

    # Pas de la tuile (cm) et position de la cellule pour que son centre tombe au milieu de tous les murs :
    # [pas, phi (centre à phi·pas), écart maximal en cm]
    def self.pas(bandes)
      t = bandes.map(&:last).max
      cs = bandes.map(&:first)
      meilleur = nil
      p = t
      while p <= 3.5 * t
        sx = cs.sum { |c| Math.cos(2 * Math::PI * c / p) }; sy = cs.sum { |c| Math.sin(2 * Math::PI * c / p) }
        phi = (Math.atan2(sy, sx) / (2 * Math::PI)) % 1.0
        e = cs.map { |c| d = (c / p - phi) % 1.0; [d, 1 - d].min * p }.max
        meilleur = [p, phi, e] if meilleur.nil? || e < meilleur[2] - 1e-9
        break if e < 0.03
        p += 0.002
      end
      meilleur
    end

    # Image pour un objet : tuile de largeur pas_cm (calée sur les murs), hauteur = celle de la cellule ;
    # la cellule (échelle k) est centrée à phi·pas ; le fond couvre toute la tuile. Renvoie [png, hauteur_cm]
    def self.png_objet(m, o, pas_cm, phi, k)
      d = m['dessin']
      l = d['l'].to_f * k; h = d['h'].to_f * k
      s = [[1024.0 / pas_cm, 700.0 / h].min, 40.0].min
      w = [(pas_cm * s).round, 4].max; hh = [(h * s).round, 4].max
      sx = w / pas_cm; sy = hh / h
      cov = Array.new(w * hh, 0.0)
      r = [o['ep'].to_f / 100.0 * l * sx / 4.0, 0.7].max
      x0 = phi * pas_cm - l / 2.0 + o['dx'].to_f          # déplacement réglé par l'utilisateur (cm)
      dy = o['dy'].to_f
      [-1, 0, 1].each do |ox|
        [-1, 0, 1].each do |oy|
          d['segments'].each do |a, b, c, e|
            xa = (x0 + a * k + ox * pas_cm) * sx; xb = (x0 + c * k + ox * pas_cm) * sx
            A2M::MotifPat.trait(cov, w, hh, xa, (h - (b * k + dy + oy * h)) * sy, xb, (h - (e * k + dy + oy * h)) * sy, r)
          end
        end
      end
      lc = A2M::MotifPat.hex(o['trait']); la = o['trait_op'].to_f / 100.0
      fc = A2M::MotifPat.hex(o['fond']); fa = o['fond_op'].to_f / 100.0
      brut = Array.new(hh) do |y|
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
      [A2M::MotifPat.encoder(w, hh, brut), h]
    end

    # Commande : crée la hachure à partir de la sélection ; renvoie le motif (ou lève une erreur lisible)
    def self.creer(model, nom)
      d = lire(model.selection.to_a)
      f = enregistrer(nom, d)
      motif(f)
    end
  end
end
