# encoding: UTF-8
# Métré Atelier 2M : éléments communs des fenêtres à vignettes (couleurs, boutons animés, vignettes des objets de la bibliothèque)
# Codes couleur : jaune = rempli ou choisi, blanc = à choisir, bleu pâle = « aucun » (rien au métré)
require 'sketchup.rb'
require 'json'
require 'base64'
require 'cgi'

module A2M
  module Panneau
    CSS = <<~'CSS'
      :root{--o:#E07838;--g:#3C3C3C;--f:#F6F3EF;--jaune:#FFE680;--bleu:#DCEBFA;--trait:#d8d0c6}
      *{box-sizing:border-box}
      body{margin:0;padding:14px 16px 0;font:13px "Segoe UI",Arial,sans-serif;background:var(--f);color:var(--g);user-select:none}
      h1{font-size:15px;margin:0 0 2px;font-weight:600} .sous{color:#8a7f75;font-size:11.5px;margin-bottom:12px}
      h2{font-size:10.5px;letter-spacing:.06em;text-transform:uppercase;margin:14px 0 6px;color:#8a7f75;font-weight:600}
      .dims{display:grid;grid-template-columns:1fr auto 1fr;gap:8px;align-items:end}
      .dims label{display:block;font-size:11px;color:#6f665e;margin-bottom:3px}
      .dims .x{font-size:18px;padding-bottom:7px;color:#8a7f75}
      input[type=text]{width:100%;font:600 17px "Segoe UI",Arial,sans-serif;padding:7px 10px;border:2px solid var(--trait);border-radius:9px;background:#fff;color:var(--g);outline:none;text-align:center}
      input[type=text].ok{background:var(--jaune)} input[type=text]:focus{border-color:var(--o)}
      .unite{font-size:11px;color:#8a7f75;text-align:center;margin-top:2px}
      .puces{display:flex;flex-wrap:wrap;gap:7px}
      .puce{border:2px solid var(--trait);background:#fff;border-radius:999px;padding:6px 12px;cursor:pointer;font:inherit;color:inherit;transition:transform .14s cubic-bezier(.3,1.6,.5,1)}
      .puce:hover{transform:translateY(-2px);border-color:var(--o)}
      .puce.rempli{background:var(--jaune);border-color:var(--o);font-weight:600}
      .puce.aucun.rempli{background:var(--bleu);border-color:#7fb0e0;font-weight:600}
      .grille{display:grid;grid-template-columns:repeat(auto-fill,minmax(120px,1fr));gap:10px}
      .carte{display:flex;flex-direction:column;background:#fff;border:2px solid var(--trait);border-radius:12px;padding:6px;cursor:pointer;text-align:left;font:inherit;color:inherit;transition:transform .16s cubic-bezier(.3,1.6,.5,1),box-shadow .16s}
      .carte:hover{border-color:var(--o);transform:translateY(-3px) scale(1.03);box-shadow:0 6px 12px rgba(224,120,56,.35)}
      .carte .vignette{height:84px;display:flex;align-items:center;justify-content:center;background:#fafafa;border-radius:8px;overflow:hidden}
      .carte .vignette img{max-width:100%;max-height:100%;object-fit:contain}
      .carte span{margin-top:6px;font-size:12px;line-height:1.25}
      .carte.rempli{background:var(--jaune);border-color:var(--o)} .carte.rempli .vignette{background:#fff7cc}
      .carte.aucun{background:#f3f8fd} .carte.aucun.rempli{background:var(--bleu);border-color:#7fb0e0} .carte.aucun .vignette{background:transparent}
      .petit{font-size:11px;color:#8a7f75;margin-top:5px}
      .apercu{background:#fff;border:1px solid var(--trait);border-radius:12px;margin-top:12px;padding:6px}
      .apercu svg{display:block;width:100%;height:170px}
      details{margin-top:12px} summary{cursor:pointer;color:#6f665e;font-size:12px}
      details .puces{margin-bottom:6px} details h3{font-size:11.5px;font-weight:600;margin:10px 0 5px;color:#6f665e}
      #bas{position:sticky;bottom:0;background:var(--f);border-top:1px solid #e2dbd3;margin:14px -16px 0;padding:10px 16px;display:flex;align-items:center;gap:12px}
      #msg{flex:1;font-size:11.5px;color:#a8541f;min-height:15px}
      #go{background:var(--o);color:#fff;border:0;border-radius:10px;padding:10px 20px;font:600 14px "Segoe UI",Arial,sans-serif;cursor:pointer;transition:transform .14s cubic-bezier(.3,1.6,.5,1),box-shadow .14s}
      #go:hover:not(:disabled){transform:translateY(-2px) scale(1.04);box-shadow:0 6px 12px rgba(224,120,56,.45)}
      #go:disabled{background:#cfc6bc;cursor:not-allowed}
    CSS

    # Page complète : titre, sous-titre, corps, script ; __DONNEES__ du script remplacé par les données en JSON
    def self.page(titre, sous, corps, script, donnees)
      js = script.sub('__DONNEES__') { JSON.generate(donnees).gsub('</', '<\/') }
      "<!doctype html><html lang=\"fr\"><head><meta charset=\"utf-8\"><style>#{CSS}</style></head><body>" \
      "<h1>#{CGI.escapeHTML(titre)}</h1><div class=\"sous\">#{CGI.escapeHTML(sous)}</div>#{corps}<script>#{js}</script></body></html>"
    end

    # Vignette d'un objet de la bibliothèque : image PNG intégrée, ou '' si elle n'existe pas
    def self.vignette(o)
      png = File.join(A2M::Bibliotheque.dossier, o['fichier'].to_s.sub(/\.skp\z/, '.png'))
      File.exist?(png) ? "data:image/png;base64,#{Base64.strict_encode64(File.binread(png))}" : ''
    rescue StandardError
      ''
    end

    def self.fenetre(titre, cle, html, largeur, hauteur)
      dlg = UI::HtmlDialog.new(dialog_title: titre, preferences_key: cle, scrollable: true, resizable: true,
                               width: largeur, height: hauteur, min_width: 380, min_height: 480, style: UI::HtmlDialog::STYLE_DIALOG)
      dlg.set_html(html)
      dlg
    end
  end
end
