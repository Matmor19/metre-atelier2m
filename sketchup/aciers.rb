# encoding: UTF-8
# Métré Atelier 2M : liste des aciers de tout le modèle (par ouvrage et par diamètre), avec le nombre de barres de 12 m à commander.
require 'sketchup.rb'
require 'json'
require 'csv'

module A2M
  module Aciers
    CORPS = <<~'HTML'
      <div id="tab">Calcul…</div>
      <div class="petit" style="margin-top:8px">Barres vendues en 12 m ; le nombre à commander est arrondi à la barre supérieure (hors chutes). Les kilos viennent des mètres posés (recouvrements et crochets compris si choisis).</div>
      <div id="bas"><div id="msg"></div><button type="button" class="puce" id="csv">Enregistrer en CSV</button><button type="button" id="act">↻ Actualiser</button></div>
    HTML
    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(i) { return document.getElementById(i); }
      function f(x, n) { return Number(x).toFixed(n).replace('.', ','); }
      function rendre(d) {
        if (!d.lignes.length) { el('tab').textContent = 'Aucun ferraillage dans le modèle : posez-en avec l’outil Ferraillage ou l’escalier béton.'; return; }
        var h = '<h2>Par ouvrage</h2><table style="width:100%;font-size:13px;border-collapse:collapse"><tr><th align=left>Ouvrage</th><th align=left>Ø</th><th align=right>Mètres</th><th align=right>Kilos</th></tr>';
        d.lignes.forEach(function (l) { h += '<tr><td>' + l.nom + '</td><td>' + l.d + '</td><td align=right>' + f(l.ml, 1) + '</td><td align=right>' + f(l.kg, 1) + '</td></tr>'; });
        h += '</table><h2>À commander</h2><table style="width:100%;font-size:13px;border-collapse:collapse"><tr><th align=left>Diamètre</th><th align=right>Mètres</th><th align=right>Kilos</th><th align=right>Barres de 12 m</th></tr>';
        d.totaux.forEach(function (t) { h += '<tr><td>Ø ' + t.d + ' mm</td><td align=right>' + f(t.ml, 1) + '</td><td align=right>' + f(t.kg, 1) + '</td><td align=right><b>' + t.barres + '</b></td></tr>'; });
        h += '<tr><td><b>Total</b></td><td align=right><b>' + f(d.ml, 1) + '</b></td><td align=right><b>' + f(d.kg, 1) + '</b></td><td></td></tr></table>';
        el('tab').innerHTML = h;
      }
      el('act').onclick = function () { sketchup.actualiser(''); };
      el('csv').onclick = function () { sketchup.csv(''); };
      sketchup.pret('');
    JS

    def self.collecter(ents, lignes, prof = 0)
      ents.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        j = e.get_attribute(A2M::Ferraillage::DICO, 'detail')
        if j
          nom = e.name.to_s.sub(/\s*\(\d+ kg\)\z/, '')
          JSON.parse(j).each { |x| lignes << { 'nom' => nom, 'd' => x['d'], 'ml' => x['ml'], 'kg' => x['kg'] } }
        elsif prof < 3
          collecter(e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities, lignes, prof + 1)
        end
      end
    end

    def self.donnees
      lignes = []
      collecter(Sketchup.active_model.entities, lignes)
      par = Hash.new { |h, k| h[k] = [0.0, 0.0] }
      lignes.each { |l| par[l['d']][0] += l['ml']; par[l['d']][1] += l['kg'] }
      totaux = par.sort.map { |d, (ml, kg)| { 'd' => d, 'ml' => ml.round(2), 'kg' => kg.round(2), 'barres' => (ml / A2M::Ferraillage::LONG_BARRE).ceil } }
      { 'lignes' => lignes, 'totaux' => totaux, 'ml' => totaux.sum { |t| t['ml'] }.round(2), 'kg' => totaux.sum { |t| t['kg'] }.round(2) }
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        envoyer
        @fen.bring_to_front
        return
      end
      html = A2M::Panneau.page('Liste des aciers', 'Tous les ferraillages du modèle, par ouvrage et par diamètre', CORPS, SCRIPT, {})
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : liste des aciers', 'A2M_Panneau_Aciers', html, 520, 700)
      @fen = dlg
      dlg.add_action_callback('pret') { |_c, _j| UI.start_timer(0, false) { envoyer } }
      dlg.add_action_callback('actualiser') { |_c, _j| UI.start_timer(0, false) { envoyer } }
      dlg.add_action_callback('csv') { |_c, _j| UI.start_timer(0, false) { enregistrer } }
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end

    def self.envoyer
      @fen.execute_script("rendre(#{JSON.generate(donnees)})") if @fen && (@fen.visible? rescue false)
    end

    def self.enregistrer
      d = donnees
      return UI.messagebox('Aucun ferraillage dans le modèle.') if d['lignes'].empty?
      chemin = UI.savepanel('Enregistrer la liste des aciers', '', 'liste_aciers.csv')
      return unless chemin
      chemin += '.csv' unless chemin.downcase.end_with?('.csv')
      File.open(chemin, 'w:UTF-8') do |f|
        f.write("﻿")
        f.puts(['Ouvrage', 'Diamètre (mm)', 'Mètres', 'Kilos'].join(';'))
        d['lignes'].each { |l| f.puts([l['nom'], l['d'], l['ml'].to_s.tr('.', ','), l['kg'].to_s.tr('.', ',')].join(';')) }
        f.puts
        f.puts(['À commander', 'Diamètre (mm)', 'Mètres', 'Kilos', 'Barres de 12 m'].join(';'))
        d['totaux'].each { |t| f.puts(['', t['d'], t['ml'].to_s.tr('.', ','), t['kg'].to_s.tr('.', ','), t['barres']].join(';')) }
      end
      Sketchup.status_text = "Liste des aciers enregistrée : #{chemin}"
    end
  end
end
