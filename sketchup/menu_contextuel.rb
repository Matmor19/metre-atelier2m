# encoding: UTF-8
# Métré Atelier 2M : menu clic droit sur les portes (charnière gauche ↔ droite, ouvrir de l'autre côté du mur)
require 'sketchup.rb'
require 'json'

module A2M
  module MenuContextuel
    TAGS = %w[A2M_PORTE_INT A2M_PORTE_ENTREE A2M_PORTE_FENETRE].freeze

    def self.portes(sel)
      sel.select { |e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && TAGS.include?(e.layer.name) }
    end

    def self.sens(e)
      s = (JSON.parse(e.get_attribute('a2m', 'sens').to_s) rescue nil)
      s.is_a?(Array) && s.size == 2 ? s : ['ici', 'gauche']
    end

    # Axe horizontal de la largeur de la porte (le long du mur) et centre, en repère du parent
    def self.axes(e)
      t = e.transformation
      # Porte de la bibliothèque posée par l'outil : on pivote ou on retourne autour du milieu du CORPS du cadre, calculé comme à la
      # pose (PortesInt.transfo). L'origine de l'objet n'est PAS ce milieu (elle peut en être loin d'un mètre) et la boîte englobante
      # compte la poignée d'un seul côté : tourner autour de l'une ou de l'autre faisait sortir la porte de la cloison.
      # L'axe x de l'objet posé est toujours le long du mur (repère donné à la pose).
      # Reconnaissance : marque « a2m / sens » donnée par l'outil Porte intérieure (PortesInt.poser), ou objet de la bibliothèque.
      # Sans cela, la boîte englobante compterait aussi l'arc d'ouverture dessiné au sol, et le centre serait faux.
      if e.is_a?(Sketchup::ComponentInstance) && (e.get_attribute('a2m', 'sens') || e.get_attribute('a2m_biblio', 'fichier'))
        d = e.definition
        cf = (A2M::PortesInt.corps_faces(d.entities, Geom::Transformation.new) rescue nil)
        if cf
          xm = cf[:xc] / 2.54; ym = cf[:yc] / 2.54
        else
          bv = A2M::Bibliotheque.boite_visible(d)
          xm = bv.center.x; ym = bv.center.y
        end
        c = t * Geom::Point3d.new(xm, ym, 0)
        ax = Geom::Vector3d.new(t.xaxis.x, t.xaxis.y, 0)
        return [c, ax.length > 0.001 ? ax.normalize : Geom::Vector3d.new(1, 0, 0)]
      end
      bb = e.bounds
      c = bb.center
      bl = (e.is_a?(Sketchup::Group) ? e.entities.parent : e.definition).bounds
      wx = bl.width * t.xscale; wy = bl.height * t.yscale
      ax = wx >= wy ? t.xaxis : t.yaxis
      ax = Geom::Vector3d.new(ax.x, ax.y, 0)
      ax = ax.length > 0.001 ? ax.normalize : Geom::Vector3d.new(1, 0, 0)
      [c, ax]
    end

    # Porte posée par l'outil (ou objet de la bibliothèque) : composant, souvent dynamique
    def self.porte_outil?(e)
      e.is_a?(Sketchup::ComponentInstance) && (e.get_attribute('a2m', 'sens') || e.get_attribute('a2m_biblio', 'fichier'))
    end

    # Milieu du corps du cadre dans le repère de l'objet (pouces), comme à la pose
    def self.centre_local(d)
      cf = (A2M::PortesInt.corps_faces(d.entities, Geom::Transformation.new) rescue nil)
      return [cf[:xc] / 2.54, cf[:yc] / 2.54] if cf
      bv = A2M::Bibliotheque.boite_visible(d)
      [bv.center.x, bv.center.y]
    end

    DA = 'dynamic_attributes'.freeze

    # Pièces animées au clic (vantail d'une porte dynamique : onclick = ANIMATE(...)), sans descendre dans leur contenu
    def self.animes(ents)
      ents.flat_map do |x|
        if x.is_a?(Sketchup::ComponentInstance) && [x, x.definition].any? { |o| o.get_attribute(DA, 'onclick').to_s =~ /ANIMATE/i }
          [x]
        elsif x.is_a?(Sketchup::Group) || x.is_a?(Sketchup::ComponentInstance)
          animes(x.definition.entities)
        else
          []
        end
      end
    end

    def self.retournee?(t)
      a = t.to_a
      (a[0] * (a[5] * a[10] - a[6] * a[9]) - a[4] * (a[1] * a[10] - a[2] * a[9]) + a[8] * (a[1] * a[6] - a[2] * a[5])) < 0
    end

    # ANIMATE("RotZ",0,-45,-90) -> ANIMATE("RotZ",0,45,90) : le vantail retourné tourne dans l'autre sens
    def self.inverser_rotz(txt)
      txt.to_s.gsub(/(ANIMATE\w*\(\s*"rotz"\s*,)([^)]*)\)/i) do
        debut = Regexp.last_match(1)
        vals = Regexp.last_match(2).split(',').map do |v|
          s = v.strip
          next v unless s =~ /\A-?\d+(\.\d+)?\z/
          s.start_with?('-') ? s[1..] : (s.to_f.zero? ? s : "-#{s}")
        end
        "#{debut}#{vals.join(',')})"
      end
    end

    # Vantail animé retourné en miroir par le changement de charnière : l'extension Composants dynamiques perd ce retournement
    # dès la première animation (le vantail repart de travers). On remet donc la pièce à l'endroit (déterminant positif), on
    # retourne son contenu dans son propre repère (autour de son origine = l'axe des paumelles), et on inverse le sens de RotZ.
    def self.redresser(p)
      return unless retournee?(p.transformation)
      p.make_unique if p.definition.count_instances > 1
      s = Geom::Transformation.scaling(-1, 1, 1)
      p.definition.entities.transform_entities(s, p.definition.entities.to_a)
      p.transformation = p.transformation * s
      [p, p.definition].each do |o|
        oc = o.get_attribute(DA, 'onclick')
        o.set_attribute(DA, 'onclick', inverser_rotz(oc)) if oc
        rz = o.get_attribute(DA, 'rotz')
        o.set_attribute(DA, 'rotz', (-rz.to_f).to_s) if rz && rz.to_f != 0
      end
    end

    def self.miroir(e)
      if porte_outil?(e)
        # Le miroir est fait sur le CONTENU de la porte (autour du milieu du cadre, le long de sa largeur), pas sur la porte :
        # un composant dynamique retourné en miroir est redessiné par l'extension Composants dynamiques, qui le recale sur sa
        # boîte englobante (arc d'ouverture compris) et le fait sortir de la cloison. Ici la porte garde sa place.
        e.make_unique if e.definition.count_instances > 1
        d = e.definition
        xm, _ym = centre_local(d)
        m = Geom::Transformation.translation(Geom::Vector3d.new(xm, 0, 0)) * Geom::Transformation.scaling(-1, 1, 1) *
            Geom::Transformation.translation(Geom::Vector3d.new(-xm, 0, 0))
        d.entities.transform_entities(m, d.entities.to_a)
        animes(d.entities).each { |p| redresser(p) }
        return
      end
      c, n = axes(e)
      m = [1 - 2 * n.x * n.x, -2 * n.y * n.x, 0, 0,
           -2 * n.x * n.y, 1 - 2 * n.y * n.y, 0, 0,
           0, 0, 1, 0, 0, 0, 0, 1]
      d = n.x * c.x + n.y * c.y
      m[12] = 2 * d * n.x; m[13] = 2 * d * n.y
      e.transform!(Geom::Transformation.new(m))
    end

    # Vantail animé tourné d'un demi-tour avec le contenu de la porte : on garde son origine (axe des paumelles) et on remet
    # ses axes droits, le demi-tour passant dans son contenu. L'extension Composants dynamiques recalcule RotZ à partir des
    # axes de la pièce : sans cela l'animation repartirait de l'ancienne orientation.
    def self.aplanir(p)
      t = p.transformation
      return if retournee?(t)
      # On garde l'ouverture en cours (RotZ, en degrés, sens trigonométrique) : la porte peut être ouverte à 45° ou 90°
      # au moment du changement. Effacer cet angle décalait toute l'animation (ouverture à 90°, demi-tour, plus de fermeture).
      rz = [p, p.definition].map { |o| o.get_attribute(DA, 'rotz') }.compact.first.to_f
      cible = Geom::Transformation.translation(Geom::Vector3d.new(t.origin.to_a)) * Geom::Transformation.rotation(ORIGIN, Z_AXIS, rz.degrees)
      q = cible.inverse * t
      p.make_unique if p.definition.count_instances > 1
      p.definition.entities.transform_entities(q, p.definition.entities.to_a)
      p.transformation = cible
    end

    def self.tourner(e)
      if porte_outil?(e)
        # Demi-tour du CONTENU autour du milieu du cadre (même raison que pour le miroir : la porte elle-même ne bouge pas,
        # l'extension Composants dynamiques n'a rien à recaler)
        e.make_unique if e.definition.count_instances > 1
        d = e.definition
        xm, ym = centre_local(d)
        r = Geom::Transformation.rotation(Geom::Point3d.new(xm, ym, 0), Z_AXIS, Math::PI)
        d.entities.transform_entities(r, d.entities.to_a)
        animes(d.entities).each { |p| aplanir(p) }
        return
      end
      c, _ = axes(e)
      e.transform!(Geom::Transformation.rotation(Geom::Point3d.new(c.x, c.y, 0), Z_AXIS, Math::PI))
    end

    def self.maj_nom(e, s)
      bp = (JSON.parse(e.get_attribute('a2m', 'bp').to_s) rescue nil)
      return unless bp.is_a?(Hash)
      bp['pousse'] = "poussant #{s[1] == 'droite' ? 'droit' : 'gauche'}"
      e.set_attribute('a2m', 'bp', JSON.generate(bp))
      e.name = e.name.sub(/poussant (droit|gauche)/, bp['pousse'])
    end

    def self.agir(quoi)
      model = Sketchup.active_model
      lst = portes(model.selection.to_a)
      return if lst.empty?
      model.start_operation(quoi == :charniere ? 'Charnière de l’autre côté' : 'Ouvrir de l’autre côté du mur', true)
      begin
        lst.each do |e|
          s = sens(e)
          if quoi == :charniere
            miroir(e)
            s[1] = s[1] == 'droite' ? 'gauche' : 'droite'
          else
            tourner(e)
            s[0] = s[0] == 'ici' ? 'la' : 'ici'
          end
          e.set_attribute('a2m', 'sens', JSON.generate([s[0], s[1]]))
          maj_nom(e, s)
        end
        A2M::Plan2D.rafraichir rescue nil
        model.commit_operation
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Modification impossible : #{ex.message}")
      end
    end

    # Objets de la bibliothèque (ou leur image 2D sur le plan) : choix de l'image 2D du plan (couleur ou blanche)
    def self.objets_biblio(sel)
      m = Sketchup.active_model
      sel.map do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        # image 2D du plan : on agit sur l'objet qu'elle représente
        e = m.find_entity_by_persistent_id(e.get_attribute('a2m_biblio', 'source').to_i) if e.get_attribute('a2m_biblio', 'jumeau')
        e if e && e.valid? && e.get_attribute('a2m_biblio', 'fichier')
      end.compact.uniq
    end

    def self.choisir_2d(lst, version)
      model = Sketchup.active_model
      model.start_operation('Image 2D de l\'objet', true)
      begin
        lst.each { |e| e.set_attribute('a2m_biblio', 'vue2d', version) }
        A2M::Plan2D.rafraichir rescue nil
        model.commit_operation
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Modification impossible : #{ex.message}")
      end
    end

    def self.installer
      return if @ok
      @ok = true
      UI.add_context_menu_handler do |menu|
        mur = Sketchup.active_model.selection.to_a.find { |e| e.respond_to?(:get_attribute) && e.get_attribute('a2m_mur', 'id') }
        if mur
          menu.add_separator
          menu.add_item('Atelier 2M : modifier ce mur') { A2M::DessinMurs.modifier(mur) }
        end
        ouv = Sketchup.active_model.selection.to_a.find { |e| A2M::Suivi.suivie?(e) }
        if ouv
          menu.add_separator
          menu.add_item('Atelier 2M : modifier cette ouverture') { A2M::Ouvertures.modifier(ouv) }
        end
        autre = Sketchup.active_model.selection.to_a.find { |e| %i[sol solmur escalier garde_corps couverture charpente zinguerie semelle ferraillage].include?(A2M::Modif.genre(e)) }
        if autre
          menu.add_separator
          menu.add_item('Atelier 2M : modifier cet objet') { A2M::Modif.modifier(autre) }
        end
        toit = Sketchup.active_model.selection.to_a.find { |e| e.respond_to?(:get_attribute) && e.get_attribute('a2m_toiture', 'base') }
        if toit
          menu.add_separator
          menu.add_item('Atelier 2M : modifier cette toiture') { A2M::Toiture.modifier(toit) }
        end
        ob = objets_biblio(Sketchup.active_model.selection.to_a)
        unless ob.empty?
          menu.add_separator
          sous = menu.add_submenu('Atelier 2M : image 2D du plan')
          actuel = ob.map { |e| e.get_attribute('a2m_biblio', 'vue2d') == 'blanc' ? 'blanc' : 'couleur' }.uniq
          sous.add_item((actuel == ['couleur'] ? '✓ ' : '') + 'Version couleur') { choisir_2d(ob, 'couleur') }
          sous.add_item((actuel == ['blanc'] ? '✓ ' : '') + 'Version blanche') { choisir_2d(ob, 'blanc') }
        end
        # Sur le plan, l'image couvre l'objet : un clic droit tombe sur le groupe des symboles 2D → toutes les images d'un coup
        if Sketchup.active_model.selection.any? { |e| e.is_a?(Sketchup::Group) && e.name.to_s.start_with?('Symboles 2D') }
          tous = []
          A2M::Plan2D.parcourir(Sketchup.active_model.entities, Geom::Transformation.new) { |e, _t| tous << e if e.get_attribute('a2m_biblio', 'fichier') }
          unless tous.empty?
            menu.add_separator
            sous = menu.add_submenu('Atelier 2M : objets sur le plan')
            sous.add_item('Tous en version couleur') { choisir_2d(tous, 'couleur') }
            sous.add_item('Tous en version blanche') { choisir_2d(tous, 'blanc') }
          end
        end
        lst = portes(Sketchup.active_model.selection.to_a)
        next if lst.empty?
        menu.add_separator
        sous = menu.add_submenu('Atelier 2M : porte')
        sous.add_item('Charnière gauche ↔ droite') { agir(:charniere) }
        sous.add_item('Ouvrir de l’autre côté du mur') { agir(:cote) }
      end
    end
  end
end
A2M::MenuContextuel.installer
