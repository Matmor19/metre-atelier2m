# encoding: UTF-8
# Métré Atelier 2M : feuille de présentation LayOut — vues du modèle (scènes) + cartouche de votre charte, en un clic
# Le fichier .layout créé s'ouvre dans LayOut : on peut ensuite tout modifier (cotes, annotations, échelle…).
require 'sketchup.rb'
require 'json'
require 'tmpdir'

module A2M
  module Feuille
    FORMATS = { 'A3' => [420.0, 297.0], 'A4' => [297.0, 210.0], 'A2' => [594.0, 420.0], 'A1' => [841.0, 594.0] }.freeze

    CORPS = <<~'HTML'
      <h2>Format (paysage)</h2><div class="puces" id="formats"></div>
      <h2>Vues à placer (4 au plus)</h2><div class="puces" id="scenes"></div><div class="petit" id="aucune"></div>
      <h2>Cartouche : <span id="cnom"></span></h2><div id="champs"></div>
      <div class="petit">Les champs et les couleurs viennent de « Cartouches et charte ».</div>
      <div id="bas"><div id="msg"></div><button type="button" class="puce" id="cart">Cartouches…</button><button type="button" id="go">Créer la feuille</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      var fmt = 'A3', choix = {};
      function el(id) { return document.getElementById(id); }
      D.scenes.forEach(function (s) { choix[s] = false; });
      var n0 = 0; D.scenes.forEach(function (s) { if (s.indexOf('A2M') === 0 && n0 < 2) { choix[s] = true; n0++; } });
      function nbchoix() { return Object.keys(choix).filter(function (k) { return choix[k]; }).length; }
      function rendre() {
        var f = el('formats'); f.innerHTML = '';
        D.formats.forEach(function (n) { var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (fmt === n ? ' rempli' : ''); b.textContent = n; b.addEventListener('click', function () { fmt = n; rendre(); }); f.appendChild(b); });
        var s = el('scenes'); s.innerHTML = '';
        D.scenes.forEach(function (n) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (choix[n] ? ' rempli' : ''); b.textContent = n;
          b.addEventListener('click', function () { if (!choix[n] && nbchoix() >= 4) return; choix[n] = !choix[n]; rendre(); }); s.appendChild(b);
        });
        el('aucune').textContent = D.scenes.length ? '' : 'Aucune scène : créez-les avec « Vues prêtes à l\'emploi ».';
        el('cnom').textContent = D.cartouche;
        el('msg').textContent = nbchoix() + ' vue(s)';
      }
      var champs = el('champs');
      D.champs.forEach(function (c) {
        var d = document.createElement('div'); d.style.cssText = 'display:flex;gap:8px;align-items:center;margin-bottom:5px';
        d.innerHTML = '<span class="petit" style="width:120px;margin:0"></span><input type="text" style="text-align:left;font-size:13px;flex:1">';
        d.querySelector('span').textContent = c.libelle; d.querySelector('input').value = c.defaut || ''; d.querySelector('input').setAttribute('data-l', c.libelle); champs.appendChild(d);
      });
      el('cart').addEventListener('click', function () { sketchup.cartouches(); });
      el('go').addEventListener('click', function () {
        var v = {}; document.querySelectorAll('#champs input').forEach(function (i) { v[i.getAttribute('data-l')] = i.value; });
        sketchup.creer(JSON.stringify({ format: fmt, scenes: Object.keys(choix).filter(function (k) { return choix[k]; }), valeurs: v }));
      });
      rendre();
    JS

    def self.mm(x) x.to_f / 25.4 end

    def self.couleur(hex)
      h = hex.to_s.delete('#')
      h = 'E07838' unless h =~ /\A\h{6}\z/
      Sketchup::Color.new(h[0, 2].to_i(16), h[2, 2].to_i(16), h[4, 2].to_i(16))
    end

    def self.rect(doc, calque, page, x, y, w, h, fond, trait = nil, epaisseur = 0.5)
      r = Layout::Rectangle.new(Geom::Bounds2d.new(mm(x), mm(y), mm(w), mm(h)))
      st = r.style
      if fond
        st.fill_color = fond
        st.solid_filled = true
      else
        st.solid_filled = false
      end
      if trait
        st.stroke_color = trait
        st.stroke_width = epaisseur
        st.stroked = true
      else
        st.stroked = false
      end
      r.style = st
      doc.add_entity(r, calque, page)
      r
    end

    def self.texte(doc, calque, page, txt, x, y, taille, couleur_txt, gras = false)
      return if txt.to_s.strip.empty?
      t = Layout::FormattedText.new(txt.to_s, Geom::Point2d.new(mm(x), mm(y)), Layout::FormattedText::ANCHOR_TYPE_TOP_LEFT)
      st = t.style
      st.font_size = taille
      st.text_color = couleur_txt
      st.font_family = 'Segoe UI'
      st.text_bold = true if gras
      t.style = st
      doc.add_entity(t, calque, page)
      t
    end

    def self.donnees
      c = A2M::Cartouches.actif
      champs = (c['champs'] || []).map(&:dup)
      champs.each { |x| x['defaut'] = (Sketchup.active_model.title.to_s.empty? ? 'Projet' : Sketchup.active_model.title) if x['libelle'].to_s.downcase == 'projet' && x['defaut'].to_s.empty? }
      { 'formats' => FORMATS.keys, 'scenes' => Sketchup.active_model.pages.map(&:name), 'champs' => champs, 'cartouche' => c['nom'] }
    end

    def self.creer(r)
      model = Sketchup.active_model
      return UI.messagebox('Enregistrez d\'abord le modèle SketchUp (Fichier > Enregistrer) : LayOut lit le fichier du modèle.') if model.path.to_s.empty?
      model.save if model.modified?
      return UI.messagebox('Choisissez au moins une vue.') if r['scenes'].to_a.empty?
      c = A2M::Cartouches.actif
      w, h = FORMATS[r['format']] || FORMATS['A3']
      doc = Layout::Document.new
      doc.page_info.width = mm(w)
      doc.page_info.height = mm(h)
      begin; doc.page_info.left_margin = 0; doc.page_info.right_margin = 0; doc.page_info.top_margin = 0; doc.page_info.bottom_margin = 0; rescue StandardError; end
      calque = doc.layers.first
      page = doc.pages.first
      marge = 10.0; bande = 38.0
      zone_x = marge; zone_y = marge; zone_w = w - 2 * marge; zone_h = h - 2 * marge - bande - 4
      accent = couleur(c['couleur']); fond = couleur(c['fond']); gris = Sketchup::Color.new(60, 60, 60)
      noms = r['scenes']
      idx = noms.map { |n| model.pages.to_a.index { |p| p.name == n } }.compact
      n = idx.size
      cols = n <= 1 ? 1 : 2
      rows = (n / cols.to_f).ceil
      cw = (zone_w - (cols - 1) * 5) / cols
      ch = (zone_h - (rows - 1) * 5) / rows
      idx.each_with_index do |i, k|
        cx = zone_x + (k % cols) * (cw + 5)
        cy = zone_y + (k / cols) * (ch + 5)
        sm = Layout::SketchUpModel.new(model.path, Geom::Bounds2d.new(mm(cx), mm(cy), mm(cw), mm(ch)))
        sm.current_scene = i + 1
        begin; sm.render_mode = Layout::SketchUpModel::VECTOR_RENDER; rescue StandardError; end
        doc.add_entity(sm, calque, page)
        texte(doc, calque, page, noms[k].to_s.sub(/\AA2M – /, ''), cx + 2, cy + 2, 11, gris, true)
      end
      # Cartouche : bloc société à gauche, champs en grille à droite
      by = h - marge - bande
      rect(doc, calque, page, marge, by, w - 2 * marge, bande, nil, gris, 0.75)
      rect(doc, calque, page, marge, by, 85.0, bande, fond, gris, 0.75)
      logo_ok = false
      unless c['logo'].to_s.empty?
        begin
          m = c['logo'].match(%r{\Adata:image/(png|jpeg|svg\+xml);base64,(.+)\z}m)
          if m
            f = File.join(Dir.mktmpdir('a2m_logo'), "logo.#{m[1] == 'jpeg' ? 'jpg' : (m[1] == 'png' ? 'png' : 'svg')}")
            File.binwrite(f, Base64.decode64(m[2]))
            doc.add_entity(Layout::Image.new(f, Geom::Bounds2d.new(mm(marge + 3), mm(by + 3), mm(24), mm(16))), calque, page)
            logo_ok = true
          end
        rescue StandardError
          logo_ok = false
        end
      end
      s = c['societe'].to_a
      texte(doc, calque, page, s[0], marge + (logo_ok ? 30 : 4), by + 4, 12, gris, true)
      texte(doc, calque, page, s[1], marge + 4, by + 22, 8, gris)
      texte(doc, calque, page, s[2], marge + 4, by + 27, 8, gris)
      texte(doc, calque, page, s[3], marge + 4, by + 32, 8, gris)
      champs = (c['champs'] || [])
      gx = marge + 85.0; gw = w - 2 * marge - 85.0
      nc = 4
      rows_c = [(champs.size / nc.to_f).ceil, 1].max
      cell_w = gw / nc; cell_h = bande / [rows_c, 2].max
      champs.each_with_index do |ch2, k|
        x = gx + (k % nc) * cell_w
        y = by + (k / nc) * cell_h
        rect(doc, calque, page, x, y, cell_w, cell_h, nil, gris, 0.4)
        texte(doc, calque, page, ch2['libelle'].to_s.upcase, x + 2, y + 1.5, 6, accent)
        texte(doc, calque, page, r['valeurs'][ch2['libelle']] || ch2['defaut'], x + 2, y + 6, 10, gris, true)
      end
      rect(doc, calque, page, marge, by + bande - 1.5, w - 2 * marge, 1.5, accent)
      nom = "#{File.basename(model.path, '.*')}_feuille_#{r['format']}.layout"
      cible = UI.savepanel('Enregistrer la feuille LayOut', File.dirname(model.path), nom)
      return unless cible
      cible += '.layout' unless cible.downcase.end_with?('.layout')
      doc.save(cible)
      UI.openURL("file:///#{cible.tr('\\', '/')}")
    rescue StandardError => ex
      UI.messagebox("Création de la feuille impossible : #{ex.message}\n#{ex.backtrace.first(3).join("\n")}")
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      html = A2M::Panneau.page('Feuille de présentation LayOut', 'Vues du modèle + cartouche de votre charte', CORPS, SCRIPT, donnees)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : feuille LayOut', 'A2M_Panneau_Feuille', html, 460, 680)
      @fen = dlg
      dlg.add_action_callback('creer') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) { creer(r) } if r
      end
      dlg.add_action_callback('cartouches') { |_c| A2M::Cartouches.ouvrir }
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
