# encoding: UTF-8
# Métré Atelier 2M : escaliers droits, quart tournant avec palier, demi-tournant (marches, contremarches, limons), avec chemins pour les garde-corps
require 'sketchup.rb'
require 'json'

module A2M
  module Escalier
    TAG = 'A2M_ESCALIER'
    TYPES = [
      ['droit',  'Escalier droit',       'Une seule volée, en ligne'],
      ['quart_g', 'Quart tournant gauche', 'Palier carré, tourne à gauche'],
      ['quart_d', 'Quart tournant droit',  'Palier carré, tourne à droite'],
      ['demi_g', 'Demi-tournant gauche', 'Palier rectangulaire, retour à gauche'],
      ['demi_d', 'Demi-tournant droit',  'Palier rectangulaire, retour à droite']
    ].freeze
    MATIERES = { 'Chêne' => [176, 140, 96], 'Blanc' => [240, 240, 236], 'Noir' => [40, 42, 46], 'Béton' => [170, 170, 170], 'Frêne' => [214, 190, 150] }.freeze

    CORPS = <<~'HTML'
      <h2>Forme</h2>
      <div class="grille" id="types"></div>
      <h2>Dimensions</h2>
      <div class="dims">
        <div><label>Hauteur à monter (cm)</label><input type="text" id="h" value="270"></div>
        <div><label>Largeur (cm)</label><input type="text" id="w" value="90"></div>
        <div><label>Giron (cm)</label><input type="text" id="g" value="25"></div>
      </div>
      <div class="petit" id="calc"></div>
      <h2>Ouvrage</h2>
      <div class="puces" id="opts"></div>
      <h2>Matière</h2>
      <div class="puces" id="mat"></div>
      <div class="petit">Cliquez ensuite le point de départ (pied de la première marche), puis un second point pour donner la direction de montée (les axes rouge et vert sont verrouillés ; Ctrl pour libérer).</div>
      <div id="bas"><div id="msg"></div><button type="button" id="go">Poser l'escalier</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      var s = { t: 'droit', mat: 'Chêne', contre: true, limons: true, mur: 'aucun' };
      function calc() {
        var H = parseFloat(el('h').value.replace(',', '.')) || 0, g = parseFloat(el('g').value.replace(',', '.')) || 0;
        var n = Math.max(2, Math.round(H / 17.5)), h = H / n, b = 2 * h + g;
        el('calc').textContent = n + ' marches de ' + h.toFixed(1).replace('.', ',') + ' cm — loi de Blondel (2h + g) : ' + b.toFixed(1).replace('.', ',') + ' cm ' + (b >= 59 && b <= 66 ? '✓ confortable' : '⚠ hors de 59 à 66 cm');
      }
      function rendre() {
        var g = el('types'); g.innerHTML = '';
        D.types.forEach(function (t) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte' + (s.t === t.cle ? ' rempli' : '');
          var f = { droit: 'M8 32 V8 H40 V32 Z M8 14 H40 M8 20 H40 M8 26 H40', quart_g: 'M8 32 V18 H22 V8 H40 V32 Z M8 24 H22 M22 14 H40 M22 24 H40', quart_d: 'M8 8 H26 V18 H40 V32 H8 Z M8 14 H26 M26 24 H40 M16 18 V32', demi_g: 'M8 8 H40 V32 H8 Z M24 8 V32 M8 14 H24 M8 20 H24 M8 26 H24', demi_d: 'M8 8 H40 V32 H8 Z M24 8 V32 M24 14 H40 M24 20 H40 M24 26 H40' }[t.cle];
          b.innerHTML = '<div class="vignette"><svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1.2"><path d="' + f + '"/></svg></div><span></span><div class="petit" style="margin:2px 0 0"></div>';
          b.querySelector('span').textContent = t.libelle; b.querySelector('.petit').textContent = t.aide;
          b.addEventListener('click', function () { s.t = t.cle; rendre(); }); g.appendChild(b);
        });
        var o = el('opts'); o.innerHTML = '';
        [['contre', 'Contremarches'], ['limons', 'Limons latéraux']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s[x[0]] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { s[x[0]] = !s[x[0]]; rendre(); }); o.appendChild(b);
        });
        var w = document.createElement('span'); w.className = 'petit'; w.textContent = ' Côté mur (sans garde-corps) :'; o.appendChild(w);
        [['aucun', 'aucun'], ['gauche', 'à gauche'], ['droite', 'à droite']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s.mur === x[0] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { s.mur = x[0]; rendre(); }); o.appendChild(b);
        });
        var m = el('mat'); m.innerHTML = '';
        D.mat.forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s.mat === x ? ' rempli' : ''); b.textContent = x;
          b.addEventListener('click', function () { s.mat = x; rendre(); }); m.appendChild(b);
        });
        calc();
      }
      el('h').addEventListener('input', calc); el('g').addEventListener('input', calc);
      el('go').addEventListener('click', function () { s.h = el('h').value; s.w = el('w').value; s.g = el('g').value; sketchup.poser(JSON.stringify(s)); });
      rendre();
    JS

    class << self; attr_reader :dernier; attr_accessor :transparent; end

    def self.nombre(v, d) (Float(v.to_s.tr(',', '.')) rescue d) end

    # Bloc : origine + dir × [x0,x1] + lat × [y0,y1] + Z × [z0,z1]
    def self.bloc(ents, o, dir, lat, x0, x1, y0, y1, z0, z1, couleur)
      return if (x1 - x0).abs < 0.01 || (y1 - y0).abs < 0.01 || (z1 - z0).abs < 0.01
      p = ->(x, y, z) { o.offset(dir, x).offset(lat, y).offset(Z_AXIS, z) }
      f = ents.add_face(p.call(x0, y0, z0), p.call(x1, y0, z0), p.call(x1, y1, z0), p.call(x0, y1, z0))
      return unless f
      f.reverse! if f.normal.z < 0
      f.pushpull(z1 - z0)
      c = Sketchup::Color.new(*couleur)
      ents.grep(Sketchup::Face).each { |x| next unless x.material.nil?; x.material = c; x.back_material = c }
    end

    RI = 2.cm   # épaisseur des contremarches

    # Polygone (x, z) coupé sous le plan z = zmin
    def self.couper_z(pts, zmin)
      res = []
      pts.each_with_index do |p, i|
        q = pts[(i + 1) % pts.size]
        pin = p[1] >= zmin; qin = q[1] >= zmin
        res << p if pin
        res << [p[0] + (zmin - p[1]) / (q[1] - p[1]) * (q[0] - p[0]), zmin] if pin != qin
      end
      res
    end

    # Polygone (x, z) extrudé en travers, de y0 à y1
    def self.prisme_xz(ents, o, dir, lat, pts, y0, y1, couleur)
      return if pts.size < 3
      f = ents.add_face(pts.map { |x, z| o.offset(dir, x).offset(lat, y0).offset(Z_AXIS, z) })
      return unless f
      f.reverse! if f.normal.dot(lat) < 0
      f.pushpull(y1 - y0)
      c = Sketchup::Color.new(*couleur)
      ents.grep(Sketchup::Face).each { |x| next unless x.material.nil?; x.material = c; x.back_material = c }
    end

    # Volée de m marches : retourne les chemins de garde-corps des côtés (gauche = y max, droite = y min)
    # struct : 'bois' (limons pleins), 'cremaillere' (limons crémaillère), 'central' (limon central métal)
    def self.volee(ents, o, dir, lat, m, zb, h, g, w, ep, contre, limons, couleur, mur, struct = 'bois', nez = 2.cm)
      m.times do |k|
        i = k + 1
        bloc(ents, o, dir, lat, (i - 1) * g - nez, i * g + RI, 0, w, zb + i * h - ep, zb + i * h, couleur)
        bloc(ents, o, dir, lat, (i - 1) * g, (i - 1) * g + RI, 0, w, zb + (i - 1) * h, zb + i * h - ep, couleur) if contre
      end
      if m > 0 && struct == 'cremaillere'
        hb = h + ep + 9.cm
        haut = []
        m.times { |k| i = k + 1; z = zb + i * h - ep; haut << [(i - 1) * g, z] << [i * g, z] }
        poly = couper_z(haut + [[m * g, zb + h + m * h - hb], [0, zb + h - hb]], zb)
        [[0, 4.cm], [w - 4.cm, w]].each { |y0, y1| prisme_xz(ents, o, dir, lat, poly, y0, y1, couleur) }
      elsif m > 0 && struct == 'central'
        acier = MATIERES['Noir']
        sl = h / g
        t0 = zb - ep - 1.cm
        poly = couper_z([[0, t0], [m * g, t0 + sl * m * g], [m * g, t0 + sl * m * g - 16.cm], [0, t0 - 16.cm]], zb)
        prisme_xz(ents, o, dir, lat, poly, w / 2 - 4.cm, w / 2 + 4.cm, acier)
        m.times do |k|
          i = k + 1; xa = (i - 1) * g + 2.cm
          bloc(ents, o, dir, lat, xa, i * g - 2.cm, w / 2 - 4.cm, w / 2 + 4.cm, [t0 + sl * xa - 2.cm, zb].max, zb + i * h - ep, acier)
        end
      elsif limons && m > 0
        [[0, 4.cm], [w - 4.cm, w]].each do |y0, y1|
          pas = h / g
          xc = pas > 0 ? g * (22.cm - h) / h : 0
          xc = 0 if xc < 0
          pts = [[0, zb], [xc, zb], [m * g, zb + m * h + h - 22.cm], [m * g, zb + m * h + h - ep - 0.5.cm], [0, zb + h - ep - 0.5.cm]]
          pts = pts.select.with_index { |_, i| i != 1 || xc > 0 }
          prisme_xz(ents, o, dir, lat, pts, y0, y1, couleur)
        end
      end
      cotes = []
      [[0, 'droite'], [w, 'gauche']].each do |y, nom|
        next if mur == nom
        cotes << [o.offset(dir, 0).offset(lat, y).offset(Z_AXIS, zb + h), o.offset(dir, m * g).offset(lat, y).offset(Z_AXIS, zb + m * h + h)]
      end
      cotes
    end

    # Quart tournant à 3 marches balancées dans un carré w × w : rayons à 0°, 30°, 60°, 90° depuis l'angle intérieur
    # (retourne le chemin du garde-corps du côté extérieur)
    def self.quartier(ents, o1, dir, lat, w, zt1, h, ep, couleur, gauche, contre)
      pt = ->(x, y) { o1.offset(dir, x).offset(lat, gauche ? y : w - y) }
      e30 = [Math.tan(Math::PI / 6) * w, 0]
      e60 = [w, w - w / Math.tan(Math::PI / 3)]
      pp = [0, w]
      polys = [[pp, [0, 0], e30], [pp, e30, [w, 0], e60], [pp, e60, [w, w], [w, w + RI], [0, w + RI]]]
      polys.each_with_index do |pl, j|
        z = zt1 + j * h
        f = ents.add_face(pl.map { |x, y| pt.call(x, y).offset(Z_AXIS, z - ep) })
        next unless f
        f.reverse! if f.normal.z < 0
        f.pushpull(ep)
        c = Sketchup::Color.new(*couleur)
        ents.grep(Sketchup::Face).each { |x| next unless x.material.nil?; x.material = c; x.back_material = c }
      end
      # poteau d'angle (noyau) sous l'angle intérieur : porte les trois marches
      bloc(ents, o1, dir, lat, 0, 7.cm, gauche ? w - 7.cm : 0, gauche ? w : 7.cm, 0, zt1 + 2 * h - ep, couleur)
      if contre
        [e30, e60, [0, 0]].each_with_index do |b, j|
          a3 = pt.call(*pp); b3 = pt.call(*b)
          nrm = Z_AXIS.cross(b3 - a3); nrm.normalize!
          z = zt1 + [1, 2, 0][j] * h
          f = ents.add_face([a3, b3, b3.offset(nrm, RI), a3.offset(nrm, RI)].map { |p| p.offset(Z_AXIS, z - h) })
          next unless f
          f.reverse! if f.normal.z < 0
          f.pushpull(h - ep)
          c = Sketchup::Color.new(*couleur)
          ents.grep(Sketchup::Face).each { |x| next unless x.material.nil?; x.material = c; x.back_material = c }
        end
      end
      [[[0, 0], 0], [e30, 1], [[w, 0], 1.5], [e60, 2], [[w, w], 3]].map { |q, k| pt.call(*q).offset(Z_AXIS, zt1 + k * h) }
    end

    ENR_ESC = 3.cm

    # Volée en béton : une seule masse en dents de scie (marches + paillasse inclinée), avec ses barres
    def self.volee_beton(ents, rge, stock, o, dir, lat, m, zb, h, g, w, eb, dd, sd, couleur, mur)
      gf = g.to_f; hf = h.to_f; ebf = eb.to_f
      cosa = gf / Math.sqrt(gf * gf + hf * hf)
      ev = ebf / cosa
      zs = ->(x) { zb.to_f + hf + (hf / gf) * x - ev }
      x0 = (ev - hf) * gf / hf
      pts = []
      if x0 > 0 then pts << [0.0, zb.to_f]; pts << [0.0, zb.to_f + hf]
      else pts << [0.0, zs.call(0.0)]; pts << [0.0, zb.to_f + hf] end
      m.times do |k|
        pts << [k * gf, zb.to_f + (k + 1) * hf] unless k == 0
        pts << [(k + 1) * gf, zb.to_f + (k + 1) * hf]
        pts << [(k + 1) * gf, zb.to_f + (k + 2) * hf] if k < m - 1
      end
      pts << [m * gf, zs.call(m * gf)]
      pts << [x0, zb.to_f] if x0 > 0
      pts = pts.each_with_index.select { |q, i| i == 0 || (q[0] - pts[i - 1][0]).abs > 1e-6 || (q[1] - pts[i - 1][1]).abs > 1e-6 }.map(&:first)
      q = pts.map { |x, z| o.offset(dir, x).offset(lat, 0).offset(Z_AXIS, z) }
      f = ents.add_face(q)
      if f
        f.reverse! if f.normal.dot(lat) < 0
        f.pushpull(w)
        c = Sketchup::Color.new(*couleur)
        ents.grep(Sketchup::Face).each { |x| x.material = c; x.back_material = c }
      end
      # barres : principales suivant la pente (au-dessus de la sous-face), de répartition en travers
      en = ENR_ESC.to_f
      lat_pos = A2M::Ferraillage.repartir(en, w.to_f - en, A2M::Ferraillage.nombre_entre(en, w.to_f - en, sd.to_f))
      xa = [x0, 0.0].max + en; xb = m * gf - en
      dz = (en + dd / 25.4 / 2) / cosa
      if xb > xa
        lat_pos.each do |y|
          p1 = o.offset(dir, xa).offset(lat, y).offset(Z_AXIS, zs.call(xa) + dz)
          p2 = o.offset(dir, xb).offset(lat, y).offset(Z_AXIS, zs.call(xb) + dz)
          A2M::Ferraillage.barre_seule(rge, Sketchup.active_model, dd, p1, p2, stock)
        end
        long = (xb - xa) / cosa
        nr = A2M::Ferraillage.nombre_entre(0.0, long, 25.cm.to_f)
        A2M::Ferraillage.repartir(0.0, long, nr).each do |t|
          x = xa + t * cosa
          z = zs.call(x) + dz + (dd + 8) / 25.4
          p1 = o.offset(dir, x).offset(lat, en).offset(Z_AXIS, z)
          p2 = o.offset(dir, x).offset(lat, w.to_f - en).offset(Z_AXIS, z)
          A2M::Ferraillage.barre_seule(rge, Sketchup.active_model, 8, p1, p2, stock)
        end
      end
      cotes = []
      [[0, 'droite'], [w, 'gauche']].each do |y, nom|
        next if mur == nom
        cotes << [o.offset(dir, 0).offset(lat, y).offset(Z_AXIS, zb + h), o.offset(dir, m * g).offset(lat, y).offset(Z_AXIS, zb + m * h + h)]
      end
      cotes
    end

    # Grille simple de barres dans une dalle de palier (deux sens)
    def self.grille_palier(rge, stock, o, dir, lat, x0, x1, y0, y1, z, dd, s)
      en = ENR_ESC
      fx = A2M::Ferraillage.repartir(y0.to_f + en.to_f, y1.to_f - en.to_f, A2M::Ferraillage.nombre_entre(y0.to_f + en.to_f, y1.to_f - en.to_f, s.to_f))
      fx.each { |y| A2M::Ferraillage.barre_seule(rge, Sketchup.active_model, dd, o.offset(dir, x0 + en).offset(lat, y).offset(Z_AXIS, z), o.offset(dir, x1 - en).offset(lat, y).offset(Z_AXIS, z), stock) }
      fy = A2M::Ferraillage.repartir(x0.to_f + en.to_f, x1.to_f - en.to_f, A2M::Ferraillage.nombre_entre(x0.to_f + en.to_f, x1.to_f - en.to_f, s.to_f))
      fy.each { |x| A2M::Ferraillage.barre_seule(rge, Sketchup.active_model, dd, o.offset(dir, x).offset(lat, y0 + en).offset(Z_AXIS, z + dd / 25.4), o.offset(dir, x).offset(lat, y1 - en).offset(Z_AXIS, z + dd / 25.4), stock) }
    end

    def self.poser(r, o, dir)
      model = Sketchup.active_model
      hauteur = nombre(r['h'], 270).cm; w = nombre(r['w'], 90).cm; g = nombre(r['g'], 25).cm
      n = r['nm'].to_i > 1 ? r['nm'].to_i : [(hauteur / 17.5.cm).round, 2].max
      h = hauteur / n
      ep = nombre(r['ep'], 4).cm; nez = nombre(r['nez'], 2).cm
      o_orig = o; oz = o.z; o = Geom::Point3d.new(o.x, o.y, 0)
      treads = n - 1
      couleur = MATIERES[r['mat']] || MATIERES['Chêne']
      dir = dir.clone; dir.z = 0; dir.normalize!
      lat = Z_AXIS.cross(dir); lat.normalize!        # gauche
      model.start_operation('Escalier', true, false, !!@transparent)
      begin
        if @modif && @modif[:grp] && @modif[:grp].valid?
          @modif[:grp].erase!
        end
        @modif = nil
        tag, _ = A2M::Balises.balise(model, TAG, [176, 140, 96])
        grp = model.entities.add_group
        grp.layer = tag
        grp.name = "#{TYPES.find { |x| x[0] == r['t'] }[1]} – #{n} marches"
        e = grp.entities
        gc = []
        types = r['t']
        beton = r['struct'] ? r['struct'] == 'beton' : !!r['beton']
        struct = beton ? 'bois' : (r['struct'] || 'bois')
        eb = nombre(r['eb'], 14).cm; dd = nombre(r['db'], 10).to_i; sd = nombre(r['sb'], 15).cm
        stock = {}
        rge = beton ? e.add_group : nil
        epp = beton ? eb : ep
        vol = lambda do |o2, d2, l2, m2, zb2|
          if beton then volee_beton(e, rge.entities, stock, o2, d2, l2, m2, zb2, h, g, w, eb, dd, sd, couleur, r['mur'])
          else volee(e, o2, d2, l2, m2, zb2, h, g, w, ep, r['contre'], r['limons'], couleur, r['mur'], struct, nez) end
        end
        if types == 'droit'
          gc.concat(vol.call(o, dir, lat, treads, o.z))
        else
          gauche = types.end_with?('_g')
          quart = types.start_with?('quart')
          bal = quart && r['bal'] && !beton && treads >= 5
          m1 = bal ? (treads - 3) / 2 : (treads - 1) / 2
          m2 = bal ? treads - 3 - m1 : treads - 1 - m1
          gc.concat(vol.call(o, dir, lat, m1, o.z))
          o1 = o.offset(dir, m1 * g)
          if bal
            zt1 = o.z + (m1 + 1) * h
            ch = quartier(e, o1, dir, lat, w, zt1, h, ep, couleur, gauche, r['contre'])
            gc << ch unless r['mur'] == (gauche ? 'droite' : 'gauche')
            zt = zt1 + 2 * h
          else
            # palier : une marche pleine (prolongée sous la première contremarche de la volée suivante)
            zt = o.z + (m1 + 1) * h
            lon = w
            lar = quart ? w : 2 * w
            xlo = quart ? 0 : -RI
            y0p = gauche ? 0 : w - lar
            y1p = gauche ? lar : w
            ylo = quart ? (gauche ? y0p : y0p - RI) : y0p
            yhi = quart ? (gauche ? y1p + RI : y1p) : y1p
            bloc(e, o1, dir, lat, xlo, lon, ylo, yhi, zt - epp, zt, couleur)
            bloc(e, o1, dir, lat, 0, RI, y0p, y1p, zt - h, zt - epp, couleur) if r['contre'] && !beton
            grille_palier(rge.entities, stock, o1, dir, lat, 0, lon, y0p, y1p, zt - epp + ENR_ESC.to_f + dd / 50.8, dd, sd) if beton
          end
          if quart
            if gauche
              o2 = o1.offset(dir, w).offset(lat, w); d2 = lat; l2 = dir.reverse
            else
              o2 = o1; d2 = lat.reverse; l2 = dir
            end
          else
            if gauche
              o2 = o1.offset(lat, 2 * w); d2 = dir.reverse; l2 = lat.reverse
            else
              o2 = o1.offset(lat, -w); d2 = dir.reverse; l2 = lat
            end
          end
          gc.concat(vol.call(o2, d2, l2, m2, zt))
        end
        if beton
          if stock.empty?
            rge.erase!
          else
            lb, _ = A2M::Balises.balise(model, A2M::Ferraillage::BALISE, [200, 60, 40])
            rge.layer = lb
            stock.delete(:jonctions)
            detail = stock.sort.map { |d2, l| { 'd' => d2, 'ml' => (l * 100).round / 100.0, 'kg' => (l * A2M::Ferraillage.kgm(d2) * 100).round / 100.0 } }
            kg = detail.sum { |x| x['kg'] }.round(2)
            rge.name = "Ferraillage escalier (#{kg.round} kg)"
            rge.set_attribute(A2M::Ferraillage::DICO, 'kg', kg)
            rge.set_attribute(A2M::Ferraillage::DICO, 'ml', detail.sum { |x| x['ml'] }.round(2))
            rge.set_attribute(A2M::Ferraillage::DICO, 'detail', JSON.generate(detail))
            rge.set_attribute(A2M::Ferraillage::DICO, 'type', 'escalier')
          end
          grp.name = "#{grp.name} (béton #{(eb.to_f * 2.54).round} cm)"
        end
        grp.set_attribute('a2m', 'escalier_gc', JSON.generate(gc.map { |c| c.map(&:to_a) }))
        grp.set_attribute('a2m', 'escalier', JSON.generate('type' => types, 'marches' => n, 'hauteur_marche' => (h.to_f * 2.54).round(1), 'giron' => (g.to_f * 2.54).round(1), 'largeur' => (w.to_f * 2.54).round(0)))
        A2M::Modif.noter(grp, 'escalier', { 'r' => r.reject { |k, _| k == 'replacer' }, 'o' => o_orig.to_a, 'dir' => dir.to_a })
        grp.transform!(Geom::Transformation.translation(Geom::Vector3d.new(0, 0, oz))) if oz.abs > 0.001
        @dernier = grp
        model.commit_operation
        Sketchup.status_text = "Escalier posé : #{n} marches de #{(h.to_f * 2.54).round(1)} cm, giron #{(g.to_f * 2.54).round(1)} cm."
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Escalier impossible : #{ex.message}\n#{ex.backtrace.first}")
      end
    end

    def self.pose_initiale(r, o, dir) poser(r, o, dir) end

    class Outil
      def initialize(r) @r = r; @pts = []; @pt = A2M::Pointeur.new end
      def activate; Sketchup.status_text = 'Escalier : cliquez le pied de la première marche' end
      def deactivate(view) view.invalidate end
      def onSetCursor() UI.set_cursor(632) end
      def onMouseMove(_f, x, y, view) @pt.bouger(view, x, y, @pts); view.invalidate end
      def onKeyDown(key, rpt, _f, view) @pt.touche_bas(key, rpt, view, @pts) end
      def onKeyUp(key, _rpt, _f, view) @pt.touche_haut(key, view) end
      def getMenu(menu) @pt.menu(menu) end
      def onCancel(_r, view) Sketchup.active_model.select_tool(nil) end
      def onLButtonDown(_f, _x, _y, view)
        q = (@pt.pos || @pt.ip.position).clone
        @pts << q
        if @pts.size == 1 then Sketchup.status_text = 'Escalier : cliquez un second point : la direction de montée'
        else
          a, b = @pts
          Sketchup.active_model.select_tool(nil)
          r = @r
          UI.start_timer(0, false) { A2M::Escalier.pose_initiale(r, a, b - a) }
        end
        view.invalidate
      end
      def draw(view) @pt.dessiner(view, @pts, 'orange') end
      def getExtents
        bb = Geom::BoundingBox.new
        @pts.each { |q| bb.add(q) }
        bb.add(@pt.pos) if @pt.pos
        bb
      end
    end

    # Rouvre un escalier posé : mêmes réglages ; l'escalier est refait au même endroit (ou replacé en 2 clics)
    def self.modifier(grp, d)
      return UI.messagebox('Cet escalier n\'a pas gardé ses réglages : reposez-le une fois avec l\'outil.') unless d && d['r']
      @fen.close if @fen && (@fen.visible? rescue false)
      ouvrir(d['r'], { grp: grp, o: Geom::Point3d.new(*d['o']), dir: Geom::Vector3d.new(*d['dir']) })
    end

    def self.ouvrir(pre = nil, modif = nil)
      @modif = modif
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      d = { 'types' => TYPES.map { |k, l, a| { 'cle' => k, 'libelle' => l, 'aide' => a } }, 'mat' => MATIERES.keys }
      html = A2M::Panneau.page(modif ? 'Modifier l\'escalier' : 'Escalier', 'Droit, quart tournant ou demi-tournant, calculé avec la loi de Blondel', CORPS,
                               modif ? SCRIPT + A2M::Modif.js_prerempli(pre, 'Appliquer la modification', 'Replacer l\'escalier (2 clics) au lieu de le garder où il est') : SCRIPT, d)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : escalier', 'A2M_Panneau_Esc', html, 470, 780)
      @fen = dlg
      dlg.add_action_callback('poser') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        if r && @modif && !r['replacer']
          m = @modif
          UI.start_timer(0, false) { poser(r, m[:o], m[:dir]) }
        elsif r
          UI.start_timer(0, false) { Sketchup.active_model.select_tool(Outil.new(r)) }
        end
      end
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
