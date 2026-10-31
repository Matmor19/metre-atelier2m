# encoding: UTF-8
# Métré Atelier 2M : génération de menuiseries types pour la bibliothèque.
# Porte-fenêtre 1 vantail, porte-fenêtre 2 vantaux, porte d'entrée 1 vantail, à la française, en PVC.
# Dessinées ici en cm (x = largeur, y = profondeur, 0 = face extérieure, z = hauteur), puis rangées
# comme les objets paramétrés à la main : même fiche, mêmes lignes d'étirement (au milieu des vitrages ou du panneau).
require 'sketchup.rb'

module A2M
  module ObjetsMenuiseries
    DORMANT = 7.0     # cm : épaisseur du dormant (cadre fixe)
    OUVRANT = 6.0     # cm : épaisseur du cadre de vantail
    VITRE_EP = 2.4    # cm : épaisseur du double vitrage
    PROF = 14.0       # cm : profondeur totale de la menuiserie
    VANTAIL_AV = 4.0  # cm : recul du vantail depuis la face extérieure
    VANTAIL_AP = 10.0 # cm : profondeur du vantail

    # Parallélépipède : x de x0 à x1, y de y0 à y1 (profondeur), z de z0 à z1 (hauteur), en cm
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

    # Vantail entre xa et xb. panneau = true : porte pleine, false : cadre + vitrage
    # poignee_x : position de la poignée (côté de la fermeture)
    def self.vantail(ents, xa, xb, h, nom, panneau, poignee_x)
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
      if panneau
        pan = e.add_group
        pan.name = 'Panneau'
        boite(pan.entities, xa + OUVRANT, xb - OUVRANT, y0 + 1, y1 - 1, zb + OUVRANT, zt - OUVRANT)
      else
        vit = e.add_group
        vit.name = 'Vitrage'
        boite(vit.entities, xa + OUVRANT, xb - OUVRANT, y0 + 2, y0 + 2 + VITRE_EP, zb + OUVRANT, zt - OUVRANT)
      end
      # Poignée : petite pièce sur la face extérieure, à 1 m environ du sol
      pog = e.add_group
      pog.name = 'Poignée'
      boite(pog.entities, poignee_x - 1.5, poignee_x + 1.5, -3, y0, 95, 102)
      g
    end

    # Positions des lignes d'étirement, en pouces, lues sur les sommets de l'objet (même calcul que le paramétrage)
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

    def self.construire(model, nom, type_nom, l, h, vantaux, choix, panneau)
      type = A2M::Bibliotheque::TYPES.find { |t| t[0] == type_nom }
      raise "Type inconnu : #{type_nom}" unless type
      d = model.definitions.add(nom)
      ents = d.entities
      dormant(ents, l, h)
      if vantaux == 1
        vantail(ents, DORMANT, l - DORMANT, h, 'Vantail', panneau, l - DORMANT - OUVRANT - 4)
      else
        m = l / 2.0
        vantail(ents, DORMANT, m, h, 'Vantail gauche', panneau, m - OUVRANT - 4)
        vantail(ents, m, l - DORMANT, h, 'Vantail droit', panneau, m + OUVRANT + 4)
      end
      pts = sommets(ents, Geom::Transformation.new)
      xs = pts.map(&:x)
      zs = pts.map(&:z)
      # Lignes d'étirement : au milieu de chaque vantail (à travers le vitrage ou le panneau), jamais sur la poignée
      positions_x = vantaux == 1 ? [l / 2.0] : [l * 0.25, l * 0.75]
      positions_z = [h / 2.0]
      lx = A2M::Etirement.lignes_depuis(positions_x.map { |c| c.cm.to_f }, xs)
      lz = A2M::Etirement.lignes_depuis(positions_z.map { |c| c.cm.to_f }, zs)
      info = { 'nom' => nom, 'type' => type[0], 'balise' => type[1], 'vantaux' => vantaux, 'choix' => choix,
               'l0' => l.cm.to_f, 'h0' => h.cm.to_f, 'p0' => PROF.cm.to_f, 'lx' => lx, 'lz' => lz, 'version' => 1 }
      A2M::Bibliotheque.ranger(d, type, nom, info)
    end

    def self.creer
      model = Sketchup.active_model
      resultats = []
      model.start_operation('Créer les menuiseries types', true)
      begin
        resultats << construire(model, 'Porte-fenêtre 1 vantail PVC 90 × 215 (à la française)', 'Porte-fenêtre, baie ou coulissant',
                                90, 215, 1, { 'mat' => 'pvc', 'vantaux' => '1', 'ouvrant' => 'francaise', 'vitrage' => 'double' }, false)
        resultats << construire(model, 'Porte-fenêtre 2 vantaux PVC 140 × 215 (à la française)', 'Porte-fenêtre, baie ou coulissant',
                                140, 215, 2, { 'mat' => 'pvc', 'vantaux' => '2', 'ouvrant' => 'francaise', 'vitrage' => 'double' }, false)
        resultats << construire(model, 'Porte d\'entrée 1 vantail PVC 90 × 215 (à la française)', 'Porte d\'entrée',
                                90, 215, 1, { 'mat' => 'pvc', 'vantaux' => '1' }, true)
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
