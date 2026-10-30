# encoding: UTF-8
# Métré Atelier 2M : hachures de coupe par type de couche (SketchUp 2027 et plus)
# Chaque couche (mur, isolant, plaque, cloison, chape…) reçoit un motif (.pat) et ses réglages :
# couleur et transparence du trait, couleur et transparence du fond, épaisseur, écartement, angle.
# Le motif est dessiné par l'extension en une image qui se répète (texture de la hachure) : tout est réglable,
# et l'aperçu de la fenêtre est exactement ce qui sera posé.
# Motifs : ceux de l'Atelier 2M (fournis), ceux de SketchUp, ceux téléchargés sur internet
# et tout fichier .pat déposé dans Documents\Atelier 2M\Hachures\Motifs.
require 'sketchup.rb'
require 'json'
require 'fileutils'
require File.join(File.dirname(__FILE__), 'hachures_moteur')

module A2M
  module Hachures
    CLE = 'A2M_Metre'
    PREFIXE = 'A2M · '
    ICI = File.dirname(__FILE__)
    # Balises qui donnent des volumes coupés
    BALISES = %w[A2M_MUR_PERI A2M_MUR_SOUB A2M_MUR_REFEND A2M_MUR_PIGNON A2M_DOUBLAGE A2M_ISOLANT_DOUBLAGE A2M_CLOISON
                 A2M_ISOLANT_SOL A2M_CHAPE A2M_PLANELLE A2M_ISOLANT_PLANELLE A2M_SEMELLE A2M_PIECE A2M_TOITURE A2M_TOITURE_2 A2M_TOITURE_3 A2M_TOITURE_4]
    DEFAUT = { 'trait' => '#1e1e1e', 'trait_op' => 100, 'fond' => '#ffffff', 'fond_op' => 0, 'ep' => 4, 'taille' => 10, 'angle' => 0 }
    # Hachures gratuites téléchargées sur cet ordinateur, pour votre usage
    INTERNET = 'https://draftsperson.net/hatchpatterns/'
    ARCHIVES = (1..11).map { |i| "Brick #{i}" } + ['Stone'] + [1, 2, 3, 5, 6, 7, 8, 9, 10, 11].map { |i| "Stone #{i}" } +
               ['wood'] + (1..6).map { |i| "Wood #{i}" } + ([1, 2, 3, 4, 5] + (7..16).to_a).map { |i| "parquet #{i}" } +
               (1..10).map { |i| format('Roof %02d', i) } + ['Urban'] + (1..7).map { |i| format('Urban %02d', i) } + ['autopat']

    def self.disponible?(model = Sketchup.active_model)
      model.respond_to?(:hatch_patterns) && Sketchup::Group.method_defined?(:hatch_pattern=)
    end

    def self.dossier
      d = File.join(File.dirname(A2M::Bibliotheque.dossier), 'Hachures').tr('\\', '/')
      %w[Motifs SketchUp textures].each { |s| FileUtils.mkdir_p(File.join(d, s)) }
      d
    end

    # Réglages gardés dans un fichier (Documents\Atelier 2M\Hachures\reglages.json) :
    # { 'couches' => { balise => réglage }, 'dossiers' => [dossiers de motifs ajoutés] }
    def self.fichier_reglages() File.join(dossier, 'reglages.json') end

    def self.tout
      JSON.parse(File.read(fichier_reglages, encoding: 'UTF-8'))
    rescue StandardError
      { 'couches' => {}, 'dossiers' => [] }
    end

    def self.ecrire_tout(t)
      File.write(fichier_reglages, JSON.pretty_generate(t), encoding: 'UTF-8')
    end

    def self.reglages
      tout['couches'] || {}
    end

    def self.enregistrer(r)
      t = tout
      t['couches'] = r
      ecrire_tout(t)
    end

    def self.dossiers_ajoutes
      (tout['dossiers'] || []).select { |d| File.directory?(d) }
    end

    def self.ajouter_dossier(d)
      t = tout
      t['dossiers'] = ((t['dossiers'] || []) + [d.tr('\\', '/')]).uniq
      ecrire_tout(t)
    end

    def self.retirer_dossier(d)
      t = tout
      t['dossiers'] = (t['dossiers'] || []) - [d]
      ecrire_tout(t)
    end

    def self.libelle(b)
      (A2M::Balises::LISTE.find { |n, _, _| n == b } || [nil, b])[1].to_s.sub(/\s*\(.*\)\s*\z/, '')
    end

    def self.nom_couche(b) "#{PREFIXE}#{libelle(b)}" end

    # ---- Motifs ----
    def self.bibliotheque_sketchup
      v = Sketchup.version.to_i
      bases = [ENV['ProgramData'], ENV['APPDATA'], ENV['LOCALAPPDATA']].compact
      dirs = bases.flat_map { |b| ["#{b}/SketchUp/SketchUp 20#{v}/SketchUp/HatchPatterns", "#{b}/SketchUp/SketchUp 20#{v}/HatchPatterns"] }
      dirs << (Sketchup.get_resource_path('../HatchPatterns') rescue nil)
      dirs.compact.map { |d| d.tr('\\', '/') }.select { |d| File.directory?(d) }.uniq.flat_map { |d| Dir.glob(File.join(d, '**', '*.skh')) }.uniq.sort
    end

    # Les hachures de SketchUp sont recopiées une fois en fichiers .pat (pour les dessiner avec nos réglages)
    def self.exporter_sketchup(model)
      dest = File.join(dossier, 'SketchUp')
      marque = File.join(dest, 'fait.txt')
      return if File.exist?(marque)
      hp = model.hatch_patterns
      bibliotheque_sketchup.each_with_index do |f, i|
        nom = File.basename(f, '.skh')
        sortie = File.join(dest, "#{nom}.pat")
        m = nil
        begin
          m = hp.add("A2M export #{i}", f)
          m.save_fill_pattern_to_file(sortie)
          t = A2M::MotifPat.texte_fichier(sortie)
          t = t =~ /^\s*\*/ ? t.sub(/^\s*\*[^,\n]*/, "*#{nom}") : "*#{nom}, #{nom}\n#{t}"
          File.write(sortie, t, encoding: 'UTF-8')
        rescue StandardError
          File.delete(sortie) if File.exist?(sortie) && File.size(sortie).zero?
        ensure
          hp.remove(m) if m && m.valid?
        end
      end
      File.write(marque, Time.now.to_s)
    end

    # Hachures des logiciels de DAO installés sur ce poste (ZWCAD, AutoCAD) : fichiers métriques et motifs personnels
    def self.sources_cao
      res = []
      app = ENV['APPDATA'].to_s.tr('\\', '/')
      pf = [ENV['ProgramFiles'], ENV['ProgramW6432'], 'C:/Program Files'].compact.map { |x| x.tr('\\', '/') }.uniq
      cherche = lambda do |logiciel, motifs, fichiers, programmes|
        trouves = Dir.glob(motifs.map { |m| File.join(app, m) } + (programmes ? pf.flat_map { |x| motifs.map { |m| File.join(x, m) } } : []))
        fichiers.each do |nom, groupe|
          f = trouves.select { |t| File.basename(t).casecmp?(nom) }
                     .min_by { |t| [t.include?('/fr-FR/') ? 0 : 1, t.start_with?(app) ? 0 : 1, t] }
          res << ["#{logiciel} · #{groupe}", f] if f
        end
      end
      cherche.call('ZWCAD', ['ZWSOFT/**/*.pat'], [['ZWCADISO.pat', 'motifs'], ['zwcadusr.pat', 'mes motifs']], true)
      cherche.call('AutoCAD', ['Autodesk/**/*.pat'], [['acadiso.pat', 'motifs']], false)
      res
    rescue StandardError
      []
    end

    # Catalogue : { id => motif } ; id = « groupe|fichier|nom »
    def self.catalogue(recharger = false)
      return @cat if @cat && !recharger
      sources = [['Atelier 2M', File.join(ICI, 'hachures')], ['SketchUp', File.join(dossier, 'SketchUp')]] + sources_cao
      motifs = File.join(dossier, 'Motifs').tr('\\', '/')
      Dir.glob(File.join(motifs, '**', '*.pat')).map { |f| File.dirname(f) }.uniq.sort.each do |d|
        # (Windows : majuscules et minuscules indifférentes dans les chemins)
        reste = d.downcase.start_with?(motifs.downcase) ? d[motifs.size..-1].to_s.sub(%r{\A/}, '') : File.basename(d)
        rel = reste.empty? ? 'Mes motifs' : reste.split('/').first
        sources << [rel, d]
      end
      dossiers_ajoutes.each do |d|
        Dir.glob(File.join(d, '**', '*.pat')).map { |f| File.dirname(f) }.uniq.sort.each do |s|
          reste = s.downcase.start_with?(d.downcase) ? s[d.size..-1].to_s.sub(%r{\A/}, '') : File.basename(s)
          sources << [File.basename(d) + (reste.empty? ? '' : ' › ' + reste), s, d]
        end
      end
      @cat = {}
      sources.each do |groupe, d, ajout|
        (File.file?(d) ? [d] : Dir.glob(File.join(d, '*.pat')).sort).each do |f|
          begin
            A2M::MotifPat.lire(A2M::MotifPat.texte_fichier(f), File.basename(f, '.*')).each do |m|
              id = "#{groupe}|#{File.basename(f)}|#{m['nom']}"
              @cat[id] = m.merge('groupe' => groupe, 'id' => id, 'ajout' => ajout)
            end
          rescue StandardError
            next
          end
        end
      end
      @cat
    end

    # ---- Hachure d'une couche dans le modèle ----
    def self.objets(model, b)
      res = []
      fouiller = lambda do |ents, prof|
        ents.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          if e.layer && e.layer.name == b then res << e
          elsif prof < 3 then fouiller.call(e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities, prof + 1)
          end
        end
      end
      fouiller.call(model.entities, 0)
      res
    end

    # Fabrique (ou refait) la hachure de la couche : image du motif avec ses couleurs, à la bonne échelle
    def self.construire(model, b, r = reglages)
      x = r[b]
      return nil unless x.is_a?(Hash) && x['motif']
      m = catalogue[x['motif']] || catalogue(true)[x['motif']]
      return nil unless m
      o = DEFAUT.merge(x)
      png, tx, ty = A2M::MotifPat.png(m, o)
      tex = File.join(dossier, 'textures')
      Dir.glob(File.join(tex, "#{b}_*.png")).each { |f| File.delete(f) rescue nil }
      f = File.join(tex, "#{b}_#{Time.now.to_i}#{rand(1000)}.png")
      File.binwrite(f, png)
      hp = model.hatch_patterns
      h = hp[nom_couche(b)]
      unless h
        base = bibliotheque_sketchup.first or raise 'bibliothèque de hachures de SketchUp introuvable'
        h = hp.add(nom_couche(b), base)
      end
      h.clear_fill_pattern rescue nil
      h.set_fill_texture_image_and_file_name(Sketchup::ImageRep.new(f), f)
      k = o['taille'].to_f / m['ref']                     # centimètres par unité du motif
      h.set_uv_scale([tx * k / 2.54, 0.01].max, [ty * k / 2.54, 0.01].max)
      h.rotation_angle = o['angle'].to_f
      h
    end

    def self.motif_couche(model, b, r = reglages)
      h = model.hatch_patterns[nom_couche(b)] rescue nil
      return h if h
      x = r[b] or return nil
      if x.is_a?(Hash) && x['motif'] then construire(model, b, r)
      elsif x.is_a?(Hash) && x['nom'] then (model.hatch_patterns[x['nom']] rescue nil)   # réglage de la version précédente
      elsif x.is_a?(String) then (model.hatch_patterns[x] rescue nil)
      end
    rescue StandardError
      nil
    end

    # Pose la hachure réglée pour la balise de ce groupe (appelée par les outils de dessin)
    def self.poser(ent, model = Sketchup.active_model)
      return unless disponible?(model) && ent && ent.layer
      m = motif_couche(model, ent.layer.name)
      ent.hatch_pattern = m if m
    rescue StandardError
      nil
    end

    def self.regler_couche(model, b, donnees)
      r = reglages
      if donnees.nil? || donnees['motif'].to_s.empty?
        objets(model, b).each { |e| e.hatch_pattern = nil rescue nil }
        h = model.hatch_patterns[nom_couche(b)] rescue nil
        model.hatch_patterns.remove(h) if h
        r.delete(b)
        enregistrer(r)
        return
      end
      avant = r[b].is_a?(Hash) ? r[b].reject { |k, _| %w[nom fichier source].include?(k) } : {}
      r[b] = DEFAUT.merge(avant).merge(donnees)
      enregistrer(r)
      h = construire(model, b, r) or raise 'motif introuvable'
      objets(model, b).each { |e| e.hatch_pattern = h }
    end

    # ---- Téléchargement de hachures (.pat) sur internet ----
    def self.telecharger(progres, fini)
      dest = File.join(dossier, 'Motifs', 'Internet - draftsperson.net')
      FileUtils.mkdir_p(dest)
      liste = ARCHIVES.map { |n| [n, "#{INTERNET}#{n.gsub(' ', '%20')}.zip"] } +
              %w[fanpaver flagst-2].map { |n| [n, "#{INTERNET}#{n}.pat"] }
      ok = 0; nb = 0; i = 0
      suivant = nil
      suivant = lambda do
        if i >= liste.size
          fini.call(ok, nb)
          return
        end
        nom, url = liste[i]
        i += 1
        progres.call(i, liste.size, nom)
        @req = Sketchup::Http::Request.new(url, Sketchup::Http::GET)
        @req.start do |_rq, rep|
          begin
            corps = rep.body.to_s.b
            if rep.status_code.to_i == 200 && corps.start_with?('PK'.b)
              A2M::MotifPat.dezipper(corps).each do |f, data|
                next unless f =~ /\.pat\z/i
                File.binwrite(File.join(dest, "#{nom} - #{File.basename(f)}"), data)
                nb += 1
              end
              ok += 1
            elsif rep.status_code.to_i == 200 && url.end_with?('.pat') && corps.include?('*'.b)
              File.binwrite(File.join(dest, "#{nom}.pat"), corps)
              nb += 1; ok += 1
            end
          rescue StandardError
            nil
          end
          UI.start_timer(0.05, false) { suivant.call }
        end
      end
      suivant.call
    end

    # ---- Fenêtre ----
    def self.etat(model)
      r = reglages
      couches = BALISES.map do |b|
        x = r[b].is_a?(Hash) && r[b]['motif'] ? DEFAUT.merge(r[b]) : nil
        objs = objets(model, b)
        d = { 'balise' => b, 'libelle' => libelle(b), 'nb' => objs.size, 'r' => x }
        unless x
          # Hachure posée autrement (panneau de SketchUp, version précédente) : elle est montrée
          h = objs.map { |e| e.hatch_pattern rescue nil }.compact.first
          d.merge!('existante' => h.name, 'img' => vignette(h)) if h
        end
        d
      end
      { 'couches' => couches, 'style' => (model.rendering_options['SectionCutFilled'] ? true : false), 'dossiers' => dossiers_ajoutes }
    end

    def self.vignette(h)
      f = File.join(dossier, 'textures', 'vignette.png')
      img = h.thumbnail_image or return nil
      img.save_file(f)
      'data:image/png;base64,' + [File.binread(f)].pack('m0')
    rescue StandardError
      nil
    end

    def self.motifs_pour_page
      catalogue.values.map { |m| { 'id' => m['id'], 'nom' => m['nom'], 'desc' => m['description'], 'groupe' => m['groupe'], 'fam' => m['familles'], 'ref' => m['ref'], 'ajout' => m['ajout'] } }
    end

    def self.regler
      model = Sketchup.active_model
      return UI.messagebox('Les hachures de coupe demandent SketchUp 2027 ou plus récent.') unless disponible?(model)
      if @dlg && @dlg.visible?
        @dlg.bring_to_front
        return
      end
      @dlg = UI::HtmlDialog.new(dialog_title: 'Hachures de coupe par couche', preferences_key: 'A2M_Metre_Hachures2', scrollable: false,
                                resizable: true, width: 1040, height: 740, min_width: 760, min_height: 500, style: UI::HtmlDialog::STYLE_DIALOG)
      @dlg.set_file(File.join(ICI, 'hachures', 'fenetre.html'))
      envoyer = lambda do |quoi, donnees|
        @dlg.execute_script("recevoir(#{JSON.generate(quoi)}, #{JSON.generate(donnees)})") if @dlg
      end
      @dlg.add_action_callback('pret') do |_c|
        m = Sketchup.active_model
        envoyer.call('etat', etat(m))
        UI.start_timer(0.1, false) do
          begin
            exporter_sketchup(m)
          rescue StandardError
            nil
          end
          catalogue(true)
          envoyer.call('motifs', motifs_pour_page)
        end
      end
      @dlg.add_action_callback('regler') do |_c, b, json|
        m = Sketchup.active_model
        m.start_operation('Hachure de coupe (métré)', true)
        begin
          regler_couche(m, b, json.to_s.empty? ? nil : JSON.parse(json))
          m.commit_operation
        rescue StandardError => ex
          m.abort_operation
          UI.messagebox("Hachure non modifiée (#{ex.message}).")
        end
        envoyer.call('etat', etat(m))
      end
      @dlg.add_action_callback('style') do |_c|
        m = Sketchup.active_model
        m.rendering_options['SectionCutFilled'] = true
        envoyer.call('etat', etat(m))
      end
      @dlg.add_action_callback('dossier') { |_c| UI.openURL('file:///' + File.join(dossier, 'Motifs').tr('\\', '/')) }
      @dlg.add_action_callback('internet') do |_c|
        telecharger(
          ->(i, n, nom) { envoyer.call('progres', { 'i' => i, 'n' => n, 'nom' => nom }) },
          lambda do |ok, nb|
            catalogue(true)
            envoyer.call('motifs', motifs_pour_page)
            envoyer.call('progres', { 'fin' => true, 'ok' => ok, 'nb' => nb })
          end
        )
      end
      @dlg.add_action_callback('ajouter_dossier') do |_c|
        d = UI.select_directory(title: 'Dossier de hachures (fichiers .pat) à ajouter à la galerie')
        if d
          ajouter_dossier(d)
          catalogue(true)
          envoyer.call('motifs', motifs_pour_page)
          envoyer.call('etat', etat(Sketchup.active_model))
          envoyer.call('groupe', File.basename(d.tr('\\', '/')))
        end
      end
      @dlg.add_action_callback('retirer_dossier') do |_c, d|
        retirer_dossier(d)
        catalogue(true)
        envoyer.call('motifs', motifs_pour_page)
        envoyer.call('etat', etat(Sketchup.active_model))
      end
      @dlg.add_action_callback('fermer') { |_c| @dlg.close }
      @dlg.show
    end

    # Commande : applique les hachures réglées à tous les groupes et composants balisés du modèle
    def self.appliquer
      model = Sketchup.active_model
      return UI.messagebox('Les hachures de coupe demandent SketchUp 2027 ou plus récent.') unless disponible?(model)
      r = reglages
      return UI.messagebox('Aucune hachure réglée : Extensions > Métré Atelier 2M > Hachures de coupe par couche.') if r.empty?
      manque = []; n = 0
      model.start_operation('Hachures de coupe (métré)', true)
      r.each_key do |b|
        m = motif_couche(model, b, r)
        unless m
          manque << libelle(b)
          next
        end
        objets(model, b).each { |e| e.hatch_pattern = m; n += 1 }
      end
      model.commit_operation
      msg = "Hachures posées sur #{n} groupe(s) ou composant(s)."
      msg += "\nIntrouvables (à choisir à nouveau) : #{manque.uniq.join(', ')}" if manque.any?
      UI.messagebox(msg)
    rescue StandardError => ex
      model.abort_operation rescue nil
      UI.messagebox("Hachures non posées (#{ex.message}).")
    end
  end
end
