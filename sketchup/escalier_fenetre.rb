# encoding: UTF-8
# Métré Atelier 2M : fenêtre de l'escalier avec vue de dessus et coupe à l'échelle. Les dessins se calculent à mesure des réglages ;
# une fois l'escalier posé (2 clics), chaque réglage le refait en direct dans le modèle. L'ancienne fenêtre reste en réserve.
require 'sketchup.rb'
require 'json'

module A2M
  module Escalier
    class << self
      alias_method :ouvrir_classique, :ouvrir unless method_defined?(:ouvrir_classique)
      alias_method :modifier_classique, :modifier unless method_defined?(:modifier_classique)
      def ouvrir(*_a) A2M::EscalierFenetre.ouvrir end
      def modifier(grp, d) A2M::EscalierFenetre.modifier(grp, d) end
      def pose_initiale(r, o, dir) A2M::EscalierFenetre.pose_initiale(r, o, dir) end
    end
  end

  module EscalierFenetre
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
        .info{font-size:12px;color:#6f665e;margin:6px 0}
        .bon{color:#2f7a3a;font-weight:600} .mauvais{color:#a8541f;font-weight:600}
      </style>
      <h2>Vue de dessus</h2>
      <svg id="dessus" class="vue" viewBox="0 0 520 280" style="height:280px"></svg>
      <h2>Coupe (développée)</h2>
      <svg id="coupe" class="vue" viewBox="0 0 520 200" style="height:200px"></svg>
      <div class="info" id="info"></div>
      <h2>Forme</h2>
      <div class="grille" id="types"></div>
      <div id="champs"></div>
      <h2>Ouvrage</h2>
      <div class="puces" id="opts"></div>
      <h2>Matière</h2>
      <div class="puces" id="mat"></div>
      <div class="rang"><button type="button" class="btn fort" id="placer">Placer l'escalier (2 clics)</button></div>
      <div class="petit" id="aide">Cliquez le pied de la première marche, puis un second point pour la direction de montée. Ensuite chaque réglage ici refait l'escalier dans le modèle.</div>
      <div class="rang" id="fin" style="display:none"><button type="button" class="btn fort" id="valider">Valider</button><button type="button" class="btn" id="suppr">Supprimer cet escalier</button></div>
      <div id="bas"><div id="msg"></div></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      var P = { t: 'droit', h: 270, w: 90, g: 25, nm: 0, contre: true, limons: true, mur: 'aucun', mat: 'Chêne', beton: false, eb: 14, db: 10, sb: 15 }, placed = false, tmr = null;
      var CH = [['h', 'Hauteur à monter (cm)', 100, 450, 0.5], ['w', 'Largeur de l’escalier (cm)', 60, 150, 1], ['g', 'Giron (cm)', 18, 35, 0.5], ['nm', 'Nombre de marches (0 = calculé)', 0, 25, 1], ['eb', 'Épaisseur de la paillasse béton (cm)', 10, 25, 1, 1], ['db', 'Ø des barres principales (mm)', 8, 16, 2, 1], ['sb', 'Espacement des barres (cm)', 10, 25, 1, 1]];
      var FORMES = { droit: 'M8 32 V8 H40 V32 Z M8 14 H40 M8 20 H40 M8 26 H40', quart_g: 'M8 32 V18 H22 V8 H40 V32 Z M8 24 H22 M22 14 H40 M22 24 H40', quart_d: 'M8 8 H26 V18 H40 V32 H8 Z M8 14 H26 M26 24 H40 M16 18 V32', demi_g: 'M8 8 H40 V32 H8 Z M24 8 V32 M8 14 H24 M32 14 H40', demi_d: 'M8 8 H40 V32 H8 Z M24 8 V32 M8 14 H24 M32 14 H40' };
      function envoyer() { clearTimeout(tmr); tmr = setTimeout(function () { if (placed) sketchup.maj(JSON.stringify(P)); }, 80); }
      function pose(v) { placed = v; el('placer').textContent = v ? 'Replacer l’escalier (2 clics)' : 'Placer l’escalier (2 clics)'; el('fin').style.display = v ? 'flex' : 'none'; }
      function init(p, pl) { for (var k in p) { P[k] = (typeof P[k] === 'number') ? (parseFloat(String(p[k]).replace(',', '.')) || 0) : p[k]; } pose(!!pl); rendre(); champs(true); dessiner(); }
      function rendre() {
        var g = el('types'); g.innerHTML = '';
        D.types.forEach(function (t) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte' + (P.t === t.cle ? ' rempli' : '');
          b.innerHTML = '<div class="vignette"><svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1.2"><path d="' + FORMES[t.cle] + '"/></svg></div><span></span><div class="petit" style="margin:2px 0 0"></div>';
          b.querySelector('span').textContent = t.libelle; b.querySelector('.petit').textContent = t.aide;
          b.addEventListener('click', function () { P.t = t.cle; rendre(); dessiner(); envoyer(); }); g.appendChild(b);
        });
        var o = el('opts'); o.innerHTML = '';
        [['contre', 'Contremarches'], ['limons', 'Limons latéraux']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (P[x[0]] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { P[x[0]] = !P[x[0]]; rendre(); envoyer(); }); o.appendChild(b);
        });
        var bt = document.createElement('button'); bt.type = 'button'; bt.className = 'puce' + (P.beton ? ' rempli' : ''); bt.textContent = 'Structure béton + ferraillage';
        bt.addEventListener('click', function () { P.beton = !P.beton; rendre(); envoyer(); }); o.appendChild(bt);
        var w = document.createElement('span'); w.className = 'petit'; w.textContent = ' Côté mur (sans garde-corps) :'; o.appendChild(w);
        [['aucun', 'aucun'], ['gauche', 'à gauche'], ['droite', 'à droite']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (P.mur === x[0] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { P.mur = x[0]; rendre(); envoyer(); }); o.appendChild(b);
        });
        var m = el('mat'); m.innerHTML = '';
        D.mat.forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (P.mat === x ? ' rempli' : ''); b.textContent = x;
          b.addEventListener('click', function () { P.mat = x; rendre(); envoyer(); }); m.appendChild(b);
        });
        if (el('champs').children.length) champs(false);
      }
      function champs(reset) {
        var z = el('champs');
        if (z.children.length === 0) {
          CH.forEach(function (c) {
            var w = document.createElement('div'); w.className = 'champ';
            w.innerHTML = '<label></label><input type="text" id="v_' + c[0] + '"><input type="range" id="r_' + c[0] + '">';
            w.querySelector('label').textContent = c[1]; if (c[5]) w.setAttribute('data-b', '1'); z.appendChild(w);
            var r = w.querySelector('[type=range]'), v = w.querySelector('[type=text]');
            r.min = c[2]; r.max = c[3]; r.step = c[4];
            r.addEventListener('input', function () { v.value = r.value.replace('.', ','); P[c[0]] = parseFloat(r.value); dessiner(); envoyer(); });
            v.addEventListener('input', function () { var x = parseFloat(v.value.replace(',', '.')); if (!isNaN(x)) { P[c[0]] = x; if (x > +r.max) r.max = x; r.value = x; dessiner(); envoyer(); } });
          });
        }
        Array.prototype.forEach.call(z.querySelectorAll('[data-b]'), function (q) { q.style.display = P.beton ? '' : 'none'; });
        CH.forEach(function (c) { var r = el('r_' + c[0]), v = el('v_' + c[0]); if (reset || document.activeElement !== v) { r.value = P[c[0]]; v.value = (+P[c[0]]).toString().replace('.', ','); } });
      }
      // Géométrie à plat : mêmes règles que le modèle (volée 1, palier, volée 2)
      function geo() {
        var H = P.h, w = P.w, g = P.g, n = P.nm > 1 ? Math.round(P.nm) : Math.max(2, Math.round(H / 17.5)), h = H / n, tr = n - 1, R = [], pal = null, v1 = 0, v2 = 0, tourne = P.t !== 'droit';
        function vol(ox, oy, dx, dy, lx, ly, m) { for (var i = 1; i <= m; i++) { var a = (i - 1) * g, b = i * g; R.push([[0, a, 0], [0, b, 0], [0, b, w], [0, a, w]].map(function (q) { return [ox + dx * q[1] + lx * q[2], oy + dy * q[1] + ly * q[2]]; })); } }
        if (!tourne) { v1 = tr; vol(0, 0, 1, 0, 0, 1, tr); }
        else {
          var gauche = P.t.slice(-2) === '_g', quart = P.t.indexOf('quart') === 0;
          v1 = Math.floor((tr - 1) / 2); v2 = tr - 1 - v1;
          vol(0, 0, 1, 0, 0, 1, v1);
          var x1 = v1 * g, lar = quart ? w : 2 * w, y0 = gauche ? 0 : w - lar;
          pal = [[x1, y0], [x1 + w, y0], [x1 + w, y0 + lar], [x1, y0 + lar]];
          if (quart) { if (gauche) vol(x1 + w, w, 0, 1, -1, 0, v2); else vol(x1, 0, 0, -1, 1, 0, v2); }
          else { if (gauche) vol(x1, 2 * w, -1, 0, 0, -1, v2); else vol(x1, -w, -1, 0, 0, 1, v2); }
        }
        return { n: n, h: h, R: R, pal: pal, v1: v1, v2: v2, tourne: tourne };
      }
      function dessiner() {
        var G = geo(), g = P.g, w = P.w;
        var b = (2 * G.h + g), ok = b >= 59 && b <= 66;
        el('info').innerHTML = G.n + ' marches de ' + G.h.toFixed(1).replace('.', ',') + ' cm, giron ' + g.toString().replace('.', ',') + ' cm : loi de Blondel (2h + g) = ' + b.toFixed(1).replace('.', ',') + ' cm <span class="' + (ok ? 'bon' : 'mauvais') + '">' + (ok ? '✓ confortable' : '⚠ hors de 59 à 66 cm') + '</span>';
        // vue de dessus
        var xs = [], ys = [];
        G.R.forEach(function (r) { r.forEach(function (q) { xs.push(q[0]); ys.push(q[1]); }); }); if (G.pal) G.pal.forEach(function (q) { xs.push(q[0]); ys.push(q[1]); });
        var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs), y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys), W = 520, H = 280;
        var k = Math.min((W - 40) / Math.max(x1 - x0, 1), (H - 40) / Math.max(y1 - y0, 1));
        function X(x) { return 20 + (x - x0) * k + ((W - 40) - (x1 - x0) * k) / 2; } function Y(y) { return H - 20 - (y - y0) * k - ((H - 40) - (y1 - y0) * k) / 2; }
        function poly(p, f) { return '<polygon points="' + p.map(function (q) { return X(q[0]) + ',' + Y(q[1]); }).join(' ') + '" fill="' + f + '" stroke="#8a7f75" stroke-width="1"/>'; }
        var o = '';
        G.R.forEach(function (r, i) { o += poly(r, i % 2 ? '#e9dcc9' : '#f1e6d6'); });
        if (G.pal) o += poly(G.pal, '#e2cfb4');
        o += '<circle cx="' + X(0) + '" cy="' + Y(w / 2) + '" r="5" fill="#E07838"/><text x="' + (X(0) + 8) + '" y="' + (Y(w / 2) - 7) + '" font-size="10" fill="#a8541f">départ</text>';
        el('dessus').innerHTML = o;
        // coupe développée
        var pts = [[0, 0]], x = 0, z = 0, ha = G.h;
        function marches(m) { for (var i = 0; i < m; i++) { z += ha; pts.push([x, z]); x += g; pts.push([x, z]); } }
        marches(G.v1);
        if (G.tourne) { z += ha; pts.push([x, z]); x += w; pts.push([x, z]); marches(G.v2); }
        z += ha; pts.push([x, z]); x += g * 1.5; pts.push([x, z]);
        var cx1 = Math.max.apply(null, pts.map(function (q) { return q[0]; })), cz1 = Math.max.apply(null, pts.map(function (q) { return q[1]; })), W2 = 520, H2 = 200;
        var k2 = Math.min((W2 - 60) / cx1, (H2 - 40) / (cz1 + 20));
        function X2(a) { return 30 + a * k2 + ((W2 - 60) - cx1 * k2) / 2; } function Z2(a) { return H2 - 20 - a * k2; }
        var d = 'M' + pts.map(function (q) { return X2(q[0]) + ' ' + Z2(q[1]); }).join(' L');
        var s = '<line x1="10" y1="' + Z2(0) + '" x2="510" y2="' + Z2(0) + '" stroke="#6f665e"/>';
        s += '<path d="' + d + ' V' + Z2(0) + ' H' + X2(0) + ' Z" fill="#f1e6d6" stroke="#8a7f75" stroke-width="1.5"/>';
        s += '<text x="12" y="16" font-size="10" fill="#8a7f75">hauteur à monter : ' + P.h.toString().replace('.', ',') + ' cm' + (G.tourne ? ' (coupe dépliée : le palier est compté à plat)' : '') + '</text>';
        el('coupe').innerHTML = s;
      }
      el('placer').addEventListener('click', function () { sketchup.placer(JSON.stringify(P)); });
      el('valider').addEventListener('click', function () { sketchup.valider(''); });
      el('suppr').addEventListener('click', function () { sketchup.supprimer(''); pose(false); });
      rendre(); champs(true); dessiner();
      sketchup.pret('');
    JS

    def self.ouvrir
      @cur = { r: nil, o: nil, dir: nil, grp: nil }
      afficher
    end

    def self.modifier(grp, d)
      return UI.messagebox('Cet escalier n\'a pas gardé ses réglages : reposez-le une fois avec l\'outil.') unless d && d['r']
      @cur = { r: d['r'].reject { |k, _| k == 'replacer' }, o: Geom::Point3d.new(*d['o']), dir: Geom::Vector3d.new(*d['dir']), grp: grp }
      afficher
    end

    def self.afficher
      if @fen && (@fen.visible? rescue false)
        envoyer_init
        @fen.bring_to_front
        return
      end
      d = { 'types' => A2M::Escalier::TYPES.map { |k, l, a| { 'cle' => k, 'libelle' => l, 'aide' => a } }, 'mat' => A2M::Escalier::MATIERES.keys }
      html = A2M::Panneau.page('Escalier', 'Vue de dessus et coupe à l\'échelle : droit, quart tournant ou demi-tournant (loi de Blondel)', CORPS, SCRIPT, d)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : escalier', 'A2M_Panneau_EscFen', html, 580, 1000)
      @fen = dlg
      dlg.add_action_callback('pret') { |_c, _j| UI.start_timer(0, false) { envoyer_init } }
      dlg.add_action_callback('placer') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) { Sketchup.active_model.select_tool(A2M::Escalier::Outil.new(r)) } if r
      end
      dlg.add_action_callback('maj') { |_c, json| UI.start_timer(0, false) { maj(json) } }
      dlg.add_action_callback('valider') { |_c, _j| UI.start_timer(0, false) { valider } }
      dlg.add_action_callback('supprimer') { |_c, _j| UI.start_timer(0, false) { supprimer } }
      dlg.set_on_closed { @fen = nil; @cur = nil }
      dlg.show
    end

    def self.envoyer_init
      return unless @fen && @cur
      r = @cur[:r] || {}
      @fen.execute_script("init(#{JSON.generate(r)},#{@cur[:grp] && @cur[:grp].valid? ? 'true' : 'false'})")
    end

    def self.pose_initiale(r, o, dir)
      c = @cur
      if c && c[:grp] && c[:grp].valid?
        A2M::Escalier.instance_variable_set(:@modif, { grp: c[:grp] })
      end
      A2M::Escalier.transparent = false
      A2M::Escalier.poser(r, o, dir)
      g = A2M::Escalier.dernier
      if c && g && g.valid?
        c[:r] = r; c[:o] = o; c[:dir] = dir.clone; c[:grp] = g
        @fen.execute_script('pose(true)') if @fen && (@fen.visible? rescue false)
      end
    end

    def self.maj(json)
      c = @cur
      return unless c && c[:o]
      r = (JSON.parse(json.to_s) rescue nil) or return
      c[:r] = r
      A2M::Escalier.instance_variable_set(:@modif, { grp: c[:grp] })
      A2M::Escalier.transparent = true
      A2M::Escalier.poser(r, c[:o], c[:dir])
      g = A2M::Escalier.dernier
      c[:grp] = g if g && g.valid?
    end

    def self.valider
      g = @cur && @cur[:grp]
      Sketchup.active_model.selection.clear
      Sketchup.active_model.selection.add(g) if g && g.valid?
      @cur = nil
      @fen.close if @fen
    end

    def self.supprimer
      g = @cur && @cur[:grp]
      if g && g.valid?
        Sketchup.active_model.start_operation('Supprimer l\'escalier', true)
        g.erase!
        Sketchup.active_model.commit_operation
      end
      @cur[:grp] = nil if @cur
    end
  end
end
