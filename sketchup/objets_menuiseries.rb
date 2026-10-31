# encoding: UTF-8
# Métré Atelier 2M : génération de menuiseries types pour la bibliothèque (PVC, à la française).
# Dessinées en cm (x = largeur, y = profondeur, 0 = face extérieure, z = hauteur), puis rangées
# comme les objets paramétrés à la main : même fiche, mêmes lignes d'étirement (au milieu des vitrages ou des panneaux).
require 'sketchup.rb'

module A2M
  module ObjetsMenuiseries
    DORMANT = 7.0     # cm : épaisseur du dormant (cadre fixe)
    OUVRANT = 6.0     # cm : épaisseur du cadre de vantail
    VITRE_EP = 2.4    # cm : épaisseur du double vitrage
    PROF = 14.0       # cm : profondeur totale de la menuiserie
    VANTAIL_AV = 4.0  # cm : recul du vantail depuis la face extérieure
    VANTAIL_AP = 10.0 # cm : profondeur du vantail

    # Parallélépipède en cm : x de x0 à x1, y de y0 à y1 (profondeur), z de z0 à z1 (hauteur)
    def self.boite(ents, x0, x1, y0, y1, z0, z1)
      pts = [[x0, y0, z0], [x1, y0, z0], [x1, y0, z1], [x0, y0, z1]].map { |x, y, z| Geom::Point3d.new(x.cm, y.cm, z.cm) }
      f = ents.add_face(pts)
      return unless f
      dist = (y1 - y0).cm
      f.pushpull(f.normal.y < 0 ? -dist : dist)   # on pousse vers le fond (+y)
    end

    def self.dormant(ents, l, h)
      g = ents.add_group
      g.name = 'Dormant'
      e = g.entities
      boite(e, 0, l, 0, PROF, 0, DORMANT)
      boite(e, 0, l, 0, PROF, h - DORMANT, h)
      boite(e, 0, DORMANT, 0, PROF, DORMANT, h - DORMANT)
      boite(e, l - DORMANT, l, 0, PROF, DORMANT, h - DORMANT)
      g
    end

    # Vantail entre xa et xb.
    # bas : nil = vitrage sur toute la hauteur ; :plein = panneau plein ; nombre = hauteur (cm) du bas plein
    #       (panneau ou soubassement, nom_bas), vitrage au-dessus
    def self.vantail(ents, xa, xb, h, nom, bas, poignee_x, nom_bas)
      g = ents.add_group
      g.name = nom
      e = g.entities
      zb = DORMANT
      zt = h - DORMANT
      y0 = VANTAIL_AV
      y1 = VANTAIL_AV + VANTAIL_AP
      boite(e, xa, xb, y0, y1, zb, zb + OUVRANT)
      boite(e, xa, xb, y0, y1, zt - OUVRANT, zt)
      boite(e, xa, xa + OUVRANT, y0, y1, zb, zt)
      boite(e, xb - OUVRANT, xb, y0, y1, zb, zt)
      zi = zb + OUVRANT          # intérieur du cadre, en bas
      zs = zt - OUVRANT          # intérieur du cadre, en haut
      if bas == :plein || (bas.is_a?(Numeric) && bas >= zs - zi)
        pan = e.add_group
        pan.name = 'Panneau'
        boite(pan.entities, xa + OUVRANT, xb - OUVRANT, y0 + 1, y1 - 1, zi, zs)
      else
        zv = zi
        if bas.is_a?(Numeric) && bas > 0
          sol = e.add_group
          sol.name = nom_bas
          boite(sol.entities, xa + OUVRANT, xb - OUVRANT, y0 + 1, y1 - 1, zi, zi + bas)
          zv = zi + bas
        end
        vit = e.add_group
        vit.name = 'Vitrage'
        boite(vit.entities, xa + OUVRANT, xb - OUVRANT, y0 + 2, y0 + 2 + VITRE_EP, zv, zs)
      end
      # Poignée : petite pièce sur la face extérieure, à 1 m environ du sol
      pog = e.add_group
      pog.name = 'Poignée'
      boite(pog.entities, poignee_x - 1.5, poignee_x + 1.5, -3, y0, 95, 102)
      g
    end

    # Sommets de l'objet en pouces (même lecture que le paramétrage, pour calculer les lignes d'étirement)
    def self.sommets(ents, tr, sortie = [])
      ents.each do |e|
        case e
        when Sketchup::Face then e.vertices.each { |v| sortie << v.position.transform(tr) }
        when Sketchup::Group then sommets(e.entities, tr * e.transformation, sortie)
        when Sketchup::ComponentInstance then sommets(e.definition.entities, tr * e.transformation, sortie)
        end
      end
      sortie
    end

    def self.construire(model, nom, type_nom, l, h, vantaux, choix, bas, nom_bas)
      type = A2M::Bibliotheque::TYPES.find { |t| t[0] == type_nom }
      raise "Type inconnu : #{type_nom}" unless type
      d = model.definitions.add(nom)
      ents = d.entities
      dormant(ents, l, h)
      if vantaux == 1
        vantail(ents, DORMANT, l - DORMANT, h, 'Vantail', bas, l - DORMANT - OUVRANT - 4, nom_bas)
      else
        m = l / 2.0
        vantail(ents, DORMANT, m, h, 'Vantail gauche', bas, m - OUVRANT - 4, nom_bas)
        vantail(ents, m, l - DORMANT, h, 'Vantail droit', bas, m + OUVRANT + 4, nom_bas)
      end
      pts = sommets(ents, Geom::Transformation.new)
      xs = pts.map(&:x)
      zs = pts.map(&:z)
      # Lignes d'étirement : au milieu de chaque vantail, à travers le vitrage ou le panneau, jamais sur la poignée
      positions_x = vantaux == 1 ? [l / 2.0] : [l * 0.25, l * 0.75]
      positions_z = [h / 2.0]
      lx = A2M::Etirement.lignes_depuis(positions_x.map { |c| c.cm.to_f }, xs)
      lz = A2M::Etirement.lignes_depuis(positions_z.map { |c| c.cm.to_f }, zs)
      info = { 'nom' => nom, 'type' => type[0], 'balise' => type[1], 'vantaux' => vantaux, 'choix' => choix,
               'l0' => l.cm.to_f, 'h0' => h.cm.to_f, 'p0' => PROF.cm.to_f, 'lx' => lx, 'lz' => lz, 'version' => 1 }
      A2M::Bibliotheque.ranger(d, type, nom, info)
    end

    PF = 'Porte-fenêtre, baie ou coulissant'
    PE = 'Porte d\'entrée'

    # [nom, type, largeur, hauteur, vantaux, choix, bas, nom du bas]
    MODELES = [
      ['Porte-fenêtre 1 vantail PVC 90 × 215 (à la française)', PF, 90, 215, 1, { 'mat' => 'pvc', 'vantaux' => '1', 'ouvrant' => 'francaise', 'vitrage' => 'double' }, nil, nil],
      ['Porte-fenêtre 2 vantaux PVC 140 × 215 (à la française)', PF, 140, 215, 2, { 'mat' => 'pvc', 'vantaux' => '2', 'ouvrant' => 'francaise', 'vitrage' => 'double' }, nil, nil],
      ['Porte-fenêtre 1 vantail PVC 90 × 215 avec soubassement 40 cm', PF, 90, 215, 1, { 'mat' => 'pvc', 'vantaux' => '1', 'ouvrant' => 'francaise', 'vitrage' => 'double' }, 40, 'Soubassement'],
      ['Porte-fenêtre 2 vantaux PVC 140 × 215 avec soubassement 40 cm', PF, 140, 215, 2, { 'mat' => 'pvc', 'vantaux' => '2', 'ouvrant' => 'francaise', 'vitrage' => 'double' }, 40, 'Soubassement'],
      ['Porte d\'entrée 1 vantail PVC 90 × 215 (à la française)', PE, 90, 215, 1, { 'mat' => 'pvc', 'vantaux' => '1' }, :plein, 'Panneau'],
      ['Porte d\'entrée 1 vantail PVC 90 × 215 vitrage haut', PE, 90, 215, 1, { 'mat' => 'pvc', 'vantaux' => '1' }, 120, 'Panneau'],
      ['Porte d\'entrée 2 vantaux PVC 140 × 215 (à la française)', PE, 140, 215, 2, { 'mat' => 'pvc', 'vantaux' => '2' }, :plein, 'Panneau'],
      ['Porte d\'entrée 2 vantaux PVC 140 × 215 vitrage haut', PE, 140, 215, 2, { 'mat' => 'pvc', 'vantaux' => '2' }, 120, 'Panneau']
    ].freeze

    # Portes d'entrée à un vantail, d'après six styles courants : panneau plein ou lames, une ou plusieurs baies.
    # vitres : zones vitrées en fractions de la surface intérieure (x0, x1, z0, z1), poignee : 'gauche', 'droite' ou 'centre'
    STYLES = [
      ['Porte d\'entrée 1 vantail bois, lames horizontales 90 × 215', 'bois', { lames: 12.0, vitres: [], poignee: 'gauche' }],
      ['Porte d\'entrée 1 vantail alu bleue, baie verticale à droite 90 × 215', 'alu', { lames: nil, vitres: [[0.55, 0.78, 0.25, 0.85]], poignee: 'droite' }],
      ['Porte d\'entrée 1 vantail alu grise, baie verticale à gauche 90 × 215', 'alu', { lames: nil, vitres: [[0.2, 0.42, 0.2, 0.9]], poignee: 'droite' }],
      ['Porte d\'entrée 1 vantail PVC vert, vitrage haut 90 × 215', 'pvc', { lames: nil, vitres: [[0.12, 0.88, 0.55, 0.92]], poignee: 'centre' }],
      ['Porte d\'entrée 1 vantail alu anthracite, lames fines 90 × 215', 'alu', { lames: 9.0, vitres: [], poignee: 'droite' }],
      ['Porte d\'entrée 1 vantail alu gris clair, grande baie 90 × 215', 'alu', { lames: nil, vitres: [[0.15, 0.75, 0.08, 0.92]], poignee: 'droite' }]
    ].freeze

    # Une porte à un vantail, dessinée d'après un style de STYLES
    def self.porte_style(model, nom, mat, cfg)
      type = A2M::Bibliotheque::TYPES.find { |t| t[0] == PE }
      l = 90.0
      h = 215.0
      d = model.definitions.add(nom)
      ents = d.entities
      dormant(ents, l, h)
      xi = DORMANT + OUVRANT
      xf = l - DORMANT - OUVRANT
      zi = DORMANT + OUVRANT
      zs = h - DORMANT - OUVRANT
      y0 = VANTAIL_AV
      y1 = VANTAIL_AV + VANTAIL_AP
      vf = ents.add_group
      vf.name = 'Vantail'
      e = vf.entities
      boite(e, DORMANT, l - DORMANT, y0, y1, DORMANT, DORMANT + OUVRANT)
      boite(e, DORMANT, l - DORMANT, y0, y1, h - DORMANT - OUVRANT, h - DORMANT)
      boite(e, DORMANT, DORMANT + OUVRANT, y0, y1, DORMANT, h - DORMANT)
      boite(e, l - DORMANT - OUVRANT, l - DORMANT, y0, y1, DORMANT, h - DORMANT)
      # Panneau : plein, ou en lames horizontales séparées par un petit joint
      pan = e.add_group
      pan.name = 'Panneau'
      if cfg[:lames]
        bh = cfg[:lames]
        z = zi
        while z + bh <= zs + 0.01
          boite(pan.entities, xi, xf, y0 + VITRE_EP, y1 - 1, z, z + bh - 0.6)
          z += bh
        end
      else
        boite(pan.entities, xi, xf, y0 + VITRE_EP, y1 - 1, zi, zs)
      end
      # Vitrages, devant le panneau
      cfg[:vitres].each do |fx0, fx1, fz0, fz1|
        vit = e.add_group
        vit.name = 'Vitrage'
        boite(vit.entities, xi + fx0 * (xf - xi), xi + fx1 * (xf - xi), y0, y0 + VITRE_EP,
              zi + fz0 * (zs - zi), zi + fz1 * (zs - zi))
      end
      # Poignée
      px = { 'droite' => xf - 4.0, 'gauche' => xi + 4.0, 'centre' => l / 2.0 }[cfg[:poignee]]
      pog = e.add_group
      pog.name = 'Poignée'
      boite(pog.entities, px - 1.5, px + 1.5, -3, y0, 95, 102)
      pts = sommets(ents, Geom::Transformation.new)
      lx = A2M::Etirement.lignes_depuis([(l / 2.0).cm.to_f], pts.map(&:x))
      lz = A2M::Etirement.lignes_depuis([(h / 2.0).cm.to_f], pts.map(&:z))
      choix = { 'mat' => mat, 'vantaux' => '1' }
      info = { 'nom' => nom, 'type' => type[0], 'balise' => type[1], 'vantaux' => 1, 'choix' => choix,
               'l0' => l.cm.to_f, 'h0' => h.cm.to_f, 'p0' => PROF.cm.to_f, 'lx' => lx, 'lz' => lz, 'version' => 1 }
      A2M::Bibliotheque.ranger(d, type, nom, info)
    end

    def self.creer
      model = Sketchup.active_model
      resultats = []
      model.start_operation('Créer les menuiseries types', true)
      begin
        MODELES.each do |nom, type, l, h, vant, choix, bas, nom_bas|
          resultats << construire(model, nom, type, l, h, vant, choix, bas, nom_bas)
        end
        STYLES.each { |nom, mat, cfg| resultats << porte_style(model, nom, mat, cfg) }
        model.commit_operation
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Création interrompue : #{ex.message}")
        return
      end
      UI.messagebox("Menuiseries types rangées dans la bibliothèque :\n\n" + resultats.map(&:to_s).join("\n"))
    end
  end
end
