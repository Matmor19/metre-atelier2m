# encoding: UTF-8
# Métré Atelier 2M : charpente traditionnelle sous les pans de toiture (chevrons, contre-liteaux, liteaux, faîtière, sablière) avec métrés
require 'sketchup.rb'
require 'json'

module A2M
  module Charpente
    TAG = 'A2M_CHARPENTE'
    SECTIONS = { '6 × 15' => [6, 15], '6 × 18' => [6, 18], '7,5 × 22' => [7.5, 22], '8 × 20' => [8, 20] }.freeze

    CORPS = <<~'HTML'
      <h2>Chevrons</h2>
      <div class="puces" id="sec"></div>
      <div class="dims">
        <div><label>Entraxe chevrons (cm)</label><input type="text" id="ent" value="60"></div>
        <div><label>Pas des liteaux (cm)</label><input type="text" id="pas" value="32"></div>
      </div>
      <div class="petit">Le pas des liteaux suit votre couverture : tuile mécanique 33, ardoise 22 à 25 (ou voligeage), zinc : voligeage plein.</div>
      <h2>Ce qui est posé</h2>
      <div class="puces" id="opts"></div>
      <h2>Sur quoi</h2>
      <div class="puces" id="cible"></div>
      <div id="bas"><div id="msg"></div><button type="button" id="go">Poser la charpente</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      var s = { sec: '6 × 15', cible: 'tout', chev: true, contre: true, lit: true, faitiere: true, sabliere: true };
      function rendre() {
        var c = el('sec'); c.innerHTML = '';
        D.sec.forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s.sec === x ? ' rempli' : ''); b.textContent = x;
          b.addEventListener('click', function () { s.sec = x; rendre(); }); c.appendChild(b);
        });
        var o = el('opts'); o.innerHTML = '';
        [['chev', 'Chevrons'], ['contre', 'Contre-liteaux'], ['lit', 'Liteaux'], ['faitiere', 'Faîtière'], ['sabliere', 'Sablière']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s[x[0]] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { s[x[0]] = !s[x[0]]; rendre(); }); o.appendChild(b);
        });
        var t = el('cible'); t.innerHTML = '';
        [['tout', 'Tous les pans'], ['sel', 'Pans sélectionnés']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s.cible === x[0] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { s.cible = x[0]; rendre(); }); t.appendChild(b);
        });
      }
      el('go').addEventListener('click', function () { s.ent = el('ent').value; s.pas = el('pas').value; sketchup.poser(JSON.stringify(s)); });
      rendre();
    JS

    def self.nombre(v, d) (Float(v.to_s.tr(',', '.')) rescue d) end

    # Barre orientée : a-b l'axe ; lat et up donnent la section l × h
    def self.barre(ents, a, b, lat, up, l, h, couleur)
      d = b - a
      return false if d.length < 1.cm
      d.normalize!
      pts = [a.offset(lat, -l / 2).offset(up, -h / 2), a.offset(lat, l / 2).offset(up, -h / 2), a.offset(lat, l / 2).offset(up, h / 2), a.offset(lat, -l / 2).offset(up, h / 2)]
      f = ents.add_face(pts)
      return false unless f
      f.reverse! if f.normal.dot(d) < 0
      f.pushpull(a.distance(b))
      true
    end

    def self.pan(model, face, t, r)
      n = (t * face.normal); n.normalize!
      pts = face.outer_loop.vertices.map { |v| t * v.position }
      bas = Z_AXIS.reverse
      pr = n.clone; pr.length = bas.dot(n)
      bas = bas - pr; bas.normalize!
      haut = bas.reverse
      u = haut.cross(n); u.normalize!
      zmin = pts.map(&:z).min
      o = pts.find { |p| (p.z - zmin).abs < 0.01 } || pts[0]
      poly = pts.map { |p| w = p - o; [w.dot(u) * 2.54, w.dot(haut) * 2.54] }
      sec = SECTIONS[r['sec']] || SECTIONS['6 × 15']
      cw = sec[0].cm; ch = sec[1].cm
      ent = nombre(r['ent'], 60); pas = nombre(r['pas'], 32)
      umin = poly.map(&:first).min; umax = poly.map(&:first).max
      vmin = poly.map(&:last).min; vmax = poly.map(&:last).max
      g = model.entities.add_group
      tg, _ = A2M::Balises.balise(model, TAG, [200, 160, 110])
      g.layer = tg
      g.name = 'Charpente – pan'
      e = g.entities
      at = ->(uu, vv, prof) { o.offset(u, uu.cm).offset(haut, vv.cm).offset(n, -prof) }
      ep_lit = 4.cm; ep_contre = 3.cm
      nc = 0; ml_ch = 0.0; ml_lit = 0.0; ml_ctr = 0.0
      z_lit = ep_lit / 2; z_ctr = ep_lit + ep_contre / 2; z_chev = ep_lit + ep_contre + ch / 2
      if r['chev']
        x = umin + ent / 2.0
        while x < umax
          A2M::Couverture.coupe_v(poly, x).each do |a, b|
            if barre(e, at.call(x, a, z_chev), at.call(x, b, z_chev), u, n, cw, ch, nil) then nc += 1; ml_ch += (b - a) / 100.0 end
          end
          x += ent
        end
      end
      if r['contre']
        x = umin + ent / 2.0
        while x < umax
          A2M::Couverture.coupe_v(poly, x).each { |a, b| ml_ctr += (b - a) / 100.0 if barre(e, at.call(x, a, z_ctr), at.call(x, b, z_ctr), u, n, 3.cm, ep_contre, nil) }
          x += ent
        end
      end
      if r['lit']
        v = vmin + pas
        while v < vmax - 2
          A2M::Couverture.coupe_h(poly, v).each { |a, b| ml_lit += (b - a) / 100.0 if barre(e, at.call(a, v, z_lit), at.call(b, v, z_lit), haut, n, 4.cm, ep_lit, nil) }
          v += pas
        end
      end
      if r['sabliere']
        A2M::Couverture.coupe_h(poly, vmin + 6).each { |a, b| barre(e, at.call(a, vmin + 6, ep_lit + ep_contre + 6.cm), at.call(b, vmin + 6, ep_lit + ep_contre + 6.cm), haut, n, 7.5.cm, 15.cm, nil) }
      end
      if r['faitiere']
        A2M::Couverture.coupe_h(poly, vmax - 8).each { |a, b| barre(e, at.call(a, vmax - 8, ep_lit + ep_contre + 11.cm), at.call(b, vmax - 8, ep_lit + ep_contre + 11.cm), haut, n, 7.5.cm, 22.cm, nil) }
      end
      c = Sketchup::Color.new(214, 178, 130)
      e.grep(Sketchup::Face).each { |f| f.material = c; f.back_material = c }
      A2M::Modif.noter(g, 'charpente', { 'r' => r.reject { |k, _| k == 'cible' } })
      g.set_attribute('a2m', 'charpente', JSON.generate('chevrons' => nc, 'ml_chevrons' => ml_ch.round(1), 'ml_liteaux' => ml_lit.round(1), 'ml_contre_liteaux' => ml_ctr.round(1), 'section' => r['sec'], 'entraxe' => ent))
      [nc, ml_ch, ml_lit, ml_ctr]
    end

    def self.poser(r)
      model = Sketchup.active_model
      cibles = A2M::Couverture.pans(model, r['cible'])
      return UI.messagebox('Aucun pan trouvé. Générez la toiture ou sélectionnez des pans.') if cibles.empty?
      model.start_operation('Charpente', true)
      begin
        model.entities.grep(Sketchup::Group).each { |x| x.erase! if x.valid? && x.layer.name == TAG } if r['cible'] == 'tout'
        tot = [0, 0.0, 0.0, 0.0]
        cibles.each { |f, t| res = pan(model, f, t, r); 4.times { |i| tot[i] += res[i] } }
        model.commit_operation
        UI.messagebox("Charpente posée sur #{cibles.size} pan(s) :\n#{tot[0]} chevrons (#{tot[1].round(1).to_s.tr('.', ',')} ml), contre-liteaux #{tot[3].round(1).to_s.tr('.', ',')} ml, liteaux #{tot[2].round(1).to_s.tr('.', ',')} ml.")
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Charpente impossible : #{ex.message}\n#{ex.backtrace.first}")
      end
    end

    # Rouvre la charpente posée : mêmes réglages, refaite sous tous les pans
    def self.modifier(_grp, d)
      return UI.messagebox('Cette charpente n\'a pas gardé ses réglages : reposez-la une fois.') unless d && d['r']
      @fen.close if @fen && (@fen.visible? rescue false)
      ouvrir(d['r'].merge('cible' => 'tout'))
    end

    def self.ouvrir(pre = nil)
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      html = A2M::Panneau.page(pre ? 'Modifier la charpente' : 'Charpente', 'Chevrons, contre-liteaux, liteaux, faîtière et sablière sous les pans', CORPS,
                               pre ? SCRIPT + A2M::Modif.js_prerempli(pre, 'Appliquer la modification') : SCRIPT, { 'sec' => SECTIONS.keys })
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : charpente', 'A2M_Panneau_Charp', html, 460, 640)
      @fen = dlg
      dlg.add_action_callback('poser') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) { poser(r) } if r
      end
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
