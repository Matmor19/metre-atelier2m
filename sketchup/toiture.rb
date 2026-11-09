# encoding: UTF-8
# Métré Atelier 2M : toiture générée sur les murs sélectionnés (monopente, 2 pans, 4 pans, ou toiture qui suit exactement le contour des murs)
require 'sketchup.rb'
require 'json'
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

    ATTR = 'a2m_toiture'
    class << self; attr_reader :polys_dernier; end

    # Fenêtre de réglages ; avec modif = true, une question de plus sur le contour. Retourne un Hash ou nil.
    def self.saisir(prm, modif = false)
      r = prm || @r
      noms = ['Type de toiture', 'Pente (%)', 'Débord (m)', 'Épaisseur de la toiture (cm), perpendiculaire au pan (0 = simple face)',
              'Faîtage parallèle au', 'Monopente : côté haut', 'Toiture n°']
      vals = [r[:type] || '2 pans', (r[:pente] || 45).to_s, (r[:d] || 0.5).to_s, (r[:ep] || 20).to_s,
              r[:sens] || 'grand côté', r[:haut] || 'côté opposé à l\'origine', r[:num] || '1']
      listes = [TYPES.join('|'), '', '', '', 'grand côté|petit côté', 'côté opposé à l\'origine|côté de l\'origine', '1|2|3|4']
      if modif
        noms << 'Contour de la toiture'; vals << 'Garder le contour actuel'
        listes << 'Garder le contour actuel|Reprendre sur les murs sélectionnés avec la toiture'
      end
      rep = UI.inputbox(noms, vals, listes, modif ? 'Modifier la toiture (Métré Atelier 2M)' : 'Toiture (Métré Atelier 2M)')
      return nil unless rep
      h = { type: rep[0], pente: rep[1].tr(',', '.').to_f, d: rep[2].tr(',', '.').to_f, ep: rep[3].tr(',', '.').to_f,
            sens: rep[4], haut: rep[5], num: rep[6], reprendre: modif && rep[7].start_with?('Reprendre') }
      if h[:pente] <= 0 then UI.messagebox('La pente doit être supérieure à 0.'); return nil end
      if h[:ep] < 0 then UI.messagebox('L\'épaisseur ne peut pas être négative.'); return nil end
      @r = h.reject { |k, _| k == :reprendre }
      h
    end

    # Ce qu'il faut retenir des murs pour refaire la toiture plus tard (JSON-able)
    def self.base_des_murs(murs, type, model)
      if type == SUIT
        c = contour(murs, model)
        return nil unless c
        { 'k' => 'suit', 'cpts' => c[0], 'ztop' => c[1].to_f }
      else
        rc = rectangle(murs)
        return nil unless rc
        o, u, v, l, w, ztop = rc
        { 'k' => 'rect', 'o' => o.to_a, 'u' => u.to_a, 'v' => v.to_a, 'l' => l, 'w' => w, 'ztop' => ztop.to_f }
      end
    end


    # ---- Faîtages et arêtiers : visuel seulement (le métré reste au mètre linéaire, il ne les lit pas) ----
    # Une pièce par arête : faîtage = arête horizontale entre deux pans, arêtier = arête inclinée en saillie.
    # Les noues (arêtes rentrantes) ne reçoivent rien. Groupes séparés, balises A2M_FAITAGE_3D / A2M_ARETIER_3D.
    ACC = 'a2m_toiture_acc'
    FAIT_PROFIL = [[-14, -2], [14, -2], [10, 8], [-10, 8]].freeze   # [écart latéral cm, hauteur cm]

    def self.accessoires(model, toit, polys)
      cle = ->(q) { [q.x, q.y, q.z].map { |c| (c * 10).round } }
      aretes = Hash.new { |h, k| h[k] = [] }
      polys.each_with_index do |pts, pi|
        pts.each_with_index { |a, i| b = pts[(i + 1) % pts.size]; aretes[[cle.call(a), cle.call(b)].sort] << [a, b, pi] }
      end
      nrm = lambda do |pts|
        n = Geom::Vector3d.new(0, 0, 0)
        pts.each_with_index { |a, i| b = pts[(i + 1) % pts.size]; n += Geom::Vector3d.new((a.y - b.y) * (a.z + b.z), (a.z - b.z) * (a.x + b.x), (a.x - b.x) * (a.y + b.y)) }
        n.length > 0 ? n.normalize : n
      end
      normales = polys.map { |pts| n = nrm.call(pts); n.z < 0 ? n.reverse : n }
      centres = polys.map { |pts| Geom::Point3d.new(pts.sum { |q| q.x } / pts.size, pts.sum { |q| q.y } / pts.size, pts.sum { |q| q.z } / pts.size) }
      pid = toit.persistent_id
      cree = 0
      aretes.each_value do |l|
        next unless l.size == 2
        a, b, p1 = l[0]; _, _, p2 = l[1]
        next if p1 == p2 || a.distance(b) < 0.05.m
        # saillie ? l'autre pan doit être sous le plan du premier
        next unless (centres[p2] - centres[p1]).dot(normales[p1]) < -1e-6 && (centres[p1] - centres[p2]).dot(normales[p2]) < -1e-6
        horiz = (a.z - b.z).abs < 0.001.m
        tag = horiz ? 'A2M_FAITAGE_3D' : 'A2M_ARETIER_3D'
        d = b - a
        s = Z_AXIS.cross(d); next if s.length < 1e-9
        s.normalize!
        g = model.active_entities.add_group
        sec = lambda { |o| FAIT_PROFIL.map { |x, z| o.offset(s, x.cm).offset(Z_AXIS, z.cm) } }
        sa = sec.call(a); sb = sec.call(b)
        g.entities.add_face(sa); g.entities.add_face(sb)
        sa.each_index { |i| j = (i + 1) % sa.size; g.entities.add_face(sa[i], sa[j], sb[j], sb[i]) }
        g.entities.grep(Sketchup::Face).each { |f| c = f.bounds.center; f.reverse! if f.normal.dot(c - Geom::Point3d.new((a.x + b.x) / 2.0, (a.y + b.y) / 2.0, (a.z + b.z) / 2.0 + 0.04.m)) < 0 }
        lb, _ = A2M::Balises.balise(model, tag, (A2M::Balises::LISTE.find { |n, _, _| n == tag } || [])[2])
        g.layer = lb
        g.name = horiz ? 'Faîtage' : 'Arêtier'
        g.set_attribute(ACC, 'toit', pid)
        cree += 1
      end
      cree
    end

    def self.effacer_accessoires(model, toit)
      pid = toit.persistent_id
      model.active_entities.to_a.each { |e| e.erase! if e.valid? && e.respond_to?(:get_attribute) && e.get_attribute(ACC, 'toit') == pid }
    end

    def self.batir(model, prm, base)
      type, d, ep, num = prm[:type], prm[:d], prm[:ep], prm[:num]
      s = prm[:pente] / 100.0
      tag = num == '1' ? 'A2M_TOITURE' : "A2M_TOITURE_#{num}"
      ztop = base['ztop'].to_f
      ztop += (ep / 100.0 * Math.sqrt(1 + s * s)).m if ep > 0   # la sous-face repose sur le haut des murs
      if base['k'] == 'suit'
        raise 'Ce contour ne convient pas au type choisi' unless type == SUIT
        ext = A2M::Squelette.decaler(A2M::Squelette.nettoyer(base['cpts']), d)
        polys = A2M::Squelette.toit(ext, s).map { |poly| poly.map { |x, y, z| Geom::Point3d.new(x.m, y.m, ztop + (z - s * d).m) } }
      else
        raise 'Ce contour ne convient pas au type choisi : reprenez-le sur les murs' if type == SUIT
        o = Geom::Point3d.new(*base['o']); u = Geom::Vector3d.new(*base['u']); v = Geom::Vector3d.new(*base['v'])
        l, w = base['l'], base['w']
        if prm[:sens] == 'petit côté'
          o = o.offset(u, l.m); u, v = v, u.reverse; l, w = w, l
        end
        if type == 'Monopente' && prm[:haut] == 'côté de l\'origine'
          o = o.offset(u, l.m).offset(v, w.m); u = u.reverse; v = v.reverse
        end
        polys = pans(type, l, w, s, d).map do |poly|
          poly.map { |pu, pv, pz| o.offset(u, pu.m).offset(v, pv.m).offset(Z_AXIS, ztop + pz.m) }
        end
      end
      @polys_dernier = polys
      grp = model.active_entities.add_group
      polys.each do |pts|
        f = grp.entities.add_face(pts)
        f.reverse! if f && f.normal.z < 0
      end
      epaissir(grp.entities, polys, ep, s) if ep > 0
      lb, _ = A2M::Balises.balise(model, tag, (A2M::Balises::LISTE.find { |n, _, _| n == tag } || [])[2])
      grp.layer = lb
      A2M::Hachures.poser(grp, model)
      grp.name = "Toiture #{num} – #{type} #{prm[:pente].round}%#{ep > 0 ? ", ép. #{ep.round(1)} cm" : ''}"
      grp.set_attribute(ATTR, 'prm', JSON.generate(prm.reject { |k, _| k == :reprendre }.map { |k, v| [k.to_s, v] }.to_h))
      grp.set_attribute(ATTR, 'base', JSON.generate(base))
      (accessoires(model, grp, polys) rescue nil)
      grp
    end

    def self.lancer
      model = Sketchup.active_model
      murs = model.selection.to_a.select { |e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && !e.get_attribute(ATTR, 'base') }
      if murs.empty?
        UI.messagebox('Sélectionnez les murs (groupes) sur lesquels poser la toiture. Elle couvre le rectangle de ces murs, ou suit exactement leur contour (type « Suit les murs »).')
        return
      end
      prm = saisir(nil) or return
      model.start_operation('Toiture (métré)', true)
      begin
        base = base_des_murs(murs, prm[:type], model)
        unless base
          model.abort_operation
          return UI.messagebox(prm[:type] == SUIT ? 'Je ne trouve pas le dessus des murs dans la sélection (faces horizontales en haut des murs).' : 'Aucune géométrie trouvée dans la sélection.')
        end
        grp = batir(model, prm, base)
        model.commit_operation
        Sketchup.status_text = "#{grp.name} créée, débord #{prm[:d]} m. Pour la changer : « Modifier la toiture »."
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("La toiture n'a pas pu être créée (#{ex.message}).")
      end
    end

    # Rouvre une toiture déjà créée : mêmes réglages, contour gardé (ou repris sur d'autres murs sélectionnés avec elle)
    def self.modifier(grp = nil)
      model = Sketchup.active_model
      grp ||= model.selection.to_a.find { |e| e.respond_to?(:get_attribute) && e.get_attribute(ATTR, 'base') }
      unless grp
        UI.messagebox('Sélectionnez la toiture à modifier (une toiture créée avec « Créer la toiture »).')
        return
      end
      prm = (JSON.parse(grp.get_attribute(ATTR, 'prm')).map { |k, v| [k.to_sym, v] }.to_h rescue nil)
      base = (JSON.parse(grp.get_attribute(ATTR, 'base')) rescue nil)
      return UI.messagebox('Cette toiture n\'a pas gardé ses réglages.') unless prm && base
      nv = saisir(prm, true) or return
      model.start_operation('Modifier la toiture (métré)', true)
      begin
        if nv[:reprendre]
          murs = model.selection.to_a.select { |e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && !e.get_attribute(ATTR, 'base') }
          if murs.empty?
            model.abort_operation
            return UI.messagebox('Pour reprendre le contour : sélectionnez les murs EN PLUS de la toiture, puis relancez « Modifier la toiture ».')
          end
          base = base_des_murs(murs, nv[:type], model)
          unless base
            model.abort_operation
            return UI.messagebox('Je ne trouve pas le dessus de ces murs.')
          end
        elsif (nv[:type] == SUIT) != (base['k'] == 'suit')
          model.abort_operation
          return UI.messagebox('Ce changement de type demande de reprendre le contour : choisissez « Reprendre sur les murs sélectionnés avec la toiture ».')
        end
        nouvelle = batir(model, nv, base)
        effacer_accessoires(model, grp)
        grp.erase!
        model.commit_operation
        model.selection.clear
        model.selection.add(nouvelle)
        Sketchup.status_text = "#{nouvelle.name} modifiée."
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("La toiture n'a pas pu être modifiée (#{ex.message}).")
      end
    end
  end
end
