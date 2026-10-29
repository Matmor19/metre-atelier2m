# encoding: UTF-8
# Métré Atelier 2M : envoi direct de l'extraction au métré (script Google du métré), sans fichier
require 'sketchup.rb'
require 'json'
require 'net/http'
require 'uri'
require 'openssl'

module A2M
  module Envoi
    SECTION = 'A2M_Metre'

    def self.reglages
      url = Sketchup.read_default(SECTION, 'url', '').to_s
      jet = Sketchup.read_default(SECTION, 'jeton', '').to_s
      rep = UI.inputbox(['Adresse du script du métré (se termine par /exec)', 'Jeton (le même que dans les réglages du métré)'], [url, jet], 'Envoi au métré : réglages')
      return false unless rep
      Sketchup.write_default(SECTION, 'url', rep[0].to_s.strip)
      Sketchup.write_default(SECTION, 'jeton', rep[1].to_s.strip)
      true
    end

    # POST vers Apps Script, en suivant la redirection de Google (réponse lue en GET)
    def self.post(url, corps)
      uri = URI(url)
      http = Net::HTTP.new(uri.host, uri.port)
      http.use_ssl = true
      http.open_timeout = 20; http.read_timeout = 60
      req = Net::HTTP::Post.new(uri.request_uri, 'Content-Type' => 'text/plain;charset=utf-8')
      req.body = corps
      rep = http.request(req)
      5.times do
        break unless rep.is_a?(Net::HTTPRedirection)
        u = URI(rep['location'])
        h = Net::HTTP.new(u.host, u.port); h.use_ssl = true
        rep = h.request(Net::HTTP::Get.new(u.request_uri))
      end
      JSON.parse(rep.body)
    end

    def self.lancer
      url = Sketchup.read_default(SECTION, 'url', '').to_s
      if url.empty?
        return unless reglages
        url = Sketchup.read_default(SECTION, 'url', '').to_s
      end
      jet = Sketchup.read_default(SECTION, 'jeton', '').to_s
      res = A2M::Extraction.extraire
      resume = "#{res['murs'].size} mur(s), #{res['pieces'].size} pièce(s)"
      unless res['alertes'].empty?
        return unless UI.messagebox("Extraction : #{resume}\n\nÀ vérifier :\n- " + res['alertes'].first(15).join("\n- ") + "\n\nEnvoyer quand même ?", MB_YESNO) == IDYES
      end
      Sketchup.status_text = 'Envoi au métré…'
      begin
        r = post(url, JSON.generate({ 'token' => jet, 'action' => 'deposer_sketchup', 'extraction' => res }))
        if r['ok']
          UI.messagebox("Extraction envoyée au métré (#{resume}).\n\nDans le configurateur du chantier : bouton « Récupérer depuis SketchUp ».")
        else
          UI.messagebox("Le métré a refusé l'envoi : #{r['erreur']}.\nVérifiez l'adresse et le jeton (Extensions > Métré Atelier 2M > Réglages de l'envoi), et que le script du métré est à jour.")
        end
      rescue StandardError => ex
        UI.messagebox("Envoi impossible (#{ex.message}).\nVous pouvez passer par « Extraire pour le configurateur » (fichier .json).")
      end
    end
  end
end
