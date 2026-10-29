# encoding: UTF-8
# Métré Atelier 2M : outil de dessin des murs, doublages et cloisons, directement sur la bonne balise
require 'sketchup.rb'

module A2M
  module DessinMurs
    # [libellé, balise, hauteur par défaut (m), épaisseur par défaut (cm), nom des groupes]
    TYPES = [
      ['Mur périphérique',           'A2M_MUR_PERI',         2.50, 20.0, 'Mur périphérique'],
      ['Mur de soubassement',        'A2M_MUR_SOUB',         1.00, 20.0, 'Mur de soubassement'],
      ['Mur de refend',              'A2M_MUR_REFEND',       2.50, 20.0, 'Mur de refend'],
      ['Mur pignon',                 'A2M_MUR_PIGNON',       2.50, 20.0, 'Mur pignon'],
      ['Doublage : plaque de plâtre', 'A2M_DOUBLAGE',        2.50, 1.3,  'Doublage plaque'],
      ['Doublage : isolant',         'A2M_ISOLANT_DOUBLAGE', 2.50, 14.0, 'Doublage isolant'],
      ['Cloison',                    'A2M_CLOISON',          2.50, 7.2,  'Cloison']
    ]
    TRACES = ['Axe du mur', 'Face gauche (le mur part à droite du tracé)', 'Face droite (le mur part à gauche du tracé)']
    @reglages = {}

    def self.demander
      dernier = @reglages[:type] || TYPES[0][0]
      t = TYPES.find { |x| x[0] == dernier } || TYPES[0]
      r = @reglages[t[0]] || {}
      rep = UI.inputbox(['Type', 'Hauteur (m)', 'Épaisseur (cm)', 'Le tracé suit'],
                        [t[0], (r[:h] || t[2]).to_s, (r[:e] || t[3]).to_s, @reglages[:trace] || TRACES[0]],
                        [TYPES.map(&:first).join('|'), '', '', TRACES.join('|')], 'Dessiner un mur (Métré Atelier 2M)')
      return nil unless rep
      type = TYPES.find { |x| x[0] == rep[0] }
      h = rep[1].to_s.tr(',', '.').to_f; e = rep[2].to_s.tr(',', '.').to_f
      if h <= 0 || e <= 0
        UI.messagebox('La hauteur et l\'épaisseur doivent être supérieures à 0.')
        return nil
      end
      # Une hauteur ou une épaisseur tapée par erreur en cm ou en m est signalée
      return nil if h > 20 && UI.messagebox("Hauteur de #{h} m : c'est bien en mètres ?", MB_YESNO) == IDNO
      @reglages[:type] = type[0]; @reglages[:trace] = rep[3]; @reglages[type[0]] = { h: h, e: e }
      { type: type, h: h, e: e, trace: TRACES.index(rep[3]) || 0 }
    end

    def self.lancer
      p = demander
      Sketchup.active_model.select_tool(Outil.new(p)) if p
    end

    # ---- Géométrie 2D (plan horizontal), en pouces (unité interne de SketchUp) ----
    def self.decale(pts, d, ferme)
      n = pts.size
      seg = (0...(ferme ? n : n - 1)).map do |i|
        a = pts[i]; b = pts[(i + 1) % n]
        dx = b.x - a.x; dy = b.y - a.y; l = Math.hypot(dx, dy)
        ux, uy = dx / l, dy / l
        nx, ny = -uy, ux
        [[a.x + nx * d, a.y + ny * d], [ux, uy]]
      end
      inter = lambda do |s1, s2|
        (p1x, p1y), (u1x, u1y) = s1
        (p2x, p2y), (u2x, u2y) = s2
        cr = u1x * u2y - u1y * u2x
        return [p2x, p2y] if cr.abs < 1e-9
        t = ((p2x - p1x) * u2y - (p2y - p1y) * u2x) / cr
        [p1x + t * u1x, p1y + t * u1y]
      end
      if ferme
        (0...n).map { |i| inter.call(seg[i - 1], seg[i]) }
      else
        res = [seg[0][0]]
        (1...(n - 1)).each { |i| res << inter.call(seg[i - 1], seg[i]) }
        (lx, ly), (ux, uy) = seg[-1]
        lsx, lsy = pts[-1].x - pts[-2].x, pts[-1].y - pts[-2].y
        res << [lx + lsx, ly + lsy]
        res
      end
    end

    def self.aire(poly) poly.each_with_index.sum { |(x1, y1), i| x2, y2 = poly[(i + 1) % poly.size]; x1 * y2 - x2 * y1 } / 2.0 end

    # Couches à construire : [type, hauteur (m), décalage gauche, décalage droit (pouces)]
    #  - mur simple : selon le tracé (axe, face gauche, face droite)
    #  - mur composé : le tracé est la face extérieure de la 1re couche, les couches s'empilent du côté choisi
    def self.couches_de(p)
      if p[:couches]
        # 0 : couches à droite du tracé ; 1 : à gauche ; 2 : tracé dans l'axe de l'épaisseur totale (couches de gauche à droite)
        sg = p[:cote] == 1 ? 1.0 : -1.0
        s = p[:cote] == 2 ? -p[:couches].sum { |c| (c[:e] / 100.0).m } / 2.0 : 0.0
        p[:couches].map do |c|
          e = (c[:e] / 100.0).m
          d1, d2 = sg * s, sg * (s + e)
          s += e
          [c[:type], c[:h], [d1, d2].max, [d1, d2].min, c[:e]]
        end
      else
        e = (p[:e] / 100.0).m
        dg, dd = [[e / 2.0, -e / 2.0], [0.0, -e], [e, 0.0]][p[:trace]]
        [[p[:type], p[:h], dg, dd, p[:e]]]
      end
    end

    # Une couche : empreinte entre deux décalages du tracé, extrudée sur la hauteur, dans un groupe sur la balise du type
    def self.construire_couche(pts, ferme, type, hm, dg, dd)
      model = Sketchup.active_model
      z = pts[0].z
      grp = model.active_entities.add_group
      ents = grp.entities
      a = decale(pts, dg, ferme); b = decale(pts, dd, ferme)
      p3 = ->(poly) { poly.map { |x, y| Geom::Point3d.new(x, y, z) } }
      if ferme
        ext, int = aire(a).abs >= aire(b).abs ? [a, b] : [b, a]
        ents.add_face(p3.call(ext))
        trou = ents.add_face(p3.call(int))
        trou.erase! if trou && trou.valid?
        f = ents.grep(Sketchup::Face).max_by(&:area)
      else
        f = ents.add_face(p3.call(a + b.reverse))
      end
      f.reverse! if f.normal.z < 0
      f.pushpull(hm.m)
      l, _ = A2M::Balises.balise(model, type[1], (A2M::Balises::LISTE.find { |n, _, _| n == type[1] } || [])[2])
      grp.layer = l
      num = model.active_entities.grep(Sketchup::Group).count { |g| g.name.start_with?(type[4]) }
      grp.name = "#{type[4]} #{num}"
      grp
    end

    def self.construire(pts, ferme, p)
      model = Sketchup.active_model
      model.start_operation(p[:couches] ? 'Dessiner un mur composé (métré)' : 'Dessiner un mur (métré)', true)
      begin
        noms = couches_de(p).map { |type, hm, dg, dd, ecm| g = construire_couche(pts, ferme, type, hm, dg, dd); "#{g.name} (#{ecm} cm)" }
        model.commit_operation
        Sketchup.status_text = "Créé : #{noms.join(' + ')}"
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Le mur n'a pas pu être créé (#{ex.message}). Vérifiez que le tracé ne se recoupe pas.")
      end
    end

    # ---- Mur composé : nombre de couches, puis type, épaisseur et hauteur de chacune ----
    COTES_COMPOSE = ['à droite du tracé', 'à gauche du tracé', 'dans l\'axe du tracé']
    TAB = 9   # touche Tab : change le côté du mur par rapport au tracé

    # Libellé du côté en cours (barre d'état et texte près du curseur)
    def self.lib_cote(p)
      p[:couches] ? "Couches #{COTES_COMPOSE[p[:cote]]}" : ['Tracé dans l\'axe du mur', 'Mur à droite du tracé', 'Mur à gauche du tracé'][p[:trace]]
    end

    # Tab : axe → à droite → à gauche (mur simple) ; à droite → à gauche → dans l'axe (mur composé). Le choix est retenu.
    def self.cote_suivant(p)
      if p[:couches]
        p[:cote] = (p[:cote] + 1) % 3
        (@reglages[:compose] ||= {})[:cote] = COTES_COMPOSE[p[:cote]]
      else
        p[:trace] = (p[:trace] + 1) % 3
        @reglages[:trace] = TRACES[p[:trace]]
      end
    end

    COMPO_DEFAUT = [['Mur périphérique', 20.0, 2.50], ['Doublage : isolant', 14.0, 2.50], ['Doublage : plaque de plâtre', 1.3, 2.50]]
    def self.lancer_compose
      r = @reglages[:compose] || {}
      rep = UI.inputbox(['Nombre de couches (de l\'extérieur vers l\'intérieur)', 'Le tracé est la face extérieure ; les couches partent'],
                        [(r[:n] || 3).to_s, r[:cote] || 'à droite du tracé'],
                        ['1|2|3|4|5', COTES_COMPOSE.join('|')], 'Mur composé (Métré Atelier 2M)')
      return unless rep
      n = rep[0].to_i
      prec = r[:couches] || []
      lib = []; val = []; lst = []
      n.times do |i|
        d = prec[i] || COMPO_DEFAUT[i] || COMPO_DEFAUT[-1]
        lib += ["Couche #{i + 1} : type", "Couche #{i + 1} : épaisseur (cm)", "Couche #{i + 1} : hauteur (m)"]
        val += [d[0], d[1].to_s, d[2].to_s]
        lst += [TYPES.map(&:first).join('|'), '', '']
      end
      rep2 = UI.inputbox(lib, val, lst, "Mur composé : #{n} couche(s), de l'extérieur vers l'intérieur")
      return unless rep2
      couches = []
      n.times do |i|
        type = TYPES.find { |x| x[0] == rep2[i * 3] }
        e = rep2[i * 3 + 1].to_s.tr(',', '.').to_f; h = rep2[i * 3 + 2].to_s.tr(',', '.').to_f
        return UI.messagebox("Couche #{i + 1} : l'épaisseur et la hauteur doivent être supérieures à 0.") if e <= 0 || h <= 0
        couches << { type: type, e: e, h: h }
      end
      cote = COTES_COMPOSE.index(rep[1]) || 0
      @reglages[:compose] = { n: n, cote: rep[1], couches: couches.map { |c| [c[:type][0], c[:e], c[:h]] } }
      tot = couches.sum { |c| c[:e] }
      p = { couches: couches, cote: cote, type: ['Mur composé'], h: couches.map { |c| c[:h] }.max, e: tot.round(1) }
      Sketchup.active_model.select_tool(Outil.new(p))
    end

    # ---- L'outil : clics successifs ; Entrée ou double-clic termine ; clic sur le premier point ferme le tour ----
    class Outil
      def initialize(p)
        @p = p; @pts = []; @pt = A2M::Pointeur.new
      end

      def activate
        maj_statut
      end

      def maj_statut
        lib = @p[:couches] ? "Mur composé (#{@p[:couches].map { |c| c[:e] }.join(' + ')} cm)" : "#{@p[:type][0]} — h #{@p[:h]} m, ép. #{@p[:e]} cm"
        Sketchup.status_text = "#{lib}, #{A2M::DessinMurs.lib_cote(@p).downcase} (Tab pour changer). Cliquez les points du tracé (accrochages SketchUp) ; tapez une longueur puis Entrée ; " \
                               'Maj = bloquer la direction, flèche droite = axe rouge, flèche gauche = axe vert ; clic sur le 1er point (carré vert) pour fermer ; double-clic ou Entrée pour finir ; Échap pour annuler.'
        Sketchup.vcb_label = 'Longueur'
      end

      def deactivate(view) view.invalidate end
      def resume(view) maj_statut; view.invalidate end

      def onMouseMove(_flags, x, y, view)
        q = @pt.bouger(view, x, y, @pts)
        Sketchup.vcb_value = @pts[-1].distance(q).to_l.to_s if @pts.any?
        view.invalidate
      end

      def onKeyDown(key, rpt, _flags, view)
        if key == A2M::DessinMurs::TAB
          return true if rpt > 1
          A2M::DessinMurs.cote_suivant(@p)
          maj_statut
          view.invalidate
          return true
        end
        @pt.touche_bas(key, rpt, view, @pts)
      end
      def onKeyUp(key, _rpt, _flags, view) @pt.touche_haut(key, view) end

      def ajouter(pt, view, ferme = false)
        pt = Geom::Point3d.new(pt.x, pt.y, @pts.empty? ? pt.z : @pts[0].z)
        if @pts.size >= 3 && (ferme || pt.distance(@pts[0]) < 0.4)   # retour au premier point = tour fermé
          A2M::DessinMurs.construire(@pts.dup, true, @p)
          return reset(view)
        end
        return if @pts.any? && pt.distance(@pts[-1]) < 0.04
        @pts << pt
        @pt.valider
        view.invalidate
      end

      def onLButtonDown(_flags, _x, _y, view)
        ajouter(@pt.pos || @pt.ip.position, view, @pt.ferme?)
      end

      def onLButtonDoubleClick(_flags, _x, _y, view)
        terminer(view)
      end

      def onReturn(view) terminer(view) end

      def onUserText(text, view)
        l = text.to_l rescue nil
        return UI.beep unless l && @pts.any? && @pt.pos
        dir = @pt.pos - @pts[-1]
        return UI.beep if dir.length < 0.001
        dir.length = l
        ajouter(@pts[-1].offset(dir), view)
      end

      def terminer(view)
        if @pts.size >= 2
          A2M::DessinMurs.construire(@pts.dup, false, @p)
        end
        reset(view)
      end

      def reset(view)
        @pts.clear; @pt.vider(view); maj_statut; view.invalidate
      end

      def onCancel(_reason, view)
        @pts.empty? ? Sketchup.active_model.select_tool(nil) : reset(view)
      end

      def draw(view)
        @pt.dessiner(view, @pts, 'orange')
        # Côté en cours, écrit près du curseur
        if @pt.pos
          sp = view.screen_coords(@pt.pos)
          view.draw_text(Geom::Point3d.new(sp.x + 18, sp.y + 14, 0), "#{A2M::DessinMurs.lib_cote(@p)}  (Tab)", color: 'DimGray', size: 10) rescue nil
        end
        return if @pts.empty? || @pt.pos.nil?
        chemin = @pts + [@pt.pos]
        # Aperçu de l'épaisseur
        if chemin[-1].distance(chemin[-2]) > 0.01
          cs = A2M::DessinMurs.couches_de(@p)
          dg = cs.map { |c| c[2] }.max; dd = cs.map { |c| c[3] }.min
          ferme = @pt.ferme?
          ch = ferme ? @pts : chemin
          a = A2M::DessinMurs.decale(ch, dg, ferme); b = A2M::DessinMurs.decale(ch, dd, ferme)
          a << a[0] if ferme; b << b[0] if ferme
          z = chemin[0].z
          view.line_width = 1
          view.drawing_color = 'gray'
          view.draw(GL_LINE_STRIP, a.map { |x, y| Geom::Point3d.new(x, y, z) })
          view.draw(GL_LINE_STRIP, b.map { |x, y| Geom::Point3d.new(x, y, z) })
        end
      end

      def getExtents
        bb = Geom::BoundingBox.new
        @pts.each { |q| bb.add(q) }
        bb.add(@pt.pos) if @pt.pos
        bb
      end
    end
  end
end
