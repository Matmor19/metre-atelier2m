# encoding: UTF-8
# Métré Atelier 2M : journal des erreurs Ruby, écrit dans Documents\Atelier 2M\journal_erreurs.txt
# Deux sources :
#  1. tout ce que SketchUp écrit sur la sortie d'erreur ($stderr) : les erreurs non rattrapées, de cette extension
#     comme des autres (elles s'affichent d'habitude seulement dans la Console Ruby) ;
#  2. les erreurs levées dans les fichiers de cette extension, même quand le code les rattrape en silence (« rescue nil ») :
#     elles sont notées une seule fois par endroit et par message, pour ne pas remplir le fichier.
# Le journal ne change rien au fonctionnement : s'il ne peut pas écrire, il se tait.
require 'sketchup.rb'
require 'fileutils'

module A2M
  module JournalErreurs
    TAILLE_MAX = 300 * 1024 unless defined?(TAILLE_MAX)   # au-delà, l'ancien journal devient journal_erreurs_ancien.txt
    MAX_SESSION = 400 unless defined?(MAX_SESSION)        # entrées « rattrapées » au plus par session de SketchUp
    ICI = File.dirname(__FILE__).tr('\\', '/') unless defined?(ICI)

    def self.fichier
      dos = defined?(A2M::Bibliotheque) && A2M::Bibliotheque.respond_to?(:dossier) ? (File.dirname(A2M::Bibliotheque.dossier) rescue nil) : nil
      unless dos
        base = ENV['USERPROFILE'] || ENV['HOME'] || Dir.home
        doc = File.join(base, 'Documents')
        dos = File.join(File.directory?(doc) ? doc : base, 'Atelier 2M')
      end
      File.join(dos, 'journal_erreurs.txt')
    end

    def self.ecrire(texte)
      return if @ecriture                       # pas de boucle si l'écriture elle-même échoue
      @ecriture = true
      begin
        ecrire_fichier(texte)
      ensure
        @ecriture = false
      end
    end

    def self.ecrire_fichier(texte)
      f = fichier
      FileUtils.mkdir_p(File.dirname(f))
      if File.exist?(f) && File.size(f) > TAILLE_MAX
        ancien = f.sub(/\.txt\z/, '_ancien.txt')
        File.delete(ancien) if File.exist?(ancien)
        File.rename(f, ancien)
      end
      entete = @entete_ecrit ? '' : "\n===== #{Time.now.strftime('%d/%m/%Y %H:%M:%S')} — SketchUp #{Sketchup.version rescue '?'} — Métré Atelier 2M #{(A2M::Metre::EXT.version rescue '?')}\n"
      @entete_ecrit = true
      File.open(f, 'a:UTF-8') { |io| io.write(entete + texte.to_s.encode('UTF-8', invalid: :replace, undef: :replace)) }
    rescue StandardError
      nil
    end

    def self.heure() Time.now.strftime('%H:%M:%S') end

    # ---- 1. Sortie d'erreur : on recopie dans le fichier, la Console Ruby reçoit toujours le même texte ----
    class Copie
      def initialize(orig) @orig = orig; @tampon = +'' end
      attr_reader :orig

      def write(*args)
        r = @orig.write(*args)
        recopier(args.join)
        r
      end

      def print(*args) write(*args.map(&:to_s)); nil end
      def puts(*args) write(*(args.empty? ? ["\n"] : args.flatten.map { |a| s = a.to_s; s.end_with?("\n") ? s : s + "\n" })); nil end
      def <<(obj) write(obj.to_s); self end
      def flush() @orig.flush rescue nil; self end
      def sync() true end
      def sync=(_v) end
      def respond_to_missing?(nom, privee = false) @orig.respond_to?(nom, privee) || super end
      def method_missing(nom, *args, &bloc) @orig.respond_to?(nom) ? @orig.__send__(nom, *args, &bloc) : super end

      private

      # Regroupe par ligne entière, horodatée
      def recopier(txt)
        @tampon << txt.to_s
        return unless @tampon.include?("\n")
        lignes = @tampon.split("\n", -1)
        @tampon = lignes.pop.to_s
        texte = lignes.reject { |l| l.strip.empty? }.map { |l| "#{A2M::JournalErreurs.heure}  [console] #{l}\n" }.join
        A2M::JournalErreurs.ecrire(texte) unless texte.empty?
      rescue StandardError
        nil
      end
    end

    def self.brancher_console
      return if $stderr.is_a?(Copie)
      $stderr = Copie.new($stderr)
    rescue StandardError
      nil
    end

    # ---- 2. Erreurs levées dans nos fichiers, même rattrapées ----
    def self.brancher_trace
      return if @trace
      @vus = {}
      @n = 0
      @trace = TracePoint.new(:raise) do |tp|
        begin
          ex = tp.raised_exception
          next if ex.is_a?(SystemExit) || ex.is_a?(StopIteration)
          # Premier endroit de la pile qui est dans nos fichiers (l'erreur peut naître dans une méthode de Ruby ou de SketchUp)
          ici = ICI.downcase
          loc = (ex.backtrace_locations || caller_locations).find { |l| l.path.to_s.tr('\\', '/').downcase.start_with?(ici) }
          next unless loc
          chemin = loc.path.to_s.tr('\\', '/')
          next if chemin.end_with?('journal_erreurs.rb')
          ligne = loc.lineno
          cle = "#{chemin}:#{ligne}:#{ex.class}:#{ex.message.to_s[0, 80]}"
          next if @vus[cle] || @n >= MAX_SESSION
          @vus[cle] = true
          @n += 1
          pile = (ex.backtrace || caller).first(6).map { |l| "            #{l.sub(ICI + '/', '')}" }.join("\n")
          ecrire("#{heure}  [#{File.basename(chemin)}:#{ligne}] #{ex.class} : #{ex.message.to_s[0, 300]}\n#{pile}\n")
        rescue StandardError
          nil
        end
      end
      @trace.enable
    rescue StandardError
      nil
    end

    # Commande : ouvrir le journal dans le Bloc-notes (ou dire qu'il est vide)
    def self.ouvrir
      f = fichier
      if File.exist?(f) && File.size(f) > 0
        UI.openURL("file:///#{f.tr('\\', '/')}")
      else
        UI.messagebox("Aucune erreur enregistrée pour le moment.\n\nLe journal sera écrit ici :\n#{f}")
      end
    end

    brancher_console
    brancher_trace
  end
end
