# encoding: UTF-8
# Métré Atelier 2M : compositions de parois (murs, cloisons, dalles, planchers, plafonds). Chaque composition = une pile de couches
# (type du métré, épaisseur, couleur), montrée en vignette. On choisit une vignette, on règle les épaisseurs, puis on pose :
# au clic (murs, cloisons), sur les lignes sélectionnées, ou sur les murs sélectionnés (dalles, planchers, plafonds).
# Vos propres compositions sont rangées dans Documents/Atelier 2M/Compositions/compositions.json et s'ajoutent à celles fournies.
require 'sketchup.rb'
require 'json'
require 'fileutils'

module A2M
  module Compositions
    FAMILLES = ['Murs', 'Cloisons', 'Dalles et planchers', 'Plafonds'].freeze
    MURS = ['Murs', 'Cloisons'].freeze

    BALISES_MUR = [['A2M_MUR_PERI', 'Maçonnerie ou structure (mur périphérique)'], ['A2M_MUR_REFEND', 'Mur de refend'], ['A2M_MUR_SOUB', 'Soubassement'],
                   ['A2M_MUR_PIGNON', 'Mur pignon'], ['A2M_ENDUIT_EXT', 'Enduit extérieur'], ['A2M_ISOLANT_DOUBLAGE', 'Isolant (doublage)'], ['A2M_DOUBLAGE', 'Plaque de plâtre (doublage)'],
                   ['A2M_CLOISON', 'Cloison']].freeze
    BALISES_SOL = [['A2M_DALLAGE', 'Dalle béton (RDC)'], ['A2M_PLANCHER_ETAGE', 'Plancher d\'étage'], ['A2M_ISOLANT_SOL', 'Isolation au sol'],
                   ['A2M_CHAPE', 'Chape'], ['A2M_PLAFOND', 'Plafond']].freeze
    COULEURS = { 'A2M_MUR_PERI' => [190, 175, 160], 'A2M_MUR_REFEND' => [170, 165, 160], 'A2M_MUR_SOUB' => [150, 150, 150], 'A2M_MUR_PIGNON' => [190, 175, 160], 'A2M_ENDUIT_EXT' => [225, 210, 185],
                 'A2M_ISOLANT_DOUBLAGE' => [250, 224, 140], 'A2M_DOUBLAGE' => [245, 245, 245], 'A2M_CLOISON' => [225, 215, 200],
                 'A2M_DALLAGE' => [150, 150, 155], 'A2M_PLANCHER_ETAGE' => [190, 150, 100], 'A2M_ISOLANT_SOL' => [250, 224, 140],
                 'A2M_CHAPE' => [205, 190, 160], 'A2M_PLAFOND' => [240, 240, 245] }.freeze

    def self.c(nom, balise, e, h = nil) h ? { 'nom' => nom, 'balise' => balise, 'e' => e, 'h' => h } : { 'nom' => nom, 'balise' => balise, 'e' => e } end

    # Compositions fournies (modifiables en copie). Murs : de l'extérieur vers l'intérieur. Sols : de bas en haut.
    FOURNIES = [
      { 'id' => 'f_mur_brique_enduit', 'nom' => 'Enduit ext. 1,8 + brique 20 + isolant 12 + plaque', 'famille' => 'Murs', 'couches' => [c('Enduit extérieur', 'A2M_ENDUIT_EXT', 1.8), c('Brique', 'A2M_MUR_PERI', 20), c('Isolant', 'A2M_ISOLANT_DOUBLAGE', 12), c('Plaque de plâtre', 'A2M_DOUBLAGE', 1.3)] },
      { 'id' => 'f_mur_parpaing_enduit', 'nom' => 'Enduit ext. 1,8 + parpaing 20 + doublage isolé', 'famille' => 'Murs', 'couches' => [c('Enduit extérieur', 'A2M_ENDUIT_EXT', 1.8), c('Parpaing', 'A2M_MUR_PERI', 20), c('Isolant', 'A2M_ISOLANT_DOUBLAGE', 10), c('Plaque de plâtre', 'A2M_DOUBLAGE', 1.3)] },
      { 'id' => 'f_mur_parpaing_enduit_brut', 'nom' => 'Enduit ext. 1,8 + parpaing 20 brut', 'famille' => 'Murs', 'couches' => [c('Enduit extérieur', 'A2M_ENDUIT_EXT', 1.8), c('Parpaing', 'A2M_MUR_PERI', 20)] },
      { 'id' => 'f_mur_brique', 'nom' => 'Brique 20 + isolant 12 + plaque', 'famille' => 'Murs', 'couches' => [c('Brique', 'A2M_MUR_PERI', 20), c('Isolant', 'A2M_ISOLANT_DOUBLAGE', 12), c('Plaque de plâtre', 'A2M_DOUBLAGE', 1.3)] },
      { 'id' => 'f_mur_parpaing_doub', 'nom' => 'Parpaing 20 + doublage isolé', 'famille' => 'Murs', 'couches' => [c('Parpaing', 'A2M_MUR_PERI', 20), c('Isolant', 'A2M_ISOLANT_DOUBLAGE', 10), c('Plaque de plâtre', 'A2M_DOUBLAGE', 1.3)] },
      { 'id' => 'f_mur_parpaing', 'nom' => 'Parpaing 20 brut', 'famille' => 'Murs', 'couches' => [c('Parpaing', 'A2M_MUR_PERI', 20)] },
      { 'id' => 'f_mur_ossature', 'nom' => 'Ossature bois 14,5 + isolant + plaque', 'famille' => 'Murs', 'couches' => [c('Ossature bois', 'A2M_MUR_PERI', 14.5), c('Isolant', 'A2M_ISOLANT_DOUBLAGE', 4.5), c('Plaque de plâtre', 'A2M_DOUBLAGE', 1.3)] },
      { 'id' => 'f_mur_refend', 'nom' => 'Refend béton 20', 'famille' => 'Murs', 'couches' => [c('Béton', 'A2M_MUR_REFEND', 20)] },
      { 'id' => 'f_mur_soub', 'nom' => 'Soubassement parpaing 20', 'famille' => 'Murs', 'couches' => [c('Parpaing', 'A2M_MUR_SOUB', 20, 1.0)] },
      { 'id' => 'f_cl_72', 'nom' => 'Cloison placo 72/48', 'famille' => 'Cloisons', 'couches' => [c('Cloison', 'A2M_CLOISON', 7.2)] },
      { 'id' => 'f_cl_98', 'nom' => 'Cloison placo 98/48', 'famille' => 'Cloisons', 'couches' => [c('Cloison', 'A2M_CLOISON', 9.8)] },
      { 'id' => 'f_cl_carreaux', 'nom' => 'Carreaux de plâtre 7', 'famille' => 'Cloisons', 'couches' => [c('Carreaux de plâtre', 'A2M_CLOISON', 7)] },
      { 'id' => 'f_cl_brique', 'nom' => 'Cloison brique 5', 'famille' => 'Cloisons', 'couches' => [c('Brique', 'A2M_CLOISON', 5)] },
      { 'id' => 'f_dalle_tp', 'nom' => 'Dalle terre-plein : béton 12 + isolant 10 + chape 5', 'famille' => 'Dalles et planchers', 'couches' => [c('Dalle béton', 'A2M_DALLAGE', 12), c('Isolation au sol', 'A2M_ISOLANT_SOL', 10), c('Chape', 'A2M_CHAPE', 5)] },
      { 'id' => 'f_dalle_brute', 'nom' => 'Dalle brute béton 15', 'famille' => 'Dalles et planchers', 'couches' => [c('Dalle béton', 'A2M_DALLAGE', 15)] },
      { 'id' => 'f_dalle_isolee', 'nom' => 'Dalle béton 12 + isolant 10', 'famille' => 'Dalles et planchers', 'couches' => [c('Dalle béton', 'A2M_DALLAGE', 12), c('Isolation au sol', 'A2M_ISOLANT_SOL', 10)] },
      { 'id' => 'f_plancher_hourdis', 'nom' => 'Plancher hourdis 20 + chape 5', 'famille' => 'Dalles et planchers', 'couches' => [c('Plancher hourdis', 'A2M_PLANCHER_ETAGE', 20), c('Chape', 'A2M_CHAPE', 5)] },
      { 'id' => 'f_plancher_bois', 'nom' => 'Plancher bois 22', 'famille' => 'Dalles et planchers', 'couches' => [c('Plancher bois', 'A2M_PLANCHER_ETAGE', 22)] },
      { 'id' => 'f_plafond_ba13', 'nom' => 'Plafond placo BA13', 'famille' => 'Plafonds', 'couches' => [c('Plafond', 'A2M_PLAFOND', 1.3)] },
      { 'id' => 'f_plafond_ba18', 'nom' => 'Plafond placo 2 × BA13', 'famille' => 'Plafonds', 'couches' => [c('Plafond', 'A2M_PLAFOND', 2.6)] }
    ].each { |x| x['integre'] = true }.freeze

    def self.dossier
      base = ENV['USERPROFILE'] || ENV['HOME'] || Dir.home
      doc = File.join(base, 'Documents')
      File.join(File.directory?(doc) ? doc : base, 'Atelier 2M', 'Compositions').tr('\\', '/')
    end

    def self.fichier() File.join(dossier, 'compositions.json') end

    def self.utilisateur
      return [] unless File.exist?(fichier)
      l = JSON.parse(File.read(fichier, encoding: 'UTF-8')) rescue []
      l.is_a?(Array) ? l.select { |x| x.is_a?(Hash) && x['couches'].is_a?(Array) } : []
    end

    def self.enregistrer(liste)
      FileUtils.mkdir_p(dossier)
      File.write(fichier, JSON.pretty_generate(liste), encoding: 'UTF-8')
    end

    def self.toutes() utilisateur + FOURNIES end
    def self.trouver(id) toutes.find { |x| x['id'] == id } end

    # Composition prête pour le panneau : couleurs ajoutées
    def self.pour_panneau(x)
      x.merge('couches' => x['couches'].map { |k| k.merge('couleur' => k['couleur'] || COULEURS[k['balise']] || [190, 190, 190]) })
    end

    def self.donnees
      { 'liste' => toutes.map { |x| pour_panneau(x) }, 'familles' => FAMILLES, 'dossier' => dossier,
        'balisesMur' => BALISES_MUR, 'balisesSol' => BALISES_SOL }
    end

    # ---- Chaînage des lignes sélectionnées en tracés ----
    def self.tracés(edges)
      reste = edges.dup
      res = []
      until reste.empty?
        e = reste.shift
        pts = [e.start.position, e.end.position]
        loop do
          sui = reste.find { |x| x.start.position == pts.last || x.end.position == pts.last }
          if sui
            reste.delete(sui)
            pts << (sui.start.position == pts.last ? sui.end.position : sui.start.position)
            next
          end
          pre = reste.find { |x| x.start.position == pts.first || x.end.position == pts.first }
          break unless pre
          reste.delete(pre)
          pts.unshift(pre.start.position == pts.first ? pre.end.position : pre.start.position)
        end
        ferme = pts.size > 3 && pts.first == pts.last
        pts.pop if ferme
        res << [pts, ferme]
      end
      res
    end

    def self.poser(r)
      comp = trouver(r['id']) or return UI.messagebox('Composition introuvable.')
      es = r['e'] || []
      couches = comp['couches'].each_with_index.map { |k, i| k.merge('e' => (es[i].to_s.tr(',', '.').to_f > 0 ? es[i].to_s.tr(',', '.').to_f : k['e'].to_f)) }
      if MURS.include?(comp['famille'])
        h = r['h'].to_s.tr(',', '.').to_f
        h = 2.5 if h <= 0
        cs = couches.map do |k|
          t = A2M::DessinMurs::TYPES.find { |x| x[1] == k['balise'] } || A2M::DessinMurs::TYPES[0]
          { type: t, e: k['e'].to_f, h: (k['h'] || (r['h'].to_s.empty? ? t[2] : h)).to_f }
        end
        cote = r['cote'].to_i
        p = { couches: cs, cote: cote, type: ['Mur composé'], h: cs.map { |c| c[:h] }.max, e: cs.sum { |c| c[:e] }.round(1) }
        if r['mode'] == 'selection'
          edges = Sketchup.active_model.selection.grep(Sketchup::Edge)
          return UI.messagebox('Sélectionnez d\'abord les lignes (ou arêtes) le long desquelles poser le mur.') if edges.empty?
          tracés(edges).each { |pts, ferme| A2M::DessinMurs.construire(pts, ferme, p) }
        else
          Sketchup.active_model.select_tool(A2M::DessinMurs::Outil.new(p))
        end
      else
        if r['mode'] == 'face'
          f = Sketchup.active_model.selection.grep(Sketchup::Face).first
          return UI.messagebox('Sélectionnez d\'abord une face horizontale (le contour du sol).') unless f
          surf = [[f.outer_loop.vertices.map(&:position), f.loops.reject(&:outer?).map { |lp| lp.vertices.map(&:position) }]]
          A2M::SolMurs.poser_couches(couches, r['hsp'], surf, f.vertices.first.position.z)
        else
          A2M::SolMurs.poser_couches(couches, r['hsp'], nil)
        end
      end
    end

    CORPS = <<~'HTML'
      <div id="vue_liste">
        <div class="puces" id="fam"></div>
        <div class="grille" id="cartes" style="margin-top:10px;grid-template-columns:repeat(auto-fill,minmax(130px,1fr))"></div>
        <div id="detail" style="display:none">
          <h2 id="dtitre"></h2>
          <div id="couches"></div>
          <div class="petit" id="total"></div>
          <div class="dims" id="hbloc" style="margin-top:8px;grid-template-columns:1fr"><div><label id="hlib">Hauteur (m)</label><input type="text" id="h"></div></div>
          <div class="puces" id="cotes" style="margin-top:8px"></div>
          <div class="puces" id="niv" style="margin-top:8px"></div>
          <div class="puces" id="actions" style="margin-top:12px"></div>
        </div>
        <div class="petit" id="aide" style="margin-top:12px"></div>
      </div>
      <div id="vue_edit" style="display:none">
        <h2>Nouvelle composition</h2>
        <div class="dims" style="grid-template-columns:1fr 1fr"><div><label>Nom</label><input type="text" id="enom" style="font-size:14px;text-align:left"></div><div><label>Famille</label><select id="efam" style="width:100%;padding:8px;border:2px solid #d8d0c6;border-radius:9px;background:#fff"></select></div></div>
        <h2 id="elib">Couches</h2>
        <div id="elignes"></div>
        <div class="puces" style="margin-top:8px"><button type="button" class="puce" id="eajout">+ Ajouter une couche</button></div>
        <div class="petit" id="eaide"></div>
      </div>
      <div id="bas"><div id="msg"></div><button type="button" id="nouv" class="puce">Nouvelle composition</button><button type="button" id="modif" class="puce" style="display:none">Modifier</button><button type="button" id="suppr" class="puce" style="display:none">Supprimer</button><button type="button" id="ok" style="display:none">Enregistrer</button><button type="button" id="ann" class="puce" style="display:none">Annuler</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      var fam = D.familles[0], sel = null, e = [], etat = { cote: 0, niveau: 'RDC', mode: null };
      var edit = null;
      function el(i) { return document.getElementById(i); }
      function num(v) { return parseFloat(String(v).replace(',', '.')); }
      function murs(f) { return f === 'Murs' || f === 'Cloisons'; }
      function vignette(c, est_mur) {
        var tot = c.couches.reduce(function (a, k) { return a + k.e; }, 0), W = 100, H = 56, x = 4, y = H - 4, svg = '';
        if (est_mur) {
          var lar = W - 8, cx = 4;
          c.couches.forEach(function (k) { var w = Math.max(lar * k.e / tot, 4); svg += '<rect x="' + cx + '" y="6" width="' + w + '" height="' + (H - 12) + '" fill="rgb(' + k.couleur.join(',') + ')" stroke="#3C3C3C" stroke-width=".8"/>'; cx += w; });
        } else {
          var haut = H - 12, cy = H - 6;
          c.couches.forEach(function (k) { var h = Math.max(haut * k.e / tot, 4); cy -= h; svg += '<rect x="6" y="' + cy + '" width="' + (W - 12) + '" height="' + h + '" fill="rgb(' + k.couleur.join(',') + ')" stroke="#3C3C3C" stroke-width=".8"/>'; });
        }
        return '<svg viewBox="0 0 ' + W + ' ' + H + '" width="100%" height="64">' + svg + '</svg>';
      }
      function maj(d) { D = d; if (sel && !D.liste.some(function (x) { return x.id === sel.id; })) sel = null; rendre(); }
      function rendre() {
        el('vue_liste').style.display = edit ? 'none' : ''; el('vue_edit').style.display = edit ? '' : 'none';
        el('nouv').style.display = edit ? 'none' : ''; el('ok').style.display = edit ? '' : 'none'; el('ann').style.display = edit ? '' : 'none';
        el('modif').style.display = (!edit && sel) ? '' : 'none'; el('suppr').style.display = (!edit && sel && !sel.integre) ? '' : 'none';
        if (edit) return rendre_edit();
        var f = el('fam'); f.innerHTML = '';
        D.familles.forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (fam === x ? ' rempli' : ''); b.textContent = x;
          b.addEventListener('click', function () { fam = x; sel = null; rendre(); }); f.appendChild(b);
        });
        var g = el('cartes'); g.innerHTML = '';
        D.liste.filter(function (x) { return x.famille === fam; }).forEach(function (x) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte' + (sel && sel.id === x.id ? ' rempli' : '');
          var tot = x.couches.reduce(function (a, k) { return a + k.e; }, 0);
          b.innerHTML = '<div class="vignette" style="height:64px;background:#fff">' + vignette(x, murs(x.famille)) + '</div><span></span><div class="petit" style="margin:2px 0 0"></div>';
          b.querySelector('span').textContent = x.nom; b.querySelector('.petit').textContent = (Math.round(tot * 10) / 10) + ' cm' + (x.integre ? '' : ' · à vous');
          b.addEventListener('click', function () { sel = x; e = x.couches.map(function (k) { return k.e; }); rendre(); }); g.appendChild(b);
        });
        el('aide').textContent = D.liste.filter(function (x) { return x.famille === fam; }).length ? 'Cliquez une vignette pour régler les épaisseurs et poser.' : 'Aucune composition ici : créez-en une avec « Nouvelle composition ».';
        var det = el('detail'); det.style.display = sel ? '' : 'none';
        if (!sel) { el('msg').textContent = ''; return; }
        el('dtitre').textContent = sel.nom;
        var c = el('couches'); c.innerHTML = '';
        sel.couches.forEach(function (k, i) {
          var l = document.createElement('div'); l.style.cssText = 'display:flex;align-items:center;gap:8px;margin-bottom:6px';
          l.innerHTML = '<div style="width:18px;height:18px;border-radius:4px;border:1px solid #3C3C3C;background:rgb(' + k.couleur.join(',') + ')"></div><div style="flex:1;font-size:12.5px"></div><input type="text" style="width:70px;font-size:14px;padding:5px;text-align:center"><span>cm</span>';
          l.children[1].textContent = k.nom; var inp = l.querySelector('input'); inp.value = e[i];
          inp.addEventListener('input', function () { e[i] = num(inp.value); tot(); }); c.appendChild(l);
        });
        tot();
        var m = murs(sel.famille);
        el('hbloc').style.display = m ? '' : 'none'; if (m && !el('h').value) el('h').value = '2.5';
        var co = el('cotes'); co.innerHTML = '';
        if (m && sel.couches.length > 1) ['Couches à droite du tracé', 'Couches à gauche', 'Tracé dans l\'axe'].forEach(function (t, i) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (etat.cote === i ? ' rempli' : ''); b.textContent = t;
          b.addEventListener('click', function () { etat.cote = i; rendre(); }); co.appendChild(b);
        });
        var nv = el('niv'); nv.innerHTML = '';
        if (!m) { ['RDC', 'Étage'].forEach(function (t) { var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (etat.niveau === t ? ' rempli' : ''); b.textContent = t; b.addEventListener('click', function () { etat.niveau = t; rendre(); }); nv.appendChild(b); });
          if (sel.couches.some(function (k) { return k.balise === 'A2M_PLAFOND'; })) { var d = document.createElement('input'); d.type = 'text'; d.id = 'hsp'; d.value = '250'; d.style.cssText = 'width:80px;font-size:14px;padding:5px'; var lb = document.createElement('span'); lb.textContent = 'hauteur sous plafond (cm)'; nv.appendChild(d); nv.appendChild(lb); } }
        var ac = el('actions'); ac.innerHTML = '';
        var acts = m ? [['clic', 'Tracer au clic'], ['selection', 'Sur les lignes sélectionnées']] : [['murs', 'Sur les murs sélectionnés'], ['face', 'Sur la face sélectionnée']];
        acts.forEach(function (a) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce rempli'; b.style.fontWeight = '600'; b.textContent = a[1];
          b.addEventListener('click', function () {
            var h = el('hsp'); sketchup.poser(JSON.stringify({ id: sel.id, e: e, h: el('h').value, cote: etat.cote, mode: a[0], niveau: etat.niveau, hsp: h ? h.value : '' }));
          }); ac.appendChild(b);
        });
      }
      function tot() { if (!sel) return; var t = e.reduce(function (a, v) { return a + (v > 0 ? v : 0); }, 0); el('total').textContent = 'Épaisseur totale : ' + (Math.round(t * 10) / 10) + ' cm'; }
      // ---- Création / modification ----
      function rendre_edit() {
        var s = el('efam'); if (!s.options.length) D.familles.forEach(function (x) { var o = document.createElement('option'); o.value = x; o.textContent = x; s.appendChild(o); });
        s.value = edit.famille; el('enom').value = edit.nom; s.onchange = function () { edit.famille = s.value; edit.couches.forEach(function (k) { k.balise = opts()[0][0]; }); rendre_edit(); };
        el('enom').oninput = function () { edit.nom = this.value; };
        el('elib').textContent = murs(edit.famille) ? 'Couches, de l\'extérieur vers l\'intérieur' : 'Couches, de bas en haut';
        var L = el('elignes'); L.innerHTML = '';
        edit.couches.forEach(function (k, i) {
          var l = document.createElement('div'); l.style.cssText = 'display:grid;grid-template-columns:1fr 1.3fr 70px 26px;gap:6px;margin-bottom:6px;align-items:center';
          var nom = document.createElement('input'); nom.type = 'text'; nom.value = k.nom; nom.placeholder = 'Nom'; nom.style.cssText = 'font-size:13px;padding:5px;text-align:left'; nom.oninput = function () { k.nom = nom.value; };
          var sb = document.createElement('select'); sb.style.cssText = 'padding:6px;border:2px solid #d8d0c6;border-radius:8px;background:#fff';
          opts().forEach(function (o) { var op = document.createElement('option'); op.value = o[0]; op.textContent = o[1]; sb.appendChild(op); }); sb.value = k.balise; sb.onchange = function () { k.balise = sb.value; };
          var ep = document.createElement('input'); ep.type = 'text'; ep.value = k.e; ep.style.cssText = 'font-size:13px;padding:5px;text-align:center'; ep.oninput = function () { k.e = num(ep.value); };
          var x = document.createElement('button'); x.type = 'button'; x.textContent = '×'; x.className = 'puce'; x.style.padding = '2px 8px'; x.onclick = function () { edit.couches.splice(i, 1); rendre_edit(); };
          [nom, sb, ep, x].forEach(function (n) { l.appendChild(n); }); L.appendChild(l);
        });
        el('eaide').textContent = 'Chaque couche prend la balise du métré choisie : c\'est elle qui compte les surfaces, longueurs et volumes. L\'épaisseur est modifiable à chaque pose.';
      }
      function opts() { return murs(edit.famille) ? D.balisesMur : D.balisesSol; }
      el('nouv').addEventListener('click', function () { edit = { id: null, nom: '', famille: fam, couches: [{ nom: '', balise: (murs(fam) ? D.balisesMur : D.balisesSol)[0][0], e: 10 }] }; rendre(); });
      el('modif').addEventListener('click', function () { if (!sel) return; edit = { id: sel.integre ? null : sel.id, nom: sel.integre ? sel.nom + ' (copie)' : sel.nom, famille: sel.famille, couches: sel.couches.map(function (k, i) { return { nom: k.nom, balise: k.balise, e: e[i] > 0 ? e[i] : k.e }; }) }; rendre(); });
      el('eajout').addEventListener('click', function () { edit.couches.push({ nom: '', balise: opts()[0][0], e: 5 }); rendre_edit(); });
      el('ann').addEventListener('click', function () { edit = null; rendre(); });
      el('ok').addEventListener('click', function () {
        if (!edit.nom.trim()) { el('msg').textContent = 'Donnez un nom à la composition.'; return; }
        var bon = edit.couches.filter(function (k) { return k.e > 0; });
        if (!bon.length) { el('msg').textContent = 'Il faut au moins une couche avec une épaisseur.'; return; }
        edit.couches = bon.map(function (k) { return { nom: k.nom || 'Couche', balise: k.balise, e: k.e }; });
        sketchup.sauver(JSON.stringify(edit)); fam = edit.famille; edit = null; el('msg').textContent = '';
      });
      el('suppr').addEventListener('click', function () { if (sel && !sel.integre) sketchup.supprimer(sel.id); });
      rendre();
    JS

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      html = A2M::Panneau.page('Compositions', 'Murs, cloisons, dalles et plafonds : choisissez une vignette, réglez les épaisseurs, posez', CORPS, SCRIPT, donnees)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : compositions', 'A2M_Panneau_Compositions', html, 520, 760)
      @fen = dlg
      dlg.add_action_callback('poser') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) { poser(r) } if r
      end
      dlg.add_action_callback('sauver') do |_c, json|
        x = (JSON.parse(json.to_s) rescue nil)
        next unless x.is_a?(Hash)
        liste = utilisateur
        x['id'] ||= "u_#{Time.now.to_i}_#{rand(1000)}"
        x.delete('integre')
        i = liste.index { |y| y['id'] == x['id'] }
        i ? liste[i] = x : liste << x
        enregistrer(liste)
        dlg.execute_script("maj(#{JSON.generate(donnees)})")
      end
      dlg.add_action_callback('supprimer') do |_c, id|
        UI.start_timer(0, false) do
          if UI.messagebox('Supprimer cette composition de votre bibliothèque ?', MB_YESNO) == IDYES
            enregistrer(utilisateur.reject { |y| y['id'] == id.to_s })
            dlg.execute_script("maj(#{JSON.generate(donnees)})")
          end
        end
      end
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
