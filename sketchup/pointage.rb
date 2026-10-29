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
      view.draw_points([pts[0]], 12, 2, @ferme ? 'lime' : 'darkgreen') if pts.size >= 3
      view.draw_points([@pos], 8, 1, 'black') unless @guides.empty? && !@axe
    end
  end
end
