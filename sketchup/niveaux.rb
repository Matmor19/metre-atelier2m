# encoding: UTF-8
# Métré Atelier 2M : niveaux du bâtiment. Le DESSOUS DE LA DALLE est le niveau 0 ; ce qui est dessous (semelles, soubassement)
# est négatif, ce qui est dessus est positif. Une liste de niveaux (code, nom, altitude en m) que l'on modifie, complète ou
# réduit librement, un schéma en coupe qui suit la liste en direct, le tracé des niveaux dans le modèle,
# et le recalage du zéro sur un point cliqué.
require 'sketchup.rb'
require 'json'

module A2M
  module Niveaux
    DICO = 'A2M_NIVEAUX'
    BALISE = 'A2M_NIVEAUX'

    # Liste de départ : tout se modifie, s'ajoute ou se supprime
    DEFAUT = [
      ['HM',  'Haut des murs',            2.70],
      ['PL',  'Sous-plafond (faux plafond)', 2.50],
      ['FF',  'Fini du sol',              0.15],
      ['DS',  'Dessus de la dalle',       0.12],
      ['DD',  'Dessous de la dalle (zéro)', 0.00],
      ['SEM', 'Dessous des semelles',    -0.60]
    ].freeze

    def self.liste(model = Sketchup.active_model)
      brut = model.get_attribute(DICO, 'liste', nil)
      l = (JSON.parse(brut.to_s) rescue nil) if brut
      l = DEFAUT.map { |c, n, a| { 'code' => c, 'nom' => n, 'alt' => a } } unless l.is_a?(Array) && !l.empty?
      l
    end

    def self.enregistrer(l, model = Sketchup.active_model)
      propre = l.map do |n|
        a = n['alt'].to_s.tr(',', '.').tr('−', '-').to_f
        { 'code' => n['code'].to_s.strip[0, 12], 'nom' => n['nom'].to_s.strip[0, 60], 'alt' => a.round(3) }
      end
      model.start_operation('Niveaux du bâtiment', true)
      model.set_attribute(DICO, 'liste', JSON.generate(propre))
      model.commit_operation
      propre
    end

    CORPS = <<~'HTML'
      <div id="coupe">
        <div id="gauche">
          <div class="entete"><span class="c1">Code</span><span class="c2">Nom du niveau</span><span class="c3">Altitude (m)</span><span class="c4"></span></div>
          <div id="lignes"></div>
          <button class="ajout" onclick="ajouter()">+ Ajouter un niveau</button>
          <div class="petit">Le zéro est le dessous de la dalle : ce qui est dessous est négatif (−0,60), ce qui est dessus est positif (+0,15). Les modifications sont enregistrées à la volée.</div>
        </div>
        <div id="droite"><svg id="schema" viewBox="0 0 460 600" preserveAspectRatio="xMidYMid meet"></svg></div>
      </div>
      <div id="bas">
        <div id="msg"></div>
        <button class="sec" onclick="sketchup.defaut('')">Remettre la liste de départ</button>
        <button class="sec" onclick="sketchup.caler('')">Caler le zéro sur un point cliqué</button>
        <button id="go" onclick="sketchup.tracer('')">Tracer les niveaux dans le modèle</button>
      </div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      var liste = D.liste;
      var COUL = ['#E07838', '#3E8EDE', '#2E9E6B', '#B0589E', '#C9A227', '#5F6B7A', '#D0503E', '#1F9AA8'];
      function nb(t){ var v = parseFloat(String(t).replace(/\s/g,'').replace('−','-').replace(',', '.')); return isFinite(v) ? v : null; }
      function fmt(a){ var s = Math.abs(a).toFixed(2).replace('.', ','); return a > 0.0001 ? '+' + s : (a < -0.0001 ? '−' + s : s); }
      var t0 = null;
      function sauver(){ clearTimeout(t0); t0 = setTimeout(function(){ sketchup.maj(JSON.stringify(liste)); }, 250); }
      function msg(t){ document.getElementById('msg').textContent = t || ''; }
      function ligne(i){
        var n = liste[i];
        var d = document.createElement('div'); d.className = 'lig'; d.dataset.i = i;
        d.innerHTML = '<input class="c1" type="text" value="' + (n.code||'').replace(/"/g,'&quot;') + '">' +
                      '<input class="c2" type="text" value="' + (n.nom||'').replace(/"/g,'&quot;') + '">' +
                      '<input class="c3" type="text" value="' + String(n.alt).replace('.', ',') + '">' +
                      '<button class="sup" title="Supprimer ce niveau">✕</button>';
        var ins = d.querySelectorAll('input');
        ins[0].oninput = function(){ n.code = this.value; dessiner(); sauver(); };
        ins[1].oninput = function(){ n.nom = this.value; dessiner(); sauver(); };
        ins[2].oninput = function(){ var v = nb(this.value); this.classList.toggle('err', v === null); if (v !== null){ n.alt = v; dessiner(); sauver(); } };
        ins[2].onblur = function(){ if (nb(this.value) !== null) this.value = String(n.alt).replace('.', ','); };
        d.querySelector('.sup').onclick = function(){ liste.splice(liste.indexOf(n), 1); tableau(); dessiner(); sauver(); };
        return d;
      }
      function tableau(){
        var z = document.getElementById('lignes'); z.innerHTML = '';
        liste.forEach(function(n, i){ z.appendChild(ligne(i)); });
      }
      function ajouter(){
        var h = liste.length ? Math.max.apply(null, liste.map(function(n){ return n.alt; })) : 0;
        liste.push({ code: 'N' + (liste.length + 1), nom: 'Nouveau niveau', alt: Math.round((h + 0.1) * 100) / 100 });
        tableau(); dessiner(); sauver();
        var z = document.getElementById('lignes'); var l = z.lastChild; if (l){ var i = l.querySelectorAll('input')[1]; i.focus(); i.select(); }
      }
      function recharger(l){ liste = l; tableau(); dessiner(); }
      function dessiner(){
        var L = liste.filter(function(n){ return isFinite(n.alt); }).map(function(n, k){ return { code: n.code, nom: n.nom, alt: n.alt, k: k }; })
                     .sort(function(a, b){ return b.alt - a.alt; });
        var s = document.getElementById('schema'), h = '';
        var haut = 30, bas = 30, H = 600;
        var amax = Math.max(0.5, Math.max.apply(null, L.map(function(n){ return n.alt; }).concat([0])));
        var amin = Math.min(-0.4, Math.min.apply(null, L.map(function(n){ return n.alt; }).concat([0])));
        var pad = (amax - amin) * 0.06; amax += pad; amin -= pad;
        function Y(a){ return haut + (amax - a) / (amax - amin) * (H - haut - bas); }
        h += '<defs><pattern id="hach" width="6" height="6" patternUnits="userSpaceOnUse" patternTransform="rotate(45)"><line x1="0" y1="0" x2="0" y2="6" stroke="#b9a58f" stroke-width="1"/></pattern></defs>';
        // terrain sous la dalle
        h += '<rect x="40" y="' + Y(0) + '" width="260" height="' + (Y(amin) - Y(0)) + '" fill="url(#hach)" opacity=".55"/>';
        h += '<line x1="40" y1="' + Y(0) + '" x2="300" y2="' + Y(0) + '" stroke="#E07838" stroke-width="2.6"/>';
        // mur (coupe)
        h += '<rect x="170" y="' + Y(amax) + '" width="34" height="' + (Y(amin) - Y(amax)) + '" fill="#e6e1da" stroke="#8a7f75"/>';
        h += '<rect x="204" y="' + Y(amax) + '" width="9" height="' + (Y(amin) - Y(amax)) + '" fill="#f3d9bd" stroke="#8a7f75"/>';
        // dalle entre le zéro et son dessus si un niveau DS / dessus existe : bande indicative
        var ds = L.filter(function(n){ return /^DS$/i.test((n.code||'').trim()); })[0];
        if (ds && ds.alt > 0) h += '<rect x="60" y="' + Y(ds.alt) + '" width="110" height="' + (Y(0) - Y(ds.alt)) + '" fill="#9fc2e6" stroke="#5b86b3"/>';
        // positions des étiquettes (écart minimal 30 px, étalées vers le haut et le bas)
        var ys = L.map(function(n){ return Y(n.alt); });
        var ly = ys.slice();
        for (var p = 0; p < 40; p++){
          var bouge = false;
          for (var i = 1; i < ly.length; i++){ if (ly[i] - ly[i-1] < 30){ var m = (30 - (ly[i] - ly[i-1])) / 2; ly[i-1] -= m; ly[i] += m; bouge = true; } }
          if (!bouge) break;
        }
        L.forEach(function(n, i){
          var c = COUL[n.k % COUL.length];
          var zero = Math.abs(n.alt) < 0.0001;
          h += '<line x1="40" y1="' + ys[i] + '" x2="300" y2="' + ys[i] + '" stroke="' + c + '" stroke-width="' + (zero ? 2.6 : 1.3) + '"' + (zero ? '' : ' stroke-dasharray="7 3"') + '/>';
          h += '<polygon points="46,' + (ys[i]) + ' 58,' + (ys[i] - 6) + ' 58,' + (ys[i] + 6) + '" fill="' + c + '"/>';
          h += '<polyline points="300,' + ys[i] + ' 310,' + ly[i] + ' 322,' + ly[i] + '" fill="none" stroke="' + c + '"/>';
          h += '<text x="328" y="' + (ly[i] - 2) + '" font-size="14" font-weight="700" fill="' + c + '">' + esc(n.code) + '  ' + fmt(n.alt) + ' m</text>';
          h += '<text x="328" y="' + (ly[i] + 12) + '" font-size="11" fill="#6f665e">' + esc(n.nom) + '</text>';
        });
        // cote de hauteur totale (du plus bas au plus haut des niveaux)
        if (L.length > 1){
          var yh = L[0].alt, yb = L[L.length - 1].alt;
          h += '<line x1="22" y1="' + Y(yh) + '" x2="22" y2="' + Y(yb) + '" stroke="#6f665e"/>';
          h += '<line x1="16" y1="' + Y(yh) + '" x2="28" y2="' + Y(yh) + '" stroke="#6f665e"/><line x1="16" y1="' + Y(yb) + '" x2="28" y2="' + Y(yb) + '" stroke="#6f665e"/>';
          h += '<text transform="translate(14,' + ((Y(yh) + Y(yb)) / 2) + ') rotate(-90)" text-anchor="middle" font-size="11" fill="#6f665e">' + (yh - yb).toFixed(2).replace('.', ',') + ' m</text>';
        }
        h += '<text x="62" y="' + (Y(amin) - 6) + '" font-size="11" fill="#8a7f75">sous la dalle : négatif</text>';
        s.innerHTML = h;
      }
      function esc(t){ return String(t || '').replace(/&/g,'&amp;').replace(/</g,'&lt;'); }
      tableau(); dessiner();
    JS

    STYLE_PLUS = <<~'CSS'
      #coupe{display:grid;grid-template-columns:minmax(330px,1fr) minmax(360px,1.1fr);gap:16px;align-items:start}
      #gauche{background:#fff;border:1px solid var(--trait);border-radius:12px;padding:10px}
      .entete,.lig{display:grid;grid-template-columns:62px 1fr 86px 28px;gap:6px;align-items:center}
      .entete{font-size:10.5px;text-transform:uppercase;letter-spacing:.05em;color:#8a7f75;margin-bottom:4px}
      .lig{margin-bottom:5px}
      .lig input{font:13px "Segoe UI",Arial,sans-serif;font-weight:400;padding:6px 8px;text-align:left;border:2px solid var(--trait);border-radius:8px;background:#fff}
      .lig input.c3{text-align:right;font-weight:600;background:var(--jaune)}
      .lig input.err{border-color:#d0503e;background:#fde4df}
      .sup{border:0;background:#f3eee8;border-radius:8px;height:30px;cursor:pointer;color:#a8541f;font-size:13px}
      .sup:hover{background:#f6c9a5}
      .ajout{margin-top:6px;width:100%;border:2px dashed var(--o);background:#fff;color:#a8541f;border-radius:10px;padding:8px;font:600 13px "Segoe UI",Arial,sans-serif;cursor:pointer}
      .ajout:hover{background:#FFF0E3}
      #droite{background:#fff;border:1px solid var(--trait);border-radius:12px;padding:6px;position:sticky;top:8px}
      #schema{width:100%;height:calc(100vh - 190px);min-height:380px}
      .sec{background:#fff;color:#a8541f;border:2px solid var(--o);border-radius:10px;padding:8px 12px;font:600 12.5px "Segoe UI",Arial,sans-serif;cursor:pointer}
      .sec:hover{background:#FFF0E3}
    CSS

    def self.ouvrir
      model = Sketchup.active_model
      html = A2M::Panneau.page('Niveaux du bâtiment', 'Le dessous de la dalle est le zéro ; ajoutez, modifiez ou supprimez les niveaux, le schéma suit.',
                               CORPS, SCRIPT, { 'liste' => liste(model) })
      html = html.sub('</style>') { STYLE_PLUS + '</style>' }
      @dlg.close if @dlg && (@dlg.visible? rescue false)
      dlg = UI::HtmlDialog.new(dialog_title: 'Métré Atelier 2M : niveaux du bâtiment', preferences_key: 'A2M_Niveaux', scrollable: true,
                               resizable: true, width: 980, height: 700, min_width: 760, min_height: 520, style: UI::HtmlDialog::STYLE_DIALOG)
      @dlg = dlg
      dlg.set_html(html)
      dlg.add_action_callback('maj') do |_c, json|
        l = (JSON.parse(json.to_s) rescue nil)
        enregistrer(l) if l.is_a?(Array)
      end
      dlg.add_action_callback('defaut') do |_c, _j|
        l = enregistrer(DEFAUT.map { |c, n, a| { 'code' => c, 'nom' => n, 'alt' => a } })
        dlg.execute_script("recharger(#{JSON.generate(l)}); msg('Liste de départ remise.')")
      end
      dlg.add_action_callback('tracer') do |_c, _j|
        n = tracer(liste)
        dlg.execute_script("msg(#{JSON.generate(n)})")
      end
      dlg.add_action_callback('caler') do |_c, _j|
        Sketchup.active_model.select_tool(OutilZero.new(dlg))
        dlg.execute_script("msg('Cliquez dans SketchUp le point du dessous de la dalle : il devient le zéro.')")
      end
      dlg.show
    end

    # Trace chaque niveau dans le modèle : un cadre horizontal en lignes de construction et une étiquette « CODE +0,15 m »
    def self.tracer(l)
      model = Sketchup.active_model
      model.start_operation('Niveaux : tracer dans le modèle', true)
      model.entities.grep(Sketchup::Group).select { |g| g.get_attribute('a2m', 'niveaux') }.each { |g| g.erase! }
      bb = Geom::BoundingBox.new
      model.entities.each { |e| bb.add(e.bounds) if e.respond_to?(:bounds) && e.is_a?(Sketchup::Drawingelement) && !e.is_a?(Sketchup::ConstructionLine) && !e.is_a?(Sketchup::Text) }
      if bb.empty?
        bb.add(Geom::Point3d.new(0, 0, 0)); bb.add(Geom::Point3d.new(10.m, 8.m, 0))
      end
      marge = 0.5.m
      x0 = bb.min.x - marge; x1 = bb.max.x + marge; y0 = bb.min.y - marge; y1 = bb.max.y + marge
      g = model.entities.add_group
      g.name = 'Niveaux (A2M)'
      g.set_attribute('a2m', 'niveaux', true)
      tag = model.layers[BALISE] || model.layers.add(BALISE)
      g.layer = tag
      l.each do |n|
        z = n['alt'].to_f.m
        p = [Geom::Point3d.new(x0, y0, z), Geom::Point3d.new(x1, y0, z), Geom::Point3d.new(x1, y1, z), Geom::Point3d.new(x0, y1, z)]
        4.times { |i| g.entities.add_cline(p[i], p[(i + 1) % 4]) }
        a = n['alt'].to_f
        s = format('%.2f', a.abs).tr('.', ',')
        s = (a > 0.0001 ? '+' : (a < -0.0001 ? '−' : '')) + s
        g.entities.add_text("#{n['code']}  #{s} m", Geom::Point3d.new(x0, y0, z))
      end
      model.commit_operation
      "#{l.size} niveau(x) tracé(s) dans le groupe « Niveaux (A2M) » (balise #{BALISE}) : masquez la balise pour les cacher."
    rescue StandardError => ex
      model.abort_operation rescue nil
      "Tracé impossible : #{ex.message}"
    end

    # Recale le modèle pour que l'altitude z (pouces) devienne 0 ; l'altitude NGF de l'origine suit si elle est connue
    def self.caler(z)
      model = Sketchup.active_model
      if z.abs < 0.01
        UI.messagebox('Ce point est déjà au niveau 0 : rien à déplacer.')
        return false
      end
      m = format('%.3f', z.to_m).tr('.', ',')
      return false unless UI.messagebox("Le point cliqué est à #{m} m du zéro actuel.\n\nTout le modèle va être déplacé de #{m} m en hauteur pour que ce point devienne le niveau 0 (dessous de la dalle). Continuer ?", MB_YESNO) == IDYES
      A2M::Suivi.suspendre!
      model.start_operation('Niveau 0 : recaler le modèle', true)
      ents = model.entities
      ents.transform_entities(Geom::Transformation.translation(Geom::Vector3d.new(0, 0, -z)), ents.to_a)
      A2M::Suivi.decaler_z(model, -z)
      ngf = (A2M::Ngf.origine rescue nil)
      model.set_attribute(A2M::Ngf::DICO, 'origine_ngf', ngf + z.to_m) if ngf
      model.commit_operation
      A2M::Suivi.reprendre!
      true
    rescue StandardError => ex
      model.abort_operation rescue nil
      A2M::Suivi.reprendre!
      UI.messagebox("Recalage impossible : #{ex.message}")
      false
    end

    class OutilZero
      def initialize(dlg)
        @dlg = dlg
        @ip = Sketchup::InputPoint.new
      end

      def activate
        Sketchup.status_text = 'Cliquez le point du dessous de la dalle : il devient le niveau 0. Échap pour annuler.'
      end

      def onMouseMove(_f, x, y, v)
        @ip.pick(v, x, y)
        v.tooltip = @ip.tooltip
        v.invalidate
      end

      def draw(v)
        @ip.draw(v) if @ip.valid?
      end

      def onLButtonDown(_f, x, y, v)
        @ip.pick(v, x, y)
        return unless @ip.valid?
        z = @ip.position.z
        Sketchup.active_model.select_tool(nil)
        ok = Niveaux.caler(z)
        (@dlg.execute_script("msg(#{JSON.generate(ok ? 'Zéro recalé : le modèle a été déplacé.' : 'Zéro inchangé.')})") rescue nil)
      end

      def onCancel(_r, _v)
        Sketchup.active_model.select_tool(nil)
      end
    end
  end
end

# Mise à jour à chaud : le menu du Métré n'est construit qu'au démarrage ; une entrée provisoire permet d'utiliser l'outil tout de suite
if defined?(::ACTIONS_A2M) && !$a2m_niveaux_menu && !::ACTIONS_A2M.any? { |a| a[0] == 'niveaux' }
  $a2m_niveaux_menu = true
  UI.menu('Extensions').add_item('Niveaux du bâtiment (Métré A2M, provisoire jusqu\'au redémarrage)…') { A2M::Niveaux.ouvrir }
end
