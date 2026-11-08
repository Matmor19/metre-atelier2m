# encoding: UTF-8
# Métré Atelier 2M : mise à jour de l'extension
# Au démarrage de SketchUp, l'extension lit la version publiée (GitHub). Si elle est plus récente,
# une fenêtre montre les nouveautés et propose de l'installer : téléchargement et installation automatiques.
require 'sketchup.rb'
require 'json'
require 'zlib'

module A2M
  module MiseAJour
    BASE = 'https://raw.githubusercontent.com/Matmor19/metre-atelier2m/main/sketchup/'
    API = 'https://api.github.com/repos/Matmor19/metre-atelier2m/commits/main'

    # Adresse des fichiers au dernier enregistrement publié (évite le cache de GitHub, qui peut servir
    # l'ancienne version pendant quelques minutes) ; sans réponse de GitHub : l'adresse habituelle
    def self.base
      @rq0 = Sketchup::Http::Request.new(API, Sketchup::Http::GET)
      @rq0.headers = { 'User-Agent' => 'A2M-Metre-SketchUp', 'Accept' => 'application/vnd.github+json' } rescue nil
      @rq0.start do |_q, rep|
        sha = (JSON.parse(rep.body)['sha'] rescue nil) if rep.status_code == 200
        yield sha && sha =~ /\A\h{40}\z/ ? "https://raw.githubusercontent.com/Matmor19/metre-atelier2m/#{sha}/sketchup/" : BASE
      end
    rescue StandardError
      yield BASE
    end

    def self.installee() A2M::Metre::EXT.version.to_s end

    def self.plus_recente?(a, b)
      (a.to_s.split('.').map(&:to_i) <=> b.to_s.split('.').map(&:to_i)) > 0
    end

    # manuel : lancé depuis le menu (on répond aussi quand tout est à jour ou que la connexion échoue)
    def self.verifier(manuel = false)
      return unless defined?(Sketchup::Http::Request)
      base { |b| verifier_depuis(b, manuel) }
    end

    def self.verifier_depuis(b, manuel)
      @base = b
      @req = Sketchup::Http::Request.new("#{b}version.json?#{Time.now.to_i}", Sketchup::Http::GET)
      @req.start do |_rq, rep|
        begin
          raise "réponse #{rep.status_code}" unless rep.status_code == 200
          d = JSON.parse(rep.body)
          v = d['version'].to_s
          if plus_recente?(v, installee)
            notes = Array(d['notes']).first(8).map { |x| "  • #{x.to_s[0, 160]}" }.join("\n")   # la boîte Windows ne défile pas : liste courte
            q = UI.messagebox("Métré Atelier 2M : une nouvelle version est disponible.\n\n" \
                              "Version installée : #{installee}\nNouvelle version : #{v}\n\n" \
                              "Nouveautés :\n#{notes}\n\nMettre à jour maintenant ?", MB_YESNO)
            telecharger(v) if q == IDYES
          elsif manuel
            UI.messagebox("Métré Atelier 2M est à jour (version #{installee}).")
          end
        rescue StandardError => ex
          UI.messagebox("Impossible de vérifier les mises à jour (#{ex.message}). Vérifiez la connexion internet.") if manuel
        end
      end
    end

    def self.telecharger(v)
      Sketchup.status_text = "Métré Atelier 2M : téléchargement de la version #{v}…"
      @req2 = Sketchup::Http::Request.new("#{@base || BASE}a2m_metre.rbz?#{Time.now.to_i}", Sketchup::Http::GET)
      @req2.start do |_rq, rep|
        begin
          raise "réponse #{rep.status_code}" unless rep.status_code == 200 && rep.body.to_s.bytesize > 1000
          f = File.join(Sketchup.temp_dir, "a2m_metre_#{v}.rbz")
          File.binwrite(f, rep.body)
          Sketchup.install_from_archive(f)
          apres_installation(v)
        rescue StandardError => ex
          UI.messagebox("La mise à jour n'a pas pu être installée (#{ex.message}).\n" \
                        'Vous pouvez toujours l\'installer à la main : Extensions > Gestionnaire d\'extensions > Installer l\'extension.')
        end
      end
    end

    # ---- Fichier .rbz déposé dans un dossier (le vôtre, et Téléchargements) ----
    def self.dossiers
      base = ENV['USERPROFILE'] || ENV['HOME'] || Dir.home
      d = Sketchup.read_default('A2M_Metre', 'dossier_rbz').to_s
      ([d] + [File.join(base, 'Downloads'), File.join(base, 'Téléchargements')]).reject(&:empty?).select { |x| File.directory?(x) }.uniq
    end

    # Version écrite dans un .rbz (lecture du fichier a2m_metre.rb dans l'archive, sans rien installer)
    def self.version_rbz(f)
      donnees = File.binread(f)
      i = 0
      while (i = donnees.index("PK\x03\x04".b, i))
        meth, = donnees[i + 8, 2].unpack('v')
        taille, = donnees[i + 18, 4].unpack('V')
        ln, lx = donnees[i + 26, 4].unpack('vv')
        nom = donnees[i + 30, ln]
        brut = donnees[i + 30 + ln + lx, taille]
        if nom == 'a2m_metre.rb'
          txt = meth == 8 ? Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(brut) : brut
          m = txt.force_encoding('UTF-8').match(/EXT\.version\s*=\s*'([^']+)'/)
          return m && m[1]
        end
        i += 30 + ln + lx + taille
      end
      nil
    rescue StandardError
      nil
    end

    # Le plus récent des a2m_metre*.rbz trouvés, s'il est plus récent que la version installée
    def self.rbz_local
      meilleur = nil
      dossiers.each do |d|
        Dir.glob(File.join(d.tr('\\', '/'), 'a2m_metre*.rbz')).each do |f|
          v = version_rbz(f)
          next unless v && plus_recente?(v, installee)
          meilleur = [v, f] if meilleur.nil? || plus_recente?(v, meilleur[0])
        end
      end
      meilleur
    end

    # Fichiers qui créent menus, barres d'outils ou observateurs : les recharger les doublerait, ils attendent le redémarrage
    SANS_RECHARGE = %w[menu_contextuel palette plan2d suivi tableau variantes].freeze

    # Recharge les fichiers de l'extension tout juste installée, sans fermer SketchUp ; renvoie [rechargés, échecs]
    def self.recharger(v = nil)
      ici = File.dirname(__FILE__)
      main = File.read(File.join(ici, 'main.rb'), encoding: 'UTF-8')
      liste = %w[hachures_moteur hachures_fr hachures_onde hachures_dessin] + main[/%w\[([^\]]*)\]\.each \{ \|f\| require/, 1].to_s.split
      ok = 0
      ko = []
      verb = $VERBOSE
      $VERBOSE = nil
      liste.each do |f|
        next if SANS_RECHARGE.include?(f)
        begin
          load File.join(ici, "#{f}.rb")
          ok += 1
        rescue Exception => ex
          ko << "#{f} (#{ex.message[0, 60]})"
        end
      end
      $VERBOSE = verb
      A2M::Metre::EXT.version = v if v && ko.empty?
      A2M::Hachures.catalogue(true) rescue nil
      [ok, ko]
    end

    # Veille : quand les fichiers de l'extension changent sur le disque (installation par le Gestionnaire d'extensions,
    # par la mise à jour intégrée ou à la main), ils sont rechargés tout seuls au bout de quelques secondes
    def self.veille
      return if @veille
      main = File.join(File.dirname(__FILE__), 'main.rb')
      @vu = (File.mtime(main) rescue nil)
      @veille = UI.start_timer(3, true) do
        begin
          t = (File.mtime(main) rescue nil)
          next if t.nil? || t == @vu || @attente
          @vu = t
          @attente = true
          UI.start_timer(4, false) do                       # on laisse finir l'installation avant de recharger
            @attente = false
            ok, ko = recharger(version_disque)
            Sketchup.status_text = ko.empty? ? "Métré Atelier 2M : version #{installee} rechargée." : "Métré Atelier 2M : rechargement incomplet (#{ko.join(', ')}) — redémarrez SketchUp."
          end
        rescue StandardError
          nil
        end
      end
    end

    def self.version_disque
      f = File.join(File.dirname(__FILE__), '..', 'a2m_metre_chargeur.rb')
      File.read(f, encoding: 'UTF-8')[/EXT\.version = '([^']+)'/, 1]
    rescue StandardError
      nil
    end

    def self.apres_installation(v)
      ok, ko = recharger(v)
      if ko.empty?
        UI.messagebox("Version #{v} installée et déjà chargée : vous pouvez l'utiliser tout de suite.\n\n(Si un nouveau bouton ou un nouveau menu a été ajouté, il apparaîtra au prochain démarrage de SketchUp.)")
      else
        UI.messagebox("Version #{v} installée, mais certaines parties n'ont pas pu être rechargées : #{ko.join(', ')}.\n\nFermez SketchUp puis rouvrez-le pour tout utiliser.")
      end
    end

    def self.installer_local(v, f)
      q = UI.messagebox("Métré Atelier 2M : le fichier\n#{f}\ncontient la version #{v} (installée : #{installee}).\n\nL'installer maintenant ?", MB_YESNO)
      return unless q == IDYES
      Sketchup.install_from_archive(f)
      apres_installation(v)
    rescue StandardError => ex
      UI.messagebox("Installation impossible (#{ex.message}).")
    end

    # Commande : le dossier où vous déposez le fichier .rbz
    def self.choisir_dossier
      d = UI.select_directory(title: 'Dossier où vous déposez le fichier a2m_metre.rbz')
      return unless d
      Sketchup.write_default('A2M_Metre', 'dossier_rbz', d)
      l = rbz_local
      l ? installer_local(*l) : UI.messagebox("Dossier retenu : #{d}\nÀ chaque ouverture de SketchUp, un a2m_metre.rbz plus récent qui s'y trouve vous sera proposé.")
    end

    # Au démarrage : d'abord un .rbz plus récent dans vos dossiers, sinon la version publiée en ligne
    def self.au_demarrage
      veille
      UI.start_timer(8, false) do
        l = rbz_local
        l ? installer_local(*l) : verifier(false)
      end
    end
  end
end
