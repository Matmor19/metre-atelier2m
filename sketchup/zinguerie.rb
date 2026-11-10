# encoding: UTF-8
# Métré Atelier 2M : zinguerie. Gouttières (avec crochets) sur les égouts de la toiture ; descentes d'eaux pluviales placées au clic
# sur l'égout et réglées sur une coupe (naissance, coudes, tuyau horizontal, tuyau vertical contre le mur, colliers, regard en pied).
# Visuel seulement : les linéaires de gouttière et de descente vont au métré comme avant (en mètres linéaires).
require 'sketchup.rb'
require 'json'

module A2M
  module Zinguerie
    # clé, libellé, aide, rayon extérieur cm, forme, descente conseillée
    GOUTTIERES = [
      ['demi25',  'Zinc dév. 25',     'Demi-ronde en zinc, développé 25 cm (ton profil et ton crochet)',   4.5, :demi,  'd80'],
      ['demi33',  'Zinc dév. 33',     'Demi-ronde en zinc, développé 33 cm',   6.0, :demi,  'd100'],
      ['nant',    'Nantaise',         'Gouttière carrée à fond plat',          6.0, :carre, 'd100'],
      ['alu',     'Profil alu',       'Gouttière alu, profil carré',           6.5, :carre, 'd80']
    ].freeze
    # Objets de ta bibliothèque utilisés à la place des formes calculées : [profil de gouttière, crochet]
    LIB_GOUTTIERE = { 'demi25' => ['Goutière Zinc', 'Crochet goutière Dev 25'] }.freeze
    # Objets de la descente pour cette gouttière : naissance, collier (pour Ø 80), regard en pied
    LIB_DESCENTE = { 'demi25' => { 'naissance' => 'Naissance Dev 25', 'collier' => 'Colier descente zinc', 'regard' => 'Regard béton pied de descente' } }.freeze
    DESCENTES = [['d60', 'Ø 60', 3.0], ['d80', 'Ø 80', 4.0], ['d100', 'Ø 100', 5.0]].freeze
    PARAM_DEFAUT = { 'jeu' => 3.0, 'chute' => 10.0, 'haut_sol' => 0.0, 'c1' => 25.0, 'c2' => 30.0, 'n' => 3, 'regard' => true, 't' => 0.0 }.freeze
    GRIS_ZINC = [150, 160, 168].freeze

    CORPS = <<~'HTML'
      <style>
        .champ{display:grid;grid-template-columns:1fr 78px;gap:4px 10px;align-items:center;margin:7px 0}
        .champ label{font-size:11.5px;color:#6f665e;line-height:1.25}
        .champ input[type=range]{grid-column:1 / 3;width:100%;accent-color:#E07838;margin:0}
        .champ input[type=text]{font-size:13px;padding:4px 6px;border-radius:7px}
        #coupe{display:none} #coupe.visible{display:block}
        #schema{background:#fff;border:1px solid #d8d0c6;border-radius:12px;width:100%;height:330px;display:block}
        .rang{display:flex;gap:8px;align-items:center;margin:8px 0;flex-wrap:wrap}
        .btn{border:2px solid #d8d0c6;background:#fff;border-radius:10px;padding:8px 14px;cursor:pointer;font:600 12.5px "Segoe UI",Arial,sans-serif;color:#3C3C3C}
        .btn:hover{border-color:#E07838} .btn.fort{background:#E07838;color:#fff;border-color:#E07838}
        .alerte{color:#a8541f;font-size:11.5px;min-height:15px}
      </style>
      <h2>Gouttière</h2>
      <div class="grille" id="gout"></div>
      <div class="champ"><label>Crochets : un tous les (cm)</label><input type="text" id="crochet" value="50"></div>
      <div class="puces" id="cible"></div>
      <div class="petit">« Tous les égouts » : repérés dans les groupes de toiture. « Égouts sélectionnés » : sélectionnez des arêtes horizontales en bas de pan.</div>
      <div class="rang"><button type="button" class="btn fort" id="poserg">Poser les gouttières</button></div>
      <h2>Descente d'eaux pluviales</h2>
      <div class="rang"><button type="button" class="btn fort" id="placer">Placer une descente (clic sur l'égout)</button></div>
      <div id="coupe">
        <div class="petit" style="margin-bottom:6px">Coupe perpendiculaire au mur : tout se règle ici, le modèle suit en direct.</div>
        <svg id="schema" viewBox="0 0 400 330" preserveAspectRatio="xMidYMid meet"></svg>
        <div class="alerte" id="alerte"></div>
        <div class="puces" id="desc" style="margin-top:6px"></div>
        <div id="champs"></div>
        <div class="rang"><label><input type="checkbox" id="regard" checked> Regard en pied</label></div>
        <div class="rang"><button type="button" class="btn fort" id="valider">Valider</button><button type="button" class="btn" id="suppr">Supprimer cette descente</button></div>
        <div class="petit">Pour la rouvrir plus tard : sélectionnez la descente, puis « Modifier ce que j'ai dessiné ».</div>
      </div>
      <div id="bas"><div id="msg"></div></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      var s = { g: 'demi25', cible: 'tout', crochet: 50 };
      var P = null, M = null, tmr = null;
      var CH = [['t', 'Position le long de l’égout (m)', 0, 10, 0.05],
                ['deb', 'Distance égout → mur (cm)', 0, 200, 1],
                ['jeu', 'Écart du tuyau au mur (cm)', 1, 10, 0.5],
                ['chute', 'Descente avant le premier coude (cm)', 0, 80, 1],
                ['c1', 'Collier de départ : distance sous le coude (cm)', 5, 120, 1],
                ['c2', 'Collier d’arrivée : distance au-dessus du pied (cm)', 5, 120, 1],
                ['n', 'Nombre de colliers (répartis régulièrement)', 1, 10, 1],
                ['haut_sol', 'Bas du tuyau au-dessus du sol (cm)', 0, 60, 1]];
      function rendreG() {
        var g = el('gout'); g.innerHTML = '';
        D.gout.forEach(function (t) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte' + (s.g === t.cle ? ' rempli' : '');
          var arc = t.forme === 'demi' ? '<path d="M10 16 A14 14 0 0 0 38 16" fill="none" stroke="#E07838" stroke-width="2.4"/>' : '<path d="M10 14 V30 H38 V14" fill="none" stroke="#E07838" stroke-width="2.4"/>';
          b.innerHTML = '<div class="vignette"><svg viewBox="0 0 48 40" width="60" height="50"><path d="M4 10 H44" stroke="#3C3C3C"/>' + arc + '</svg></div><span></span><div class="petit" style="margin:2px 0 0"></div>';
          b.querySelector('span').textContent = t.libelle; b.querySelector('.petit').textContent = t.aide;
          b.addEventListener('click', function () { s.g = t.cle; rendreG(); if (P) { P.g = t.cle; P.d = t.desc; envoyer(); } }); g.appendChild(b);
        });
        var c = el('cible'); c.innerHTML = '';
        [['tout', 'Tous les égouts'], ['sel', 'Égouts sélectionnés']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s.cible === x[0] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { s.cible = x[0]; rendreG(); }); c.appendChild(b);
        });
      }
      function rendreD() {
        var d = el('desc'); d.innerHTML = '';
        D.desc.forEach(function (t) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (P && P.d === t.cle ? ' rempli' : ''); b.textContent = 'Descente ' + t.libelle;
          b.addEventListener('click', function () { P.d = t.cle; rendreD(); envoyer(); }); d.appendChild(b);
        });
      }
      function champs(reset) {
        var z = el('champs');
        if (z.children.length === 0) {
          CH.forEach(function (c) {
            var w = document.createElement('div'); w.className = 'champ';
            w.innerHTML = '<label></label><input type="text" id="v_' + c[0] + '"><input type="range" id="r_' + c[0] + '">';
            w.querySelector('label').textContent = c[1]; z.appendChild(w);
            var r = w.querySelector('[type=range]'), v = w.querySelector('[type=text]');
            r.min = c[2]; r.max = c[3]; r.step = c[4];
            r.addEventListener('input', function () { v.value = r.value; P[c[0]] = parseFloat(r.value); envoyer(); });
            v.addEventListener('input', function () { var x = parseFloat(v.value.replace(',', '.')); if (!isNaN(x)) { P[c[0]] = x; if (x > +r.max) r.max = x; r.value = x; envoyer(); } });
          });
        }
        CH.forEach(function (c) {
          var r = el('r_' + c[0]), v = el('v_' + c[0]);
          if (c[0] === 't' && M) { r.max = Math.max(0.1, M.long); }
          if (reset || document.activeElement !== v) { r.value = P[c[0]]; v.value = (+P[c[0]]).toString().replace('.', ','); }
        });
        el('regard').checked = !!P.regard;
      }
      function envoyer() { clearTimeout(tmr); tmr = setTimeout(function () { sketchup.maj(JSON.stringify(P)); }, 70); }
      el('regard').addEventListener('change', function () { P.regard = el('regard').checked; envoyer(); });
      el('poserg').addEventListener('click', function () { sketchup.poser(JSON.stringify(s)); });
      el('placer').addEventListener('click', function () { sketchup.placer(''); });
      el('valider').addEventListener('click', function () { sketchup.valider(''); fermer(); });
      el('suppr').addEventListener('click', function () { sketchup.supprimer(''); fermer(); });
      function fermer() { P = null; el('coupe').className = ''; }
      el('crochet').addEventListener('input', function () { var x = parseFloat(el('crochet').value.replace(',', '.')); if (!isNaN(x)) s.crochet = x; });
      // état envoyé par SketchUp : p = réglages, m = mesures (en cm)
      function etat(p, m, reset) {
        P = p; M = m; el('coupe').className = 'visible';
        if (reset) { rendreD(); }
        champs(reset); dessiner(); el('alerte').textContent = m.msg || '';
        el('desc').querySelectorAll('.puce').forEach(function (b, i) { b.className = 'puce' + (D.desc[i].cle === P.d ? ' rempli' : ''); });
      }
      function dessiner() {
        var sv = el('schema'), m = M, p = P, W = 400, H = 330;
        var xmin = -m.deb - 40, xmax = m.xg + m.rg * 2 + 30, zmax = 45, zmin = -m.haut - 30;
        var k = Math.min((W - 20) / (xmax - xmin), (H - 20) / (zmax - zmin));
        function X(x) { return 10 + (x - xmin) * k; } function Z(z) { return 10 + (zmax - z) * k; }
        var o = '';
        o += '<rect x="' + X(xmin) + '" y="' + Z(-m.haut) + '" width="' + ((xmax - xmin) * k) + '" height="' + (30 * k + 40) + '" fill="#e8e1d8"/>';
        o += '<rect x="' + X(xmin) + '" y="' + Z(-5) + '" width="' + ((-m.deb - xmin) * k) + '" height="' + ((m.haut - 5) * k) + '" fill="#d9cfc2" stroke="#8a7f75"/>';
        o += '<polygon points="' + X(-m.deb - 25) + ',' + Z(25) + ' ' + X(0) + ',' + Z(2) + ' ' + X(0) + ',' + Z(-3) + ' ' + X(-m.deb - 25) + ',' + Z(18) + '" fill="#b89b84" stroke="#6f665e"/>';
        o += '<line x1="' + X(xmin) + '" y1="' + Z(-m.haut) + '" x2="' + X(xmax) + '" y2="' + Z(-m.haut) + '" stroke="#6f665e" stroke-width="1.5"/>';
        var gx = X(m.xg), gz = Z(-2 - m.rg * 0.5);
        if (m.demi) o += '<path d="M' + (gx - m.rg * k) + ' ' + Z(-2) + ' A' + (m.rg * k) + ' ' + (m.ry * k) + ' 0 0 0 ' + (gx + m.rg * k) + ' ' + Z(-2) + '" fill="none" stroke="#7a8691" stroke-width="3"/>';
        else o += '<path d="M' + (gx - m.rg * k) + ' ' + Z(-2 + m.rg * 1.4) + ' V' + Z(-2) + ' H' + (gx + m.rg * k) + ' V' + Z(-2 + m.rg * 1.4) + '" fill="none" stroke="#7a8691" stroke-width="3"/>';
        var w = Math.max(2, m.r * 2 * k), cl = '#E07838';
        var pts = [[m.xg, m.z0], [m.xg, m.z1], [m.xg - m.rb, m.z1 - m.rb], [m.xw + m.rb, m.z1 - m.rb], [m.xw, m.z2], [m.xw, m.zb]];
        var d = 'M' + X(pts[0][0]) + ' ' + Z(pts[0][1]) + ' L' + X(pts[1][0]) + ' ' + Z(pts[1][1]);
        d += ' Q' + X(m.xg) + ' ' + Z(m.z1 - m.rb) + ' ' + X(pts[2][0]) + ' ' + Z(pts[2][1]);
        d += ' L' + X(pts[3][0]) + ' ' + Z(pts[3][1]);
        d += ' Q' + X(m.xw) + ' ' + Z(m.z1 - m.rb) + ' ' + X(pts[4][0]) + ' ' + Z(pts[4][1]);
        d += ' L' + X(pts[5][0]) + ' ' + Z(pts[5][1]);
        o += '<path d="' + d + '" fill="none" stroke="' + cl + '" stroke-width="' + w + '" stroke-linejoin="round"/>';
        (m.colliers || []).forEach(function (z) {
          o += '<rect x="' + (X(m.xw) - (m.r + 1) * k) + '" y="' + (Z(z) - 1.2 * k) + '" width="' + ((m.r * 2 + 2) * k) + '" height="' + (2.4 * k) + '" fill="#3C3C3C"/>';
          o += '<rect x="' + X(m.xw - m.r - p.jeu) + '" y="' + (Z(z) - 1 * k) + '" width="' + ((p.jeu) * k) + '" height="' + (2 * k) + '" fill="#3C3C3C"/>';
        });
        if (p.regard) o += '<rect x="' + (X(m.xw) - 15 * k) + '" y="' + Z(-m.haut) + '" width="' + (30 * k) + '" height="' + (30 * k) + '" fill="#bfc6cc" stroke="#6f665e"/>';
        o += '<text x="' + X(xmin) + '" y="' + (Z(40)) + '" font-size="10" fill="#8a7f75">mur</text>';
        sv.innerHTML = o;
      }
      rendreG();
      sketchup.pret('');
    JS

    # Égouts : arêtes horizontales au bas d'un pan incliné, avec leur direction horizontale vers l'extérieur
    # Parcourt groupes et composants ; ne retient que les pans (faces inclinées vers le haut) des éléments dont le tag correspond
    def self.scan_pans(ents, t, roof, res, prof, dedans)
      ents.each do |g|
        if g.is_a?(Sketchup::Group) || g.is_a?(Sketchup::ComponentInstance)
          tt = t * g.transformation
          nom = g.layer.name.to_s
          ok = dedans || roof.nil? || nom.start_with?('A2M_TOITURE') || nom =~ roof
          sous = g.is_a?(Sketchup::Group) ? g.entities : g.definition.entities
          scan_pans(sous, tt, roof, res, prof + 1, ok) if prof < 5
        elsif g.is_a?(Sketchup::Face) && (dedans || roof.nil?)
          n = t * g.normal
          n = n.reverse if n.z < 0
          next unless n.z > 0.05 && n.z < 0.999
          zmin = g.vertices.map { |v| (t * v.position).z }.min
          g.edges.each do |e|
            autre = e.faces.find { |f| f != g }
            next if autre && (t * autre.normal).z > 0.05 && (t * autre.normal).z < 0.999 && (t * autre.normal).dot(n) > 0.2
            a = t * e.start.position; b = t * e.end.position
            next unless (a.z - zmin).abs < 0.02 && (b.z - zmin).abs < 0.02
            res << [a, b, Geom::Vector3d.new(n.x, n.y, 0)]
          end
        end
      end
    end

    def self.egouts(model, cible)
      res = []
      if cible == 'sel'
        model.selection.grep(Sketchup::Edge).each do |e|
          a = e.start.position; b = e.end.position
          next if (a.z - b.z).abs > 0.01
          f = e.faces.first
          sortie = if f then v = f.normal; Geom::Vector3d.new(v.x, v.y, 0) else Geom::Vector3d.new(0, 0, 0) end
          res << [a, b, sortie]
        end
      else
        # 1) groupes de toiture Atelier 2M ou tags évoquant une toiture ; 2) à défaut, tout pan incliné du modèle
        roof = /toit|couvert|tuile|zinc|ardoise|pan/i
        [:roof, :tout].each do |mode|
          res.clear
          scan_pans(model.entities, Geom::Transformation.new, mode == :roof ? roof : nil, res, 0, false)
          break unless res.empty?
        end
        if res.empty?
          return egouts(model, 'sel') if model.selection.grep(Sketchup::Edge).any? && cible != 'sel'
        end
      end
      res.select { |a, b, s| a.distance(b) > 5.cm && s.length > 0.001 }
    end


    # Ton profil de gouttière et ton crochet (bibliothèque) pour cette gouttière : nil si absents (formes calculées)
    # 'pts' : contour [largeur, hauteur] en cm, bas de la gouttière à 0 et arrière (côté mur) à 0
    def self.perso(g)
      noms = LIB_GOUTTIERE[g[0]] or return nil
      objs = A2M::Bibliotheque.objets
      po = objs.find { |o| o['nom'] == noms[0] && o['profils'] } or return nil
      pts = po['profils'][0][1].map { |x, z| [x.to_f * 2.54, z.to_f * 2.54] }
      return nil if pts.size < 6
      lg = pts.map(&:first); hg = pts.map(&:last)
      pts = pts.map { |x, z| [x - lg.min, z - hg.min] }
      bas = pts.min_by { |_x, z| z }   # creux de la gouttière : le tuyau de descente passe sous ce point
      ld = LIB_DESCENTE[g[0]] || {}
      trouve = ->(n) { n && objs.find { |o| o['nom'] == n && o['fichier'] } }
      { 'pts' => pts, 'larg' => lg.max - lg.min, 'haut' => hg.max - hg.min, 'cx' => bas[0],
        'crochet' => trouve.(noms[1]), 'naissance' => trouve.(ld['naissance']), 'collier' => trouve.(ld['collier']), 'regard' => trouve.(ld['regard']) }
    end

    def self.profil(forme, r)
      ep = 0.1
      pts = []
      if forme == :demi
        cy = -2.0
        ext = (0..16).map { |i| t = Math::PI + Math::PI * i / 16.0; [r * 0.4 + r * Math.cos(t), cy + r * Math.sin(t)] }
        int = (0..16).map { |i| t = 2 * Math::PI - Math::PI * i / 16.0; [r * 0.4 + (r - ep) * Math.cos(t), cy + (r - ep) * Math.sin(t)] }
        pts = ext + int
        # bords relevés
        [pts, [[r * 1.4, cy], [r * 1.4, cy + 1.2], [r * 1.4 - ep, cy + 1.2]]]
      else
        w = r * 2; h = r * 1.4; cy = -2.0
        [[[0.4 * r, cy], [0.4 * r + w, cy], [0.4 * r + w, cy + h], [0.4 * r + w - ep, cy + h], [0.4 * r + w - ep, cy + ep], [0.4 * r + ep, cy + ep], [0.4 * r + ep, cy + h], [0.4 * r, cy + h]], []]
      end[0]
    end

    # Positions (pouces, depuis a) des naissances de descente posées sur cet égout : la gouttière y est coupée
    def self.coupes_naissances(model, a, b, g)
      res = []
      model.entities.grep(Sketchup::Group).each do |e|
        next unless e.valid? && e.layer.name == 'A2M_DESCENTE'
        o = A2M::Modif.lire(e) or next
        d = o[1]
        next unless d['kind'] == 'descente' && d['ctx'] && d['ctx']['a'] && d['ctx']['b'] && d['p'] && d['p']['g'] == g[0]
        next unless Geom::Point3d.new(*d['ctx']['a']).distance(a) < 0.05 && Geom::Point3d.new(*d['ctx']['b']).distance(b) < 0.05
        res << [[d['p']['t'].to_f.m, 0.0].max, (b - a).length].min
      end
      res.sort
    end

    def self.gouttiere(model, a, b, sortie, g, crochet_cm = 50)
      sortie = sortie.clone; sortie.normalize!
      d = b - a; l = d.length; u = d.normalize
      pe = perso(g)
      if pe
        xg = pe['cx'] * 0.4   # le creux de la gouttière est un peu vers l'extérieur de l'égout
        pf = pe['pts'].map { |w, h| [w - pe['cx'] + xg, h - 2.0 - pe['haut']] }
      else
        pf = profil(g[4], g[3])
      end
      # tronçons : la gouttière est coupée là où ta naissance est posée
      coupes = pe && pe['naissance'] ? coupes_naissances(model, a, b, g) : []
      demi = pe && pe['naissance'] ? pe['naissance']['l0'].to_f / 2.0 : 0.0
      tronc = []; pos = 0.0
      coupes.each { |t| c0 = t - demi; tronc << [pos, c0] if c0 - pos > 5.cm; pos = [pos, t + demi].max }
      tronc << [pos, l] if l - pos > 5.cm
      grp = model.entities.add_group
      tg, _ = A2M::Balises.balise(model, 'A2M_GOUTTIERE', [130, 140, 150])
      grp.layer = tg
      grp.name = "Gouttière #{g[1]} – #{(l.to_f * 0.0254).round(2)} m"
      ok = false
      tronc.each do |t0, t1|
        p0 = a.offset(u, t0); p1 = a.offset(u, t1)
        f = grp.entities.add_face(pf.map { |w, h| p0.offset(sortie, w.cm).offset(Z_AXIS, h.cm) })
        next unless f
        f.followme(grp.entities.add_edges(p0, p1)) rescue nil
        ok = true
      end
      return grp.erase! unless ok
      grp.entities.grep(Sketchup::Edge).each { |e| e.erase! if e.valid? && e.faces.empty? }
      grp.entities.grep(Sketchup::Face).each { |x| x.material = Sketchup::Color.new(*GRIS_ZINC); x.back_material = Sketchup::Color.new(*GRIS_ZINC) }
      pe && pe['crochet'] ? crochets_objet(model, grp, a, d, sortie, pe, xg, crochet_cm, coupes) : crochets(grp, a, d, sortie, pf, crochet_cm)
      A2M::Modif.noter(grp, 'zinguerie', { 'r' => @r_en_cours }) if @r_en_cours
      grp.set_attribute('a2m', 'edge', JSON.generate([a.to_a, b.to_a, sortie.to_a]))
      grp.set_attribute('a2m', 'zinguerie', JSON.generate('type' => g[1], 'ml' => (l.to_f * 0.0254).round(2)))
      [grp, (l.to_f * 0.0254)]
    end

    # Refait la gouttière de cet égout avec ses réglages d'origine (après la pose, le déplacement ou la suppression d'une naissance)
    def self.refaire_gouttiere(model, ctx)
      a = Geom::Point3d.new(*ctx['a']); b = Geom::Point3d.new(*ctx['b'])
      model.entities.grep(Sketchup::Group).each do |e|
        next unless e.valid? && e.layer.name == 'A2M_GOUTTIERE'
        ed = (JSON.parse(e.get_attribute('a2m', 'edge').to_s) rescue nil) or next
        next unless Geom::Point3d.new(*ed[0]).distance(a) < 0.05 && Geom::Point3d.new(*ed[1]).distance(b) < 0.05
        o = A2M::Modif.lire(e)
        r = o && o[1]['r'] or next
        g = GOUTTIERES.find { |x| x[0] == r['g'] } or next
        e.erase!
        @r_en_cours = r
        gouttiere(model, a, b, Geom::Vector3d.new(*ed[2]), g, r['crochet'].to_f.nonzero? || 50)
        return true
      end
      false
    end

    # Crochets provisoires : une tranche du profil, un peu plus grande, tous les « pas » cm (remplacés plus tard par vos objets)
    def self.crochets(grp, a, d, sortie, pf, pas_cm)
      return if pas_cm.to_f < 15
      l = d.length; u = d.normalize
      xs = pf.map(&:first); zs = pf.map(&:last)
      cx = (xs.min + xs.max) / 2.0; cz = (zs.min + zs.max) / 2.0
      n = ((l.to_f / 2.54 - 20) / pas_cm).floor
      (0..n).each do |i|
        q = a.offset(u, (10 + i * pas_cm).cm)
        break if q.distance(a) > l - 5.cm
        pts = pf.map { |w, h| q.offset(sortie, (cx + (w - cx) * 1.08).cm).offset(Z_AXIS, (cz + (h - cz) * 1.08).cm) }
        sg = grp.entities.add_group
        ff = sg.entities.add_face(pts)
        next unless ff
        ff.pushpull(ff.normal.dot(u) > 0 ? 1.5.cm : -1.5.cm)
        sg.name = 'Crochet'
        sg.entities.grep(Sketchup::Face).each { |x| x.material = Sketchup::Color.new(70, 75, 80); x.back_material = Sketchup::Color.new(70, 75, 80) }
      end
    end


    # Crochets de ta bibliothèque : posés tous les « pas » cm, creux du crochet sous le creux de la gouttière
    # (objet : X le long de la gouttière, Y de l'arrière vers l'avant, Z vers le haut, bas du crochet à Z = 0)
    def self.crochets_objet(model, grp, a, d, sortie, pe, xg, pas_cm, coupes = [])
      return if pas_cm.to_f < 15
      defn = A2M::Bibliotheque.charger(pe['crochet'], model)
      l = d.length; u = d.normalize
      ux = (u.cross(sortie).z > 0) ? u : u.reverse     # repère direct : X x Y = Z vers le haut
      lc = pe['crochet']['l0'].to_f                      # largeur du crochet le long de la gouttière (pouces)
      n = ((l.to_f / 2.54 - 20) / pas_cm).floor
      (0..n).each do |i|
        t = (10 + i * pas_cm).cm
        break if t > l - 5.cm
        demi_n = pe['naissance'] ? pe['naissance']['l0'].to_f / 2.0 + lc / 2.0 + 1.cm : 0.0
        next if coupes.any? { |c| (c - t).abs < demi_n }   # pas de crochet sous la naissance
        q = a.offset(u, t)
        o = q.offset(ux, -lc / 2.0).offset(sortie, (xg - pe['cx'] - 0.22).cm).offset(Z_AXIS, (-2.0 - pe['haut'] - 0.2).cm)
        tr = Geom::Transformation.axes(o, ux, sortie, Z_AXIS)
        inst = grp.entities.add_instance(defn, tr)
        inst.name = 'Crochet' if inst
      end
    end

    def self.zsol(model)
      zs = []
      A2M::Plan2D.parcourir(model.entities, Geom::Transformation.new) { |e, t| zs << A2M::Plan2D.coins(e, t).map(&:z).min if e.layer.name == 'A2M_PIECE' }
      zs.empty? ? model.bounds.min.z : zs.min
    end

    # ---------------- Descente : mesures et montage ----------------
    def self.cm_de(len) len.to_f * 2.54 end

    # Toutes les cotes du montage, en cm, dans le repère de la coupe : x vers l'extérieur depuis la ligne d'égout, z depuis l'égout
    def self.mesures(ctx, p, g, de, hsol_cm)
      rg = g[3]; r = de[2]
      pe = perso(g)
      rg = pe['cx'] if pe
      demi = (g[4] == :demi)
      xg = demi ? rg * 0.4 : rg * 1.4   # axe de la gouttière par rapport à la ligne d'égout
      deb = p['deb'].to_f
      jeu = p['jeu'].to_f
      xw = -(deb - jeu - r)
      rb = r * 1.5
      msg = ''
      if xg - xw < 2 * rb
        rb = [(xg - xw) / 2.0, 0.5].max
        msg = 'Le débord est trop faible pour deux coudes : augmentez la distance égout → mur ou réduisez l\'écart au mur.'
      end
      z0 = demi ? -2.0 - (pe ? pe['haut'] : rg) : -2.0
      z1 = z0 - 6.0 - p['chute'].to_f
      z2 = z1 - 2 * rb
      zb = -hsol_cm + p['haut_sol'].to_f
      if z2 - zb < 15
        msg = 'Descente trop courte : il faut plus de hauteur entre l\'égout et le sol.' if msg.empty?
        zb = z2 - 15
      end
      n = [p['n'].to_i, 1].max
      zc_h = z2 - p['c1'].to_f; zc_b = zb + p['c2'].to_f
      cols = if n == 1 || zc_h <= zc_b then [(zc_h + zc_b) / 2.0]
             else (0...n).map { |i| zc_h + (zc_b - zc_h) * i / (n - 1.0) } end
      { 'deb' => deb, 'xg' => xg, 'xw' => xw, 'r' => r, 'rg' => rg, 'rb' => rb, 'z0' => z0, 'z1' => z1, 'z2' => z2, 'zb' => zb,
        'haut' => hsol_cm, 'demi' => demi, 'ry' => (pe ? pe['haut'] : rg), 'L' => (xg - rb) - (xw + rb), 'colliers' => cols, 'msg' => msg, 'long' => ctx['long'].to_f }
    end

    def self.pt_local(o, s, x, z) o.offset(s, x.cm).offset(Z_AXIS, z.cm) end

    def self.colorier(ents, rgb)
      ents.each do |e|
        if e.is_a?(Sketchup::Face) then e.material = Sketchup::Color.new(*rgb); e.back_material = Sketchup::Color.new(*rgb)
        elsif e.is_a?(Sketchup::Group) then colorier(e.entities, rgb) end
      end
    end

    def self.tube(ents, p0, dir, long_in, r_cm)
      return if long_in < 0.05.cm
      c = ents.add_circle(p0, dir, r_cm.cm, 20)
      f = ents.add_face(c)
      return unless f
      f.pushpull(f.normal.dot(dir) > 0 ? long_in : -long_in)
    end

    # Coude à 90° : le disque de la section est balayé le long d'un arc de centre c (en repère x, z)
    def self.coude(ents, o, s, cx, cz, rb, a0, a1, r_cm)
      pts = (0..12).map { |i| t = (a0 + (a1 - a0) * i / 12.0) * Math::PI / 180.0; pt_local(o, s, cx + rb * Math.cos(t), cz + rb * Math.sin(t)) }
      ed = ents.add_curve(*pts)
      tg = pts[1] - pts[0]
      c = ents.add_circle(pts[0], tg, r_cm.cm, 20)
      f = ents.add_face(c) or return
      f.followme(ed) rescue nil
      ed.each { |e| e.erase! if e.valid? && e.faces.empty? }
    end

    def self.collier(grp, o, s, m, z)
      ey = Z_AXIS.cross(s); ey.normalize!
      sg = grp.entities.add_group
      e2 = sg.entities
      c = pt_local(o, s, m['xw'], z)
      ext = e2.add_face(e2.add_circle(c, Z_AXIS, (m['r'] + 0.8).cm, 20))
      return unless ext
      int = e2.add_face(e2.add_circle(c, Z_AXIS, m['r'].cm, 20))
      int.erase! if int
      ext.pushpull(ext.normal.z > 0 ? 2.cm : -2.cm) if ext.valid?
      xa = m['xw'] - (m['r'] + 0.6); xb = m['xw'] - (m['r'] + p_jeu_vers_mur(m))
      pts = [[xa, -1.0], [xb, -1.0], [xb, 1.0], [xa, 1.0]].map { |x, y| pt_local(o, s, x, z).offset(ey, y.cm) }
      f2 = e2.add_face(pts)
      f2.pushpull(f2.normal.z > 0 ? 2.cm : -2.cm) if f2
      sg.name = 'Collier'
      colorier(e2, [60, 60, 60])
    end

    # Ton collier : anneau vertical (centre à 6,96 / 10,55 / 1,35 cm dans l'objet), patte de scellement vers le mur (Y de l'objet vers l'extérieur)
    def self.collier_objet(model, grp, obj, o, s, m, z)
      defn = A2M::Bibliotheque.charger(obj, model)
      x = s.cross(Z_AXIS); x.normalize!
      c = pt_local(o, s, m['xw'], z)
      base = c.offset(x, -6.96.cm).offset(s, -10.55.cm).offset(Z_AXIS, -1.35.cm)
      inst = grp.entities.add_instance(defn, Geom::Transformation.axes(base, x, s, Z_AXIS))
      inst.name = 'Collier' if inst
    end

    def self.p_jeu_vers_mur(m) m['jeu'].to_f end

    def self.monter_descente(model, ctx, p)
      g = GOUTTIERES.find { |x| x[0] == p['g'] } || GOUTTIERES[0]
      de = DESCENTES.find { |x| x[0] == p['d'] } || DESCENTES[1]
      a = Geom::Point3d.new(*ctx['a']); b = Geom::Point3d.new(*ctx['b'])
      s = Geom::Vector3d.new(*ctx['s']); s.normalize!
      d = b - a; u = d.normalize
      t = [[p['t'].to_f.m, 0.0].max, d.length].min
      o = a.offset(u, t)
      m = mesures(ctx, p, g, de, cm_de(o.z - ctx['sol'].to_f))
      m['jeu'] = p['jeu'].to_f
      grp = model.entities.add_group
      e = grp.entities
      r = m['r']
      pe = perso(g)
      nais = pe && pe['naissance'] && de[0] == 'd80' ? pe['naissance'] : nil
      if nais
        # ta naissance remplace la pièce provisoire ; la sortie fait 6,3 cm sous le creux de la gouttière
        tube(e, pt_local(o, s, m['xg'], m['z0'] - 6.3), Z_AXIS.reverse, (m['z0'] - 6.3 - m['z1']).cm, r)
      else
        # naissance (évasée), tuyau jusqu'au premier coude
        tube(e, pt_local(o, s, m['xg'], m['z0']), Z_AXIS.reverse, 6.cm, r * 1.25)
        tube(e, pt_local(o, s, m['xg'], m['z0'] - 6), Z_AXIS.reverse, (m['z0'] - 6 - m['z1']).cm, r)
      end
      coude(e, o, s, m['xg'] - m['rb'], m['z1'], m['rb'], 0, -90, r)
      hz = m['L']
      tube(e, pt_local(o, s, m['xg'] - m['rb'], m['z1'] - m['rb']), s.reverse, hz.cm, r) if hz > 0.1
      coude(e, o, s, m['xw'] + m['rb'], m['z2'], m['rb'], 90, 180, r)
      tube(e, pt_local(o, s, m['xw'], m['z2']), Z_AXIS.reverse, (m['z2'] - m['zb']).cm, r)
      colorier(e, GRIS_ZINC)
      if nais
        ux = (u.cross(s).z > 0) ? u : u.reverse
        base = o.offset(ux, -nais['l0'].to_f / 2.0).offset(s, (m['xg'] - pe['cx'] - 0.22).cm).offset(Z_AXIS, (m['z0'] - 6.3).cm)
        inst = e.add_instance(A2M::Bibliotheque.charger(nais, model), Geom::Transformation.axes(base, ux, s, Z_AXIS))
        inst.name = 'Naissance' if inst
      end
      col = pe && pe['collier'] && de[0] == 'd80' ? pe['collier'] : nil
      m['colliers'].each { |z| col ? collier_objet(model, grp, col, o, s, m, z) : collier(grp, o, s, m, z) }
      reg = pe && pe['regard'] ? pe['regard'] : nil
      if p['regard'] && reg
        dr = A2M::Bibliotheque.charger(reg, model)
        bb = dr.bounds
        cible = pt_local(o, s, m['xw'], m['zb'])
        v = cible - Geom::Point3d.new(bb.center.x, bb.center.y, bb.max.z)   # centré sous le tuyau, dessus au bas du tuyau
        ir = grp.entities.add_instance(dr, Geom::Transformation.translation(v))
        ir.name = 'Regard en pied' if ir
      elsif p['regard']
        ey = Z_AXIS.cross(s); ey.normalize!
        sg = grp.entities.add_group
        pts = [[-15, -15], [15, -15], [15, 15], [-15, 15]].map { |dx, dy| pt_local(o, s, m['xw'] + dx, m['zb']).offset(ey, dy.cm) }
        f = sg.entities.add_face(pts)
        f.pushpull(f.normal.z > 0 ? -35.cm : 35.cm) if f
        sg.name = 'Regard en pied'
        colorier(sg.entities, [175, 180, 185])
      end
      tg, _ = A2M::Balises.balise(model, 'A2M_DESCENTE', [110, 120, 130])
      grp.layer = tg
      long_m = ((m['z0'] - m['zb']).abs + hz.abs) / 100.0
      grp.name = "Descente #{de[1]} – #{format('%.2f', long_m).tr('.', ',')} m"
      A2M::Modif.noter(grp, 'zinguerie', { 'kind' => 'descente', 'ctx' => ctx, 'p' => p })
      grp.set_attribute('a2m', 'zinguerie', JSON.generate('type' => "Descente #{de[1]}", 'ml' => long_m.round(2)))
      [grp, m]
    end

    # Distance horizontale de l'égout au mur le plus proche (cm), cherchée vers l'intérieur à plusieurs hauteurs ; nil si rien trouvé
    def self.distance_mur(model, o, s)
      [30, 60, 100, 150, 220].each do |dz|
        dep = o.offset(Z_AXIS, -dz.cm)
        h = model.raytest([dep, s.reverse])
        next unless h
        chemin = h[1].select { |x| x.respond_to?(:layer) }
        next if chemin.any? { |x| x.layer.name.to_s =~ /TOITURE|COUVERTURE|CHARPENTE|GOUTTIERE|DESCENTE/ }
        dist = cm_de(dep.distance(h[0]))
        return dist if dist > 0.5 && dist < 400
      end
      nil
    end

    # ---------------- Placement au clic sur l'égout ----------------
    class OutilDescente
      def initialize(lst) @lst = lst; @best = nil end
      def activate
        Sketchup.status_text = 'Descente : cliquez sur l\'égout (bas du pan de toiture) à l\'endroit voulu. Échap pour annuler.'
      end
      def meilleur(p)
        best = nil
        @lst.each do |a, b, s|
          d = b - a; l = d.length; next if l < 1.mm
          u = d.normalize
          t = [[(p - a).dot(u), 0.0].max, l].min
          q = a.offset(u, t)
          di = q.distance(p)
          best = [di, a, b, s, t, q] if best.nil? || di < best[0]
        end
        best
      end
      def onMouseMove(_f, x, y, view)
        ip = Sketchup::InputPoint.new; ip.pick(view, x, y)
        @best = meilleur(ip.position)
        view.invalidate
      end
      def draw(view)
        return unless @best
        view.line_width = 4; view.drawing_color = Sketchup::Color.new(224, 120, 56)
        view.draw_line(@best[1], @best[2])
        view.draw_points([@best[5]], 12, 2, Sketchup::Color.new(224, 120, 56))
      end
      def onLButtonDown(_f, _x, _y, _v)
        return unless @best
        b = @best
        Sketchup.active_model.select_tool(nil)
        UI.start_timer(0.1, false) { A2M::Zinguerie.nouvelle_descente(b[1], b[2], b[3], b[4]) }
      end
    end

    def self.poser(r)
      model = Sketchup.active_model
      g = GOUTTIERES.find { |x| x[0] == r['g'] } or return
      @r_en_cours = r.reject { |k, _| k == 'cible' }
      lst = egouts(model, r['cible'])
      return UI.messagebox('Aucun égout trouvé. Générez d\'abord la toiture, ou sélectionnez des arêtes horizontales en bas de pan.') if lst.empty?
      model.start_operation('Gouttières Atelier 2M', true)
      begin
        model.entities.grep(Sketchup::Group).each { |x| x.erase! if x.valid? && x.layer.name == 'A2M_GOUTTIERE' } if r['cible'] == 'tout'
        ml = 0.0
        lst.each do |a, b, s|
          grp, l = gouttiere(model, a, b, s, g, r['crochet'].to_f.nonzero? || 50)
          ml += l if grp
        end
        model.commit_operation
        Sketchup.status_text = "Gouttières posées : #{format('%.1f', ml).tr('.', ',')} ml. Pour les descentes : « Placer une descente »."
        envoyer_msg("Gouttières posées : #{format('%.1f', ml).tr('.', ',')} ml.")
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Gouttières impossibles : #{ex.message}\n#{ex.backtrace.first}")
      end
    end

    def self.envoyer_msg(t)
      @fen.execute_script("document.getElementById('msg').textContent=#{JSON.generate(t)}") if @fen && (@fen.visible? rescue false)
    end

    # ---------------- Descente : création, mise à jour en direct, réouverture ----------------
    def self.placer
      model = Sketchup.active_model
      lst = egouts(model, 'tout')
      lst = egouts(model, 'sel') if lst.empty?
      return UI.messagebox('Aucun égout trouvé. Générez d\'abord la toiture (ou sélectionnez une arête horizontale en bas de pan).') if lst.empty?
      model.select_tool(OutilDescente.new(lst))
    end

    def self.nouvelle_descente(a, b, s, t)
      model = Sketchup.active_model
      o = a.offset((b - a).normalize, t)
      sn = s.clone; sn.normalize!
      deb = distance_mur(model, o, sn)
      g = GOUTTIERES.find { |x| x[0] == (@derniere_g || 'demi25') } || GOUTTIERES[0]
      p = PARAM_DEFAUT.merge('g' => g[0], 'd' => g[5], 't' => (t.to_f * 0.0254).round(2), 'deb' => (deb || 60.0).round(1))
      ctx = { 'a' => a.to_a, 'b' => b.to_a, 's' => sn.to_a, 'sol' => zsol(model).to_f, 'long' => (b - a).length.to_f * 0.0254 }
      @cur = { 'grp' => nil, 'ctx' => ctx, 'p' => p, 'premier' => true }
      ouvrir
      reconstruire(true)
      envoyer_msg(deb ? '' : 'Aucun mur trouvé sous cet égout : réglez la distance égout → mur à la main.')
    end

    def self.reconstruire(reset = false)
      return unless @cur
      model = Sketchup.active_model
      model.start_operation('Descente Atelier 2M', true, false, !@cur['premier'])
      begin
        old = @cur['grp']
        old.erase! if old && old.valid?
        grp, m = monter_descente(model, @cur['ctx'], @cur['p'])
        @cur['grp'] = grp; @cur['premier'] = false
        cle = [@cur['p']['t'], @cur['p']['g'], @cur['p']['d']]
        if @cur['cle_gout'] != cle
          refaire_gouttiere(model, @cur['ctx'])   # la gouttière est coupée à la naissance
          @cur['cle_gout'] = cle
        end
        model.commit_operation
        envoyer_etat(m, reset)
      rescue StandardError => ex
        model.abort_operation
        envoyer_msg("Descente impossible : #{ex.message}")
      end
    end

    def self.envoyer_etat(m, reset)
      return unless @fen && @cur
      @fen.execute_script("etat(#{JSON.generate(@cur['p'])},#{JSON.generate(m)},#{reset ? 'true' : 'false'})")
    end

    def self.maj(json)
      return unless @cur
      pn = (JSON.parse(json.to_s) rescue nil) or return
      @cur['p'] = @cur['p'].merge(pn)
      @derniere_g = @cur['p']['g']
      reconstruire(false)
    end

    def self.valider
      @cur = nil
    end

    def self.supprimer
      return unless @cur
      g = @cur['grp']
      if g && g.valid?
        Sketchup.active_model.start_operation('Supprimer la descente', true)
        g.erase!
        refaire_gouttiere(Sketchup.active_model, @cur['ctx'])   # la gouttière redevient continue
        Sketchup.active_model.commit_operation
      end
      @cur = nil
    end

    # Rouvre la zinguerie posée : gouttières (même réglages, refaites sur tous les égouts) ou une descente avec sa coupe
    def self.modifier(grp, d)
      return UI.messagebox('Cette zinguerie n\'a pas gardé ses réglages : reposez-la une fois.') unless d
      if d['kind'] == 'descente'
        @cur = { 'grp' => grp, 'ctx' => d['ctx'], 'p' => PARAM_DEFAUT.merge(d['p'] || {}), 'premier' => false }
        ouvrir
        UI.start_timer(0.2, false) { reconstruire(true) }
        return
      end
      return UI.messagebox('Cette zinguerie n\'a pas gardé ses réglages : reposez-la une fois.') unless d['r']
      @fen.close if @fen && (@fen.visible? rescue false)
      ouvrir(d['r'].merge('cible' => 'tout'))
    end

    def self.ouvrir(pre = nil)
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      d = { 'gout' => GOUTTIERES.map { |k, l, a, _r, f, ds| { 'cle' => k, 'libelle' => l, 'aide' => a, 'forme' => f.to_s, 'desc' => ds } },
            'desc' => DESCENTES.map { |k, l, _r| { 'cle' => k, 'libelle' => l } } }
      html = A2M::Panneau.page('Zinguerie', 'Gouttières, crochets, descentes, colliers et regard', CORPS,
                               pre ? SCRIPT + A2M::Modif.js_prerempli(pre, 'Appliquer la modification') : SCRIPT, d)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : zinguerie', 'A2M_Panneau_Zinguerie', html, 520, 900)
      @fen = dlg
      dlg.add_action_callback('pret') { |_c, _j| UI.start_timer(0, false) { reconstruire(true) if @cur && @cur['grp'] } }
      dlg.add_action_callback('poser') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) { poser(r) } if r
      end
      dlg.add_action_callback('placer') { |_c, _j| UI.start_timer(0, false) { placer } }
      dlg.add_action_callback('maj') { |_c, json| UI.start_timer(0, false) { maj(json) } }
      dlg.add_action_callback('valider') { |_c, _j| valider }
      dlg.add_action_callback('supprimer') { |_c, _j| UI.start_timer(0, false) { supprimer } }
      dlg.set_on_closed { @fen = nil; @cur = nil }
      dlg.show
    end
  end
end



