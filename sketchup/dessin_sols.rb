# encoding: UTF-8
# Métré Atelier 2M : outil de dessin des dalles, planchers, isolants de sol, chapes, revêtements et plafonds
require 'sketchup.rb'

module A2M
  module DessinSols
    # [libellé, balise RDC, balise étage, épaisseur par défaut (cm), sens par défaut, nom des groupes]
    # Le revêtement de sol est dessiné pièce par pièce : il devient la pièce (surface et linéaire) dans le configurateur.
    TYPES = [
      ['Dalle béton',             'A2M_DALLAGE',       'A2M_PLANCHER_ETAGE', 12.0, 0, 'Dalle béton'],
      ['Dalle bois (plancher bois)', 'A2M_DALLAGE',    'A2M_PLANCHER_ETAGE', 22.0, 0, 'Plancher bois'],
      ['Plancher hourdis',        'A2M_DALLAGE',       'A2M_PLANCHER_ETAGE', 20.0, 0, 'Plancher hourdis'],
      ['Isolation au sol',        'A2M_ISOLANT_SOL',   'A2M_ISOLANT_SOL',    10.0, 0, 'Isolant de sol'],
      ['Chape',                   'A2M_CHAPE',         'A2M_CHAPE',           5.0, 0, 'Chape'],
      ['Revêtement de sol (une pièce)', 'A2M_PIECE',   'A2M_PIECE',           1.0, 0, nil],
      ['Plafond',                 'A2M_PLAFOND',       'A2M_PLAFOND',         1.3, 1, 'Plafond']
    ]
    NIVEAUX = ['RDC', 'Étage']
    SENS = ['Au-dessus du tracé (le tracé est le dessous)', 'En dessous du tracé (le tracé est le dessus)']
    @reglages = {}

    def self.demander
      t = TYPES.find { |x| x[0] == @reglages[:type] } || TYPES[0]
      r = @reglages[t[0]] || {}
      rep = UI.inputbox(['Type', 'Niveau', 'Épaisseur (cm)', 'Pose'],
                        [t[0], @reglages[:niveau] || NIVEAUX[0], (r[:e] || t[3]).to_s, SENS[r[:sens] || t[4]]],
                        [TYPES.map(&:first).join('|'), NIVEAUX.join('|'), '', SENS.join('|')], 'Dessiner un sol ou un plafond (Métré Atelier 2M)')
      return nil unless rep
      type = TYPES.find { |x| x[0] == rep[0] }
      e = rep[2].to_s.tr(',', '.').to_f
      return UI.messagebox('L\'épaisseur doit être supérieure à 0.') && nil if e <= 0
      sens = SENS.index(rep[3]) || 0
      nom = nil
      if type[5].nil?
        rp = UI.inputbox(['Nom de la pièce (ex. Séjour, Chambre 1)'], [''], 'Revêtement de sol')
        return nil unless rp && !rp[0].to_s.strip.empty?
        nom = rp[0].to_s.strip
      end
      @reglages[:type] = type[0]; @reglages[:niveau] = rep[1]; @reglages[type[0]] = { e: e, sens: sens }
      { type: type, etage: rep[1] == 'Étage', e: e, sens: sens, nom: nom }
    end

    def self.lancer
      p = demander
      Sketchup.active_model.select_tool(Outil.new(p)) if p
    end

    def self.construire(pts, p)
      model = Sketchup.active_model
      model.start_operation('Dessiner un sol ou un plafond (métré)', true)
      begin
        grp = model.active_entities.add_group
        z = pts[0].z
        f = grp.entities.add_face(pts.map { |q| Geom::Point3d.new(q.x, q.y, z) })
        f.reverse! if f.normal.z < 0
        e = (p[:e] / 100.0).m
        f.pushpull(p[:sens] == 0 ? e : -e)
        type = p[:type]
        tag = p[:etage] ? type[2] : type[1]
        l, _ = A2M::Balises.balise(model, tag, (A2M::Balises::LISTE.find { |n, _, _| n == tag } || [])[2])
        grp.layer = l
        if p[:nom]
          grp.name = p[:nom]
        else
          base = "#{type[5]}#{type[1] != type[2] ? (p[:etage] ? ' étage' : ' RDC') : ''}"
          num = model.active_entities.grep(Sketchup::Group).count { |g| g.name.start_with?(base) }
          grp.name = "#{base} #{num}"
        end
        model.commit_operation
        Sketchup.status_text = "#{grp.name} créé : épaisseur #{p[:e]} cm, balise #{tag}"
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("La surface n'a pas pu être créée (#{ex.message}). Vérifiez que le contour ne se recoupe pas.")
      end
    end

    # Outil : clics successifs sur le contour ; clic sur le premier point ou Entrée pour fermer ; Échap pour annuler
    class Outil
      def initialize(p) @p = p; @pts = []; @ip = Sketchup::InputPoint.new; @ip0 = Sketchup::InputPoint.new end
      def activate() statut end
      def resume(view) statut; view.invalidate end
      def deactivate(view) view.invalidate end
      def statut
        Sketchup.status_text = "#{@p[:type][0]}#{@p[:nom] ? ' (' + @p[:nom] + ')' : ''} — ép. #{@p[:e]} cm. Cliquez le contour ; " \
                               'tapez une longueur puis Entrée ; clic sur le 1er point ou Entrée pour fermer ; Échap pour annuler.'
        Sketchup.vcb_label = 'Longueur'
      end
      def sol(pt) Geom::Point3d.new(pt.x, pt.y, @pts.empty? ? pt.z : @pts[0].z) end
      def onMouseMove(_f, x, y, view)
        @pts.empty? ? @ip.pick(view, x, y) : @ip.pick(view, x, y, @ip0)
        Sketchup.vcb_value = @pts[-1].distance(sol(@ip.position)).to_l.to_s if @pts.any?
        view.invalidate
      end
      def ajouter(pt, view)
        pt = sol(pt)
        if @pts.size >= 3 && pt.distance(@pts[0]) < 0.4
          fermer(view)
          return
        end
        return if @pts.any? && pt.distance(@pts[-1]) < 0.04
        @pts << pt; @ip0.copy!(@ip); view.invalidate
      end
      def fermer(view)
        if @pts.size >= 3
          A2M::DessinSols.construire(@pts.dup, @p)
          @pts.clear; @ip0.clear
          # Revêtement : une pièce par contour ; on redemande le nom pour la pièce suivante
          if @p[:nom]
            rp = UI.inputbox(['Nom de la pièce suivante (vide pour arrêter)'], [''], 'Revêtement de sol')
            if rp && !rp[0].to_s.strip.empty? then @p = @p.merge(nom: rp[0].to_s.strip) else Sketchup.active_model.select_tool(nil) end
          end
        end
        statut; view.invalidate
      end
      def onLButtonDown(_f, _x, _y, view) ajouter(@ip.position, view) end
      def onReturn(view) fermer(view) end
      def onUserText(text, view)
        l = text.to_l rescue nil
        return UI.beep unless l && @pts.any?
        dir = sol(@ip.position) - @pts[-1]
        return UI.beep if dir.length < 0.001
        dir.length = l
        ajouter(@pts[-1].offset(dir), view)
      end
      def onCancel(_r, view) @pts.empty? ? Sketchup.active_model.select_tool(nil) : (@pts.clear; @ip0.clear; view.invalidate) end
      def draw(view)
        @ip.draw(view) if @ip.display?
        return if @pts.empty?
        view.line_width = 2; view.drawing_color = 'green'
        view.draw(GL_LINE_STRIP, @pts + [sol(@ip.position)])
        view.line_width = 1; view.drawing_color = 'gray'
        view.draw(GL_LINES, [sol(@ip.position), @pts[0]]) if @pts.size >= 2
      end
      def getExtents
        bb = Geom::BoundingBox.new; @pts.each { |q| bb.add(q) }; bb.add(@ip.position) if @ip.valid?; bb
      end
    end
  end
end
