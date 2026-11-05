# encoding: UTF-8
# Métré Atelier 2M : relevé de côtes — vous tapez les mesures prises sur place, la pièce se dessine toute seule.
# Une pièce rectangulaire : deux côtes. Une pièce quelconque : côté par côté, avec l'angle à chaque coin.
require 'sketchup.rb'
require 'json'

module A2M
  module Releve
    CORPS = <<~'HTML'
      <h2>Nom de la pièce</h2><input type="text" id="nom" value="Séjour" style="text-align:left;font-size:15px">
      <h2>Forme</h2><div class="puces" id="formes"></div>
      <div id="rect" style="margin-top:10px">
        <div class="dims"><div><label>Longueur</label><input type="text" id="lon" value="500"></div><div class="x">×</div><div><label>Largeur</label><input type="text" id="lar" value="400"></div></div>
        <div class="unite">en cm</div>
      </div>
      <div id="libre" style="display:none;margin-top:10px">
        <div class="petit" style="margin:0 0 6px">Partez d'un coin, tournez toujours dans le même sens. Le dernier côté peut rester vide : il se ferme tout seul.</div>
        <div id="cotes"></div>
        <button type="button" class="puce" id="plus" style="margin-top:6px">+ Ajouter un côté</button>
      </div>
      <h2>Aperçu</h2><div class="apercu"><svg id="svg" viewBox="0 0 300 170"></svg></div>
      <div class="petit" id="info"></div>
      <div id="bas"><div id="msg"></div><button type="button" id="go">Dessiner la pièce</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      var forme = 'rect', cotes = [{ l: 500, a: 90 }, { l: 400, a: 90 }, { l: 500, a: 90 }, { l: '', a: 90 }];
      function el(id) { return document.getElementById(id); }
      function num(v) { return parseFloat(String(v).replace(',', '.')) || 0; }
      function points() {
        if (forme === 'rect') { var L = num(el('lon').value), W = num(el('lar').value); return L > 0 && W > 0 ? { pts: [[0, 0], [L, 0], [L, W], [0, W]], ecart: 0 } : { pts: [], ecart: 0 }; }
        var x = 0, y = 0, h = 0, pts = [[0, 0]], ecart = 0;
        for (var i = 0; i < cotes.length; i++) {
          var l = num(cotes[i].l), last = (i === cotes.length - 1);
          if (!l && last) break;
          if (!l) continue;
          x += l * Math.cos(h * Math.PI / 180); y += l * Math.sin(h * Math.PI / 180);
          h += num(cotes[i].a);
          pts.push([x, y]);
        }
        var n = pts.length;
        if (n > 1) { var d = Math.hypot(pts[n - 1][0], pts[n - 1][1]); if (d < 1.5) pts.pop(); else ecart = d; }
        return { pts: pts, ecart: ecart };
      }
      function rendre() {
        var f = el('formes'); f.innerHTML = '';
        [['rect', 'Pièce rectangulaire'], ['libre', 'Côté par côté']].forEach(function (a) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (forme === a[0] ? ' rempli' : ''); b.textContent = a[1];
          b.addEventListener('click', function () { forme = a[0]; rendre(); }); f.appendChild(b);
        });
        el('rect').style.display = forme === 'rect' ? '' : 'none'; el('libre').style.display = forme === 'libre' ? '' : 'none';
        var c = el('cotes'); c.innerHTML = '';
        cotes.forEach(function (k, i) {
          var d = document.createElement('div'); d.style.cssText = 'display:flex;gap:8px;align-items:center;margin-bottom:5px';
          d.innerHTML = '<span class="petit" style="width:54px;margin:0">Côté ' + (i + 1) + '</span><input type="text" style="flex:1;font-size:14px;padding:5px" placeholder="longueur cm"><span class="petit" style="margin:0">puis tourner de</span><input type="text" style="width:60px;font-size:14px;padding:5px"><span class="petit" style="margin:0">°</span>';
          var v = d.querySelectorAll('input'); v[0].value = k.l; v[1].value = k.a;
          v[0].addEventListener('input', function () { k.l = v[0].value; dessin(); }); v[1].addEventListener('input', function () { k.a = v[1].value; dessin(); });
          c.appendChild(d);
        });
        dessin();
      }
      function dessin() {
        var r = points(), p = r.pts, s = el('svg');
        if (p.length < 3) { s.innerHTML = '<text x="150" y="88" text-anchor="middle" fill="#8a7f75" font-size="12">Entrez les côtes…</text>'; el('info').textContent = ''; el('go').disabled = true; return; }
        var xs = p.map(function (q) { return q[0]; }), ys = p.map(function (q) { return q[1]; });
        var x0 = Math.min.apply(null, xs), x1 = Math.max.apply(null, xs), y0 = Math.min.apply(null, ys), y1 = Math.max.apply(null, ys);
        var k = Math.min(260 / ((x1 - x0) || 1), 130 / ((y1 - y0) || 1)), ox = 150 - k * (x0 + x1) / 2, oy = 85 + k * (y0 + y1) / 2;
        var d = p.map(function (q, i) { return (i ? 'L' : 'M') + (ox + k * q[0]).toFixed(1) + ' ' + (oy - k * q[1]).toFixed(1); }).join(' ') + ' Z';
        var t = ''; for (var i = 0; i < p.length; i++) { var a = p[i], b = p[(i + 1) % p.length], L = Math.hypot(b[0] - a[0], b[1] - a[1]); t += '<text x="' + (ox + k * (a[0] + b[0]) / 2).toFixed(1) + '" y="' + (oy - k * (a[1] + b[1]) / 2 - 3).toFixed(1) + '" text-anchor="middle" font-size="9" fill="#3C3C3C">' + Math.round(L) + '</text>'; }
        s.innerHTML = '<path d="' + d + '" fill="rgba(224,120,56,.28)" stroke="#E07838" stroke-width="2" stroke-linejoin="round"/>' + t;
        var a2 = 0; for (var j = 0; j < p.length; j++) { var u = p[j], w = p[(j + 1) % p.length]; a2 += u[0] * w[1] - w[0] * u[1]; }
        el('info').textContent = 'Surface : ' + (Math.abs(a2) / 2 / 10000).toFixed(2).replace('.', ',') + ' m²' + (r.ecart ? ' — ⚠ il manque ' + Math.round(r.ecart) + ' cm pour fermer : vérifiez vos côtes' : ' ✓ la pièce se ferme');
        el('go').disabled = false;
      }
      el('plus').addEventListener('click', function () { cotes.splice(cotes.length - 1, 0, { l: '', a: 90 }); rendre(); });
      ['nom', 'lon', 'lar'].forEach(function (i) { el(i).addEventListener('input', dessin); });
      el('go').addEventListener('click', function () {
        var r = points(); if (r.pts.length < 3) return;
        sketchup.dessiner(JSON.stringify({ nom: el('nom').value, pts: r.pts }));
      });
      rendre();
    JS

    # Dessine la pièce : groupe nommé, sur la balise A2M_PIECE, posé à droite de ce qui existe déjà
    def self.dessiner(nom, pts)
      model = Sketchup.active_model
      nom = nom.to_s.strip.empty? ? 'Pièce' : nom.to_s.strip
      model.start_operation('Relevé de côtes : ' + nom, true)
      bb = model.bounds
      dx = bb.empty? ? 0.0 : bb.max.x.to_m + 1.0
      g = model.active_entities.add_group
      f = g.entities.add_face(pts.map { |x, y| Geom::Point3d.new((dx + x / 100.0).m, (y / 100.0).m, 0) })
      f.reverse! if f.normal.z < 0
      lb, _ = A2M::Balises.balise(model, 'A2M_PIECE', [120, 200, 120])
      g.layer = lb
      g.name = nom
      A2M::Hachures.poser(g, model) rescue nil
      model.selection.clear
      model.selection.add(g)
      model.commit_operation
      model.active_view.zoom(g) rescue nil
      Sketchup.status_text = "#{nom} : #{(f.area * 0.00064516).round(2)} m²"
    rescue StandardError => ex
      model.abort_operation
      UI.messagebox("Dessin impossible : #{ex.message}")
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      html = A2M::Panneau.page('Relevé de côtes', 'Tapez les mesures prises sur place : la pièce se dessine', CORPS, SCRIPT, {})
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : relevé de côtes', 'A2M_Panneau_Releve', html, 440, 700)
      @fen = dlg
      dlg.add_action_callback('dessiner') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) { dessiner(r['nom'], r['pts']) } if r && r['pts'].is_a?(Array) && r['pts'].size >= 3
      end
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
