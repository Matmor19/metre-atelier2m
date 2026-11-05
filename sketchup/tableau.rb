# encoding: UTF-8
# Métré Atelier 2M : tableau de bord du modèle — métré en direct + points à vérifier, dans une seule fenêtre
# Les chiffres viennent de la même extraction que celle envoyée au métré : ce que vous voyez ici est ce qui partira.
require 'sketchup.rb'
require 'json'

module A2M
  module Tableau
    CORPS = <<~'HTML'
      <div style="display:flex;gap:8px;align-items:center;margin-bottom:6px">
        <button type="button" class="puce" id="actu">↻ Actualiser</button>
        <button type="button" class="puce rempli" id="auto">Mise à jour automatique</button>
        <span class="petit" id="heure" style="margin:0 0 0 auto"></span>
      </div>
      <h2>Contrôle avant métré</h2>
      <div id="controle"></div>
      <h2>Métré en direct</h2>
      <div class="grille" id="cartes"></div>
      <h2>Par pièce</h2>
      <div id="pieces"></div>
      <div id="infos"></div>
      <div id="bas">
        <div id="msg"></div>
        <button type="button" class="puce" id="extraire">Enregistrer le fichier</button>
        <button type="button" id="go">Envoyer au métré</button>
      </div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      var auto = true;
      function esc(t) { var d = document.createElement('div'); d.textContent = t; return d.innerHTML; }
      function nb(x) { return (Math.round(x * 100) / 100).toLocaleString('fr-FR'); }
      function rendre() {
        el('heure').textContent = D.heure ? 'à ' + D.heure : '';
        var c = el('controle');
        if (!D.problemes.length) c.innerHTML = '<div class="apercu" style="margin:0;padding:10px 12px;background:#f3faf0;border-color:#bcdcae">✔ Aucun point à vérifier : le modèle est prêt à partir au métré.</div>';
        else {
          c.innerHTML = '<div class="petit" style="margin:0 0 6px">' + D.problemes.length + ' point(s) à vérifier — cliquez pour voir l\'élément dans le modèle</div>';
          D.problemes.slice(0, 40).forEach(function (p, i) {
            var b = document.createElement('button'); b.type = 'button'; b.className = 'puce'; b.style.cssText = 'display:block;width:100%;text-align:left;border-radius:9px;margin-bottom:5px;background:#FFF4DC';
            b.textContent = '⚠ ' + p; b.addEventListener('click', function () { sketchup.voir(i); }); c.appendChild(b);
          });
          if (D.problemes.length > 40) c.insertAdjacentHTML('beforeend', '<div class="petit">… et ' + (D.problemes.length - 40) + ' autre(s)</div>');
        }
        var g = el('cartes'); g.innerHTML = '';
        D.cartes.forEach(function (k) {
          var d = document.createElement('div'); d.className = 'carte'; d.style.cursor = 'default';
          d.innerHTML = '<div style="font-size:22px;font-weight:600;color:#E07838">' + esc(k[1]) + '</div><span>' + esc(k[0]) + '</span>' + (k[2] ? '<div class="petit">' + esc(k[2]) + '</div>' : '');
          g.appendChild(d);
        });
        if (!D.cartes.length) g.innerHTML = '<div class="petit">Rien de balisé pour le moment : dessinez avec les outils Atelier 2M.</div>';
        var p = el('pieces');
        if (!D.pieces.length) p.innerHTML = '<div class="petit">Aucune pièce (balise A2M_PIECE).</div>';
        else {
          var h = '<table style="width:100%;border-collapse:collapse;font-size:12px"><tr style="color:#8a7f75;text-align:left"><th>Pièce</th><th>m²</th><th>Fen.</th><th>Portes</th><th>Élec.</th></tr>';
          D.pieces.forEach(function (x) { h += '<tr style="border-top:1px solid #e2dbd3"><td style="padding:5px 0">' + esc(x.nom) + '</td><td>' + nb(x.surf) + '</td><td>' + x.fen + '</td><td>' + x.portes + '</td><td>' + x.elec + '</td></tr>'; });
          p.innerHTML = h + '</table>';
        }
        el('infos').innerHTML = D.infos.length ? '<h2>À reporter à la main</h2><div class="petit" style="margin:0">' + D.infos.map(esc).join('<br>') + '</div>' : '';
        el('msg').textContent = D.problemes.length ? 'Corrigez ou envoyez quand même' : 'Tout est prêt';
        el('auto').className = 'puce' + (auto ? ' rempli' : '');
      }
      el('actu').addEventListener('click', function () { sketchup.actualiser(); });
      el('auto').addEventListener('click', function () { auto = !auto; sketchup.auto(auto ? 1 : 0); rendre(); });
      el('extraire').addEventListener('click', function () { sketchup.action('extraire'); });
      el('go').addEventListener('click', function () { sketchup.action('envoi'); });
      function maj(n) { D = n; rendre(); }
      function auto_off() { auto = false; rendre(); }
      rendre();
    JS

    class Veilleur < Sketchup::ModelObserver
      def onTransactionCommit(_m) A2M::Tableau.demander_maj end
      def onTransactionUndo(_m) A2M::Tableau.demander_maj end
      def onTransactionRedo(_m) A2M::Tableau.demander_maj end
    end

    # Données du tableau de bord : extraction + contrôle
    def self.donnees
      res = A2M::Extraction.extraire
      pb, = A2M::Controle.problemes
      @pb = pb
      murs = res['murs']
      ml = murs.sum { |m| m['longueur'].to_f }
      m2 = murs.sum { |m| m['longueur'].to_f * m['hauteur'].to_f }
      pieces = res['pieces']
      fen = pieces.sum { |p| p['menus'].sum { |x| x['nb'] } }
      portes = pieces.sum { |p| p['portesInt'].sum { |x| x['nb'] } }
      cartes = []
      cartes << ['Murs', "#{nb(ml)} ml", "#{nb(m2)} m² de façade brute (#{murs.size} mur(s))"] unless murs.empty?
      cartes << ['Pièces', "#{nb(pieces.sum { |p| p['surf'].to_f })} m²", "#{pieces.size} pièce(s)"] unless pieces.empty?
      cartes << ['Menuiseries extérieures', fen.to_s, 'fenêtres, portes-fenêtres, portes d\'entrée'] if fen > 0
      cartes << ['Portes intérieures', portes.to_s, nil] if portes > 0
      pl = res['plancher']
      cartes << ['Plancher', "#{nb(pl['brut'] || pl['surface'])} m²", pl['brut'] ? 'dallage' : 'plancher d\'étage'] if pl['brut'] || pl['surface']
      t = res['toiture']
      cartes << ['Couverture', "#{nb(t['surfCouv'])} m²", "pente #{t['pente']} %"] if t['surfCouv']
      cartes << ['Cloisons', "#{nb(res['plat']['cloi_ml'])} ml", nil] if res['plat']['cloi_ml']
      cartes << ['Doublage', "#{nb(res['plat']['doub_ml'])} ml", nil] if res['plat']['doub_ml']
      f = res['fond']
      cartes << ['Fouilles en rigoles', "#{nb(f['rigLin'])} ml", nil] if f['rigLin']
      lignes = pieces.map do |p|
        { 'nom' => p['nom'], 'surf' => p['surf'].to_f, 'fen' => p['menus'].sum { |x| x['nb'] }, 'portes' => p['portesInt'].sum { |x| x['nb'] }, 'elec' => (p['app'] || {}).values.sum }
      end
      infos = (res['infos'] || {}).map { |k, v| "#{k.tr('_', ' ')} : #{v}#{v.is_a?(Numeric) ? ' m²' : ''}" }
      { 'cartes' => cartes, 'pieces' => lignes, 'infos' => infos + res['alertes'].map { |a| '⚠ ' + a },
        'problemes' => pb.map { |m, _| m }, 'heure' => Time.now.strftime('%H:%M:%S') }
    end

    def self.nb(x) x.to_f.round(2).to_s.sub('.', ',') end

    def self.rafraichir
      return unless @fen && (@fen.visible? rescue false)
      t0 = Time.now
      d = donnees
      @fen.execute_script("maj(#{JSON.generate(d).gsub('</', '<\/')})")
      if Time.now - t0 > 2.0 && @auto
        @auto = false
        @fen.execute_script('auto_off()')
      end
    rescue StandardError => ex
      @fen.execute_script("document.getElementById('msg').textContent=#{JSON.generate('Calcul impossible : ' + ex.message)}") rescue nil
    end

    def self.demander_maj
      return unless @auto && @fen
      UI.stop_timer(@minuteur) if @minuteur
      @minuteur = UI.start_timer(1.5, false) { rafraichir }
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        rafraichir
        return
      end
      @auto = true
      html = A2M::Panneau.page('Tableau de bord du modèle', 'Contrôle et métré en direct, avant envoi au métré', CORPS, SCRIPT,
                               'cartes' => [], 'pieces' => [], 'infos' => [], 'problemes' => [], 'heure' => '')
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : tableau de bord', 'A2M_Panneau_Tableau', html, 480, 760)
      @fen = dlg
      @veilleur ||= Veilleur.new
      Sketchup.active_model.add_observer(@veilleur) rescue nil
      dlg.add_action_callback('actualiser') { |_c| UI.start_timer(0, false) { rafraichir } }
      dlg.add_action_callback('auto') { |_c, v| @auto = v.to_i == 1; rafraichir if @auto }
      dlg.add_action_callback('voir') do |_c, i|
        e = (@pb || [])[i.to_i] && @pb[i.to_i][1]
        if e && e.valid?
          m = Sketchup.active_model
          m.selection.clear
          m.selection.add(e)
          m.active_view.zoom(e) rescue nil
        end
      end
      dlg.add_action_callback('action') do |_c, a|
        UI.start_timer(0, false) do
          a == 'envoi' ? A2M::Envoi.lancer : A2M::Extraction.lancer
          rafraichir
        end
      end
      dlg.set_on_closed do
        Sketchup.active_model.remove_observer(@veilleur) rescue nil
        @fen = nil
      end
      dlg.show
      UI.start_timer(0.6, false) { rafraichir }
    end
  end
end
