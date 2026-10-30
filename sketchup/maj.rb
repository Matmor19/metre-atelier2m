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
            notes = Array(d['notes']).map { |x| "  • #{x}" }.join("\n")
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
          UI.messagebox("Version #{v} installée.\n\nFermez SketchUp puis rouvrez-le pour l'utiliser.")
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

    def self.installer_local(v, f)
      q = UI.messagebox("Métré Atelier 2M : le fichier\n#{f}\ncontient la version #{v} (installée : #{installee}).\n\nL'installer maintenant ?", MB_YESNO)
      return unless q == IDYES
      Sketchup.install_from_archive(f)
      UI.messagebox("Version #{v} installée.\n\nFermez SketchUp puis rouvrez-le pour l'utiliser.")
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
      UI.start_timer(8, false) do
        l = rbz_local
        l ? installer_local(*l) : verifier(false)
      end
    end
  end
end
