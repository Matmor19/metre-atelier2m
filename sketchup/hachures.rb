# encoding: UTF-8
# Métré Atelier 2M : hachures de coupe par type de couche (SketchUp 2027 et plus)
# Chaque balise du métré (mur, isolant, plaque, cloison, chape…) reçoit une hachure choisie une fois pour toutes.
# Les outils de dessin la posent sur chaque groupe créé ; une commande l'applique à un modèle déjà dessiné.
require 'sketchup.rb'
require 'json'

module A2M
  module Hachures
    CLE = 'A2M_Metre'
    AUCUNE = '(aucune hachure)'
    # Balises qui donnent des volumes coupés
    BALISES = %w[A2M_MUR_PERI A2M_MUR_SOUB A2M_MUR_REFEND A2M_MUR_PIGNON A2M_DOUBLAGE A2M_ISOLANT_DOUBLAGE A2M_CLOISON
                 A2M_ISOLANT_SOL A2M_CHAPE A2M_PLANELLE A2M_ISOLANT_PLANELLE A2M_SEMELLE A2M_PIECE A2M_TOITURE A2M_TOITURE_2 A2M_TOITURE_3 A2M_TOITURE_4]

    def self.disponible?(model = Sketchup.active_model)
      model.respond_to?(:hatch_patterns) && Sketchup::Group.method_defined?(:hatch_pattern=)
    end

    def self.reglages
      JSON.parse(Sketchup.read_default(CLE, 'hachures', '{}').to_s) rescue {}
    end

    # Hachures présentes dans le modèle (bibliothèque de SketchUp et celles de votre gabarit)
    def self.noms(model = Sketchup.active_model)
      hp = model.hatch_patterns
      liste = hp.respond_to?(:map) ? hp.map { |x| x.respond_to?(:name) ? x.name : x.to_s } : []
      liste.compact.uniq.sort
    rescue StandardError
      []
    end

    def self.motif(model, nom)
      return nil if nom.to_s.empty? || nom == AUCUNE
      model.hatch_patterns[nom]
    rescue StandardError
      nil
    end

    # Pose la hachure réglée pour la balise de ce groupe (appelée par les outils de dessin)
    def self.poser(ent, model = Sketchup.active_model)
      return unless disponible?(model) && ent && ent.layer
      nom = reglages[ent.layer.name]
      m = motif(model, nom)
      ent.hatch_pattern = m if m
    rescue StandardError
      nil
    end

    def self.libelle(b) "#{b} — #{(A2M::Balises::LISTE.find { |n, _, _| n == b } || [nil, ''])[1]}" end

    # Commande : une hachure par type de couche (retenue pour tous vos modèles)
    def self.regler
      model = Sketchup.active_model
      return UI.messagebox('Les hachures de coupe demandent SketchUp 2027 ou plus récent.') unless disponible?(model)
      dispo = noms(model)
      return UI.messagebox("Aucune hachure dans ce modèle.\nAjoutez-en une depuis le panneau Matériaux (Remplissage de coupe), puis relancez ce réglage.") if dispo.empty?
      r = reglages
      liste = ([AUCUNE] + dispo).join('|')
      rep = UI.inputbox(BALISES.map { |b| libelle(b) }, BALISES.map { |b| dispo.include?(r[b]) ? r[b] : AUCUNE }, BALISES.map { liste },
                        'Hachures de coupe par type de couche')
      return unless rep
      BALISES.each_with_index { |b, i| rep[i] == AUCUNE ? r.delete(b) : r[b] = rep[i] }
      Sketchup.write_default(CLE, 'hachures', JSON.generate(r))
      if UI.messagebox("Hachures enregistrées : elles seront posées sur tout ce que vous dessinerez avec l'extension.\n\nLes appliquer aussi maintenant aux couches déjà dessinées dans ce modèle ?", MB_YESNO) == IDYES
        appliquer
      end
    end

    # Commande : applique les hachures réglées à tous les groupes et composants balisés du modèle
    def self.appliquer
      model = Sketchup.active_model
      return UI.messagebox('Les hachures de coupe demandent SketchUp 2027 ou plus récent.') unless disponible?(model)
      r = reglages
      return UI.messagebox('Aucune hachure réglée : Extensions > Métré Atelier 2M > Hachures de coupe par couche.') if r.empty?
      manque = []; n = 0
      model.start_operation('Hachures de coupe (métré)', true)
      fouiller = lambda do |ents, prof|
        ents.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          nom = e.layer && r[e.layer.name]
          if nom
            m = motif(model, nom)
            if m then e.hatch_pattern = m; n += 1
            else manque << nom
            end
          elsif prof < 3
            fouiller.call(e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities, prof + 1)
          end
        end
      end
      fouiller.call(model.entities, 0)
      model.commit_operation
      msg = "Hachures posées sur #{n} groupe(s) ou composant(s)."
      msg += "\nAbsentes de ce modèle (à ajouter, ou à mettre dans votre gabarit) : #{manque.uniq.join(', ')}" if manque.any?
      UI.messagebox(msg)
    rescue StandardError => ex
      model.abort_operation rescue nil
      UI.messagebox("Hachures non posées (#{ex.message}).")
    end
  end
end
