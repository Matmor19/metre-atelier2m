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
      ['Terrasse (pièce extérieure)', 'A2M_PIECE',     'A2M_PIECE',          12.0, 0, nil],
      ['Allée ou accès',          'A2M_ALLEE',         'A2M_ALLEE',          10.0, 0, 'Allée'],
      ['Plafond',                 'A2M_PLAFOND',       'A2M_PLAFOND',         1.3, 0, 'Plafond']
    ]
    NIVEAUX = ['RDC', 'Étage']
    SENS = ['Au-dessus du tracé (le tracé est le dessous)', 'En dessous du tracé (le tracé est le dessus)']
    @reglages = {}

    def self.demander
      t = TYPES.find { |x| x[0] == @reglages[:type] } || TYPES[0]
      r = @reglages[t[0]] || {}
      alt0 = r[:alt] || (t[0] == 'Plafond' ? 2.5 : 0.0)
      rep = UI.inputbox(['Type', 'Niveau', 'Épaisseur (cm)', 'Pose', 'Hauteur au-dessus du tracé (m) — plafond : hauteur sous plafond'],
                        [t[0], @reglages[:niveau] || NIVEAUX[0], (r[:e] || t[3]).to_s, SENS[r[:sens] || t[4]], alt0.to_s],
                        [TYPES.map(&:first).join('|'), NIVEAUX.join('|'), '', SENS.join('|'), ''], 'Dessiner un sol ou un plafond (Métré Atelier 2M)')
      return nil unless rep
      type = TYPES.find { |x| x[0] == rep[0] }
      e = rep[2].to_s.tr(',', '.').to_f
      return UI.messagebox('L\'épaisseur doit être supérieure à 0.') && nil if e <= 0
      sens = SENS.index(rep[3]) || 0
      alt = rep[4].to_s.tr(',', '.').to_f
      # Type changé dans la liste : le plafond propose 2,50 m s'il n'a pas encore de réglage
      alt = 2.5 if type[0] == 'Plafond' && alt.zero? && !(@reglages[type[0]] || {})[:alt] && rep[0] != t[0]
      nom = nil
      if type[5].nil?
        rp = UI.inputbox(['Nom de la pièce (ex. Séjour, Chambre 1)'], [type[0].start_with?('Terrasse') ? 'Terrasse' : ''], 'Revêtement de sol')
        return nil unless rp && !rp[0].to_s.strip.empty?
        nom = rp[0].to_s.strip
      end
      @reglages[:type] = type[0]; @reglages[:niveau] = rep[1]; @reglages[type[0]] = { e: e, sens: sens, alt: alt }
      { type: type, etage: rep[1] == 'Étage', e: e, sens: sens, nom: nom, alt: alt }
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
        z = pts[0].z + (p[:alt] || 0).to_f.m   # hauteur de pose au-dessus du tracé (plafond : hauteur sous plafond)
        f = grp.entities.add_face(pts.map { |q| Geom::Point3d.new(q.x, q.y, z) })
        f.reverse! if f.normal.z < 0
        e = (p[:e] / 100.0).m
        f.pushpull(p[:sens] == 0 ? e : -e)
        type = p[:type]
        tag = p[:etage] ? type[2] : type[1]
        l, _ = A2M::Balises.balise(model, tag, (A2M::Balises::LISTE.find { |n, _, _| n == tag } || [])[2])
        grp.layer = l
        A2M::Hachures.poser(grp, model)
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
      def initialize(p) @p = p; @pts = []; @pt = A2M::Pointeur.new end
      def activate() statut end
      def resume(view) statut; view.invalidate end
      def deactivate(view) view.invalidate end
      def statut
        Sketchup.status_text = "#{@p[:type][0]}#{@p[:nom] ? ' (' + @p[:nom] + ')' : ''} — ép. #{@p[:e]} cm#{(@p[:alt] || 0).to_f > 0 ? ", posé à #{@p[:alt]} m au-dessus du tracé" : ''}. Cliquez le contour (au sol, accrochages SketchUp) ; " \
                               'tapez une longueur puis Entrée ; Maj = bloquer la direction, flèches droite/gauche = axes rouge/vert ; clic sur le 1er point (carré vert) ou Entrée pour fermer ; Échap pour annuler.'
        Sketchup.vcb_label = 'Longueur'
      end
      def sol(pt) Geom::Point3d.new(pt.x, pt.y, @pts.empty? ? pt.z : @pts[0].z) end
      def onMouseMove(_f, x, y, view)
        q = @pt.bouger(view, x, y, @pts)
        Sketchup.vcb_value = @pts[-1].distance(q).to_l.to_s if @pts.any?
        view.invalidate
      end
      def onKeyDown(key, rpt, _f, view) @pt.touche_bas(key, rpt, view, @pts) end
      def onKeyUp(key, _rpt, _f, view) @pt.touche_haut(key, view) end
      def ajouter(pt, view, ferme = false)
        pt = sol(pt)
        if @pts.size >= 3 && (ferme || pt.distance(@pts[0]) < 0.4)
          fermer(view)
          return
        end
        return if @pts.any? && pt.distance(@pts[-1]) < 0.04
        @pts << pt; @pt.valider; view.invalidate
      end
      def fermer(view)
        if @pts.size >= 3
          A2M::DessinSols.construire(@pts.dup, @p)
          @pts.clear; @pt.vider(Sketchup.active_model.active_view)
          # Revêtement : une pièce par contour ; on redemande le nom pour la pièce suivante
          if @p[:nom]
            rp = UI.inputbox(['Nom de la pièce suivante (vide pour arrêter)'], [''], 'Revêtement de sol')
            if rp && !rp[0].to_s.strip.empty? then @p = @p.merge(nom: rp[0].to_s.strip) else Sketchup.active_model.select_tool(nil) end
          end
        end
        statut; view.invalidate
      end
      def onLButtonDown(_f, _x, _y, view) ajouter(@pt.pos || @pt.ip.position, view, @pt.ferme?) end
      def onReturn(view) fermer(view) end
      def onUserText(text, view)
        l = text.to_l rescue nil
        return UI.beep unless l && @pts.any? && @pt.pos
        dir = @pt.pos - @pts[-1]
        return UI.beep if dir.length < 0.001
        dir.length = l
        ajouter(@pts[-1].offset(dir), view)
      end
      def onCancel(_r, view) @pts.empty? ? Sketchup.active_model.select_tool(nil) : (@pts.clear; @pt.vider(view); view.invalidate) end
      def draw(view)
        @pt.dessiner(view, @pts, 'green')
        return if @pts.empty? || @pt.pos.nil?
        view.line_width = 1; view.drawing_color = 'gray'; view.line_stipple = '-'
        view.draw(GL_LINES, [@pt.pos, @pts[0]]) if @pts.size >= 2 && !@pt.ferme?
        view.line_stipple = ''
        # Aperçu à la hauteur de pose
        if (@p[:alt] || 0).to_f > 0
          dz = Geom::Vector3d.new(0, 0, @p[:alt].to_f.m)
          view.line_stipple = '-'; view.drawing_color = 'blue'
          view.draw(GL_LINE_STRIP, (@pts + [@pt.pos]).map { |q| q.offset(dz) })
          view.line_stipple = ''
        end
      end
      def getExtents
        bb = Geom::BoundingBox.new; @pts.each { |q| bb.add(q) }; bb.add(@pt.pos) if @pt.pos; bb
      end
    end
  end
end
