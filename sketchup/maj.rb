# encoding: UTF-8
# Métré Atelier 2M : mise à jour de l'extension
# Au démarrage de SketchUp, l'extension lit la version publiée (GitHub). Si elle est plus récente,
# une fenêtre montre les nouveautés et propose de l'installer : téléchargement et installation automatiques.
require 'sketchup.rb'
require 'json'

module A2M
  module MiseAJour
    BASE = 'https://raw.githubusercontent.com/Matmor19/metre-atelier2m/main/sketchup/'

    def self.installee() A2M::Metre::EXT.version.to_s end

    def self.plus_recente?(a, b)
      (a.to_s.split('.').map(&:to_i) <=> b.to_s.split('.').map(&:to_i)) > 0
    end

    # manuel : lancé depuis le menu (on répond aussi quand tout est à jour ou que la connexion échoue)
    def self.verifier(manuel = false)
      return unless defined?(Sketchup::Http::Request)
      @req = Sketchup::Http::Request.new("#{BASE}version.json?#{Time.now.to_i}", Sketchup::Http::GET)
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
      @req2 = Sketchup::Http::Request.new("#{BASE}a2m_metre.rbz?#{Time.now.to_i}", Sketchup::Http::GET)
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

    # Vérification discrète quelques secondes après le démarrage (SketchUp a fini de s'ouvrir)
    def self.au_demarrage
      UI.start_timer(8, false) { verifier(false) }
    end
  end
end
