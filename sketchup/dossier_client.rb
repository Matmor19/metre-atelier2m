# encoding: UTF-8
# Métré Atelier 2M : dossier de présentation client — vues du modèle, surfaces par pièce, menuiseries, en une page imprimable / PDF
# Les vues sont celles des scènes du modèle (celles créées par « Vues prêtes à l'emploi » ou les vôtres) ; les chiffres viennent de l'extraction du métré.
require 'sketchup.rb'
require 'json'
require 'cgi'
require 'base64'
require 'tmpdir'

module A2M
  module DossierClient
    CONTACT = ['Atelier 2M · Dessin d\'architecture', '29 avenue Thiers, 19100 Brive-la-Gaillarde', '06 59 98 68 81 · contact@atelier2m.com', 'www.atelier2m.com'].freeze

    CORPS = <<~'HTML'
      <h2>Projet</h2>
      <div style="display:grid;gap:8px">
        <input type="text" id="projet" placeholder="Nom du projet" style="text-align:left;font:600 15px 'Segoe UI',Arial,sans-serif;padding:8px 12px">
        <input type="text" id="client" placeholder="Client (facultatif)" style="text-align:left;font:13px 'Segoe UI',Arial,sans-serif;padding:8px 12px">
      </div>
      <h2>Vues à présenter</h2>
      <div class="puces" id="scenes"></div>
      <div class="petit" id="aucune"></div>
      <h2>Contenu</h2>
      <div class="puces" id="parts"></div>
      <div id="bas"><div id="msg"></div><button type="button" id="go">Créer le dossier</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      el('projet').value = D.projet;
      var choix = {}; D.scenes.forEach(function (s) { choix[s] = s.indexOf('A2M') === 0; });
      var parts = { surfaces: true, menuiseries: true, synthese: true };
      var noms = { surfaces: 'Surfaces par pièce', menuiseries: 'Menuiseries', synthese: 'Synthèse du métré' };
      function rendre() {
        var s = el('scenes'); s.innerHTML = '';
        D.scenes.forEach(function (n) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (choix[n] ? ' rempli' : ''); b.textContent = n;
          b.addEventListener('click', function () { choix[n] = !choix[n]; rendre(); }); s.appendChild(b);
        });
        el('aucune').textContent = D.scenes.length ? '' : 'Aucune scène dans le modèle : créez-les avec « Vues prêtes à l\'emploi ».';
        var p = el('parts'); p.innerHTML = '';
        Object.keys(parts).forEach(function (k) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (parts[k] ? ' rempli' : ''); b.textContent = noms[k];
          b.addEventListener('click', function () { parts[k] = !parts[k]; rendre(); }); p.appendChild(b);
        });
        var n = Object.keys(choix).filter(function (k) { return choix[k]; }).length;
        el('msg').textContent = n + ' vue(s)';
      }
      el('go').addEventListener('click', function () {
        sketchup.creer(JSON.stringify({ projet: el('projet').value, client: el('client').value, scenes: Object.keys(choix).filter(function (k) { return choix[k]; }), parts: parts }));
      });
      rendre();
    JS

    def self.esc(t) CGI.escapeHTML(t.to_s) end
    def self.nb(x) x.to_f.round(2).to_s.sub('.', ',') end

    # Page complète du dossier (images en base64 : un seul fichier)
    def self.page(projet, client, images, res, lignes, parts)
      pieces = res['pieces'] || []
      murs = res['murs'] || []
      html = +"<!doctype html><html lang=\"fr\"><head><meta charset=\"utf-8\"><title>#{esc(projet)} — Dossier de présentation</title><style>"
      html << "@page{size:A4;margin:14mm}*{box-sizing:border-box}body{font:12.5px 'Segoe UI',Arial,sans-serif;color:#3C3C3C;margin:0;background:#fff}" \
              ".page{page-break-after:always;min-height:260mm;position:relative}.page:last-child{page-break-after:auto}" \
              ".bandeau{background:#F9DCC0;border-bottom:3px solid #E07838;padding:34mm 12mm 14mm}.bandeau h1{font-size:30px;margin:0 0 6px;letter-spacing:.01em}.bandeau .c{font-size:15px;color:#6f665e}" \
              ".marque{display:flex;align-items:center;gap:10px;padding:8mm 12mm 0}.marque b{font-size:15px}.marque span{color:#8a7f75;font-size:11px;display:block}" \
              "h2{font-size:16px;margin:0 0 10px;padding-bottom:5px;border-bottom:2px solid #E07838}.contenu{padding:6mm 12mm}" \
              ".vues{display:grid;grid-template-columns:1fr;gap:10px}.vue{break-inside:avoid}.vue img{width:100%;border:1px solid #ddd;border-radius:4px}.vue div{font-size:11px;color:#8a7f75;margin-top:3px}" \
              "table{width:100%;border-collapse:collapse}th{background:#F9DCC0;text-align:left;padding:6px;font-size:11px;border-bottom:2px solid #E07838}td{padding:6px;border-bottom:1px solid #e5e0da}" \
              ".cartes{display:grid;grid-template-columns:repeat(3,1fr);gap:10px;margin-bottom:14px}.k{border:1px solid #e5e0da;border-radius:8px;padding:10px}.k b{display:block;font-size:20px;color:#E07838}.k span{font-size:11px;color:#6f665e}" \
              ".pied{position:absolute;bottom:0;left:12mm;right:12mm;font-size:10px;color:#8a7f75;border-top:1px solid #ddd;padding-top:4px}</style></head><body>"
      logo = '<svg viewBox="0 0 28 24" width="34" height="29"><path d="M3 21 V4 L14 15" fill="none" stroke="#6B6B6B" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/><path d="M14 15 L25 4 V21" fill="none" stroke="#E07838" stroke-width="2.4" stroke-linecap="round" stroke-linejoin="round"/></svg>'
      pied = "<div class=\"pied\">#{esc(CONTACT.join(' — '))}</div>"
      html << "<div class=\"page\"><div class=\"marque\">#{logo}<div><b>#{esc(CONTACT[0])}</b><span>#{esc(CONTACT[1])}</span></div></div>" \
              "<div class=\"bandeau\"><h1>#{esc(projet)}</h1>#{client.to_s.strip.empty? ? '' : "<div class=\"c\">Client : #{esc(client)}</div>"}<div class=\"c\">Dossier de présentation — #{Time.now.strftime('%d/%m/%Y')}</div></div>#{pied}</div>"
      images.each_slice(2) do |duo|
        html << '<div class="page"><div class="contenu"><h2>Vues du projet</h2><div class="vues">'
        duo.each { |nom, b64| html << "<div class=\"vue\"><img alt=\"#{esc(nom)}\" src=\"data:image/png;base64,#{b64}\"><div>#{esc(nom)}</div></div>" }
        html << "</div></div>#{pied}</div>"
      end
      if parts['surfaces'] && !pieces.empty?
        html << '<div class="page"><div class="contenu"><h2>Surfaces par pièce</h2><table><tr><th>Pièce</th><th>Surface (m²)</th><th>Périmètre (m)</th></tr>'
        pieces.each { |p| html << "<tr><td>#{esc(p['nom'])}</td><td>#{nb(p['surf'])}</td><td>#{nb(p['perim'])}</td></tr>" }
        html << "<tr><td><b>Total</b></td><td><b>#{nb(pieces.sum { |p| p['surf'].to_f })}</b></td><td></td></tr></table></div>#{pied}</div>"
      end
      if parts['menuiseries'] && !lignes.empty?
        html << '<div class="page"><div class="contenu"><h2>Menuiseries</h2><table><tr><th>Repère</th><th>Type</th><th>Dimensions (cm)</th><th>Caractéristiques</th><th>Qté</th></tr>'
        lignes.each do |l|
          carac = [l[4], l[5], l[6], l[7], l[8]].reject { |x| x.to_s.empty? }.join(' · ')
          html << "<tr><td><b style=\"color:#E07838\">#{esc(l[0])}</b></td><td>#{esc(l[1])}</td><td>#{esc(l[2])}#{l[3].to_s.empty? ? '' : ' × ' + esc(l[3])}</td><td>#{esc(carac)}</td><td>#{esc(l[9])}</td></tr>"
        end
        html << "</table></div>#{pied}</div>"
      end
      if parts['synthese']
        ml = murs.sum { |m| m['longueur'].to_f }
        k = []
        k << ['Murs', "#{nb(ml)} ml"] unless murs.empty?
        k << ['Surface des pièces', "#{nb(pieces.sum { |p| p['surf'].to_f })} m²"] unless pieces.empty?
        k << ['Couverture', "#{nb(res['toiture']['surfCouv'])} m²"] if res['toiture'] && res['toiture']['surfCouv']
        k << ['Plancher', "#{nb(res['plancher']['brut'] || res['plancher']['surface'])} m²"] if res['plancher'] && (res['plancher']['brut'] || res['plancher']['surface'])
        k << ['Cloisons', "#{nb(res['plat']['cloi_ml'])} ml"] if res['plat'] && res['plat']['cloi_ml']
        unless k.empty?
          html << '<div class="page"><div class="contenu"><h2>Synthèse du projet</h2><div class="cartes">'
          k.each { |t, v| html << "<div class=\"k\"><b>#{esc(v)}</b><span>#{esc(t)}</span></div>" }
          html << "</div></div>#{pied}</div>"
        end
      end
      html << '<script>if(location.search.indexOf("pdf")>=0)setTimeout(function(){window.print()},500)</script></body></html>'
    end

    # Image de chaque scène demandée ; la scène active est rétablie ensuite
    def self.images(noms)
      model = Sketchup.active_model
      view = model.active_view
      avant = model.pages.selected_page
      dossier = Dir.mktmpdir('a2m_dossier')
      res = []
      noms.each do |n|
        page = model.pages[n]
        next unless page
        model.pages.selected_page = page
        f = File.join(dossier, "v#{res.size}.png")
        view.write_image(filename: f, width: 1600, height: 1000, antialias: true, transparent: false)
        res << [n, Base64.strict_encode64(File.binread(f))] if File.exist?(f)
      end
      model.pages.selected_page = avant if avant
      res
    end

    def self.creer(r)
      projet = r['projet'].to_s.strip.empty? ? 'Projet' : r['projet'].to_s.strip
      imgs = images(r['scenes'] || [])
      res = A2M::Extraction.extraire
      lignes = A2M::Nomenclature.lignes(res)
      html = page(projet, r['client'], imgs, res, lignes, r['parts'] || {})
      nom = "dossier_#{projet.gsub(/[^\w\-]+/, '_')}.html"
      p = UI.savepanel('Enregistrer le dossier de présentation', '', nom)
      return unless p
      p += '.html' unless p.downcase.end_with?('.html')
      File.write(p, html, mode: 'w:UTF-8')
      UI.openURL('file:///' + p.tr('\\', '/') + '?pdf')
    end

    def self.ouvrir
      model = Sketchup.active_model
      html = A2M::Panneau.page('Dossier de présentation client', 'Vues, surfaces et menuiseries en un document prêt à imprimer ou à enregistrer en PDF', CORPS, SCRIPT,
                               'projet' => (model.title.to_s.empty? ? 'Projet' : model.title), 'scenes' => model.pages.map(&:name))
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : dossier client', 'A2M_Panneau_Dossier', html, 480, 620)
      dlg.add_action_callback('creer') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) do
          begin
            creer(r) if r
          rescue StandardError => ex
            UI.messagebox("Dossier impossible : #{ex.message}")
          end
        end
      end
      dlg.show
    end
  end
end
