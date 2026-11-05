# encoding: UTF-8
# Métré Atelier 2M : export DWG / DXF pour ZWCAD (une balise = un calque)
require 'sketchup.rb'
require 'fileutils'

module A2M
  module ExportCAO
    FORMATS = ['DWG', 'DXF']
    VERSIONS = { 'AutoCAD 2018 (ZWCAD 2026 : recommandé)' => 'acad_2018', 'AutoCAD 2013' => 'acad_2013', 'AutoCAD 2010' => 'acad_2010', 'AutoCAD 2007' => 'acad_2007' }

    def self.dossier
      base = (ENV['USERPROFILE'] || Dir.home).to_s.tr('\\', '/')
      d = File.join(base, 'Documents', 'Atelier 2M', 'Export CAO')
      FileUtils.mkdir_p(d) rescue nil
      d
    end

    def self.exporter(format, version, avec_scenes)
      model = Sketchup.active_model
      nom = (model.title.to_s.empty? ? 'Sans titre' : model.title).gsub(/[^\w\- ]/, '_')
      opts = { show_summary: false, acad_version: VERSIONS[version] || 'acad_2018', faces_flag: true, construction_geometry: false,
               dimensions: true, text: true, edges: true }
      sorties = []
      chemin = File.join(dossier, "#{nom}.#{format.downcase}")
      ok = model.export(chemin, opts)
      sorties << chemin if ok
      if avec_scenes
        # Scènes 2D (plans, coupes, façades) : une sortie par scène
        model.pages.each do |p|
          next unless p.name =~ /Plan 2D|Coupe|Façade/
          model.pages.selected_page = p
          model.active_view.refresh
          ch = File.join(dossier, "#{nom} – #{p.name.gsub(/[^\w\- ]/, '_')}.#{format.downcase}")
          sorties << ch if model.export(ch, opts.merge(hidden_lines: true))
        end
      end
      sorties
    end

    def self.lancer
      model = Sketchup.active_model
      rep = UI.inputbox(['Format', 'Version'], ['DWG', VERSIONS.keys[0]], [FORMATS.join('|'), VERSIONS.keys.join('|')], 'Export pour ZWCAD')
      return unless rep
      s = exporter(rep[0], rep[1], false)
      if s.empty?
        UI.messagebox('Export impossible : SketchUp n\'a rien écrit. L\'export DWG/DXF demande SketchUp Pro.')
      else
        UI.messagebox("Export terminé (#{s.size} fichier(s)) dans :\n#{dossier}\n\nChaque balise Métré A2M devient un calque dans ZWCAD.")
        UI.openURL("file:///#{dossier}") rescue nil
      end
    end
  end
end
