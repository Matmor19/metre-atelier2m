# encoding: UTF-8
# Métré Atelier 2M : coupes automatiques (ligne de coupe tracée en 2 clics, scène, niveaux et cotes de hauteur, repère sur le plan)
require 'sketchup.rb'
require 'json'

module A2M
  module Coupes
    PREFIXE = 'A2M Coupe '
    TAG_COTES = 'A2M_COTES'

    CORPS = <<~'HTML'
      <h2>Proposition en un clic</h2>
      <div class="grille" id="auto"></div>
      <div class="petit">Passe par le milieu du bâtiment. Vous pouvez ensuite déplacer le plan de coupe avec l'outil Déplacer de SketchUp, puis cliquer « Actualiser ».</div>
      <h2>Ou tracez votre coupe</h2>
      <button type="button" class="puce rempli" id="trace">Tracer une coupe (2 clics + 1 clic pour le sens de vue)</button>
      <h2>Réglages</h2>
      <div class="puces" id="regl"></div>
      <h2>Coupes du modèle</h2>
      <div id="liste"></div>
      <div id="bas"><div id="msg"></div></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      var reg = { cotes: true, niveaux: true, poche: true, repere: true };
      function rendre() {
        var a = el('auto'); a.innerHTML = '';
        [['long', 'Coupe longitudinale', 'dans le sens de la plus grande longueur'], ['trans', 'Coupe transversale', 'dans le sens de la plus petite largeur']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte';
          b.innerHTML = '<div class="vignette"><svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1"><rect x="8" y="8" width="32" height="24" fill="#fff"/><path d="' + (x[0] === 'long' ? 'M4 20 H44' : 'M24 4 V36') + '" stroke="#E07838" stroke-dasharray="4 2"/></svg></div><span></span><div class="petit" style="margin:2px 0 0"></div>';
          b.querySelector('span').textContent = x[1]; b.querySelector('.petit').textContent = x[2];
          b.addEventListener('click', function () { sketchup.auto(JSON.stringify({ sens: x[0], reg: reg })); }); a.appendChild(b);
        });
        var r = el('regl'); r.innerHTML = '';
        [['cotes', 'Cotes de hauteur'], ['niveaux', 'Niveaux et altitudes'], ['poche', 'Murs coupés en poché'], ['repere', 'Repère sur le plan']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (reg[x[0]] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { reg[x[0]] = !reg[x[0]]; rendre(); }); r.appendChild(b);
        });
        var l = el('liste'); l.innerHTML = '';
        if (!D.coupes.length) { l.innerHTML = '<div class="petit">Aucune coupe pour le moment.</div>'; }
        D.coupes.forEach(function (c) {
          var d = document.createElement('div'); d.className = 'ligne'; d.style.cssText = 'display:flex;gap:6px;align-items:center;margin:4px 0';
          var s = document.createElement('span'); s.style.flex = '1'; s.textContent = 'Coupe ' + c; d.appendChild(s);
          [['maj', 'Actualiser'], ['inv', 'Inverser'], ['voir', 'Voir'], ['sup', 'Supprimer']].forEach(function (x) {
            var b = document.createElement('button'); b.type = 'button'; b.className = 'puce'; b.textContent = x[1];
            b.addEventListener('click', function () { sketchup.action(JSON.stringify({ a: x[0], nom: c, reg: reg })); }); d.appendChild(b);
          });
          l.appendChild(d);
        });
      }
      function maj(liste) { D.coupes = liste; rendre(); }
      el('trace').addEventListener('click', function () { sketchup.tracer(JSON.stringify({ reg: reg })); });
      rendre();
    JS

    # ---- Outil : 2 clics pour la ligne, 1 clic pour le côté d'où l'on regarde ----
    class Outil
      def initialize(reg) @reg = reg; @pts = []; @ip = Sketchup::InputPoint.new; @souris = nil end
      def activate; Sketchup.status_text = 'Coupe : cliquez le début de la ligne de coupe' end
      def deactivate(view) view.invalidate end
      def onSetCursor() UI.set_cursor(632) end
      def onMouseMove(_f, x, y, view)
        @ip.pick(view, x, y); @souris = @ip.position; view.invalidate
      end
      def onLButtonDown(_f, x, y, view)
        @ip.pick(view, x, y)
        p = @ip.position.clone; p.z = 0
        @pts << p
        if @pts.size == 1 then Sketchup.status_text = 'Coupe : cliquez la fin de la ligne'
        elsif @pts.size == 2 then Sketchup.status_text = 'Coupe : cliquez du côté d\'où vous voulez regarder'
        else
          a, b, c = @pts
          u = b - a
          n = Z_AXIS.cross(u); n.normalize!
          vers = c - a
          n.reverse! if n.dot(vers) < 0     # n pointe vers le spectateur
          Sketchup.active_model.select_tool(nil)
          UI.start_timer(0, false) { A2M::Coupes.creer(a, b, n.reverse, @reg) }   # direction de regard = vers le modèle
        end
        view.invalidate
      end
      def draw(view)
        m = @souris or return
        a = @pts[0]
        return unless a
        view.drawing_color = Sketchup::Color.new(224, 120, 56)
        view.line_width = 2
        view.line_stipple = '-'
        if @pts.size == 1 then view.draw_lines(a, m)
        elsif @pts.size == 2 then view.draw_lines(@pts[0], @pts[1])
        end
      end
    end

    def self.nombre(v, d) (Float(v.to_s.tr(',', '.')) rescue d) end

    def self.noms(model)
      model.entities.grep(Sketchup::SectionPlane).map(&:name).select { |n| n.start_with?(PREFIXE) }.map { |n| n.sub(PREFIXE, '') }.sort
    end

    def self.nom_suivant(model)
      ('A'..'Z').find { |l| !noms(model).include?(l) } || "X#{noms(model).size + 1}"
    end

    def self.plan_de(model, nom) model.entities.grep(Sketchup::SectionPlane).find { |s| s.name == PREFIXE + nom } end

    # Niveaux utiles lus dans le modèle (altitudes en pouces) : sol, planchers, plafonds, point haut
    def self.niveaux(model)
      zs = {}
      sol = nil
      A2M::Plan2D.parcourir(model.entities, Geom::Transformation.new) do |e, t|
        cs = A2M::Plan2D.coins(e, t)
        case e.layer.name
        when 'A2M_PIECE' then z = cs.map(&:z).min; sol = sol ? [sol, z].min : z
        when 'A2M_PLANCHER_ETAGE' then zs["Plancher étage"] = cs.map(&:z).max
        when 'A2M_PLAFOND' then zs["Plafond"] = cs.map(&:z).min
        end
      end
      sol ||= model.bounds.min.z
      haut = model.bounds.max.z
      liste = [['Sol fini', sol]]
      zs.each { |k, z| liste << [k, z] }
      liste << ['Point haut', haut]
      liste.sort_by { |_, z| z }.uniq { |_, z| z.round(2) }
    end

    def self.cm_txt(z, sol) format('%+.2f m', (z - sol).to_f * 0.0254).tr('.', ',') end

    def self.tag_prive(model, nom)
      model.layers["#{TAG_COTES}_#{nom}"] || model.layers.add("#{TAG_COTES}_#{nom}")
    end

    def self.creer(a, b, dir, reg, nom = nil)
      model = Sketchup.active_model
      return UI.messagebox('Le modèle est vide.') if model.bounds.empty?
      reg ||= {}
      nom ||= nom_suivant(model)
      dir = dir.clone; dir.z = 0; dir.normalize!
      model.start_operation("Coupe #{nom}", true)
      begin
        u = b - a; u.z = 0
        return UI.messagebox('La ligne de coupe est trop courte.') if u.length < 1.cm
        u.normalize!
        mil = Geom::Point3d.new((a.x + b.x) / 2, (a.y + b.y) / 2, 0)
        model.entities.grep(Sketchup::SectionPlane).each { |s| s.erase! if s.name == PREFIXE + nom }
        sp = model.entities.add_section_plane([mil.x, mil.y, model.bounds.center.z], [dir.x, dir.y, dir.z])
        sp.name = PREFIXE + nom
        sp.activate
        sp.set_attribute('a2m', 'coupe', JSON.generate('a' => a.to_a, 'b' => b.to_a, 'dir' => dir.to_a))
        habiller(model, nom, a, b, dir, u, reg)
        mettre_a_jour_scene(model, nom, sp, dir, reg)
        model.commit_operation
        Sketchup.status_text = "Coupe #{nom} créée (scène « A2M – Coupe #{nom} »)."
        majliste
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Coupe impossible : #{ex.message}")
      end
    end

    # Cotes de hauteur, niveaux et repère sur le plan
    def self.habiller(model, nom, a, b, dir, u, reg)
      model.entities.grep(Sketchup::Group).each { |g| g.erase! if g.valid? && g.name == "Cotes coupe #{nom}" }
      model.entities.grep(Sketchup::Group).each { |g| g.erase! if g.valid? && g.name == "Repère coupe #{nom}" }
      bb = model.bounds
      tag = tag_prive(model, nom)
      niv = niveaux(model)
      sol = niv.first[1]
      g = model.entities.add_group
      g.name = "Cotes coupe #{nom}"
      g.layer = tag
      ents = g.entities
      # Cotes placées à gauche du bâtiment dans la vue : à gauche = -(u) vu depuis le regard dir
      gauche = Z_AXIS.cross(dir); gauche.normalize!
      etendue = [a, b].map { |p| p.to_a }.flatten
      coin = [bb.min, bb.max].map { |p| (p - a).dot(gauche) }.max
      x0 = a.offset(gauche, coin + 80.cm)
      pts_cote = niv.map { |_, z| Geom::Point3d.new(x0.x, x0.y, z) }
      if reg['cotes'] != false
        (0...pts_cote.size - 1).each do |i|
          next if (pts_cote[i + 1].z - pts_cote[i].z).abs < 2.cm
          d = ents.add_dimension_linear(pts_cote[i], pts_cote[i + 1], gauche.clone.tap { |v| v.length = 25.cm })
          d.layer = tag rescue nil
        end
        if pts_cote.size > 2
          d = ents.add_dimension_linear(pts_cote.first, pts_cote.last, gauche.clone.tap { |v| v.length = 60.cm })
        end
      end
      if reg['niveaux'] != false
        niv.each do |lib, z|
          p0 = Geom::Point3d.new(x0.x, x0.y, z)
          ents.add_line(p0.offset(gauche, -30.cm), p0.offset(gauche, 70.cm))
          ents.add_text("#{lib} #{cm_txt(z, sol)}", p0.offset(gauche, 95.cm))
        end
      end
      ents.grep(Sketchup::Text).each { |t| t.layer = tag }
      ents.grep(Sketchup::Edge).each { |e| e.layer = tag }
      # repère sur le plan : trait, lettres aux deux extrémités, flèche du sens de vue
      if reg['repere'] != false
        tp = model.layers[A2M::Plan2D::TAG] || model.layers.add(A2M::Plan2D::TAG)
        r = model.entities.add_group
        r.name = "Repère coupe #{nom}"
        r.layer = tp
        z = [bb.min.z, niveaux(model).first[1]].max + 119.cm
        a2 = a.offset(u, -40.cm); b2 = b.offset(u, 40.cm)
        a2.z = b2.z = z
        r.entities.add_line(a2, b2)
        [a2, b2].each do |p|
          r.entities.add_line(p, p.offset(dir, 60.cm))
          r.entities.add_line(p.offset(dir, 60.cm), p.offset(dir, 45.cm).offset(u, p == a2 ? 12.cm : -12.cm))
          r.entities.add_line(p.offset(dir, 60.cm), p.offset(dir, 45.cm).offset(u, p == a2 ? -12.cm : 12.cm))
          r.entities.add_text(nom, p.offset(dir, 90.cm))
        end
        r.entities.grep(Sketchup::Text).each { |t| t.layer = tp }
      end
    end

    # Caméra parallèle face à la coupe + scène ; les cotes de cette coupe ne sont visibles que dans sa scène
    def self.mettre_a_jour_scene(model, nom, sp, dir, reg)
      bb = model.bounds
      c = bb.center
      tag = tag_prive(model, nom)
      ro = model.rendering_options
      ro['DisplaySectionPlanes'] = false rescue nil
      ro['DisplaySectionCuts'] = true rescue nil
      ro['SectionCutWidth'] = 4 rescue nil
      ro['SectionDefaultFillColor'] = (reg['poche'] != false ? Sketchup::Color.new(20, 20, 20) : Sketchup::Color.new(200, 200, 200)) rescue nil
      ro['RenderMode'] = 2 rescue nil
      ro['EdgeDisplayMode'] = true rescue nil
      model.shadow_info['DisplayShadows'] = false rescue nil
      sp.activate
      tag.visible = true
      view = model.active_view
      eye = c.offset(dir, -(bb.diagonal * 1.5 + 500))
      cam = Sketchup::Camera.new(eye, c, Z_AXIS)
      cam.perspective = false
      view.camera = cam
      view.zoom_extents
      nomp = "A2M – Coupe #{nom}"
      page = model.pages[nomp] || model.pages.add(nomp)
      page.update
      model.pages.each do |p|
        if p == page then p.set_visibility(tag, true) rescue nil
        elsif p.name =~ /Plan 2D/ then p.set_visibility(tag, false) rescue nil
        else p.set_visibility(tag, false) rescue nil
        end
      end
      model.pages.each { |p| p.set_visibility(model.layers[A2M::Plan2D::TAG], true) if p.name =~ /Plan 2D/ && model.layers[A2M::Plan2D::TAG] } rescue nil
      model.pages.selected_page = page rescue nil
    end

    def self.lire(sp) JSON.parse(sp.get_attribute('a2m', 'coupe').to_s) rescue nil end

    # Coupe automatique au milieu du bâtiment
    def self.auto(sens, reg)
      model = Sketchup.active_model
      bb = model.bounds
      return UI.messagebox('Le modèle est vide.') if bb.empty?
      c = bb.center
      long_x = bb.width >= bb.height
      along_x = (sens == 'long') ? long_x : !long_x
      if along_x
        a = Geom::Point3d.new(bb.min.x - 50.cm, c.y, 0); b = Geom::Point3d.new(bb.max.x + 50.cm, c.y, 0)
        dir = Geom::Vector3d.new(0, 1, 0)
      else
        a = Geom::Point3d.new(c.x, bb.min.y - 50.cm, 0); b = Geom::Point3d.new(c.x, bb.max.y + 50.cm, 0)
        dir = Geom::Vector3d.new(-1, 0, 0)
      end
      creer(a, b, dir, reg)
    end

    def self.action(r)
      model = Sketchup.active_model
      nom = r['nom'].to_s
      sp = plan_de(model, nom)
      return UI.messagebox("La coupe #{nom} n'existe plus.") unless sp
      d = lire(sp) or return
      reg = r['reg'] || {}
      case r['a']
      when 'sup'
        model.start_operation('Supprimer la coupe', true)
        sp.erase!
        model.entities.grep(Sketchup::Group).each { |g| g.erase! if g.valid? && ["Cotes coupe #{nom}", "Repère coupe #{nom}"].include?(g.name) }
        pg = model.pages["A2M – Coupe #{nom}"]
        model.pages.erase(pg) if pg
        model.commit_operation
      when 'inv'
        dir = Geom::Vector3d.new(*d['dir']).reverse
        creer(Geom::Point3d.new(*d['a']), Geom::Point3d.new(*d['b']), dir, reg, nom)
        return
      when 'maj', 'voir'
        # le plan de coupe a pu être déplacé : sa position actuelle devient la ligne de coupe
        pl = sp.get_plane
        n = Geom::Vector3d.new(pl[0], pl[1], pl[2]); n.z = 0; n.normalize!
        dir = n
        u = Z_AXIS.cross(dir); u.normalize!
        mil = Geom::Point3d.new(-pl[3] * pl[0] / (pl[0]**2 + pl[1]**2 + pl[2]**2), -pl[3] * pl[1] / (pl[0]**2 + pl[1]**2 + pl[2]**2), 0)
        long = Geom::Point3d.new(*d['a']).distance(Geom::Point3d.new(*d['b'])) / 2
        a = mil.offset(u, -long); b = mil.offset(u, long)
        if r['a'] == 'voir'
          pg = model.pages["A2M – Coupe #{nom}"]
          model.pages.selected_page = pg if pg
        else
          creer(a, b, dir, reg, nom)
          return
        end
      end
      majliste
    end

    def self.majliste
      return unless @fen && (@fen.visible? rescue false)
      @fen.execute_script("maj(#{JSON.generate(noms(Sketchup.active_model))})")
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      html = A2M::Panneau.page('Coupes automatiques', 'Une ligne de coupe, une scène, les niveaux et les cotes de hauteur',
                               CORPS, SCRIPT, 'coupes' => noms(Sketchup.active_model))
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : coupes', 'A2M_Panneau_Coupes', html, 440, 700)
      @fen = dlg
      dlg.add_action_callback('auto') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) { auto(r['sens'], r['reg'] || {}) } if r
      end
      dlg.add_action_callback('tracer') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil) || {}
        UI.start_timer(0, false) { Sketchup.active_model.select_tool(Outil.new(r['reg'] || {})) }
      end
      dlg.add_action_callback('action') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) { action(r) } if r
      end
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
