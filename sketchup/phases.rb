# encoding: UTF-8
# Métré Atelier 2M : phases du projet (existant / à démolir / à construire) — code couleur des dossiers de rénovation
# La phase est mémorisée sur chaque groupe ou composant ; la couleur est facultative et réversible ; le métré n'est pas touché.
require 'sketchup.rb'
require 'json'

module A2M
  module Phases
    DICO = 'a2m'
    # [clé, libellé, aide, couleur RVB, nom de la matière]
    LISTE = [
      ['existant',  'Existant conservé', 'Gris : ce qui reste tel quel',            [190, 190, 190], 'A2M phase existant'],
      ['demolition', 'À démolir',        'Rouge : ce qui disparaît',                [214, 40, 40],   'A2M phase démolition'],
      ['neuf',      'À construire',      'Bleu : ce qui est créé',                  [40, 110, 210],  'A2M phase construction']
    ].freeze
    VUES = [
      ['tout',    'Tout afficher',      'Les trois phases ensemble'],
      ['etat',    'État existant',      'Existant + à démolir (sans le neuf)'],
      ['demol',   'Démolition',         'Existant + à démolir'],
      ['projet',  'Projet fini',        'Existant conservé + à construire']
    ].freeze

    CORPS = <<~'HTML'
      <h2>1. Choisir des éléments dans le modèle</h2>
      <div class="petit" id="nbsel" style="margin:0 0 4px"></div>
      <h2>2. Leur phase</h2>
      <div class="grille" id="phases"></div>
      <div class="puces" style="margin-top:10px"><button type="button" class="puce rempli" id="col">Colorier selon la phase</button><button type="button" class="puce" id="raz">Retirer la phase</button></div>
      <h2>Le curseur Avant / Après</h2>
      <div style="background:#fff;border:2px solid #d8d0c6;border-radius:12px;padding:12px 14px">
        <input type="range" id="cur" min="0" max="2" step="1" value="1" style="width:100%;accent-color:#E07838">
        <div style="display:flex;justify-content:space-between;font-size:11.5px;margin-top:2px"><span style="color:#8a8a8a;font-weight:600">Avant</span><span style="color:#D62828;font-weight:600">Pendant</span><span style="color:#286ED2;font-weight:600">Après</span></div>
        <div class="petit" id="curinfo" style="margin:6px 0 0;text-align:center">Faites glisser : l'existant, les travaux, puis le projet fini</div>
      </div>
      <h2>3. Afficher</h2>
      <div class="grille" id="vues"></div>
      <div id="bas"><div id="msg"></div><button type="button" class="puce" id="actu">↻ Actualiser</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__, colorier = true;
      function el(id) { return document.getElementById(id); }
      function rendre() {
        el('nbsel').textContent = D.nb + ' élément(s) sélectionné(s) · phases déjà posées : ' + D.comptes.map(function (c) { return c[0] + ' ' + c[1]; }).join(', ');
        var g = el('phases'); g.innerHTML = '';
        D.phases.forEach(function (p) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte';
          b.innerHTML = '<div class="vignette" style="background:rgb(' + p.rvb.join(',') + ')"></div><span></span><div class="petit" style="margin:2px 0 0"></div>';
          b.querySelector('span').textContent = p.libelle; b.querySelector('.petit').textContent = p.aide;
          b.addEventListener('click', function () { sketchup.poser(JSON.stringify({ phase: p.cle, colorier: colorier })); }); g.appendChild(b);
        });
        var v = el('vues'); v.innerHTML = '';
        D.vues.forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte' + (D.vue === x.cle ? ' rempli' : '');
          b.innerHTML = '<span></span><div class="petit" style="margin:2px 0 0"></div>'; b.querySelector('span').textContent = x.libelle; b.querySelector('.petit').textContent = x.aide;
          b.addEventListener('click', function () { sketchup.afficher(x.cle); }); v.appendChild(b);
        });
        el('col').className = 'puce' + (colorier ? ' rempli' : '');
        el('msg').textContent = D.msg || '';
      }
      var minut = null, CUR = ['etat', 'tout', 'projet'], INFO = ['État existant : ce qui reste et ce qui va disparaître', 'Pendant les travaux : tout est visible, démolition en rouge, neuf en bleu', 'Projet fini : l\'existant conservé et le neuf'];
      el('cur').addEventListener('input', function () {
        var v = parseInt(el('cur').value, 10); el('curinfo').textContent = INFO[v];
        clearTimeout(minut); minut = setTimeout(function () { sketchup.afficher(CUR[v]); }, 120);
      });
      el('col').addEventListener('click', function () { colorier = !colorier; rendre(); });
      el('raz').addEventListener('click', function () { sketchup.poser(JSON.stringify({ phase: '', colorier: true })); });
      el('actu').addEventListener('click', function () { sketchup.actualiser(); });
      function maj(n) { D = n; rendre(); }
      rendre();
    JS

    def self.elements(ents = Sketchup.active_model.entities)
      ents.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
    end

    def self.matiere(model, l)
      m = model.materials[l[4]] || model.materials.add(l[4])
      m.color = Sketchup::Color.new(*l[3])
      m
    end

    # Pose (ou retire, si phase vide) la phase sur la sélection
    def self.poser(phase, colorier)
      model = Sketchup.active_model
      sel = elements(model.selection)
      return 0 if sel.empty?
      model.start_operation('Phase du projet', true)
      sel.each do |e|
        # Matière d'origine mémorisée une seule fois, pour pouvoir tout rétablir
        if e.get_attribute(DICO, 'mat_avant').nil?
          e.set_attribute(DICO, 'mat_avant', e.material ? e.material.name : '')
        end
        if phase.to_s.empty?
          e.delete_attribute(DICO, 'phase')
          av = e.get_attribute(DICO, 'mat_avant').to_s
          e.material = av.empty? ? nil : model.materials[av]
          e.delete_attribute(DICO, 'mat_avant')
        else
          e.set_attribute(DICO, 'phase', phase)
          l = LISTE.find { |x| x[0] == phase }
          e.material = matiere(model, l) if colorier && l
        end
        e.visible = true
      end
      model.commit_operation
      sel.size
    end

    # Masque ce qui n'appartient pas à la vue choisie
    def self.afficher(vue)
      model = Sketchup.active_model
      model.start_operation('Afficher une phase', true)
      elements.each do |e|
        ph = e.get_attribute(DICO, 'phase').to_s
        e.visible = case vue
                    when 'etat', 'demol' then ph != 'neuf'
                    when 'projet' then ph != 'demolition'
                    else true
                    end
      end
      model.commit_operation
      @vue = vue
    end

    def self.donnees(msg = nil)
      cpt = Hash.new(0)
      elements.each { |e| ph = e.get_attribute(DICO, 'phase').to_s; cpt[ph] += 1 unless ph.empty? }
      { 'nb' => elements(Sketchup.active_model.selection).size,
        'comptes' => LISTE.map { |k, l, *| [l.downcase, cpt[k]] },
        'phases' => LISTE.map { |k, l, a, rvb, _| { 'cle' => k, 'libelle' => l, 'aide' => a, 'rvb' => rvb } },
        'vues' => VUES.map { |k, l, a| { 'cle' => k, 'libelle' => l, 'aide' => a } }, 'vue' => @vue || 'tout', 'msg' => msg.to_s }
    end

    def self.rafraichir(msg = nil)
      @fen.execute_script("maj(#{JSON.generate(donnees(msg)).gsub('</', '<\/')})") if @fen
    rescue StandardError
      nil
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        rafraichir
        return
      end
      html = A2M::Panneau.page('Phases du projet', 'Existant, démolition, construction : les couleurs des dossiers de rénovation', CORPS, SCRIPT, donnees)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : phases', 'A2M_Panneau_Phases', html, 440, 600)
      @fen = dlg
      dlg.add_action_callback('poser') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) do
          n = r ? poser(r['phase'], r['colorier']) : 0
          rafraichir(n.zero? ? 'Sélectionnez d\'abord des groupes ou composants.' : "#{n} élément(s) mis à jour")
        end
      end
      dlg.add_action_callback('afficher') { |_c, v| UI.start_timer(0, false) { afficher(v.to_s); rafraichir } }
      dlg.add_action_callback('actualiser') { |_c| UI.start_timer(0, false) { rafraichir } }
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
