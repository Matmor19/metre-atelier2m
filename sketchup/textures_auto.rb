# encoding: UTF-8
# Métré Atelier 2M : textures automatiques.
# Quand un élément est dessiné avec les outils Atelier 2M (mur de soubassement, semelles…), la matière A2M_ choisie
# pour son type est posée dessus : côtés (axes rouge et vert), dessus et dessous (axe bleu).
# Les matières viennent du modèle ouvert ou, à défaut, de Mes éléments > Textures. Leur taille de motif n'est jamais modifiée.
require 'sketchup.rb'
require 'json'
require 'fileutils'

module A2M
  module TexturesAuto
    # type d'élément (balise) => matière par face ; « haut » et « bas » reprennent « cotes » si absents
    DEFAUT = {
      'A2M_MUR_SOUB' => { 'cotes' => 'A2M_Parpaing', 'haut' => 'A2M_Mortier béton', 'bas' => 'A2M_Mortier béton' },
      'A2M_SEMELLE'  => { 'cotes' => 'A2M_Béton fondation' }
    }.freeze

    def self.fichier
      File.join(File.dirname(A2M::MesElements.dossier), 'textures_auto.json').tr('\\', '/')
    end

    # Table réglée : réglages de l'utilisateur par-dessus les valeurs d'origine
    def self.table
      perso = (JSON.parse(File.read(fichier, encoding: 'UTF-8')) rescue {})
      DEFAUT.merge(perso.is_a?(Hash) ? perso : {})
    end

    def self.cle(n) A2M::MesElements.nom_tex(n).downcase end

    # Matière du modèle (nom tolérant : espaces, #1, majuscules), sinon chargée depuis Mes éléments > Textures
    def self.matiere(model, nom)
      return nil if nom.to_s.empty?
      k = cle(nom)
      m = model.materials.find { |x| cle(x.name) == k }
      return m if m
      f = File.join(A2M::MesElements.dossier, A2M::MesElements::TEX, A2M::MesElements.nettoyer(A2M::MesElements.nom_tex(nom)) + '.skm')
      File.exist?(f) ? (model.materials.load(f) rescue nil) : nil
    end

    # Pose les matières sur les faces du groupe ou du composant selon la table de son type
    def self.appliquer(ent, model = Sketchup.active_model, ecraser = false, cle_type = nil)
      return 0 unless ent && ent.valid? && (ent.layer || cle_type)
      t = table[cle_type || ent.layer.name]
      return 0 unless t
      ents = ent.is_a?(Sketchup::ComponentInstance) ? ent.definition.entities : ent.entities
      tr = ent.transformation
      mats = { 'cotes' => matiere(model, t['cotes']), 'haut' => matiere(model, t['haut'] || t['cotes']), 'bas' => matiere(model, t['bas'] || t['cotes']) }
      n = 0
      ents.grep(Sketchup::Face).each do |f|
        nz = (tr * f.normal).z
        role = nz > 0.99 ? 'haut' : (nz < -0.99 ? 'bas' : 'cotes')
        m = mats[role]
        next unless m
        next if f.material && !ecraser
        f.material = m
        n += 1
      end
      n
    rescue StandardError
      0
    end

    # Commande : applique les textures à tous les éléments du modèle (ou à la sélection) dont le type est dans la table
    def self.tout_le_modele
      model = Sketchup.active_model
      sel = model.selection.grep(Sketchup::Group) + model.selection.grep(Sketchup::ComponentInstance)
      cibles = sel.empty? ? (model.entities.grep(Sketchup::Group) + model.entities.grep(Sketchup::ComponentInstance)) : sel
      cibles = cibles.select { |e| table.key?(e.layer.name) }
      return UI.messagebox("Rien à texturer : aucun élément de type #{table.keys.join(', ')}.") if cibles.empty?
      model.start_operation('Textures automatiques (A2M_)', true)
      n = cibles.sum { |e| appliquer(e, model, true) }
      model.commit_operation
      manque = table.values.flat_map(&:values).uniq.reject { |nom| matiere(model, nom) }
      msg = "#{n} face(s) texturée(s) sur #{cibles.size} élément(s)."
      msg += "\n\nMatière introuvable : #{manque.join(', ')}.\nDessinez-la dans le modèle (nom A2M_…) ou importez-la dans Mes éléments > Textures." unless manque.empty?
      UI.messagebox(msg)
    end
  end
end
