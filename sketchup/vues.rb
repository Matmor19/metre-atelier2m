# encoding: UTF-8
# Métré Atelier 2M : vues prêtes à l'emploi (plan, façades, perspective) créées en scènes SketchUp
require 'sketchup.rb'
require 'json'

module A2M
  module Vues
    # [clé, libellé, icône, direction de l'œil par rapport au centre, haut de l'écran, projection parallèle]
    LISTE = [
      ['plan',  'Plan (vue du dessus)',    '<svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"><rect x="8" y="6" width="32" height="28" fill="#fff"/><path d="M8 20 H24 V6 M24 20 V34 M30 20 H40" /><rect x="10" y="8" width="12" height="10" fill="#E07838" opacity=".35" stroke="none"/><path d="M42 12 V4 M39 7 L42 4 L45 7" stroke="#E07838"/></svg>', [0, 0, 1],  [0, 1, 0], true],
      ['sud',   'Façade Sud',              '<svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"><rect x="8" y="16" width="32" height="18" fill="#fff"/><path d="M6 17 L24 5 L42 17 Z" fill="#E07838" opacity=".5"/><path d="M6 17 L24 5 L42 17" /><rect x="12" y="21" width="7" height="7" fill="#BFE0F5"/><rect x="29" y="21" width="7" height="7" fill="#BFE0F5"/><rect x="21" y="23" width="6" height="11" fill="#E6C58F"/><path d="M4 34 H44" /><text x="41" y="13" font-size="10" font-weight="600" fill="#E07838" stroke="none" font-family="Segoe UI,Arial">S</text></svg>', [0, -1, 0], [0, 0, 1], true],
      ['nord',  'Façade Nord',             '<svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"><rect x="8" y="16" width="32" height="18" fill="#fff"/><path d="M6 17 L24 5 L42 17 Z" fill="#E07838" opacity=".5"/><path d="M6 17 L24 5 L42 17" /><rect x="12" y="21" width="7" height="7" fill="#BFE0F5"/><rect x="29" y="21" width="7" height="7" fill="#BFE0F5"/><rect x="21" y="23" width="6" height="11" fill="#E6C58F"/><path d="M4 34 H44" /><text x="41" y="13" font-size="10" font-weight="600" fill="#E07838" stroke="none" font-family="Segoe UI,Arial">N</text></svg>', [0, 1, 0],  [0, 0, 1], true],
      ['est',   'Façade Est',              '<svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"><rect x="8" y="16" width="32" height="18" fill="#fff"/><path d="M6 17 L24 5 L42 17 Z" fill="#E07838" opacity=".5"/><path d="M6 17 L24 5 L42 17" /><rect x="12" y="21" width="7" height="7" fill="#BFE0F5"/><rect x="29" y="21" width="7" height="7" fill="#BFE0F5"/><rect x="21" y="23" width="6" height="11" fill="#E6C58F"/><path d="M4 34 H44" /><text x="41" y="13" font-size="10" font-weight="600" fill="#E07838" stroke="none" font-family="Segoe UI,Arial">E</text></svg>', [1, 0, 0],  [0, 0, 1], true],
      ['ouest', 'Façade Ouest',            '<svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"><rect x="8" y="16" width="32" height="18" fill="#fff"/><path d="M6 17 L24 5 L42 17 Z" fill="#E07838" opacity=".5"/><path d="M6 17 L24 5 L42 17" /><rect x="12" y="21" width="7" height="7" fill="#BFE0F5"/><rect x="29" y="21" width="7" height="7" fill="#BFE0F5"/><rect x="21" y="23" width="6" height="11" fill="#E6C58F"/><path d="M4 34 H44" /><text x="41" y="13" font-size="10" font-weight="600" fill="#E07838" stroke="none" font-family="Segoe UI,Arial">O</text></svg>', [-1, 0, 0], [0, 0, 1], true],
      ['persp', 'Perspective d\'ensemble', '<svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"><path d="M6 22 L24 30 L42 22 L24 14 Z" fill="#fff"/><path d="M6 22 V30 L24 38 V30 M42 22 V30 L24 38" fill="#f3f3f3"/><path d="M10 20 L24 8 L38 20" fill="#E07838" opacity=".5" stroke="#3C3C3C"/><path d="M6 30 L24 38 L42 30" /></svg>', [-1, -1, 0.7], [0, 0, 1], false]
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
          b.innerHTML = '<div class="vignette">' + v.icone + '</div><span></span>'; b.querySelector('span').textContent = v.libelle;
          b.addEventListener('click', function () { choix[v.cle] = !choix[v.cle]; rendre(); }); g.appendChild(b);
        });
        var st = el('styles'); st.innerHTML = '';
        D.styles.forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte' + (reg.style === x.cle ? ' rempli' : '');
          b.innerHTML = '<div class="vignette">' + x.icone + '</div><span></span><div class="petit" style="margin:2px 0 0"></div>';
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
      ['reel',      'Réaliste',        '<svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"><rect x="8" y="8" width="32" height="24" rx="2" fill="#BFE0F5"/><path d="M8 28 L18 18 L26 25 L32 20 L40 28 V30 Q40 32 38 32 H10 Q8 32 8 30 Z" fill="#fff"/><circle cx="33" cy="14" r="2.4" fill="#E07838" stroke="none"/></svg>', 'Couleurs et textures (client, 3D)', 3, false],
      ['technique', 'Plan technique',  '<svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"><rect x="8" y="8" width="32" height="24" rx="1" fill="#fff"/><path d="M8 8 L16 16 H32 L40 8 M16 16 V32 M32 16 V32 M16 24 H32" stroke-dasharray="2 1.5"/><path d="M12 36 H36 M12 34 V38 M36 34 V38" stroke="#E07838"/></svg>', 'Lignes cachées, contours francs (dossier, permis)', 1, true],
      ['maquette',  'Maquette blanche', '<svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"><path d="M24 6 L40 14 V28 L24 36 L8 28 V14 Z" fill="#f4f4f4"/><path d="M8 14 L24 22 L40 14 M24 22 V36" /><path d="M24 6 L40 14 L24 22 L8 14 Z" fill="#fff" stroke="#3C3C3C"/></svg>', 'Monochrome, volumes lisibles (esquisse)', 4, true]
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
          (model.pages[nom] || model.pages.add(nom)).tap { |p| p.update }
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
