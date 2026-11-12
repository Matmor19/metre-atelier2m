# encoding: UTF-8
# Métré Atelier 2M : fenêtre du garde-corps avec élévation d'une travée et vue de dessus du tracé, à l'échelle.
# Les réglages (hauteur, entraxe, espacement des barreaux, câbles, lisses, section des poteaux…) refont le garde-corps en direct.
require 'sketchup.rb'
require 'json'

module A2M
  module GardeCorps
    class << self
      alias_method :ouvrir_classique, :ouvrir unless method_defined?(:ouvrir_classique)
      alias_method :modifier_classique, :modifier unless method_defined?(:modifier_classique)
      def ouvrir(*_a) A2M::GardeCorpsFenetre.ouvrir end
      def modifier(grp, d) A2M::GardeCorpsFenetre.modifier(grp, d) end
    end
  end

  module GardeCorpsFenetre
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
      <h2>Élévation d'une travée</h2>
      <svg id="elev" class="vue" viewBox="0 0 520 260" style="height:260px"></svg>
      <div class="info" id="info"></div>
      <h2>Vue de dessus du tracé</h2>
      <svg id="plan" class="vue" viewBox="0 0 520 200" style="height:200px"></svg>
      <h2>Remplissage</h2>
      <div class="grille" id="rempl"></div>
      <div id="champs"></div>
      <h2>Fixation des poteaux</h2>
      <div class="grille" id="fixg"></div>
      <div class="puces" id="cotep" style="display:none"></div>
      <h2>Main courante</h2>
      <div class="puces" id="mcp"></div>
      <h2>Matière</h2>
      <div class="puces" id="mat"></div>
      <h2>Profil des pièces</h2>
      <div class="puces" id="prof"></div>
      <h2>Sur quoi</h2>
      <div class="puces" id="cible"></div>
      <div class="petit">« Tracé sélectionné » : sélectionnez des arêtes (bord de dalle, de balcon, limon d'escalier) avant de cliquer « Poser ». « Escaliers » : les côtés libres des escaliers posés avec l'outil Escalier.</div>
      <div class="rang"><button type="button" class="btn fort" id="placer">Poser le garde-corps</button></div>
      <div class="rang" id="fin" style="display:none"><button type="button" class="btn fort" id="valider">Valider</button><button type="button" class="btn" id="suppr">Supprimer ce garde-corps</button></div>
      <div id="bas"><div id="msg"></div></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      var P = { r: 'barreaux', mat: 'Métal noir', cible: 'sel', haut: 100, ent: 120, esp: 10, pas: 10, nl: 3, pot: 4, bas: 8, prof: 'rond', fort: true, fix: 'plat', mc: 'tube', cote: 1 }, placed = false, tmr = null, T = null;
      var CH = [['haut', 'Hauteur (cm)', 80, 130, 1, null], ['ent', 'Entraxe des poteaux (cm)', 60, 200, 1, null], ['pot', 'Section des poteaux (cm)', 2, 10, 0.5, null],
                ['bas', 'Vide sous le remplissage (cm)', 2, 15, 0.5, null],
                ['esp', 'Espacement maximal des barreaux (cm)', 5, 15, 0.5, 'barreaux,grille'], ['pas', 'Écart entre les câbles (cm)', 5, 15, 0.5, 'cables,grille'], ['nl', 'Nombre de lisses', 1, 6, 1, 'lisses']];
      function envoyer() { clearTimeout(tmr); tmr = setTimeout(function () { if (placed) sketchup.maj(JSON.stringify(P)); }, 80); }
      function pose(v, t) { placed = v; T = t || T; el('placer').textContent = v ? 'Replacer sur la sélection' : 'Poser le garde-corps'; el('fin').style.display = v ? 'flex' : 'none'; dessiner(); }
      function init(p, pl) { for (var k in p) { P[k] = (typeof P[k] === 'number') ? (parseFloat(String(p[k]).replace(',', '.')) || P[k]) : p[k]; } placed = !!pl; rendre(); champs(true); pose(!!pl); }
      function rendre() {
        var g = el('rempl'); g.innerHTML = '';
        D.rempl.forEach(function (t) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte' + (P.r === t.cle ? ' rempli' : '');
          var m = { barreaux: '<path d="M10 10 V32 M16 10 V32 M22 10 V32 M28 10 V32 M34 10 V32 M38 10 V32"/>', cables: '<path d="M8 14 H40 M8 20 H40 M8 26 H40 M8 32 H40"/>', verre: '<rect x="9" y="12" width="30" height="20"/>', lisses: '<path d="M8 16 H40 M8 24 H40 M8 32 H40"/>', plein: '<rect x="9" y="14" width="30" height="18" fill="#ddd"/>', verre_pinces: '<rect x="11" y="12" width="26" height="20" fill="#cfe6f5"/><circle cx="11" cy="16" r="2"/><circle cx="11" cy="28" r="2"/><circle cx="37" cy="16" r="2"/><circle cx="37" cy="28" r="2"/>', verre_profil: '<rect x="9" y="10" width="30" height="20" fill="#cfe6f5"/><rect x="8" y="30" width="32" height="4" fill="#999"/>', grille: '<path d="M12 10 V32 M20 10 V32 M28 10 V32 M36 10 V32 M8 16 H40 M8 22 H40 M8 28 H40"/>' }[t.cle];
          b.innerHTML = '<div class="vignette"><svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1.2"><path d="M8 8 H40" stroke="#E07838" stroke-width="2.4"/>' + m + '</svg></div><span></span><div class="petit" style="margin:2px 0 0"></div>';
          b.querySelector('span').textContent = t.libelle; b.querySelector('.petit').textContent = t.aide;
          b.addEventListener('click', function () { P.r = t.cle; rendre(); champs(false); dessiner(); envoyer(); }); g.appendChild(b);
        });
        var m = el('mat'); m.innerHTML = '';
        D.mat.forEach(function (x) { var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (P.mat === x ? ' rempli' : ''); b.textContent = x; b.addEventListener('click', function () { P.mat = x; rendre(); envoyer(); }); m.appendChild(b); });
        var pf = el('prof'); pf.innerHTML = '';
        [['rond', 'Rond'], ['carre', 'Carré']].forEach(function (x) { var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (P.prof === x[0] ? ' rempli' : ''); b.textContent = x[1]; b.addEventListener('click', function () { P.prof = x[0]; rendre(); envoyer(); }); pf.appendChild(b); });
        var fb = document.createElement('button'); fb.type = 'button'; fb.className = 'puce' + (P.fort ? ' rempli' : ''); fb.textContent = 'Poteaux d\u2019extrémité renforcés'; fb.addEventListener('click', function () { P.fort = !P.fort; rendre(); envoyer(); }); pf.appendChild(fb);
        var fg = el('fixg'); fg.innerHTML = '';
        D.fix.forEach(function (t) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte' + (P.fix === t.cle ? ' rempli' : '');
          var m = { plat: '<rect x="18" y="8" width="5" height="22"/><rect x="10" y="30" width="22" height="3" fill="#bbb"/><circle cx="13" cy="28" r="1"/><circle cx="29" cy="28" r="1"/>', rosace: '<rect x="18" y="8" width="5" height="22"/><ellipse cx="20.5" cy="31" rx="12" ry="3" fill="#bbb"/>', lateral: '<rect x="28" y="6" width="12" height="30" fill="#ddd"/><rect x="21" y="8" width="5" height="28"/><rect x="26" y="26" width="2" height="9" fill="#bbb"/>', scelle: '<rect x="4" y="26" width="40" height="10" fill="#ddd"/><rect x="18" y="8" width="5" height="26"/><rect x="15" y="25" width="11" height="2" fill="#bbb"/>', aucune: '<rect x="18" y="8" width="5" height="26"/><path d="M6 34 H36"/>' }[t.cle];
          b.innerHTML = '<div class="vignette"><svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1.2">' + m + '</svg></div><span></span><div class="petit" style="margin:2px 0 0"></div>';
          b.querySelector('span').textContent = t.libelle; b.querySelector('.petit').textContent = t.aide;
          b.addEventListener('click', function () { P.fix = t.cle; rendre(); dessiner(); envoyer(); }); fg.appendChild(b);
        });
        var cp = el('cotep'); cp.innerHTML = ''; cp.style.display = P.fix === 'lateral' ? 'flex' : 'none';
        [[1, 'Poteau à gauche du tracé'], [-1, 'Poteau à droite du tracé']].forEach(function (x) { var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (P.cote === x[0] ? ' rempli' : ''); b.textContent = x[1]; b.addEventListener('click', function () { P.cote = x[0]; rendre(); envoyer(); }); cp.appendChild(b); });
        var mp = el('mcp'); mp.innerHTML = '';
        D.mains.forEach(function (x) { var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (P.mc === x[0] ? ' rempli' : ''); b.textContent = x[1]; b.addEventListener('click', function () { P.mc = x[0]; rendre(); dessiner(); envoyer(); }); mp.appendChild(b); });
        var c = el('cible'); c.innerHTML = '';
        [['sel', 'Tracé sélectionné'], ['esc', 'Escaliers']].forEach(function (x) { var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (P.cible === x[0] ? ' rempli' : ''); b.textContent = x[1]; b.addEventListener('click', function () { P.cible = x[0]; rendre(); }); c.appendChild(b); });
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
            r.addEventListener('input', function () { v.value = r.value.replace('.', ','); P[c[0]] = parseFloat(r.value); dessiner(); envoyer(); });
            v.addEventListener('input', function () { var x = parseFloat(v.value.replace(',', '.')); if (!isNaN(x)) { P[c[0]] = x; if (x > +r.max) r.max = x; r.value = x; dessiner(); envoyer(); } });
          });
        }
        CH.forEach(function (c) { var r = el('r_' + c[0]), v = el('v_' + c[0]); el('w_' + c[0]).style.display = (!c[5] || c[5].split(',').indexOf(P.r) >= 0) ? 'grid' : 'none'; if (reset || document.activeElement !== v) { r.value = P[c[0]]; v.value = (+P[c[0]]).toString().replace('.', ','); } });
      }
      function dessiner() {
        var W = 520, H = 260, L = P.ent, h = P.haut, pot = P.pot, bas = P.bas;
        var k = Math.min((W - 60) / (L + 2 * pot), (H - 95) / (h + 6));
        function X(x) { return 30 + (x + pot) * k + ((W - 60) - (L + 2 * pot) * k) / 2; } function Z(z) { return H - 70 - z * k; }
        var c = '#3C3C3C', o = '<line x1="10" y1="' + Z(0) + '" x2="510" y2="' + Z(0) + '" stroke="#6f665e"/>';
        function R(x0, z0, x1, z1, f) { return '<rect x="' + X(x0) + '" y="' + Z(z1) + '" width="' + ((x1 - x0) * k) + '" height="' + ((z1 - z0) * k) + '" fill="' + (f || c) + '"/>'; }
        var info = '', ok = true;
        if (P.r === 'barreaux') { var nb = Math.floor(L / P.esp), sp = L / (nb + 1); for (var i = 1; i <= nb; i++) o += R(sp * i - 0.7, bas, sp * i + 0.7, h - 2); o += R(0, bas, L, bas + 2); info = nb + ' barreaux, vide entre barreaux ' + (sp - 1.4).toFixed(1).replace('.', ',') + ' cm'; ok = (sp - 1.4) < 11; info += ok ? ' <span class="bon">✓ moins de 11 cm</span>' : ' <span class="mauvais">⚠ plus de 11 cm</span>'; }
        if (P.r === 'cables') { for (var z = 12; z < h - 4; z += P.pas) o += R(0, z - 0.3, L, z + 0.3, '#9aa0a6'); info = 'Câbles tous les ' + P.pas.toString().replace('.', ',') + ' cm'; }
        if (P.r === 'verre') { o += R(3, bas, L - 3, h - 4, 'rgba(120,180,215,.45)'); info = 'Panneau de verre entre les poteaux'; }
        if (P.r === 'lisses') { for (var j = 1; j <= P.nl; j++) o += R(0, h * j / (P.nl + 1) - 1, L, h * j / (P.nl + 1) + 1); info = P.nl + ' lisses'; }
        if (P.r === 'verre_pinces') { o += R(pot / 2 + 0.5, bas, L - pot / 2 - 0.5, h - 4, 'rgba(120,180,215,.45)'); [[pot / 2 + 2.5, bas + 8], [pot / 2 + 2.5, h - 12], [L - pot / 2 - 2.5, bas + 8], [L - pot / 2 - 2.5, h - 12]].forEach(function (q) { o += '<circle cx="' + X(q[0]) + '" cy="' + Z(q[1]) + '" r="' + (2.5 * k) + '" fill="#9aa0a6" stroke="#555"/>'; }); info = 'Verre sur 4 pinces par panneau'; }
        if (P.r === 'verre_profil') { o += R(0.5, 7, L - 0.5, h - (P.mc === 'aucune' ? 0 : 2), 'rgba(120,180,215,.45)') + R(-3, 0, L + 3, 8, '#9aa0a6'); info = 'Verre continu dans un profilé, sans poteau intermédiaire'; }
        if (P.r === 'grille') { var nb2 = Math.floor(L / P.esp), sp2 = L / (nb2 + 1); for (var i2 = 1; i2 <= nb2; i2++) o += R(sp2 * i2 - 0.4, bas, sp2 * i2 + 0.4, h - 2); for (var z2 = bas + P.pas / 2; z2 < h - 3; z2 += P.pas) o += R(0, z2 - 0.4, L, z2 + 0.4); info = 'Grille : tiges verticales tous les ' + P.esp.toString().replace('.', ',') + ' cm, horizontales tous les ' + P.pas.toString().replace('.', ',') + ' cm'; }
        if (P.r === 'plein') { o += R(2, bas, L - 2, h - 6, '#c8a574'); info = 'Panneau plein'; }
        var zb = { plat: 1, rosace: 1, lateral: -20, scelle: -10 }[P.fix] || 0;
        if (P.r !== 'verre_profil') o += R(-pot, zb, 0, h) + R(L, zb, L + pot, h);
        if (P.fix === 'plat') o += R(-6, 0, 6, 1, '#9aa0a6') + R(L - 6, 0, L + 6, 1, '#9aa0a6');
        if (P.fix === 'rosace') o += R(-6, 0, 6, 1, '#9aa0a6') + R(L - 6, 0, L + 6, 1, '#9aa0a6') + R(-pot * 0.8, 1, pot * 0.8, 2.5, '#9aa0a6') + R(L - pot * 0.8, 1, L + pot * 0.8, 2.5, '#9aa0a6');
        if (P.fix === 'scelle') o += R(-pot * 1.1, 0, pot * 1.1, 1.2, '#9aa0a6') + R(L - pot * 1.1, 0, L + pot * 1.1, 1.2, '#9aa0a6');
        if (P.fix === 'lateral') o += R(-pot / 2 - 1, -16, -pot / 2, 4, '#9aa0a6') + R(L + pot / 2, -16, L + pot / 2 + 1, 4, '#9aa0a6');
        if (P.mc === 'tube') o += R(-pot - 0.5, h - 4, L + pot + 0.5, h); else if (P.mc === 'plat') o += R(-pot - 0.5, h - 3.5, L + pot + 0.5, h);
        o += '<text x="12" y="16" font-size="10" fill="#8a7f75">hauteur ' + h + ' cm, entraxe ' + L + ' cm</text>';
        var hn = h >= 100 ? '<span class="bon">✓ hauteur d’au moins 100 cm</span>' : '<span class="mauvais">⚠ moins de 100 cm</span>';
        el('elev').innerHTML = o; el('info').innerHTML = info + ' · ' + hn;
        // plan : tracé envoyé par SketchUp
        var p = el('plan');
        if (!T || !T.chemins.length) { p.innerHTML = '<text x="20" y="100" font-size="12" fill="#8a7f75">Le tracé apparaîtra ici quand le garde-corps sera posé.</text>'; return; }
        var xs = [], ys = []; T.chemins.forEach(function (ch) { ch.forEach(function (q) { xs.push(q[0]); ys.push(q[1]); }); });
        var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs), y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys), w2 = 520, h2 = 200;
        var k2 = Math.min((w2 - 40) / Math.max(x1 - x0, 0.1), (h2 - 40) / Math.max(y1 - y0, 0.1));
        function X2(x) { return 20 + (x - x0) * k2 + ((w2 - 40) - (x1 - x0) * k2) / 2; } function Y2(y) { return h2 - 20 - (y - y0) * k2 - ((h2 - 40) - (y1 - y0) * k2) / 2; }
        var s = '';
        T.chemins.forEach(function (ch) { s += '<polyline points="' + ch.map(function (q) { return X2(q[0]) + ',' + Y2(q[1]); }).join(' ') + '" fill="none" stroke="#6f665e" stroke-width="3"/>'; });
        T.poteaux.forEach(function (q) { s += '<rect x="' + (X2(q[0]) - 3.5) + '" y="' + (Y2(q[1]) - 3.5) + '" width="7" height="7" fill="#E07838"/>'; });
        s += '<text x="12" y="16" font-size="10" fill="#8a7f75">' + T.poteaux.length + ' poteaux, ' + T.ml.toFixed(2).replace('.', ',') + ' ml</text>';
        p.innerHTML = s;
      }
      el('placer').addEventListener('click', function () { sketchup.placer(JSON.stringify(P)); });
      el('valider').addEventListener('click', function () { sketchup.valider(''); });
      el('suppr').addEventListener('click', function () { sketchup.supprimer(''); pose(false, { chemins: [], poteaux: [], ml: 0 }); });
      rendre(); champs(true); dessiner();
      sketchup.pret('');
    JS

    def self.ouvrir
      @cur = { r: nil, chs: nil, grps: [] }
      afficher
    end

    def self.modifier(grp, d)
      return UI.messagebox('Ce garde-corps n\'a pas gardé son tracé : reposez-le une fois.') unless d && d['r'] && d['pts']
      @cur = { r: d['r'].reject { |k, _| k == 'replacer' }, chs: [A2M::Modif.pts_de(d['pts'])], grps: [grp] }
      afficher
    end

    def self.afficher
      if @fen && (@fen.visible? rescue false)
        envoyer_init
        @fen.bring_to_front
        return
      end
      d = { 'fix' => A2M::GardeCorps::FIXATIONS.map { |k, l, a| { 'cle' => k, 'libelle' => l, 'aide' => a } }, 'mains' => A2M::GardeCorps::MAINS, 'rempl' => A2M::GardeCorps::REMPLISSAGES.map { |k, l, a| { 'cle' => k, 'libelle' => l, 'aide' => a } }, 'mat' => A2M::GardeCorps::MATIERES.keys }
      html = A2M::Panneau.page('Garde-corps', 'Élévation d\'une travée et tracé à l\'échelle : tout se règle ici', CORPS, SCRIPT, d)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : garde-corps', 'A2M_Panneau_GCFen', html, 580, 1000)
      @fen = dlg
      dlg.add_action_callback('pret') { |_c, _j| UI.start_timer(0, false) { envoyer_init } }
      dlg.add_action_callback('placer') { |_c, json| UI.start_timer(0, false) { placer(json) } }
      dlg.add_action_callback('maj') { |_c, json| UI.start_timer(0, false) { maj(json) } }
      dlg.add_action_callback('valider') { |_c, _j| UI.start_timer(0, false) { valider } }
      dlg.add_action_callback('supprimer') { |_c, _j| UI.start_timer(0, false) { supprimer } }
      dlg.set_on_closed { @fen = nil; @cur = nil }
      dlg.show
    end

    def self.envoyer_init
      return unless @fen && @cur
      pose = @cur[:grps].any? { |g| g && g.valid? }
      @fen.execute_script("init(#{JSON.generate(@cur[:r] || {})},#{pose ? 'true' : 'false'})")
      envoyer_trace(0.0) if pose
    end

    def self.msg(t) @fen.execute_script("document.getElementById('msg').textContent=#{JSON.generate(t)}") if @fen && (@fen.visible? rescue false) end

    def self.envoyer_trace(ml)
      return unless @fen && @cur && @cur[:chs]
      ch = @cur[:chs].map { |c| c.map { |q| [q.x.to_m.round(3), q.y.to_m.round(3)] } }
      po = (A2M::GardeCorps.posts || []).map { |q| [q.x.to_m.round(3), q.y.to_m.round(3)] }
      ml = @cur[:ml].to_f if ml.to_f == 0.0 && @cur[:ml]
      @fen.execute_script("pose(true,#{JSON.generate('chemins' => ch, 'poteaux' => po, 'ml' => ml.to_f)})")
    end

    def self.placer(json)
      r = (JSON.parse(json.to_s) rescue nil) or return
      model = Sketchup.active_model
      chs = r['cible'] == 'esc' ? A2M::GardeCorps.chemins_escaliers(model) : A2M::GardeCorps.chemins_selection(model)
      if chs.empty?
        return msg(r['cible'] == 'esc' ? 'Aucun escalier de l\'outil Escalier dans le modèle.' : 'Sélectionnez d\'abord des arêtes (le tracé du garde-corps), puis cliquez de nouveau.')
      end
      msg('')
      @cur[:r] = r; @cur[:chs] = chs
      reconstruire(false)
    end

    def self.reconstruire(transparent)
      c = @cur
      gs, ml = A2M::GardeCorps.refaire(c[:chs], c[:r], c[:grps], transparent)
      c[:grps] = gs; c[:ml] = ml
      envoyer_trace(ml)
    rescue StandardError => ex
      msg("Garde-corps impossible : #{ex.message}")
    end

    def self.maj(json)
      c = @cur
      return unless c && c[:chs] && c[:grps].any? { |g| g && g.valid? }
      r = (JSON.parse(json.to_s) rescue nil) or return
      c[:r] = r
      reconstruire(true)
    end

    def self.valider
      gs = @cur ? @cur[:grps].select { |g| g && g.valid? } : []
      Sketchup.active_model.selection.clear
      gs.each { |g| Sketchup.active_model.selection.add(g) }
      @cur = nil
      @fen.close if @fen
    end

    def self.supprimer
      return unless @cur
      gs = @cur[:grps].select { |g| g && g.valid? }
      unless gs.empty?
        Sketchup.active_model.start_operation('Supprimer le garde-corps', true)
        gs.each(&:erase!)
        Sketchup.active_model.commit_operation
      end
      @cur[:grps] = []
    end
  end
end
