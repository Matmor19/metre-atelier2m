# encoding: UTF-8
# Métré Atelier 2M : couverture (ardoise, tuiles, zinc à joints debout, bac acier) posée sur les pans de toiture
require 'sketchup.rb'
require 'json'

module A2M
  module Couverture
    TAG = 'A2M_COUVERTURE'
    # clé, libellé, aide, rangs [pureau cm, pas cm], épaisseur cm, couleurs, nervure (hauteur cm, largeur cm) ou nil, décalage des joints (0 à 1)
    TYPES = [
      ['ardoise',  'Ardoise naturelle',   'Ardoises 32 × 22, pureau 12 cm, joints décalés',    [12, 22], 1.0, [[62, 66, 72], [55, 59, 66], [70, 74, 80]], nil, 0.5],
      ['tuile_m',  'Tuile mécanique',     'Rang tous les 33 cm, joint tous les 30 cm',         [33, 30], 2.0, [[176, 82, 56], [160, 70, 48], [188, 94, 66]], nil, 0.0],
      ['tuile_p',  'Tuile plate',         'Pureau 14 cm, tuiles de 17 cm, joints décalés',     [14, 17], 1.2, [[170, 80, 52], [150, 66, 44], [182, 92, 62]], nil, 0.5],
      ['zinc',     'Zinc à joints debout', 'Joint debout tous les 50 cm',                       [0, 50], 0.5, [[150, 160, 168]], [2.5, 1.2], 0.0],
      ['bac',      'Bac acier',           'Nervure tous les 33 cm',                            [0, 33], 0.5, [[84, 92, 100]], [2.8, 2.0], 0.0]
    ].freeze

    CORPS = <<~'HTML'
      <h2>Matériau</h2>
      <div class="grille" id="mat"></div>
      <h2>Réglages</h2>
      <div class="dims">
        <div><label id="l1">Pureau (cm)</label><input type="text" id="pur" value="12"></div>
        <div><label id="l2">Pas / largeur (cm)</label><input type="text" id="pas" value="22"></div>
      </div>
      <div class="petit" id="aide"></div>
      <h2>Sur quoi</h2>
      <div class="puces" id="cible"></div>
      <div class="petit">« Pans sélectionnés » : sélectionnez des pans (ou des groupes de toiture) avant de cliquer. Une couverture déjà posée sur un pan est remplacée.</div>
      <div id="bas"><div id="msg"></div><button type="button" id="go">Poser la couverture</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      var s = { mat: 'ardoise', cible: 'sel' };
      function choisir(k) { s.mat = k; var t = D.types.filter(function (x) { return x.cle === k; })[0]; el('pur').value = t.pur; el('pas').value = t.pas; rendre(); }
      function rendre() {
        var g = el('mat'); g.innerHTML = '';
        D.types.forEach(function (t) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte' + (s.mat === t.cle ? ' rempli' : '');
          b.innerHTML = '<div class="vignette"><svg viewBox="0 0 48 40" width="60" height="50"><rect x="6" y="6" width="36" height="28" fill="rgb(' + t.rgb + ')" stroke="#3C3C3C" stroke-width="1"/>' + t.motif + '</svg></div><span></span><div class="petit" style="margin:2px 0 0"></div>';
          b.querySelector('span').textContent = t.libelle; b.querySelector('.petit').textContent = t.aide;
          b.addEventListener('click', function () { choisir(t.cle); }); g.appendChild(b);
        });
        var t = D.types.filter(function (x) { return x.cle === s.mat; })[0];
        el('l1').textContent = t.pur_zero ? 'Pureau (sans objet)' : 'Pureau (cm)'; el('pur').disabled = t.pur_zero;
        el('l2').textContent = t.pur_zero ? 'Entraxe des joints (cm)' : 'Largeur de l\'élément (cm)';
        el('aide').textContent = t.aide;
        var c = el('cible'); c.innerHTML = '';
        [['sel', 'Pans sélectionnés'], ['tout', 'Tous les pans de la toiture']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s.cible === x[0] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { s.cible = x[0]; rendre(); }); c.appendChild(b);
        });
      }
      el('go').addEventListener('click', function () { sketchup.poser(JSON.stringify({ mat: s.mat, cible: s.cible, pur: el('pur').value, pas: el('pas').value })); });
      choisir('ardoise');
    JS

    MOTIFS = {
      'ardoise' => '<path d="M6 14 H42 M6 22 H42 M6 30 H42 M14 6 V14 M26 6 V14 M38 6 V14 M20 14 V22 M32 14 V22 M14 22 V30 M26 22 V30 M38 22 V30" stroke="#fff" stroke-opacity=".5"/>',
      'tuile_m' => '<path d="M6 16 H42 M6 26 H42 M16 6 V16 M28 6 V16 M36 16 V26 M22 16 V26" stroke="#fff" stroke-opacity=".5"/>',
      'tuile_p' => '<path d="M6 12 H42 M6 18 H42 M6 24 H42 M6 30 H42 M14 6 V12 M26 6 V12 M20 12 V18 M32 12 V18" stroke="#fff" stroke-opacity=".5"/>',
      'zinc'    => '<path d="M14 6 V34 M24 6 V34 M34 6 V34" stroke="#fff" stroke-width="2"/>',
      'bac'     => '<path d="M12 6 V34 M18 6 V34 M24 6 V34 M30 6 V34 M36 6 V34" stroke="#fff" stroke-width="1.4"/>'
    }

    def self.nombre(v, d) (Float(v.to_s.tr(',', '.')) rescue d) end

    # Faces de pan : faces inclinées (pas verticales) des groupes de toiture, en repère monde
    def self.pans(model, cible)
      src = []
      if cible == 'sel'
        model.selection.each { |e| src << e }
      else
        model.entities.each { |e| src << e if (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.layer.name.to_s.start_with?('A2M_TOITURE') }
      end
      res = []
      src.each do |e|
        if e.is_a?(Sketchup::Face) then res << [e, Geom::Transformation.new]
        elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          next if e.layer.name == TAG
          ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          ents.grep(Sketchup::Face).each { |f| res << [f, e.transformation] }
        end
      end
      res.select { |f, t| n = (t * f.normal) ; n.z > 0.05 && n.z < 0.999 }
    end

    # Intersections d'une droite v = c (horizontale dans le repère du pan) avec le polygone : intervalles [u0, u1]
    def self.coupe_h(poly, c)
      xs = []
      poly.each_with_index do |p, i|
        q = poly[(i + 1) % poly.size]
        next if (p[1] - c) * (q[1] - c) > 0 || p[1] == q[1]
        xs << p[0] + (c - p[1]) * (q[0] - p[0]) / (q[1] - p[1])
      end
      xs.sort.each_slice(2).select { |a| a.size == 2 && a[1] - a[0] > 0.2 }
    end

    def self.coupe_v(poly, c)
      coupe_h(poly.map { |u, v| [v, u] }, c)
    end

    def self.poser_pan(model, face, t, type, pur, pas)
      cle, lib, _a, _r, ep, couleurs, nerv, decal = type
      n = (t * face.normal); n.normalize!
      pts = face.outer_loop.vertices.map { |v| t * v.position }
      # repère du pan : v = ligne de plus grande pente (vers le haut), u horizontal
      bas = Z_AXIS.reverse
      pr = n.clone; pr.length = bas.dot(n)
      bas = bas - pr
      bas.normalize!
      haut = bas.reverse
      u = haut.cross(n); u.normalize!
      zmin = pts.map(&:z).min
      o = pts.find { |p| (p.z - zmin).abs < 0.01 } || pts[0]
      poly = pts.map { |p| w = p - o; [w.dot(u), w.dot(haut)] }
      umin = poly.map(&:first).min; umax = poly.map(&:first).max
      vmin = poly.map(&:last).min; vmax = poly.map(&:last).max
      model.entities.grep(Sketchup::Group).each { |g| g.erase! if g.valid? && g.layer.name == TAG && g.get_attribute('a2m', 'sur') == face.persistent_id }
      g = model.entities.add_group
      tg, _ = A2M::Balises.balise(model, TAG, [150, 90, 70])
      g.layer = tg
      g.name = "Couverture – #{lib}"
      ents = g.entities
      base = pts.map { |p| p.offset(n, 0.3.cm) }
      f = ents.add_face(base)
      return g.erase! unless f
      f.reverse! if f.normal.dot(n) < 0
      f.pushpull(ep.cm)
      dz = (0.3 + ep).cm
      top = lambda { |uu, vv| o.offset(u, uu.cm).offset(haut, vv.cm).offset(n, dz) }
      # coordonnées en cm depuis l'origine
      poly_cm = poly.map { |a, b| [a * 2.54, b * 2.54] }
      vmin_c = poly_cm.map(&:last).min; vmax_c = poly_cm.map(&:last).max
      umin_c = poly_cm.map(&:first).min; umax_c = poly_cm.map(&:first).max
      elements = 0
      if nerv
        # joints debout / nervures : prismes le long de la plus grande pente
        x = umin_c + pas / 2.0
        while x < umax_c
          coupe_v(poly_cm, x).each do |a, b|
            p0 = top.call(x - nerv[1] / 2.0, a); p1 = top.call(x + nerv[1] / 2.0, a)
            p2 = top.call(x + nerv[1] / 2.0, b); p3 = top.call(x - nerv[1] / 2.0, b)
            rf = ents.add_face(p0, p1, p2, p3) rescue nil
            next unless rf
            rf.reverse! if rf.normal.dot(n) < 0
            rf.pushpull(nerv[0].cm) rescue nil
            elements += 1
          end
          x += pas
        end
        ents.grep(Sketchup::Face).each { |x2| x2.material = Sketchup::Color.new(*couleurs[0]); x2.back_material = Sketchup::Color.new(*couleurs[0]) }
      else
        # rangs : lignes horizontales tous les « pureau » ; joints verticaux tous les « pas », décalés un rang sur deux
        rang = 0
        v = vmin_c
        while v < vmax_c - 0.1
          vn = [v + pur, vmax_c].min
          vm = (v + vn) / 2.0
          vv = v + pur / 2.0
          coupe_h(poly_cm, vm).each do |a, b|
            d = decal > 0 && rang.odd? ? pas * decal : 0
            x = umin_c + d - pas
            while x < umax_c
              x1 = x; x += pas
              aa = [x1, a].max; bb = [x, b].min
              next if bb - aa < 0.5
              elements += 1
              if aa > a + 0.05 then ents.add_line(top.call(aa, v), top.call(aa, vn)) rescue nil end
            end
            ents.add_line(top.call(a, v), top.call(b, v)) rescue nil
          end
          v = vn; rang += 1
        end
        # teintes variées d'un élément à l'autre
        k = 0
        ents.grep(Sketchup::Face).each do |x2|
          next unless x2.normal.dot(n) > 0.99
          c = couleurs[(k * 7 + x2.area.to_i) % couleurs.size]
          x2.material = Sketchup::Color.new(*c); x2.back_material = Sketchup::Color.new(*c)
          k += 1
        end
      end
      m2 = face.area * 2.54**2 / 10000.0 * ((t.xscale * t.yscale) rescue 1)
      g.set_attribute('a2m', 'sur', face.persistent_id)
      A2M::Modif.noter(g, 'couverture', { 'r' => @r_en_cours }) if @r_en_cours
      g.set_attribute('a2m', 'couverture', JSON.generate('type' => lib, 'm2' => m2.round(2), 'elements' => elements, 'pureau' => pur, 'pas' => pas))
      m2
    end

    def self.poser(r)
      model = Sketchup.active_model
      type = TYPES.find { |x| x[0] == r['mat'] } or return
      pur = nombre(r['pur'], type[3][0]); pas = nombre(r['pas'], type[3][1])
      pur = type[3][0] if pur <= 0 && type[3][0] > 0
      pas = 1.0 if pas <= 0
      cibles = pans(model, r['cible'])
      return UI.messagebox('Aucun pan trouvé. Sélectionnez des pans de toiture (ou choisissez « Tous les pans »).') if cibles.empty?
      @r_en_cours = r.reject { |k, _| k == 'cible' }
      model.start_operation('Couverture Atelier 2M', true)
      begin
        total = 0.0
        cibles.each { |f, t| total += poser_pan(model, f, t, type, pur, pas).to_f }
        model.commit_operation
        UI.messagebox("#{type[1]} posé sur #{cibles.size} pan(s) : #{format('%.1f', total).tr('.', ',')} m².")
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Couverture impossible : #{ex.message}\n#{ex.backtrace.first}")
      end
    end

    # Rouvre la couverture posée : mêmes réglages, appliqués à tous les pans (la couverture déjà posée est remplacée)
    def self.modifier(_grp, d)
      return UI.messagebox('Cette couverture n\'a pas gardé ses réglages : reposez-la une fois.') unless d && d['r']
      @fen.close if @fen && (@fen.visible? rescue false)
      ouvrir(d['r'].merge('cible' => 'tout'))
    end

    def self.ouvrir(pre = nil)
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      d = { 'types' => TYPES.map { |k, l, a, r, _e, c, n, _d| { 'cle' => k, 'libelle' => l, 'aide' => a, 'pur' => r[0], 'pas' => r[1], 'pur_zero' => r[0] == 0, 'rgb' => c[0].join(','), 'motif' => MOTIFS[k] } } }
      html = A2M::Panneau.page(pre ? 'Modifier la couverture' : 'Couverture', 'Ardoise, tuiles, zinc et bac acier posés sur les pans', CORPS,
                               pre ? SCRIPT + A2M::Modif.js_prerempli(pre, 'Appliquer la modification') : SCRIPT, d)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : couverture', 'A2M_Panneau_Couverture', html, 460, 760)
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
