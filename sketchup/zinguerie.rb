# encoding: UTF-8
# Métré Atelier 2M : zinguerie (gouttières, descentes d'eaux pluviales) posée automatiquement sur les égouts de la toiture
require 'sketchup.rb'
require 'json'

module A2M
  module Zinguerie
    # clé, libellé, aide, rayon extérieur cm, forme
    GOUTTIERES = [
      ['demi25',  'Demi-ronde développé 25', 'Gouttière pendante classique, 8 cm de large', 6.0, :demi],
      ['demi33',  'Demi-ronde développé 33', 'Gouttière demi-ronde plus grande',           8.0, :demi],
      ['nant',    'Nantaise (carrée)',       'Gouttière à fond plat, profil carré',         7.0, :carre]
    ].freeze
    DESCENTES = [['d80', 'Descente Ø 80', 4.0], ['d100', 'Descente Ø 100', 5.0]].freeze

    CORPS = <<~'HTML'
      <h2>Gouttière</h2>
      <div class="grille" id="gout"></div>
      <h2>Descente d'eaux pluviales</h2>
      <div class="puces" id="desc"></div>
      <div class="petit">Une descente est posée à chaque extrémité de gouttière (à partir de 2 descentes par pan de plus de 12 m, une au milieu).</div>
      <h2>Sur quoi</h2>
      <div class="puces" id="cible"></div>
      <div class="petit">« Égouts sélectionnés » : sélectionnez des arêtes horizontales en bas de pan. « Tous les égouts » : repérés automatiquement dans les groupes de toiture.</div>
      <div id="bas"><div id="msg"></div><button type="button" id="go">Poser la zinguerie</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      var s = { g: 'demi25', d: 'd80', cible: 'tout', avecDesc: true };
      function rendre() {
        var g = el('gout'); g.innerHTML = '';
        D.gout.forEach(function (t) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte' + (s.g === t.cle ? ' rempli' : '');
          var arc = t.forme === 'demi' ? '<path d="M10 16 A14 14 0 0 0 38 16" fill="none" stroke="#E07838" stroke-width="2.4"/>' : '<path d="M10 14 V30 H38 V14" fill="none" stroke="#E07838" stroke-width="2.4"/>';
          b.innerHTML = '<div class="vignette"><svg viewBox="0 0 48 40" width="60" height="50"><path d="M4 10 H44" stroke="#3C3C3C"/>' + arc + '</svg></div><span></span><div class="petit" style="margin:2px 0 0"></div>';
          b.querySelector('span').textContent = t.libelle; b.querySelector('.petit').textContent = t.aide;
          b.addEventListener('click', function () { s.g = t.cle; rendre(); }); g.appendChild(b);
        });
        var d = el('desc'); d.innerHTML = '';
        D.desc.forEach(function (t) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s.avecDesc && s.d === t.cle ? ' rempli' : ''); b.textContent = t.libelle;
          b.addEventListener('click', function () { s.d = t.cle; s.avecDesc = true; rendre(); }); d.appendChild(b);
        });
        var n = document.createElement('button'); n.type = 'button'; n.className = 'puce' + (!s.avecDesc ? ' rempli' : ''); n.textContent = 'Sans descente';
        n.addEventListener('click', function () { s.avecDesc = false; rendre(); }); d.appendChild(n);
        var c = el('cible'); c.innerHTML = '';
        [['tout', 'Tous les égouts'], ['sel', 'Égouts sélectionnés']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s.cible === x[0] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { s.cible = x[0]; rendre(); }); c.appendChild(b);
        });
      }
      el('go').addEventListener('click', function () { sketchup.poser(JSON.stringify(s)); });
      rendre();
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

    def self.gouttiere(model, a, b, sortie, g)
      sortie = sortie.clone; sortie.normalize!
      d = b - a; l = d.length
      face_pts = profil(g[4], g[3]).map { |w, h| a.offset(sortie, w.cm).offset(Z_AXIS, h.cm) }
      grp = model.entities.add_group
      tg, _ = A2M::Balises.balise(model, 'A2M_GOUTTIERE', [130, 140, 150])
      grp.layer = tg
      grp.name = "Gouttière #{g[1]} – #{(l.to_f * 0.0254).round(2)} m"
      f = grp.entities.add_face(face_pts)
      return grp.erase! unless f
      chemin = grp.entities.add_edges(a, b)
      f.followme(chemin) rescue nil
      grp.entities.grep(Sketchup::Edge).each { |e| e.erase! if e.valid? && e.faces.empty? }
      grp.entities.grep(Sketchup::Face).each { |x| x.material = Sketchup::Color.new(150, 160, 168); x.back_material = Sketchup::Color.new(150, 160, 168) }
      grp.set_attribute('a2m', 'zinguerie', JSON.generate('type' => g[1], 'ml' => (l.to_f * 0.0254).round(2)))
      [grp, (l.to_f * 0.0254)]
    end

    def self.descente(model, pt, sortie, g, de, zsol)
      sortie = sortie.clone; sortie.normalize!
      r = de[2]
      cx = pt.offset(sortie, (g[3] * 0.4 + g[3] * 0.4).cm)
      zhaut = pt.z - 2.cm - g[3].cm
      return nil if zhaut <= zsol + 5.cm
      centre = Geom::Point3d.new(cx.x, cx.y, zhaut)
      grp = model.entities.add_group
      tg, _ = A2M::Balises.balise(model, 'A2M_DESCENTE', [110, 120, 130])
      grp.layer = tg
      grp.name = "#{de[1]} – #{((zhaut - zsol).to_f * 0.0254).round(2)} m"
      c = grp.entities.add_circle(centre, Z_AXIS, r.cm, 24)
      f = grp.entities.add_face(c)
      f.reverse! if f.normal.z > 0
      f.pushpull(zhaut - zsol)
      grp.entities.grep(Sketchup::Face).each { |x| x.material = Sketchup::Color.new(120, 130, 140); x.back_material = Sketchup::Color.new(120, 130, 140) }
      grp.set_attribute('a2m', 'zinguerie', JSON.generate('type' => de[1], 'ml' => ((zhaut - zsol).to_f * 0.0254).round(2)))
      grp
    end

    def self.zsol(model)
      zs = []
      A2M::Plan2D.parcourir(model.entities, Geom::Transformation.new) { |e, t| zs << A2M::Plan2D.coins(e, t).map(&:z).min if e.layer.name == 'A2M_PIECE' }
      zs.empty? ? model.bounds.min.z : zs.min
    end

    def self.poser(r)
      model = Sketchup.active_model
      g = GOUTTIERES.find { |x| x[0] == r['g'] } or return
      de = DESCENTES.find { |x| x[0] == r['d'] } || DESCENTES[0]
      lst = egouts(model, r['cible'])
      return UI.messagebox('Aucun égout trouvé. Générez d\'abord la toiture, ou sélectionnez des arêtes horizontales en bas de pan.') if lst.empty?
      model.start_operation('Zinguerie Atelier 2M', true)
      begin
        model.entities.grep(Sketchup::Group).each { |x| x.erase! if x.valid? && %w[A2M_GOUTTIERE A2M_DESCENTE].include?(x.layer.name) } if r['cible'] == 'tout'
        sol = zsol(model)
        ml = 0.0; nd = 0
        lst.each do |a, b, s|
          grp, l = gouttiere(model, a, b, s, g)
          ml += l if grp
          next unless r['avecDesc']
          pts = [a.offset(a.vector_to(b), 8.cm), b.offset(b.vector_to(a), 8.cm)]
          pts.each { |p| nd += 1 if descente(model, p, s, g, de, sol) }
        end
        model.commit_operation
        UI.messagebox("Zinguerie posée : #{format('%.1f', ml).tr('.', ',')} ml de gouttière#{r['avecDesc'] ? ", #{nd} descente(s)" : ''}.")
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Zinguerie impossible : #{ex.message}\n#{ex.backtrace.first}")
      end
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      d = { 'gout' => GOUTTIERES.map { |k, l, a, _r, f| { 'cle' => k, 'libelle' => l, 'aide' => a, 'forme' => f.to_s } },
            'desc' => DESCENTES.map { |k, l, _r| { 'cle' => k, 'libelle' => l } } }
      html = A2M::Panneau.page('Zinguerie', 'Gouttières et descentes posées sur les égouts de la toiture', CORPS, SCRIPT, d)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : zinguerie', 'A2M_Panneau_Zinguerie', html, 460, 680)
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
