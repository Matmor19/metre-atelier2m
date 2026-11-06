# encoding: UTF-8
# Métré Atelier 2M : coupe à ligne brisée. SketchUp n'a qu'un plan de coupe plat : la coupe brisée est donc fabriquée en géométrie.
# Les ouvrages solides sont copiés et recoupés par un prisme (la zone entre la ligne brisée et le spectateur), les faces coupées sont
# peintes en noir (poché), le tout est rangé dans un groupe « Coupe brisée Bn » ; la scène cache les originaux et ne montre que cette coupe.
require 'sketchup.rb'
require 'json'

module A2M
  module CoupeBrisee
    ATTR = 'coupe_brisee'
    PREFIXE = 'Coupe brisée '
    IGNORES = /\A(Cotes coupe|Repère coupe|Coupe brisée|Séparateur)/

    def self.groupe(model, nom)
      model.entities.grep(Sketchup::Group).find { |g| g.valid? && g.name == PREFIXE + nom && g.get_attribute('a2m', ATTR) }
    end

    def self.donnees(g) JSON.parse(g.get_attribute('a2m', ATTR).to_s) rescue nil end

    def self.nom_suivant(model)
      i = 1
      i += 1 while groupe(model, "B#{i}")
      "B#{i}"
    end

    def self.lignes(model)
      model.entities.grep(Sketchup::Group).select { |g| g.valid? && g.name.start_with?(PREFIXE) && g.get_attribute('a2m', ATTR) }.map do |g|
        d = donnees(g) or next
        pts = d['pts'].map { |p| [(p[0] * 2.54).round(1), (p[1] * 2.54).round(1)] }
        { 'nom' => g.name.sub(PREFIXE, ''), 'brisee' => true, 'pts' => pts, 'a' => pts.first, 'b' => pts.last, 'dir' => d['dir'][0, 2] }
      end.compact
    end

    # Ouvrages de premier niveau à recouper : visibles, hors cotes, repères, séparateurs et coupes déjà faites
    def self.sources(model)
      model.entities.select do |e|
        (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.valid? && (e.visible? || e.get_attribute('a2m', 'cache_par')) && e.layer.visible? &&
          !(e.name.to_s =~ IGNORES) && !e.layer.name.start_with?('A2M_COTES') && e.layer.name != A2M::Separateur::TAG
      end
    end

    def self.dist_segment(px, py, a, b)
      dx = b[0] - a[0]; dy = b[1] - a[1]
      l2 = dx * dx + dy * dy
      t = l2 < 1e-12 ? 0.0 : [[((px - a[0]) * dx + (py - a[1]) * dy) / l2, 0.0].max, 1.0].min
      Math.hypot(px - (a[0] + t * dx), py - (a[1] + t * dy))
    end

    def self.noir(model)
      m = model.materials['A2M_Poché_coupe'] || model.materials.add('A2M_Poché_coupe')
      m.color = Sketchup::Color.new(20, 20, 20)
      m
    end

    # Peint en noir les faces verticales posées sur la ligne brisée (faces nées de la coupe)
    def self.poche(ent, pts, mat)
      t = ent.transformation
      ents = ent.is_a?(Sketchup::Group) ? ent.entities : ent.definition.entities
      n = 0
      ents.grep(Sketchup::Face).each do |f|
        nz = (t * f.normal).z.abs
        next if nz > 0.02
        ok = f.vertices.all? do |v|
          q = t * v.position
          pts.each_cons(2).any? { |a, b| dist_segment(q.x, q.y, a, b) < 0.05 }
        end
        next unless ok
        f.material = mat; f.back_material = mat
        n += 1
      end
      n
    end

    # Prisme : de la ligne brisée jusqu'à une ligne lointaine côté spectateur, sur toute la hauteur du modèle
    def self.prisme(model, pts, dir)
      bb = model.bounds
      long = bb.diagonal * 2 + 1000
      zb = bb.min.z - 100.cm; zh = bb.max.z + 100.cm
      v = dir.clone; v.z = 0; v.normalize!
      poly = pts.map { |p| Geom::Point3d.new(p.x, p.y, zb) }
      poly << poly.last.offset(v, -long)
      poly << poly[0].offset(v, -long)
      g = model.entities.add_group
      f = g.entities.add_face(poly)
      raise 'La ligne brisée se recoupe : tracez-la sans croisement.' unless f && f.valid?
      f.reverse! if f.normal.z < 0
      f.pushpull(zh - zb)
      g
    end

    def self.derriere?(pts, dir, c)
      # le centre est du côté du modèle (sens du regard) de la ligne brisée ?
      v = dir.clone; v.z = 0; v.normalize!
      best = nil
      pts.each_cons(2) do |a, b|
        d = dist_segment(c.x, c.y, [a.x, a.y], [b.x, b.y])
        best = [d, a, b] if best.nil? || d < best[0]
      end
      _, a, b = best
      s = b - a; s.z = 0
      nrm = Z_AXIS.cross(s)
      nrm.reverse! if nrm.dot(v) < 0           # nrm : côté du modèle
      (c - a).dot(nrm) >= 0
    end

    def self.creer(pts, dir, reg, nom = nil)
      model = Sketchup.active_model
      return UI.messagebox('Le modèle est vide.') if model.bounds.empty?
      reg ||= {}
      nom ||= nom_suivant(model)
      pts = pts.map { |p| Geom::Point3d.new(p.x, p.y, 0) }
      dir = dir.clone; dir.z = 0; dir.normalize!
      model.start_operation("Coupe brisée #{nom}", true)
      begin
        anciens = groupe(model, nom)
        anciens.erase! if anciens
        src = sources(model)
        p0 = prisme(model, pts, dir)
        mat = noir(model)
        garde = []; ignores = []
        src.each do |s|
          c = s.copy
          ok = false
          if (s.is_a?(Sketchup::Group) || s.is_a?(Sketchup::ComponentInstance)) && (s.manifold? rescue false)
            p1 = p0.copy
            res = A2M::Ouvertures.inverse? ? c.subtract(p1) : p1.subtract(c)
            if res
              ok = true
              res.name = s.name; res.layer = s.layer
              poche(res, pts, mat)
              garde << res
            else
              p1.erase! if p1.valid?
            end
          end
          unless ok
            if derriere?(pts, dir, s.bounds.center)
              garde << c
              ignores << s.name unless s.name.to_s.empty?
            else
              c.erase! if c.valid?
            end
          end
        end
        p0.erase!
        raise 'Rien à couper : aucun ouvrage visible.' if garde.empty?
        g = model.entities.add_group(garde)
        g.name = PREFIXE + nom
        g.layer = A2M::Coupes.tag_prive(model, nom)
        g.set_attribute('a2m', ATTR, JSON.generate('pts' => pts.map { |p| [p.x.to_f, p.y.to_f] }, 'dir' => dir.to_a.map(&:to_f), 'sources' => src.size))
        a = pts.first; b = pts.last
        u = b - a; u.z = 0; u.normalize!
        A2M::Coupes.habiller(model, nom, a, b, dir, u, reg, pts)
        scene(model, nom, g, src, dir, reg)
        model.commit_operation
        Sketchup.status_text = "Coupe brisée #{nom} créée (scène « A2M – Coupe #{nom} »)." + (ignores.any? ? " Éléments non solides gardés entiers : #{ignores.first(4).join(', ')}" : '')
        A2M::Coupes.majliste
        g
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Coupe brisée impossible : #{ex.message}")
        nil
      end
    end

    def self.scene(model, nom, g, src, dir, reg)
      model.entities.active_section_plane = nil rescue nil
      ro = model.rendering_options
      ro['DisplaySectionPlanes'] = false rescue nil
      ro['RenderMode'] = 2 rescue nil
      ro['EdgeDisplayMode'] = true rescue nil
      model.shadow_info['DisplayShadows'] = false rescue nil
      tag = A2M::Coupes.tag_prive(model, nom)
      tag.visible = true
      bb = model.bounds
      view = model.active_view
      marge = reg['marge'].to_f
      c = bb.center
      # les originaux sont cachés le temps de cadrer la caméra
      src.each { |s| s.visible = false if s.valid? }
      eye = c.offset(dir, -(bb.diagonal * 1.5 + 500))
      cam = Sketchup::Camera.new(eye, c, Z_AXIS); cam.perspective = false
      view.camera = cam
      view.zoom_extents
      if marge > 0 then c2 = view.camera; c2.height = c2.height * (1 + marge / 100.0) rescue nil; view.camera = c2 end
      nomp = "A2M – Coupe #{nom}"
      page = model.pages[nomp] || model.pages.add(nomp)
      page.update
      page3 = nil
      if reg['paire'] != false
        side = Z_AXIS.cross(dir); side.normalize!
        v = Geom::Vector3d.new(dir.x * 0.8 + side.x * 0.6, dir.y * 0.8 + side.y * 0.6, -0.55); v.normalize!
        cam3 = Sketchup::Camera.new(c.offset(v, -(bb.diagonal * 1.6 + 500)), c, Z_AXIS); cam3.perspective = true
        view.camera = cam3; view.zoom_extents
        page3 = model.pages["#{nomp} 3D"] || model.pages.add("#{nomp} 3D")
        page3.update
      end
      src.each { |s| s.visible = true if s.valid? }
      src.each { |s| s.set_attribute('a2m', 'cache_par', nom) if s.valid? }
      mes = [page, page3].compact
      model.pages.each do |p|
        mine = mes.include?(p)
        p.set_visibility(tag, mine) rescue nil
        # les originaux sont cachés dans les scènes de cette coupe, et explicitement visibles dans toutes les autres
        src.each { |s| p.set_drawingelement_visibility(s, !mine) if s.valid? }
      end
      model.pages.selected_page = page rescue nil
    end

    def self.action(r, g)
      model = Sketchup.active_model
      nom = r['nom'].to_s
      d = donnees(g) or return
      reg = r['reg'] || {}
      case r['a']
      when 'sup'
        model.start_operation('Supprimer la coupe brisée', true)
        model.entities.each { |x| (x.set_attribute('a2m', 'cache_par', nil); x.visible = true) if x.valid? && x.respond_to?(:visible=) && x.get_attribute('a2m', 'cache_par') == nom }
        g.erase!
        model.entities.grep(Sketchup::Group).each { |x| x.erase! if x.valid? && ["Cotes coupe #{nom}", "Repère coupe #{nom}"].include?(x.name) }
        ["A2M – Coupe #{nom}", "A2M – Coupe #{nom} 3D"].each { |np| pg = model.pages[np]; model.pages.erase(pg) if pg }
        model.commit_operation
      when 'inv'
        creer(d['pts'].map { |p| Geom::Point3d.new(p[0], p[1], 0) }, Geom::Vector3d.new(*d['dir']).reverse, reg, nom)
        return
      when 'maj'
        creer(d['pts'].map { |p| Geom::Point3d.new(p[0], p[1], 0) }, Geom::Vector3d.new(*d['dir']), reg, nom)
        return
      when 'voir'
        pg = model.pages["A2M – Coupe #{nom}"]
        model.pages.selected_page = pg if pg
      end
      A2M::Coupes.majliste
    end
  end
end
