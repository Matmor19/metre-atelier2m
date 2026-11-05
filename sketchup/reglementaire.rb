# encoding: UTF-8
# Métré Atelier 2M : surfaces et hauteurs réglementaires pour les permis (emprise au sol, surface de plancher, hauteurs, reculs)
require 'sketchup.rb'
require 'json'

module A2M
  module Reglementaire
    CORPS = <<~'HTML'
      <h2>Chiffres du projet</h2>
      <div id="tab"></div>
      <div class="petit" id="avert"></div>
      <h2>Reculs par rapport aux limites</h2>
      <div class="petit">Dessinez ou sélectionnez les lignes de limite de propriété (arêtes), puis cliquez « Calculer les reculs ». La distance est mesurée à l'horizontale entre chaque limite et le point le plus proche du bâtiment.</div>
      <div id="reculs"></div>
      <div id="bas"><div id="msg"></div><button type="button" id="go">Recalculer</button> <button type="button" id="rec">Calculer les reculs</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      function fm(n) { return (Math.round(n * 100) / 100).toString().replace('.', ','); }
      function maj(d) { D = d; rendre(); }
      function rendre() {
        var t = el('tab'); t.innerHTML = '';
        D.lignes.forEach(function (l) {
          var r = document.createElement('div'); r.style.cssText = 'display:flex;justify-content:space-between;padding:7px 0;border-bottom:1px solid #eadfd3';
          var a = document.createElement('div'); a.innerHTML = '<b></b><div class="petit" style="margin:0"></div>'; a.querySelector('b').textContent = l.titre; a.querySelector('.petit').textContent = l.aide;
          var b = document.createElement('div'); b.style.cssText = 'font-weight:600;font-size:16px;color:#C85F1F;white-space:nowrap'; b.textContent = l.valeur;
          r.appendChild(a); r.appendChild(b); t.appendChild(r);
        });
        el('avert').textContent = D.avert || '';
        var c = el('reculs'); c.innerHTML = '';
        if (!D.reculs.length) c.innerHTML = '<div class="petit">Aucun recul calculé pour le moment.</div>';
        D.reculs.forEach(function (x) {
          var r = document.createElement('div'); r.style.cssText = 'display:flex;justify-content:space-between;padding:5px 0;border-bottom:1px solid #eadfd3';
          r.innerHTML = '<span></span><b></b>'; r.querySelector('span').textContent = x.nom; r.querySelector('b').textContent = x.valeur; c.appendChild(r);
        });
      }
      el('go').addEventListener('click', function () { sketchup.recalc(''); });
      el('rec').addEventListener('click', function () { sketchup.reculs(''); });
      rendre();
    JS

    BAL_MURS = %w[A2M_MUR_PERI A2M_MUR_SOUB A2M_MUR_PIGNON].freeze
    BAL_INT = %w[A2M_MUR_REFEND A2M_CLOISON].freeze

    def self.m2(v) format('%.1f m²', v).tr('.', ',') end
    def self.m(v) format('%.2f m', v).tr('.', ',') end

    # Surface en plan (m²) de l'union des empreintes des groupes de ces balises
    def self.empreinte(model, balises)
      pts = []
      groupes = []
      A2M::Plan2D.parcourir(model.entities, Geom::Transformation.new) { |e, t| groupes << [e, t] if balises.include?(e.layer.name) }
      return [0.0, []] if groupes.empty?
      tmp = model.entities.add_group
      begin
        groupes.each do |e, t|
          ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          bas = ents.grep(Sketchup::Face).select { |f| (t * f.normal).z.abs > 0.99 }
          next if bas.empty?
          zmin = bas.map { |f| (t * f.vertices[0].position).z }.min
          bas.select { |f| ((t * f.vertices[0].position).z - zmin).abs < 0.5.cm }.each do |f|
            p2 = f.outer_loop.vertices.map { |v| q = t * v.position; Geom::Point3d.new(q.x, q.y, 0) }
            nf = (tmp.entities.add_face(p2) rescue nil)
            nf.erase! if nf && false
          end
        end
        faces = tmp.entities.grep(Sketchup::Face)
        aire = faces.sum { |f| f.area } * 2.54**2 / 10000.0
        contour = tmp.entities.grep(Sketchup::Edge).select { |ed| ed.faces.size == 1 }.map { |ed| [ed.start.position, ed.end.position] }
        [aire, contour]
      ensure
        tmp.erase!
      end
    end

    def self.calculer
      model = Sketchup.active_model
      lignes = []; avert = []
      emp, contour = empreinte(model, BAL_MURS)
      lignes << { 'titre' => 'Emprise au sol', 'aide' => 'Projection verticale de toutes les constructions (murs extérieurs, hors débords de toiture)', 'valeur' => emp > 0 ? m2(emp) : '—' }
      avert << 'Aucun mur périphérique balisé : posez les murs avec l\'outil Mur.' if emp <= 0
      # Pièces
      pieces = 0.0; nb = 0
      A2M::Plan2D.parcourir(model.entities, Geom::Transformation.new) do |e, t|
        next unless e.layer.name == 'A2M_PIECE'
        f = (e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities).grep(Sketchup::Face).max_by(&:area)
        next unless f
        pieces += f.area * 2.54**2 / 10000.0 * (t.xscale * t.yscale); nb += 1
      end
      int, _ = empreinte(model, BAL_INT)
      lignes << { 'titre' => 'Somme des pièces', 'aide' => "#{nb} pièce(s) balisée(s) A2M_PIECE (surface utile)", 'valeur' => nb > 0 ? m2(pieces) : '—' }
      lignes << { 'titre' => 'Surface de plancher (estimation)', 'aide' => 'Pièces + épaisseur des cloisons et refends ; à contrôler (hauteur sous plafond > 1,80 m, trémies d\'escalier à déduire)', 'valeur' => nb > 0 ? m2(pieces + int) : '—' }
      avert << 'Aucune pièce balisée : utilisez « Pièces automatiques » ou « Relevé de côtes ».' if nb == 0
      # Hauteurs
      zhaut = nil; zegout = nil
      A2M::Plan2D.parcourir(model.entities, Geom::Transformation.new) do |e, t|
        next unless e.layer.name.to_s.start_with?('A2M_TOITURE')
        cs = A2M::Plan2D.coins(e, t)
        zhaut = [zhaut, cs.map(&:z).max].compact.max
        zegout = [zegout, cs.map(&:z).min].compact.min
      end
      zsol = A2M::Zinguerie.zsol(model) rescue model.bounds.min.z
      zterr = nil
      A2M::Plan2D.parcourir(model.entities, Geom::Transformation.new) { |e, t| zterr = A2M::Plan2D.coins(e, t).map(&:z).min if e.layer.name == 'A2M_TERRAIN' }
      ref = zterr || zsol
      lignes << { 'titre' => 'Hauteur au faîtage', 'aide' => "Point haut de la toiture au-dessus de #{zterr ? 'votre terrain balisé' : 'le sol fini du rez-de-chaussée (balisez le terrain A2M_TERRAIN pour le sol naturel)'}", 'valeur' => zhaut ? m((zhaut - ref).to_f * 0.0254) : '—' }
      lignes << { 'titre' => 'Hauteur à l\'égout', 'aide' => 'Bas des pans de toiture au-dessus de la même référence', 'valeur' => zegout ? m((zegout - ref).to_f * 0.0254) : '—' }
      avert << 'Pas de toiture balisée : générez-la avec l\'outil Toiture.' unless zhaut
      { 'lignes' => lignes, 'avert' => avert.join(' '), 'reculs' => @reculs || [] }
    end

    def self.reculs
      model = Sketchup.active_model
      aretes = model.selection.grep(Sketchup::Edge)
      aretes += model.selection.grep(Sketchup::Face).flat_map(&:edges)
      return UI.messagebox('Sélectionnez les lignes de limite de propriété (arêtes ou face du terrain).') if aretes.empty?
      emp, contour = empreinte(model, BAL_MURS)
      return UI.messagebox('Aucun mur périphérique balisé.') if contour.empty?
      pts = contour.flat_map { |a, b| [a, b] }
      res = []
      model.start_operation('Reculs', true)
      grp = model.entities.add_group
      grp.name = 'Reculs'
      aretes.uniq.each_with_index do |e, i|
        a = e.start.position; b = e.end.position
        a0 = Geom::Point3d.new(a.x, a.y, 0); b0 = Geom::Point3d.new(b.x, b.y, 0)
        l = [a0, b0]
        best = nil
        pts.each do |p|
          q = Geom::Point3d.new(p.x, p.y, 0)
          pr = q.project_to_line(l)
          seg = (pr - a0).dot(b0 - a0)
          pr = seg < 0 ? a0 : (seg > (b0 - a0).dot(b0 - a0) ? b0 : pr)
          d = q.distance(pr)
          best = [d, q, pr] if best.nil? || d < best[0]
        end
        contour.each do |c1, c2|
          [a0, b0].each do |p|
            c = [Geom::Point3d.new(c1.x, c1.y, 0), Geom::Point3d.new(c2.x, c2.y, 0)]
            pr = p.project_to_line(c)
            seg = (pr - c[0]).dot(c[1] - c[0])
            pr = seg < 0 ? c[0] : (seg > (c[1] - c[0]).dot(c[1] - c[0]) ? c[1] : pr)
            d = p.distance(pr)
            best = [d, pr, p] if d < best[0]
          end
        end
        res << { 'nom' => "Limite #{i + 1} (#{(a0.distance(b0).to_f * 0.0254).round(1).to_s.tr('.', ',')} m)", 'valeur' => m(best[0].to_f * 0.0254) }
        grp.entities.add_dimension_linear(best[1], best[2], Geom::Vector3d.new(0, 0, 0.1.m)) rescue nil
      end
      model.commit_operation
      @reculs = res
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      html = A2M::Panneau.page('Surfaces réglementaires', 'Emprise, surface de plancher, hauteurs et reculs pour le permis', CORPS, SCRIPT, calculer)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : surfaces réglementaires', 'A2M_Panneau_Regl', html, 480, 700)
      @fen = dlg
      dlg.add_action_callback('recalc') { |_c, _j| UI.start_timer(0, false) { dlg.execute_script("maj(#{JSON.generate(calculer)})") } }
      dlg.add_action_callback('reculs') { |_c, _j| UI.start_timer(0, false) { reculs; dlg.execute_script("maj(#{JSON.generate(calculer)})") } }
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
