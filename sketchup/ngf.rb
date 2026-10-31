# encoding: UTF-8
# Métré Atelier 2M : altitudes NGF. Le modèle n'est pas déplacé : on enregistre seulement
# l'altitude NGF de son origine (point 0,0,0), puis les cotes NGF sont calculées à partir de là.
require 'sketchup.rb'

module A2M
  module Ngf
    DICO = 'A2M_NGF'

    # Altitude NGF de l'origine du modèle (mètres), ou nil si pas encore recalé
    def self.origine(model = Sketchup.active_model)
      valeur = model.get_attribute(DICO, 'origine_ngf', nil)
      valeur.nil? ? nil : valeur.to_f
    end

    # Une seule saisie : l'altitude NGF de l'origine du modèle
    def self.recaler
      model = Sketchup.active_model
      actuel = origine
      defaut = actuel ? format('%.2f', actuel).tr('.', ',') : ''
      res = UI.inputbox(['Altitude NGF de l\'origine du modèle (m) :'], [defaut], 'Recaler le NGF')
      return unless res
      valeur = Float(res[0].to_s.strip.tr(',', '.')) rescue nil
      if valeur.nil?
        UI.messagebox('Valeur non reconnue : entrez un nombre, par exemple 112,35.')
        return
      end
      model.start_operation('Recaler le NGF', true)
      model.set_attribute(DICO, 'origine_ngf', valeur)
      model.commit_operation
      UI.messagebox(format('Modèle recalé : origine à %.2f m NGF.', valeur).tr('.', ','))
    end

    # Texte de cote pour un point (coordonnée Z en pouces SketchUp), ou nil si pas recalé
    def self.texte(z_pouces, model = Sketchup.active_model)
      base = origine(model)
      return nil unless base
      format('NGF %.2f', base + z_pouces.to_m).tr('.', ',')
    end

    # Outil : on clique un point, la cote NGF est posée dessus. Échap ou clic droit pour sortir.
    class Cote
      def initialize
        @ip = Sketchup::InputPoint.new
      end

      def activate(view)
        view.invalidate
      end

      def onMouseMove(_flags, x, y, view)
        @ip.pick(view, x, y)
        view.invalidate
      end

      def draw(view)
        @ip.draw(view) if @ip.display?
      end

      def onLButtonDown(_flags, x, y, view)
        @ip.pick(view, x, y)
        model = view.model
        texte = A2M::Ngf.texte(@ip.position.z, model)
        if texte.nil?
          UI.messagebox('Recalez d\'abord le modèle : menu Extensions > Métré Atelier 2M > Recaler le NGF.')
          model.select_tool(nil)
          return
        end
        model.start_operation('Cote NGF', true)
        model.entities.add_text(texte, @ip.position)
        model.commit_operation
      end

      def onCancel(_reason, view)
        view.model.select_tool(nil)
      end
    end

    def self.poser_cotes
      if origine.nil?
        UI.messagebox('Recalez d\'abord le modèle : menu Extensions > Métré Atelier 2M > Recaler le NGF.')
        return
      end
      Sketchup.active_model.select_tool(Cote.new)
    end
  end
end
