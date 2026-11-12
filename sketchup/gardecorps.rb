# encoding: UTF-8
# Métré Atelier 2M : garde-corps (poteaux, main courante, remplissage barreaux / câbles / verre / lisses) le long d'un tracé 3D
require 'sketchup.rb'
require 'json'

module A2M
  module GardeCorps
    TAG = 'A2M_GARDE_CORPS'
    # clé, libellé, aide
    REMPLISSAGES = [
      ['barreaux', 'Barreaudage vertical', 'Barreaux verticaux, espacement inférieur à 11 cm (norme)'],
      ['cables',   'Câbles inox',          'Câbles horizontaux tous les 10 cm'],
      ['verre',    'Verre feuilleté',      'Panneau vitré entre les poteaux'],
      ['lisses',   'Lisses horizontales',  'Trois lisses en bois ou métal'],
      ['plein',    'Panneau plein',        'Lisse haute et panneau plein (bois, tôle)'],
      ['verre_pinces', 'Verre sur pinces',     'Verre fixé par des pinces rondes inox sur chaque poteau'],
      ['verre_profil', 'Verre en profilé',     'Verre continu tenu par un profilé au sol, sans poteaux intermédiaires'],
      ['grille',   'Grille métallique',    'Mailles soudées : tiges verticales et horizontales fines']
    ].freeze
    MATIERES = {
      'Bois chêne' => [176, 140, 96], 'Bois blanc' => [240, 240, 236], 'Métal noir' => [40, 42, 46],
      'Inox' => [185, 190, 196], 'Laiton' => [190, 150, 80]
    }.freeze

    CORPS = <<~'HTML'
      <h2>Remplissage</h2>
      <div class="grille" id="rempl"></div>
      <h2>Dimensions</h2>
      <div class="dims">
        <div><label>Hauteur (cm)</label><input type="text" id="haut" value="100"></div>
        <div><label>Entraxe poteaux (cm)</label><input type="text" id="ent" value="120"></div>
      </div>
      <h2>Matière</h2>
      <div class="puces" id="mat"></div>
      <h2>Sur quoi</h2>
      <div class="puces" id="cible"></div>
      <div class="petit">« Tracé sélectionné » : sélectionnez des arêtes (bord de dalle, de balcon, limon d'escalier). « Escaliers » : les côtés libres des escaliers posés avec l'outil Escalier.</div>
      <div id="bas"><div id="msg"></div><button type="button" id="go">Poser le garde-corps</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      var s = { r: 'barreaux', mat: 'Métal noir', cible: 'sel' };
      function rendre() {
        var g = el('rempl'); g.innerHTML = '';
        D.rempl.forEach(function (t) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte' + (s.r === t.cle ? ' rempli' : '');
          var m = { barreaux: '<path d="M10 10 V32 M16 10 V32 M22 10 V32 M28 10 V32 M34 10 V32 M38 10 V32"/>', cables: '<path d="M8 14 H40 M8 20 H40 M8 26 H40 M8 32 H40"/>', verre: '<rect x="9" y="12" width="30" height="20" fill="#BFE0F5"/>', lisses: '<path d="M8 16 H40 M8 24 H40 M8 32 H40" stroke-width="2.4"/>', plein: '<rect x="9" y="16" width="30" height="16" fill="#E6C58F"/>' }[t.cle];
          b.innerHTML = '<div class="vignette"><svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1.2"><path d="M8 8 H40" stroke="#E07838" stroke-width="2.4"/>' + m + '<path d="M8 8 V34 M40 8 V34"/></svg></div><span></span><div class="petit" style="margin:2px 0 0"></div>';
          b.querySelector('span').textContent = t.libelle; b.querySelector('.petit').textContent = t.aide;
          b.addEventListener('click', function () { s.r = t.cle; rendre(); }); g.appendChild(b);
        });
        var m = el('mat'); m.innerHTML = '';
        D.mat.forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s.mat === x ? ' rempli' : ''); b.textContent = x;
          b.addEventListener('click', function () { s.mat = x; rendre(); }); m.appendChild(b);
        });
        var c = el('cible'); c.innerHTML = '';
        [['sel', 'Tracé sélectionné'], ['esc', 'Escaliers']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s.cible === x[0] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { s.cible = x[0]; rendre(); }); c.appendChild(b);
        });
      }
      el('go').addEventListener('click', function () { s.haut = el('haut').value; s.ent = el('ent').value; sketchup.poser(JSON.stringify(s)); });
      rendre();
    JS

    class << self; attr_reader :dernier_g, :posts; end

    def self.nombre(v, d) (Float(v.to_s.tr(',', '.')) rescue d) end

    # Barre pleine entre a et b : section l (largeur horizontale) × h, centrée sur l'axe a-b
    def self.barre(ents, a, b, l, h, couleur, verre = false, rond = false)
      d = b - a
      return nil if d.length < 0.5.mm
      d.normalize!
      lat = Z_AXIS.cross(d)
      lat = lat.length < 0.001 ? X_AXIS.clone : lat
      lat.normalize!
      up = lat.cross(d); up.normalize!
      if rond
        cercle = ents.add_circle(a, d, [l, h].min / 2.0, 12)
        fc = ents.add_face(cercle)
        return nil unless fc
        fc.reverse! if fc.normal.dot(d) < 0
        fc.pushpull(a.distance(b))
        c = Sketchup::Color.new(*couleur)
        ents.grep(Sketchup::Face).each { |x| next unless x.material.nil?; x.material = c; x.back_material = c }
        return nil
      end
      pts = [a.offset(lat, -l / 2).offset(up, -h / 2), a.offset(lat, l / 2).offset(up, -h / 2), a.offset(lat, l / 2).offset(up, h / 2), a.offset(lat, -l / 2).offset(up, h / 2)]
      f = ents.add_face(pts)
      return nil unless f
      f.reverse! if f.normal.dot(d) < 0
      f.pushpull(a.distance(b))
      c = Sketchup::Color.new(*couleur)
      ents.grep(Sketchup::Face).each { |x| next unless x.material.nil?; x.material = c; x.back_material = c }
      nil
    end

    # Systèmes de fixation des poteaux : clé, libellé, aide
    FIXATIONS = [
      ['plat',    'Platine carrée sur dessus', 'Platine 12 × 12 cm vissée sur le dessus, 4 boulons'],
      ['rosace',  'Platine ronde (rosace)',    'Rosace ronde de 12 cm avec cache de finition'],
      ['lateral', 'Fixation en chant',         'Platine verticale sur le nez de dalle ou le limon, 2 boulons'],
      ['scelle',  'Scellé avec collerette',    'Poteau scellé de 10 cm dans le béton, collerette de finition'],
      ['aucune',  'Poteau posé directement',   'Pas de platine : poteau seul']
    ].freeze
    MAINS = [['tube', 'Tube'], ['plat', 'Plat bois'], ['aucune', 'Sans main courante']].freeze

    def self.colorer(ents, couleur, alpha = nil)
      if alpha
        mats = ents.model.materials
        c = mats['A2M_GC_Verre'] || mats.add('A2M_GC_Verre')
        c.color = Sketchup::Color.new(*couleur); c.alpha = alpha
      else
        c = Sketchup::Color.new(*couleur)
      end
      ents.grep(Sketchup::Face).each { |x| next unless x.material.nil?; x.material = c; x.back_material = c }
    end

    # Prisme à base rectangulaire horizontale (a le long de dh, b le long de lat), de z0 à z0 + h au-dessus du point c
    def self.plaque_h(ents, c, dh, lat, a, b, z0, h, couleur)
      o = Geom::Point3d.new(c.x, c.y, c.z + z0)
      f = ents.add_face(o.offset(dh, -a / 2).offset(lat, -b / 2), o.offset(dh, a / 2).offset(lat, -b / 2), o.offset(dh, a / 2).offset(lat, b / 2), o.offset(dh, -a / 2).offset(lat, b / 2))
      return unless f
      f.reverse! if f.normal.z < 0
      f.pushpull(h)
      colorer(ents, couleur)
    end

    def self.disque(ents, c, r, z0, h, couleur)
      o = Geom::Point3d.new(c.x, c.y, c.z + z0)
      f = ents.add_face(ents.add_circle(o, Z_AXIS, r, 16))
      return unless f
      f.reverse! if f.normal.z < 0
      f.pushpull(h)
      colorer(ents, couleur)
    end

    # Plaque verticale parallèle au tracé, à la distance off (signée) du point c, d'épaisseur ep vers le côté de off
    def self.plaque_v(ents, c, dh, lat, w, z0, z1, off, ep, couleur)
      s = off < 0 ? -1 : 1
      o = Geom::Point3d.new(c.x, c.y, c.z).offset(lat, off)
      f = ents.add_face(o.offset(dh, -w / 2).offset(Z_AXIS, z0), o.offset(dh, w / 2).offset(Z_AXIS, z0), o.offset(dh, w / 2).offset(Z_AXIS, z1), o.offset(dh, -w / 2).offset(Z_AXIS, z1))
      return unless f
      f.reverse! if f.normal.dot(lat) * s < 0
      f.pushpull(ep)
      colorer(ents, couleur)
    end

    # Tracé décalé latéralement de d (angles en onglet)
    def self.decaler(pts, d)
      segs = (0...pts.size - 1).map { |i| v = pts[i + 1] - pts[i]; v.z = 0; v.length < 0.001 ? nil : (v.normalize!; Z_AXIS.cross(v)) }
      pts.each_with_index.map do |p, i|
        n1 = i > 0 ? segs[i - 1] : nil; n2 = segs[i]
        n1 ||= n2; n2 ||= n1
        next p unless n1
        s = n1 + n2; k = 1 + n1.dot(n2)
        m = s.length > 0.001 && k > 0.2 ? Geom::Vector3d.new(s.x / k, s.y / k, 0) : n1
        p.offset(Geom::Vector3d.new(m.x * d, m.y * d, 0))
      end
    end

    # Panneau mince (verre, plein) entre deux poteaux : de bas à haut
    def self.panneau(ents, a, b, db, dt, ep, couleur, alpha = nil)   # db, dt : hauteurs du bas et du haut au-dessus de chaque extrémité (le panneau suit la pente)
      d = b - a; d.z = 0
      return if d.length < 1.cm
      d.normalize!
      lat = Z_AXIS.cross(d); lat.normalize!
      pts = [a.offset(Z_AXIS, db).offset(lat, -ep / 2), b.offset(Z_AXIS, db).offset(lat, -ep / 2), b.offset(Z_AXIS, dt).offset(lat, -ep / 2), a.offset(Z_AXIS, dt).offset(lat, -ep / 2)]
      f = ents.add_face(pts)
      return unless f
      f.reverse! if f.normal.dot(lat) < 0
      f.pushpull(ep)
      colorer(ents, couleur, alpha)
    end

    # Pose le garde-corps le long d'une polyligne de points 3D (le dessus de la main courante suit le tracé + hauteur)
    def self.poser_chemin(model, pts0, r)
      cle = r['r']; hauteur = nombre(r['haut'], 100).cm; ent = nombre(r['ent'], 120).cm
      pot = nombre(r['pot'], 4).cm; esp = [nombre(r['esp'], 10), 3].max.cm; bas = nombre(r['bas'], 8).cm; pas_c = [nombre(r['pas'], 10), 3].max.cm; nl = [nombre(r['nl'], 3).to_i, 1].max
      @dernier_g = nil; @posts ||= []
      couleur = MATIERES[r['mat']] || MATIERES['Métal noir']
      inox = MATIERES['Inox']
      rd = r['prof'] != 'carre'
      renf = r['fort'] != false ? 1.5 : 1.0   # poteaux de départ et d'arrivée renforcés
      fix = r['fix'] || 'aucune'
      mc = r['mc'] || 'tube'
      cote = r['cote'].to_i == -1 ? -1 : 1
      hr = { 'tube' => (rd ? 4.2.cm : 4.cm), 'plat' => 3.5.cm }[mc] || 0.0   # épaisseur de la main courante : son dessus est à la hauteur réglée
      zr = hauteur - hr / 2
      ytop = hauteur - (mc == 'aucune' ? 2.cm : hr - 0.5.cm)
      pts = fix == 'lateral' ? decaler(pts0, cote * (pot / 2 + 1.cm)) : pts0
      zb = { 'plat' => 1.cm, 'rosace' => 1.cm, 'lateral' => -20.cm, 'scelle' => -10.cm }[fix] || 0.0
      sans_inter = (cle == 'verre_profil')
      tag, _ = A2M::Balises.balise(model, TAG, [60, 60, 66])
      g = model.entities.add_group
      g.layer = tag
      g.name = "Garde-corps – #{REMPLISSAGES.find { |x| x[0] == cle }[1]}"
      e = g.entities
      ml = 0.0; npot = 0; npinces = 0
      (0...pts.size - 1).each do |i|
        a = pts[i]; b = pts[i + 1]
        l = a.distance(b)
        next if l < 3.cm
        ml += l
        n = [(l / ent).ceil, 1].max
        pas = l / n
        dir = b - a; dir.normalize!
        dh = dir.clone; dh.z = 0; dh = dh.length < 0.001 ? X_AXIS.clone : dh.normalize
        lat = Z_AXIS.cross(dh)
        # poteaux et leur fixation
        (0..n).each do |k|
          p = a.offset(dir, pas * k)
          next unless k < n || i == pts.size - 2
          ex = (i == 0 && k == 0) || (i == pts.size - 2 && k == n)
          next if sans_inter && !ex
          sp = ex ? pot * renf : pot
          barre(e, p.offset(Z_AXIS, zb), p.offset(Z_AXIS, ex ? hauteur + 2.cm : (mc == 'aucune' ? hauteur : zr)), sp, sp, couleur, false, rd)
          @posts << p; npot += 1
          case fix
          when 'plat'
            plaque_h(e, p, dh, lat, 12.cm, 12.cm, 0, 1.cm, inox)
            [[-1, -1], [1, -1], [1, 1], [-1, 1]].each { |sx, sy| disque(e, p.offset(dh, sx * 4.2.cm).offset(lat, sy * 4.2.cm), 0.6.cm, 1.cm, 0.8.cm, inox) }
          when 'rosace'
            disque(e, p, 6.cm, 0, 1.cm, inox)
            disque(e, p, [sp * 0.8, 3.cm].max, 1.cm, 1.5.cm, inox)
          when 'scelle'
            disque(e, p, [sp * 1.1, 3.cm].max, 0, 1.2.cm, inox)
          when 'lateral'
            plaque_v(e, p, dh, lat, 10.cm, -16.cm, 4.cm, -cote * pot / 2, 1.cm, inox)
            [-10.cm, -2.cm].each { |z| barre(e, p.offset(lat, -cote * (pot / 2 + 1.cm)).offset(Z_AXIS, z), p.offset(lat, -cote * (pot / 2 + 1.8.cm)).offset(Z_AXIS, z), 1.6.cm, 1.6.cm, inox, false, true) }
          end
        end
        # main courante sur le dessus
        # main courante : son dessus est à la hauteur réglée ; aux angles intérieurs elle dépasse d'une demi-section pour que les tronçons se rejoignent
        ext = [hr, rd ? 4.2.cm : 5.cm].max / 2
        ha = (i > 0 ? a.offset(dir, -ext) : a).offset(Z_AXIS, zr); hb = (i < pts.size - 2 ? b.offset(dir, ext) : b).offset(Z_AXIS, zr)
        case mc
        when 'tube' then barre(e, ha, hb, rd ? 4.2.cm : 5.cm, rd ? 4.2.cm : 4.cm, couleur, false, rd)
        when 'plat' then barre(e, ha, hb, 7.cm, 3.5.cm, couleur)
        end
        htop = hauteur - (mc == 'aucune' ? 0 : 2.cm)
        case cle
        when 'barreaux'
          nb = (l / esp).floor
          (1..nb).each do |k|
            p = a.offset(dir, l * k / (nb + 1.0))
            barre(e, p.offset(Z_AXIS, bas), p.offset(Z_AXIS, ytop), 1.4.cm, 1.4.cm, couleur, false, rd)
          end
          barre(e, a.offset(Z_AXIS, bas), b.offset(Z_AXIS, bas), 3.cm, 2.cm, couleur)
        when 'cables'
          z = 12.cm
          while z < hauteur - 4.cm
            barre(e, a.offset(Z_AXIS, z), b.offset(Z_AXIS, z), 0.6.cm, 0.6.cm, inox); z += pas_c
          end
        when 'verre'
          (0...n).each { |k| p = a.offset(dir, pas * k + 3.cm); q = a.offset(dir, pas * (k + 1) - 3.cm); panneau(e, p, q, bas, hauteur - 4.cm, 1.cm, [170, 205, 225], 0.4) }
        when 'verre_pinces'
          (0...n).each do |k|
            p = a.offset(dir, pas * k + pot / 2 + 0.5.cm); q = a.offset(dir, pas * (k + 1) - pot / 2 - 0.5.cm)
            z0 = bas; z1 = hauteur - 4.cm
            panneau(e, p, q, z0, z1, 1.cm, [170, 205, 225], 0.4)
            [[p, 1], [q, -1]].each do |pe, sg|
              c = pe.offset(dh, sg * 2.cm)
              [z0 + 8.cm, z1 - 8.cm].each do |zz|
                cp = Geom::Point3d.new(c.x, c.y, c.z + zz)
                barre(e, cp.offset(lat, -1.3.cm), cp.offset(lat, 1.3.cm), 5.cm, 5.cm, inox, false, true); npinces += 1
              end
            end
          end
        when 'verre_profil'
          barre(e, a.offset(Z_AXIS, 4.cm), b.offset(Z_AXIS, 4.cm), 6.cm, 8.cm, inox)
          (0...n).each { |k| p = a.offset(dir, pas * k + 0.5.cm); q = a.offset(dir, pas * (k + 1) - 0.5.cm); panneau(e, p, q, 7.cm, htop, 1.2.cm, [170, 205, 225], 0.4) }
        when 'grille'
          nb = (l / esp).floor
          (1..nb).each { |k| p = a.offset(dir, l * k / (nb + 1.0)); barre(e, p.offset(Z_AXIS, bas), p.offset(Z_AXIS, ytop), 0.8.cm, 0.8.cm, couleur, false, true) }
          z = bas + pas_c / 2
          while z < hauteur - 3.cm
            barre(e, a.offset(Z_AXIS, z), b.offset(Z_AXIS, z), 0.8.cm, 0.8.cm, couleur, false, true); z += pas_c
          end
        when 'lisses'
          (1..nl).map { |j| j / (nl + 1.0) }.each { |t| barre(e, a.offset(Z_AXIS, hauteur * t), b.offset(Z_AXIS, hauteur * t), rd ? 3.cm : 4.cm, rd ? 3.cm : 2.cm, couleur, false, rd) }
        when 'plein'
          (0...n).each { |k| p = a.offset(dir, pas * k + 2.cm); q = a.offset(dir, pas * (k + 1) - 2.cm); panneau(e, p, q, bas, hauteur - 6.cm, 2.cm, [190, 150, 100]) }
        end
      end
      A2M::Modif.noter(g, 'garde_corps', { 'r' => r.reject { |k, _| k == 'replacer' }, 'pts' => A2M::Modif.pts_vers(pts0) })
      nfix = fix == 'aucune' ? 0 : npot
      g.set_attribute('a2m', 'garde_corps', JSON.generate('type' => cle, 'ml' => (ml.to_f * 0.0254).round(2), 'hauteur' => (hauteur.to_f * 2.54).round(0),
                                                          'poteaux' => npot, 'fixation' => (FIXATIONS.find { |x| x[0] == fix } || [])[1], 'nb_fixations' => nfix, 'pinces' => npinces))
      @dernier_g = g
      ml * 0.0254
    end

    # Refait le garde-corps sur ces chemins (fenêtre à réglages en direct) ; retourne [groupes, ml]
    def self.refaire(chs, r, anciens, transparent)
      model = Sketchup.active_model
      model.start_operation('Garde-corps', true, false, transparent)
      begin
        anciens.each { |g| g.erase! if g && g.valid? }
        @posts = []
        gs = []; ml = 0.0
        chs.each { |c| ml += poser_chemin(model, c, r); gs << @dernier_g }
        model.commit_operation
        [gs, ml]
      rescue StandardError
        model.abort_operation
        raise
      end
    end

    # Chaînes de points à partir des arêtes sélectionnées (bout à bout)
    def self.chemins_selection(model)
      aretes = model.selection.grep(Sketchup::Edge).dup
      res = []
      until aretes.empty?
        ch = [aretes.shift]
        loop do
          fin = ch.last.end.position
          s = aretes.find { |x| x.start.position == fin || x.end.position == fin }
          break unless s
          aretes.delete(s)
          ch << s
        end
        pts = [ch[0].start.position]
        ch.each { |x| pts << (x.start.position == pts.last ? x.end.position : x.start.position) }
        res << pts
      end
      res
    end

    def self.chemins_escaliers(model)
      res = []
      A2M::Plan2D.parcourir(model.entities, Geom::Transformation.new) do |e, t|
        d = e.get_attribute('a2m', 'escalier_gc') or next
        (JSON.parse(d) rescue []).each { |ch| res << ch.map { |p| t * Geom::Point3d.new(*p) } }
      end
      res
    end

    def self.poser(r)
      model = Sketchup.active_model
      reprise = @modif && !r['replacer']
      chs = reprise ? [@modif[:pts]] : (r['cible'] == 'esc' ? chemins_escaliers(model) : chemins_selection(model))
      return UI.messagebox(r['cible'] == 'esc' ? 'Aucun escalier de l\'outil Escalier dans le modèle.' : 'Sélectionnez d\'abord des arêtes (le tracé du garde-corps).') if chs.empty?
      model.start_operation('Garde-corps', true)
      begin
        @modif[:grp].erase! if @modif && @modif[:grp] && @modif[:grp].valid?
        @modif = nil
        ml = chs.sum { |c| poser_chemin(model, c, r) }
        model.commit_operation
        UI.messagebox("Garde-corps posé : #{format('%.2f', ml).tr('.', ',')} ml.")
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Garde-corps impossible : #{ex.message}\n#{ex.backtrace.first}")
      end
    end

    # Rouvre un garde-corps posé : mêmes réglages, même tracé (ou nouveau tracé sur les arêtes sélectionnées)
    def self.modifier(grp, d)
      return UI.messagebox('Ce garde-corps n\'a pas gardé son tracé : reposez-le une fois.') unless d && d['r'] && d['pts']
      @fen.close if @fen && (@fen.visible? rescue false)
      ouvrir(d['r'], { grp: grp, pts: A2M::Modif.pts_de(d['pts']) })
    end

    def self.ouvrir(pre = nil, modif = nil)
      @modif = modif
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      d = { 'rempl' => REMPLISSAGES.map { |k, l, a| { 'cle' => k, 'libelle' => l, 'aide' => a } }, 'mat' => MATIERES.keys }
      html = A2M::Panneau.page(modif ? 'Modifier le garde-corps' : 'Garde-corps', 'Poteaux, main courante et remplissage le long d\'un tracé', CORPS,
                               modif ? SCRIPT + A2M::Modif.js_prerempli(pre, 'Appliquer la modification', 'Prendre un nouveau tracé : arêtes sélectionnées (ou escalier)') : SCRIPT, d)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : garde-corps', 'A2M_Panneau_GC', html, 460, 760)
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
