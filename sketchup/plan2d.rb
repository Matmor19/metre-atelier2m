# encoding: UTF-8
# Métré Atelier 2M : plan 2D automatique, déduit du modèle 3D (coupe horizontale + symboles : arcs de portes, noms et surfaces)
require 'sketchup.rb'
require 'json'

module A2M
  module Plan2D
    TAG = 'A2M_SYMBOLES_2D'
    TAGS_PORTES = %w[A2M_PORTE_INT A2M_PORTE_ENTREE A2M_PORTE_FENETRE].freeze

    CORPS = <<~'HTML'
      <h2>Niveau</h2>
      <div class="dims">
        <div><label>Nom du niveau</label><input type="text" id="niv" value="RDC"></div>
        <div><label>Altitude du sol (cm)</label><input type="text" id="sol" value="0"></div>
        <div><label>Coupe à (cm)</label><input type="text" id="cut" value="120"></div>
      </div>
      <div class="petit">La coupe est faite à « Coupe à » au-dessus du sol du niveau (1,20 m : on voit les fenêtres et les portes). Pour l'étage, mettez l'altitude de son plancher.</div>
      <h2>Ce qui est dessiné</h2>
      <div class="puces" id="opts"></div>
      <h2>Échelle de présentation</h2>
      <div class="puces" id="ech"></div>
      <h2>Mise à jour</h2>
      <div class="puces" id="auto"></div>
      <div class="petit">Activée : dès que vous arrêtez de modifier le 3D, les arcs de portes, noms et surfaces se remettent à jour tout seuls (les scènes ne bougent pas).</div>
      <div class="petit" id="info"></div>
      <div id="bas"><div id="msg"></div><button type="button" id="go">Créer le plan 2D</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      var o = { poche: true, arcs: true, noms: true, surfaces: true, cotes: true, ech: 100 };
      el('sol').value = D.sol; el('niv').value = D.niveau;
      function rendre() {
        var p = el('opts'); p.innerHTML = '';
        [['poche', 'Murs en poché noir'], ['arcs', 'Portes : arc et battant'], ['noms', 'Noms des pièces'], ['surfaces', 'Surfaces des pièces'], ['cotes', 'Cotes des pièces']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (o[x[0]] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { o[x[0]] = !o[x[0]]; rendre(); }); p.appendChild(b);
        });
        var e = el('ech'); e.innerHTML = '';
        [50, 100, 200].forEach(function (v) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (o.ech === v ? ' rempli' : ''); b.textContent = '1/' + v;
          b.addEventListener('click', function () { o.ech = v; rendre(); }); e.appendChild(b);
        });
        el('info').textContent = D.info;
        var a = el('auto'); a.innerHTML = '';
        var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (D.auto ? ' rempli' : ''); b.textContent = 'Mise à jour automatique';
        b.addEventListener('click', function () { sketchup.auto(''); }); a.appendChild(b);
      }
      el('go').addEventListener('click', function () {
        sketchup.creer(JSON.stringify({ niveau: el('niv').value, sol: el('sol').value, cut: el('cut').value, o: o }));
      });
      function auto(v) { D.auto = v; rendre(); }
      rendre();
    JS

    def self.nombre(v, defaut) (Float(v.to_s.tr(',', '.')) rescue defaut) end

    # Parcourt groupes et composants (3 niveaux) en donnant l'objet et sa transformation absolue
    def self.parcourir(ents, t, prof = 0, &bloc)
      ents.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        tt = t * e.transformation
        bloc.call(e, tt)
        sous = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
        parcourir(sous, tt, prof + 1, &bloc) if prof < 2 && !e.layer.name.start_with?('A2M_PORTE') && e.layer.name != 'A2M_PIECE'
      end
    end

    def self.coins(e, t)
      b = (e.is_a?(Sketchup::Group) ? e.entities.parent : e.definition).bounds
      (0..7).map { |i| b.corner(i).transform(t) }
    end

    # Sol le plus bas des pièces (cm), pour proposer une altitude par défaut
    def self.sol_auto(model)
      zs = []
      parcourir(model.entities, Geom::Transformation.new) { |e, t| zs << coins(e, t).map(&:z).min if e.layer.name == 'A2M_PIECE' }
      zs.empty? ? 0.0 : (zs.min.to_f * 2.54).round(1)
    end

    def self.sans_ancien(model, nom)
      model.entities.grep(Sketchup::Group).each { |g| g.erase! if g.name == nom && g.valid? }
    end

    # Polyligne dessinée dans le groupe (arc de 90° : charnière c, direction du battant ferme b, direction d'ouverture o)
    def self.arc(ents, c, b, o, r)
      pts = (0..16).map { |i| a = Math::PI / 2 * i / 16.0; c.offset(b, r * Math.cos(a)).offset(o, r * Math.sin(a)) }
      ents.add_curve(pts)
    end

    def self.symboles_portes(ents, zs, zmin, zmax)
      n = 0
      parcourir(Sketchup.active_model.entities, Geom::Transformation.new) do |e, t|
        next unless TAGS_PORTES.include?(e.layer.name)
        cs = coins(e, t)
        next if cs.map(&:z).max < zmin || cs.map(&:z).min > zmax
        # axe de largeur = axe horizontal le plus long de la boîte
        xs = cs.map(&:x); ys = cs.map(&:y)
        o = Geom::Point3d.new((xs.min + xs.max) / 2, (ys.min + ys.max) / 2, 0)
        lx = xs.max - xs.min; ly = ys.max - ys.min
        # boîte non alignée sur les axes : on se base sur l'axe X local du composant
        ux = t.xaxis; ux.z = 0
        uy = t.yaxis; uy.z = 0
        ux = ux.length > 0.001 ? ux.normalize : Geom::Vector3d.new(1, 0, 0)
        uy = uy.length > 0.001 ? uy.normalize : Geom::Vector3d.new(0, 1, 0)
        bb = (e.is_a?(Sketchup::Group) ? e.entities.parent : e.definition).bounds
        wx = bb.width * t.xscale; wy = bb.height * t.yscale
        if wx >= wy then lg = ux; ep = uy; l = wx else lg = uy; ep = ux; l = wy end
        sens = (JSON.parse(e.get_attribute('a2m', 'sens').to_s) rescue nil)
        # sens du battant : [:ici|:la, 'droite'|'gauche']
        pouss = ep.clone
        charn = 'gauche'
        if sens
          charn = sens[1].to_s
          pouss = sens[0].to_s == 'ici' ? pouss : pouss.reverse
        end
        # extrémité de charnière : à droite de celui qui pousse = côté « droite »
        droite = pouss.cross(Z_AXIS); droite.normalize!
        c = o.clone; c.z = zs
        bord = lg.dot(droite) > 0 ? lg : lg.reverse     # direction « droite » le long de l'ouverture
        h = charn == 'droite' ? c.offset(bord, l / 2.0) : c.offset(bord.reverse, l / 2.0)
        ferme = charn == 'droite' ? bord.reverse : bord
        ents.add_line(h, h.offset(pouss, l))
        arc(ents, h, ferme, pouss, l)
        n += 1
      end
      n
    end

    def self.textes_pieces(ents, zs, zmin, zmax, noms, surfaces)
      n = 0
      parcourir(Sketchup.active_model.entities, Geom::Transformation.new) do |e, t|
        next unless e.layer.name == 'A2M_PIECE'
        cs = coins(e, t)
        next if cs.map(&:z).max < zmin - 5 || cs.map(&:z).min > zmax
        faces = (e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities).grep(Sketchup::Face)
        f = faces.max_by(&:area) or next
        m2 = f.area * 0.00064516 * (t.xscale * t.yscale)
        ctr = cs.inject([0, 0]) { |a, p| [a[0] + p.x, a[1] + p.y] }.map { |v| v / 8.0 }
        ligne = []
        ligne << e.name.to_s unless e.name.to_s.empty? || !noms
        ligne << format('%.1f m²', m2).tr('.', ',') if surfaces
        next if ligne.empty?
        tx = ents.add_text(ligne.join("\n"), Geom::Point3d.new(ctr[0], ctr[1], zs))
        tx.layer = Sketchup.active_model.layers[TAG] rescue nil
        n += 1
      end
      n
    end

    # Reconstruit le groupe de symboles d'un niveau (arcs de portes, noms et surfaces)
    # Objets de la bibliothèque (chaise, meuble…) : leur image 2D (couleur ou blanche) posée à leur place, sous le plan de coupe
    def self.symboles_objets(ents, zs, zmin, zmax)
      n = 0
      parcourir(Sketchup.active_model.entities, Geom::Transformation.new) do |e, t|
        next unless e.get_attribute('a2m_biblio', 'fichier')
        next if !e.visible? || e.layer.name.start_with?('A2M_PORTE', 'A2M_FENETRE')
        cs = coins(e, t)
        next if cs.map(&:z).max < zmin || cs.map(&:z).min > zmax
        n += 1 if A2M::VueObjet.image_sur_plan(ents, e, t, zs)
      end
      n
    rescue StandardError
      0
    end

    def self.symboles(model, nom, sol, zcut, o, tag)
      sans_ancien(model, nom)
      g = model.entities.add_group
      g.name = nom
      g.layer = tag
      zs = zcut - 1.cm
      np = o['arcs'] ? symboles_portes(g.entities, zs, sol, zcut) : 0
      nt = (o['noms'] || o['surfaces']) ? textes_pieces(g.entities, zs, sol, zcut, o['noms'], o['surfaces']) : 0
      cotes_pieces(g.entities, zs, sol, zcut) if o['cotes']
      symboles_objets(g.entities, zs, sol, zcut)
      g.entities.grep(Sketchup::Text).each { |t| t.layer = tag }
      [np, nt]
    end

    # Mise à jour silencieuse de tous les niveaux déjà créés (sans toucher à la vue ni aux scènes)
    def self.rafraichir
      model = Sketchup.active_model
      return unless model
      (model.attribute_dictionary('a2m') || {}).each_pair do |k, v|
        next unless k.to_s.start_with?('plan2d_')
        r = (JSON.parse(v.to_s) rescue nil) or next
        sol = nombre(r['sol'], 0).cm; cut = nombre(r['cut'], 120).cm
        tag = model.layers[TAG] || model.layers.add(TAG)
        symboles(model, "Symboles 2D – #{r['niveau'].to_s.strip}", sol, sol + cut, r['o'] || {}, tag)
      end
      A2M::Coupes.rafraichir rescue nil
    end

    # Observateur : après une pause de 2 s sans modification, les plans et coupes se remettent à jour
    class ObsAuto < Sketchup::EntitiesObserver
      def declencher
        return if A2M::Plan2D.occupe?
        UI.stop_timer(@t) if @t
        @t = UI.start_timer(2.0, false) do
          A2M::Plan2D.occupe!(true)
          begin
            m = Sketchup.active_model
            m.start_operation('Mise à jour plan 2D', true, false, true)
            A2M::Plan2D.rafraichir
            m.commit_operation
          rescue StandardError
            m.abort_operation rescue nil
          ensure
            A2M::Plan2D.occupe!(false)
          end
        end
      end
      def onElementAdded(_e, _x) declencher end
      def onElementModified(_e, _x) declencher end
      def onElementRemoved(_e, _x) declencher end
    end

    def self.occupe?() @occupe end
    def self.occupe!(v) @occupe = v end

    def self.auto?() Sketchup.read_default('A2M_Metre', 'plan_auto', true) ? true : false end

    def self.auto_basculer
      v = !auto?
      Sketchup.write_default('A2M_Metre', 'plan_auto', v)
      brancher
      Sketchup.status_text = v ? 'Plans 2D et coupes : mise à jour automatique activée.' : 'Plans 2D et coupes : mise à jour automatique coupée.'
      v
    end

    def self.brancher
      model = Sketchup.active_model
      return unless model
      (@obs_model.entities.remove_observer(@obs) rescue nil) if @obs && @obs_model
      @obs = nil
      return unless auto?
      @obs = ObsAuto.new
      @obs_model = model
      model.entities.add_observer(@obs)
    end

    # Cotes automatiques : longueur et largeur de chaque pièce, tracées à l'intérieur le long de deux côtés
    def self.cotes_pieces(ents, zs, zmin, zmax)
      n = 0
      parcourir(Sketchup.active_model.entities, Geom::Transformation.new) do |e, t|
        next unless e.layer.name == 'A2M_PIECE'
        cs = coins(e, t)
        next if cs.map(&:z).max < zmin - 5 || cs.map(&:z).min > zmax
        x0 = cs.map(&:x).min; x1 = cs.map(&:x).max; y0 = cs.map(&:y).min; y1 = cs.map(&:y).max
        next if x1 - x0 < 30.cm || y1 - y0 < 30.cm
        d = 25.cm
        ents.add_dimension_linear(Geom::Point3d.new(x0, y0, zs), Geom::Point3d.new(x1, y0, zs), Geom::Vector3d.new(0, d, 0))
        ents.add_dimension_linear(Geom::Point3d.new(x0, y0, zs), Geom::Point3d.new(x0, y1, zs), Geom::Vector3d.new(d, 0, 0))
        n += 2
      end
      n
    end

    def self.creer(r)
      model = Sketchup.active_model
      return UI.messagebox('Le modèle est vide.') if model.bounds.empty?
      niveau = r['niveau'].to_s.strip; niveau = 'RDC' if niveau.empty?
      sol = nombre(r['sol'], 0).cm
      cut = nombre(r['cut'], 120).cm
      o = r['o'] || {}
      zcut = sol + cut
      nom = "Symboles 2D – #{niveau}"
      model.start_operation('Plan 2D Atelier 2M', true)
      begin
        tag = model.layers[TAG] || model.layers.add(TAG)
        np, nt = symboles(model, nom, sol, zcut, o, tag)
        model.set_attribute('a2m', "plan2d_#{niveau}", JSON.generate(r))
        # plan de coupe horizontal : la partie au-dessus est masquée
        model.entities.grep(Sketchup::SectionPlane).each { |s| s.erase! if s.name == "A2M #{niveau}" }
        bb = model.bounds
        sp = model.entities.add_section_plane([bb.center.x, bb.center.y, zcut], [0, 0, -1])
        sp.name = "A2M #{niveau}"
        sp.activate
        ro = model.rendering_options
        ro['DisplaySectionPlanes'] = false rescue nil
        ro['DisplaySectionCuts'] = true rescue nil
        ro['SectionCutWidth'] = 4 rescue nil
        ro['SectionDefaultFillColor'] = (o['poche'] ? Sketchup::Color.new(20, 20, 20) : Sketchup::Color.new(200, 200, 200)) rescue nil
        ro['RenderMode'] = 2 rescue nil
        ro['EdgeDisplayMode'] = true rescue nil
        ro['DrawSilhouettes'] = false rescue nil
        model.shadow_info['DisplayShadows'] = false rescue nil
        tag.visible = true
        view = model.active_view
        c = bb.center
        cam = Sketchup::Camera.new(Geom::Point3d.new(c.x, c.y, bb.max.z + 1000), c, Geom::Vector3d.new(0, 1, 0))
        cam.perspective = false
        view.camera = cam
        view.zoom_extents
        page_nom = "A2M – Plan 2D #{niveau}"
        page = model.pages[page_nom] || model.pages.add(page_nom)
        page.update
        model.pages.each { |p| p.set_visibility(tag, p == page) rescue nil }
        model.commit_operation
        UI.messagebox("Plan 2D « #{niveau} » créé : #{np} porte(s) avec arc, #{nt} texte(s) de pièce.\nScène « #{page_nom} » dans la barre des scènes. Relancez l'outil après chaque modification du 3D pour le mettre à jour.")
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Plan 2D impossible : #{ex.message}")
      end
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      model = Sketchup.active_model
      info = 'Le plan se déduit du 3D : rien à redessiner. Les murs coupés sont en poché, les portes ont leur arc de battant (sens choisi à la pose), chaque pièce son nom et sa surface.'
      html = A2M::Panneau.page('Plan 2D automatique', 'Le plan se tient à jour à partir du modèle 3D', CORPS, SCRIPT,
                               'sol' => sol_auto(model), 'niveau' => 'RDC', 'info' => info, 'auto' => auto?)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : plan 2D', 'A2M_Panneau_Plan2D', html, 440, 600)
      @fen = dlg
      dlg.add_action_callback('auto') { |_c, _j| auto_basculer; dlg.execute_script("auto(#{auto?})") }
      dlg.add_action_callback('creer') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) { creer(r) } if r
      end
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
