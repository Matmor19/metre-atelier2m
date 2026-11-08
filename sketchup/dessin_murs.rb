# encoding: UTF-8
# Métré Atelier 2M : outil de dessin des murs, doublages et cloisons, directement sur la bonne balise
require 'sketchup.rb'
require 'json'

module A2M
  module DessinMurs
    # [libellé, balise, hauteur par défaut (m), épaisseur par défaut (cm), nom des groupes]
    TYPES = [
      ['Mur périphérique',           'A2M_MUR_PERI',         2.50, 20.0, 'Mur périphérique'],
      ['Mur de soubassement',        'A2M_MUR_SOUB',         1.00, 20.0, 'Mur de soubassement'],
      ['Mur de refend',              'A2M_MUR_REFEND',       2.50, 20.0, 'Mur de refend'],
      ['Mur pignon',                 'A2M_MUR_PIGNON',       2.50, 20.0, 'Mur pignon'],
      ['Enduit extérieur',           'A2M_ENDUIT_EXT',       2.50, 1.8,  'Enduit extérieur'],
      ['Doublage : plaque de plâtre', 'A2M_DOUBLAGE',        2.50, 1.3,  'Doublage plaque'],
      ['Doublage : isolant',         'A2M_ISOLANT_DOUBLAGE', 2.50, 14.0, 'Doublage isolant'],
      ['Cloison',                    'A2M_CLOISON',          2.50, 7.2,  'Cloison']
    ]
    TRACES = ['Axe du mur', 'Face gauche (le mur part à droite du tracé)', 'Face droite (le mur part à gauche du tracé)']
    @reglages = {}

    def self.demander
      dernier = @reglages[:type] || TYPES[0][0]
      t = TYPES.find { |x| x[0] == dernier } || TYPES[0]
      r = @reglages[t[0]] || {}
      rep = UI.inputbox(['Type', 'Hauteur (m)', 'Épaisseur (cm)', 'Le tracé suit'],
                        [t[0], (r[:h] || t[2]).to_s, (r[:e] || t[3]).to_s, @reglages[:trace] || TRACES[0]],
                        [TYPES.map(&:first).join('|'), '', '', TRACES.join('|')], 'Dessiner un mur (Métré Atelier 2M)')
      return nil unless rep
      type = TYPES.find { |x| x[0] == rep[0] }
      h = rep[1].to_s.tr(',', '.').to_f; e = rep[2].to_s.tr(',', '.').to_f
      if h <= 0 || e <= 0
        UI.messagebox('La hauteur et l\'épaisseur doivent être supérieures à 0.')
        return nil
      end
      # Une hauteur ou une épaisseur tapée par erreur en cm ou en m est signalée
      return nil if h > 20 && UI.messagebox("Hauteur de #{h} m : c'est bien en mètres ?", MB_YESNO) == IDNO
      @reglages[:type] = type[0]; @reglages[:trace] = rep[3]; @reglages[type[0]] = { h: h, e: e }
      { type: type, h: h, e: e, trace: TRACES.index(rep[3]) || 0 }
    end

    # Panneau à cartes : un clic sur le type, la hauteur et l'épaisseur se règlent d'un coup d'œil, puis « Dessiner »
    CORPS = <<~'HTML'
      <h2>Que dessiner</h2>
      <div class="grille" id="types"></div>
      <h2>Réglages</h2>
      <div class="dims"><div><label>Hauteur (m)</label><input type="text" id="h"></div><div class="x">×</div><div><label>Épaisseur (cm)</label><input type="text" id="e"></div></div>
      <h2>Le tracé suit</h2>
      <div class="puces" id="trace"></div>
      <div class="petit">Pendant le tracé : Tab change le côté, tapez une longueur puis Entrée, clic droit ou Ctrl pour libérer les axes.</div>
      <div id="bas"><div id="msg"></div><button type="button" id="go">Dessiner</button></div>
    HTML
    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(i) { return document.getElementById(i); }
      var s = D.etat;
      function num(v) { return parseFloat(String(v).replace(',', '.')); }
      function rendre() {
        var g = el('types'); g.innerHTML = '';
        D.types.forEach(function (t, i) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte' + (s.type === i ? ' rempli' : '');
          b.innerHTML = '<div class="vignette"><svg viewBox="0 0 48 40" width="60" height="50"><rect x="4" y="' + (20 - Math.min(t.e, 30) / 2) + '" width="40" height="' + Math.max(Math.min(t.e, 30), 3) + '" fill="' + t.couleur + '" stroke="#3C3C3C"/></svg></div><span></span><div class="petit" style="margin:2px 0 0"></div>';
          b.querySelector('span').textContent = t.libelle; b.querySelector('.petit').textContent = t.h + ' m × ' + t.e + ' cm';
          b.addEventListener('click', function () { s.type = i; s.h = t.h; s.e = t.e; el('h').value = t.h; el('e').value = t.e; rendre(); });
          g.appendChild(b);
        });
        var c = el('trace'); c.innerHTML = '';
        D.traces.forEach(function (x, i) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (s.trace === i ? ' rempli' : ''); b.textContent = x;
          b.addEventListener('click', function () { s.trace = i; rendre(); }); c.appendChild(b);
        });
        var h = num(el('h').value), e = num(el('e').value);
        el('h').className = h > 0 ? 'ok' : ''; el('e').className = e > 0 ? 'ok' : '';
        el('go').disabled = !(h > 0 && e > 0);
        el('msg').textContent = (h > 20) ? 'Hauteur en mètres : ' + h + ' m ?' : '';
      }
      el('h').value = s.h; el('e').value = s.e;
      el('h').addEventListener('input', rendre); el('e').addEventListener('input', rendre);
      el('go').addEventListener('click', function () { sketchup.dessiner(JSON.stringify({ type: s.type, h: num(el('h').value), e: num(el('e').value), trace: s.trace })); });
      rendre();
    JS
    COULEURS = ['#D9D2C8', '#C9C9C9', '#D9D2C8', '#D9D2C8', '#FFFFFF', '#FAE08C', '#F0E6D8'].freeze
    LIBELLES = ['Mur', 'Soubassement', 'Refend', 'Pignon', 'Doublage plaque', 'Doublage isolant', 'Cloison'].freeze

    def self.lancer
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      idx = TYPES.index { |x| x[0] == @reglages[:type] } || 0
      r = @reglages[TYPES[idx][0]] || {}
      d = { 'types' => TYPES.each_with_index.map { |t, i| { 'libelle' => LIBELLES[i], 'h' => (@reglages[t[0]] || {})[:h] || t[2], 'e' => (@reglages[t[0]] || {})[:e] || t[3], 'couleur' => COULEURS[i] } },
            'traces' => ['Axe du mur', 'Face gauche', 'Face droite'],
            'etat' => { 'type' => idx, 'h' => r[:h] || TYPES[idx][2], 'e' => r[:e] || TYPES[idx][3], 'trace' => TRACES.index(@reglages[:trace]) || 0 } }
      html = A2M::Panneau.page('Dessiner un mur', 'Choisissez le type, réglez si besoin, puis tracez', CORPS, SCRIPT, d)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : mur', 'A2M_Panneau_Mur', html, 440, 600)
      @fen = dlg
      dlg.add_action_callback('dessiner') do |_c, json|
        x = (JSON.parse(json.to_s) rescue nil)
        next unless x
        t = TYPES[x['type'].to_i] || TYPES[0]
        @reglages[:type] = t[0]; @reglages[:trace] = TRACES[x['trace'].to_i] || TRACES[0]; @reglages[t[0]] = { h: x['h'].to_f, e: x['e'].to_f }
        dlg.close
        UI.start_timer(0.1, false) { Sketchup.active_model.select_tool(Outil.new({ type: t, h: x['h'].to_f, e: x['e'].to_f, trace: x['trace'].to_i })) }
      end
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end

    # ---- Géométrie 2D (plan horizontal), en pouces (unité interne de SketchUp) ----
    # Points en double et points intermédiaires alignés (tronçons dans le prolongement l'un de l'autre) retirés :
    # sans cela, l'angle entre deux tronçons alignés « part à l'infini » et le mur devient immense
    def self.nettoyer(pts, ferme)
      res = []
      pts.each { |q| res << q if res.empty? || Math.hypot(q.x - res[-1].x, q.y - res[-1].y) > 0.04 }
      res.pop if ferme && res.size > 1 && Math.hypot(res[0].x - res[-1].x, res[0].y - res[-1].y) <= 0.04
      loop do
        n = res.size
        break if n < 3
        idx = (0...n).find do |i|
          next false if !ferme && (i == 0 || i == n - 1)
          a = res[i - 1]; b = res[i]; c = res[(i + 1) % n]
          ux, uy = b.x - a.x, b.y - a.y; vx, vy = c.x - b.x, c.y - b.y
          lu = Math.hypot(ux, uy); lv = Math.hypot(vx, vy)
          (ux * vy - uy * vx).abs / (lu * lv) < 1e-3 && (ux * vx + uy * vy) > 0
        end
        break unless idx
        res.delete_at(idx)
      end
      res
    end

    def self.decale(pts, d, ferme)
      pts = nettoyer(pts, ferme)
      n = pts.size
      seg = (0...(ferme ? n : n - 1)).map do |i|
        a = pts[i]; b = pts[(i + 1) % n]
        dx = b.x - a.x; dy = b.y - a.y; l = Math.hypot(dx, dy)
        ux, uy = dx / l, dy / l
        nx, ny = -uy, ux
        [[a.x + nx * d, a.y + ny * d], [ux, uy]]
      end
      inter = lambda do |s1, s2|
        (p1x, p1y), (u1x, u1y) = s1
        (p2x, p2y), (u2x, u2y) = s2
        cr = u1x * u2y - u1y * u2x
        return [p2x, p2y] if cr.abs < 1e-3   # tronçons alignés (ou presque) : pas d'angle à calculer
        t = ((p2x - p1x) * u2y - (p2y - p1y) * u2x) / cr
        [p1x + t * u1x, p1y + t * u1y]
      end
      if ferme
        (0...n).map { |i| inter.call(seg[i - 1], seg[i]) }
      else
        res = [seg[0][0]]
        (1...(n - 1)).each { |i| res << inter.call(seg[i - 1], seg[i]) }
        (lx, ly), (ux, uy) = seg[-1]
        lsx, lsy = pts[-1].x - pts[-2].x, pts[-1].y - pts[-2].y
        res << [lx + lsx, ly + lsy]
        res
      end
    end

    def self.aire(poly) poly.each_with_index.sum { |(x1, y1), i| x2, y2 = poly[(i + 1) % poly.size]; x1 * y2 - x2 * y1 } / 2.0 end

    # Couches à construire : [type, hauteur (m), décalage gauche, décalage droit (pouces)]
    #  - mur simple : selon le tracé (axe, face gauche, face droite)
    #  - mur composé : le tracé est la face extérieure de la 1re couche, les couches s'empilent du côté choisi
    def self.couches_de(p)
      if p[:couches]
        # 0 : couches à droite du tracé ; 1 : à gauche ; 2 : tracé dans l'axe de l'épaisseur totale (couches de gauche à droite)
        sg = p[:cote] == 1 ? 1.0 : -1.0
        ref = p[:ref]
        if ref
          # Couche d'insertion : le tracé est sa face extérieure ; les couches qui la précèdent (enduit…) sont de l'autre côté du tracé
          avant = p[:couches][0...ref].sum { |c| (c[:e] / 100.0).m }
          s = p[:cote] == 2 ? -avant - (p[:couches][ref][:e] / 100.0).m / 2.0 : -avant
        else
          s = p[:cote] == 2 ? -p[:couches].sum { |c| (c[:e] / 100.0).m } / 2.0 : 0.0
        end
        p[:couches].map do |c|
          e = (c[:e] / 100.0).m
          d1, d2 = sg * s, sg * (s + e)
          s += e
          [c[:type], c[:h], [d1, d2].max, [d1, d2].min, c[:e]]
        end
      else
        e = (p[:e] / 100.0).m
        dg, dd = [[e / 2.0, -e / 2.0], [0.0, -e], [e, 0.0]][p[:trace]]
        [[p[:type], p[:h], dg, dd, p[:e]]]
      end
    end

    # Une couche : empreinte entre deux décalages du tracé, extrudée sur la hauteur, dans un groupe sur la balise du type
    def self.construire_couche(pts, ferme, type, hm, dg, dd)
      model = Sketchup.active_model
      z = pts[0].z
      grp = model.active_entities.add_group
      ents = grp.entities
      a = decale(pts, dg, ferme); b = decale(pts, dd, ferme)
      p3 = ->(poly) { poly.map { |x, y| Geom::Point3d.new(x, y, z) } }
      if ferme
        ext, int = aire(a).abs >= aire(b).abs ? [a, b] : [b, a]
        ents.add_face(p3.call(ext))
        trou = ents.add_face(p3.call(int))
        trou.erase! if trou && trou.valid?
        f = ents.grep(Sketchup::Face).max_by(&:area)
      else
        f = ents.add_face(p3.call(a + b.reverse))
      end
      f.reverse! if f.normal.z < 0
      f.pushpull(hm.m)
      l, _ = A2M::Balises.balise(model, type[1], (A2M::Balises::LISTE.find { |n, _, _| n == type[1] } || [])[2])
      grp.layer = l
      A2M::Hachures.poser(grp, model)
      num = model.active_entities.grep(Sketchup::Group).count { |g| g.name.start_with?(type[4]) }
      grp.name = "#{type[4]} #{num}"
      grp
    end

    def self.construire(pts, ferme, p)
      model = Sketchup.active_model
      model.start_operation(p[:couches] ? 'Dessiner un mur composé (métré)' : 'Dessiner un mur (métré)', true)
      begin
        noms = couches_de(p).map { |type, hm, dg, dd, ecm| g = construire_couche(pts, ferme, type, hm, dg, dd); "#{g.name} (#{ecm} cm)" }
        model.commit_operation
        Sketchup.status_text = "Créé : #{noms.join(' + ')}"
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Le mur n'a pas pu être créé (#{ex.message}). Vérifiez que le tracé ne se recoupe pas.")
      end
    end

    # ---- Mur composé : nombre de couches, puis type, épaisseur et hauteur de chacune ----
    COTES_COMPOSE = ['à droite du tracé', 'à gauche du tracé', 'dans l\'axe du tracé']
    TAB = 9   # touche Tab : change le côté du mur par rapport au tracé

    # Libellé du côté en cours (barre d'état et texte près du curseur)
    def self.lib_cote(p)
      p[:couches] ? "Couches #{COTES_COMPOSE[p[:cote]]}" : ['Tracé dans l\'axe du mur', 'Mur à droite du tracé', 'Mur à gauche du tracé'][p[:trace]]
    end

    # Tab : axe → à droite → à gauche (mur simple) ; à droite → à gauche → dans l'axe (mur composé). Le choix est retenu.
    def self.cote_suivant(p)
      if p[:couches]
        p[:cote] = (p[:cote] + 1) % 3
        (@reglages[:compose] ||= {})[:cote] = COTES_COMPOSE[p[:cote]]
      else
        p[:trace] = (p[:trace] + 1) % 3
        @reglages[:trace] = TRACES[p[:trace]]
      end
    end

    COMPO_DEFAUT = [['Enduit extérieur', 1.8, 2.50], ['Mur périphérique', 20.0, 2.50], ['Doublage : isolant', 14.0, 2.50], ['Doublage : plaque de plâtre', 1.3, 2.50], ['Cloison', 7.2, 2.50]]

    CORPS_COMPOSE = <<~'HTML'
      <h2>Nombre de couches (de l'extérieur vers l'intérieur)</h2>
      <div class="puces" id="nb"></div>
      <h2>Le tracé et la couche d'insertion</h2>
      <div class="petit" style="margin-bottom:6px">Cliquez la couche par laquelle vous insérez le mur : <b>le tracé en est la face extérieure</b>. Les couches qui la précèdent (enduit…) se placent à l'extérieur du tracé.</div>
      <div id="coupe" style="background:#fff;border:2px solid #d8d0c6;border-radius:8px;margin-bottom:8px"></div>
      <div class="puces" id="cotes"></div>
      <h2>Couches</h2>
      <div id="lignes"></div>
      <div id="bas"><div id="msg" style="flex:1;color:#6f665e"></div><button id="annuler" type="button" class="puce">Annuler</button><button id="go" type="button">Dessiner le mur</button></div>
    HTML

    SCRIPT_COMPOSE = <<~'JS'
      var D = __DONNEES__;
      function el(i) { return document.getElementById(i); }
      function num(v) { var x = parseFloat(String(v).replace(',', '.')); return isFinite(x) ? x : 0; }
      var etat = { n: D.n, cote: D.cote, ref: D.ref, c: D.couches };
      function couleur(nom) { return D.couleurs[nom] || [190, 190, 190]; }
      function ajuster() {
        while (etat.c.length < etat.n) { var d = D.defaut[Math.min(etat.c.length, D.defaut.length - 1)]; etat.c.push({ type: d[0], e: d[1], h: d[2] }); }
        etat.c.length = etat.n; if (etat.ref >= etat.n) etat.ref = etat.n - 1;
      }
      function rendre() {
        ajuster();
        var nb = el('nb'); nb.innerHTML = '';
        [1, 2, 3, 4, 5].forEach(function (k) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (etat.n === k ? ' rempli' : ''); b.textContent = k;
          b.addEventListener('click', function () { etat.n = k; rendre(); }); nb.appendChild(b);
        });
        var co = el('cotes'); co.innerHTML = '';
        D.cotes.forEach(function (t, i) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (etat.cote === i ? ' rempli' : ''); b.textContent = t;
          b.addEventListener('click', function () { etat.cote = i; rendre(); }); co.appendChild(b);
        });
        // coupe en plan : le tracé (trait orange) est la face extérieure de la couche d'insertion
        var tot = etat.c.reduce(function (a, k) { return a + Math.max(k.e, 0.1); }, 0), W = 560, x = 10, lar = W - 20, svg = '', xtrace = 10;
        etat.c.forEach(function (k, i) {
          var w = Math.max(lar * Math.max(k.e, 0.1) / tot, 6);
          if (i === etat.ref) xtrace = etat.cote === 2 ? x + w / 2 : x;
          svg += '<rect x="' + x + '" y="22" width="' + w + '" height="46" fill="rgb(' + couleur(k.type).join(',') + ')" stroke="' + (i === etat.ref ? '#e07838' : '#3C3C3C') + '" stroke-width="' + (i === etat.ref ? 2.5 : .8) + '"/>';
          x += w;
        });
        svg += '<line x1="' + xtrace + '" y1="10" x2="' + xtrace + '" y2="80" stroke="#e07838" stroke-width="2" stroke-dasharray="4 3"/><text x="' + (xtrace + 4) + '" y="16" font-size="11" fill="#c9672f">tracé</text>';
        svg += '<text x="12" y="92" font-size="10.5" fill="#6f665e">extérieur</text><text x="' + (W - 12) + '" y="92" font-size="10.5" fill="#6f665e" text-anchor="end">intérieur</text>';
        el('coupe').innerHTML = '<svg viewBox="0 0 ' + W + ' 98" width="100%" height="98">' + svg + '</svg>';
        var L = el('lignes'); L.innerHTML = '';
        etat.c.forEach(function (k, i) {
          var r = i === etat.ref;
          var l = document.createElement('div');
          l.style.cssText = 'display:grid;grid-template-columns:96px 1fr 64px 64px;gap:6px;align-items:center;margin-bottom:6px;padding:6px;border-radius:10px;border:2px solid ' + (r ? '#e07838' : 'transparent') + ';background:' + (r ? '#fdeedd' : 'transparent');
          var bi = document.createElement('button'); bi.type = 'button'; bi.className = 'puce' + (r ? ' rempli' : ''); bi.textContent = r ? '★ Insertion' : 'Insérer ici';
          bi.addEventListener('click', function () { etat.ref = i; rendre(); });
          var sb = document.createElement('select'); sb.style.cssText = 'padding:7px;border:2px solid #d8d0c6;border-radius:8px;background:#fff;min-width:0';
          D.types.forEach(function (t) { var o = document.createElement('option'); o.value = t[0]; o.textContent = t[0]; sb.appendChild(o); }); sb.value = k.type;
          sb.addEventListener('change', function () { k.type = sb.value; var d = D.types.filter(function (t) { return t[0] === sb.value; })[0]; if (d) { k.e = d[1]; k.h = d[2]; } rendre(); });
          var ep = document.createElement('input'); ep.type = 'text'; ep.value = k.e; ep.title = 'Épaisseur (cm)'; ep.style.cssText = 'font-size:13px;padding:6px;text-align:center'; ep.addEventListener('input', function () { k.e = num(ep.value); });
          ep.addEventListener('change', rendre);
          var hh = document.createElement('input'); hh.type = 'text'; hh.value = k.h; hh.title = 'Hauteur (m)'; hh.style.cssText = 'font-size:13px;padding:6px;text-align:center'; hh.addEventListener('input', function () { k.h = num(hh.value); });
          [bi, sb, ep, hh].forEach(function (n) { l.appendChild(n); }); L.appendChild(l);
        });
        var cap = document.createElement('div'); cap.className = 'petit'; cap.textContent = 'Colonnes : insertion · type · épaisseur (cm) · hauteur (m).'; L.appendChild(cap);
        el('msg').textContent = 'Insertion par la couche « ' + etat.c[etat.ref].type + ' ».';
      }
      el('go').addEventListener('click', function () {
        for (var i = 0; i < etat.c.length; i++) if (!(etat.c[i].e > 0 && etat.c[i].h > 0)) { el('msg').textContent = 'Couche ' + (i + 1) + ' : épaisseur et hauteur doivent être supérieures à 0.'; return; }
        sketchup.ok(JSON.stringify(etat));
      });
      el('annuler').addEventListener('click', function () { sketchup.annuler(''); });
      rendre();
    JS

    def self.index_insertion(types)
      i = types.index { |t| t.to_s.start_with?('Mur ') && t != 'Mur de soubassement' }
      i || 0
    end

    def self.lancer_compose
      return @fen_compose.bring_to_front if @fen_compose && (@fen_compose.visible? rescue false)
      r = @reglages[:compose] || {}
      prec = r[:couches] || [COMPO_DEFAUT[0], COMPO_DEFAUT[1], COMPO_DEFAUT[2], COMPO_DEFAUT[3]]
      cs = prec.map { |t, e, h| { 'type' => t, 'e' => e, 'h' => h } }
      n = [[r[:n] || cs.size, 1].max, 5].min
      ref = r[:ref] || index_insertion(cs.map { |c| c['type'] })
      couleurs = {}
      TYPES.each { |t| couleurs[t[0]] = A2M::Compositions::COULEURS[t[1]] || [190, 190, 190] }
      donnees = { 'n' => n, 'cote' => COTES_COMPOSE.index(r[:cote]) || 0, 'ref' => [ref, n - 1].min, 'couches' => cs, 'couleurs' => couleurs,
                  'types' => TYPES.map { |t| [t[0], t[3], t[2]] }, 'defaut' => COMPO_DEFAUT,
                  'cotes' => ['Intérieur à droite du tracé', 'Intérieur à gauche du tracé', 'Tracé dans l\'axe de la couche d\'insertion'] }
      html = A2M::Panneau.page('Mur composé', 'Choisissez les couches et celle par laquelle le mur est inséré', CORPS_COMPOSE, SCRIPT_COMPOSE, donnees)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : mur composé', 'A2M_Panneau_Compose', html, 620, 700)
      @fen_compose = dlg
      dlg.add_action_callback('ok') do |_ctx, json|
        d = (JSON.parse(json.to_s) rescue nil)
        next unless d
        couches = d['c'].map { |c| { type: TYPES.find { |x| x[0] == c['type'] } || TYPES[0], e: c['e'].to_f, h: c['h'].to_f } }
        cote = d['cote'].to_i
        ref = [[d['ref'].to_i, 0].max, couches.size - 1].min
        @reglages[:compose] = { n: couches.size, cote: COTES_COMPOSE[cote], ref: ref, couches: couches.map { |c| [c[:type][0], c[:e], c[:h]] } }
        p = { couches: couches, cote: cote, ref: ref, type: ['Mur composé'], h: couches.map { |c| c[:h] }.max, e: couches.sum { |c| c[:e] }.round(1) }
        dlg.close
        UI.start_timer(0, false) { Sketchup.active_model.select_tool(Outil.new(p)) }
      end
      dlg.add_action_callback('annuler') { |_ctx, _x| dlg.close }
      dlg.set_on_closed { @fen_compose = nil }
      dlg.show
    end

    # ---- L'outil : clics successifs ; Entrée ou double-clic termine ; clic sur le premier point ferme le tour ----
    class Outil
      def initialize(p)
        @p = p; @pts = []; @pt = A2M::Pointeur.new
      end

      def activate
        maj_statut
      end

      def maj_statut
        lib = @p[:couches] ? "Mur composé (#{@p[:couches].map { |c| c[:e] }.join(' + ')} cm)" : "#{@p[:type][0]} — h #{@p[:h]} m, ép. #{@p[:e]} cm"
        Sketchup.status_text = "#{lib}, #{A2M::DessinMurs.lib_cote(@p).downcase} (Tab pour changer). Cliquez les points du tracé (accrochages SketchUp) ; tapez une longueur puis Entrée ; " \
                               'Ctrl ou clic droit = axes verrouillés ou tracé libre, Maj = bloquer la direction, flèche droite = axe rouge, flèche gauche = axe vert ; clic sur le 1er point (carré vert) pour fermer ; double-clic ou Entrée pour finir ; Échap pour annuler.'
        Sketchup.vcb_label = 'Longueur'
      end

      def deactivate(view) view.invalidate end
      def resume(view) maj_statut; view.invalidate end

      def onMouseMove(_flags, x, y, view)
        q = @pt.bouger(view, x, y, @pts)
        Sketchup.vcb_value = @pts[-1].distance(q).to_l.to_s if @pts.any?
        view.invalidate
      end

      def onKeyDown(key, rpt, _flags, view)
        if key == A2M::DessinMurs::TAB
          return true if rpt > 1
          A2M::DessinMurs.cote_suivant(@p)
          maj_statut
          view.invalidate
          return true
        end
        @pt.touche_bas(key, rpt, view, @pts)
      end
      def onKeyUp(key, _rpt, _flags, view) @pt.touche_haut(key, view) end
      def getMenu(menu) @pt.menu(menu) end

      def ajouter(pt, view, ferme = false)
        pt = Geom::Point3d.new(pt.x, pt.y, @pts.empty? ? pt.z : @pts[0].z)
        if @pts.size >= 3 && (ferme || pt.distance(@pts[0]) < 0.4)   # retour au premier point = tour fermé
          A2M::DessinMurs.construire(@pts.dup, true, @p)
          return reset(view)
        end
        return if @pts.any? && pt.distance(@pts[-1]) < 0.04
        @pts << pt
        @pt.valider
        view.invalidate
      end

      def onLButtonDown(_flags, _x, _y, view)
        ajouter(@pt.pos || @pt.ip.position, view, @pt.ferme?)
      end

      def onLButtonDoubleClick(_flags, _x, _y, view)
        terminer(view)
      end

      def onReturn(view) terminer(view) end

      def onUserText(text, view)
        l = text.to_l rescue nil
        return UI.beep unless l && @pts.any? && @pt.pos
        dir = @pt.pos - @pts[-1]
        return UI.beep if dir.length < 0.001
        dir.length = l
        ajouter(@pts[-1].offset(dir), view)
      end

      def terminer(view)
        if @pts.size >= 2
          A2M::DessinMurs.construire(@pts.dup, false, @p)
        end
        reset(view)
      end

      def reset(view)
        @pts.clear; @pt.vider(view); maj_statut; view.invalidate
      end

      def onCancel(_reason, view)
        @pts.empty? ? Sketchup.active_model.select_tool(nil) : reset(view)
      end

      def draw(view)
        @pt.dessiner(view, @pts, 'orange')
        # Côté en cours, écrit près du curseur
        if @pt.pos
          sp = view.screen_coords(@pt.pos)
          view.draw_text(Geom::Point3d.new(sp.x + 18, sp.y + 14, 0), "#{A2M::DessinMurs.lib_cote(@p)}  (Tab)", color: 'DimGray', size: 10) rescue nil
        end
        return if @pts.empty? || @pt.pos.nil?
        chemin = @pts + [@pt.pos]
        # Aperçu de l'épaisseur
        if chemin[-1].distance(chemin[-2]) > 0.01
          cs = A2M::DessinMurs.couches_de(@p)
          dg = cs.map { |c| c[2] }.max; dd = cs.map { |c| c[3] }.min
          ferme = @pt.ferme?
          ch = ferme ? @pts : chemin
          a = A2M::DessinMurs.decale(ch, dg, ferme); b = A2M::DessinMurs.decale(ch, dd, ferme)
          a << a[0] if ferme; b << b[0] if ferme
          z = chemin[0].z
          view.line_width = 1
          view.drawing_color = 'gray'
          view.draw(GL_LINE_STRIP, a.map { |x, y| Geom::Point3d.new(x, y, z) })
          view.draw(GL_LINE_STRIP, b.map { |x, y| Geom::Point3d.new(x, y, z) })
        end
      end

      def getExtents
        bb = Geom::BoundingBox.new
        @pts.each { |q| bb.add(q) }
        bb.add(@pt.pos) if @pt.pos
        bb
      end
    end
  end
end
