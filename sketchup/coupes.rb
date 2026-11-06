# encoding: UTF-8
# Métré Atelier 2M : coupes automatiques (ligne de coupe tracée en 2 clics, scène, niveaux et cotes de hauteur, repère sur le plan)
require 'sketchup.rb'
require 'json'

module A2M
  module Coupes
    PREFIXE = 'A2M Coupe '
    TAG_COTES = 'A2M_COTES'

    CORPS = <<~'HTML'
      <h2>Votre plan, tel que dessiné</h2>
      <div class="petit">Le plan ci-dessous est la tranche réelle de votre modèle à <span id="hcut">1,20</span> m du sol. Glissez une ligne pour la déplacer, la flèche change le sens de vue.</div>
      <div class="puces" id="barre"></div>
      <div id="miniplan" style="background:#fff;border:1px solid #ddd;border-radius:10px;margin:6px 0;touch-action:none"><svg id="svg" width="100%" height="300" style="display:block"></svg></div>
      <div class="puces" id="presets"></div>
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
      var reg = { cotes: true, niveaux: true, poche: true, repere: true, paire: true, marge: 10 };
      function rendre() {
        var a = el('auto'); a.innerHTML = '';
        [['long', 'Coupe longitudinale', 'dans le sens de la plus grande longueur'], ['trans', 'Coupe transversale', 'dans le sens de la plus petite largeur']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte';
          b.innerHTML = '<div class="vignette"><svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1"><rect x="8" y="8" width="32" height="24" fill="#fff"/><path d="' + (x[0] === 'long' ? 'M4 20 H44' : 'M24 4 V36') + '" stroke="#E07838" stroke-dasharray="4 2"/></svg></div><span></span><div class="petit" style="margin:2px 0 0"></div>';
          b.querySelector('span').textContent = x[1]; b.querySelector('.petit').textContent = x[2];
          b.addEventListener('click', function () { sketchup.auto(JSON.stringify({ sens: x[0], reg: reg })); }); a.appendChild(b);
        });
        var r = el('regl'); r.innerHTML = '';
        [['cotes', 'Cotes de hauteur'], ['niveaux', 'Niveaux et altitudes'], ['poche', 'Murs coupés en poché noir'], ['repere', 'Repère sur le plan'], ['paire', 'Scène 2D + scène 3D jumelle']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (reg[x[0]] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { reg[x[0]] = !reg[x[0]]; rendre(); if (ZONE) dessiner(); }); r.appendChild(b);
        });
        [0, 10, 20].forEach(function (m) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (reg.marge === m ? ' rempli' : ''); b.textContent = 'Marge ' + m + ' %';
          b.addEventListener('click', function () { reg.marge = m; rendre(); }); r.appendChild(b);
        });
        var l = el('liste'); l.innerHTML = '';
        if (!D.coupes.length) { l.innerHTML = '<div class="petit">Aucune coupe pour le moment.</div>'; }
        D.coupes.forEach(function (c) {
          var d = document.createElement('div'); d.className = 'ligne'; d.style.cssText = 'display:flex;gap:6px;align-items:center;margin:4px 0';
          var s = document.createElement('span'); s.style.flex = '1'; s.textContent = 'Coupe ' + c.nom; d.appendChild(s);
          [['maj', 'Actualiser'], ['inv', 'Inverser'], ['voir', 'Voir'], ['sup', 'Supprimer']].forEach(function (x) {
            var b = document.createElement('button'); b.type = 'button'; b.className = 'puce'; b.textContent = x[1];
            b.addEventListener('click', function () { sketchup.action(JSON.stringify({ a: x[0], nom: c.nom, reg: reg })); }); d.appendChild(b);
          });
          l.appendChild(d);
        });
      }
      function maj(liste) { D.coupes = liste; rendre(); }
      el('trace').addEventListener('click', function () { sketchup.tracer(JSON.stringify({ reg: reg })); });
      rendre();

      var svg = el('svg'), NS = 'http://www.w3.org/2000/svg', L = [], ZONE = null, BB = D.plan.bb;
      function e(n, a, p) { var x = document.createElementNS(NS, n); for (var k in a) x.setAttribute(k, a[k]); if (p) p.appendChild(x); return x; }
      function viewbox() {
        var m = Math.max(BB[2] - BB[0], BB[3] - BB[1]) * 0.18 + 60;
        ZONE = [BB[0] - m, BB[1] - m, BB[2] - BB[0] + 2 * m, BB[3] - BB[1] + 2 * m];
        svg.setAttribute('viewBox', ZONE.join(' '));
      }
      function aPartirDe(c) {
        var h = Math.abs(c.dir[1]) >= Math.abs(c.dir[0]);
        return { nom: c.nom, t: h ? 'R' : 'V', pos: h ? -c.a[1] : c.a[0], dir: h ? (c.dir[1] > 0 ? 1 : -1) : (c.dir[0] > 0 ? 1 : -1) };
      }
      function monde(l) {
        var x0 = BB[0] - 50, x1 = BB[2] + 50, y0 = BB[1] - 50, y1 = BB[3] + 50;   // y en repère écran (déjà inversé)
        if (l.t === 'R') return { a: [x0, -l.pos], b: [x1, -l.pos], dir: [0, l.dir] };
        return { a: [l.pos, -y1], b: [l.pos, -y0], dir: [l.dir, 0] };
      }
      function trace(d, f, cls, st, p) { var q = e('path', { d: d, fill: f ? st.fill : 'none', 'fill-rule': 'evenodd', stroke: st.stroke, 'stroke-width': st.w, 'vector-effect': 'non-scaling-stroke', 'stroke-linejoin': 'round' }, p); return q; }
      function dessiner() {
        viewbox(); svg.innerHTML = '';
        var g = e('g', {}, svg);
        D.plan.pieces.forEach(function (d) { e('path', { d: d, fill: '#F4EFE8', stroke: 'none' }, g); });
        D.plan.autres.forEach(function (o) { trace(o.d, o.f, 0, { fill: '#E6E6E6', stroke: '#777', w: 1 }, g); });
        D.plan.murs.forEach(function (o) { trace(o.d, o.f, 0, { fill: reg.poche ? '#141414' : '#BDBDBD', stroke: '#000', w: 1 }, g); });
        D.plan.ouv.forEach(function (o) { trace(o.d, o.f, 0, { fill: '#FFFFFF', stroke: '#333', w: 1 }, g); });
        var k = ZONE[2] / 400;
        L.forEach(function (l) {
          var col = l.t === 'R' ? '#B3302F' : '#2E8B6A', h = l.t === 'R';
          var grp = e('g', { style: 'cursor:' + (h ? 'ns-resize' : 'ew-resize') }, svg);
          var x1 = h ? BB[0] - 50 : l.pos, x2 = h ? BB[2] + 50 : l.pos, y1 = h ? l.pos : BB[1] - 50, y2 = h ? l.pos : BB[3] + 50;
          e('line', { x1: x1, y1: y1, x2: x2, y2: y2, stroke: col, 'stroke-width': 2, 'stroke-dasharray': l.actif ? '' : '8 5', 'vector-effect': 'non-scaling-stroke' }, grp);
          e('line', { x1: x1, y1: y1, x2: x2, y2: y2, stroke: 'transparent', 'stroke-width': 16, 'vector-effect': 'non-scaling-stroke' }, grp);
          var bx = h ? x1 : x1, by = h ? y1 : y2;
          var bw = 46 * k, bh = 20 * k;
          var tx = h ? x1 - bw * 0.2 : x1 - bw / 2, ty = h ? y1 - bh / 2 : y1 - bh * 1.25;
          var r = e('rect', { x: tx, y: ty, width: bw, height: bh, rx: 6 * k, fill: '#fff', stroke: col, 'stroke-width': 1.5, 'vector-effect': 'non-scaling-stroke' }, grp);
          var t = e('text', { x: tx + bw / 2, y: ty + bh * 0.72, 'text-anchor': 'middle', 'font-size': 13 * k, fill: col, 'font-weight': 700, 'font-family': 'Segoe UI,Arial' }, grp); t.textContent = l.nom;
          // flèche de sens de vue au milieu de la ligne
          var mx = h ? (x1 + x2) / 2 : x1, my = h ? y1 : (y1 + y2) / 2, s = 14 * k;
          var f = h ? [0, -l.dir * -1] : [l.dir, 0];   // sens écran : R dir +1 = vers le haut (y écran négatif)
          var vx = h ? 0 : l.dir, vy = h ? -l.dir : 0;
          var a = e('g', { style: 'cursor:pointer' }, grp);
          e('circle', { cx: mx + vx * s * 1.4, cy: my + vy * s * 1.4, r: s, fill: '#fff', stroke: col, 'stroke-width': 1.5, 'vector-effect': 'non-scaling-stroke' }, a);
          e('path', { d: 'M' + (mx + vx * s * 0.8 - vy * s * 0.5) + ' ' + (my + vy * s * 0.8 + vx * s * 0.5) + ' L' + (mx + vx * s * 2.0) + ' ' + (my + vy * s * 2.0) + ' L' + (mx + vx * s * 0.8 + vy * s * 0.5) + ' ' + (my + vy * s * 0.8 - vx * s * 0.5), fill: 'none', stroke: col, 'stroke-width': 2, 'vector-effect': 'non-scaling-stroke' }, a);
          a.addEventListener('pointerdown', function (ev) { ev.stopPropagation(); l.dir = -l.dir; appliquer(l); dessiner(); });
          var sup = e('g', { style: 'cursor:pointer' }, grp);
          var sx = h ? x2 - 10 * k : x1 + 14 * k, sy = h ? y1 - 14 * k : y2 - 10 * k;
          e('circle', { cx: sx, cy: sy, r: 8 * k, fill: '#fff', stroke: '#999', 'stroke-width': 1, 'vector-effect': 'non-scaling-stroke' }, sup);
          var tt = e('text', { x: sx, y: sy + 4.5 * k, 'text-anchor': 'middle', 'font-size': 12 * k, fill: '#777', 'font-family': 'Segoe UI,Arial' }, sup); tt.textContent = '×';
          sup.addEventListener('pointerdown', function (ev) { ev.stopPropagation(); retirer(l); });
          grp.addEventListener('pointerdown', function (ev) { debut(ev, l); });
        });
      }
      function pt(ev) { var p = svg.createSVGPoint(); p.x = ev.clientX; p.y = ev.clientY; return p.matrixTransform(svg.getScreenCTM().inverse()); }
      var cur = null;
      function debut(ev, l) { cur = l; svg.setPointerCapture(ev.pointerId); ev.preventDefault(); }
      svg.addEventListener('pointermove', function (ev) { if (!cur) return; var p = pt(ev); cur.pos = Math.round(cur.t === 'R' ? p.y : p.x); dessiner(); });
      svg.addEventListener('pointerup', function () { if (!cur) return; var l = cur; cur = null; appliquer(l); });
      function appliquer(l) { l.actif = true; var m = monde(l); sketchup.appliquer(JSON.stringify({ nom: l.nom, a: m.a, b: m.b, dir: m.dir, reg: reg })); }
      function retirer(l) { L = L.filter(function (x) { return x !== l; }); sketchup.action(JSON.stringify({ a: 'sup', nom: l.nom, reg: reg })); dessiner(); }
      function nomLibre(t) { var i = 1; while (L.some(function (x) { return x.nom === t + i; })) i++; return t + i; }
      function ajouter(t) {
        var c = [(BB[0] + BB[2]) / 2, (BB[1] + BB[3]) / 2];
        var l = { nom: nomLibre(t), t: t, pos: Math.round(t === 'R' ? c[1] : c[0]), dir: 1, actif: false };
        L.push(l); dessiner(); appliquer(l); dessiner();
      }
      function preset(n) {
        L.slice().forEach(function (x) { sketchup.action(JSON.stringify({ a: 'sup', nom: x.nom, reg: reg })); }); L = [];
        var w = BB[2] - BB[0], h = BB[3] - BB[1], nr = Math.round(n / 2), nv = n - nr;
        for (var i = 1; i <= nr; i++) L.push({ nom: 'R' + i, t: 'R', pos: Math.round(BB[1] + h * i / (nr + 1)), dir: 1, actif: false });
        for (var j = 1; j <= nv; j++) L.push({ nom: 'V' + j, t: 'V', pos: Math.round(BB[0] + w * j / (nv + 1)), dir: 1, actif: false });
        dessiner(); L.forEach(function (x) { appliquer(x); }); dessiner();
      }
      (function () {
        el('hcut').textContent = (D.plan.cut / 100).toFixed(2).replace('.', ',');
        L = D.coupes.map(function (c) { var l = aPartirDe(c); l.actif = true; return l; });
        var b = el('barre');
        [['R', '+ Coupe rouge (—)'], ['V', '+ Coupe verte (|)']].forEach(function (x) {
          var q = document.createElement('button'); q.type = 'button'; q.className = 'puce rempli'; q.textContent = x[1];
          q.addEventListener('click', function () { ajouter(x[0]); }); b.appendChild(q);
        });
        var pr = el('presets'); var lab = document.createElement('span'); lab.className = 'petit'; lab.textContent = 'Poser d\'un coup :'; lab.style.marginRight = '6px'; pr.appendChild(lab);
        [4, 6, 10].forEach(function (n) { var q = document.createElement('button'); q.type = 'button'; q.className = 'puce'; q.textContent = n + ' coupes'; q.addEventListener('click', function () { preset(n); }); pr.appendChild(q); });
        dessiner();
      })();
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
      marge = reg['marge'].to_f
      if marge > 0
        c2 = view.camera
        c2.height = c2.height * (1 + marge / 100.0) rescue nil
        view.camera = c2
      end
      nomp = "A2M – Coupe #{nom}"
      page = model.pages[nomp] || model.pages.add(nomp)
      page.update
      page3 = nil
      if reg['paire'] != false
        # scène jumelle en 3D : même coupe vue de trois quarts, en perspective
        side = Z_AXIS.cross(dir); side.normalize!
        v = Geom::Vector3d.new(dir.x * 0.8 + side.x * 0.6, dir.y * 0.8 + side.y * 0.6, -0.55)
        v.normalize!
        eye3 = c.offset(v, -(bb.diagonal * 1.6 + 500))
        cam3 = Sketchup::Camera.new(eye3, c, Z_AXIS)
        cam3.perspective = true
        view.camera = cam3
        view.zoom_extents
        page3 = model.pages["#{nomp} 3D"] || model.pages.add("#{nomp} 3D")
        page3.update
        view.camera = cam
        c2 = view.camera
        view.zoom_extents
        if marge > 0 then c2 = view.camera; c2.height = c2.height * (1 + marge / 100.0) rescue nil; view.camera = c2 end
      else
        model.pages.erase(model.pages["#{nomp} 3D"]) if model.pages["#{nomp} 3D"]
      end
      model.pages.each do |p|
        if p == page || p == page3 then p.set_visibility(tag, true) rescue nil
        elsif p.name =~ /Plan 2D/ then p.set_visibility(tag, false) rescue nil
        else p.set_visibility(tag, false) rescue nil
        end
      end
      model.pages.each { |p| p.set_visibility(model.layers[A2M::Plan2D::TAG], true) if p.name =~ /Plan 2D/ && model.layers[A2M::Plan2D::TAG] } rescue nil
      model.pages.selected_page = page rescue nil
    end

    # Mise à jour silencieuse des cotes et repères de toutes les coupes
    def self.rafraichir
      model = Sketchup.active_model
      model.entities.grep(Sketchup::SectionPlane).each do |sp|
        next unless sp.name.start_with?(PREFIXE)
        d = lire(sp) or next
        nom = sp.name.sub(PREFIXE, '')
        dir = Geom::Vector3d.new(*d['dir'])
        a = Geom::Point3d.new(*d['a']); b = Geom::Point3d.new(*d['b'])
        u = b - a; u.z = 0; u.normalize!
        habiller(model, nom, a, b, dir, u, {})
      end
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
        ["A2M – Coupe #{nom}", "A2M – Coupe #{nom} 3D"].each { |np| pg = model.pages[np]; model.pages.erase(pg) if pg }
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

    # Lignes de coupe existantes (cm, y en repère modèle)
    def self.lignes(model)
      model.entities.grep(Sketchup::SectionPlane).select { |s| s.name.start_with?(PREFIXE) }.map do |sp|
        d = lire(sp) or next
        { 'nom' => sp.name.sub(PREFIXE, ''), 'a' => d['a'][0, 2].map { |v| (v * 2.54).round(1) }, 'b' => d['b'][0, 2].map { |v| (v * 2.54).round(1) }, 'dir' => d['dir'][0, 2] }
      end.compact
    end

    # Ligne venue du mini-plan (cm) : crée ou met à jour la coupe
    def self.appliquer(r)
      return unless r
      a = Geom::Point3d.new(r['a'][0].to_f / 2.54, r['a'][1].to_f / 2.54, 0)
      b = Geom::Point3d.new(r['b'][0].to_f / 2.54, r['b'][1].to_f / 2.54, 0)
      dir = Geom::Vector3d.new(r['dir'][0].to_f, r['dir'][1].to_f, 0)
      creer(a, b, dir, r['reg'] || {}, r['nom'].to_s)
    end

    def self.majliste
      return unless @fen && (@fen.visible? rescue false)
      @fen.execute_script("maj(#{JSON.generate(lignes(Sketchup.active_model))})")
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      html = A2M::Panneau.page('Coupes automatiques', 'Une ligne de coupe, une scène, les niveaux et les cotes de hauteur',
                               CORPS, SCRIPT, 'coupes' => lignes(Sketchup.active_model), 'plan' => A2M::MiniPlan.donnees(120.0))
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : coupes', 'A2M_Panneau_Coupes', html, 470, 820)
      @fen = dlg
      dlg.add_action_callback('auto') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) { auto(r['sens'], r['reg'] || {}) } if r
      end
      dlg.add_action_callback('tracer') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil) || {}
        UI.start_timer(0, false) { Sketchup.active_model.select_tool(Outil.new(r['reg'] || {})) }
      end
      dlg.add_action_callback('appliquer') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) { appliquer(r) } if r
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
