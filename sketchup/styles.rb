# encoding: UTF-8
# Métré Atelier 2M : styles de vue en un clic (intérieur, plan technique, coupe grise, construire et démolir, tracé sur plan), avec favoris
require 'sketchup.rb'
require 'json'

module A2M
  module Styles
    # clé, libellé, aide, mode de rendu, silhouettes, arêtes, fond (RVB), face (RVB ou nil), pictogramme
    STYLES = [
      ['interieur',  'Intérieur',            'Couleurs et textures, arêtes fines : pour travailler et présenter', 3, false, true,  [255, 255, 255], nil],
      ['technique',  'Plan technique',       'Lignes noires sur fond blanc, sans couleurs : pour les plans et LayOut', 1, true, true, [255, 255, 255], nil],
      ['coupe',      'Coupe grise',          'Tout en gris clair, arêtes noires : les coupes lisibles', 4, true, true, [255, 255, 255], [215, 215, 215]],
      ['demolir',    'Construire et démolir', 'Existant gris, démolition rouge, construction bleu (phases), arêtes noires', 2, false, true, [255, 255, 255], nil],
      ['trace',      'Tracé sur plan',       'Fil de fer sur fond clair, pour redessiner par-dessus un plan calé', 0, false, true, [245, 245, 240], nil]
    ].freeze

    def self.appliquer(cle)
      s = STYLES.find { |x| x[0] == cle } or return
      model = Sketchup.active_model
      ro = model.rendering_options
      model.start_operation('Style Atelier 2M', true)
      begin
        { 'RenderMode' => s[3], 'DrawSilhouettes' => s[4], 'EdgeDisplayMode' => s[5], 'DrawHorizon' => false, 'DrawGround' => false,
          'DisplayInstanceAxes' => false, 'BackgroundColor' => Sketchup::Color.new(*s[6]), 'EdgeColorMode' => 0 }.each { |k, v| ro[k] = v rescue nil }
        ro['SkyColor'] = Sketchup::Color.new(*s[6]) rescue nil
        ro['GroundColor'] = Sketchup::Color.new(*s[6]) rescue nil
        ro['FaceFrontColor'] = Sketchup::Color.new(*(s[7] || [255, 255, 255])) rescue nil
        ro['ForegroundColor'] = Sketchup::Color.new(0, 0, 0) rescue nil
        model.shadow_info['DisplayShadows'] = false rescue nil
        if cle == 'demolir'
          # sans phase posée, rien ne change : on colore seulement ce qui est marqué
          A2M::Phases.afficher('toutes') rescue nil
        elsif @dernier == 'demolir'
          A2M::Phases.afficher('toutes') rescue nil
        end
        model.commit_operation
        @dernier = cle
        Sketchup.status_text = "Style « #{s[1]} » appliqué."
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Style impossible : #{ex.message}")
      end
    end

    def self.favoris
      (JSON.parse(Sketchup.read_default('A2M_Metre', 'styles_favoris', '[]').to_s) rescue []) || []
    end

    def self.basculer_favori(cle)
      f = favoris
      f.include?(cle) ? f.delete(cle) : f << cle
      Sketchup.write_default('A2M_Metre', 'styles_favoris', JSON.generate(f))
      f
    end

    CORPS = <<~'HTML'
      <div class="grille" id="liste"></div>
      <div class="petit">L'étoile garde un style en favori (il passe en tête). Un clic sur une carte applique le style à la vue en cours.</div>
    HTML
    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(i) { return document.getElementById(i); }
      function rendre() {
        var g = el('liste'); g.innerHTML = '';
        var l = D.styles.slice().sort(function (a, b) { return (D.fav.indexOf(b.cle) >= 0) - (D.fav.indexOf(a.cle) >= 0); });
        l.forEach(function (t) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte';
          var f = D.fav.indexOf(t.cle) >= 0;
          b.innerHTML = '<div class="vignette"><svg viewBox="0 0 48 40" width="70" height="56">' + t.icone + '</svg></div><span></span><div class="petit" style="margin:2px 0 0"></div><div class="etoile" style="position:absolute;top:6px;right:9px;font-size:16px;color:' + (f ? '#E07838' : '#bbb') + '">' + (f ? '★' : '☆') + '</div>';
          b.style.position = 'relative';
          b.querySelector('span').textContent = t.libelle; b.querySelector('.petit').textContent = t.aide;
          b.addEventListener('click', function (e) {
            if (e.target.className === 'etoile') { sketchup.favori(t.cle); return; }
            sketchup.appliquer(t.cle);
          });
          g.appendChild(b);
        });
      }
      function maj(f) { D.fav = f; rendre(); }
      rendre();
    JS

    ICONES = {
      'interieur' => '<rect x="6" y="8" width="36" height="26" fill="#F9DCC0" stroke="#3C3C3C"/><rect x="26" y="14" width="10" height="14" fill="#BFE0F5" stroke="#3C3C3C"/><path d="M6 28 H42" stroke="#E07838"/>',
      'technique' => '<rect x="6" y="8" width="36" height="26" fill="#fff" stroke="#000" stroke-width="2"/><path d="M6 21 H20 M28 21 H42 M24 8 V16" stroke="#000" stroke-width="2"/>',
      'coupe' => '<path d="M6 34 V12 L24 5 L42 12 V34 Z" fill="#D7D7D7" stroke="#000" stroke-width="1.6"/>',
      'demolir' => '<rect x="5" y="10" width="12" height="22" fill="#C9C9C9" stroke="#3C3C3C"/><rect x="19" y="10" width="12" height="22" fill="#D83A3A" stroke="#3C3C3C"/><rect x="33" y="10" width="10" height="22" fill="#2E6FD0" stroke="#3C3C3C"/>',
      'trace' => '<path d="M6 34 V12 L24 5 L42 12 V34 Z M6 12 L24 19 L42 12 M24 19 V34" fill="none" stroke="#3C3C3C"/>'
    }.freeze

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      d = { 'styles' => STYLES.map { |k, l, a, *_| { 'cle' => k, 'libelle' => l, 'aide' => a, 'icone' => ICONES[k] } }, 'fav' => favoris }
      html = A2M::Panneau.page('Styles', 'Un clic change l\'aspect de la vue : le plan, la coupe ou la présentation', CORPS, SCRIPT, d)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : styles', 'A2M_Panneau_Styles', html, 460, 600)
      @fen = dlg
      dlg.add_action_callback('appliquer') { |_c, cle| UI.start_timer(0, false) { appliquer(cle.to_s) } }
      dlg.add_action_callback('favori') do |_c, cle|
        f = basculer_favori(cle.to_s)
        dlg.execute_script("maj(#{JSON.generate(f)})")
      end
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
