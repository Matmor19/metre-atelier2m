# encoding: UTF-8
# Métré Atelier 2M : nomenclature des menuiseries (repères, dimensions, caractéristiques, pièces) — pour devis, DCE, commande
# Source : la même extraction que l'envoi au métré. Sorties : tableau Excel (.csv) et page imprimable (PDF depuis le navigateur).
require 'sketchup.rb'
require 'json'
require 'cgi'
require 'tmpdir'

module A2M
  module Nomenclature
    TYPES = { 'fen' => ['F', 'Fenêtre'], 'pf' => ['PF', 'Porte-fenêtre / baie'], 'pe' => ['PE', "Porte d'entrée"], 'pi' => ['P', 'Porte intérieure'] }.freeze
    COLONNES = ['Repère', 'Type', 'Largeur (cm)', 'Hauteur (cm)', 'Matériau', 'Ouvrant', 'Vantaux', 'Vitrage', 'Fermeture', 'Quantité', 'Pièces'].freeze

    CORPS = <<~'HTML'
      <div id="tab"></div>
      <div id="bas"><div id="msg"></div>
        <button type="button" class="puce" id="csv">Excel (.csv)</button>
        <button type="button" id="go">Page imprimable / PDF</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function esc(t) { var d = document.createElement('div'); d.textContent = t == null ? '' : t; return d.innerHTML; }
      var h = '';
      if (!D.lignes.length) h = '<div class="petit" style="padding:30px 0;text-align:center">Aucune menuiserie dans le modèle. Posez-en avec « Créer une ouverture » ou la bibliothèque.</div>';
      else {
        h = '<table style="width:100%;border-collapse:collapse;font-size:12px"><tr style="color:#8a7f75;text-align:left"><th>Repère</th><th>Type et caractéristiques</th><th>Dimensions (cm)</th><th>Qté</th><th>Pièces</th></tr>';
        D.lignes.forEach(function (l) {
          var carac = [l[4], l[5], l[6], l[7], l[8]].filter(function (x) { return x; }).join(' · ');
          h += '<tr style="border-top:1px solid #e2dbd3;vertical-align:top"><td style="padding:6px 6px 6px 0"><b style="color:#E07838">' + esc(l[0]) + '</b></td><td>' + esc(l[1]) + (carac ? '<div class="petit" style="margin:2px 0 0">' + esc(carac) + '</div>' : '') + '</td><td>' + esc(l[2]) + (l[3] ? ' × ' + esc(l[3]) : '') + '</td><td><b>' + esc(l[9]) + '</b></td><td class="petit">' + esc(l[10]) + '</td></tr>';
        });
        h += '</table>';
      }
      document.getElementById('tab').innerHTML = h;
      document.getElementById('msg').textContent = D.total + ' menuiserie(s), ' + D.lignes.length + ' repère(s)';
      document.getElementById('csv').addEventListener('click', function () { sketchup.sortie('csv'); });
      document.getElementById('go').addEventListener('click', function () { sketchup.sortie('html'); });
    JS

    def self.etiquette(code, groupe)
      (A2M::Ouvertures::CHOIX_ME[groupe] || []).find { |k, _| k == code.to_s }&.last.to_s
    end

    # Lignes regroupées : même type, même taille, mêmes caractéristiques ; repères F1, F2…, P1, P2…
    def self.lignes(res)
      acc = {}
      (res['pieces'] || []).each do |pc|
        (pc['menus'] || []).each do |m|
          cle = [m['type'], m['l'], m['h'], m['choix'] || {}]
          a = (acc[cle] ||= { nb: 0, pieces: [] })
          a[:nb] += m['nb'].to_i
          a[:pieces] << "#{pc['nom']} (#{m['nb']})"
        end
        (pc['portesInt'] || []).each do |m|
          cle = ['pi', m['l'], nil, m['choix'] || {}]
          a = (acc[cle] ||= { nb: 0, pieces: [] })
          a[:nb] += m['nb'].to_i
          a[:pieces] << "#{pc['nom']} (#{m['nb']})"
        end
      end
      compte = Hash.new(0)
      acc.sort_by { |(t, l, h, _), _| [TYPES.keys.index(t) || 9, l.to_i, h.to_i] }.map do |(t, l, h, ch), a|
        pre, lib = TYPES[t] || ['?', t.to_s]
        compte[t] += 1
        f = ch['volet'] == 'non' ? 'Sans' : etiquette(ch['ferm'], 'ferm')
        [pre + compte[t].to_s, lib, l.to_s, h ? h.to_s : '', etiquette(ch['mat'], 'mat'), etiquette(ch['ouvrant'], 'ouvrant'),
         etiquette(ch['vantaux'], 'vantaux'), etiquette(ch['vitrage'], 'vitrage'), f, a[:nb].to_s, a[:pieces].join(' ; ')]
      end
    end

    def self.csv(lignes)
      q = ->(v) { '"' + v.to_s.gsub('"', '""') + '"' }
      "﻿" + ([COLONNES] + lignes).map { |l| l.map(&q).join(';') }.join("\r\n") + "\r\n"
    end

    def self.page_imprimable(lignes, titre)
      th = COLONNES.map { |c| "<th>#{CGI.escapeHTML(c)}</th>" }.join
      tr = lignes.map { |l| '<tr>' + l.map { |v| "<td>#{CGI.escapeHTML(v.to_s)}</td>" }.join + '</tr>' }.join
      "<!doctype html><html lang=\"fr\"><head><meta charset=\"utf-8\"><title>Nomenclature des menuiseries</title><style>" \
      "body{font:12px 'Segoe UI',Arial,sans-serif;color:#3C3C3C;margin:24px}h1{font-size:18px;margin:0 0 2px}.s{color:#8a7f75;margin-bottom:14px}" \
      "table{width:100%;border-collapse:collapse}th{background:#F9DCC0;text-align:left;padding:6px;border-bottom:2px solid #E07838;font-size:11px}" \
      "td{padding:6px;border-bottom:1px solid #ddd;vertical-align:top}td:first-child{font-weight:700;color:#E07838}" \
      "@media print{body{margin:10mm}}</style></head><body><h1>Nomenclature des menuiseries</h1>" \
      "<div class=\"s\">#{CGI.escapeHTML(titre)} — Atelier 2M, #{Time.now.strftime('%d/%m/%Y')}</div><table><tr>#{th}</tr>#{tr}</table>" \
      "<script>setTimeout(function(){window.print()},400)</script></body></html>"
    end

    def self.ouvrir
      res = A2M::Extraction.extraire
      lg = lignes(res)
      titre = res['modele'].to_s
      total = lg.sum { |l| l[9].to_i }
      html = A2M::Panneau.page('Nomenclature des menuiseries', 'Repères, dimensions, caractéristiques et pièces', CORPS, SCRIPT,
                               'colonnes' => COLONNES, 'lignes' => lg, 'total' => total)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : menuiseries', 'A2M_Panneau_Nomenclature', html, 560, 640)
      dlg.add_action_callback('sortie') do |_c, quoi|
        UI.start_timer(0, false) do
          nom = "menuiseries_#{titre.gsub(/[^\w\-]+/, '_')}"
          if quoi == 'csv'
            p = UI.savepanel('Enregistrer la nomenclature', '', nom + '.csv')
            next unless p
            p += '.csv' unless p.downcase.end_with?('.csv')
            File.write(p, csv(lg), mode: 'w:UTF-8')
            UI.messagebox("Nomenclature enregistrée :\n#{p}\n\nS'ouvre directement dans Excel.")
          else
            p = File.join(Dir.tmpdir, nom + '.html')
            File.write(p, page_imprimable(lg, titre), mode: 'w:UTF-8')
            UI.openURL('file:///' + p.tr('\\', '/'))
          end
        end
      end
      dlg.show
    end
  end
end
