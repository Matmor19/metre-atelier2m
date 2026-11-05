# encoding: UTF-8
# Métré Atelier 2M : calage d'un plan existant (image) : import, mise à l'échelle en 2 clics sur une cote connue, mise d'équerre
require 'sketchup.rb'

module A2M
  module Calage
    TAG = 'A2M_PLAN_EXISTANT'

    # Outil : 2 clics sur une longueur connue du plan, puis la vraie valeur ; l'image est mise à l'échelle autour du 1er point
    class Outil
      def initialize(img) @img = img; @pts = []; @ip = Sketchup::InputPoint.new; @m = nil end
      def activate; Sketchup.status_text = 'Calage : cliquez le début d\'une longueur connue du plan (un mur, une cote écrite…)'; end
      def deactivate(view) view.invalidate end
      def onCancel(_r, view) Sketchup.active_model.select_tool(nil) end
      def onSetCursor() UI.set_cursor(632) end
      def onMouseMove(_f, x, y, view) @ip.pick(view, x, y); @m = @ip.position; view.invalidate end
      def onLButtonDown(_f, x, y, view)
        @ip.pick(view, x, y)
        @pts << @ip.position.clone
        if @pts.size == 1
          Sketchup.status_text = 'Calage : cliquez la fin de cette longueur'
        else
          Sketchup.active_model.select_tool(nil)
          a, b = @pts; img = @img
          UI.start_timer(0, false) { A2M::Calage.caler(img, a, b) }
        end
        view.invalidate
      end
      def draw(view)
        return if @pts.empty? || @m.nil?
        view.drawing_color = Sketchup::Color.new(224, 120, 56); view.line_width = 2
        view.draw_lines(@pts[0], @m)
        view.draw_points(@pts, 8, 1, Sketchup::Color.new(224, 120, 56))
      end
    end

    def self.importer
      model = Sketchup.active_model
      chemin = UI.openpanel('Choisir le plan à caler (image)', '', 'Images|*.png;*.jpg;*.jpeg;*.bmp;*.tif;*.tiff||')
      return unless chemin
      model.start_operation('Importer un plan existant', true)
      begin
        img = model.entities.add_image(chemin, ORIGIN, 10.m)
        tag, _ = A2M::Balises.balise(model, TAG, [150, 150, 160]) rescue nil
        img.layer = tag if tag
        img.name = 'Plan existant'
        model.commit_operation
      rescue StandardError => ex
        model.abort_operation
        return UI.messagebox("Import impossible : #{ex.message}\nLe PDF n'est pas accepté : exportez la page en image (PNG ou JPG).")
      end
      model.selection.clear; model.selection.add(img)
      model.active_view.zoom(img)
      UI.messagebox("Plan importé (à une échelle provisoire de 10 m de large).\nCliquez maintenant deux points sur une longueur connue du plan, puis tapez sa vraie valeur.")
      model.select_tool(Outil.new(img))
    end

    def self.caler(img, a, b)
      model = Sketchup.active_model
      mesure = a.distance(b)
      return UI.messagebox('Les deux points sont confondus.') if mesure < 1.mm
      rep = UI.inputbox(['Vraie longueur (cm)', 'Mettre le plan d\'équerre'], ['100', 'Pas de rotation'], ['', 'Pas de rotation|Cette ligne sur l\'axe rouge|Cette ligne sur l\'axe vert'], 'Calage du plan')
      return unless rep
      reel = (Float(rep[0].to_s.tr(',', '.')) rescue 0).cm
      return UI.messagebox('Longueur invalide.') if reel <= 0
      model.start_operation('Caler le plan', true)
      img.locked = false if img.respond_to?(:locked=)
      img.transform!(Geom::Transformation.scaling(a, reel / mesure))
      d = b - a; d = Geom::Vector3d.new(d.x, d.y, 0)
      vers = { 'Cette ligne sur l\'axe rouge' => X_AXIS, 'Cette ligne sur l\'axe vert' => Y_AXIS }[rep[1]]
      if vers
        ang = d.angle_between(vers)
        sens = d.cross(vers).z >= 0 ? 1 : -1
        # on tourne vers l'axe le plus proche, dans les deux sens possibles
        ang = sens * d.angle_between(vers)
        ang -= Math::PI * (ang.abs > Math::PI / 2 ? (ang <=> 0) : 0)
        img.transform!(Geom::Transformation.rotation(a, Z_AXIS, ang))
      end
      model.commit_operation
      model.active_view.zoom(img)
      Sketchup.status_text = "Plan calé : #{(reel.to_f * 2.54).round(1)} cm mesurés sur le plan. Vérifiez avec le mètre de SketchUp."
    end
  end
end
