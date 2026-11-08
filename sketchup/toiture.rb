# encoding: UTF-8
# Métré Atelier 2M : toiture générée sur les murs sélectionnés (monopente, 2 pans, 4 pans, ou toiture qui suit exactement le contour des murs)
require 'sketchup.rb'
require File.join(File.dirname(__FILE__), 'squelette')

module A2M
  module Toiture
    TYPES = ['2 pans', '4 pans', 'Monopente', 'Suit les murs']
    SUIT = 'Suit les murs'
    @r = {}

    # Pans dans le repère du rectangle des murs : u le long du faîtage (longueur L), v en travers (largeur W), z depuis le haut des murs.
    # s = pente (m/m), d = débord (m). Retourne une liste de polygones [[u, v, z], …] en mètres.
    def self.pans(type, l, w, s, d)
      ze = -s * d
      case type
      when '2 pans'
        zr = s * w / 2.0
        [[[-d, -d, ze], [l + d, -d, ze], [l + d, w / 2.0, zr], [-d, w / 2.0, zr]],
         [[l + d, w + d, ze], [-d, w + d, ze], [-d, w / 2.0, zr], [l + d, w / 2.0, zr]]]
      when '4 pans'
        zr = s * w / 2.0
        if l <= w + 1e-9   # carré ou presque : pyramide
          c = [l / 2.0, w / 2.0, s * [l, w].min / 2.0]
          a = [-d, -d, ze]; b = [l + d, -d, ze]; e = [l + d, w + d, ze]; f = [-d, w + d, ze]
          [[a, b, c], [b, e, c], [e, f, c], [f, a, c]]
        else
          r1 = [w / 2.0, w / 2.0, zr]; r2 = [l - w / 2.0, w / 2.0, zr]
          a = [-d, -d, ze]; b = [l + d, -d, ze]; e = [l + d, w + d, ze]; f = [-d, w + d, ze]
          [[a, b, r2, r1], [e, f, r1, r2], [b, e, r2], [f, a, r1]]
        end
      else # monopente : bas côté v = 0, haut côté v = W
        [[[-d, -d, ze], [l + d, -d, ze], [l + d, w + d, s * (w + d)], [-d, w + d, s * (w + d)]]]
      end
    end

    # Rectangle orienté des murs sélectionnés : origine, axes (u = plus grand côté), longueur, largeur, haut des murs
    def self.rectangle(groupes)
      pts = []; aretes = []
      groupes.each do |g|
        ents = g.is_a?(Sketchup::Group) ? g.entities : g.definition.entities
        ents.grep(Sketchup::Edge).each { |e| a = g.transformation * e.start.position; b = g.transformation * e.end.position; pts << a << b; aretes << [a, b] }
      end
      return nil if pts.empty?
      horiz = aretes.select { |a, b| (a.z - b.z).abs < 0.4 }
      ref = horiz.max_by { |a, b| a.distance(b) }
      u = Geom::Vector3d.new(ref[1].x - ref[0].x, ref[1].y - ref[0].y, 0).normalize
      v = Z_AXIS.cross(u).normalize
      pu = pts.map { |q| q.x * u.x + q.y * u.y }; pv = pts.map { |q| q.x * v.x + q.y * v.y }
      o = Geom::Point3d.new(0, 0, 0).offset(u, pu.min).offset(v, pv.min)
      lu = (pu.max - pu.min).to_m; lv = (pv.max - pv.min).to_m
      ztop = pts.map(&:z).max
      lu >= lv ? [o, u, v, lu, lv, ztop] : [o.offset(u, (lu).m), v, u.reverse, lv, lu, ztop]
    end


    # Contour extérieur des murs (liste de [x, y] en mètres) : on réunit les faces du dessus des murs
    # dans un groupe provisoire, on efface les arêtes intérieures, et on lit le contour de la plus grande face.
    def self.contour(groupes, model)
      faces = []
      marche = lambda do |ents, tr|
        ents.each do |e|
          case e
          when Sketchup::Face
            faces << e.outer_loop.vertices.map { |vx| tr * vx.position } if e.normal.transform(tr).z > 0.99
          when Sketchup::Group then marche.call(e.entities, tr * e.transformation)
          when Sketchup::ComponentInstance then marche.call(e.definition.entities, tr * e.transformation)
          end
        end
      end
      groupes.each do |g|
        ents = g.is_a?(Sketchup::Group) ? g.entities : g.definition.entities
        marche.call(ents, g.transformation)
      end
      return nil if faces.empty?
      ztop = faces.flatten.map(&:z).max
      hautes = faces.select { |f| f.all? { |q| q.z > ztop - 0.4.m } }
      tmp = model.active_entities.add_group
      begin
        hautes.each do |pts|
          begin
            tmp.entities.add_face(pts.map { |q| Geom::Point3d.new(q.x, q.y, 0) })
          rescue StandardError
            nil
          end
        end
        tmp.entities.grep(Sketchup::Edge).select { |e| e.faces.size == 2 }.each(&:erase!)
        grande = tmp.entities.grep(Sketchup::Face).max_by(&:area)
        return nil unless grande
        pts = grande.outer_loop.vertices.map { |vx| [vx.position.x.to_m, vx.position.y.to_m] }
        [pts, ztop]
      ensure
        tmp.erase! if tmp.valid?
      end
    end

    # Épaisseur : sous-face parallèle aux pans (toutes les pentes sont égales, la sous-face est le dessus descendu
    # d'une même hauteur), chants verticaux à l'égout et aux rives. Le métré ne lit que le dessus des pans
    # (sous-face et chants verticaux sont ignorés à l'extraction) : surface et linéaires inchangés.
    def self.epaissir(ents, polys, ep_cm, s)
      dz = (ep_cm / 100.0 * Math.sqrt(1 + s * s)).m
      bas = ->(q) { q.offset(Z_AXIS, -dz) }
      # Bords du contour extérieur : ceux qui n'appartiennent qu'à un seul pan
      cle = ->(a, b) { [a, b].map { |q| [q.x, q.y, q.z].map { |c| (c * 10).round } }.sort }
      compte = Hash.new(0); bords = {}
      polys.each { |pts| pts.each_with_index { |a, i| b = pts[(i + 1) % pts.size]; k = cle.call(a, b); compte[k] += 1; bords[k] = [a, b] } }
      cx = polys.flatten.sum(&:x) / polys.flatten.size; cy = polys.flatten.sum(&:y) / polys.flatten.size
      polys.each do |pts|
        f = ents.add_face(pts.map(&bas))
        f.reverse! if f && f.normal.z > 0
      end
      bords.each do |k, (a, b)|
        next unless compte[k] == 1
        f = ents.add_face([a, b, bas.call(b), bas.call(a)])
        next unless f
        m = Geom::Point3d.new((a.x + b.x) / 2.0, (a.y + b.y) / 2.0, 0)
        f.reverse! if f.normal.x * (m.x - cx) + f.normal.y * (m.y - cy) < 0   # chant tourné vers l'extérieur
      end
    end

    def self.lancer
      model = Sketchup.active_model
      murs = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      if murs.empty?
        UI.messagebox('Sélectionnez les murs (groupes) sur lesquels poser la toiture. Elle couvre le rectangle de ces murs, ou suit exactement leur contour (type « Suit les murs »).')
        return
      end
      rep = UI.inputbox(['Type de toiture', 'Pente (%)', 'Débord (m)', 'Épaisseur de la toiture (cm), perpendiculaire au pan (0 = simple face)',
                         'Faîtage parallèle au', 'Monopente : côté haut', 'Toiture n°'],
                        [@r[:type] || '2 pans', (@r[:pente] || 45).to_s, (@r[:d] || 0.5).to_s, (@r[:ep] || 20).to_s,
                         @r[:sens] || 'grand côté', @r[:haut] || 'côté opposé à l\'origine', @r[:num] || '1'],
                        [TYPES.join('|'), '', '', '', 'grand côté|petit côté', 'côté opposé à l\'origine|côté de l\'origine', '1|2|3|4'], 'Toiture (Métré Atelier 2M)')
      return unless rep
      type, pente, d, ep, sens, haut, num = rep[0], rep[1].tr(',', '.').to_f, rep[2].tr(',', '.').to_f, rep[3].tr(',', '.').to_f, rep[4], rep[5], rep[6]
      return UI.messagebox('La pente doit être supérieure à 0.') if pente <= 0
      return UI.messagebox('L\'épaisseur ne peut pas être négative.') if ep < 0
      @r = { type: type, pente: pente, d: d, ep: ep, sens: sens, haut: haut, num: num }
      suit = (type == SUIT)
      if suit
        ztop = nil
      else
        rc = rectangle(murs)
        return UI.messagebox('Aucune géométrie trouvée dans la sélection.') unless rc
        o, u, v, l, w, ztop = rc
      end
      if !suit && sens == 'petit côté'
        o = o.offset(u, l.m); u, v = v, u.reverse; l, w = w, l
      end
      if !suit && type == 'Monopente' && haut == 'côté de l\'origine'
        o = o.offset(u, l.m).offset(v, w.m); u = u.reverse; v = v.reverse
      end
      tag = num == '1' ? 'A2M_TOITURE' : "A2M_TOITURE_#{num}"
      model.start_operation('Toiture (métré)', true)
      begin
        s = pente / 100.0
        if suit
          c = contour(murs, model)
          unless c
            model.abort_operation
            return UI.messagebox('Je ne trouve pas le dessus des murs dans la sélection (faces horizontales en haut des murs).')
          end
          cpts, ztop = c
          ztop += (ep / 100.0 * Math.sqrt(1 + s * s)).m if ep > 0
          ext = A2M::Squelette.decaler(A2M::Squelette.nettoyer(cpts), d)
          pans3 = A2M::Squelette.toit(ext, s)
          polys = pans3.map { |poly| poly.map { |x, y, z| Geom::Point3d.new(x.m, y.m, ztop + (z - s * d).m) } }
          l = w = 0
        else
          # Avec une épaisseur, la sous-face repose sur le haut des murs (au nu extérieur) : le dessus est remonté d'autant
          ztop += (ep / 100.0 * Math.sqrt(1 + s * s)).m if ep > 0
          polys = pans(type, l, w, s, d).map do |poly|
            poly.map { |pu, pv, pz| o.offset(u, pu.m).offset(v, pv.m).offset(Z_AXIS, ztop + pz.m) }
          end
        end
        grp = model.active_entities.add_group
        polys.each do |pts|
          f = grp.entities.add_face(pts)
          f.reverse! if f && f.normal.z < 0
        end
        epaissir(grp.entities, polys, ep, pente / 100.0) if ep > 0
        lb, _ = A2M::Balises.balise(model, tag, (A2M::Balises::LISTE.find { |n, _, _| n == tag } || [])[2])
        grp.layer = lb
        A2M::Hachures.poser(grp, model)
        grp.name = "Toiture #{num} – #{type} #{pente.round}%#{ep > 0 ? ", ép. #{ep.round(1)} cm" : ''}"
        model.commit_operation
        Sketchup.status_text = suit ? "#{grp.name} créée (suit les murs), débord #{d} m, balise #{tag}" : "#{grp.name} créée sur #{l.round(2)} × #{w.round(2)} m, débord #{d} m, balise #{tag}"
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("La toiture n'a pas pu être créée (#{ex.message}).")
      end
    end
  end
end
