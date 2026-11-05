# encoding: UTF-8
# Métré Atelier 2M : pointage commun aux outils de tracé (murs, sols)
# Accrochages de SketchUp (extrémité, milieu, sur l'arête, axes depuis le point précédent), info-bulles,
# Maj pour bloquer la direction, flèche droite = axe rouge, flèche gauche = axe vert,
# aimant sur le premier point (fermer le tour) et alignement sur les points déjà cliqués (pointillés).
require 'sketchup.rb'

module A2M
  class Pointeur
    AIMANT = 12      # pixels : rayon d'attraction du premier point
    ALIGNE = 8       # pixels : tolérance d'alignement sur un point déjà cliqué
    AXES = { VK_RIGHT => [X_AXIS, 'rouge'], VK_LEFT => [Y_AXIS, 'vert'] }

    attr_reader :pos, :ip

    TOUCHE_AXES = 0     # touche Ctrl (COPY_MODIFIER_KEY) : verrouille ou libère les axes ; X et N sont déjà pris par les raccourcis de l'utilisateur

    # Axes verrouillés par défaut : le tracé suit l'axe rouge ou l'axe vert (le plus proche de la direction visée) ;
    # X, ou la commande « Axes verrouillés », passe en tracé libre
    def self.axes?
      @axes = (Sketchup.read_default('A2M_Metre', 'axes_auto', true) ? true : false) if @axes.nil?
      @axes
    end

    def self.basculer
      @axes = !axes?
      Sketchup.write_default('A2M_Metre', 'axes_auto', @axes)
      Sketchup.status_text = @axes ? 'Axes verrouillés : le tracé suit l\'axe rouge ou vert (Ctrl pour tracer librement).' : 'Tracé libre : plus d\'axes imposés (Ctrl pour reverrouiller).'
      @axes
    end

    def initialize
      @ip = Sketchup::InputPoint.new
      @ip0 = Sketchup::InputPoint.new
      @axe = nil; @pos = nil; @guides = []; @info = nil; @ferme = false
    end

    def ferme?() @ferme end

    # Après un clic validé : le point devient la référence des accrochages suivants
    def valider
      @ip0.copy!(@ip)
      @axe = nil
    end

    def vider(view = Sketchup.active_model.active_view)
      @ip0.clear; @axe = nil; @guides = []; @info = nil; @ferme = false
      view.lock_inference if view.inference_locked?
    end

    # pts : points déjà cliqués (le tracé reste à la hauteur du premier)
    def bouger(view, x, y, pts)
      pts.empty? ? @ip.pick(view, x, y) : @ip.pick(view, x, y, @ip0)
      q = @ip.position
      z = pts.empty? ? q.z : pts[0].z
      q = Geom::Point3d.new(q.x, q.y, z)
      @info = nil; @guides = []; @ferme = false
      if pts.any? && (@axe || view.inference_locked?)
        # Direction bloquée (flèche ou Maj) : on peut viser un point déjà cliqué (le premier, pour refermer)
        # ou un point du modèle ; le point retenu est sur la direction bloquée, en face du point visé
        dir = @axe ? @axe[0] : Geom::Vector3d.new(q.x - pts[-1].x, q.y - pts[-1].y, 0)
        if dir.length > 1e-6
          ligne = [pts[-1], dir]
          ref = nil; dmin = AIMANT
          pts[0..-2].each_with_index do |p, i|
            sp = view.screen_coords(p); d = Math.hypot(sp.x - x, sp.y - y)
            ref = [p, i] if d < dmin && (dmin = d)
          end
          ref ||= [@ip.position, nil] if @axe && @ip.degrees_of_freedom == 0
          if ref
            q = ref[0].project_to_line(ligne)
            q = Geom::Point3d.new(q.x, q.y, z)
            @guides = [[Geom::Point3d.new(ref[0].x, ref[0].y, z), q]]
          elsif @axe
            q = q.project_to_line(ligne)
            q = Geom::Point3d.new(q.x, q.y, z)
          end
          nom = @axe ? "l'axe #{@axe[1]}" : 'la direction bloquée'
          @info = if ref && ref[1] == 0 then "Sur #{nom}, en face du premier point"
                  elsif ref && ref[1] then "Sur #{nom}, en face du point #{ref[1] + 1} du tracé"
                  elsif ref then "Sur #{nom}, en face du point visé"
                  else "Sur #{nom} (#{@axe ? 'même flèche' : 'Maj'} pour débloquer)"
                  end
        end
      elsif !view.inference_locked?
        s0 = pts.size >= 3 ? view.screen_coords(pts[0]) : nil
        if s0 && Math.hypot(s0.x - x, s0.y - y) < AIMANT
          q = pts[0].clone
          @ferme = true
          @info = 'Premier point : cliquez pour fermer le tour'
        elsif Pointeur.axes? && pts.any?
          # Axes verrouillés : direction rouge ou verte la plus proche de la visée, longueur libre ;
          # l'autre coordonnée peut s'aligner sur le point du modèle visé ou sur un point déjà cliqué
          p0 = pts[-1]
          horiz = (q.x - p0.x).abs >= (q.y - p0.y).abs
          cible = @ip.degrees_of_freedom == 0 ? @ip.position : nil
          if horiz
            vx = q.x
            if cible then vx = cible.x
            else
              pts.each { |p| sp = view.screen_coords(Geom::Point3d.new(p.x, p0.y, z)); vx = p.x if Math.hypot(sp.x - x, sp.y - y) < ALIGNE }
            end
            q = Geom::Point3d.new(vx, p0.y, z)
            @info = 'Axe rouge verrouillé (Ctrl pour tracer librement)'
          else
            vy = q.y
            if cible then vy = cible.y
            else
              pts.each { |p| sp = view.screen_coords(Geom::Point3d.new(p0.x, p.y, z)); vy = p.y if Math.hypot(sp.x - x, sp.y - y) < ALIGNE }
            end
            q = Geom::Point3d.new(p0.x, vy, z)
            @info = 'Axe vert verrouillé (Ctrl pour tracer librement)'
          end
          @axe_auto = horiz ? 'rouge' : 'vert'
        elsif @ip.degrees_of_freedom > 0
          # Pas d'accrochage sur un point du modèle : alignement sur les points déjà cliqués
          bx = nil; by = nil
          pts.each do |p|
            cx = Geom::Point3d.new(p.x, q.y, z); sx = view.screen_coords(cx); dx = Math.hypot(sx.x - x, sx.y - y)
            cy = Geom::Point3d.new(q.x, p.y, z); sy = view.screen_coords(cy); dy = Math.hypot(sy.x - x, sy.y - y)
            bx = [dx, p] if dx < ALIGNE && (bx.nil? || dx < bx[0])
            by = [dy, p] if dy < ALIGNE && (by.nil? || dy < by[0])
          end
          if bx || by
            q = Geom::Point3d.new(bx ? bx[1].x : q.x, by ? by[1].y : q.y, z)
            @guides = [bx, by].compact.map { |_, p| [p, q] }
            @info = by && bx ? 'Aligné sur deux points du tracé' : 'Aligné sur un point du tracé'
          end
        end
      end
      @pos = q
      view.tooltip = @info || @ip.tooltip
      q
    end

    # Clic droit pendant le tracé : bascule axes verrouillés / tracé libre
    def menu(menu)
      menu.add_item(Pointeur.axes? ? 'Tracer librement (sans axes)' : 'Verrouiller les axes') { Pointeur.basculer }
    end

    # Maj : bloque la direction (appui long : bloque tant que la touche est tenue) ; flèches : axes rouge et vert
    def touche_bas(key, rpt, view, pts)
      if key == CONSTRAIN_MODIFIER_KEY && rpt == 1
        @maj = Time.now
        if view.inference_locked? then view.lock_inference
        elsif pts.any? && @ip.valid? then view.lock_inference(@ip, @ip0)
        elsif @ip.valid? then view.lock_inference(@ip)
        end
        return true
      end
      if (key == TOUCHE_AXES || key == COPY_MODIFIER_KEY) && (@t_axes.nil? || Time.now - @t_axes > 0.3)
        @t_axes = Time.now
        Pointeur.basculer
        view.invalidate
        return true
      end
      if (a = AXES[key]) && pts.any?
        @axe = @axe && @axe[0] == a[0] ? nil : a
        view.invalidate
        return true
      end
      false
    end

    def touche_haut(key, view)
      return false unless key == CONSTRAIN_MODIFIER_KEY
      view.lock_inference if view.inference_locked? && @maj && Time.now - @maj > 0.5
      true
    end

    # Dessin : point d'accrochage, pointillés d'alignement, premier point aimanté,
    # dernier segment coloré comme dans SketchUp (rouge, vert : parallèle à un axe)
    def dessiner(view, pts, couleur)
      @ip.draw(view) if @ip.display? && !@ferme && !@axe && @guides.empty?
      return if pts.empty? || @pos.nil?
      view.line_width = 2; view.drawing_color = couleur
      view.draw(GL_LINE_STRIP, pts) if pts.size >= 2
      view.set_color_from_line(pts[-1], @pos)
      view.draw(GL_LINES, [pts[-1], @pos])
      view.line_width = 1; view.line_stipple = '.'
      @guides.each do |a, b|
        next if a.distance(b) < 0.01
        view.drawing_color = (a.x - b.x).abs < 0.01 ? 'green' : ((a.y - b.y).abs < 0.01 ? 'red' : 'gray')
        view.draw(GL_LINES, [a, b])
      end
      view.line_stipple = ''
      # Pastille de mode près du curseur
      sp = view.screen_coords(@pos)
      view.draw_text(Geom::Point3d.new(sp.x + 18, sp.y - 8, 0), Pointeur.axes? ? "Axes verrouillés (Ctrl : libre)" : 'Tracé libre (Ctrl : axes)',
                     color: Pointeur.axes? ? 'DarkOrange' : 'DimGray', size: 9) rescue nil
      view.draw_points([pts[0]], 12, 2, @ferme ? 'lime' : 'darkgreen') if pts.size >= 3
      view.draw_points([@pos], 8, 1, 'black') unless @guides.empty? && !@axe
    end
  end
end
