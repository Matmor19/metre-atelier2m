# encoding: UTF-8
# Métré Atelier 2M : vues prêtes à l'emploi (plan, façades, perspective) créées en scènes SketchUp
require 'sketchup.rb'
require 'json'

module A2M
  module Vues
    # [clé, libellé, icône, direction de l'œil par rapport au centre, haut de l'écran, projection parallèle]
    LISTE = [
      ['plan',  'Plan (vue du dessus)',    '⬇️', [0, 0, 1],  [0, 1, 0], true],
      ['sud',   'Façade Sud',              '🧭', [0, -1, 0], [0, 0, 1], true],
      ['nord',  'Façade Nord',             '🧭', [0, 1, 0],  [0, 0, 1], true],
      ['est',   'Façade Est',              '🧭', [1, 0, 0],  [0, 0, 1], true],
      ['ouest', 'Façade Ouest',            '🧭', [-1, 0, 0], [0, 0, 1], true],
      ['persp', 'Perspective d\'ensemble', '🏠', [-1, -1, 0.7], [0, 0, 1], false]
    ].freeze

    CORPS = <<~'HTML'
      <h2>Vues à créer</h2>
      <div class="grille" id="vues"></div>
      <div class="petit">Chaque vue devient une scène nommée (« A2M – Plan », « A2M – Façade Sud »…). Si elle existe déjà, elle est mise à jour.</div>
      <h2>Style d'affichage</h2>
      <div class="grille" id="styles"></div>
      <h2>Réglages</h2>
      <div class="puces" id="regl"></div>
      <div id="bas"><div id="msg"></div><button id="go" type="button">Créer les vues</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      var choix = {}; D.vues.forEach(function (v) { choix[v.cle] = true; });
      var reg = { aretes: true, ombres: false, style: 'reel' };
      function rendre() {
        var g = el('vues'); g.innerHTML = '';
        D.vues.forEach(function (v) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte' + (choix[v.cle] ? ' rempli' : '');
          b.innerHTML = '<div class="vignette" style="font-size:34px">' + v.icone + '</div><span></span>'; b.querySelector('span').textContent = v.libelle;
          b.addEventListener('click', function () { choix[v.cle] = !choix[v.cle]; rendre(); }); g.appendChild(b);
        });
        var st = el('styles'); st.innerHTML = '';
        D.styles.forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte' + (reg.style === x.cle ? ' rempli' : '');
          b.innerHTML = '<div class="vignette" style="font-size:30px">' + x.icone + '</div><span></span><div class="petit" style="margin:2px 0 0"></div>';
          b.querySelector('span').textContent = x.libelle; b.querySelector('.petit').textContent = x.aide;
          b.addEventListener('click', function () { reg.style = x.cle; rendre(); }); st.appendChild(b);
        });
        var r = el('regl'); r.innerHTML = '';
        [['aretes', 'Arêtes visibles'], ['ombres', 'Ombres activées']].forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (reg[x[0]] ? ' rempli' : ''); b.textContent = x[1];
          b.addEventListener('click', function () { reg[x[0]] = !reg[x[0]]; rendre(); }); r.appendChild(b);
        });
        var n = Object.keys(choix).filter(function (k) { return choix[k]; }).length;
        el('go').disabled = !n; el('msg').textContent = n ? n + ' vue(s) à créer' : 'Cliquez au moins une vue.';
      }
      el('go').addEventListener('click', function () { sketchup.creer(JSON.stringify({ vues: Object.keys(choix).filter(function (k) { return choix[k]; }), reg: reg })); });
      rendre();
    JS

    # Styles prêts à l'emploi : [clé, libellé, icône, aide, RenderMode, silhouettes]
    STYLES = [
      ['reel',      'Réaliste',        '🎨', 'Couleurs et textures (client, 3D)', 3, false],
      ['technique', 'Plan technique',  '📐', 'Lignes cachées, contours francs (dossier, permis)', 1, true],
      ['maquette',  'Maquette blanche', '⬜', 'Monochrome, volumes lisibles (esquisse)', 4, true]
    ].freeze

    def self.creer(cles, reg)
      model = Sketchup.active_model
      bb = model.bounds
      return UI.messagebox('Le modèle est vide : dessinez d\'abord quelque chose.') if bb.empty?
      view = model.active_view
      c = bb.center
      d = [bb.diagonal * 1.5, 1000].max
      model.start_operation('Vues Atelier 2M', true)
      begin
        ro = model.rendering_options
        ro['EdgeDisplayMode'] = reg['aretes'] ? true : false rescue nil
        st = STYLES.find { |x| x[0] == reg['style'] } || STYLES[0]
        ro['RenderMode'] = st[4] rescue nil
        ro['DrawSilhouettes'] = st[5] rescue nil
        model.shadow_info['DisplayShadows'] = reg['ombres'] ? true : false rescue nil
        LISTE.select { |l| cles.include?(l[0]) }.each do |cle, lib, _i, dir, haut, para|
          v = Geom::Vector3d.new(*dir); v.normalize!
          eye = c.offset(v, d)
          cam = Sketchup::Camera.new(eye, c, Geom::Vector3d.new(*haut))
          cam.perspective = !para
          view.camera = cam
          view.zoom_extents
          nom = "A2M – #{lib.sub(/ \(.*\)/, '')}#{st[0] == 'reel' ? '' : ' (' + st[1].downcase + ')'}"
          (model.pages[nom] || model.pages.add(nom)).tap { |p| p.update(Sketchup::Page::PAGE_ALL) }
        end
        model.commit_operation
        UI.messagebox("#{cles.size} vue(s) créée(s). Elles sont dans la barre des scènes, en haut de la fenêtre de dessin.")
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Création des vues impossible : #{ex.message}")
      end
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      html = A2M::Panneau.page('Vues prêtes à l\'emploi', 'Plan, façades et perspective en un clic', CORPS, SCRIPT,
                               'vues' => LISTE.map { |k, l, i, *| { 'cle' => k, 'libelle' => l, 'icone' => i } },
                               'styles' => STYLES.map { |k, l, i, a, *| { 'cle' => k, 'libelle' => l, 'icone' => i, 'aide' => a } })
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : vues', 'A2M_Panneau_Vues', html, 460, 720)
      @fen = dlg
      dlg.add_action_callback('creer') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) { creer(r['vues'], r['reg'] || {}) } if r && r['vues'].is_a?(Array) && !r['vues'].empty?
      end
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
