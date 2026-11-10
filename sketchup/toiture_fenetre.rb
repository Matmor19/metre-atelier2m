# encoding: UTF-8
# Métré Atelier 2M : fenêtre de la toiture avec vue de dessus et coupe à l'échelle. Tout se règle avec des curseurs :
# la toiture du modèle est refaite en direct. L'ancienne fenêtre de saisie reste disponible (lancer_classique / modifier_classique).
require 'sketchup.rb'
require 'json'

module A2M
  module Toiture
    class << self
      alias_method :lancer_classique, :lancer unless method_defined?(:lancer_classique)
      alias_method :modifier_classique, :modifier unless method_defined?(:modifier_classique)
      def lancer() A2M::ToitureFenetre.lancer end
      def modifier(grp = nil) A2M::ToitureFenetre.modifier(grp) end
    end
  end

  module ToitureFenetre
    CORPS = <<~'HTML'
      <style>
        .champ{display:grid;grid-template-columns:1fr 78px;gap:4px 10px;align-items:center;margin:7px 0}
        .champ label{font-size:11.5px;color:#6f665e;line-height:1.25}
        .champ input[type=range]{grid-column:1 / 3;width:100%;accent-color:#E07838;margin:0}
        .champ input[type=text]{font-size:13px;padding:4px 6px;border-radius:7px}
        .vue{background:#fff;border:1px solid #d8d0c6;border-radius:12px;width:100%;display:block}
        .btn{border:2px solid #d8d0c6;background:#fff;border-radius:10px;padding:8px 14px;cursor:pointer;font:600 12.5px "Segoe UI",Arial,sans-serif;color:#3C3C3C}
        .btn:hover{border-color:#E07838} .btn.fort{background:#E07838;color:#fff;border-color:#E07838}
        .rang{display:flex;gap:8px;align-items:center;margin:8px 0;flex-wrap:wrap}
        .alerte{color:#a8541f;font-size:11.5px;min-height:15px}
        .info{font-size:12px;color:#6f665e;margin:4px 0}
      </style>
      <h2>Vue de dessus</h2>
      <svg id="dessus" class="vue" viewBox="0 0 520 300" style="height:300px"></svg>
      <h2>Coupe</h2>
      <svg id="coupe" class="vue" viewBox="0 0 520 200" style="height:200px"></svg>
      <div class="info" id="info"></div>
      <div class="alerte" id="alerte"></div>
      <h2>Type de toiture</h2>
      <div class="puces" id="types"></div>
      <div id="sens_bloc"><h2>Faîtage parallèle au</h2><div class="puces" id="sens"></div></div>
      <div id="haut_bloc"><h2 id="haut_titre">Monopente : côté haut</h2><div class="puces" id="haut"></div></div>
      <div id="champs"></div>
      <div id="pig_bloc"><div class="rang"><label><input type="checkbox" id="pignons"> Murs pignons (extrémités du faîtage, jusqu'à la toiture)</label></div>
        <div id="pig_opts"><div class="puces" id="pig_type"></div><div class="rang" id="pig_comp_bloc"><select id="pig_comp" style="max-width:100%;padding:6px;border-radius:8px"></select></div></div></div>
      <h2>Toiture n°</h2>
      <div class="puces" id="num"></div>
      <div class="rang"><button type="button" class="btn" id="reprendre">Reprendre le contour sur les murs sélectionnés</button></div>
      <div class="rang"><button type="button" class="btn fort" id="valider">Valider</button><button type="button" class="btn" id="suppr">Supprimer cette toiture</button></div>
      <div class="petit">Faîtages et arêtiers sont posés tout seuls (visuel, hors métré). Pour rouvrir : sélectionnez la toiture, puis « Modifier ce que j'ai dessiné ».</div>
      <div id="bas"><div id="msg"></div></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      var P = null, DATA = null, tmr = null;
      var CH = [['pente', 'Pente (%)', 5, 150, 1], ['d', 'Débord (cm)', 0, 150, 1], ['ep', 'Épaisseur de la toiture (cm)', 0, 40, 0.5], ['pig_ep', 'Épaisseur des murs pignons (cm)', 10, 40, 1]];
      function envoyer() { clearTimeout(tmr); tmr = setTimeout(function () { sketchup.maj(JSON.stringify(P)); }, 90); }
      function puces(id, liste, cle, aff) {
        var z = el(id); z.innerHTML = '';
        liste.forEach(function (v) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (P && P[cle] === v ? ' rempli' : ''); b.textContent = aff ? aff(v) : v;
          b.addEventListener('click', function () { P[cle] = v; rendre(); envoyer(); }); z.appendChild(b);
        });
      }
      function rendre() {
        puces('types', D.types, 'type'); puces('sens', ['grand côté', 'petit côté'], 'sens'); puces('haut', D.hauts, 'haut'); puces('num', ['1', '2', '3', '4'], 'num');
        el('sens_bloc').style.display = (P.type === 'Suit les murs') ? 'none' : 'block';
        var pg = (P.type === '2 pans' || P.type === '3 pans' || P.type === 'Monopente'); el('pig_bloc').style.display = pg ? 'block' : 'none'; el('pignons').checked = !!P.pignons; var wp = el('w_pig_ep'); if (wp) wp.style.display = (pg && P.pignons && P.pig_type !== 'compose') ? 'grid' : 'none'; el('pig_opts').style.display = (pg && P.pignons) ? 'block' : 'none'; pigtype();
        el('haut_bloc').style.display = (P.type === 'Monopente' || P.type === '3 pans') ? 'block' : 'none';
        el('haut_titre').textContent = P.type === '3 pans' ? '3 pans : côté de la croupe' : 'Monopente : côté haut';
      }
      function pigtype() {
        var z = el('pig_type'); z.innerHTML = '';
        [['brique', 'Brique'], ['parpaing', 'Parpaing'], ['compose', 'Mur composé']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (P.pig_type === x[0] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { P.pig_type = x[0]; if (x[0] === 'compose' && !P.pig_comp && D.compos.length) P.pig_comp = D.compos[0].id; rendre(); envoyer(); }); z.appendChild(b);
        });
        var sel = el('pig_comp'); if (sel.options.length === 0) { D.compos.forEach(function (c) { var o = document.createElement('option'); o.value = c.id; o.textContent = c.nom + ' (' + c.total + ' cm)'; sel.appendChild(o); }); sel.addEventListener('change', function () { P.pig_comp = sel.value; envoyer(); }); }
        sel.value = P.pig_comp || ''; el('pig_comp_bloc').style.display = P.pig_type === 'compose' ? 'flex' : 'none';
      }
      function champs(reset) {
        var z = el('champs');
        if (z.children.length === 0) {
          CH.forEach(function (c) {
            var w = document.createElement('div'); w.className = 'champ'; w.id = 'w_' + c[0];
            w.innerHTML = '<label></label><input type="text" id="v_' + c[0] + '"><input type="range" id="r_' + c[0] + '">';
            w.querySelector('label').textContent = c[1]; z.appendChild(w);
            var r = w.querySelector('[type=range]'), v = w.querySelector('[type=text]');
            r.min = c[2]; r.max = c[3]; r.step = c[4];
            r.addEventListener('input', function () { v.value = r.value.replace('.', ','); P[c[0]] = parseFloat(r.value); envoyer(); });
            v.addEventListener('input', function () { var x = parseFloat(v.value.replace(',', '.')); if (!isNaN(x) && (c[0] !== 'pente' || x > 0)) { P[c[0]] = x; if (x > +r.max) r.max = x; r.value = x; envoyer(); } });
          });
        }
        CH.forEach(function (c) { var r = el('r_' + c[0]), v = el('v_' + c[0]); if (reset || document.activeElement !== v) { r.value = P[c[0]]; v.value = (+P[c[0]]).toString().replace('.', ','); } });
      }
      el('pignons').addEventListener('change', function () { P.pignons = el('pignons').checked; rendre(); envoyer(); });
      el('reprendre').addEventListener('click', function () { sketchup.reprendre(''); });
      el('valider').addEventListener('click', function () { sketchup.valider(''); });
      el('suppr').addEventListener('click', function () { sketchup.supprimer(''); });
      function etat(p, data, reset) {
        P = p; DATA = data; rendre(); champs(reset);
        el('alerte').textContent = data.msg || '';
        el('info').textContent = data.info || '';
        dessus(data); coupe(data);
      }
      function poly4(xa, ya, xb, yb) { return '<rect x="' + xa + '" y="' + ya + '" width="' + (xb - xa) + '" height="' + (yb - ya) + '" fill="#8a7f75" fill-opacity="0.7" stroke="#3C3C3C"/>'; }
      function cle(a, b) { function r(q) { return Math.round(q[0] * 100) + ',' + Math.round(q[1] * 100) + ',' + Math.round(q[2] * 100); } var x = r(a), y = r(b); return x < y ? x + '|' + y : y + '|' + x; }
      function dessus(d) {
        var sv = el('dessus'), W = 520, H = 300, polys = d.polys, out = d.contour || [];
        var xs = [], ys = [];
        polys.forEach(function (p) { p.forEach(function (q) { xs.push(q[0]); ys.push(q[1]); }); }); out.forEach(function (q) { xs.push(q[0]); ys.push(q[1]); });
        var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs), y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys);
        var k = Math.min((W - 40) / Math.max(x1 - x0, 0.1), (H - 40) / Math.max(y1 - y0, 0.1));
        function X(x) { return 20 + (x - x0) * k + ((W - 40) - (x1 - x0) * k) / 2; } function Y(y) { return H - 20 - (y - y0) * k - ((H - 40) - (y1 - y0) * k) / 2; }
        var o = '', cnt = {}, ar = {};
        polys.forEach(function (p, i) {
          o += '<polygon points="' + p.map(function (q) { return X(q[0]) + ',' + Y(q[1]); }).join(' ') + '" fill="' + (i % 2 ? '#f2d9c4' : '#f7e6d6') + '" stroke="#b89b84" stroke-width="1"/>';
          p.forEach(function (a, j) { var b = p[(j + 1) % p.length], c = cle(a, b); if (!cnt[c]) cnt[c] = 0; cnt[c]++; ar[c] = [a, b]; });
          // flèche de pente : du haut vers le bas du pan
          var zs = p.map(function (q) { return q[2]; }), zmin = Math.min.apply(null, zs), zmax = Math.max.apply(null, zs);
          if (zmax - zmin > 0.01) {
            var hi = [0, 0, 0], lo = [0, 0, 0], nh = 0, nl = 0;
            p.forEach(function (q) { if (q[2] > zmax - 0.01) { hi[0] += q[0]; hi[1] += q[1]; nh++; } if (q[2] < zmin + 0.01) { lo[0] += q[0]; lo[1] += q[1]; nl++; } });
            var ax = hi[0] / nh, ay = hi[1] / nh, bx = lo[0] / nl, by = lo[1] / nl, mx = (ax + bx) / 2, my = (ay + by) / 2, dx = bx - ax, dy = by - ay, L = Math.sqrt(dx * dx + dy * dy) || 1;
            var cx = p.reduce(function (s, q) { return s + q[0]; }, 0) / p.length, cy = p.reduce(function (s, q) { return s + q[1]; }, 0) / p.length;
            var ux = dx / L, uy = dy / L, px = X(cx), py = Y(cy), qx = X(cx + ux * 0.5), qy = Y(cy + uy * 0.5);
            o += '<line x1="' + px + '" y1="' + py + '" x2="' + qx + '" y2="' + qy + '" stroke="#a8541f" stroke-width="1.6"/><circle cx="' + qx + '" cy="' + qy + '" r="3" fill="#a8541f"/>';
          }
        });
        (d.pig || []).forEach(function (g) { o += poly4(X(g[0]), Y(d.wlarg), X(g[1]), Y(0)); });
        if (out.length) o += '<polygon points="' + out.map(function (q) { return X(q[0]) + ',' + Y(q[1]); }).join(' ') + '" fill="none" stroke="#6f665e" stroke-width="2" stroke-dasharray="6 4"/>';
        Object.keys(cnt).forEach(function (c) {
          if (cnt[c] < 2) return; var a = ar[c][0], b = ar[c][1], hor = Math.abs(a[2] - b[2]) < 0.01;
          o += '<line x1="' + X(a[0]) + '" y1="' + Y(a[1]) + '" x2="' + X(b[0]) + '" y2="' + Y(b[1]) + '" stroke="' + (hor ? '#3C3C3C' : '#E07838') + '" stroke-width="' + (hor ? 4 : 3) + '"/>';
        });
        o += '<text x="12" y="16" font-size="10" fill="#8a7f75">trait noir = faîtage, orange = arêtier, pointillé = murs, flèche = sens de la pente</text>';
        sv.innerHTML = o;
      }
      function coupe(d) {
        var sv = el('coupe'), W = 520, H = 200, segs = d.coupe || [];
        if (!segs.length) { sv.innerHTML = ''; return; }
        var ys = [], zs = [];
        segs.forEach(function (s) { s.forEach(function (q) { ys.push(q[0]); zs.push(q[1]); }); });
        var wl = d.murs || [];
        wl.forEach(function (m) { ys.push(m[0], m[1]); });
        var y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys), z1 = Math.max.apply(null, zs) + 0.2, z0 = -1.2;
        var k = Math.min((W - 60) / Math.max(y1 - y0, 0.1), (H - 40) / (z1 - z0));
        function X(y) { return 30 + (y - y0) * k + ((W - 60) - (y1 - y0) * k) / 2; } function Z(z) { return 20 + (z1 - z) * k; }
        var o = '<rect x="0" y="' + Z(z0) + '" width="' + W + '" height="' + (H - Z(z0)) + '" fill="#fff"/>';
        wl.forEach(function (m) { o += '<rect x="' + X(m[0]) + '" y="' + Z(0) + '" width="' + ((m[1] - m[0]) * k) + '" height="' + ((-z0) * k) + '" fill="#d9cfc2" stroke="#8a7f75"/>'; });
        var e = Math.max(1.5, (d.ep || 0) * k / 100);
        segs.forEach(function (s) {
          o += '<line x1="' + X(s[0][0]) + '" y1="' + Z(s[0][1]) + '" x2="' + X(s[1][0]) + '" y2="' + Z(s[1][1]) + '" stroke="#b89b84" stroke-width="' + (e * 1.0) + '" stroke-linecap="butt"/>';
          o += '<line x1="' + X(s[0][0]) + '" y1="' + Z(s[0][1]) + '" x2="' + X(s[1][0]) + '" y2="' + Z(s[1][1]) + '" stroke="#6f665e" stroke-width="1.2"/>';
        });
        if (d.hfaite !== undefined) o += '<text x="12" y="16" font-size="10" fill="#8a7f75">hauteur du haut de toiture au-dessus des murs : ' + d.hfaite.toFixed(2).replace('.', ',') + ' m</text>';
        sv.innerHTML = o;
      }
      sketchup.pret('');
    JS

    # Repère (origine, axes, longueur, largeur) tel que le prend batir selon le sens et le côté haut
    def self.repere(prm, base)
      o = Geom::Point3d.new(*base['o']); u = Geom::Vector3d.new(*base['u']); v = Geom::Vector3d.new(*base['v'])
      l, w = base['l'], base['w']
      if prm[:sens] == 'petit côté' then o = o.offset(u, l.m); u, v = v, u.reverse; l, w = w, l end
      if ['Monopente', '3 pans'].include?(prm[:type]) && prm[:haut] == 'côté de l\'origine' then o = o.offset(u, l.m).offset(v, w.m); u = u.reverse; v = v.reverse end
      [o, u, v, l, w]
    end

    PIG_STRUCT = %w[A2M_MUR_PERI A2M_MUR_REFEND A2M_MUR_SOUB].freeze
    PIG_COULEURS = { 'brique' => [196, 112, 84], 'parpaing' => [160, 160, 165] }.freeze

    # Couches du pignon, de l'extérieur vers l'intérieur : brique ou parpaing (une couche de l'épaisseur choisie) ou une composition de murs
    def self.couches_pignon(prm)
      t = [prm[:pig_ep].to_f, 5].max
      if prm[:pig_type] == 'compose'
        c = A2M::Compositions.trouver(prm[:pig_comp].to_s)
        return c['couches'].map { |k| { 'nom' => k['nom'], 'balise' => (PIG_STRUCT.include?(k['balise']) ? 'A2M_MUR_PIGNON' : k['balise']), 'e' => k['e'].to_f, 'cle' => nil } } if c
      end
      cle = prm[:pig_type] == 'parpaing' ? 'parpaing' : 'brique'
      [{ 'nom' => cle == 'parpaing' ? 'Parpaing' : 'Brique', 'balise' => 'A2M_MUR_PIGNON', 'e' => t, 'cle' => cle }]
    end

    def self.pig_epaisseur(prm) couches_pignon(prm).sum { |k| k['e'] } end

    def self.compositions_murs
      A2M::Compositions.toutes.select { |x| x['famille'] == 'Murs' }.map { |x| { 'id' => x['id'], 'nom' => x['nom'], 'total' => x['couches'].sum { |k| k['e'].to_f }.round(1) } }
    end

    # Murs pignons : les deux extrémités du faîtage (types 2 pans et monopente), jusqu'à la sous-face de la toiture
    def self.pignons(model, toit, prm, base)
      return 0 unless prm[:pignons] && base['k'] == 'rect' && ['2 pans', '3 pans', 'Monopente'].include?(prm[:type])
      o, u, v, l, w = repere(prm, base)
      s = prm[:pente] / 100.0
      z0 = base['ztop'].to_f
      profil = ['2 pans', '3 pans'].include?(prm[:type]) ? [[0, 0], [w, 0], [w / 2.0, s * w / 2.0]] : [[0, 0], [w, 0], [w, s * w]]
      cree = 0
      (prm[:type] == '3 pans' ? [0] : [0, 1]).each do |bout|
        acc = 0.0
        couches_pignon(prm).each do |k|
          e = k['e'] / 100.0
          ua = bout == 0 ? acc : l - acc - e
          acc += e
          g = model.active_entities.add_group
          pts = profil.map { |pv, pz| o.offset(u, ua.m).offset(v, pv.m).offset(Z_AXIS, z0 + pz.m) }
          f = g.entities.add_face(pts)
          unless f then g.erase!; next end
          f.pushpull(f.normal.dot(u) > 0 ? e.m : -e.m)
          lb, _ = A2M::Balises.balise(model, k['balise'], A2M::Compositions::COULEURS[k['balise']])
          g.layer = lb
          g.name = "Pignon – #{k['nom']}"
          rgb = (k['cle'] && PIG_COULEURS[k['cle']]) || A2M::Compositions::COULEURS[k['balise']] || [190, 175, 160]
          mat = k['cle'] ? model.materials.to_a.find { |m| m.name.downcase == "a2m_#{k['cle']}" } : nil
          g.entities.grep(Sketchup::Face).each { |x| if mat then x.material = mat; x.back_material = mat else c = Sketchup::Color.new(*rgb); x.material = c; x.back_material = c end }
          g.set_attribute(A2M::Toiture::ACC, 'toit', toit.persistent_id)
          cree += 1
        end
      end
      cree
    end

    # ---- Données du dessin : pans et contour projetés à plat (vue de dessus), tranche verticale au milieu (coupe) ----
    def self.donnees(prm, base, polys)
      ztop = base['ztop'].to_f
      if base['k'] == 'rect'
        o = Geom::Point3d.new(*base['o']); u = Geom::Vector3d.new(*base['u']); v = Geom::Vector3d.new(*base['v'])
        l, w = base['l'], base['w']
        if prm[:sens] == 'petit côté' then o = o.offset(u, l.m); u, v = v, u.reverse; l, w = w, l end
        if ['Monopente', '3 pans'].include?(prm[:type]) && prm[:haut] == 'côté de l\'origine' then o = o.offset(u, l.m).offset(v, w.m); u = u.reverse; v = v.reverse end
        proj = ->(q) { d = q - o; [d.dot(u).to_m, d.dot(v).to_m, (q.z - ztop).to_m] }
        contour = [[0, 0], [l, 0], [l, w], [0, w]]
        murs = [[-0.1, 0.1], [w - 0.1, w + 0.1]]
        cx = l / 2.0
      else
        proj = ->(q) { [q.x.to_m, q.y.to_m, (q.z - ztop).to_m] }
        contour = base['cpts']
        murs = []
        xs = contour.map(&:first); cx = (xs.min + xs.max) / 2.0
      end
      pp = polys.map { |pts| pts.map { |q| proj.call(q).map { |c| c.round(3) } } }
      segs = []
      pp.each do |pts|
        cr = []
        pts.each_with_index do |a, i|
          b = pts[(i + 1) % pts.size]
          next if (a[0] - cx) * (b[0] - cx) > 0 || (a[0] - b[0]).abs < 1e-9
          t = (cx - a[0]) / (b[0] - a[0])
          cr << [(a[1] + (b[1] - a[1]) * t).round(3), (a[2] + (b[2] - a[2]) * t).round(3)]
        end
        cr = cr.uniq.sort_by(&:first)
        segs << [cr.first, cr.last] if cr.size >= 2
      end
      hmax = pp.flatten(1).map { |q| q[2] }.max.to_f
      pig = (prm[:pignons] && base['k'] == 'rect' && ['2 pans', '3 pans', 'Monopente'].include?(prm[:type])) ? (prm[:type] == '3 pans' ? [[0.0, pig_epaisseur(prm) / 100.0]] : [[0.0, pig_epaisseur(prm) / 100.0], [l - pig_epaisseur(prm) / 100.0, l]]) : []
      { 'pig' => pig, 'wlarg' => (base['k'] == 'rect' ? w : 0), 'polys' => pp, 'contour' => contour, 'coupe' => segs, 'murs' => murs, 'ep' => prm[:ep].to_f, 'hfaite' => hmax }
    end

    def self.prm_json(prm) { 'type' => prm[:type], 'pente' => prm[:pente], 'd' => (prm[:d] * 100).round(1), 'ep' => prm[:ep], 'sens' => prm[:sens], 'haut' => prm[:haut], 'num' => prm[:num].to_s, 'pignons' => !!prm[:pignons], 'pig_ep' => prm[:pig_ep].to_f, 'pig_type' => prm[:pig_type], 'pig_comp' => prm[:pig_comp].to_s } end

    def self.defaut
      r = (A2M::Toiture.instance_variable_get(:@r) || {})
      { type: r[:type] || '2 pans', pente: (r[:pente] || 45).to_f, d: (r[:d] || 0.5).to_f, ep: (r[:ep] || 20).to_f,
        sens: r[:sens] || 'grand côté', pignons: r[:pignons] ? true : false, pig_type: (r[:pig_type] || 'brique'), pig_comp: r[:pig_comp].to_s, pig_ep: (r[:pig_ep] || 20).to_f, haut: r[:haut] || 'côté opposé à l\'origine', num: (r[:num] || '1').to_s }
    end

    def self.murs_selection(model)
      model.selection.to_a.select { |e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && !e.get_attribute(A2M::Toiture::ATTR, 'base') }
    end

    def self.lancer
      model = Sketchup.active_model
      murs = murs_selection(model)
      if murs.empty?
        UI.messagebox('Sélectionnez les murs (groupes) sur lesquels poser la toiture, puis relancez « Créer la toiture ». Elle couvre le rectangle de ces murs, ou suit exactement leur contour (type « Suit les murs »).')
        return
      end
      prm = defaut
      base = A2M::Toiture.base_des_murs(murs, prm[:type], model)
      return UI.messagebox('Je ne trouve pas la géométrie de ces murs.') unless base
      @cur = { murs: murs, prm: prm, base: base, grp: nil, premier: true }
      ouvrir
      reconstruire(true)
    end

    def self.modifier(grp = nil)
      model = Sketchup.active_model
      grp ||= model.selection.to_a.find { |e| e.respond_to?(:get_attribute) && e.get_attribute(A2M::Toiture::ATTR, 'base') }
      return UI.messagebox('Sélectionnez la toiture à modifier (une toiture créée avec « Créer la toiture »).') unless grp
      prm = (JSON.parse(grp.get_attribute(A2M::Toiture::ATTR, 'prm')).map { |k, v| [k.to_sym, v] }.to_h rescue nil)
      base = (JSON.parse(grp.get_attribute(A2M::Toiture::ATTR, 'base')) rescue nil)
      return UI.messagebox('Cette toiture n\'a pas gardé ses réglages.') unless prm && base
      prm = defaut.merge(prm.reject { |k, _| k == :reprendre })
      prm[:num] = prm[:num].to_s
      @cur = { murs: nil, prm: prm, base: base, grp: grp, premier: true }
      ouvrir
      UI.start_timer(0.2, false) { reconstruire(true) }
    end

    def self.reconstruire(reset = false)
      c = @cur or return
      model = Sketchup.active_model
      model.start_operation('Toiture (métré)', true, false, !c[:premier])
      begin
        suit = c[:prm][:type] == A2M::Toiture::SUIT
        if suit != (c[:base]['k'] == 'suit')
          raise 'Ce changement de type demande de reprendre le contour : sélectionnez les murs, puis « Reprendre le contour sur les murs sélectionnés ».' unless c[:murs] && c[:murs].all?(&:valid?)
          nb = A2M::Toiture.base_des_murs(c[:murs], c[:prm][:type], model) or raise 'Je ne trouve pas le dessus des murs.'
          c[:base] = nb
        end
        nouvelle = A2M::Toiture.batir(model, c[:prm], c[:base])
        pignons(model, nouvelle, c[:prm], c[:base])
        if c[:grp] && c[:grp].valid?
          A2M::Toiture.effacer_accessoires(model, c[:grp])
          c[:grp].erase!
        end
        c[:grp] = nouvelle; c[:premier] = false
        model.commit_operation
        A2M::Toiture.instance_variable_set(:@r, c[:prm].dup)
        d = donnees(c[:prm], c[:base], A2M::Toiture.polys_dernier)
        s = Math.atan(c[:prm][:pente] / 100.0) * 180 / Math::PI
        d['info'] = "Pente #{c[:prm][:pente].round(1).to_s.tr('.', ',')} % (#{s.round(1).to_s.tr('.', ',')}°), débord #{(c[:prm][:d] * 100).round} cm"
        envoyer(d, reset)
      rescue StandardError => ex
        model.abort_operation
        envoyer({ 'polys' => [], 'contour' => [], 'coupe' => [], 'msg' => ex.message.to_s }, false) if @fen
      end
    end

    def self.envoyer(d, reset)
      return unless @fen && (@fen.visible? rescue false) && @cur
      if d['polys'].empty?
        @fen.execute_script("document.getElementById('alerte').textContent=#{JSON.generate(d['msg'].to_s)}")
      else
        @fen.execute_script("etat(#{JSON.generate(prm_json(@cur[:prm]))},#{JSON.generate(d)},#{reset ? 'true' : 'false'})")
      end
    end

    def self.maj(json)
      return unless @cur
      h = (JSON.parse(json.to_s) rescue nil) or return
      p = @cur[:prm]
      p[:type] = h['type'] if h['type']
      p[:pente] = h['pente'].to_f if h['pente'].to_f > 0
      p[:d] = h['d'].to_f / 100.0
      p[:ep] = [h['ep'].to_f, 0].max
      p[:sens] = h['sens'] if h['sens']
      p[:haut] = h['haut'] if h['haut']
      p[:num] = h['num'].to_s if h['num']
      p[:pignons] = h['pignons'] ? true : false
      p[:pig_ep] = [h['pig_ep'].to_f, 5].max if h['pig_ep']
      p[:pig_type] = h['pig_type'] if %w[brique parpaing compose].include?(h['pig_type'])
      p[:pig_comp] = h['pig_comp'].to_s if h['pig_comp']
      reconstruire(false)
    end

    def self.reprendre
      c = @cur or return
      model = Sketchup.active_model
      murs = murs_selection(model)
      return UI.messagebox('Sélectionnez les murs (en plus ou à la place de la toiture), puis cliquez de nouveau.') if murs.empty?
      c[:murs] = murs
      c[:base] = A2M::Toiture.base_des_murs(murs, c[:prm][:type], model) or return UI.messagebox('Je ne trouve pas le dessus de ces murs.')
      reconstruire(false)
    end

    def self.supprimer
      c = @cur or return
      g = c[:grp]
      if g && g.valid?
        Sketchup.active_model.start_operation('Supprimer la toiture', true)
        A2M::Toiture.effacer_accessoires(Sketchup.active_model, g)
        g.erase!
        Sketchup.active_model.commit_operation
      end
      @cur = nil
      @fen.close if @fen
    end

    def self.valider
      g = @cur && @cur[:grp]
      Sketchup.active_model.selection.clear
      Sketchup.active_model.selection.add(g) if g && g.valid?
      @cur = nil
      @fen.close if @fen
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      d = { 'compos' => compositions_murs, 'types' => A2M::Toiture::TYPES, 'hauts' => ['côté opposé à l\'origine', 'côté de l\'origine'] }
      html = A2M::Panneau.page('Toiture', 'Vue de dessus et coupe à l\'échelle : tout se règle ici, le modèle suit en direct', CORPS, SCRIPT, d)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : toiture', 'A2M_Panneau_Toiture', html, 580, 940)
      @fen = dlg
      dlg.add_action_callback('pret') { |_c, _j| UI.start_timer(0, false) { reconstruire(true) if @cur && @cur[:grp] } }
      dlg.add_action_callback('maj') { |_c, json| UI.start_timer(0, false) { maj(json) } }
      dlg.add_action_callback('reprendre') { |_c, _j| UI.start_timer(0, false) { reprendre } }
      dlg.add_action_callback('valider') { |_c, _j| UI.start_timer(0, false) { valider } }
      dlg.add_action_callback('supprimer') { |_c, _j| UI.start_timer(0, false) { supprimer } }
      dlg.set_on_closed { @fen = nil; @cur = nil }
      dlg.show
    end
  end
end
