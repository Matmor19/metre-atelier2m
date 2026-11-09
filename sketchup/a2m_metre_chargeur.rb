# encoding: UTF-8
# Extension « Métré Atelier 2M » : balises du métré et extraction du modèle pour le configurateur
require 'sketchup.rb'
require 'extensions.rb'
require 'uri'

# Compatibilité : URI.encode, URI.decode, URI.escape et URI.unescape n'existent plus dans le Ruby de SketchUp 2027.
# Des extensions anciennes (BIMobject, par exemple) les appellent encore au démarrage et affichent une erreur à chaque ouverture.
# Rien n'est changé si ces méthodes existent déjà.
module URI
  class << self
    unless respond_to?(:encode)
      def encode(str, *args) DEFAULT_PARSER.escape(str.to_s, *args) end
    end
    unless respond_to?(:escape)
      def escape(str, *args) DEFAULT_PARSER.escape(str.to_s, *args) end
    end
    unless respond_to?(:decode)
      def decode(str, *args) DEFAULT_PARSER.unescape(str.to_s, *args) end
    end
    unless respond_to?(:unescape)
      def unescape(str, *args) DEFAULT_PARSER.unescape(str.to_s, *args) end
    end
  end
end

module A2M
  module Metre
    EXT = SketchupExtension.new('Métré Atelier 2M', 'a2m_metre/main')
    EXT.description = 'Crée et applique les balises A2M_, puis extrait murs, pièces, menuiseries, toiture et surfaces dans un fichier .json à importer dans le configurateur du métré.'
    EXT.version = '2.97.32'
    EXT.creator = 'Atelier 2M'
    Sketchup.register_extension(EXT, true)
  end
end
