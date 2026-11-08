# encoding: UTF-8
# Métré Atelier 2M : dalle béton, isolant de sol, chape et plafond posés d'un coup à partir des murs sélectionnés.
# Dalle : sous toute l'emprise des murs. Isolant, chape, plafond : dans chaque pièce fermée.
require 'sketchup.rb'
require 'json'

module A2M
  module SolMurs
    # clé, libellé, aide, épaisseur par défaut (cm), balise RDC, balise étage, zone (:emprise | :pieces)
    COUCHES = [
      ['dalle',   'Dalle béton',      'Sous toute l\'emprise des murs, sous le niveau du sol', 12.0, 'A2M_DALLAGE', 'A2M_PLANCHER_ETAGE', :emprise],
      ['isolant', 'Isolation au sol', 'Dans chaque pièce, au-dessus de la dalle',               10.0, 'A2M_ISOLANT_SOL', 'A2M_ISOLANT_SOL', :pieces],
      ['chape',   'Chape',            'Dans chaque pièce, au-dessus de l\'isolant',               5.0, 'A2M_CHAPE', 'A2M_CHAPE', :pieces],
      ['plafond', 'Plafond',          'Dans chaque pièce, à la hauteur sous plafond choisie',     1.3, 'A2M_PLAFOND', 'A2M_PLAFOND', :pieces]
    ].freeze

    # Pièces fermées (contours intérieurs) et emprise extérieure des murs, en coordonnées du modèle
    def self.analyser(model)
      ms = A2M::PiecesAuto.murs(model, A2M::PiecesAuto::MURS + ['A2M_MUR_SOUB'])   # le soubassement porte aussi la dalle
      return nil if ms.empty?
      emp = A2M::PiecesAuto.empreintes(ms)
      z = ms.map { |g| g.bounds.min.z }.min
      bb = Geom::BoundingBox.new; ms.each { |g| bb.add(g.bounds) }
      marge = 1.m
      x0, y0, x1, y1 = bb.min.x - marge, bb.min.y - marge, bb.max.x + marge, bb.max.y + marge
      pieces = []; emprises = []
      model.start_operation('Analyse des murs', true)
      begin
        tmp = model.active_entities.add_group
        te = tmp.entities
        te.add_face([[x0, y0, z], [x1, y0, z], [x1, y1, z], [x0, y1, z]].map { |a| Geom::Point3d.new(*a) })
        emp.each { |loops| loops.each { |lp| te.add_edges((lp + [lp[0]]).map { |x, y| Geom::Point3d.new(x, y, z) }) } }
        te.intersect_with(false, Geom::Transformation.new, te, Geom::Transformation.new, true, te.to_a)
        te.grep(Sketchup::Edge).each { |e| e.find_faces if e.valid? }
        bord = ->(f) { f.vertices.any? { |v| q = v.position; (q.x - x0).abs < 0.1 || (q.x - x1).abs < 0.1 || (q.y - y0).abs < 0.1 || (q.y - y1).abs < 0.1 } }
        te.grep(Sketchup::Face).each do |f|
          if bord.call(f)
            # face extérieure : ses trous sont les emprises des bâtiments
            f.loops.reject(&:outer?).each { |lp| emprises << lp.vertices.map(&:position) }
            next
          end
          m = f.mesh; pts = m.polygon_points_at(1) rescue nil
          next unless pts
          cx = pts.sum(&:x) / 3.0; cy = pts.sum(&:y) / 3.0
          next if A2M::PiecesAuto.dans_un_mur(cx, cy, emp) || f.area * 0.00064516 < 1.0
          pieces << [f.outer_loop.vertices.map(&:position), f.loops.reject(&:outer?).map { |lp| lp.vertices.map(&:position) }]
        end
        tmp.erase!
      ensure
        model.abort_operation
      end
      { pieces: pieces, emprises: emprises, z: z, z_haut: ms.map { |g| g.bounds.max.z }.max }
    end

    def self.groupe(model, nom, tag, surfaces, z, epaisseur_cm, vers_le_bas)
      grp = model.active_entities.add_group
      surfaces.each do |ext, trous|
        f = grp.entities.add_face(ext.map { |q| Geom::Point3d.new(q.x, q.y, z) })
        next unless f
        trous.each { |t| h = grp.entities.add_face(t.map { |q| Geom::Point3d.new(q.x, q.y, z) }); h.erase! if h && h.valid? }
      end
      faces = grp.entities.grep(Sketchup::Face)
      faces.each do |f|
        f.reverse! if vers_le_bas ? f.normal.z > 0 : f.normal.z < 0
        f.pushpull(epaisseur_cm.cm)
      end
      l, _ = A2M::Balises.balise(model, tag, (A2M::Balises::LISTE.find { |n, _, _| n == tag } || [])[2])
      grp.layer = l
      grp.name = nom
      A2M::Hachures.poser(grp, model)
      A2M::Modif.noter(grp, 'solmur', { 'nom' => nom, 'tag' => tag, 'z' => z.to_f, 'e' => epaisseur_cm, 'bas' => vers_le_bas ? true : false,
                                        'surfaces' => surfaces.map { |ext, trous| [ext.map { |q| [q.x.to_f, q.y.to_f] }, (trous || []).map { |t| t.map { |q| [q.x.to_f, q.y.to_f] } }] } })
      grp
    end

    # Rouvre une dalle, chape ou plafond posé depuis les murs : épaisseur et sens (le contour suit les murs : modifiez les murs puis refaites la pose)
    def self.modifier(grp, d)
      return UI.messagebox('Cette surface n\'a pas gardé ses réglages : refaites-la une fois.') unless d && d['surfaces']
      rep = UI.inputbox(['Épaisseur (cm)', 'Sens'], [d['e'].to_s, d['bas'] ? 'Vers le bas' : 'Vers le haut'], ['', 'Vers le haut|Vers le bas'], "Modifier : #{grp.name}")
      return unless rep
      e = rep[0].to_s.tr(',', '.').to_f
      return UI.messagebox('L\'épaisseur doit être supérieure à 0.') if e <= 0
      model = Sketchup.active_model
      model.start_operation('Modifier une surface (métré)', true)
      begin
        surf = d['surfaces'].map { |ext, trous| [ext.map { |x, y| Geom::Point3d.new(x, y, 0) }, trous.map { |t| t.map { |x, y| Geom::Point3d.new(x, y, 0) } }] }
        nv = groupe(model, d['nom'], d['tag'], surf, d['z'].to_f, e, rep[1] == 'Vers le bas')
        grp.erase!
        model.commit_operation
        model.selection.clear; model.selection.add(nv)
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("La surface n'a pas pu être modifiée (#{ex.message}).")
      end
    end

    # Couches du panneau « Dalle, chape, plafond » : mêmes données que les compositions
    def self.couches_depuis(r)
      COUCHES.map do |cle, lib, _a, _e0, t_rdc, t_et, _z|
        c = (r['couches'] || {})[cle]
        next unless c && c['actif']
        { 'nom' => lib, 'balise' => (r['niveau'] == 'Étage' ? t_et : t_rdc), 'e' => c['e'].to_s.tr(',', '.').to_f }
      end.compact
    end

    def self.creer(r)
      poser_couches(couches_depuis(r), r['hsp'], nil)
    end

    # couches : [{'nom','balise','e'}] de bas en haut. Dalle (A2M_DALLAGE / A2M_PLANCHER_ETAGE) sous le sol, sur l'emprise des murs ;
    # isolant, chape et autres au-dessus, dans chaque pièce ; plafond à la hauteur sous plafond.
    # surfaces : nil = murs sélectionnés (ou tous) ; sinon [[contour, trous]] (face sélectionnée), avec z
    def self.poser_couches(couches, hsp, surfaces, z_surf = nil, sur_dessus = false)
      model = Sketchup.active_model
      couches = couches.select { |c| c['e'].to_f > 0 }
      return UI.messagebox('Aucune couche à poser.') if couches.empty?
      if surfaces
        a = { pieces: surfaces, emprises: surfaces.map(&:first), z: z_surf }
      else
        a = analyser(model)
        return UI.messagebox('Aucun mur balisé trouvé : sélectionnez les murs (ou laissez la sélection vide pour prendre tous les murs du modèle).') unless a
        return UI.messagebox('Les murs ne forment pas de contour fermé : vérifiez qu\'ils se touchent.') if a[:emprises].empty? && a[:pieces].empty?
      end
      z = a[:z]
      model.start_operation('Composition de sol ou de plafond (métré)', true)
      begin
        faits = []
        crees = []
        haut = 0.0
        couches.each do |c|
          tag = c['balise']; e = c['e'].to_f
          lib = c['nom'].to_s.empty? ? tag : c['nom']
          if tag == 'A2M_DALLAGE' || tag == 'A2M_PLANCHER_ETAGE'
            surf = a[:emprises].map { |pts| [pts, []] }
            surf = a[:pieces] if surf.empty?
            # sur_dessus : la dalle repose sur le dessus des murs sélectionnés (soubassement) ; sinon elle descend depuis leur pied
            crees << (sur_dessus && a[:z_haut] ? groupe(model, lib, tag, surf, a[:z_haut], e, false) : groupe(model, lib, tag, surf, z, e, true))
            faits << "#{lib} #{e} cm"
          elsif tag == 'A2M_PLAFOND'
            h = hsp.to_s.tr(',', '.').to_f
            h = 250.0 if h <= 0
            crees << groupe(model, lib, tag, a[:pieces], z + (haut + h).cm, e, false)
            faits << "#{lib} à #{h.round} cm"
          else
            crees << groupe(model, lib, tag, a[:pieces], z + haut.cm, e, false)
            haut += e
            faits << "#{lib} #{e} cm"
          end
        end
        model.commit_operation
        model.selection.clear; model.selection.add(crees.compact)   # la dalle posée est sélectionnée : les planelles se posent ensuite d'un clic
        Sketchup.status_text = faits.join(' + ') + " : #{a[:pieces].size} pièce(s)."
        UI.messagebox("Posé : " + faits.join(', ') + ".\n#{a[:pieces].size} pièce(s) fermée(s) trouvée(s)." + (haut > 0 ? "\nLes couches du sol montent de #{haut.round(1)} cm au-dessus de la base des murs." : ''))
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Pose impossible : #{ex.message}\n#{ex.backtrace.first}")
      end
    end

    CORPS = <<~'HTML'
      <h2>Niveau</h2>
      <div class="puces" id="niv"></div>
      <h2>Ce qu'il faut poser</h2>
      <div id="couches"></div>
      <div class="dims" id="hbloc" style="margin-top:6px;grid-template-columns:1fr"><div><label>Hauteur sous plafond (cm)</label><input type="text" id="hsp"></div></div>
      <div class="petit">Sélectionnez les murs de l'étage (ou aucun : tous les murs du modèle). La dalle suit l'emprise extérieure ; isolant, chape et plafond suivent chaque pièce fermée. Les couches sont posées dans l'ordre, de bas en haut.</div>
      <div id="bas"><div id="msg"></div><button type="button" id="go">Poser</button></div>
    HTML
    SCRIPT = <<~'JS'
      var D = __DONNEES__; var s = D.etat;
      function el(i) { return document.getElementById(i); }
      function rendre() {
        var n = el('niv'); n.innerHTML = '';
        ['RDC', 'Étage'].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s.niveau === x ? ' rempli' : ''); b.textContent = x;
          b.addEventListener('click', function () { s.niveau = x; rendre(); }); n.appendChild(b);
        });
        var c = el('couches'); c.innerHTML = '';
        D.couches.forEach(function (t) {
          var v = s.couches[t.cle];
          var b = document.createElement('div'); b.className = 'carte' + (v.actif ? ' rempli' : ''); b.style.cssText = 'flex-direction:row;align-items:center;gap:10px;margin-bottom:8px;cursor:pointer';
          b.innerHTML = '<div style="font-size:20px;width:26px;text-align:center"></div><div style="flex:1"><b></b><div class="petit" style="margin:2px 0 0"></div></div><div style="display:flex;align-items:center;gap:4px"><input type="text" style="width:64px;font-size:14px;padding:5px"><span>cm</span></div>';
          b.children[0].textContent = v.actif ? '☑' : '☐';
          b.querySelector('b').textContent = t.libelle; b.querySelector('.petit').textContent = t.aide;
          var inp = b.querySelector('input'); inp.value = v.e;
          inp.addEventListener('click', function (e) { e.stopPropagation(); });
          inp.addEventListener('input', function () { v.e = inp.value; });
          b.addEventListener('click', function () { v.actif = !v.actif; rendre(); });
          c.appendChild(b);
        });
        el('hbloc').style.display = s.couches.plafond.actif ? '' : 'none';
        var n2 = D.couches.filter(function (t) { return s.couches[t.cle].actif; }).length;
        el('go').disabled = !n2; el('msg').textContent = n2 ? '' : 'Cochez au moins une couche.';
      }
      el('hsp').value = s.hsp; el('hsp').addEventListener('input', function () { s.hsp = this.value; });
      el('go').addEventListener('click', function () { sketchup.poser(JSON.stringify(s)); });
      rendre();
    JS

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      @etat ||= { 'niveau' => 'RDC', 'hsp' => '250', 'couches' => COUCHES.to_h { |c| [c[0], { 'actif' => c[0] != 'plafond', 'e' => c[3].to_s }] } }
      d = { 'couches' => COUCHES.map { |k, l, a, _e, _r, _t, _z| { 'cle' => k, 'libelle' => l, 'aide' => a } }, 'etat' => @etat }
      html = A2M::Panneau.page('Dalle, chape, plafond', 'Sélectionnez les murs, cochez ce qu\'il faut poser', CORPS, SCRIPT, d)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : dalle, chape, plafond', 'A2M_Panneau_SolMurs', html, 480, 640)
      @fen = dlg
      dlg.add_action_callback('poser') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        next unless r
        @etat = r
        UI.start_timer(0, false) { creer(r) }
      end
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
