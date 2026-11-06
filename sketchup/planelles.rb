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
      polys = faces_tr.map { |f, t| [f.outer_loop.vertices.map { |v| proj.call(t * v.position) }, f.area, aspect_face(f)] }
      tous = polys.flat_map(&:first)
      wmin = tous.map(&:first).min; wmax = tous.map(&:first).max; hmin = tous.map(&:last).min
      # Plus long bord vertical, toutes faces confondues
      dos = nil; long = 0
      polys.each do |pts, _, _|
        pts.each_with_index do |(w1, h1), k|
          w2, h2 = pts[(k + 1) % pts.size]
          next unless (w1 - w2).abs < 0.04
          (long = (h1 - h2).abs; dos = w1) if (h1 - h2).abs > long
        end
      end
      inverser = dos && (dos - wmax).abs < (dos - wmin).abs
      inverser = !inverser unless ext_long
      tries = polys.sort_by { |_, a, _| -a }
      @aspects = tries.map { |_, _, l| l }
      tries.each_with_index.map do |(pts, _, _), k|
        [k.zero? ? TYPE_PL : TYPE_ISO, pts.map { |w, h| [inverser ? wmax - w : w - wmin, h - hmin] }]
      end
    end

    # Aspects retenus (dans l'ordre des parties) par le dernier profil dessiné lu, ou par le profil de bibliothèque choisi
    def self.aspects() @aspects || [] end

    # Aspect d'une face dessinée : matière 3D (nom) et hachure de coupe (celle de son groupe), si elles existent
    def self.aspect_face(f)
      m = f.material || f.back_material
      inst = (f.parent.respond_to?(:instances) ? f.parent.instances.first : nil)
      h = (inst && inst.respond_to?(:hatch_pattern) ? inst.hatch_pattern : nil)
      l = {}
      l['mat'] = m.name if m && !m.name.to_s.empty?
      l['hach'] = h.name if h && !h.name.to_s.empty?
      l.empty? ? nil : l
    rescue StandardError
      nil
    end

    # Pose l'aspect d'un profil sur le volume balayé : matière en 3D, hachure en coupe (2D)
    def self.habiller(grp, look, model)
      return unless look.is_a?(Hash)
      if (mn = look['mat'])
        m = model.materials[mn] || (A2M::TexturesAuto.matiere(model, mn) rescue nil)
        grp.entities.grep(Sketchup::Face).each { |f| f.material = m; f.back_material = m } if m
      end
      if (hn = look['hach']) && (h = (model.hatch_patterns[hn] rescue nil))
        grp.hatch_pattern = h
      end
    rescue StandardError
      nil
    end

    def self.rectangle(h, e, iso)
      c = ->(v) { (v / 100.0).m }
      r = [[TYPE_PL, [[0, 0], [c.call(e), 0], [c.call(e), c.call(h)], [0, c.call(h)]]]]
      r << [TYPE_ISO, [[c.call(e), 0], [c.call(e + iso), 0], [c.call(e + iso), c.call(h)], [c.call(e), c.call(h)]]] if iso > 0
      r
    end

    # Balaye un profil le long du contour fermé (départ au milieu du premier côté : angles propres)
    def self.balayer(pts, profil, dz, type, model, ents_cible = nil, look = nil)
      grp = (ents_cible || model.active_entities).add_group
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
      habiller(grp, look, model)
      grp
    end

    # Tous les profils de la bibliothèque de profils, les planelles en premier
    # Journal de la dernière pose (Documents/Atelier 2M/planelles_journal.txt) : permet de comprendre un souci sans refaire la pose
    def self.journal(txt = nil)
      f = File.join(File.dirname(A2M::Bibliotheque.dossier), 'planelles_journal.txt')
      if txt.nil?
        File.write(f, "#{Time.now}\n", encoding: 'UTF-8')
      else
        File.open(f, 'a', encoding: 'UTF-8') { |io| io.puts(txt) }
      end
    rescue StandardError
      nil
    end

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
      rep = UI.inputbox(['Profil', 'Nu extérieur du profil dessiné', 'Position', 'Décalage vertical (cm) — 0 : la planelle posée sur le soubassement, la dalle au niveau de son haut',
                         'Rectangle : hauteur (cm)', 'Rectangle : épaisseur (cm)', 'Rectangle : isolant derrière (cm, 0 = aucun)',
                         'Ranger le profil dessiné dans la bibliothèque sous le nom (vide = non)'],
                        [prec, @r[:ext] || EXT_LONG, @r[:pos] || DANS, (@r[:dz] || 0).to_s, (@r[:h] || ep_dalle).to_s, (@r[:e] || 5).to_s, (@r[:iso] || 0).to_s, ''],
                        [noms.join('|'), [EXT_LONG, EXT_OPPOSE].join('|'), [DANS, DEHORS].join('|'), '', '', '', '', ''],
                        "Planelles en rive de dalle (épaisseur de la dalle : #{ep_dalle} cm)")
      return unless rep
      dz, h, e, iso = rep[3..6].map { |v| v.to_s.tr(',', '.').to_f }
      @r = { profil: rep[0], ext: rep[1], pos: rep[2], dz: dz, h: h, e: e, iso: iso }
      @aspects = []
      profils = case rep[0]
                when PROFIL_DESSINE then profils_depuis(faces, rep[1] == EXT_LONG)
                when RECTANGLE then (h > 0 && e > 0 ? rectangle(h, e, iso) : nil)
                else
                  o = bib.find { |x| A2M::Profils.libelle(x) == rep[0] }
                  @aspects = (o['aspects'] || [])
                  A2M::Profils.parties(o).map { |role, pts| [role == 'isolant' ? TYPE_ISO : TYPE_PL, pts] }
                end
      aspects_pose = aspects.dup
      return UI.messagebox('Profil introuvable : dessinez une face verticale (le profil), ou choisissez le rectangle.') unless profils && profils.any?
      ranger(rep[7].to_s.strip, profils, aspects_pose) if rep[0] == PROFIL_DESSINE && !rep[7].to_s.strip.empty?
      dans = rep[2] == DANS
      unless dans
        wmax = profils.flat_map { |_, pts| pts.map(&:first) }.max
        profils = profils.map { |t, pts| [t, pts.map { |w, hh| [w - wmax, hh] }] }   # tout le profil à l'extérieur du bord
      end
      model.start_operation('Planelles en rive de dalle (métré)', true)
      journal
      begin
        faits = []
        non_recoupees = 0
        sans_descente = 0
        murs_abaisses = 0
        dalles_deplacees = 0
        soub_trouve = false
        remonte_max = 0.0
        hmax_cm = 0.0; ep_cm = 0.0
        dalles.each do |g|
          pts, = contour(g)
          vol0 = g.volume rescue 0
          journal("dalle #{g.name} : volume #{vol0.round(0)}, valide #{g.valid?}")
          # La planelle se pose sur le mur de soubassement ; la dalle se cale ensuite sur le haut de la planelle
          _, zb, zh = contour(g)
          hmax = profils.flat_map { |_, pr| pr.map(&:last) }.max
          hmax_cm = hmax * 2.54; ep_cm = (zh - zb) * 2.54
          zs = dans ? dessus_soubassement(g, zb) : nil
          remonte_cm = 0.0
          if zs
            dm = (zs + (dz / 100.0).m + hmax) - zh               # la dalle monte (ou descend) pour que son haut = haut de la planelle
            if dm.abs > 0.01
              g.transform!(Geom::Transformation.translation(Geom::Vector3d.new(0, 0, dm)))
              remonte_cm = dm * 2.54
              pts, = contour(g)
              _, zb, zh = contour(g)
            end
            dz_long = (zs + (dz / 100.0).m) - zb                 # dessous de la planelle = dessus du soubassement
            journal("soubassement trouvé : dessus z=#{(zs * 2.54).round(1)} cm, dalle déplacée de #{remonte_cm.round(1)} cm")
          else
            dz_long = (zh - zb) - hmax + (dz / 100.0).m
          end
          dalles_deplacees += 1 if remonte_cm.abs > 0.05
          soub_trouve = true if zs
          remonte_max = remonte_cm if remonte_cm.abs > remonte_max.abs
          groupes = profils.each_with_index.map { |(t, pr), k| balayer(pts, pr, dz_long, t, model, g.parent.entities, aspects_pose[k]) }
          specs = profils.map { |_, pr| spec_rect(pr) }
          # Dans l'épaisseur : la dalle est recoupée là où passe la planelle
          if dans
            # Si la planelle descend sous la dalle : la dalle redescend, au droit du mur de soubassement, jusqu'au dessus de ce mur
            if hmax > (zh - zb) + 0.01
              murs_abaisses += abaisser_soubassement(g, zb, dz_long) unless zs
              pleins = remplissages_soubassement(g, zb, dz_long)
              fus = pleins.empty? ? nil : fusionner(g, pleins)
              journal("descente : murs abaissés #{murs_abaisses}, remplissages #{pleins.size}, fusion #{fus ? 'OK volume ' + fus.volume.round(0).to_s : 'refusée'}")
              if fus
                nom, tag, mat = g.name, g.layer, g.material
                g.erase!
                fus.name = nom; fus.layer = tag; fus.material = mat if mat
                (A2M::Hachures.poser(fus, model) rescue nil)
                g = fus
              else
                sans_descente += 1
              end
              pleins.each { |x| x.erase! if x.valid? }
            end
            groupes.each_with_index do |gb, k|
              next unless gb.valid? && g.valid?
              res = soustraire(g, gb, specs[k], dz_long)
              journal("coupe #{k} (#{gb.name}) : #{res ? 'OK volume ' + res.volume.round(0).to_s : 'refusée'}")
              if res
                nom, tag, mat = g.name, g.layer, g.material
                g.erase!
                res.name = nom; res.layer = tag; res.material = mat if mat
                A2M::Hachures.poser(res, model)
                g = res
              else
                non_recoupees += 1
              end
            end
          end
          # Garde-fou : la dalle ne doit jamais disparaître ni perdre l'essentiel de son volume
          unless g.valid? && (g.volume rescue 0) > vol0 * 0.4 && g.visible?
            journal("ANNULÉ : dalle perdue (valide #{g.valid?})")
            raise 'la dalle aurait été perdue, tout est annulé'
          end
          long = (0...pts.size).sum { |k| pts[k].distance(pts[(k + 1) % pts.size]) } * 0.0254
          faits << "#{g.name.to_s.empty? ? 'Dalle' : g.name} : #{long.round(2)} ml"
        end
        model.commit_operation
        UI.messagebox("Planelles posées (#{rep[0]}, version #{(A2M::Metre::EXT.version rescue "?")}) :\n" + faits.join("\n") +
                      (non_recoupees > 0 ? "\n\nLa dalle n'a pas pu être recoupée (#{non_recoupees} fois) : elle doit être un volume fermé (groupe sans trou ni arête isolée). Les planelles sont posées, la dalle est restée intacte." : '') +
                      (soub_trouve ? "\n\nSoubassement trouvé : la planelle est posée sur son dessus." : "\n\nAUCUN mur de soubassement (balise « Murs de soubassement ») trouvé sous la dalle : la planelle a été calée sur le haut de la dalle, sans la déplacer.") +
                      (dalles_deplacees > 0 ? "\n\nLa planelle est posée sur le mur de soubassement et la dalle a été #{remonte_max > 0 ? 'remontée' : 'descendue'} de #{remonte_max.abs.round(1)} cm pour que son haut affleure le haut de la planelle. Si l'isolant ou la chape sont déjà posés, refaites-les après." : '') +
                      (murs_abaisses > 0 ? "\n\nLe dessus du mur de soubassement a été abaissé de #{((hmax_cm || 0) - (ep_cm || 0)).round(1)} cm : la planelle prend sa place sous la dalle." : '') +
                      (sans_descente > 0 ? "\n\nLa dalle n'a pas pu être prolongée jusqu'au mur de soubassement (mur balisé « Murs de soubassement » introuvable au droit de la planelle, ou calcul refusé)." : '') +
                      "\n\nLe linéaire sera rappelé à l'import dans le configurateur (pas de case planelle au métré pour l'instant).")
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Planelles non posées (#{ex.message}).")
      end
    end

    # Dessus du mur de soubassement (balise A2M_MUR_SOUB) situé sous la dalle, au droit de son emprise ; nil si aucun.
    # Cherche aussi dans les groupes et composants imbriqués ; consigne dans le journal tout ce qui a été vu.
    def self.dessus_soubassement(g, zb)
      bb = g.bounds
      tous = []
      cherche = lambda do |ents, tr, prof|
        ents.each do |w|
          next unless w.valid? && (w.is_a?(Sketchup::Group) || w.is_a?(Sketchup::ComponentInstance))
          next if w.equal?(g)
          if w.layer && w.layer.name == 'A2M_MUR_SOUB'
            b = w.bounds
            pts = [b.min, b.max].map { |q| tr * q }
            tous << [pts.map(&:z).max, pts.map(&:x).min, pts.map(&:x).max, pts.map(&:y).min, pts.map(&:y).max]
          elsif prof < 2
            cherche.call(w.is_a?(Sketchup::Group) ? w.entities : w.definition.entities, tr * w.transformation, prof + 1)
          end
        end
      end
      cherche.call(g.parent.entities, Geom::Transformation.new, 0)
      journal("murs de soubassement vus : #{tous.size} ; dessus (cm) : #{tous.map { |t| (t[0] * 2.54).round(1) }.uniq.sort.inspect} ; dessous de la dalle : #{(zb * 2.54).round(1)} cm")
      hauts = tous.select do |zt, x0, x1, y0, y1|
        zt <= zb + 2.cm && zt > zb - 40.cm && x0 < bb.max.x && x1 > bb.min.x && y0 < bb.max.y && y1 > bb.min.y
      end.map(&:first)
      hauts.empty? ? nil : hauts.max
    end

    # Murs de soubassement dont le dessus affleure le dessous de la dalle : la planelle (plus haute que la dalle) descend
    # à leur place, donc leur dessus est abaissé de l'excédent (le béton de la dalle comble ensuite l'emprise du mur).
    # Renvoie le nombre de murs abaissés.
    def self.abaisser_soubassement(g, zb, dz_long)
      delta = -dz_long
      return 0 unless delta > 0.2.cm && delta < 30.cm
      bb = g.bounds
      n = 0
      g.parent.entities.grep(Sketchup::Group).each do |w|
        next unless w.valid? && w.layer.name == 'A2M_MUR_SOUB' && (w.bounds.max.z - zb).abs < 0.8
        next unless w.bounds.min.x < bb.max.x && w.bounds.max.x > bb.min.x && w.bounds.min.y < bb.max.y && w.bounds.max.y > bb.min.y
        t = w.transformation
        zt = w.bounds.max.z
        hauts = w.entities.grep(Sketchup::Face).select { |f| f.normal.transform(t).z > 0.99 && (f.vertices.first.position.transform(t).z - zt).abs < 0.05 }
        hauts.each { |f| f.pushpull(-delta) if f.valid? }
        unless hauts.empty?
          n += 1
          # Le calcul de la hauteur refait les faces : hachure de coupe et textures A2M_ sont reposées sur le mur
          (A2M::Hachures.poser(w, Sketchup.active_model) rescue nil)
        end
      end
      n
    end

    # Volumes qui comblent, entre le dessous de la dalle et le dessus du mur de soubassement, l'emprise de ce mur
    # (la dalle « descend » au droit du mur, comme la planelle). Un groupe par face supérieure de mur ; [] si aucun mur ne convient.
    def self.remplissages_soubassement(g, zb, dz_long)
      ents = g.parent.entities
      z_planelle = zb + dz_long                       # dessous de la planelle = dessus du mur de soubassement
      bb = g.bounds
      murs = ents.grep(Sketchup::Group).select do |w|
        w.valid? && w.layer.name == 'A2M_MUR_SOUB' && (w.bounds.max.z - z_planelle).abs < 0.8 &&
          w.bounds.min.x < bb.max.x && w.bounds.max.x > bb.min.x && w.bounds.min.y < bb.max.y && w.bounds.max.y > bb.min.y
      end
      haut = (zb - z_planelle) + 1.cm                # remonte de 1 cm dans la dalle pour que les volumes se recouvrent
      res = []
      murs.each do |w|
        t = w.transformation
        zt = w.bounds.max.z
        w.entities.grep(Sketchup::Face).select { |f| f.normal.transform(t).z > 0.99 && (f.vertices.first.position.transform(t).z - zt).abs < 0.05 }.each do |f|
          fg = ents.add_group
          ext = f.outer_loop.vertices.map { |v| q = v.position.transform(t); Geom::Point3d.new(q.x, q.y, zt) }
          fg.entities.add_face(ext)
          f.loops.reject(&:outer?).each do |l|
            h = fg.entities.add_face(l.vertices.map { |v| q = v.position.transform(t); Geom::Point3d.new(q.x, q.y, zt) })
            h.erase! if h && h.valid?
          end
          nf = fg.entities.grep(Sketchup::Face).first
          if nf
            nf.reverse! if nf.normal.z < 0
            nf.pushpull(haut)
            res << fg
          else
            fg.erase!
          end
        end
      end
      res
    rescue StandardError
      res.each { |x| x.erase! if x.valid? } if res
      []
    end

    # Dalle + volumes de remplissage : copies indépendantes, chaque fusion est acceptée si le résultat est plus volumineux
    def self.fusionner(g, pleins)
      cur = g
      ok = false
      pleins.each do |plein|
        next unless plein.valid? && cur.valid?
        vol = cur.volume rescue -1
        next unless vol > 0
        a = cur.copy; a.make_unique
        b = plein.copy; b.make_unique
        res = (a.union(b) rescue nil)
        if res && res.valid? && (res.volume rescue 0) > vol + 0.5
          cur.erase! unless cur.equal?(g)
          cur = res; ok = true
        else
          res.erase! if res && res.valid?
          [a, b].each { |x| x.erase! if x && x.valid? }
        end
      end
      ok ? cur : nil
    end

    # Pour recouper la dalle, le volume balayé ne convient pas (Group#subtract le refuse, bruit de calcul du balayage).
    # Quand le profil est un rectangle, on reconstruit l'anneau de coupe proprement : contour décalé vers l'intérieur
    # de la dalle (calcul exact), face avec son trou, puis relevée. Renvoie [wmin, wmax, hmin, hmax] ou nil.
    def self.spec_rect(pr)
      return nil unless pr.size == 4
      pr = pr.map { |w, h| [w.round(6), h.round(6)] }
      ws = pr.map(&:first).uniq.sort
      hs = pr.map(&:last).uniq.sort
      return nil unless ws.size == 2 && hs.size == 2 && pr.all? { |w, h| ws.include?(w) && hs.include?(h) }
      [ws[0], ws[1], hs[0], hs[1]]
    end

    # Contour (sens trigonométrique) décalé de w vers l'intérieur : intersection des droites décalées de chaque côté
    def self.decaler(pts, w)
      return pts.map(&:clone) if w.abs < 1e-9
      n = pts.size
      droites = (0...n).map do |i|
        a, b = pts[i], pts[(i + 1) % n]
        d = (b - a).normalize
        d = Geom::Vector3d.new(0, d.y <=> 0, 0) if d.x.abs < 1e-9      # côtés d'axe : coordonnées exactes, sans bruit de calcul
        d = Geom::Vector3d.new(d.x <=> 0, 0, 0) if d.y.abs < 1e-9
        nm = Z_AXIS.cross(d).normalize
        [a.offset(nm, w), d]
      end
      (0...n).map do |i|
        p1, d1 = droites[i - 1]
        p2, d2 = droites[i]
        den = d1.x * d2.y - d1.y * d2.x
        return nil if den.abs < 1e-9
        t = ((p2.x - p1.x) * d2.y - (p2.y - p1.y) * d2.x) / den
        Geom::Point3d.new((p1.x + d1.x * t).round(9), (p1.y + d1.y * t).round(9), p1.z)   # arrondi : le bruit de calcul (1e-14) fait refuser le booléen
      end
    end

    def self.anneau_coupe(pts, spec, dz, ents_cible = nil)
      wmin, wmax, hmin, hmax = spec
      w0 = [wmin, 0.0].max
      return nil if wmax <= 1e-9 || hmax - hmin < 1e-9
      ext = decaler(pts, w0)
      int = decaler(pts, wmax)
      return nil unless ext && int
      z0 = pts[0].z + dz + hmin
      g = (ents_cible || Sketchup.active_model.active_entities).add_group
      lv = ->(l) { l.map { |p| Geom::Point3d.new(p.x, p.y, z0) } }
      g.entities.add_face(lv.call(ext))
      g.entities.add_face(lv.call(int)).erase!
      f = g.entities.grep(Sketchup::Face).first
      f.reverse! if f.normal.z < 0
      f.pushpull(hmax - hmin)
      g
    rescue StandardError
      g.erase! if g && g.valid?
      nil
    end

    # Dalle moins planelle, sans jamais perdre la dalle : calcul sur des copies neuves à chaque essai (un Group#subtract
    # raté détruit ses opérandes), dans les deux sens ; le bon sens est reconnu au résultat (la dalle amputée garde
    # l'emprise de la dalle). Renvoie le groupe résultat, ou nil.
    def self.soustraire(g, coupe, spec = nil, dz = 0.0)
      vol = g.volume rescue -1
      return nil unless vol > 0
      diag = g.bounds.diagonal
      pts, = contour(g)
      [A2M::Ouvertures.inverse?, !A2M::Ouvertures.inverse?].each do |inv|
        next unless g.valid? && coupe.valid?
        a = g.copy
        a.make_unique   # une copie partage la définition de l'original : un booléen raté détruirait aussi l'original
        b = (spec && pts) ? anneau_coupe(pts, spec, dz, g.parent.entities) : coupe.copy
        b.make_unique if b && b.valid?
        next unless a && b
        res = (inv ? a.subtract(b) : b.subtract(a)) rescue nil
        if res && res.valid?
          v = (res.volume rescue 0)
          return res if v > 0 && v <= vol + 1 && res.bounds.diagonal >= diag * 0.9
          res.erase!
        end
        [a, b].each { |x| x.erase! if x && x.valid? }
      end
      nil
    end

    # Profil dessiné rangé dans la bibliothèque (réutilisable sans le redessiner)
    def self.ranger(nom, profils, aspects = nil)
      A2M::Profils.enregistrer(nom, 'Planelle', profils.map { |t, pts| [t[1] =~ /ISOLANT/ ? 'isolant' : 'principal', pts] }, aspects)
    rescue StandardError => ex
      UI.messagebox("Profil non rangé dans la bibliothèque (#{ex.message}).")
    end
  end
end
