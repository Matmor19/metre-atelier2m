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
    def self.corps_cadre(inst, vl = 0)
      analyser_cadre(inst.definition.entities, inst.transformation, vl)
    end

    # Mesure EXACTE du cadre par ses faces planes (cm, repère de l'objet) :
    #  - faces perpendiculaires à X, hautes (>= 98 % de la plus haute) et profondes (> 5 cm) = les deux côtés du corps du cadre
    #    -> largeur et hauteur du corps, centre en X ;
    #  - faces perpendiculaires à Y, hautes (> 150 cm) et larges (>= la plus large - 3 cm) = les ailes de recouvrement et le corps
    #    -> épaisseur hors-tout, dont le milieu est le milieu du corps (ailes symétriques). La poignée et le vantail sont ignorés.
    # Renvoie { l:, h:, xc:, yc:, tot_l:, tot_h: } ou nil.
    def self.corps_faces(ents0, t0)
      px = []; py = []
      rec = lambda do |ents, t|
        ents.each do |e|
          if e.is_a?(Sketchup::Face)
            nrm = (t * e.normal) rescue e.normal
            pts = e.vertices.map { |v| t * v.position }
            xs = pts.map { |q| q.x.to_f * 2.54 }; ys = pts.map { |q| q.y.to_f * 2.54 }; zs = pts.map { |q| q.z.to_f * 2.54 }
            dx = xs.max - xs.min; dy = ys.max - ys.min; dz = zs.max - zs.min
            if nrm.x.abs > 0.99 && dy > 5 && dz > 100 then px << [xs.min, dy, dz, ys.min, ys.max]
            elsif nrm.y.abs > 0.99 && dx > 40 && dz > 150 then py << [ys.min, dx, dz, xs.min, xs.max]
            end
          elsif e.is_a?(Sketchup::Group) then rec.call(e.entities, t * e.transformation)
          elsif e.is_a?(Sketchup::ComponentInstance) then rec.call(e.definition.entities, t * e.transformation)
          end
        end
      end
      rec.call(ents0, t0)
      return nil if px.size < 2 || py.size < 2
      hmax = px.map { |f| f[2] }.max
      cotes = px.select { |f| f[2] >= hmax * 0.98 }
      return nil if cotes.size < 2
      xmin = cotes.map { |f| f[0] }.min; xmax = cotes.map { |f| f[0] }.max
      wmax = py.map { |f| f[1] }.max
      grandes = py.select { |f| f[1] >= wmax - 3.0 }
      y0 = grandes.map { |f| f[0] }.min; y1 = grandes.map { |f| f[0] }.max
      return nil if xmax - xmin < 30 || y1 - y0 < 1
      { l: xmax - xmin, h: hmax, xc: (xmin + xmax) / 2.0, yc: (y0 + y1) / 2.0, y0: y0, y1: y1, tot_l: wmax, tot_h: py.map { |f| f[2] }.max }
    rescue StandardError
      nil
    end

    # Vérification après pose : distance (cm) des faces du cadre au plan milieu de la cloison, mesurée le long de la normale n
    def self.verif_pose(r, base, n, prof)
      ds_ailes = []; ds_corps = []
      rec = lambda do |ents, t|
        ents.each do |e|
          if e.is_a?(Sketchup::Face)
            nl = (t * e.normal) rescue e.normal
            pl = e.vertices.map { |v| t * v.position }
            dz = pl.map(&:z).max - pl.map(&:z).min; dx = pl.map(&:x).max - pl.map(&:x).min
            full = pl.map { |q| (r.transformation * q - base).dot(n).to_f * 2.54 }
            if nl.y.abs > 0.99 && dx * 2.54 > 40 && dz * 2.54 > 150 then ds_ailes << [dx * 2.54, full.first]
            elsif nl.x.abs > 0.99 && dz * 2.54 > 200 then ds_corps.concat(full)
            end
          elsif e.is_a?(Sketchup::Group) then rec.call(e.entities, t * e.transformation)
          elsif e.is_a?(Sketchup::ComponentInstance) then rec.call(e.definition.entities, t * e.transformation)
          end
        end
      end
      rec.call(r.definition.entities, Geom::Transformation.new)
      wmax = ds_ailes.map(&:first).max
      ail = ds_ailes.select { |w, _| w >= wmax - 3 }.map(&:last)
      A2M::Suivi.journal("verif pose (cm, 0 = milieu cloison, cloison = ±#{(prof * 2.54 / 2).round(2)}) : ailes #{ail.min.round(2)}..#{ail.max.round(2)} | corps (faces cote) #{ds_corps.min.round(2)}..#{ds_corps.max.round(2)}")
    rescue StandardError => ex
      A2M::Suivi.journal("verif pose ERREUR #{ex.message}") rescue nil
    end

    # Diagnostic : faces perpendiculaires à Y (y, largeur, hauteur) et à X (étendue y) du cadre, en cm, dans le repère de l'objet
    def self.diag_faces(ents0, t0)
      py = []; px = []
      rec = lambda do |ents, t|
        ents.each do |e|
          if e.is_a?(Sketchup::Face)
            nrm = (t * e.normal) rescue e.normal
            pts = e.vertices.map { |v| t * v.position }
            xs = pts.map { |q| q.x * 2.54 }; ys = pts.map { |q| q.y * 2.54 }; zs = pts.map { |q| q.z * 2.54 }
            if nrm.y.abs > 0.99 && xs.max - xs.min > 2 && zs.max - zs.min > 2
              py << [ys.min.round(2), (xs.max - xs.min).round(1), (zs.max - zs.min).round(1), xs.min.round(1)]
            elsif nrm.x.abs > 0.99 && ys.max - ys.min > 1 && zs.max - zs.min > 50
              px << [xs.min.round(1), ys.min.round(2), ys.max.round(2), (zs.max - zs.min).round(0)]
            end
          elsif e.is_a?(Sketchup::Group) then rec.call(e.entities, t * e.transformation)
          elsif e.is_a?(Sketchup::ComponentInstance) then rec.call(e.definition.entities, t * e.transformation)
          end
        end
      end
      rec.call(ents0, t0)
      A2M::Suivi.journal('diag faces Y (y:largeur/hauteur@x0) : ' + py.uniq.sort.first(40).map { |a| "#{a[0]}:#{a[1]}/#{a[2]}@#{a[3]}" }.join(' '))
      A2M::Suivi.journal('diag faces X (x:y0-y1/h) : ' + px.uniq.sort.first(30).map { |a| "#{a[0]}:#{a[1]}-#{a[2]}/#{a[3]}" }.join(' '))
    rescue StandardError => ex
      A2M::Suivi.journal("diag ERREUR #{ex.message}") rescue nil
    end

    # Renvoie [corps_l, corps_h, total_l, total_h, y_milieu_corps] en cm (y du corps du cadre, dans le repère de l'objet), ou nil.
    # Corps = la plus grande largeur qui reste nettement plus étroite que les ailes (la plus grande de toutes).
    def self.analyser_cadre(ents0, t0, vl = 0)
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
      rec.call(ents0, t0)
      return nil if boites.size < 4
      ys = boites.flat_map { |b| [b[2], b[3]] }.map { |q| q.round(2) }.uniq.sort
      tr = []   # tranches : [largeur, hauteur, y0, y1]
      tous = []
      ys.each_cons(2) do |y0, y1|
        next if y1 - y0 < 0.05
        mid = (y0 + y1) / 2.0
        bs = boites.select { |b| b[2] <= mid && b[3] >= mid && b[3] - b[2] > 0.02 }
        next if bs.empty?
        l = bs.map { |b| b[1] }.max - bs.map { |b| b[0] }.min
        tous << [y0, y1, l.round(1), (bs.map { |b| b[5] }.max - bs.map { |b| b[4] }.min).round(1)]
        next if l < vl + 0.3      # tranches plus étroites que le vantail (poignée, panneau) : ignorées
        tr << [l, bs.map { |b| b[5] }.max - bs.map { |b| b[4] }.min, y0, y1]
      end
      if vl > 0
        fus = []
        tous.each do |a, b, l, h|
          d = fus.last
          if d && (d[2] - l).abs < 0.15 && (d[3] - h).abs < 0.15 && (a - d[1]).abs < 0.06 then d[1] = b else fus << [a, b, l, h] end
        end
        A2M::Suivi.journal('cadre tranches (y0-y1:largeur/hauteur) : ' + fus.map { |a, b, l, h| "#{a.round(2)}-#{b.round(2)}:#{l}/#{h}" }.join('  '))
      end
      return nil if tr.size < 2
      lmax = tr.map { |x| x[0] }.max
      hmax = tr.map { |x| x[1] }.max
      # Classes de largeur (à 0,05 cm près) : le corps du cadre est la classe la plus épaisse (somme des épaisseurs) parmi celles
      # nettement plus étroites que les ailes ; en cas d'égalité, la plus large
      classes = tr.group_by { |x| (x[0] / 0.1).round }.map do |_k, v|
        { l: v.map { |x| x[0] }.max, ep: v.sum { |x| x[3] - x[2] }, y0: v.map { |x| x[2] }.min, y1: v.map { |x| x[3] }.max, h: v.map { |x| x[1] }.min }
      end
      A2M::Suivi.journal('cadre classes : ' + classes.map { |c| "l=#{c[:l].round(1)} ep=#{c[:ep].round(1)} y=#{c[:y0].round(1)}..#{c[:y1].round(1)} h=#{c[:h].round(1)}" }.join(' | ')) rescue nil
      corps = classes.select { |c| c[:l] < lmax - 0.5 }
      corps = classes if corps.empty?
      b = corps.max_by { |c| [c[:ep].round(1), c[:l]] }
      [b[:l], b[:h], lmax, hmax, (b[:y0] + b[:y1]) / 2.0]
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
        cf = r && corps_faces(r.definition.entities, r.transformation)
        m = cf ? [cf[:l], cf[:h], cf[:tot_l], cf[:tot_h]] : (r && corps_cadre(r, p[:vl]))
        A2M::Suivi.journal("cadre : faces=#{cf ? cf.map { |k, v| "#{k}=#{v.round(2)}" }.join(' ') : 'nil'}")
        diag_faces(r.definition.entities, r.transformation) if r
        A2M::Suivi.journal("cadre : instance=#{r ? 'ok' : 'nil'} mesure=#{m ? m.map { |q| q.round(1) }.inspect : 'nil'}")
        if m && m[0] >= p[:vl] + 0.3 && m[2] - m[0] >= 0.3
          p[:l] = m[0].round(1)
          h = m[1] >= p[:vh] - 0.3 && m[3] - m[1] >= 0.3 ? m[1].round(1) : nil
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
      xm = bv.center.x; ym = bv.center.y
      cf = (corps_faces(defn.entities, Geom::Transformation.new) rescue nil)
      if cf   # centré sur le CORPS du cadre (largeur et épaisseur), ni les ailes, ni le vantail, ni la poignée
        xm = cf[:xc] / 2.54; ym = cf[:yc] / 2.54
      end
      A2M::Suivi.journal("porte : centre boite=(#{(bv.center.x * 2.54).round(2)}, #{(bv.center.y * 2.54).round(2)}) corps=#{cf ? "(#{cf[:xc].round(2)}, #{cf[:yc].round(2)})" : 'nil'}") rescue nil
      t = Geom::Transformation.translation(Geom::Vector3d.new(-xm, -ym, -bv.min.z))
      # Repère commun : côté regardé à la paramétrisation vers -Y (celui qui pousse)
      t = Geom::Transformation.rotation(ORIGIN, Z_AXIS, Math::PI) * t if (obj && obj['ext_y']) == 'max'
      x = Z_AXIS.cross(v_pousse).normalize                 # la droite de celui qui pousse
      # Charnière : mesurée sur la géométrie. La poignée est à l'extrémité libre du vantail, donc à l'opposé de la charnière :
      # charnière à droite (vue du côté poussant) = poignée à gauche. Si la poignée n'est pas trouvée, on se fie au réglage mémorisé.
      hx = (cf && cf[:y1]) ? poignee_x(defn, cf, Geom::Transformation.axes(base, x, v_pousse.reverse, Z_AXIS) * t, base, x) : nil
      if hx
        mir = (hx > 0) == (paumelles == 'droite')
      else
        mir = obj && (obj['paumelles'] || 'droite') != paumelles
      end
      A2M::Suivi.journal("porte : poignée #{hx ? (hx > 0 ? 'à droite' : 'à gauche') : 'non trouvée'} (vue du côté poussant), charnière voulue #{paumelles}, miroir #{mir ? 'oui' : 'non'}") rescue nil
      t = Geom::Transformation.scaling(-1, 1, 1) * t if mir
      Geom::Transformation.axes(base, x, v_pousse.reverse, Z_AXIS) * t
    end

    # Côté de la poignée : position (pouces) le long de x (droite de celui qui pousse) ; nil si introuvable.
    # On prend les petites faces (moins de 15 cm de large) situées au-delà de l'épaisseur du cadre, on les range à droite ou à gauche
    # du milieu, et la poignée est le groupe qui s'étale le moins en hauteur (la poignée est à un seul endroit, alors que les
    # paumelles sont réparties sur toute la hauteur du vantail).
    def self.poignee_x(defn, cf, m0, base, x)
      pts_xz = []
      marge = 1.0 / 2.54
      y0 = cf[:y0] / 2.54; y1 = cf[:y1] / 2.54
      rec = lambda do |ents, tn|
        ents.each do |e|
          if e.is_a?(Sketchup::Face)
            pts = e.vertices.map { |v| tn * v.position }
            dx = pts.map(&:x).max - pts.map(&:x).min
            ym = pts.map(&:y).sum / pts.size
            next unless dx * 2.54 < 15 && (ym > y1 + marge || ym < y0 - marge)
            c = Geom::Point3d.new(pts.map(&:x).sum / pts.size, ym, pts.map(&:z).sum / pts.size)
            pts_xz << [(m0 * c - base).dot(x).to_f, c.z.to_f * 2.54]
          elsif e.is_a?(Sketchup::Group) then rec.call(e.entities, tn * e.transformation)
          elsif e.is_a?(Sketchup::ComponentInstance) then rec.call(e.definition.entities, tn * e.transformation)
          end
        end
      end
      rec.call(defn.entities, Geom::Transformation.new)
      dr = pts_xz.select { |px, _| px * 2.54 > 2.0 }
      ga = pts_xz.select { |px, _| px * 2.54 < -2.0 }
      etal = ->(g) { g.empty? ? nil : g.map(&:last).max - g.map(&:last).min }
      er = etal.call(dr); eg = etal.call(ga)
      A2M::Suivi.journal("porte : poignée, faces à droite #{dr.size} (étalement #{er ? er.round : '-'} cm), à gauche #{ga.size} (étalement #{eg ? eg.round : '-'} cm)") rescue nil
      choix = if er && eg
        return nil if (er - eg).abs < 30
        er < eg ? dr : ga
      elsif er && er < 40 then dr
      elsif eg && eg < 40 then ga
      end
      return nil if choix.nil? || choix.size < 2
      choix.sum { |px, _| px } / choix.size
    rescue StandardError
      nil
    end

    # Cotes données à l'objet : composant dynamique = son vantail ; objet étiré = sa taille + l'écart de vantail
    def self.cotes(obj, p)
      return [p[:vl], p[:vh]] if obj['mode'] == 'dynamique'
      l0 = obj['l0'].to_f * 2.54; h0 = obj['h0'].to_f * 2.54
      return [p[:l], p[:h]] unless obj['vl0']
      [l0 + p[:vl] - obj['vl0'].to_f, h0 + p[:vh] - obj['vh0'].to_f]
    end

    # Ouverture animée au clic (comme une porte moulurée) : le panneau devient un composant dynamique qui tourne autour de
    # l'axe de la charnière = centre de l'arc 2D « sens ouverture 2D » dessiné dans le panneau. Rien n'est changé à la
    # géométrie ; l'arc 2D reste en place (il sort du panneau) ; chaque porte posée a sa propre définition.
    def self.animer(r)
      d = r.definition
      r.make_unique if d.instances.size > 1
      ents = r.definition.entities
      pan = ents.grep(Sketchup::Group).find { |g| g.name == 'Panneau' }
      return A2M::Suivi.journal('animation : pas de « Panneau » dans cette porte, animation non posée') unless pan
      arc = pan.entities.grep(Sketchup::Group).find { |g| g.name.to_s =~ /sens ouverture/i }
      cb = arc && arc.entities.grep(Sketchup::Edge).map(&:curve).compact.find { |k| k.respond_to?(:center) }
      return A2M::Suivi.journal('animation : arc « sens ouverture 2D » introuvable, animation non posée') unless cb
      c = arc.transformation * cb.center                        # axe de la charnière, repère du panneau
      # l'arc sort du panneau (il ne doit pas tourner)
      t_pan = pan.transformation
      nom_arc = arc.name; tag_arc = arc.layer
      sortie = ents.add_instance(arc.definition, t_pan * arc.transformation)
      sortie.name = nom_arc; sortie.layer = tag_arc
      arc.erase!
      nom = pan.name; tag = pan.layer
      pc = pan.to_component
      pc.name = nom; pc.layer = tag
      pc.make_unique if pc.definition.instances.size > 1
      # origine du composant sur l'axe de la charnière, sans bouger la géométrie
      v = Geom::Vector3d.new(c.x, c.y, 0)
      pc.definition.entities.transform_entities(Geom::Transformation.translation(v.reverse), pc.definition.entities.to_a)
      pc.transformation = t_pan * Geom::Transformation.translation(v)
      att = {
        '_has_movetool_behaviors' => '1.0', '_hasbehaviors' => '1.0', '_name' => 'panneau',
        '_onclick_label' => 'onClick', '_onclick_state1' => '0', 'onclick' => 'ANIMATE("RotZ",0,90)',
        'rotz' => '0.0', '_rotz_label' => 'RotZ', '_rotz_formula' => ''
      }
      [pc, pc.definition].each { |o| att.each { |k, val| o.set_attribute('dynamic_attributes', k, val) } }
      A2M::Suivi.journal("animation : panneau animé, axe de charnière à (#{(c.x * 2.54).round(2)} ; #{(c.y * 2.54).round(2)}) cm dans le panneau")
    rescue StandardError => ex
      A2M::Suivi.journal("ERREUR animation : #{ex.message} #{ex.backtrace.first}") rescue nil
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
          verif_pose(r, base, n, prof)
          animer(r) if p[:obj]['balise'] == 'A2M_PORTE_INT' && p[:obj]['mode'] != 'dynamique'
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

# Le journal s'affiche dans une fenêtre lisible (redéfini ici pour s'appliquer sans redémarrer SketchUp)
module A2M
  module Suivi
    def self.afficher_journal
      f = File.join(File.dirname(A2M::Bibliotheque.dossier), 'journal_ouvertures.txt')
      lignes = File.exist?(f) ? File.readlines(f, encoding: 'UTF-8').last(30).map { |l| l.strip[0, 1500] } : ['(journal vide)']
      esc = ->(t) { t.to_s.gsub('&', '&amp;').gsub('<', '&lt;').gsub('>', '&gt;') }
      html = "<html><body style='font-family:Consolas,monospace;font-size:17px;margin:12px;background:#fff;color:#222'>" \
             "<h3 style='margin:0 0 8px 0'>Suivi des ouvertures : #{@cache.size} menuiserie(s) suivie(s), #{@attente.size} en attente</h3>" \
             "<pre style='white-space:pre-wrap;line-height:1.35'>#{esc.call(lignes.join("\n"))}</pre></body></html>"
      dlg = UI::HtmlDialog.new(dialog_title: 'Journal des ouvertures', width: 900, height: 620, resizable: true, style: UI::HtmlDialog::STYLE_DIALOG)
      dlg.set_html(html)
      dlg.show
    rescue StandardError
      UI.messagebox("Suivi des ouvertures : #{@cache.size} menuiserie(s) suivie(s)\n\n#{lignes.to_a.last(14).join("\n")}")
    end
  end
end

# Mise à jour à chaud : menu_contextuel.rb n'est pas rechargé en cours de session, on redéfinit ici le calcul de l'axe et du centre
module A2M
  module MenuContextuel
    def self.axes(e)
      bb = e.bounds
      c = bb.center
      t = e.transformation
      c = Geom::Point3d.new(t.origin.x, t.origin.y, c.z) if e.get_attribute('a2m_biblio', 'fichier')
      bl = (e.is_a?(Sketchup::Group) ? e.entities.parent : e.definition).bounds
      wx = bl.width * t.xscale; wy = bl.height * t.yscale
      ax = wx >= wy ? t.xaxis : t.yaxis
      ax = Geom::Vector3d.new(ax.x, ax.y, 0)
      ax = ax.length > 0.001 ? ax.normalize : Geom::Vector3d.new(1, 0, 0)
      [c, ax]
    end
  end
end

# ---- Relevé (une seule fois) de la structure des portes de la bibliothèque : prépare l'animation d'ouverture ----
module A2M
  module DiagPortes
    FICHIERS = ['Portes interieures/B.P 83x204 Chauvat.skp', 'Portes interieures/B.P 63x204 Chauvat.skp',
                'Portes interieures/porte molurée.skp'].freeze

    def self.cm(v) (v.to_f * 2.54).round(2) end

    def self.pt(p) p.to_a.map { |v| cm(v) }.inspect end

    def self.attrs(e, niv, sortie)
      return unless e.attribute_dictionaries
      e.attribute_dictionaries.each do |dic|
        dic.each_pair { |k, v| sortie << "#{'  ' * niv}@#{dic.name}.#{k} = #{v.to_s[0, 160].inspect}" }
      end
    end

    def self.arbre(ents, niv, sortie)
      pre = '  ' * niv
      ents.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        d = e.definition
        b = e.bounds
        sortie << "#{pre}#{e.is_a?(Sketchup::Group) ? 'GROUPE' : 'COMPOSANT'} nom=#{e.name.inspect} def=#{d.name.inspect} tag=#{e.layer.name} " \
                  "min=#{pt(b.min)} max=#{pt(b.max)} origine=#{pt(e.transformation.origin)}"
        attrs(e, niv + 1, sortie)
        attrs(d, niv + 1, sortie) unless e.is_a?(Sketchup::Group)
        arbre(d.entities, niv + 1, sortie)
      end
      courbes = ents.grep(Sketchup::Edge).map(&:curve).compact.uniq
      courbes.each do |c|
        if c.respond_to?(:center)
          sortie << "#{pre}ARC centre=#{pt(c.center)} rayon=#{cm(c.radius)} angles=#{c.start_angle.radians.round(1)}..#{c.end_angle.radians.round(1)}"
        else
          sortie << "#{pre}COURBE #{c.class} #{c.vertices.size} points"
        end
      end
      sortie << "#{pre}(#{ents.grep(Sketchup::Edge).size} arêtes, #{ents.grep(Sketchup::Face).size} faces à ce niveau)"
    end

    def self.releve
      cible = File.join(File.dirname(A2M::Bibliotheque.dossier), 'diag_portes.txt')
      return if File.exist?(cible)
      model = Sketchup.active_model
      sortie = ["Relevé des portes (cm) – version #{A2M::EXT.version rescue '?'}"]
      FICHIERS.each do |f|
        chemin = File.join(A2M::Bibliotheque.dossier, f)
        sortie << ''
        sortie << "=== #{f}"
        begin
          model.start_operation('Relevé porte', true)
          d = model.definitions.load(chemin)
          sortie << "définition : #{d.name.inspect}"
          attrs(d, 1, sortie)
          arbre(d.entities, 1, sortie)
        rescue StandardError => ex
          sortie << "ERREUR : #{ex.message}"
        ensure
          model.abort_operation   # rien ne reste dans le modèle
        end
      end
      File.write(cible, sortie.join("\n"), encoding: 'UTF-8')
    rescue StandardError
      nil
    end
  end
end
UI.start_timer(2, false) { A2M::DiagPortes.releve }
