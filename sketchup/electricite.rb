# encoding: UTF-8
# Métré Atelier 2M : appareillage électrique posé dans le modèle et compté pièce par pièce
require 'sketchup.rb'

module A2M
  module Electricite
    BALISE = 'A2M_ELEC'
    # Mêmes clés que l'appareillage des pièces du configurateur
    APPAREILS = [
      ['prises', 'Prise de courant'], ['points', 'Point lumineux'], ['interrup', 'Interrupteur simple allumage'],
      ['vv', 'Interrupteur va-et-vient'], ['rj45', 'Prise RJ45'], ['tv', 'Prise TV'], ['hotte', 'Prise hotte'],
      ['rasoir', 'Prise rasoir'], ['plaque', 'Plaque de cuisson (32 A)'], ['four', 'Four (16 A)'],
      ['lvaisselle', 'Lave-vaisselle (16 A)'], ['llinge', 'Lave-linge (16 A)'], ['sechelinge', 'Sèche-linge (16 A)'], ['chauffeau', 'Chauffe-eau (20 A)']
    ]
    COULEURS = { 'prises' => [224, 120, 56], 'points' => [255, 210, 60], 'interrup' => [60, 60, 60], 'vv' => [110, 110, 110], 'rj45' => [60, 120, 200], 'tv' => [60, 160, 200] }
    @r = {}

    def self.lancer
      pcs = A2M::Ouvertures.pieces_du_modele
      rep = UI.inputbox(['Appareil', 'Pièce', 'Hauteur de pose (cm)'],
                        [@r[:app] || APPAREILS[0][1], @r[:piece] || A2M::Ouvertures::AUTO, (@r[:h] || 30).to_s],
                        [APPAREILS.map(&:last).join('|'), ([A2M::Ouvertures::AUTO] + pcs).join('|'), ''], 'Appareillage électrique (Métré Atelier 2M)')
      return unless rep
      cle = APPAREILS.find { |_, l| l == rep[0] }[0]
      @r = { app: rep[0], piece: rep[1], h: rep[2].tr(',', '.').to_f }
      piece = rep[1] == A2M::Ouvertures::AUTO ? nil : rep[1]
      Sketchup.active_model.select_tool(Outil.new(cle, rep[0], piece, @r[:h]))
    end

    # Repère posé : petit cube balisé, avec l'appareil et la pièce enregistrés dessus
    def self.poser(pt, cle, lib, piece, hcm)
      model = Sketchup.active_model
      model.start_operation('Appareillage (métré)', true)
      c = 4.cm
      base = Geom::Point3d.new(pt.x, pt.y, pt.z + (hcm / 100.0).m)
      g = model.active_entities.add_group
      f = g.entities.add_face([base.offset(X_AXIS, -c).offset(Y_AXIS, -c), base.offset(X_AXIS, c).offset(Y_AXIS, -c), base.offset(X_AXIS, c).offset(Y_AXIS, c), base.offset(X_AXIS, -c).offset(Y_AXIS, c)])
      f.reverse! if f.normal.z < 0
      f.pushpull(2 * c)
      mat = model.materials["A2M #{cle}"] || model.materials.add("A2M #{cle}")
      mat.color = Sketchup::Color.new(*(COULEURS[cle] || [150, 90, 200]))
      g.material = mat
      lb, _ = A2M::Balises.balise(model, BALISE, [224, 120, 56])
      g.layer = lb
      g.name = "#{lib}#{piece ? ' – ' + piece : ''}"
      g.set_attribute('a2m', 'app', cle)
      g.set_attribute('a2m', 'piece', piece) if piece
      model.commit_operation
    end

    class Outil
      def initialize(cle, lib, piece, h) @cle, @lib, @piece, @h = cle, lib, piece, h; @ip = Sketchup::InputPoint.new; @n = 0 end
      def activate() statut end
      def resume(view) statut end
      def statut
        Sketchup.status_text = "#{@lib}#{@piece ? ' (' + @piece + ')' : ''} : cliquez au sol à chaque emplacement (#{@n} posé(s)). Échap pour terminer."
      end
      def onMouseMove(_f, x, y, view) @ip.pick(view, x, y); view.invalidate end
      def onLButtonDown(_f, _x, _y, view)
        A2M::Electricite.poser(@ip.position, @cle, @lib, @piece, @h)
        @n += 1; statut; view.invalidate
      end
      def onCancel(_r, _v) Sketchup.active_model.select_tool(nil) end
      def draw(view) @ip.draw(view) if @ip.display? end
    end
  end
end
