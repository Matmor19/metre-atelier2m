# encoding: UTF-8
# Métré Atelier 2M : variantes client A / B / C — trois versions du même projet dans un seul fichier.
# On sélectionne des éléments, on coche les variantes où ils apparaissent ; un clic sur A, B ou C change tout d'un coup.
# Un élément sans variante est commun à toutes (murs porteurs, structure…). Ctrl+Z annule chaque action.
require 'sketchup.rb'
require 'json'

module A2M
  module Variantes
    LETTRES = %w[A B C].freeze
    DICO = 'a2m'.freeze

    CORPS = <<~'HTML'
      <div class="petit" style="margin:0 0 10px">① Sélectionnez des éléments dans le modèle · ② cochez où ils apparaissent · ③ cliquez sur A, B ou C pour tout basculer.</div>
      <div id="rondes" style="display:flex;gap:16px;justify-content:center;margin:10px 0 4px"></div>
      <div class="petit" id="etat" style="text-align:center;margin:0 0 6px"></div>
      <h2>Ajouter la sélection à…</h2>
      <div class="puces" id="cases"></div>
      <div class="petit" id="sel"></div>
      <div style="display:flex;gap:8px;margin-top:8px;flex-wrap:wrap">
        <button type="button" class="puce rempli" id="valider">Valider</button>
        <button type="button" class="puce" id="retirer">Retirer la sélection des variantes</button>
      </div>
      <h2>Présenter</h2>
      <div style="display:flex;gap:8px;flex-wrap:wrap">
        <button type="button" class="puce" id="tout">Tout voir</button>
        <button type="button" class="puce" id="scenes">Une scène par variante</button>
      </div>
      <div class="petit" id="info"></div>
      <div id="bas"><div id="msg"></div></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      var coches = {};
      function el(id) { return document.getElementById(id); }
      function rendre() {
        var r = el('rondes'); r.innerHTML = '';
        D.lettres.forEach(function (l) {
          var b = document.createElement('button'); b.type = 'button';
          var on = D.active === l;
          b.style.cssText = 'width:74px;height:74px;border-radius:50%;border:3px solid ' + (on ? '#E07838' : '#d8d0c6') + ';background:' + (on ? '#FFE680' : '#fff') + ';font:700 28px "Segoe UI",Arial,sans-serif;color:#3C3C3C;cursor:pointer;transition:transform .16s cubic-bezier(.3,1.6,.5,1);position:relative';
          b.innerHTML = l + '<div style="font:11px \'Segoe UI\';color:#8a7f75;margin-top:-2px">' + (D.nb[l] || 0) + ' élém.</div>';
          b.addEventListener('mouseover', function () { b.style.transform = 'scale(1.1)'; }); b.addEventListener('mouseout', function () { b.style.transform = ''; });
          b.addEventListener('click', function () { sketchup.afficher(l); }); r.appendChild(b);
        });
        el('etat').textContent = D.active ? 'Variante ' + D.active + ' affichée' : 'Tout est affiché';
        var c = el('cases'); c.innerHTML = '';
        D.lettres.forEach(function (l) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (coches[l] ? ' rempli' : ''); b.textContent = (coches[l] ? '✓ ' : '') + l;
          b.addEventListener('click', function () { coches[l] = !coches[l]; rendre(); }); c.appendChild(b);
        });
        el('sel').textContent = D.selection + ' élément(s) sélectionné(s). Rien de coché = commun à toutes les variantes.';
        el('info').textContent = D.info;
      }
      el('valider').addEventListener('click', function () { sketchup.ajouter(D.lettres.filter(function (l) { return coches[l]; }).join('')); });
      el('retirer').addEventListener('click', function () { sketchup.ajouter(''); });
      el('tout').addEventListener('click', function () { sketchup.tout(); });
      el('scenes').addEventListener('click', function () { sketchup.scenes(); });
      function maj(n) { D = n; rendre(); }
      rendre();
    JS

    def self.model() Sketchup.active_model end

    def self.lettres_de(e) e.get_attribute(DICO, 'var').to_s end

    # Éléments de premier niveau portant une variante
    def self.avec_variante
      model.entities.select { |e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && !lettres_de(e).empty? }
    end

    def self.active() model.get_attribute(DICO, 'var_active').to_s end

    def self.donnees
      nb = Hash.new(0)
      avec_variante.each { |e| lettres_de(e).each_char { |c| nb[c] += 1 } }
      n = model.selection.count { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      { 'lettres' => LETTRES, 'active' => active, 'nb' => nb, 'selection' => n,
        'info' => "#{avec_variante.size} élément(s) rangé(s) en variantes. Les autres sont communs à toutes." }
    end

    def self.pousser
      @fen.execute_script("maj(#{JSON.generate(donnees).gsub('</', '<\/')})") if @fen
    end

    def self.ajouter(lettres)
      sel = model.selection.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      return UI.messagebox('Sélectionnez d\'abord des groupes ou composants dans le modèle.') if sel.empty?
      model.start_operation('Variantes Atelier 2M', true)
      sel.each do |e|
        if lettres.empty? then e.delete_attribute(DICO, 'var') else e.set_attribute(DICO, 'var', lettres) end
        e.visible = true
      end
      model.commit_operation
      afficher(active) unless active.empty?
      pousser
    end

    # Affiche la variante : les éléments qui n'en font pas partie sont masqués
    def self.afficher(lettre)
      model.start_operation('Afficher la variante ' + lettre.to_s, true)
      avec_variante.each { |e| e.visible = lettres_de(e).include?(lettre.to_s) }
      model.set_attribute(DICO, 'var_active', lettre.to_s)
      model.commit_operation
      Sketchup.status_text = "Variante #{lettre} affichée"
      pousser
    end

    def self.tout_voir
      model.start_operation('Tout afficher', true)
      avec_variante.each { |e| e.visible = true }
      model.set_attribute(DICO, 'var_active', '')
      model.commit_operation
      pousser
    end

    # Une scène par variante, depuis la vue actuelle
    def self.scenes
      return UI.messagebox('Aucun élément n\'est rangé en variante.') if avec_variante.empty?
      avant = active
      model.start_operation('Scènes des variantes', true)
      LETTRES.each do |l|
        next unless avec_variante.any? { |e| lettres_de(e).include?(l) }
        avec_variante.each { |e| e.visible = lettres_de(e).include?(l) }
        nom = "A2M – Variante #{l}"
        (model.pages[nom] || model.pages.add(nom)).update
      end
      avec_variante.each { |e| e.visible = avant.empty? || lettres_de(e).include?(avant) }
      model.commit_operation
      UI.messagebox('Les scènes « A2M – Variante A / B / C » sont créées. Cliquez sur une scène pour voir la variante.')
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        pousser
        return
      end
      html = A2M::Panneau.page('Variantes client', 'Trois versions du même projet dans un seul fichier', CORPS, SCRIPT, donnees)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : variantes', 'A2M_Panneau_Variantes', html, 420, 620)
      @fen = dlg
      dlg.add_action_callback('afficher') { |_c, l| UI.start_timer(0, false) { afficher(l) } }
      dlg.add_action_callback('ajouter') { |_c, l| UI.start_timer(0, false) { ajouter(l.to_s) } }
      dlg.add_action_callback('tout') { |_c| UI.start_timer(0, false) { tout_voir } }
      dlg.add_action_callback('scenes') { |_c| UI.start_timer(0, false) { scenes } }
      @veilleur ||= Class.new(Sketchup::SelectionObserver) do
        def onSelectionBulkChange(_s) A2M::Variantes.pousser end
        def onSelectionCleared(_s) A2M::Variantes.pousser end
      end.new
      model.selection.add_observer(@veilleur) rescue nil
      dlg.set_on_closed { model.selection.remove_observer(@veilleur) rescue nil; @fen = nil }
      dlg.show
    end
  end
end
