# encoding: UTF-8
# Métré Atelier 2M : une pièce en un clic. On clique dans une pièce fermée (entre murs et cloisons) : un panneau propose
# l'épaisseur du sol, le revêtement, le profil de plinthes, le nom (liste + précision libre) et affiche la surface et le périmètre en ml.
require 'sketchup.rb'
require 'json'
require 'base64'

module A2M
  module PieceClic
    NOMS = ['Entrée', 'Séjour', 'Salon', 'Salle à manger', 'Cuisine', 'Cellier', 'Buanderie', 'Couloir', 'Dégagement', 'Palier', 'Chambre 1', 'Chambre 2', 'Chambre 3',
            'Chambre parentale', 'Dressing', 'Salle de bains', 'Salle d\'eau', 'WC', 'Bureau', 'Garage', 'Cave', 'Combles', 'Local technique', 'Terrasse'].freeze
    # Revêtements : les textures du dossier « sols » (nom affiché, fichier) puis quelques teintes unies sans texture
    TEINTES = [['Stratifié', [205, 175, 125]], ['Moquette', [125, 135, 155]], ['Résine', [140, 150, 156]], ['PVC / vinyle', [185, 175, 165]],
               ['Pierre naturelle', [190, 175, 150]], ['Sol brut (sans revêtement)', nil]].freeze

    def self.textures_sols
      accents = { 'Beton cire' => 'Béton ciré', 'Mosaique' => 'Mosaïque', 'Parquet chene' => 'Parquet chêne' }
      Dir.glob("#{A2M::Textures::DOSSIER}/sols/*.jpg").sort.map { |f| n = A2M::Textures.nom_affiche(File.basename(f, '.jpg')); [accents[n] || n, File.basename(f, '.jpg')] }
    end

    def self.vignette_sol(nom)
      f = "#{A2M::Textures::DOSSIER}/miniatures/sols/#{nom}.jpg"
      f = "#{A2M::Textures::DOSSIER}/sols/#{nom}.jpg" unless File.exist?(f)
      File.exist?(f) ? 'data:image/jpeg;base64,' + Base64.strict_encode64(File.binread(f)) : ''
    end

    def self.revetements
      textures_sols.map { |l, n| { 'nom' => l, 'img' => vignette_sol(n) } } + TEINTES.map { |l, _| { 'nom' => l, 'img' => '' } }
    end

    SANS_PLINTHE = 'Aucune plinthe'
    RECT = 'Plinthe rectangulaire 10 × 1,2 cm'

    # Contour de la pièce fermée qui contient le point (coordonnées du modèle, pouces) ; nil si le point n'est pas dans une pièce fermée
    def self.contour_en(model, px, py)
      ms = A2M::PiecesAuto.murs(model)
      return [nil, 'Aucun mur, cloison ou doublage balisé trouvé.'] if ms.empty?
      emp = A2M::PiecesAuto.empreintes(ms)
      return [nil, 'Vous avez cliqué dans un mur : cliquez à l\'intérieur de la pièce.'] if A2M::PiecesAuto.dans_un_mur(px, py, emp)
      z = ms.map { |g| g.bounds.min.z }.min
      bb = Geom::BoundingBox.new; ms.each { |g| bb.add(g.bounds) }
      marge = 1.m
      x0, y0, x1, y1 = bb.min.x - marge, bb.min.y - marge, bb.max.x + marge, bb.max.y + marge
      res = nil
      model.start_operation('Détection de la pièce', true)
      begin
        tmp = model.active_entities.add_group
        te = tmp.entities
        te.add_face([[x0, y0, z], [x1, y0, z], [x1, y1, z], [x0, y1, z]].map { |a| Geom::Point3d.new(*a) })
        emp.each { |loops| loops.each { |lp| te.add_edges((lp + [lp[0]]).map { |x, y| Geom::Point3d.new(x, y, z) }) } }
        A2M::Separateur.ajouter_a(te, z, model)
        prolonger_cloisons(te, emp, z)
        te.intersect_with(false, Geom::Transformation.new, te, Geom::Transformation.new, true, te.to_a)
        te.grep(Sketchup::Edge).each { |e| e.find_faces if e.valid? }
        bord = ->(f) { f.vertices.any? { |v| p = v.position; (p.x - x0).abs < 0.1 || (p.x - x1).abs < 0.1 || (p.y - y0).abs < 0.1 || (p.y - y1).abs < 0.1 } }
        cands = te.grep(Sketchup::Face).select do |f|
          next false if bord.call(f)
          poly = f.outer_loop.vertices.map { |v| [v.position.x.to_f, v.position.y.to_f] }
          A2M::PiecesAuto.dedans(px, py, poly) && f.loops.reject(&:outer?).none? { |lp| A2M::PiecesAuto.dedans(px, py, lp.vertices.map { |v| [v.position.x.to_f, v.position.y.to_f] }) }
        end
        f = cands.min_by(&:area)
        res = [f.outer_loop.vertices.map(&:position), f.loops.reject(&:outer?).map { |lp| lp.vertices.map(&:position) }, f.area * 0.00064516] if f
        tmp.erase!
      ensure
        model.abort_operation        # le modèle n'est pas modifié par la détection
      end
      return [nil, 'Pas de pièce fermée ici : vérifiez que les murs et cloisons se touchent.'] unless res
      [res, nil]
    end

    def self.perimetre(pts)
      pts.each_with_index.sum { |p, i| p.distance(pts[(i + 1) % pts.size]) }.to_f * 0.0254
    end

    def self.profils
      (A2M::Profils.tous('Plinthe') rescue [])
    end

    def self.creer(contour, r)
      model = Sketchup.active_model
      ext, trous, aire = contour
      ep = r['ep'].to_f
      nom = r['nom'].to_s.strip
      nom = 'Pièce' if nom.empty?
      prec = r['precision'].to_s.strip
      nom_final = prec.empty? ? nom : "#{nom} – #{prec}"
      model.start_operation('Pièce en un clic (métré)', true)
      begin
        lb, _ = A2M::Balises.balise(model, 'A2M_PIECE', [120, 200, 120])
        g = model.active_entities.add_group
        f = g.entities.add_face(ext)
        trous.each { |t| h = g.entities.add_face(t); h.erase! if h && h.valid? }
        f = g.entities.grep(Sketchup::Face).max_by(&:area)
        f.reverse! if f.normal.z < 0
        f.pushpull(ep.cm) if ep > 0
        g.layer = lb
        A2M::Hachures.poser(g, model)
        choix = r['revetement'].to_s
        tex = textures_sols.find { |l, _| l == choix }
        teinte = TEINTES.find { |l, _| l == choix }
        if tex
          m = A2M::Textures.materiau(model, 'sols', tex[1])
          g.entities.grep(Sketchup::Face).each { |x| x.material = m if x.normal.z > 0.99 }
        elsif teinte && teinte[1]
          m = model.materials["A2M sol #{teinte[0]}"] || model.materials.add("A2M sol #{teinte[0]}")
          m.color = Sketchup::Color.new(*teinte[1])
          g.entities.grep(Sketchup::Face).each { |x| x.material = m if x.normal.z > 0.99 }
        end
        g.name = nom_final
        g.set_attribute('a2m', 'revetement', choix)
        g.set_attribute('a2m', 'nom_liste', nom)
        g.set_attribute('a2m', 'precision', prec)
        g.set_attribute('a2m', 'epaisseur_sol', ep)
        ml_pl = nil
        if r['plinthe'].to_s != SANS_PLINTHE && !r['plinthe'].to_s.empty?
          o = profils.find { |x| A2M::Profils.libelle(x) == r['plinthe'] }
          profil = o ? A2M::Profils.parties(o).first[1] : A2M::Plinthes.profil_rectangle(10, 1.2)
          ml_pl = A2M::Plinthes.generer(g, Geom::Transformation.new, profil, model)
          g.set_attribute('a2m', 'plinthe_nom', r['plinthe'])
        end
        if r['plafond']
          h = r['hauteur'].to_s.tr(',', '.').to_f
          h = 250.0 if h <= 0
          lp, _ = A2M::Balises.balise(model, 'A2M_PLAFOND', [230, 230, 235])
          pl = model.active_entities.add_group
          pts = ext.map { |q| Geom::Point3d.new(q.x, q.y, q.z + (ep / 2.54).to_f + h.cm) }
          fp = pl.entities.add_face(pts)
          fp.reverse! if fp && fp.normal.z > 0          # face vue d'en dessous
          pl.layer = lp
          pl.name = "Plafond – #{nom_final}"
        end
        model.commit_operation
        Sketchup.status_text = "#{nom_final} : #{aire.round(2)} m², périmètre #{perimetre(ext).round(2)} ml#{ml_pl ? ", plinthes #{(ml_pl * 100).round / 100.0} ml" : ''}"
        g
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("La pièce n'a pas pu être créée : #{ex.message}\n#{ex.backtrace.first}")
        nil
      end
    end

    CORPS = <<~'HTML'
      <div class="apercu" style="margin-top:0;display:flex;gap:20px;justify-content:space-around;text-align:center">
        <div><div style="font-size:24px;font-weight:700;color:#E07838" id="surf"></div><div class="petit">surface</div></div>
        <div><div style="font-size:24px;font-weight:700;color:#E07838" id="per"></div><div class="petit">périmètre</div></div>
      </div>
      <h2>Nom de la pièce</h2>
      <div class="puces" id="noms"></div>
      <div class="dims" style="grid-template-columns:1fr 1fr;margin-top:8px"><div><label>Autre nom (liste)</label><select id="liste" style="width:100%;padding:8px;border:2px solid #d8d0c6;border-radius:9px;background:#fff"></select></div><div><label>Précision libre (facultatif)</label><input type="text" id="prec" placeholder="ex. côté jardin" style="font-size:14px;text-align:left"></div></div>
      <h2>Sol : épaisseur et texture</h2>
      <div class="dims"><div><label>Épaisseur (cm)</label><input type="text" id="ep"></div></div>
      <div class="grille" id="rev" style="margin-top:8px;grid-template-columns:repeat(auto-fill,minmax(96px,1fr))"></div>
      <h2>Plinthes</h2>
      <div class="puces" id="pl"></div>
      <h2>Ensuite</h2>
      <div class="puces" id="opts"></div>
      <div class="dims" id="hbloc" style="margin-top:8px;grid-template-columns:1fr"><div><label>Hauteur sous plafond (cm)</label><input type="text" id="hsp"></div></div>
      <div id="bas"><div id="msg"></div><button type="button" id="passer" style="display:none;background:#fff;color:#3C3C3C;border:2px solid #d8d0c6;border-radius:10px;padding:8px 14px;cursor:pointer">Passer</button><button type="button" id="go">Créer la pièce</button></div>
    HTML
    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(i) { return document.getElementById(i); }
      var s = D.etat;
      function puces(c, liste, cur, fn) {
        c.innerHTML = '';
        liste.forEach(function (t) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (cur === t ? ' rempli' : ''); b.textContent = t;
          b.addEventListener('click', function () { fn(t); }); c.appendChild(b);
        });
      }
      function rendre() {
        el('surf').textContent = D.surface.toFixed(2).replace('.', ',') + ' m²';
        el('per').textContent = D.perimetre.toFixed(2).replace('.', ',') + ' ml';
        puces(el('noms'), D.noms.slice(0, 8), s.nom, function (t) { s.nom = t; el('liste').value = t; rendre(); });
        var rv = el('rev'); rv.innerHTML = '';
        D.revetements.forEach(function (t) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte' + (s.revetement === t.nom ? ' rempli' : '');
          b.innerHTML = '<div class="vignette" style="height:46px"></div><span style="font-size:11px"></span>';
          if (t.img) { var i = document.createElement('img'); i.src = t.img; b.querySelector('.vignette').appendChild(i); }
          b.querySelector('span').textContent = t.nom;
          b.addEventListener('click', function () { s.revetement = t.nom; rendre(); }); rv.appendChild(b);
        });
        puces(el('pl'), D.plinthes, s.plinthe, function (t) { s.plinthe = t; rendre(); });
        var oc = el('opts'); oc.innerHTML = '';
        var ol = [['plafond', 'Proposer le plafond ensuite']]; if (D.total > 0) ol.push(['scenes', 'Créer les scènes 2D et 3D à la fin']);
        ol.forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s[x[0]] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { s[x[0]] = !s[x[0]]; rendre(); }); oc.appendChild(b);
        });
        el('hbloc').style.display = s.plafond ? '' : 'none';
        var e = parseFloat(String(el('ep').value).replace(',', '.'));
        el('ep').className = e >= 0 ? 'ok' : '';
        el('go').disabled = !(e >= 0) || !s.nom;
        el('msg').textContent = s.nom ? '' : 'Choisissez le nom de la pièce.';
      }
      var l = el('liste'); var o = document.createElement('option'); o.value = ''; o.textContent = '—'; l.appendChild(o);
      D.noms.forEach(function (n) { var p = document.createElement('option'); p.value = n; p.textContent = n; l.appendChild(p); });
      l.value = s.nom || '';
      l.addEventListener('change', function () { s.nom = l.value; rendre(); });
      el('ep').value = s.ep; el('ep').addEventListener('input', rendre);
      el('hsp').value = s.hauteur; el('hsp').addEventListener('input', rendre);
      if (D.total > 0) { el('passer').style.display = ''; el('passer').addEventListener('click', function () { sketchup.passer(''); }); }
      el('go').addEventListener('click', function () { sketchup.creer(JSON.stringify({ nom: s.nom, precision: el('prec').value, ep: el('ep').value, revetement: s.revetement, plinthe: s.plinthe, plafond: !!s.plafond, hauteur: el('hsp').value, scenes: !!s.scenes })); });
      if (D.existe) { el('go').textContent = 'Mettre à jour la pièce'; }
      rendre();
    JS

    # Outil : un clic dans une pièce fermée ouvre le panneau, la pièce est créée ; l'outil reste actif pour la pièce suivante
    class Outil
      def initialize; @etat = nil; @pos = nil; end
      def activate; Sketchup.status_text = 'Pièce en un clic : cliquez à l\'intérieur d\'une pièce fermée (entre murs et cloisons). Échap pour finir.'; end
      def onMouseMove(_f, x, y, view) @pos = view.inputpoint(x, y).position; view.invalidate end
      def onCancel(_r, _v) Sketchup.active_model.select_tool(nil) end
      def onLButtonDown(_f, x, y, view)
        p = view.inputpoint(x, y).position
        model = Sketchup.active_model
        ctr, err = A2M::PieceClic.contour_en(model, p.x.to_f, p.y.to_f)
        return UI.messagebox(err) unless ctr
        A2M::PieceClic.panneau(ctr)
      end
    end

    def self.pieces_existantes(model)
      model.active_entities.select { |g| (g.is_a?(Sketchup::Group) || g.is_a?(Sketchup::ComponentInstance)) && g.valid? && g.layer && g.layer.name == 'A2M_PIECE' }
    end

    def self.poly_piece(g)
      f = g.entities.grep(Sketchup::Face).max_by(&:area)
      return nil unless f
      f.outer_loop.vertices.map { |v| q = g.transformation * v.position; [q.x.to_f, q.y.to_f] }
    end

    # Pièce déjà créée qui occupe ce contour (points d'essai : centre et milieux vers les sommets)
    def self.groupe_pour_contour(model, ctr)
      pts = ctr[0]
      return nil if pts.empty?
      cx = pts.sum { |q| q.x.to_f } / pts.size; cy = pts.sum { |q| q.y.to_f } / pts.size
      essais = [[cx, cy]] + pts.map { |q| [(q.x.to_f + cx) / 2, (q.y.to_f + cy) / 2] }
      pieces_existantes(model).each do |g|
        poly = poly_piece(g)
        next unless poly
        return g if essais.any? { |x, y| (A2M::PiecesAuto.dedans(x, y, poly) rescue false) }
      end
      nil
    end

    def self.piece_existante(model, p)
      pieces_existantes(model).each do |g|
        poly = poly_piece(g)
        return g.name if poly && (A2M::PiecesAuto.dedans(p.x.to_f, p.y.to_f, poly) rescue false)
      end
      nil
    end

    # Met à jour une pièce existante : revêtement, nom, plinthes (pas de doublon)
    def self.mettre_a_jour(g, r)
      model = Sketchup.active_model
      nom = r['nom'].to_s.strip
      nom = g.get_attribute('a2m', 'nom_liste').to_s if nom.empty?
      prec = r['precision'].to_s.strip
      nom_final = prec.empty? ? nom : "#{nom} – #{prec}"
      model.start_operation('Pièce : mise à jour (métré)', true)
      begin
        choix = r['revetement'].to_s
        tex = textures_sols.find { |l, _| l == choix }
        teinte = TEINTES.find { |l, _| l == choix }
        m = nil
        if tex
          m = A2M::Textures.materiau(model, 'sols', tex[1])
        elsif teinte && teinte[1]
          m = model.materials["A2M sol #{teinte[0]}"] || model.materials.add("A2M sol #{teinte[0]}")
          m.color = Sketchup::Color.new(*teinte[1])
        end
        g.entities.grep(Sketchup::Face).each { |x| x.material = m if x.normal.z > 0.99 } if m
        g.name = nom_final
        g.set_attribute('a2m', 'revetement', choix)
        g.set_attribute('a2m', 'nom_liste', nom)
        g.set_attribute('a2m', 'precision', prec)
        ml_pl = nil
        if r['plinthe'].to_s != SANS_PLINTHE && !r['plinthe'].to_s.empty?
          o = profils.find { |x| A2M::Profils.libelle(x) == r['plinthe'] }
          profil = o ? A2M::Profils.parties(o).first[1] : A2M::Plinthes.profil_rectangle(10, 1.2)
          ml_pl = A2M::Plinthes.generer(g, Geom::Transformation.new, profil, model)
          g.set_attribute('a2m', 'plinthe_nom', r['plinthe'])
        else
          pid = g.persistent_id
          model.active_entities.grep(Sketchup::Group).select { |p| p.get_attribute('a2m', 'plinthe_de') == pid }.each(&:erase!)
          g.delete_attribute('a2m', 'plinthe_nom')
        end
        model.commit_operation
        Sketchup.status_text = "#{nom_final} mise à jour (revêtement : #{choix})#{ml_pl ? ", plinthes #{(ml_pl * 100).round / 100.0} ml" : ''}"
        g
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("La pièce n'a pas pu être mise à jour : #{ex.message}\n#{ex.backtrace.first}")
        nil
      end
    end

    def self.panneau(ctr, rang = 0, total = 0, &suite)
      @fen.close if @fen && (@fen.visible? rescue false)
      model = Sketchup.active_model
      model.select_tool(Visite.new(ctr[0]))
      begin
        bbv = Geom::BoundingBox.new; ctr[0].each { |q| bbv.add(q) }
        c = bbv.center; r = [bbv.diagonal * 1.1, 200].max
        model.active_view.camera = Sketchup::Camera.new(Geom::Point3d.new(c.x, c.y - r * 0.55, c.z + r * 1.25), c, Y_AXIS)
      rescue StandardError
        nil
      end
      deja = groupe_pour_contour(model, ctr)
      existants = model.active_entities.select { |g| (g.is_a?(Sketchup::Group) || g.is_a?(Sketchup::ComponentInstance)) && g.layer && g.layer.name == 'A2M_PIECE' }.map { |g| g.get_attribute('a2m', 'nom_liste').to_s }.reject(&:empty?)
      noms = (NOMS + existants).uniq
      if deja
        @etat = (@etat || {}).merge('revetement' => deja.get_attribute('a2m', 'revetement').to_s, 'plinthe' => (deja.get_attribute('a2m', 'plinthe_nom') || SANS_PLINTHE).to_s)
      end
      @etat ||= { 'ep' => '1', 'revetement' => (textures_sols.first || ['Sol brut (sans revêtement)']).first, 'plinthe' => RECT, 'plafond' => false, 'hauteur' => '250', 'scenes' => false }
      pls = [SANS_PLINTHE, RECT] + profils.map { |o| A2M::Profils.libelle(o) }
      pl = pls.include?(@etat['plinthe']) ? @etat['plinthe'] : RECT
      d = { 'noms' => noms, 'revetements' => revetements, 'plinthes' => pls, 'surface' => ctr[2], 'perimetre' => perimetre(ctr[0]), 'total' => total,
            'existe' => (deja ? deja.name.to_s : ''), 'etat' => { 'nom' => (deja ? deja.get_attribute('a2m', 'nom_liste').to_s : ''), 'ep' => @etat['ep'], 'revetement' => @etat['revetement'], 'plinthe' => pl, 'plafond' => @etat['plafond'], 'hauteur' => @etat['hauteur'], 'scenes' => @etat['scenes'] } }
      titre = total > 0 ? "Pièce #{rang} sur #{total} : #{ctr[2].round(2).to_s.tr('.', ',')} m²" : 'Pièce en un clic'
      titre = "Modifier : #{deja.name}" if deja
      html = A2M::Panneau.page(titre, total > 0 ? 'La pièce en surbrillance dans le modèle : donnez-lui son nom' : 'Sol, plinthes et nom en une fois', CORPS, SCRIPT, d)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : pièce', 'A2M_Panneau_PieceClic', html, 480, 800)
      @fen = dlg
      dlg.add_action_callback('creer') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        next unless r
        @etat = { 'ep' => r['ep'], 'revetement' => r['revetement'], 'plinthe' => r['plinthe'], 'plafond' => r['plafond'], 'hauteur' => r['hauteur'], 'scenes' => r['scenes'] }
        dlg.close
        UI.start_timer(0.1, false) do
          deja && deja.valid? ? mettre_a_jour(deja, r) : creer(ctr, r)
          suite ? suite.call : Sketchup.active_model.select_tool(Outil.new)
        end
      end
      dlg.add_action_callback('passer') do |_c, _x|
        dlg.close
        UI.start_timer(0.1, false) { suite.call if suite }
      end
      dlg.show
    end

    # Surbrillance de la pièce en cours pendant que le panneau est ouvert
    class Visite
      def initialize(pts) @pts = pts end
      def draw(view)
        view.drawing_color = Sketchup::Color.new(224, 120, 56, 110)
        view.draw(GL_POLYGON, @pts)
        view.line_width = 3
        view.drawing_color = 'orange'
        view.draw(GL_LINE_LOOP, @pts)
      end
      def getExtents
        bb = Geom::BoundingBox.new
        @pts.each { |q| bb.add(q) }
        bb
      end
      def onCancel(_r, _v) Sketchup.active_model.select_tool(nil) end
    end

    # Toutes les pièces fermées du modèle (ou des murs sélectionnés), une par une : nom, sol, plinthes, plafond
    TOLERANCE_JEU = 10.cm   # petit jeu toléré entre le bout d'une cloison et le mur voisin : la pièce est quand même séparée

    # Prolonge l'axe de chaque mur rectangulaire allongé de TOLERANCE_JEU à chaque bout (ligne sans épaisseur qui ferme le jeu)
    def self.prolonger_cloisons(te, emp, z)
      emp.each do |loops|
        lp = loops[0]
        next unless lp && lp.size == 4
        a, b, c, d = lp
        l1 = Math.hypot(b[0] - a[0], b[1] - a[1]); l2 = Math.hypot(c[0] - b[0], c[1] - b[1])
        next if [l1, l2].min < 1e-3 || [l1, l2].max < 2 * [l1, l2].min
        if l1 >= l2
          p0 = [(a[0] + d[0]) / 2.0, (a[1] + d[1]) / 2.0]; p1 = [(b[0] + c[0]) / 2.0, (b[1] + c[1]) / 2.0]
        else
          p0 = [(a[0] + b[0]) / 2.0, (a[1] + b[1]) / 2.0]; p1 = [(c[0] + d[0]) / 2.0, (c[1] + d[1]) / 2.0]
        end
        dd = Math.hypot(p1[0] - p0[0], p1[1] - p0[1])
        ux = (p1[0] - p0[0]) / dd; uy = (p1[1] - p0[1]) / dd
        t = TOLERANCE_JEU.to_f
        te.add_line(Geom::Point3d.new(p0[0] - ux * t, p0[1] - uy * t, z), Geom::Point3d.new(p1[0] + ux * t, p1[1] + uy * t, z))
      end
    end

    def self.detecter_toutes(model, smin = 1.0)
      ms = A2M::PiecesAuto.murs(model)
      return [] if ms.empty?
      emp = A2M::PiecesAuto.empreintes(ms)
      z = ms.map { |g| g.bounds.min.z }.min
      bb = Geom::BoundingBox.new; ms.each { |g| bb.add(g.bounds) }
      marge = 1.m
      x0, y0, x1, y1 = bb.min.x - marge, bb.min.y - marge, bb.max.x + marge, bb.max.y + marge
      res = []
      model.start_operation('Détection des pièces', true)
      begin
        tmp = model.active_entities.add_group
        te = tmp.entities
        te.add_face([[x0, y0, z], [x1, y0, z], [x1, y1, z], [x0, y1, z]].map { |a| Geom::Point3d.new(*a) })
        emp.each { |loops| loops.each { |lp| te.add_edges((lp + [lp[0]]).map { |x, y| Geom::Point3d.new(x, y, z) }) } }
        A2M::Separateur.ajouter_a(te, z, model)
        prolonger_cloisons(te, emp, z)
        te.intersect_with(false, Geom::Transformation.new, te, Geom::Transformation.new, true, te.to_a)
        te.grep(Sketchup::Edge).each { |e| e.find_faces if e.valid? }
        bord = ->(f) { f.vertices.any? { |v| q = v.position; (q.x - x0).abs < 0.1 || (q.x - x1).abs < 0.1 || (q.y - y0).abs < 0.1 || (q.y - y1).abs < 0.1 } }
        te.grep(Sketchup::Face).each do |f|
          next if bord.call(f)
          m = f.mesh; pts = m.polygon_points_at(1) rescue nil
          next unless pts
          cx = pts.sum(&:x) / 3.0; cy = pts.sum(&:y) / 3.0
          next if A2M::PiecesAuto.dans_un_mur(cx, cy, emp) || f.area * 0.00064516 < smin
          res << [f.outer_loop.vertices.map(&:position), f.loops.reject(&:outer?).map { |lp| lp.vertices.map(&:position) }, f.area * 0.00064516]
        end
        tmp.erase!
      ensure
        model.abort_operation
      end
      # ordre de lecture : de haut en bas, de gauche à droite
      res.sort_by { |c| [-(c[0].map(&:y).sum / c[0].size).round(-1), c[0].map(&:x).sum / c[0].size] }
    end

    def self.toutes
      model = Sketchup.active_model
      liste = detecter_toutes(model)
      if liste.empty?
        return UI.messagebox('Aucune pièce fermée trouvée. Vérifiez que les murs et cloisons se touchent, ou sélectionnez les murs de l\'étage.')
      end
      i = -1
      avancer = nil
      avancer = lambda do
        i += 1
        if i >= liste.size
          model.select_tool(nil)
          (model.active_view.zoom_extents rescue nil)
          if @etat && @etat['scenes']
            A2M::Vues.creer(%w[plan persp], { 'aretes' => true, 'ombres' => false, 'style' => 'reel' }) rescue nil
          end
          next
        end
        panneau(liste[i], i + 1, liste.size, &avancer)
      end
      avancer.call
    end

    def self.lancer
      Sketchup.active_model.select_tool(Outil.new)
    end
  end
end
