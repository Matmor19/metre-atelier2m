# encoding: UTF-8
# Extension « Métré Atelier 2M » : balises du métré et extraction du modèle pour le configurateur
require 'sketchup.rb'
require 'extensions.rb'

module A2M
  module Metre
    EXT = SketchupExtension.new('Métré Atelier 2M', 'a2m_metre/main')
    EXT.description = 'Crée et applique les balises A2M_, puis extrait murs, pièces, menuiseries, toiture et surfaces dans un fichier .json à importer dans le configurateur du métré.'
    EXT.version = '2.7.2'
    EXT.creator = 'Atelier 2M'
    Sketchup.register_extension(EXT, true)
  end
end
