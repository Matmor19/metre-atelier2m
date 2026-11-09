# encoding: UTF-8
# Métré Atelier 2M : outil Porte intérieure (bloc-porte de passage dans une cloison ou un refend)
#  - la porte se choisit par son vantail (63, 73, 83, 93, 103 × 204) ; la réservation est le vantail + le jeu de l'huisserie ;
#  - toute l'épaisseur est percée (couches jointives : plaque, ossature, plaque, ou refend et doublages), pas plus loin ;
#  - le bloc est centré dans l'épaisseur ; Tab choisit le sens (poussant droit ou gauche, de ce côté ou de l'autre) ;
#  - choix du configurateur (destination, âme, type, finition, pose) gardés sur la porte et repris à l'extraction.
require 'sketchup.rb'
require 'json'

module A2M
  module PortesInt
    DIMS = ['63×204', '73×204', '83×204', '93×204', '103×204']
    AUTRE = 'Autre (cotes ci-dessous)'
    AC = '— à choisir —'
    # Mêmes libellés que le configurateur du métré (rien n'est choisi d'office)
    CHOIX = [
      ['dest', 'Destination', ['à galandage', 'de communication', 'acoustique', 'de service isothermique', 'technique coupe-feu EI30', 'palière thermique', 'palière acoustique', 'palière blindage de sécurité', 'fin de chantier', 'palière coupe-feu']],
      ['ame', 'Âme', ['âme alvéolaire', 'âme pleine', 'âme tubulaire']],
      ['type', 'Type de vantail', ['isoplane', 'postformé', 'vitré']],
      ['fin', 'Finition', ['rive droite', 'recouvrement']],
      ['pose', 'Pose', ['pose traditionnelle', 'pose fin de chantier', 'pose rénovation']]
    ]
    # Sens : [côté poussant (:ici = côté cliqué), paumelles vues du côté poussant]
    SENS = [[:ici, 'droite'], [:ici, 'gauche'], [:autre, 'droite'], [:autre, 'gauche']]
    RES_SIMPLE = 'Réservation simple (huisserie balisée)'
    RES_AUCUNE = 'Aucune (seulement le passage)'
    BIB = 'Bibliothèque : '
    @r = {}

    def self.lib_sens(s)
      "Poussant #{s[1] == 'droite' ? 'droit' : 'gauche'}, #{s[0] == :ici ? 'depuis ce côté' : 'depuis l\'autre côté'}"
    end

    # ---- Fenêtre « Porte intérieure » : vignettes, aperçu, choix en un clic (codes couleur : jaune = choisi, bleu pâle = aucun, blanc = à choisir) ----
    CORPS_PANNEAU = <<~'HTML'
      <h2>Bloc-porte (vantail)</h2>
      <div class="puces" id="dims"></div>
      <div class="dims" id="autre" style="margin-top:10px;display:none">
        <div><label for="vl">Largeur du vantail</label><input type="text" id="vl" inputmode="decimal" autocomplete="off"><div class="unite">cm</div></div>
        <div class="x">×</div>
        <div><label for="vh">Hauteur du vantail</label><input type="text" id="vh" inputmode="decimal" autocomplete="off"><div class="unite">cm</div></div>
      </div>
      <div class="apercu" id="apercu"></div>
      <h2>Menuiserie posée</h2>
      <div class="grille" id="menus"></div><div class="petit" id="note_menu"></div>
      <h2>Pièce de rattachement</h2>
      <div class="puces" id="pieces"></div>
      <details><summary>Choix pour le métré (facultatif : une case vide = rien au métré)</summary><div id="choix"></div></details>
      <details><summary>Réservation autour du vantail</summary>
        <div class="dims" style="margin-top:8px">
          <div><label for="jl">Jeu total en largeur (huisserie comprise)</label><input type="text" id="jl" inputmode="decimal" autocomplete="off"><div class="unite">cm</div></div>
          <div class="x">+</div>
          <div><label for="jh">Jeu en hauteur</label><input type="text" id="jh" inputmode="decimal" autocomplete="off"><div class="unite">cm</div></div>
        </div>
      </details>
      <div id="bas"><div id="msg"></div><button id="go" type="button">Suivant : choisir l'emplacement</button></div>
    HTML

    SCRIPT_PANNEAU = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      function nombre(v) { var x = parseFloat(String(v).replace(',', '.')); return isFinite(x) ? x : 0; }
      var etat = { dim: D.dim, vl: D.vl, vh: D.vh, jl: D.jl, jh: D.jh, menu: D.menu, piece: D.piece, choix: D.choix || {} };

      function puces(conteneur, valeurs, courant, clic, classe) {
        conteneur.innerHTML = '';
        valeurs.forEach(function (v) {
          var b = document.createElement('button'); b.type = 'button';
          b.className = 'puce ' + (v.classe || classe || '') + (courant === v.id ? ' rempli' : ''); b.textContent = v.texte;
          b.addEventListener('click', function () { clic(v.id); }); conteneur.appendChild(b);
        });
      }

      function apercu() {
        var vl = etat.vl, vh = etat.vh, jl = etat.jl, jh = etat.jh;
        if (!(vl > 0 && vh > 0)) { el('apercu').innerHTML = ''; return; }
        var L = vl + jl, H = vh + jh, W = Math.max(L + 120, 220), HT = Math.max(H + 40, 250), fs = Math.max(W, HT) / 20, x0 = (W - L) / 2, xv = (W - vl) / 2, s = '';
        s += '<rect x="0" y="0" width="' + W + '" height="' + HT + '" fill="#E4DCD2" stroke="#9c9186" stroke-width="1.5"/>';
        s += '<rect x="' + x0 + '" y="' + (HT - H) + '" width="' + L + '" height="' + H + '" fill="#fff" stroke="#8a7f75" stroke-width="2" stroke-dasharray="6 4"/>';
        s += '<rect x="' + xv + '" y="' + (HT - vh) + '" width="' + vl + '" height="' + vh + '" fill="#D9C3A5" stroke="#3C3C3C" stroke-width="2.5"/>';
        s += '<rect x="' + (xv + vl * .2) + '" y="' + (HT - vh + vh * .12) + '" width="' + (vl * .6) + '" height="' + (vh * .34) + '" fill="none" stroke="#B49873" stroke-width="1.5"/>';
        s += '<rect x="' + (xv + vl * .2) + '" y="' + (HT - vh + vh * .55) + '" width="' + (vl * .6) + '" height="' + (vh * .34) + '" fill="none" stroke="#B49873" stroke-width="1.5"/>';
        s += '<circle cx="' + (xv + vl - 7) + '" cy="' + (HT - vh * .48) + '" r="3.2" fill="#3C3C3C"/>';
        s += '<text x="' + (W / 2) + '" y="' + (HT - H - fs * .4) + '" font-size="' + fs + '" font-weight="600" fill="#3C3C3C" text-anchor="middle">vantail ' + vl + ' × ' + vh + '</text>';
        s += '<text x="' + (W / 2) + '" y="' + (HT + 12) + '" font-size="' + fs * .75 + '" fill="#8a7f75" text-anchor="middle">réservation ' + Math.round(L * 10) / 10 + ' × ' + Math.round(H * 10) / 10 + ' cm (tirets)</text>';
        el('apercu').innerHTML = '<svg viewBox="-4 -4 ' + (W + 8) + ' ' + (HT + 22) + '" preserveAspectRatio="xMidYMid meet">' + s + '</svg>';
      }

      function rendre() {
        var dims = D.dims.map(function (d) { return { id: d, texte: d }; }).concat([{ id: 'autre', texte: 'Autre cote…' }]);
        puces(el('dims'), dims, etat.dim, function (id) {
          etat.dim = id;
          if (id !== 'autre') { var p = id.split('×'); etat.vl = parseFloat(p[0]); etat.vh = parseFloat(p[1]); el('vl').value = etat.vl; el('vh').value = etat.vh; }
          rendre();
        });
        el('autre').style.display = etat.dim === 'autre' ? 'grid' : 'none';
        ['vl', 'vh', 'jl', 'jh'].forEach(function (k) { el(k).classList.toggle('ok', etat[k] > 0); });
        apercu();
        // Menuiserie posée : vignettes
        var m = el('menus'); m.innerHTML = '';
        var cartes = [{ id: 'simple', nom: 'Réservation simple (huisserie balisée)', img: '', classe: '' }, { id: 'aucune', nom: 'Aucune (seulement le passage)', img: '', classe: 'aucun' }].concat(D.objets.map(function (o) { return { id: 'obj:' + o.nom, nom: o.nom, img: o.img, classe: '' }; }));
        cartes.forEach(function (c) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte ' + c.classe + (etat.menu === c.id ? ' rempli' : '');
          b.innerHTML = '<div class="vignette">' + (c.img ? '<img alt="" src="' + c.img + '">' : '') + '</div><span></span>'; b.querySelector('span').textContent = c.nom;
          b.addEventListener('click', function () { etat.menu = c.id; rendre(); }); m.appendChild(b);
        });
        el('note_menu').textContent = etat.menu === null ? 'À choisir : une menuiserie, une réservation simple ou « Aucune » (rien ne se choisit tout seul).' : '';
        // Pièce
        puces(el('pieces'), [{ id: '', texte: 'Automatique (pièce la plus proche)', classe: 'aucun' }].concat(D.pieces.map(function (p) { return { id: p, texte: p }; })), etat.piece, function (id) { etat.piece = id; rendre(); }, '');
        // Choix du configurateur : cliquer une valeur déjà choisie la vide
        var c = el('choix'); c.innerHTML = '';
        D.groupes.forEach(function (g) {
          var t = document.createElement('h3'); t.textContent = g.libelle; c.appendChild(t);
          var p = document.createElement('div'); p.className = 'puces'; c.appendChild(p);
          puces(p, g.valeurs.map(function (v) { return { id: v, texte: v }; }), etat.choix[g.cle], function (id) { if (etat.choix[g.cle] === id) delete etat.choix[g.cle]; else etat.choix[g.cle] = id; rendre(); }, '');
        });
        var manque = [];
        if (!(etat.vl > 0 && etat.vh > 0)) manque.push('la taille du vantail');
        if (etat.menu === null) manque.push('la menuiserie posée');
        el('msg').textContent = manque.length ? 'Il reste à choisir : ' + manque.join(', ') + '.' : '';
        el('go').disabled = manque.length > 0;
      }

      el('vl').value = etat.vl || ''; el('vh').value = etat.vh || ''; el('jl').value = etat.jl; el('jh').value = etat.jh;
      el('vl').addEventListener('input', function () { etat.vl = nombre(this.value); rendre(); });
      el('vh').addEventListener('input', function () { etat.vh = nombre(this.value); rendre(); });
      el('jl').addEventListener('input', function () { etat.jl = nombre(this.value); rendre(); });
      el('jh').addEventListener('input', function () { etat.jh = nombre(this.value); rendre(); });
      el('go').addEventListener('click', function () { if (!el('go').disabled) sketchup.valider(JSON.stringify(etat)); });
      rendre();
    JS

    def self.donnees_panneau(objs)
      pcs = A2M::Ouvertures.pieces_du_modele
      menu = @r[:menu]
      ok = menu == 'simple' || menu == 'aucune' || objs.any? { |o| menu == "obj:#{o['nom']}" }
      menu = objs.empty? ? 'simple' : nil unless ok
      dim = DIMS.include?(@r[:dim]) || @r[:dim] == 'autre' ? @r[:dim] : '83×204'
      { 'dims' => DIMS, 'dim' => dim, 'vl' => @r[:vl] || 83, 'vh' => @r[:vh] || 204, 'jl' => @r[:jl] || 7, 'jh' => @r[:jh] || 4, 'menu' => menu,
        'piece' => pcs.include?(@r[:piece]) ? @r[:piece] : '', 'pieces' => pcs, 'choix' => @r[:choix] || {},
        'groupes' => CHOIX.map { |k, l, v| { 'cle' => k, 'libelle' => l, 'valeurs' => v } },
        'objets' => objs.map { |o| { 'nom' => o['nom'].to_s, 'img' => A2M::Panneau.vignette(o) } } }
    end

    def self.demander(&suite)
      objs = (A2M::Bibliotheque.objets_de(['A2M_PORTE_INT']) rescue [])
      html = A2M::Panneau.page('Poser une porte intérieure', 'Étape 1 sur 2 : la porte, puis l\'emplacement dans la cloison', CORPS_PANNEAU, SCRIPT_PANNEAU, donnees_panneau(objs))
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : porte intérieure', 'A2M_Panneau_PorteInt', html, 480, 800)
      dlg.add_action_callback('valider') do |_ctx, json|
        d = (JSON.parse(json.to_s) rescue nil)
        next unless d.is_a?(Hash)
        vl, vh, jl, jh = %w[vl vh jl jh].map { |k| d[k].to_s.tr(',', '.').to_f }
        next if vl <= 0 || vh <= 0 || d['menu'].nil?
        choix = (d['choix'] || {}).select { |k, v| CHOIX.any? { |c, _, vals| c == k && vals.include?(v) } }
        piece = d['piece'].to_s.empty? ? nil : d['piece'].to_s
        @r = { dim: d['dim'], vl: vl, vh: vh, jl: jl, jh: jh, menu: d['menu'], piece: piece, choix: choix }
        obj = d['menu'].to_s.start_with?('obj:') ? objs.find { |o| "obj:#{o['nom']}" == d['menu'] } : nil
        dim = d['dim'] == 'autre' ? "#{vl.round}×#{vh.round}" : d['dim']
        dlg.close
        UI.start_timer(0, false) do
          opts = obj ? A2M::Bibliotheque.demander_options(obj) : {}
          next if opts.nil?
          pp = { type: ['Porte intérieure', 'A2M_PORTE_INT'], l: vl + jl, h: vh + jh, lin: vh + jh, vl: vl, vh: vh, n: 6, contigu: true,
                 appui: 0, res: d['menu'] != 'aucune' ? 'A2M_PORTE_INT' : nil, obj: obj, opts: opts, piece: piece, bp: choix.merge('dim' => dim) }
          mesurer_cadre(pp)
          suite.call(pp)
        end
      end
      dlg.show
    end

    # Géométrie du bloc-porte de la bibliothèque : le CORPS du cadre (ce qui entre dans la cloison) est plus étroit que le hors-tout,
    # car les ailes de recouvrement débordent sur les plaques de chaque côté. Largeur et hauteur du corps = plus petite section
    # trouvée sur l'épaisseur ; hors-tout = la plus grande. Renvoie [corps_l, corps_h, total_l, total_h] en cm, ou nil.
    def self.corps_cadre(inst)
      boites = []
      rec = lambda do |ents, t|
        ents.each do |e|
          if e.is_a?(Sketchup::Face)
            pts = e.vertices.map { |v| t * v.position }
            xs = pts.map(&:x); ys = pts.map(&:y); zs = pts.map(&:z)
            boites << [xs.min, xs.max, ys.min, ys.max, zs.min, zs.max].map { |q| q.to_f * 2.54 }
          elsif e.is_a?(Sketchup::Group)
            rec.call(e.entities, t * e.transformation)
          elsif e.is_a?(Sketchup::ComponentInstance)
            rec.call(e.definition.entities, t * e.transformation)
          end
        end
      end
      rec.call(inst.definition.entities, inst.transformation)
      return nil if boites.size < 4
      ys = boites.flat_map { |b| [b[2], b[3]] }.map { |q| q.round(2) }.uniq.sort
      ls = []; hs = []
      ys.each_cons(2) do |y0, y1|
        next if y1 - y0 < 0.05
        mid = (y0 + y1) / 2.0
        bs = boites.select { |b| b[2] <= mid && b[3] >= mid && b[3] - b[2] > 0.02 }
        next if bs.empty?
        ls << bs.map { |b| b[1] }.max - bs.map { |b| b[0] }.min
        hs << bs.map { |b| b[5] }.max - bs.map { |b| b[4] }.min
      end
      return nil if ls.size < 2
      [ls.min, hs.min, ls.max, hs.max]
    rescue StandardError
      nil
    end

    # Réservation = corps du cadre quand la porte a des ailes de recouvrement (sinon le vantail + jeu saisi, comme avant)
    def self.mesurer_cadre(p)
      obj = p[:obj]
      A2M::Suivi.journal("cadre : obj=#{obj ? obj['nom'] : 'aucun'} mode=#{obj && obj['mode']} vl0=#{obj && obj['vl0']} vl=#{p[:vl]} vh=#{p[:vh]}")
      return unless obj
      return unless obj['mode'] == 'dynamique' || obj['vl0']
      model = Sketchup.active_model
      model.start_operation('Mesure du cadre', true)
      begin
        a, c = cotes(obj, p)
        r = A2M::Bibliotheque.instance_pour(model.active_entities, obj, a, c, ORIGIN, X_AXIS, Y_AXIS, ->(_e) { 0 }, model, p[:opts], false)
        m = r && corps_cadre(r)
        A2M::Suivi.journal("cadre : instance=#{r ? 'ok' : 'nil'} mesure=#{m ? m.map { |q| q.round(1) }.inspect : 'nil'}")
        if m && m[0] >= p[:vl] + 0.3 && m[2] - m[0] >= 0.3
          p[:l] = m[0].round(1)
          h = m[1] >= p[:vh] && m[3] - m[1] >= 0.3 ? m[1].round(1) : nil
          p[:h] = h if h
          p[:lin] = p[:h]
          p[:note_cadre] = "réservation prise sur le corps du cadre (#{p[:l]} × #{p[:h].round(1)} cm), ailes de recouvrement exclues (hors-tout #{m[2].round(1)} × #{m[3].round(1)})"
        end
      rescue StandardError => ex
        A2M::Suivi.journal("cadre : ERREUR #{ex.message} #{ex.backtrace.first}")
        nil
      ensure
        model.abort_operation
      end
    end

    def self.lancer
      demander { |p| Sketchup.active_model.select_tool(Outil.new(p)) }
    end

    # Transformation de l'objet : centré sur le trou (largeur et épaisseur), posé au sol du trou,
    # tourné vers le côté poussant, retourné en miroir si ses paumelles ne sont pas du côté voulu
    def self.transfo(defn, obj, base, v_pousse, paumelles)
      bv = A2M::Bibliotheque.boite_visible(defn)
      t = Geom::Transformation.translation(Geom::Vector3d.new(-bv.center.x, -bv.center.y, -bv.min.z))
      # Repère commun : côté regardé à la paramétrisation vers -Y (celui qui pousse)
      t = Geom::Transformation.rotation(ORIGIN, Z_AXIS, Math::PI) * t if (obj && obj['ext_y']) == 'max'
      t = Geom::Transformation.scaling(-1, 1, 1) * t if obj && (obj['paumelles'] || 'droite') != paumelles
      x = Z_AXIS.cross(v_pousse).normalize
      Geom::Transformation.axes(base, x, v_pousse.reverse, Z_AXIS) * t
    end

    # Cotes données à l'objet : composant dynamique = son vantail ; objet étiré = sa taille + l'écart de vantail
    def self.cotes(obj, p)
      return [p[:vl], p[:vh]] if obj['mode'] == 'dynamique'
      l0 = obj['l0'].to_f * 2.54; h0 = obj['h0'].to_f * 2.54
      return [p[:l], p[:h]] unless obj['vl0']
      [l0 + p[:vl] - obj['vl0'].to_f, h0 + p[:vh] - obj['vh0'].to_f]
    end

    def self.poser(o, p, sens, essai = 0)
      model = Sketchup.active_model
      model.start_operation('Poser une porte intérieure (métré)', true)
      begin
        ents = model.active_entities
        u, n, b = o[:u], o[:n], o[:bas]
        id = "O#{Time.now.to_f.to_s.tr('.', '')}#{rand(1000)}"
        dec = A2M::Ouvertures.decouper(o, p, p[:res] ? id : nil, model)
        unless dec
          model.abort_operation
          return UI.messagebox('Aucune cloison trouvée derrière le point cliqué.')
        end
        prof = dec[:prof]
        l = (p[:l] / 100.0).m; h = (p[:h] / 100.0).m
        base = b.offset(u, l / 2.0).offset(n, -prof / 2.0)           # milieu du trou, au sol, au milieu de l'épaisseur
        v_pousse = sens[0] == :ici ? n : n.reverse
        alerte = nil; r = nil
        if p[:res] && p[:obj]
          a, c = cotes(p[:obj], p)
          r = A2M::Bibliotheque.instance_pour(ents, p[:obj], a, c, ORIGIN, X_AXIS, Y_AXIS, ->(_e) { 0 }, model, p[:opts], false)
          alerte = A2M::Bibliotheque.alerte!
          r.transformation = transfo(r.definition, p[:obj], base, v_pousse, sens[1])
        elsif p[:res]
          # Huisserie de réservation : cadre à la taille du trou, sur toute l'épaisseur percée
          r = ents.add_group
          e = [prof, 1.cm].max; m = 4.cm
          x = Z_AXIS.cross(v_pousse).normalize
          o0 = base.offset(x, -l / 2.0).offset(v_pousse, e / 2.0)
          ext = [o0, o0.offset(x, l), o0.offset(x, l).offset(Z_AXIS, h), o0.offset(Z_AXIS, h)]
          i0 = o0.offset(x, m)
          int = [i0, i0.offset(x, l - 2 * m), i0.offset(x, l - 2 * m).offset(Z_AXIS, h - m), i0.offset(Z_AXIS, h - m)]
          f = r.entities.add_face(ext); r.entities.add_face(int).erase! rescue nil
          f = r.entities.grep(Sketchup::Face).max_by(&:area)
          f.reverse! if f.normal.dot(v_pousse) > 0
          f.pushpull(e)
        end
        if r
          tag, _ = A2M::Balises.balise(model, 'A2M_PORTE_INT', (A2M::Balises::LISTE.find { |x, _, _| x == 'A2M_PORTE_INT' } || [])[2])
          r.layer = tag
          bp = p[:bp].merge('pousse' => "poussant #{sens[1] == 'droite' ? 'droit' : 'gauche'}")
          r.set_attribute('a2m', 'bp', JSON.generate(bp))
          r.set_attribute('a2m', 'sens', JSON.generate([sens[0].to_s, sens[1]]))
          r.set_attribute('a2m', 'piece', p[:piece]) if p[:piece]
          r.name = "Porte #{bp['dim']} #{bp['pousse']}#{p[:piece] ? ' – ' + p[:piece] : ''}"
        end
        sols = prof > 0 ? A2M::Ouvertures.ajuster_sols(o, p, prof) : []
        empreinte = [b, b.offset(u, l), b.offset(u, l).offset(n, -prof), b.offset(n, -prof)]
        A2M::Plinthes.enregistrer(empreinte, 'porte', model, r ? id : nil) if prof > 0
        plin = A2M::Plinthes.regenerer_autour(empreinte)
        A2M::Suivi.lier(r, o, p, id, dec[:couches], empreinte, 'porte') if r
        model.commit_operation
        msg = "Porte #{p[:bp]['dim']} : réservation #{p[:l].round} × #{p[:h].round} cm percée dans #{dec[:nb] - dec[:echecs].size} couche(s) (#{(prof.to_f * 2.54).round(1)} cm)."
        msg += "\n#{p[:note_cadre].capitalize rescue p[:note_cadre]}" if p[:note_cadre]
        msg += "\nRevêtements prolongés jusqu'à l'axe de la porte : #{sols.join(', ')}" if sols.any?
        msg += "\nPlinthes recoupées : #{plin.join(', ')}" if plin.any?
        msg += "\n#{alerte}" if alerte
        msg += "\nNon percé (le groupe n'est pas un solide) : #{dec[:echecs].join(', ')}" if dec[:echecs].any?
        dec[:echecs].any? || alerte ? UI.messagebox(msg) : Sketchup.status_text = msg
      rescue A2M::Ouvertures::SensInverse
        model.abort_operation
        A2M::Ouvertures.inverser!
        return poser(o, p, sens, essai + 1) if essai < 1
        UI.messagebox('Le perçage n\'a pas donné le résultat attendu : rien n\'a été modifié.')
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("La porte n'a pas pu être posée (#{ex.message}).")
      end
    end

    # Même pointage que l'outil Ouverture (point de référence, sens le long du mur, distance tapée),
    # plus Tab pour le sens d'ouverture, dessiné au sol
    class Outil < A2M::Ouvertures::Outil
      def initialize(p) super(p); @s = 0 end

      def statut
        sens = A2M::PortesInt.lib_sens(A2M::PortesInt::SENS[@s])
        Sketchup.status_text = @ref ? "#{sens} (Tab pour changer). Déplacez la souris le long de la cloison, tapez la distance jusqu'au bord de la réservation puis Entrée (ou cliquez). Échap pour recommencer." :
                                      "Porte #{@p[:bp]['dim']}, réservation #{@p[:l].round} × #{@p[:h].round} cm — #{sens} (Tab). Cliquez un point de référence sur la face de la cloison (un angle, un bord…)."
        Sketchup.vcb_label = 'Distance'
      end

      def onKeyDown(key, rpt, _f, view)
        return false unless key == 9
        return true if rpt > 1
        @s = (@s + 1) % A2M::PortesInt::SENS.size
        statut; view.invalidate
        true
      end

      def poser(d)
        A2M::PortesInt.poser(ouverture(d), @p, A2M::PortesInt::SENS[@s])
        @ref = nil; @dist = nil
        statut
      end

      def draw(view)
        super
        return unless @ref && @dist
        o = ouverture(@dist)
        s = A2M::PortesInt::SENS[@s]
        l = (@p[:l] / 100.0).m; vl = (@p[:vl] / 100.0).m
        v_p = s[0] == :ici ? o[:n] : o[:n].reverse          # vers celui qui pousse
        x = Z_AXIS.cross(v_p).normalize                       # sa droite
        ep = 7.cm
        milieu = o[:bas].offset(o[:u], l / 2.0).offset(o[:n], -ep / 2.0)
        cote_ouvre = milieu.offset(v_p, -ep / 2.0)            # le vantail s'ouvre de l'autre côté
        pivot = cote_ouvre.offset(x, (s[1] == 'droite' ? 1 : -1) * vl / 2.0)
        ferme = Geom::Vector3d.new(-x.x, -x.y, 0); ferme.reverse! if s[1] == 'gauche'
        pts = (0..12).map do |i|
          a = Math::PI / 2 * i / 12.0
          dv = Geom::Vector3d.new(ferme.x * Math.cos(a) - v_p.x * Math.sin(a), ferme.y * Math.cos(a) - v_p.y * Math.sin(a), 0)
          pivot.offset(dv, vl)
        end
        view.line_width = 2; view.drawing_color = 'DarkOrange'
        view.draw(GL_LINES, [pivot, pts[-1]])
        view.line_width = 1; view.line_stipple = '-'
        view.draw(GL_LINE_STRIP, pts)
        view.line_stipple = ''
        sp = view.screen_coords(o[:centre])
        view.draw_text(Geom::Point3d.new(sp.x + 16, sp.y + 12, 0), "#{A2M::PortesInt.lib_sens(s)}  (Tab)", color: 'DimGray', size: 10) rescue nil
      end
    end
  end
end
