# encoding: UTF-8
# Métré Atelier 2M : tapée d'isolation (habillage de tableau) autour d'une baie.
# Trois côtés seulement (jambages et linteau) : pas de tapée en bas, où il y a le seuil ou l'appui.
# Pièce visuelle : sans balise, donc hors du métré.
require 'sketchup.rb'

module A2M
  module Tapee
    # Épaisseur demandée à l'utilisateur, en cm (0 = pas de tapée)
    def self.demander
      rep = UI.inputbox(['Tapée d\'isolation : épaisseur (cm, 0 = aucune)'], ['3'], 'Tapée d\'isolation')
      return 0.0 unless rep
      (Float(rep[0].to_s.strip.tr(',', '.')) rescue 0.0)
    end

    # Une pièce = un parallélépipède : face dans le plan (vx, vy), puis épaisseur vz
    def self.boite(ents, o, vx, vy, vz)
      f = ents.add_face(o, o + vx, o + vx + vy, o + vy)
      return unless f
      dist = vz.length
      f.pushpull(f.normal.dot(vz) >= 0 ? dist : -dist)
    end

    # o : coin bas-gauche de la baie, côté extérieur ; ur : sens gauche-droite ; n : normale sortante du mur
    # l, h, prof : dimensions de la baie et profondeur du nu intérieur, en pouces (unités SketchUp)
    def self.poser(ents, o, ur, n, l, h, prof, epaisseur_cm)
      t = epaisseur_cm.to_f.cm.to_f
      return nil if epaisseur_cm.to_f <= 0 || prof.to_f <= 0.01
      z = Geom::Vector3d.new(0, 0, 1)
      d = n.reverse.normalize * prof.to_f          # de l'extérieur vers le nu intérieur
      g = ents.add_group
      g.name = 'Tapée d\'isolation'
      haut = h.to_f - t
      boite(g.entities, o, ur * t, z * haut, d)                             # jambage gauche
      boite(g.entities, o + ur * (l.to_f - t), ur * t, z * haut, d)         # jambage droit
      boite(g.entities, o + z * haut, ur * l.to_f, z * t, d)                # linteau
      g
    end
  end
end
