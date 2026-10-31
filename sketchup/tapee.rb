# encoding: UTF-8
# Métré Atelier 2M : tapée d'isolation (habillage de tableau) autour d'une baie.
# Trois côtés seulement (jambages et linteau) : pas de tapée en bas, où il y a le seuil ou l'appui.
# Pièce visuelle : sans balise, donc hors du métré.
require 'sketchup.rb'

module A2M
  module Tapee
    # Épaisseur et profondeur demandées à l'utilisateur, en cm (épaisseur 0 = pas de tapée ; profondeur 0 = égale à l'isolant)
    def self.demander
      rep = UI.inputbox(['Tapée d\'isolation : épaisseur (cm, 0 = aucune)', 'Profondeur de la tapée (cm, 0 = jusqu\'au cadre)'],
                        ['3', '0'], 'Tapée d\'isolation')
      return [0.0, 0.0] unless rep
      ep = (Float(rep[0].to_s.strip.tr(',', '.')) rescue 0.0)
      pr = (Float(rep[1].to_s.strip.tr(',', '.')) rescue 0.0)
      [ep, pr]
    end

    # Vecteur mis à l'échelle k. Écrit composante par composante : vecteur * nombre échoue dans SketchUp 2027.
    def self.mise_a_l_echelle(v, k)
      Geom::Vector3d.new(v.x * k, v.y * k, v.z * k)
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
    # profondeur_cm : 0 = jusqu'au cadre de la menuiserie (prof moins la profondeur du cadre)
    def self.poser(ents, o, ur, n, l, h, prof, epaisseur_cm, profondeur_cm = 0)
      t = epaisseur_cm.to_f.cm.to_f
      return nil if epaisseur_cm.to_f <= 0 || prof.to_f <= 0.01
      # Par défaut la tapée s'arrête à la face extérieure du cadre de la menuiserie (le cadre est posé contre le nu intérieur) :
      # elle ne descend pas jusqu'à la plaque de plâtre
      cadre = A2M::ObjetsMenuiseries::PROF.cm.to_f
      prof_tapee = profondeur_cm.to_f > 0 ? profondeur_cm.to_f.cm.to_f : [prof.to_f - cadre, 0.0].max
      return nil if prof_tapee <= 0.01
      z = Geom::Vector3d.new(0, 0, 1)
      d = mise_a_l_echelle(n.reverse.normalize, prof_tapee)   # de l'extérieur vers l'intérieur
      g = ents.add_group
      g.name = 'Tapée d\'isolation'
      g.set_attribute('a2m', 'tapee', true)   # reconnue par la texture RAL de la menuiserie
      haut = h.to_f - t
      boite(g.entities, o, mise_a_l_echelle(ur, t), mise_a_l_echelle(z, haut), d)                   # jambage gauche
      boite(g.entities, o + mise_a_l_echelle(ur, l.to_f - t), mise_a_l_echelle(ur, t), mise_a_l_echelle(z, haut), d)  # jambage droit
      boite(g.entities, o + mise_a_l_echelle(z, haut), mise_a_l_echelle(ur, l.to_f), mise_a_l_echelle(z, t), d)       # linteau
      g
    end
  end
end
