# encoding: UTF-8
# Métré Atelier 2M : cotation automatique. Cotes de chaque pièce (côté par côté) et cotes hors tout du bâtiment, posées en un clic
require 'sketchup.rb'
require 'json'

module A2M
  module CotationAuto
    TAG = 'A2M_COTES_AUTO'
    SEUIL = 30.0   # cm : on ne cote pas les côtés plus courts

    def self.sommets(face, t)
      pts = face.outer_loop.vertices.map { |v| t * v.position }
      # supprime les sommets alignés
      res = []
      pts.each_with_index do |p, i|
        a = pts[i - 1]; b = pts[(i + 1) % pts.size]
        u = a.vector_to(p) rescue next
        v = p.vector_to(b) rescue next
        res << p unless u.cross(v).length < 0.002
      end
      res
    end

    def self.aire_signee(pts)
      pts.each_with_index.sum { |p, i| q = pts[(i + 1) % pts.size]; p.x * q.y - q.x * p.y } / 2.0
    end

    def self.cotes_polygone(ents, pts, ecart, dehors)
      return 0 if pts.size < 3
      sens = aire_signee(pts) > 0 ? 1 : -1      # +1 : sens trigonométrique
      n = 0
      pts.each_with_index do |a, i|
        b = pts[(i + 1) % pts.size]
        next if a.distance(b).to_cm < SEUIL
        d = a.vector_to(b)
        ext = Geom::Vector3d.new(d.y * sens, -d.x * sens, 0)    # normale vers l'extérieur
        next if ext.length < 0.001
        ext.normalize!
        ext.length = ecart.cm * (dehors ? 1 : -1)
        c = ents.add_dimension_linear(a, b, ext)
        c.layer = Sketchup.active_model.layers[TAG] rescue nil
        n += 1
      end
      n
    end

    def self.pieces(model)
      res = []
      A2M::Plan2D.parcourir(model.entities, Geom::Transformation.new) do |e, t|
        next unless e.layer.name == 'A2M_PIECE'
        ents = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
        f = ents.grep(Sketchup::Face).max_by(&:area) or next
        res << sommets(f, t)
      end
      res.compact
    end

    # Emprise du bâtiment : boîte des murs périphériques (ou de tous les murs)
    def self.emprise(model)
      bb = Geom::BoundingBox.new
      A2M::Plan2D.parcourir(model.entities, Geom::Transformation.new) do |e, t|
        n = e.layer.name
        next unless n.start_with?('A2M_MUR_PERI') || n.start_with?('A2M_MUR_EXT')
        A2M::Plan2D.coins(e, t).each { |p| bb.add(p) }
      end
      if bb.empty?
        A2M::Plan2D.parcourir(model.entities, Geom::Transformation.new) do |e, t|
          next unless e.layer.name.start_with?('A2M_MUR')
          A2M::Plan2D.coins(e, t).each { |p| bb.add(p) }
        end
      end
      bb
    end

    def self.poser(r)
      model = Sketchup.active_model
      model.start_operation('Cotation automatique Atelier 2M', true)
      begin
        tag, _ = A2M::Balises.balise(model, TAG, [224, 120, 56])
        model.entities.grep(Sketchup::Group).each { |g| g.erase! if g.valid? && g.name == 'Cotes automatiques' }
        model.entities.grep(Sketchup::DimensionLinear).each { |c| c.erase! if c.valid? && c.layer.name == TAG }
        grp = model.entities.add_group
        grp.name = 'Cotes automatiques'; grp.layer = tag
        ents = grp.entities
        sol = A2M::Plan2D.sol_auto(model).cm + 1.cm
        np = 0; nb = 0
        if r['pieces']
          pieces(model).each do |pts|
            pts = pts.map { |p| Geom::Point3d.new(p.x, p.y, sol) }
            np += cotes_polygone(ents, pts, 15, false)
          end
        end
        if r['horsout']
          bb = emprise(model)
          unless bb.empty?
            x0 = bb.min.x; x1 = bb.max.x; y0 = bb.min.y; y1 = bb.max.y
            z = sol
            ec = r['ecart'].to_f > 0 ? r['ecart'].to_f : 80
            [[[x0, y0], [x1, y0], [0, -1]], [[x1, y0], [x1, y1], [1, 0]]].each do |a, b, v|
              d = ents.add_dimension_linear(Geom::Point3d.new(a[0], a[1], z), Geom::Point3d.new(b[0], b[1], z), Geom::Vector3d.new(v[0] * ec.cm, v[1] * ec.cm, 0))
              d.layer = tag; nb += 1
            end
          end
        end
        model.commit_operation
        UI.messagebox("Cotation posée : #{np} cote(s) de pièce, #{nb} cote(s) hors tout.\nElles sont sur la balise #{TAG} (masquable d'un clic).")
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Cotation impossible : #{ex.message}\n#{ex.backtrace.first}")
      end
    end

    CORPS = <<~'HTML'
      <h2>Quelles cotes</h2>
      <div class="puces" id="choix"></div>
      <div class="petit">« Pièces » cote chaque côté des pièces balisées A2M_PIECE (à l'intérieur). « Hors tout » cote la longueur et la largeur du bâtiment (à l'extérieur des murs).</div>
      <div id="bas"><div id="msg"></div><button type="button" id="go">Coter</button></div>
    HTML
    SCRIPT = <<~'JS'
      var s = { pieces: true, horsout: true };
      function el(i) { return document.getElementById(i); }
      function rendre() {
        var c = el('choix'); c.innerHTML = '';
        [['pieces', 'Cotes des pièces'], ['horsout', 'Cotes hors tout']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s[x[0]] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { s[x[0]] = !s[x[0]]; rendre(); }); c.appendChild(b);
        });
        el('go').disabled = !(s.pieces || s.horsout);
      }
      el('go').addEventListener('click', function () { sketchup.poser(JSON.stringify(s)); });
      rendre();
    JS

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      html = A2M::Panneau.page('Cotation automatique', 'Les cotes se posent toutes seules, sur leur propre balise', CORPS, SCRIPT, {})
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : cotation', 'A2M_Panneau_Cotation', html, 440, 520)
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
