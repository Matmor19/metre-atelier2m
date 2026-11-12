# encoding: UTF-8
# Métré Atelier 2M : bascule « Détail / Présentation » du même modèle.
# Détail : les barres du ferraillage sont visibles et le béton est en transparence (rayons X) pour voir à l'intérieur.
# Présentation : le ferraillage est masqué et le béton redevient plein, pour une vue propre. Rien n'est supprimé ni modifié.
require 'sketchup.rb'

module A2M
  module ModeVue
    DICO = 'a2m'
    CLE = 'mode_vue'
    TAGS_DETAIL = %w[A2M_FERRAILLAGE].freeze

    def self.mode(model = Sketchup.active_model) model.get_attribute(DICO, CLE, 'presentation') end

    def self.appliquer(m, model = Sketchup.active_model)
      detail = (m == 'detail')
      model.start_operation(detail ? 'Mode détail' : 'Mode présentation', true)
      TAGS_DETAIL.each { |nom| t = model.layers[nom]; t.visible = detail if t }
      model.commit_operation
      begin model.rendering_options['ModelTransparency'] = detail; rescue StandardError; end
      model.set_attribute(DICO, CLE, m)
      model.active_view.invalidate
      Sketchup.status_text = detail ? 'Mode détail : barres visibles, béton transparent.' : 'Mode présentation : ferraillage masqué, béton plein.'
    end

    def self.basculer
      appliquer(mode == 'detail' ? 'presentation' : 'detail')
    end
  end
end
