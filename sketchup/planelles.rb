# encoding: UTF-8
# Métré Atelier 2M : planelles en rive de dalle (et leur isolant), sur tout le pourtour de la dalle sélectionnée
#  - hauteur = épaisseur de la dalle (modifiable), épaisseur de la planelle et de l'isolant au choix ;
#  - dans l'épaisseur (nu extérieur de la planelle = bord de la dalle, la dalle est recoupée d'autant)
#    ou à l'extérieur de la dalle ;
#  - le linéaire est rappelé à l'import dans le configurateur (pas encore de case planelle au métré).
require 'sketchup.rb'

module A2M
  module Planelles
    DANS = 'Dans l\'épaisseur de la dalle (la dalle est recoupée)'
    DEHORS = 'À l\'extérieur de la dalle'
    TYPE_PL = ['Planelle', 'A2M_PLANELLE', 0, 0, 'Planelle']
    TYPE_ISO = ['Isolant de planelle', 'A2M_ISOLANT_PLANELLE', 0, 0, 'Isolant de planelle']
    @r = {}

    # Contour extérieur du dessus de la dalle (sens trigonométrique), hauteur du dessous et du dessus
    def self.contour(g)
      tr = g.transformation
      faces = g.entities.grep(Sketchup::Face)
      hs = faces.select { |f| f.normal.transform(tr).z > 0.99 }
      return nil if hs.empty?
      top = hs.max_by(&:area)
      pts = top.outer_loop.vertices.map { |v| tr * v.position }
      zs = faces.flat_map { |f| f.vertices.map { |v| (tr * v.position).z } }
      pts.reverse! if A2M::DessinMurs.aire(pts.map { |q| [q.x, q.y] }) < 0
      [pts.map { |q| Geom::Point3d.new(q.x, q.y, zs.min) }, zs.min, zs.max]
    end

    def self.lancer
      model = Sketchup.active_model
      dalles = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) && contour(e) }
      return UI.messagebox('Sélectionnez la ou les dalles (groupes) sur lesquelles poser les planelles.') if dalles.empty?
      _, z0, z1 = contour(dalles[0])
      ep_dalle = ((z1 - z0) * 2.54).round(1)
      rep = UI.inputbox(['Hauteur de la planelle (cm)', 'Épaisseur de la planelle (cm)', 'Isolant derrière la planelle (cm, 0 = aucun)', 'Position'],
                        [(@r[:h] || ep_dalle).to_s, (@r[:e] || 5).to_s, (@r[:iso] || 0).to_s, @r[:pos] || DANS],
                        ['', '', '', [DANS, DEHORS].join('|')], "Planelles en rive de dalle (épaisseur de la dalle : #{ep_dalle} cm)")
      return unless rep
      h, e, iso = rep[0..2].map { |v| v.to_s.tr(',', '.').to_f }
      return UI.messagebox('Hauteur et épaisseur supérieures à 0.') if h <= 0 || e <= 0
      @r = { h: h, e: e, iso: iso, pos: rep[3] }
      dans = rep[3] == DANS
      cm = ->(v) { (v / 100.0).m }
      model.start_operation('Planelles en rive de dalle (métré)', true)
      begin
        faits = []
        dalles.each do |g|
          pts, = contour(g)
          # Bandes depuis le bord de la dalle : vers l'intérieur (gauche du contour) si « dans », vers l'extérieur sinon
          if dans
            bandes = [[TYPE_PL, 0.0, cm.call(e)]]
            bandes << [TYPE_ISO, cm.call(e), cm.call(e + iso)] if iso > 0
          else
            # Dehors : l'isolant contre la dalle, la planelle à l'extérieur
            bandes = [[TYPE_ISO, 0.0, -cm.call(iso)], [TYPE_PL, -cm.call(iso), -cm.call(iso + e)]].reject { |_t, a, b| (a - b).abs < 1e-6 }
          end
          groupes = bandes.map do |t, a, b|
            A2M::DessinMurs.construire_couche(pts, true, t, h / 100.0, [a, b].max, [a, b].min)
          end
          # Dalle recoupée sous les bandes (la planelle prend la place du béton en rive)
          if dans
            groupes.each do |gb|
              copie = gb.copy
              vol = g.volume rescue -1
              nom, tag, mat = g.name, g.layer, g.material
              res = A2M::Ouvertures.inverse? ? g.subtract(copie) : copie.subtract(g)
              if res && !(vol > 0 && (res.volume rescue 0) > vol + 1)
                res.name = nom; res.layer = tag; res.material = mat if mat
                g = res
              else
                copie.erase! if copie.valid?
              end
            end
          end
          long = (0...pts.size).sum { |i| pts[i].distance(pts[(i + 1) % pts.size]) } * 0.0254
          faits << "#{g.name.to_s.empty? ? 'Dalle' : g.name} : #{long.round(2)} ml"
        end
        model.commit_operation
        UI.messagebox("Planelles posées (#{h} × #{e} cm#{iso > 0 ? ", isolant #{iso} cm" : ''}) :\n" + faits.join("\n") +
                      "\n\nLe linéaire sera rappelé à l'import dans le configurateur (pas de case planelle au métré pour l'instant).")
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Planelles non posées (#{ex.message}).")
      end
    end
  end
end
