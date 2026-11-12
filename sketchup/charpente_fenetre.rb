# encoding: UTF-8
# Métré Atelier 2M : fenêtre de la charpente avec coupe d'un pan à l'échelle ; chaque réglage refait la charpente en direct sous tous les pans.
require 'sketchup.rb'
require 'json'

module A2M
  module CharpenteFenetre
    CORPS = <<~'HTML'
      <style>
        .champ{display:grid;grid-template-columns:1fr 78px;gap:4px 10px;align-items:center;margin:7px 0}
        .champ label{font-size:11.5px;color:#6f665e}.champ input[type=range]{grid-column:1 / 3;width:100%;accent-color:#E07838;margin:0}
        .champ input[type=text]{font-size:13px;padding:4px 6px;border-radius:7px}
        .vue{background:#fff;border:1px solid #d8d0c6;border-radius:12px;width:100%;display:block}
        .info{font-size:12px;color:#6f665e;margin:6px 0}
      </style>
      <h2>Coupe d'un pan (à l'échelle)</h2>
      <svg id="coupe" class="vue" viewBox="0 0 520 230" style="height:230px"></svg>
      <div class="info" id="info"></div>
      <h2>Chevrons</h2>
      <div class="puces" id="sec"></div>
      <div id="champs"></div>
      <h2>Ce qui est posé</h2>
      <div class="puces" id="opts"></div>
      <h2>Bilan pour tous les pans</h2>
      <div class="info" id="bilan">Touchez un réglage : la charpente se pose sous tous les pans de la toiture.</div>
      <div id="bas"><div id="msg"></div><button type="button" id="fin">Terminer</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      var P = { sec: '6 × 15', ent: 60, pas: 32, chev: true, contre: true, lit: true, faitiere: true, sabliere: true, cible: 'tout' }, tmr = null;
      var CH = [['ent', 'Entraxe des chevrons (cm)', 40, 100, 1], ['pas', 'Pas des liteaux (cm) : tuile mécanique 33, ardoise 22 à 25', 15, 45, 0.5]];
      function envoyer() { clearTimeout(tmr); tmr = setTimeout(function () { sketchup.maj(JSON.stringify(P)); }, 150); }
      function init(p) { for (var k in p) { P[k] = (typeof P[k] === 'number') ? (parseFloat(String(p[k]).replace(',', '.')) || P[k]) : p[k]; } rendre(); champs(true); dessiner(); }
      function rendre() {
        var c = el('sec'); c.innerHTML = '';
        D.sec.forEach(function (x) { var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (P.sec === x ? ' rempli' : ''); b.textContent = x; b.addEventListener('click', function () { P.sec = x; rendre(); dessiner(); envoyer(); }); c.appendChild(b); });
        var o = el('opts'); o.innerHTML = '';
        [['chev', 'Chevrons'], ['contre', 'Contre-liteaux'], ['lit', 'Liteaux'], ['faitiere', 'Faîtière'], ['sabliere', 'Sablière']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (P[x[0]] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { P[x[0]] = !P[x[0]]; rendre(); dessiner(); envoyer(); }); o.appendChild(b);
        });
      }
      function champs(reset) {
        var z = el('champs');
        if (z.children.length === 0) {
          CH.forEach(function (c) {
            var w = document.createElement('div'); w.className = 'champ';
            w.innerHTML = '<label></label><input type="text" id="v_' + c[0] + '"><input type="range" id="r_' + c[0] + '">';
            w.querySelector('label').textContent = c[1]; z.appendChild(w);
            var r = w.querySelector('[type=range]'), v = w.querySelector('[type=text]'); r.min = c[2]; r.max = c[3]; r.step = c[4];
            r.addEventListener('input', function () { v.value = r.value.replace('.', ','); P[c[0]] = parseFloat(r.value); dessiner(); envoyer(); });
            v.addEventListener('input', function () { var x = parseFloat(v.value.replace(',', '.')); if (!isNaN(x)) { P[c[0]] = x; r.value = x; dessiner(); envoyer(); } });
          });
        }
        CH.forEach(function (c) { var r = el('r_' + c[0]), v = el('v_' + c[0]); if (reset || document.activeElement !== v) { r.value = P[c[0]]; v.value = String(P[c[0]]).replace('.', ','); } });
      }
      function dessiner() {
        var L = D.pan.long || 400, a = (D.pan.pente || 30) * Math.PI / 180, sec = P.sec.replace(',', '.').split('×'), ch = parseFloat(sec[1]) || 15;
        var W = 520, H = 230, k = Math.min((W - 80) / (L * Math.cos(a)), (H - 70) / (L * Math.sin(a) + 20));
        function X(s) { return 40 + s * Math.cos(a) * k; } function Y(s) { return H - 30 - s * Math.sin(a) * k; }
        var o = '<line x1="20" y1="' + (H - 30) + '" x2="500" y2="' + (H - 30) + '" stroke="#b9afa4" stroke-dasharray="4 3"/>';
        function bar(s0, s1, ep, fill) { var nx = -Math.sin(a) * ep * k, ny = -Math.cos(a) * ep * k; return '<polygon fill="' + fill + '" stroke="#8a7f75" stroke-width="0.8" points="' + X(s0) + ',' + Y(s0) + ' ' + X(s1) + ',' + Y(s1) + ' ' + (X(s1) + nx) + ',' + (Y(s1) + ny) + ' ' + (X(s0) + nx) + ',' + (Y(s0) + ny) + '"/>'; }
        if (P.chev) o += bar(0, L, ch, '#d6b282');
        var n = 0;
        if (P.lit) for (var s = P.pas; s < L - 2; s += P.pas) { n++; var cx = X(s), cy = Y(s), nx = -Math.sin(a) * (ch + 7) * k, ny = -Math.cos(a) * (ch + 7) * k; o += '<rect x="' + (cx + nx - 3) + '" y="' + (cy + ny - 3) + '" width="6" height="6" fill="#a8541f" transform="rotate(' + (-a * 180 / Math.PI) + ' ' + (cx + nx) + ' ' + (cy + ny) + ')"/>'; }
        if (P.contre) o += bar(0, L, 0, 'none');
        if (P.sabliere) { o += '<rect x="' + (X(0) - 4) + '" y="' + (Y(0) - 15 * k) + '" width="' + (7.5 * k) + '" height="' + (15 * k) + '" fill="#c79a62" stroke="#8a7f75"/>'; }
        if (P.faitiere) { o += '<rect x="' + (X(L) - 6) + '" y="' + (Y(L) - 22 * k) + '" width="' + (7.5 * k) + '" height="' + (22 * k) + '" fill="#c79a62" stroke="#8a7f75"/>'; }
        o += '<text x="12" y="16" font-size="10" fill="#8a7f75">chevron : ' + Math.round(L) + ' cm de long, pente ' + (D.pan.pente || '?') + '°</text>';
        el('coupe').innerHTML = o;
        el('info').textContent = P.lit ? ((n) + ' liteaux sur ce pan, un tous les ' + String(P.pas).replace('.', ',') + ' cm') : '';
      }
      function bilan(b) {
        if (!b) { el('bilan').textContent = 'Aucun pan trouvé : générez la toiture d’abord.'; return; }
        el('bilan').innerHTML = b.pans + ' pan(s) : ' + b.chevrons + ' chevrons (' + b.ml_chevrons + ' ml), liteaux ' + b.ml_liteaux + ' ml, contre-liteaux ' + b.ml_contre + ' ml, sablière ' + b.ml_sabliere + ' ml, faîtière ' + b.ml_faitiere + ' ml.<br><b>Bois : ' + b.m3 + ' m³</b> (hors chutes)';
      }
      el('fin').addEventListener('click', function () { sketchup.fin(''); });
      sketchup.pret('');
    JS

    def self.ouvrir(pre = nil)
      @pre = pre
      if @fen && (@fen.visible? rescue false)
        envoyer_init
        @fen.bring_to_front
        return
      end
      d = { 'sec' => A2M::Charpente::SECTIONS.keys, 'pan' => (A2M::Charpente.infos_pan || { 'pente' => 30, 'long' => 400 }) }
      html = A2M::Panneau.page('Charpente', 'Coupe à l\'échelle, réglages en direct sous tous les pans', CORPS, SCRIPT, d)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : charpente', 'A2M_Panneau_CharpFen', html, 560, 860)
      @fen = dlg
      dlg.add_action_callback('pret') { |_c, _j| UI.start_timer(0, false) { envoyer_init; appliquer(@pre) if @pre } }
      dlg.add_action_callback('maj') { |_c, json| UI.start_timer(0, false) { r = (JSON.parse(json.to_s) rescue nil); appliquer(r) if r } }
      dlg.add_action_callback('fin') { |_c, _j| UI.start_timer(0, false) { @fen.close if @fen } }
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end

    def self.envoyer_init
      return unless @fen
      @fen.execute_script("init(#{JSON.generate(@pre || {})})")
    end

    def self.appliquer(r)
      r = (r || { 'sec' => '6 × 15', 'ent' => 60, 'pas' => 32, 'chev' => true, 'contre' => true, 'lit' => true, 'faitiere' => true, 'sabliere' => true }).merge('cible' => 'tout')
      @pre = r
      A2M::Charpente.poser(r, true)
      @fen.execute_script("bilan(#{JSON.generate(A2M::Charpente.bilan)})") if @fen && (@fen.visible? rescue false)
    end

    def self.modifier(_grp, d)
      return UI.messagebox('Cette charpente n\'a pas gardé ses réglages : reposez-la une fois.') unless d && d['r']
      ouvrir(d['r'])
    end
  end

  module Charpente
    class << self
      alias_method :ouvrir_classique, :ouvrir unless method_defined?(:ouvrir_classique)
      alias_method :modifier_classique, :modifier unless method_defined?(:modifier_classique)
      def ouvrir(*_a) A2M::CharpenteFenetre.ouvrir end
      def modifier(grp, d) A2M::CharpenteFenetre.modifier(grp, d) end
    end
  end
end
