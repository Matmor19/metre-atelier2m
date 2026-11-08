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
      ['plein',    'Panneau plein',        'Lisse haute et panneau plein (bois, tôle)']
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

    def self.nombre(v, d) (Float(v.to_s.tr(',', '.')) rescue d) end

    # Barre pleine entre a et b : section l (largeur horizontale) × h, centrée sur l'axe a-b
    def self.barre(ents, a, b, l, h, couleur, verre = false)
      d = b - a
      return nil if d.length < 0.5.mm
      d.normalize!
      lat = Z_AXIS.cross(d)
      lat = lat.length < 0.001 ? X_AXIS.clone : lat
      lat.normalize!
      up = lat.cross(d); up.normalize!
      pts = [a.offset(lat, -l / 2).offset(up, -h / 2), a.offset(lat, l / 2).offset(up, -h / 2), a.offset(lat, l / 2).offset(up, h / 2), a.offset(lat, -l / 2).offset(up, h / 2)]
      f = ents.add_face(pts)
      return nil unless f
      f.reverse! if f.normal.dot(d) < 0
      f.pushpull(a.distance(b))
      c = Sketchup::Color.new(*couleur)
      ents.grep(Sketchup::Face).each { |x| next unless x.material.nil?; x.material = c; x.back_material = c }
      nil
    end

    # Panneau mince (verre, plein) entre deux poteaux : de bas à haut
    def self.panneau(ents, a, b, z0, z1, ep, couleur)
      d = b - a; d.z = 0
      return if d.length < 1.cm
      d.normalize!
      lat = Z_AXIS.cross(d); lat.normalize!
      p0 = Geom::Point3d.new(a.x, a.y, z0); p1 = Geom::Point3d.new(b.x, b.y, z0)
      pts = [p0.offset(lat, -ep / 2), p1.offset(lat, -ep / 2), Geom::Point3d.new(p1.x, p1.y, z1).offset(lat, -ep / 2), Geom::Point3d.new(p0.x, p0.y, z1).offset(lat, -ep / 2)]
      f = ents.add_face(pts)
      return unless f
      f.reverse! if f.normal.dot(lat) < 0
      f.pushpull(ep)
    end

    # Pose le garde-corps le long d'une polyligne de points 3D (le dessus de la main courante suit le tracé + hauteur)
    def self.poser_chemin(model, pts, r)
      cle = r['r']; hauteur = nombre(r['haut'], 100).cm; ent = nombre(r['ent'], 120).cm
      couleur = MATIERES[r['mat']] || MATIERES['Métal noir']
      tag, _ = A2M::Balises.balise(model, TAG, [60, 60, 66])
      g = model.entities.add_group
      g.layer = tag
      g.name = "Garde-corps – #{REMPLISSAGES.find { |x| x[0] == cle }[1]}"
      e = g.entities
      ml = 0.0
      (0...pts.size - 1).each do |i|
        a = pts[i]; b = pts[i + 1]
        l = a.distance(b)
        next if l < 3.cm
        ml += l
        n = [(l / ent).ceil, 1].max
        pas = l / n
        dir = b - a; dir.normalize!
        # poteaux
        (0..n).each { |k| p = a.offset(dir, pas * k); barre(e, p.offset(Z_AXIS, 0), p.offset(Z_AXIS, hauteur), 4.cm, 4.cm, couleur) if k < n || i == pts.size - 2 }
        # main courante sur le dessus
        ha = a.offset(Z_AXIS, hauteur); hb = b.offset(Z_AXIS, hauteur)
        barre(e, ha, hb, 5.cm, 4.cm, couleur)
        case cle
        when 'barreaux'
          nb = (l / 10.cm).floor
          (1..nb).each do |k|
            p = a.offset(dir, l * k / (nb + 1.0))
            barre(e, p.offset(Z_AXIS, 8.cm), p.offset(Z_AXIS, hauteur - 2.cm), 1.4.cm, 1.4.cm, couleur)
          end
          barre(e, a.offset(Z_AXIS, 8.cm), b.offset(Z_AXIS, 8.cm), 3.cm, 2.cm, couleur)
        when 'cables'
          z = 12.cm
          while z < hauteur - 4.cm
            barre(e, a.offset(Z_AXIS, z), b.offset(Z_AXIS, z), 0.6.cm, 0.6.cm, MATIERES['Inox']); z += 10.cm
          end
        when 'verre'
          (0...n).each { |k| p = a.offset(dir, pas * k + 3.cm); q = a.offset(dir, pas * (k + 1) - 3.cm); panneau(e, p, q, [p.z, q.z].min + 8.cm, [p.z, q.z].max + hauteur - 4.cm, 1.cm, [170, 205, 225]) }
        when 'lisses'
          [0.25, 0.5, 0.75].each { |t| barre(e, a.offset(Z_AXIS, hauteur * t), b.offset(Z_AXIS, hauteur * t), 4.cm, 2.cm, couleur) }
        when 'plein'
          (0...n).each { |k| p = a.offset(dir, pas * k + 2.cm); q = a.offset(dir, pas * (k + 1) - 2.cm); panneau(e, p, q, [p.z, q.z].min + 8.cm, [p.z, q.z].max + hauteur - 6.cm, 2.cm, [190, 150, 100]) }
        end
      end
      A2M::Modif.noter(g, 'garde_corps', { 'r' => r.reject { |k, _| k == 'replacer' }, 'pts' => A2M::Modif.pts_vers(pts) })
      g.set_attribute('a2m', 'garde_corps', JSON.generate('type' => cle, 'ml' => (ml.to_f * 0.0254).round(2), 'hauteur' => (hauteur.to_f * 2.54).round(0)))
      ml * 0.0254
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
