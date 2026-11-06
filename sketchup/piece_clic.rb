# encoding: UTF-8
# Métré Atelier 2M : une pièce en un clic. On clique dans une pièce fermée (entre murs et cloisons) : un panneau propose
# l'épaisseur du sol, le revêtement, le profil de plinthes, le nom (liste + précision libre) et affiche la surface et le périmètre en ml.
require 'sketchup.rb'
require 'json'

module A2M
  module PieceClic
    NOMS = ['Entrée', 'Séjour', 'Salon', 'Salle à manger', 'Cuisine', 'Cellier', 'Buanderie', 'Couloir', 'Dégagement', 'Palier', 'Chambre 1', 'Chambre 2', 'Chambre 3',
            'Chambre parentale', 'Dressing', 'Salle de bains', 'Salle d\'eau', 'WC', 'Bureau', 'Garage', 'Cave', 'Combles', 'Local technique', 'Terrasse'].freeze
    # libellé, couleur du sol (RVB)
    REVETEMENTS = [['Carrelage', [205, 200, 190]], ['Parquet', [190, 150, 100]], ['Stratifié', [205, 175, 125]], ['Béton ciré', [170, 170, 172]],
                   ['Moquette', [125, 135, 155]], ['Résine', [140, 150, 156]], ['PVC / vinyle', [185, 175, 165]], ['Pierre naturelle', [190, 175, 150]],
                   ['Sol brut (sans revêtement)', nil]].freeze
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
        rev = REVETEMENTS.find { |l, _| l == r['revetement'] }
        if rev && rev[1]
          m = model.materials["A2M sol #{rev[0]}"] || model.materials.add("A2M sol #{rev[0]}")
          m.color = Sketchup::Color.new(*rev[1])
          g.entities.grep(Sketchup::Face).each { |x| x.material = m if x.normal.z > 0.99 }
        end
        g.name = nom_final
        g.set_attribute('a2m', 'revetement', rev ? rev[0] : '')
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
      <h2>Sol</h2>
      <div class="dims"><div><label>Épaisseur (cm)</label><input type="text" id="ep"></div></div>
      <div class="puces" id="rev" style="margin-top:8px"></div>
      <h2>Plinthes</h2>
      <div class="puces" id="pl"></div>
      <div id="bas"><div id="msg"></div><button type="button" id="go">Créer la pièce</button></div>
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
        puces(el('rev'), D.revetements, s.revetement, function (t) { s.revetement = t; rendre(); });
        puces(el('pl'), D.plinthes, s.plinthe, function (t) { s.plinthe = t; rendre(); });
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
      el('go').addEventListener('click', function () { sketchup.creer(JSON.stringify({ nom: s.nom, precision: el('prec').value, ep: el('ep').value, revetement: s.revetement, plinthe: s.plinthe })); });
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
        deja = A2M::PieceClic.piece_existante(model, p)
        return UI.messagebox("Il y a déjà une pièce ici : « #{deja} ». Supprimez-la d'abord pour la refaire.") if deja
        A2M::PieceClic.panneau(ctr)
      end
    end

    def self.piece_existante(model, p)
      model.active_entities.each do |g|
        next unless (g.is_a?(Sketchup::Group) || g.is_a?(Sketchup::ComponentInstance)) && g.layer && g.layer.name == 'A2M_PIECE'
        b = g.bounds
        return g.name if p.x >= b.min.x && p.x <= b.max.x && p.y >= b.min.y && p.y <= b.max.y && (A2M::PiecesAuto.dedans(p.x.to_f, p.y.to_f, g.entities.grep(Sketchup::Face).max_by(&:area).outer_loop.vertices.map { |v| q = g.transformation * v.position; [q.x.to_f, q.y.to_f] }) rescue false)
      end
      nil
    end

    def self.panneau(ctr)
      @fen.close if @fen && (@fen.visible? rescue false)
      model = Sketchup.active_model
      existants = model.active_entities.select { |g| (g.is_a?(Sketchup::Group) || g.is_a?(Sketchup::ComponentInstance)) && g.layer && g.layer.name == 'A2M_PIECE' }.map { |g| g.get_attribute('a2m', 'nom_liste').to_s }.reject(&:empty?)
      noms = (NOMS + existants).uniq
      @etat ||= { 'nom' => '', 'ep' => '1', 'revetement' => 'Carrelage', 'plinthe' => RECT }
      pls = [SANS_PLINTHE, RECT] + profils.map { |o| A2M::Profils.libelle(o) }
      pl = pls.include?(@etat['plinthe']) ? @etat['plinthe'] : RECT
      d = { 'noms' => noms, 'revetements' => REVETEMENTS.map(&:first), 'plinthes' => pls, 'surface' => ctr[2], 'perimetre' => perimetre(ctr[0]),
            'etat' => { 'nom' => '', 'ep' => @etat['ep'], 'revetement' => @etat['revetement'], 'plinthe' => pl } }
      html = A2M::Panneau.page('Pièce en un clic', 'Sol, plinthes et nom en une fois', CORPS, SCRIPT, d)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : pièce', 'A2M_Panneau_PieceClic', html, 480, 760)
      @fen = dlg
      dlg.add_action_callback('creer') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        next unless r
        @etat = { 'ep' => r['ep'], 'revetement' => r['revetement'], 'plinthe' => r['plinthe'] }
        dlg.close
        UI.start_timer(0.1, false) { creer(ctr, r) }
      end
      dlg.show
    end

    def self.lancer
      Sketchup.active_model.select_tool(Outil.new)
    end
  end
end
