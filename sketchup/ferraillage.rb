# encoding: UTF-8
# Métré Atelier 2M : ferraillage en 3D (barres d'acier réelles) d'une dalle, d'une semelle, d'un linteau / d'une poutre ou d'un poteau en béton,
# avec les mètres et les kilos par diamètre (kg/m = π·Ø²/4 × 7850), repris par l'extraction du métré.
# Le béton est lu par sa boîte englobante alignée sur les axes (dalle, poutre, poteau rectangulaires et droits).
require 'sketchup.rb'
require 'json'

module A2M
  module Ferraillage
    TYPES = [['dalle', 'Dalle (2 nappes)'], ['semelle', 'Semelle (nappe basse)'], ['filante', 'Semelle filante (suit le tracé)'], ['poutre', 'Linteau / poutre'], ['poteau', 'Poteau']].freeze
    DEFAUT = { 'type' => 'dalle', 'enr' => 3.0, 'd' => 10, 's' => 20, 'haut' => 1, 'nb' => 3, 'nh' => 2, 'dh' => 10,
               'dc' => 6, 'sc' => 20, 'nc' => 2 }.freeze
    BALISE = 'A2M_FERRAILLAGE'
    DICO = 'a2m_ferraillage'
    MAX_BARRES = 4000

    # Masse linéique (kg/m) d'une barre de diamètre dmm
    def self.kgm(dmm) Math::PI * (dmm / 1000.0)**2 / 4 * 7850 end

    def self.beton?(e) (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.valid? && !e.get_attribute(DICO, 'kg') end

    # Type deviné d'après la forme du béton
    def self.deviner(bb, src = nil)
      @src_vol = src && src.respond_to?(:volume) ? src.volume.to_f : nil
      dm = src && A2M::Modif.lire(src)
      return 'filante' if dm && dm[0] == 'semelle'
      x, y, z = bb.width.to_m, bb.height.to_m, bb.depth.to_m
      vol = @src_vol && @src_vol > 0 ? @src_vol / (bb.width.to_f * bb.height.to_f * bb.depth.to_f) : nil
      return 'filante' if vol && vol < 0.7 && z < 1.0 && z > 0.15 && [x, y].min > 0.8
      return 'poteau' if z > 2.5 * [x, y].max && [x, y].max < 0.6
      return 'poutre' if [x, y].max > 3 * [x, y].min && z < 0.6 && [x, y].min < 0.6 && z > 0.12
      z < [x, y].min / 2 ? 'dalle' : (z < 0.5 ? 'semelle' : 'poutre')
    end

    # --- un jeu de barres parallèles : une définition (une barre) et des instances ---
    def self.barre_def(model, dmm, long_m)
      nom = "Fer Ø#{dmm} L#{(long_m * 100).round / 100.0}"
      dfn = model.definitions[nom] || model.definitions.add(nom)
      if dfn.entities.count == 0
        c = dfn.entities.add_circle(ORIGIN, Z_AXIS, (dmm / 2000.0).m, 6)
        f = dfn.entities.add_face(c)
        f.pushpull(f.normal.z > 0 ? long_m.m : -long_m.m)
      end
      dfn
    end

    # positions : points de départ ; dir : axe de la barre (vecteur unitaire)
    def self.famille(ents, model, nom, dmm, long_m, dir, positions, stock)
      return if positions.empty? || long_m <= 0.001
      g = ents.add_group
      g.name = "#{nom} Ø#{dmm}"
      dfn = barre_def(model, dmm, long_m)
      positions.each { |p| g.entities.add_instance(dfn, Geom::Transformation.new(p, dir)) }
      stock[dmm] = (stock[dmm] || 0.0) + long_m * positions.size
      g
    end

    def self.nombre_entre(a, b, pas) [((b - a) / pas).floor + 1, 2].max end

    def self.repartir(a, b, n) n <= 1 ? [(a + b) / 2.0] : (0...n).map { |i| a + (b - a) * i / (n - 1.0) } end

    # Cadres : une définition (anneau de 4 barres) et des instances le long de l'axe
    def self.cadres(ents, model, dc, w, h, pos_origines, ax, u, v, stock, crochets)
      g = ents.add_group
      g.name = "Cadres Ø#{dc}"
      nom = "Cadre Ø#{dc} #{(w * 100).round}x#{(h * 100).round}"
      dfn = model.definitions[nom] || model.definitions.add(nom)
      if dfn.entities.count == 0
        pts = [[0, 0], [w, 0], [w, h], [0, h]].map { |x, y| Geom::Point3d.new(x.m, y.m, 0) }
        4.times do |i|
          a, b = pts[i], pts[(i + 1) % 4]
          s = dfn.entities.add_group
          vv = b - a
          c = s.entities.add_circle(a, vv, (dc / 2000.0).m, 6)
          f = s.entities.add_face(c)
          f.pushpull(f.normal.samedirection?(vv) ? vv.length : -vv.length)
        end
      end
      pos_origines.each { |o| g.entities.add_instance(dfn, Geom::Transformation.axes(o, u, v, ax)) }
      per = 2 * (w + h) + 2 * [10 * dc / 1000.0, 0.07].max
      stock[dc] = (stock[dc] || 0.0) + per * pos_origines.size
      crochets[0] += pos_origines.size
      g
    end

    # Poutre ou poteau : longitudinales + cadres (zones de confinement aux deux bouts)
    def self.barres_lineaires(ents, model, bb, r, poteau, stock)
      enr = r['enr'] / 100.0; d = r['d']; dc = r['dc']
      mn, mx = bb.min, bb.max
      ex = { x: (mx.x - mn.x).to_m, y: (mx.y - mn.y).to_m, z: (mx.z - mn.z).to_m }
      if poteau then ax = Z_AXIS; u = X_AXIS; v = Y_AXIS; la = ex[:z]; eu = ex[:x]; ev = ex[:y]
      elsif ex[:x] >= ex[:y] then ax = X_AXIS; u = Y_AXIS; v = Z_AXIS; la = ex[:x]; eu = ex[:y]; ev = ex[:z]
      else ax = Y_AXIS; u = Z_AXIS; v = X_AXIS; la = ex[:y]; eu = ex[:z]; ev = ex[:x] end
      # origine locale = coin minimal ; coordonnées (a, p, q) le long de ax, u, v
      pt = lambda do |a, p, q|
        am = a.m.to_f; pm = p.m.to_f; qm = q.m.to_f
        mn + Geom::Vector3d.new(ax.x * am + u.x * pm + v.x * qm, ax.y * am + u.y * pm + v.y * qm, ax.z * am + u.z * pm + v.z * qm)
      end
      coords_h = nil
      # largeur utile pour les barres (axe des centres de barre)
      off = enr + dc / 1000.0 + d / 2000.0
      lcl = la - 2 * enr
      ucl = [eu - 2 * off, 0.0].max; vcl = [ev - 2 * off, 0.0].max
      coords = []
      if poteau
        n = [r['nc'], 2].max
        ps = repartir(off, off + ucl, n); qs = repartir(off, off + vcl, n)
        ps.each { |p| coords << [p, off] << [p, off + vcl] }
        qs[1..-2].each { |q| coords << [off, q] << [off + ucl, q] }
        coords.uniq!
      else
        # u = largeur ou hauteur selon l'axe ; on repère la verticale
        haut_est_u = (u == Z_AXIS)
        nb = [r['nb'], 2].max; nh = r['nh']
        bas = []; hau = []
        lar = haut_est_u ? vcl : ucl
        lpos = repartir(off, off + lar, nb); lpos_h = repartir(off, off + lar, [nh, 1].max)
        ver = haut_est_u ? ucl : vcl
        lpos.each { |w| bas << (haut_est_u ? [off, w] : [w, off]) }
        lpos_h.each { |w| hau << (haut_est_u ? [off + ver, w] : [w, off + ver]) } if nh > 0
        coords = bas
        coords_h = hau
      end
      total = coords.size + (coords_h ? coords_h.size : 0)
      if total > 200 then raise 'trop de barres longitudinales' end
      fam = ->(nom, dd, cc) { famille(ents, model, nom, dd, lcl, ax, cc.map { |p, q| pt.call(enr, p, q) }, stock) }
      if poteau then fam.call('Barres verticales', d, coords)
      else
        fam.call('Barres basses', d, coords)
        fam.call('Barres hautes', r['dh'], coords_h) if coords_h && !coords_h.empty?
      end
      # Cadres : espacement serré (moitié) sur la zone de confinement = max(grand côté, L/6, 45 cm), ailleurs espacement normal
      sc = [r['sc'], 5].max / 100.0
      zone = [[eu, ev].max, la / 6.0, 0.45].max
      zone = [zone, la / 2.0].min
      a0 = enr; a1 = la - enr
      pos = []
      a = a0
      while a <= a1 + 1e-6
        pos << a
        a += (a < a0 + zone - 1e-6 || a > a1 - zone + 1e-6) ? sc / 2.0 : sc
      end
      pos << a1 if (a1 - pos.last) > 0.02
      w = eu - 2 * enr - dc / 1000.0; h = ev - 2 * enr - dc / 1000.0
      o_c = enr + dc / 2000.0
      orig = pos.map { |aa| pt.call(aa, o_c, o_c) }
      crochets = [0]
      cadres(ents, model, dc, w, h, orig, ax, u, v, stock, crochets)
      { 'cadres' => pos.size, 'zone_cm' => (zone * 100).round }
    end

    # Dalle / semelle : deux nappes (X puis Y) basses, et hautes pour la dalle
    def self.barres_dalle(ents, model, bb, r, stock)
      enr = r['enr'] / 100.0; d = r['d']
      mn, mx = bb.min, bb.max
      lx = (mx.x - mn.x).to_m; ly = (mx.y - mn.y).to_m; lz = (mx.z - mn.z).to_m
      pas = [r['s'], 5].max / 100.0
      rad = d / 2000.0
      nx = nombre_entre(enr + rad, lx - enr - rad, pas) # barres parallèles à Y, réparties en X
      ny = nombre_entre(enr + rad, ly - enr - rad, pas)
      return 0 if nx * ny > MAX_BARRES
      xs = repartir(enr + rad, lx - enr - rad, nx); ys = repartir(enr + rad, ly - enr - rad, ny)
      couches = [[enr + rad, enr + rad + d / 1000.0]]
      couches << [lz - enr - rad - d / 1000.0, lz - enr - rad] if r['type'] == 'dalle' && r['haut'] == 1
      noms = ['basse', 'haute']
      couches.each_with_index do |(zx, zy), i|
        # barres selon X (réparties en Y) posées au niveau zx ; barres selon Y (réparties en X) au niveau zy
        famille(ents, model, "Nappe #{noms[i]} sens X", d, lx - 2 * enr, X_AXIS, ys.map { |y| mn + Geom::Vector3d.new(enr.m, y.m, zx.m) }, stock)
        famille(ents, model, "Nappe #{noms[i]} sens Y", d, ly - 2 * enr, Y_AXIS, xs.map { |x| mn + Geom::Vector3d.new(x.m, enr.m, zy.m) }, stock)
      end
      nx + ny
    end


    # --- Semelle filante : barres qui suivent le tracé du béton ---
    # Décale une boucle (points, matière à gauche) de t mètres vers la matière, avec onglets aux angles
    def self.decaler_boucle(pts, t)
      n = pts.size
      nor = (0...n).map do |i|
        d = pts[(i + 1) % n] - pts[i]
        d.z = 0
        d.normalize!
        Geom::Vector3d.new(-d.y, d.x, 0)
      end
      (0...n).map do |i|
        n0 = nor[(i - 1) % n]; n1 = nor[i]
        c = n0.dot(n1)
        k = t.m.to_f / (1.0 + c)
        pts[i] + Geom::Vector3d.new((n0.x + n1.x) * k, (n0.y + n1.y) * k, 0)
      end
    end

    def self.air(pts) pts.each_with_index.sum { |q, i| r = pts[(i + 1) % pts.size]; q.x * r.y - r.x * q.y } / 2.0 end

    def self.barre_seule(ents, model, dmm, p, q, stock)
      v = q - p
      return if v.length < 0.002.m
      dfn = barre_def(model, dmm, v.length.to_m)
      g = ents.add_group
      g.entities.add_instance(dfn, Geom::Transformation.new(p, v.normalize))
      stock[dmm] = (stock[dmm] || 0.0) + v.length.to_m
    end

    def self.barres_filante(ents, model, src, r, stock)
      enr = r['enr'] / 100.0; d = r['d']
      bb = src.bounds
      tr = src.transformation
      defn = src.is_a?(Sketchup::Group) ? src.entities : src.definition.entities
      faces = defn.grep(Sketchup::Face).select { |f| (tr * f.normal).z > 0.99 }
      raise 'Pas de face supérieure lisible sur ce béton.' if faces.empty?
      zt = faces.map { |f| (tr * f.vertices[0].position).z }.max
      faces = faces.select { |f| ((tr * f.vertices[0].position).z - zt).abs < 0.001 }
      zmin = bb.min.z; h = (zt - zmin).to_m
      z0 = zmin + (enr + d / 2000.0).m
      z1 = z0 + (d / 1000.0).m
      z2 = zt - (enr + r['dh'] / 2000.0).m
      groupes = { bas: ents.add_group, haut: ents.add_group, trans: ents.add_group }
      groupes[:bas].name = "Barres longitudinales basses Ø#{d}"; groupes[:haut].name = "Barres longitudinales hautes Ø#{r['dh']}"; groupes[:trans].name = "Barres transversales Ø#{d}"
      total = 0
      faces.each do |f|
        a = f.area(tr).to_f; per = f.loops.sum { |lp| lp.edges.sum { |e| (tr * e.start.position).distance(tr * e.end.position) } }
        w = (2.0 * a / per).to_m
        # Semelles créées par l'outil : la largeur réglée fait foi
        dm = A2M::Modif.lire(src)
        w = dm[1]['l'].to_f / 100.0 if dm && dm[0] == 'semelle' && dm[1]['l'].to_f > 0
        lat = enr + d / 2000.0
        raise 'Béton trop étroit pour cet enrobage.' if w - 2 * lat < 0.02
        f.loops.each do |lp|
          pts = lp.vertices.map { |v| tr * v.position }
          pts.map! { |p| Geom::Point3d.new(p.x, p.y, 0) }
          ccw = air(pts) > 0
          sens = lp.outer? ? ccw : !ccw
          pts.reverse! unless sens
          nb = [r['nb'], 2].max; nh = r['nh']
          # nappes longitudinales : lignes réparties sur la largeur
          lignes = ->(n, z, dd, gr) do
            (0...n).each do |i|
              t = lat + (n == 1 ? (w - 2 * lat) / 2.0 : i * (w - 2 * lat) / (n - 1.0))
              o = decaler_boucle(pts, t)
              o.each_with_index { |q, k| total += 1; barre_seule(gr.entities, model, dd, Geom::Point3d.new(q.x, q.y, z), Geom::Point3d.new(o[(k + 1) % o.size].x, o[(k + 1) % o.size].y, z), stock) }
            end
          end
          lignes.call(nb, z1, d, groupes[:bas])
          lignes.call(nh, z2, r['dh'], groupes[:haut]) if nh > 0
          # barres transversales posées sur l'axe, perpendiculaires au tracé
          axe = decaler_boucle(pts, w / 2.0)
          pas = [r['s'], 8].max / 100.0
          axe.each_with_index do |q, k|
            q2 = axe[(k + 1) % axe.size]
            v = q2 - q
            lg = v.length.to_m
            next if lg < 0.1
            dir = v.normalize
            nor = Geom::Vector3d.new(-dir.y, dir.x, 0)
            n = [((lg - 2 * enr) / pas).floor + 1, 1].max
            raise 'Trop de barres transversales.' if total + n > MAX_BARRES
            pos = (0...n).map do |i|
              s = n == 1 ? lg / 2.0 : enr + i * (lg - 2 * enr) / (n - 1.0)
              c = q + Geom::Vector3d.new(dir.x * s.m.to_f, dir.y * s.m.to_f, 0)
              c = c - Geom::Vector3d.new(nor.x * (w / 2.0 - enr).m.to_f, nor.y * (w / 2.0 - enr).m.to_f, 0)
              Geom::Point3d.new(c.x, c.y, z0)
            end
            famille(groupes[:trans].entities, model, 'Transversales', d, w - 2 * enr, nor, pos, stock)
            total += n
          end
        end
      end
      groupes.each_value { |g| g.erase! if g.valid? && g.entities.count == 0 }
    end

    # Construit le ferraillage de la source ; renvoie le groupe créé et le détail
    def self.construire(src, r, ancien = nil)
      model = Sketchup.active_model
      bb = src.bounds
      stock = {}
      ancien.erase! if ancien && ancien.valid?
      grp = model.active_entities.add_group
      info = {}
      if r['type'] == 'filante'
        barres_filante(grp.entities, model, src, r, stock)
      elsif %w[dalle semelle].include?(r['type'])
        barres_dalle(grp.entities, model, bb, r, stock)
      else
        info = barres_lineaires(grp.entities, model, bb, r, r['type'] == 'poteau', stock)
      end
      raise 'Aucune barre créée : le béton est trop petit pour cet enrobage.' if stock.empty?
      lb, _ = A2M::Balises.balise(model, BALISE, [200, 60, 40])
      grp.layer = lb
      detail = stock.sort.map { |dd, l| { 'd' => dd, 'ml' => (l * 100).round / 100.0, 'kg' => (l * kgm(dd) * 100).round / 100.0 } }
      kg = detail.sum { |x| x['kg'] }.round(2)
      ml = detail.sum { |x| x['ml'] }.round(2)
      grp.name = "Ferraillage #{src.name.to_s.empty? ? r['type'] : src.name} (#{kg.round} kg)"
      grp.set_attribute(DICO, 'kg', kg)
      grp.set_attribute(DICO, 'ml', ml)
      grp.set_attribute(DICO, 'detail', JSON.generate(detail))
      grp.set_attribute(DICO, 'type', r['type'])
      A2M::Modif.noter(grp, 'ferraillage', { 'r' => r, 'src' => src.persistent_id })
      [grp, { 'detail' => detail, 'kg' => kg, 'ml' => ml }.merge(info)]
    end

    # --- fenêtre ---
    CORPS = <<~'HTML'
      <div class="carte"><h3>Type d'ouvrage</h3><div id="types" class="puces"></div></div>
      <div class="carte"><h3>Réglages</h3><div id="champs"></div></div>
      <div class="carte"><h3>Quantités</h3><div id="qte">Choisissez un béton dans le modèle.</div></div>
      <div id="bas"><span id="msg"></span><button id="go" type="button">Terminer</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__, P = {}, tmr = null;
      var CH = {
        dalle:  [['enr','Enrobage (cm)',1,6,0.5],['d','Diamètre des barres (mm)',6,20,2],['s','Espacement (cm)',10,30,1],['haut','Nappe haute (0 = non, 1 = oui)',0,1,1]],
        filante:[['enr','Enrobage (cm)',3,8,0.5],['d','Ø barres transversales et basses (mm)',8,20,2],['s','Espacement transversal (cm)',10,30,1],['nb','Barres longitudinales basses',2,6,1],['nh','Barres longitudinales hautes',0,4,1],['dh','Ø barres hautes (mm)',8,20,2]],
        semelle:[['enr','Enrobage (cm)',3,8,0.5],['d','Diamètre des barres (mm)',8,20,2],['s','Espacement (cm)',10,30,1]],
        poutre: [['enr','Enrobage (cm)',2,6,0.5],['nb','Barres basses',2,6,1],['d','Ø barres basses (mm)',8,25,2],['nh','Barres hautes',0,4,1],['dh','Ø barres hautes (mm)',8,20,2],['dc','Ø cadres (mm)',5,10,1],['sc','Espacement des cadres (cm)',10,30,1]],
        poteau: [['enr','Enrobage (cm)',2,6,0.5],['nc','Barres par côté',2,5,1],['d','Ø barres (mm)',10,25,2],['dc','Ø cadres (mm)',5,10,1],['sc','Espacement des cadres (cm)',10,30,1]]
      };
      function el(i){ return document.getElementById(i); }
      function envoyer(){ clearTimeout(tmr); tmr = setTimeout(function(){ sketchup.maj(JSON.stringify(P)); }, 120); }
      function dessiner(){
        var t = el('types'); t.innerHTML = '';
        D.types.forEach(function(x){ var b = document.createElement('button'); b.type='button'; b.className='puce' + (P.type===x[0]?' on':''); b.textContent=x[1]; b.onclick=function(){ P.type=x[0]; dessiner(); envoyer(); }; t.appendChild(b); });
        var c = el('champs'); c.innerHTML = '';
        CH[P.type].forEach(function(f){
          var d = document.createElement('div'); d.style.cssText='margin:8px 0';
          d.innerHTML = '<div style="display:flex;justify-content:space-between;font-size:13px"><span>'+f[1]+'</span><b id="v_'+f[0]+'">'+P[f[0]]+'</b></div><input type="range" id="r_'+f[0]+'" min="'+f[2]+'" max="'+f[3]+'" step="'+f[4]+'" value="'+P[f[0]]+'" style="width:100%">';
          c.appendChild(d);
          d.querySelector('input').addEventListener('input', function(e){ P[f[0]] = parseFloat(e.target.value); el('v_'+f[0]).textContent = P[f[0]]; envoyer(); });
        });
      }
      function recu(j){
        var q = JSON.parse(j);
        if (q.erreur) { el('msg').textContent = q.erreur; return; }
        el('msg').textContent = '';
        var h = '<table style="width:100%;font-size:13px;border-collapse:collapse"><tr><th align=left>Diamètre</th><th align=right>Longueur</th><th align=right>Poids</th></tr>';
        q.detail.forEach(function(x){ h += '<tr><td>Ø '+x.d+' mm</td><td align=right>'+x.ml.toFixed(1)+' m</td><td align=right>'+x.kg.toFixed(1)+' kg</td></tr>'; });
        h += '<tr><td><b>Total</b></td><td align=right><b>'+q.ml.toFixed(1)+' m</b></td><td align=right><b>'+q.kg.toFixed(1)+' kg</b></td></tr></table>';
        if (q.cadres) h += '<div style="font-size:12px;color:#6f665e;margin-top:6px">'+q.cadres+' cadres, zone serrée de '+q.zone_cm+' cm à chaque bout (cadres à l\'espacement divisé par 2).</div>';
        el('qte').innerHTML = h;
      }
      function init(j){ var o = JSON.parse(j); P = o.r; dessiner(); if (o.ok) envoyer(); else el('qte').textContent = o.texte; }
      el('go').onclick = function(){ sketchup.fin(''); };
      sketchup.pret('');
    JS

    def self.ouvrir
      model = Sketchup.active_model
      src = model.selection.to_a.find { |e| beton?(e) }
      unless src
        UI.messagebox('Sélectionnez d\'abord le béton à ferrailler (un groupe : dalle, semelle, linteau, poutre ou poteau).')
        return
      end
      r = DEFAUT.dup
      r['type'] = deviner(src.bounds, src)
      r['enr'] = 5.0 if r['type'] == 'semelle'
      # Un ferraillage déjà posé sur ce béton est repris (et refait), pas doublé
      ancien = model.entities.grep(Sketchup::Group).find do |g|
        d = A2M::Modif.lire(g)
        d = d && d[1]
        g.valid? && g.get_attribute(DICO, 'kg') && d.is_a?(Hash) && d['src'] == src.persistent_id
      end
      if ancien
        d = A2M::Modif.lire(ancien)[1]
        r = DEFAUT.merge(d['r'])
      end
      afficher(src, r, ancien)
    end

    def self.modifier(grp, d)
      return UI.messagebox('Ce ferraillage n\'a pas gardé ses réglages.') unless d && d['r']
      src = Sketchup.active_model.find_entity_by_persistent_id(d['src'])
      return UI.messagebox('Le béton de ce ferraillage n\'est plus dans le modèle.') unless src && src.valid?
      afficher(src, DEFAUT.merge(d['r']), grp)
    end

    def self.afficher(src, r, grp)
      @cur = { src: src, r: r, grp: grp }
      if @fen && (@fen.visible? rescue false)
        envoyer_init
        @fen.bring_to_front
        return
      end
      html = A2M::Panneau.page('Ferraillage', 'Barres et cadres d\'acier en 3D, avec les mètres et les kilos par diamètre', CORPS, SCRIPT, { 'types' => TYPES })
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : ferraillage', 'A2M_Panneau_Ferraillage', html, 460, 760)
      @fen = dlg
      dlg.add_action_callback('pret') { |_c, _j| UI.start_timer(0, false) { envoyer_init } }
      dlg.add_action_callback('maj') { |_c, j| UI.start_timer(0, false) { maj(j) } }
      dlg.add_action_callback('fin') { |_c, _j| UI.start_timer(0, false) { dlg.close } }
      dlg.show
    end

    def self.envoyer_init
      return unless @fen
      @fen.execute_script("init(#{JSON.generate(JSON.generate({ 'r' => @cur[:r], 'ok' => true }))})")
    end

    def self.maj(json)
      return unless @cur && @cur[:src] && @cur[:src].valid?
      r = DEFAUT.merge(JSON.parse(json))
      %w[d dh dc nb nh nc haut].each { |k| r[k] = r[k].to_i }
      @cur[:r] = r
      model = Sketchup.active_model
      model.start_operation('Ferraillage (métré)', true, false, !@cur[:fait].nil?)
      begin
        grp, q = construire(@cur[:src], r, @cur[:grp])
        model.commit_operation
        @cur[:grp] = grp; @cur[:fait] = true
        res = q
      rescue StandardError => ex
        model.abort_operation
        res = { 'erreur' => "#{ex.message} @ #{ex.backtrace.to_a.first(3).map { |l| l.sub(/.*\//, '') }.join(' | ')}" }
        @cur[:grp] = nil if @cur[:grp] && !@cur[:grp].valid?
      end
      @fen.execute_script("recu(#{JSON.generate(JSON.generate(res))})") if @fen
    end

    # Total du ferraillage d'un modèle pour l'extraction : { diamètre => [ml, kg] }
    def self.totaux(entites, prof = 0)
      t = Hash.new { |h, k| h[k] = [0.0, 0.0] }
      entites.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        j = e.get_attribute(DICO, 'detail')
        if j
          JSON.parse(j).each { |x| t[x['d']][0] += x['ml']; t[x['d']][1] += x['kg'] }
        elsif prof < 2
          sous = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          totaux(sous, prof + 1).each { |k, v| t[k][0] += v[0]; t[k][1] += v[1] }
        end
      end
      t
    end
  end
end
