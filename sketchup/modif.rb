# encoding: UTF-8
# Métré Atelier 2M : « Modifier ce que j'ai dessiné » : un seul bouton qui rouvre l'outil qui a créé l'objet sélectionné
# (mur, toiture, ouverture, sol, escalier, garde-corps, couverture, charpente, zinguerie, semelles…) avec ses réglages.
require 'sketchup.rb'
require 'json'

module A2M
  module Modif
    CLE = 'a2m_reglage'

    # Mémorise sur le groupe l'outil qui l'a créé et ses réglages (JSON-able)
    def self.noter(ent, outil, donnees)
      ent.set_attribute(CLE, 'outil', outil)
      ent.set_attribute(CLE, 'donnees', JSON.generate(donnees))
    rescue StandardError
      nil
    end

    def self.lire(ent)
      return nil unless ent.respond_to?(:get_attribute)
      o = ent.get_attribute(CLE, 'outil') or return nil
      [o, (JSON.parse(ent.get_attribute(CLE, 'donnees').to_s) rescue {})]
    end

    def self.pts_vers(pts) pts.map { |q| [q.x.to_f, q.y.to_f, q.z.to_f] } end
    def self.pts_de(l) l.map { |x, y, z| Geom::Point3d.new(x, y, z || 0) } end

    # Ce qu'est cet objet : :mur, :toiture, :ouverture ou le nom de l'outil mémorisé ; nil sinon
    def self.genre(e)
      return nil unless e.respond_to?(:get_attribute) && e.respond_to?(:valid?) && e.valid?
      return :toiture if e.get_attribute('a2m_toiture', 'base')
      return :ouverture if A2M::Suivi.suivie?(e)
      o = e.get_attribute(CLE, 'outil')
      return o.to_sym if o
      return :mur if e.get_attribute('a2m_mur', 'id')
      nil
    end

    def self.chercher(model)
      model.selection.to_a.each { |e| g = genre(e); return [e, g] if g }
      nil
    end

    def self.modifier(ent = nil, genre = nil)
      model = Sketchup.active_model
      ent, genre = chercher(model) unless ent
      genre ||= genre(ent) if ent
      unless ent && genre
        model.select_tool(Choisir.new)
        return
      end
      d = lire(ent)
      d = d && d[1]
      case genre
      when :mur then A2M::DessinMurs.modifier(ent)
      when :toiture then A2M::Toiture.modifier(ent)
      when :ouverture then A2M::Ouvertures.modifier(ent)
      when :sol then A2M::DessinSols.modifier(ent, d)
      when :solmur then A2M::SolMurs.modifier(ent, d)
      when :escalier then A2M::Escalier.modifier(ent, d)
      when :garde_corps then A2M::GardeCorps.modifier(ent, d)
      when :couverture then A2M::Couverture.modifier(ent, d)
      when :charpente then A2M::Charpente.modifier(ent, d)
      when :zinguerie then A2M::Zinguerie.modifier(ent, d)
      when :semelle then A2M::Fondations.modifier(ent, d)
      when :ferraillage then A2M::Ferraillage.modifier(ent, d)
      else UI.messagebox('Cet objet ne peut pas encore être rouvert.')
      end
    end

    # Script ajouté à un panneau à cartes pour le remplir avec des réglages déjà faits (clés = identifiants des champs ou de l'état « s »)
    def self.js_prerempli(r, bouton = 'Appliquer la modification', replacer = nil)
      <<~JS

        (function (r) {
          for (var k in r) {
            var e = document.getElementById(k);
            if (e && e.tagName === 'INPUT') e.value = r[k];
            if (typeof s !== 'undefined') s[k] = r[k];
          }
          var go = document.getElementById('go'); if (go) go.textContent = #{JSON.generate(bouton)};
          #{replacer ? "var bas = document.getElementById('bas'); if (bas) { var l = document.createElement('label'); l.style.cssText = 'display:block;margin:6px 0;font-size:13px'; l.innerHTML = '<input type=\"checkbox\" id=\"replacer\"> #{replacer}'; bas.parentNode.insertBefore(l, bas); var cb = l.querySelector('input'); if (typeof s !== 'undefined') { cb.checked = !!s.replacer; cb.addEventListener('change', function () { s.replacer = cb.checked; }); } }" : ''}
          if (typeof choisir === 'function' && r.mat) { var sv = {}; for (var kk in r) sv[kk] = r[kk]; choisir(r.mat); for (var k2 in sv) { var e2 = document.getElementById(k2); if (e2 && e2.tagName === 'INPUT') e2.value = sv[k2]; if (typeof s !== 'undefined') s[k2] = sv[k2]; } }
          if (typeof rendre === 'function') rendre();
          if (typeof calc === 'function') calc();
        })(#{JSON.generate(r)});
      JS
    end

    # Clic sur un objet dessiné avec les outils : sa fenêtre de réglages s'ouvre
    class Choisir
      def activate
        Sketchup.status_text = 'Modifier : cliquez sur ce que vous avez dessiné (mur, toiture, ouverture, sol, escalier, garde-corps…). Échap pour quitter.'
      end
      def onSetCursor() false end
      def onCancel(_r, _v) Sketchup.active_model.select_tool(nil) end
      def onLButtonDown(_f, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        trouve = nil
        (0...ph.count).each do |i|
          (ph.path_at(i) || []).reverse_each do |e|
            g = A2M::Modif.genre(e)
            (trouve = [e, g]; break) if g
          end
          break if trouve
        end
        trouve ||= (e = ph.best_picked; g = A2M::Modif.genre(e); g && [e, g])
        if trouve
          Sketchup.active_model.select_tool(nil)
          UI.start_timer(0, false) { A2M::Modif.modifier(*trouve) }
        elsif (e = ph.all_picked.find { |q| A2M::DessinMurs.mur_possible?(q) })
          Sketchup.active_model.select_tool(nil)
          UI.start_timer(0, false) { A2M::DessinMurs.modifier(e) }
        else
          UI.beep
          Sketchup.status_text = 'Cet objet n\'a pas été dessiné avec les outils Atelier 2M (ou avant la mémoire des réglages) : refaites-le une fois avec l\'outil.'
        end
      end
    end

    # Déplacement des points d'un contour (polygone fermé) ; chaque geste rappelle le bloc avec les nouveaux points
    class Points
      PRISE = 12
      def initialize(pts, ferme = true, &bloc)
        @pts = pts.map { |q| Geom::Point3d.new(q.x, q.y, q.z) }; @ferme = ferme; @bloc = bloc
        @sel = nil; @surv = nil; @cur = nil; @ip = Sketchup::InputPoint.new
      end
      def activate() Sketchup.status_text = 'Contour : cliquez un point puis son nouvel emplacement ; cliquez sur un côté pour ajouter un point ; Suppr sur un point le retire ; Entrée ou Échap pour terminer.' end
      def deactivate(view) view.invalidate end
      def ecran(pt, view) q = view.screen_coords(pt); Geom::Point3d.new(q.x, q.y, 0) end
      def segs
        n = @pts.size
        (0...(@ferme ? n : n - 1)).map { |i| [i, @pts[i], @pts[(i + 1) % n]] }
      end
      def survol(x, y, view)
        @pts.each_with_index { |q, i| a = ecran(q, view); return [:point, i] if Math.hypot(a.x - x, a.y - y) < PRISE }
        segs.each { |i, a, b| return [:segment, i] if A2M::DessinMurs.distance_segment(Geom::Point3d.new(x, y, 0), ecran(a, view), ecran(b, view)) < PRISE }
        nil
      end
      def onMouseMove(_f, x, y, view)
        if @sel
          @ip.pick(view, x, y)
          @cur = Geom::Point3d.new(@ip.position.x, @ip.position.y, @pts[@sel].z)
        else
          @surv = survol(x, y, view)
        end
        view.invalidate
      end
      def onLButtonDown(_f, x, y, view)
        if @sel
          return unless @cur
          @pts[@sel] = @cur; @sel = nil
          @bloc.call(@pts.map(&:clone)); view.invalidate
        else
          s = survol(x, y, view) or return
          if s[0] == :point then @sel = s[1]
          else
            i = s[1]; a = @pts[i]
            q = Geom.intersect_line_plane(view.pickray(x, y), [a, Z_AXIS]) || a
            @pts.insert(i + 1, Geom::Point3d.new(q.x, q.y, a.z)); @sel = i + 1
          end
          @cur = @pts[@sel]; view.invalidate
        end
      end
      def onKeyDown(key, _r, _f, view)
        return false unless key == 46 && @surv && @surv[0] == :point && @pts.size > 3
        @pts.delete_at(@surv[1]); @surv = nil
        @bloc.call(@pts.map(&:clone)); view.invalidate
        true
      end
      def onReturn(_view) Sketchup.active_model.select_tool(nil) end
      def onCancel(_r, view) @sel ? (@sel = nil; view.invalidate) : Sketchup.active_model.select_tool(nil) end
      def draw(view)
        pts = @pts.each_with_index.map { |q, i| i == @sel && @cur ? @cur : q }
        view.line_width = 2; view.drawing_color = 'orange'
        view.draw(GL_LINE_STRIP, @ferme ? pts + [pts[0]] : pts)
        pts.each_with_index { |q, i| view.draw_points([q], 10, 2, i == @sel ? 'red' : 'orange') }
      end
      def getExtents
        bb = Geom::BoundingBox.new; @pts.each { |q| bb.add(q) }; bb.add(@cur) if @cur; bb
      end
    end
  end
end
