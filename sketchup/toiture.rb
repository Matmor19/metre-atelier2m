# encoding: UTF-8
# Métré Atelier 2M : toiture générée sur les murs sélectionnés (monopente, 2 pans, 4 pans)
require 'sketchup.rb'

module A2M
  module Toiture
    TYPES = ['2 pans', '4 pans', 'Monopente']
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

    def self.lancer
      model = Sketchup.active_model
      murs = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      if murs.empty?
        UI.messagebox('Sélectionnez les murs (groupes) sur lesquels poser la toiture. Elle couvre le rectangle de ces murs.')
        return
      end
      rep = UI.inputbox(['Type de toiture', 'Pente (%)', 'Débord (m)', 'Faîtage parallèle au', 'Monopente : côté haut', 'Toiture n°'],
                        [@r[:type] || '2 pans', (@r[:pente] || 45).to_s, (@r[:d] || 0.5).to_s, @r[:sens] || 'grand côté', @r[:haut] || 'côté opposé à l\'origine', @r[:num] || '1'],
                        [TYPES.join('|'), '', '', 'grand côté|petit côté', 'côté opposé à l\'origine|côté de l\'origine', '1|2|3|4'], 'Toiture (Métré Atelier 2M)')
      return unless rep
      type, pente, d, sens, haut, num = rep[0], rep[1].tr(',', '.').to_f, rep[2].tr(',', '.').to_f, rep[3], rep[4], rep[5]
      return UI.messagebox('La pente doit être supérieure à 0.') if pente <= 0
      @r = { type: type, pente: pente, d: d, sens: sens, haut: haut, num: num }
      rc = rectangle(murs)
      return UI.messagebox('Aucune géométrie trouvée dans la sélection.') unless rc
      o, u, v, l, w, ztop = rc
      if sens == 'petit côté'
        o = o.offset(u, l.m); u, v = v, u.reverse; l, w = w, l
      end
      if type == 'Monopente' && haut == 'côté de l\'origine'
        o = o.offset(u, l.m).offset(v, w.m); u = u.reverse; v = v.reverse
      end
      tag = num == '1' ? 'A2M_TOITURE' : "A2M_TOITURE_#{num}"
      model.start_operation('Toiture (métré)', true)
      begin
        grp = model.active_entities.add_group
        pans(type, l, w, pente / 100.0, d).each do |poly|
          pts = poly.map { |pu, pv, pz| o.offset(u, pu.m).offset(v, pv.m).offset(Z_AXIS, ztop + pz.m) }
          f = grp.entities.add_face(pts)
          f.reverse! if f && f.normal.z < 0
        end
        lb, _ = A2M::Balises.balise(model, tag, (A2M::Balises::LISTE.find { |n, _, _| n == tag } || [])[2])
        grp.layer = lb
        grp.name = "Toiture #{num} – #{type} #{pente.round}%"
        model.commit_operation
        Sketchup.status_text = "#{grp.name} créée sur #{l.round(2)} × #{w.round(2)} m, débord #{d} m, balise #{tag}"
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("La toiture n'a pas pu être créée (#{ex.message}).")
      end
    end
  end
end
