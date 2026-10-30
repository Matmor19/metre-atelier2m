# encoding: UTF-8
# Métré Atelier 2M : planelles en rive de dalle (et leur isolant), sur tout le pourtour de la dalle sélectionnée
#  - profil dessiné (planelle en L, isolant…), profil de la bibliothèque, ou rectangle avec isolant ;
#  - dans l'épaisseur (nu extérieur de la planelle = bord de la dalle, la dalle est recoupée d'autant)
#    ou à l'extérieur de la dalle ;
#  - le linéaire est rappelé à l'import dans le configurateur (pas encore de case planelle au métré).
require 'sketchup.rb'

module A2M
  module Planelles
    DANS = 'Dans l\'épaisseur de la dalle (la dalle est recoupée)'
    DEHORS = 'À l\'extérieur de la dalle'
    TYPE_PL = ['Planelle', 'A2M_PLANELLE', 0, 0, 'Planelle']
    TYPE_ISO = ['Isolant de planelle', 'A2M_ISOLANT_PLANELLE', 0, 0, 'Isolant de planelle']
    @r = {}

    # Contour extérieur du dessus de la dalle (sens trigonométrique), hauteur du dessous et du dessus
    def self.contour(g)
      tr = g.transformation
      faces = g.entities.grep(Sketchup::Face)
      hs = faces.select { |f| f.normal.transform(tr).z > 0.99 }
      return nil if hs.empty?
      top = hs.max_by(&:area)
      pts = top.outer_loop.vertices.map { |v| tr * v.position }
      zs = faces.flat_map { |f| f.vertices.map { |v| (tr * v.position).z } }
      pts.reverse! if A2M::DessinMurs.aire(pts.map { |q| [q.x, q.y] }) < 0
      [pts.map { |q| Geom::Point3d.new(q.x, q.y, zs.min) }, zs.min, zs.max]
    end

    PROFIL_DESSINE = 'Profil dessiné (sélection)'
    RECTANGLE = 'Rectangle (cotes ci-dessous)'
    EXT_LONG = 'Le plus long bord vertical'
    EXT_OPPOSE = 'Le côté opposé'

    # Profil dessiné : une ou plusieurs faces verticales dans le même plan (planelle en L, isolant…).
    # Repère commun : w = 0 au nu extérieur (le plus long bord vertical, ou le côté opposé), w vers l'intérieur ; h = 0 au plus bas.
    # La plus grande face est la planelle, les autres l'isolant.
    def self.profils_depuis(faces_tr, ext_long = true)
      return nil if faces_tr.empty?
      f0, t0 = faces_tr.max_by { |f, t| f.area }
      n = f0.normal.transform(t0).normalize
      return nil if n.z.abs > 0.1
      hx = Z_AXIS.cross(n).normalize
      o = t0 * f0.outer_loop.vertices[0].position
      proj = ->(q) { d = q - o; [d.dot(hx), d.dot(Z_AXIS)] }
      polys = faces_tr.map { |f, t| [f.outer_loop.vertices.map { |v| proj.call(t * v.position) }, f.area] }
      tous = polys.flat_map(&:first)
      wmin = tous.map(&:first).min; wmax = tous.map(&:first).max; hmin = tous.map(&:last).min
      # Plus long bord vertical, toutes faces confondues
      dos = nil; long = 0
      polys.each do |pts, _|
        pts.each_with_index do |(w1, h1), k|
          w2, h2 = pts[(k + 1) % pts.size]
          next unless (w1 - w2).abs < 0.04
          (long = (h1 - h2).abs; dos = w1) if (h1 - h2).abs > long
        end
      end
      inverser = dos && (dos - wmax).abs < (dos - wmin).abs
      inverser = !inverser unless ext_long
      polys.sort_by { |_, a| -a }.each_with_index.map do |(pts, _), k|
        [k.zero? ? TYPE_PL : TYPE_ISO, pts.map { |w, h| [inverser ? wmax - w : w - wmin, h - hmin] }]
      end
    end

    def self.rectangle(h, e, iso)
      c = ->(v) { (v / 100.0).m }
      r = [[TYPE_PL, [[0, 0], [c.call(e), 0], [c.call(e), c.call(h)], [0, c.call(h)]]]]
      r << [TYPE_ISO, [[c.call(e), 0], [c.call(e + iso), 0], [c.call(e + iso), c.call(h)], [c.call(e), c.call(h)]]] if iso > 0
      r
    end

    # Balaye un profil le long du contour fermé (départ au milieu du premier côté : angles propres)
    def self.balayer(pts, profil, dz, type, model)
      grp = model.active_entities.add_group
      ents = grp.entities
      milieu = Geom::Point3d.new((pts[0].x + pts[1].x) / 2.0, (pts[0].y + pts[1].y) / 2.0, pts[0].z)
      chemin = [milieu] + pts[1..-1] + [pts[0], milieu]
      d = (pts[1] - pts[0]).normalize
      m = Z_AXIS.cross(d).normalize                     # vers l'intérieur de la dalle (contour trigonométrique)
      face = ents.add_face(profil.map { |w, h| milieu.offset(m, w).offset(Z_AXIS, h + dz) })
      raise 'profil invalide' unless face
      bord = ents.add_edges(chemin)
      face.followme(bord)
      ents.grep(Sketchup::Edge).select { |e| e.valid? && e.faces.empty? }.each(&:erase!)
      tag, _ = A2M::Balises.balise(model, type[1], (A2M::Balises::LISTE.find { |x, _, _| x == type[1] } || [])[2])
      grp.layer = tag
      grp.name = "#{type[4]} #{model.active_entities.grep(Sketchup::Group).count { |g| g.name.to_s.start_with?(type[4]) }}"
      A2M::Hachures.poser(grp, model)
      grp
    end

    # Tous les profils de la bibliothèque de profils, les planelles en premier
    def self.bibliotheque
      (A2M::Profils.tous('Planelle') rescue [])
    end

    def self.lancer
      model = Sketchup.active_model
      sel = model.selection.to_a
      dalles = sel.select { |e| e.is_a?(Sketchup::Group) && contour(e) }
      return UI.messagebox("Sélectionnez la ou les dalles (groupes) et, si vous l'avez dessiné, votre profil de planelle (faces verticales, ou leur groupe).") if dalles.empty?
      faces = sel.grep(Sketchup::Face).select { |f| f.normal.z.abs < 0.1 }.map { |f| [f, Geom::Transformation.new] }
      sel.select { |e| e.is_a?(Sketchup::Group) && !dalles.include?(e) }.each do |g|
        g.entities.grep(Sketchup::Face).each { |f| faces << [f, g.transformation] if f.normal.transform(g.transformation).z.abs < 0.1 }
      end
      _, z0, z1 = contour(dalles[0])
      ep_dalle = ((z1 - z0) * 2.54).round(1)
      bib = bibliotheque
      noms = (faces.any? ? [PROFIL_DESSINE] : []) + bib.map { |o| A2M::Profils.libelle(o) } + [RECTANGLE]
      prec = noms.include?(@r[:profil]) ? @r[:profil] : noms[0]
      rep = UI.inputbox(['Profil', 'Nu extérieur du profil dessiné', 'Position', 'Décalage vertical depuis le dessous de la dalle (cm)',
                         'Rectangle : hauteur (cm)', 'Rectangle : épaisseur (cm)', 'Rectangle : isolant derrière (cm, 0 = aucun)',
                         'Ranger le profil dessiné dans la bibliothèque sous le nom (vide = non)'],
                        [prec, @r[:ext] || EXT_LONG, @r[:pos] || DANS, (@r[:dz] || 0).to_s, (@r[:h] || ep_dalle).to_s, (@r[:e] || 5).to_s, (@r[:iso] || 0).to_s, ''],
                        [noms.join('|'), [EXT_LONG, EXT_OPPOSE].join('|'), [DANS, DEHORS].join('|'), '', '', '', '', ''],
                        "Planelles en rive de dalle (épaisseur de la dalle : #{ep_dalle} cm)")
      return unless rep
      dz, h, e, iso = rep[3..6].map { |v| v.to_s.tr(',', '.').to_f }
      @r = { profil: rep[0], ext: rep[1], pos: rep[2], dz: dz, h: h, e: e, iso: iso }
      profils = case rep[0]
                when PROFIL_DESSINE then profils_depuis(faces, rep[1] == EXT_LONG)
                when RECTANGLE then (h > 0 && e > 0 ? rectangle(h, e, iso) : nil)
                else
                  o = bib.find { |x| A2M::Profils.libelle(x) == rep[0] }
                  A2M::Profils.parties(o).map { |role, pts| [role == 'isolant' ? TYPE_ISO : TYPE_PL, pts] }
                end
      return UI.messagebox('Profil introuvable : dessinez une face verticale (le profil), ou choisissez le rectangle.') unless profils && profils.any?
      ranger(rep[7].to_s.strip, profils) if rep[0] == PROFIL_DESSINE && !rep[7].to_s.strip.empty?
      dans = rep[2] == DANS
      unless dans
        wmax = profils.flat_map { |_, pts| pts.map(&:first) }.max
        profils = profils.map { |t, pts| [t, pts.map { |w, hh| [w - wmax, hh] }] }   # tout le profil à l'extérieur du bord
      end
      model.start_operation('Planelles en rive de dalle (métré)', true)
      begin
        faits = []
        dalles.each do |g|
          pts, = contour(g)
          groupes = profils.map { |t, pr| balayer(pts, pr, (dz / 100.0).m, t, model) }
          # Dans l'épaisseur : la dalle est recoupée là où passe la planelle
          if dans
            groupes.each do |gb|
              copie = gb.copy
              vol = g.volume rescue -1
              nom, tag, mat = g.name, g.layer, g.material
              res = A2M::Ouvertures.inverse? ? g.subtract(copie) : copie.subtract(g)
              if res && !(vol > 0 && (res.volume rescue 0) > vol + 1)
                res.name = nom; res.layer = tag; res.material = mat if mat
                g = res
              else
                copie.erase! if copie.valid?
              end
            end
          end
          long = (0...pts.size).sum { |k| pts[k].distance(pts[(k + 1) % pts.size]) } * 0.0254
          faits << "#{g.name.to_s.empty? ? 'Dalle' : g.name} : #{long.round(2)} ml"
        end
        model.commit_operation
        UI.messagebox("Planelles posées (#{rep[0]}) :\n" + faits.join("\n") +
                      "\n\nLe linéaire sera rappelé à l'import dans le configurateur (pas de case planelle au métré pour l'instant).")
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Planelles non posées (#{ex.message}).")
      end
    end

    # Profil dessiné rangé dans la bibliothèque (réutilisable sans le redessiner)
    def self.ranger(nom, profils)
      A2M::Profils.enregistrer(nom, 'Planelle', profils.map { |t, pts| [t[1] =~ /ISOLANT/ ? 'isolant' : 'principal', pts] })
    rescue StandardError => ex
      UI.messagebox("Profil non rangé dans la bibliothèque (#{ex.message}).")
    end
  end
end
