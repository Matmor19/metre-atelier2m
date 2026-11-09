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
          [c[:type], c[:h], [d1, d2].max, [d1, d2].min, c[:e], (c[:b].to_f / 100.0).m]
        end
      else
        e = (p[:e] / 100.0).m
        dg, dd = [[e / 2.0, -e / 2.0], [0.0, -e], [e, 0.0]][p[:trace]]
        [[p[:type], p[:h], dg, dd, p[:e], 0.0]]
      end
    end

    # Une couche : empreinte entre deux décalages du tracé, extrudée sur la hauteur, dans un groupe sur la balise du type
    def self.construire_couche(pts, ferme, type, hm, dg, dd, bas = 0.0)
      model = Sketchup.active_model
      z = pts[0].z - bas      # « bas » : la couche descend plus bas que le tracé (ex. enduit sous le mur)
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
      f.pushpull(hm.m + bas)
      l, _ = A2M::Balises.balise(model, type[1], (A2M::Balises::LISTE.find { |n, _, _| n == type[1] } || [])[2])
      grp.layer = l
      A2M::Hachures.poser(grp, model)
      num = model.active_entities.grep(Sketchup::Group).count { |g| g.name.start_with?(type[4]) }
      grp.name = "#{type[4]} #{num}"
      grp
    end

    # Mémoire du mur : chaque couche garde le tracé et les réglages pour pouvoir être modifiée plus tard
    def self.p_vers_json(p)
      if p[:couches]
        { 'compose' => true, 'cote' => p[:cote], 'ref' => p[:ref], 'couches' => p[:couches].map { |c| [c[:type][0], c[:e], c[:h], c[:b].to_f] } }
      else
        { 'compose' => false, 'type' => p[:type][0], 'h' => p[:h], 'e' => p[:e], 'trace' => p[:trace] }
      end
    end

    def self.type_nomme(nom) TYPES.find { |x| x[0] == nom } || TYPES[0] end

    # Réglages mémorisés → forme « mur composé » (un mur simple devient un mur à une couche)
    def self.p_compose(j)
      if j['compose']
        { couches: j['couches'].map { |t, e, h, b| { type: type_nomme(t), e: e.to_f, h: h.to_f, b: b.to_f } }, cote: j['cote'].to_i, ref: j['ref'].to_i }
      else
        { couches: [{ type: type_nomme(j['type']), e: j['e'].to_f, h: j['h'].to_f }], cote: [2, 0, 1][j['trace'].to_i] || 2, ref: 0 }
      end
    end

    # chemins : plusieurs tracés fusionnés dans un même mur (cloisons reliées) ; pts/ferme gardent le premier
    def self.marquer(grp, id, pts, ferme, p, i, chemins = nil)
      d = 'a2m_mur'
      if chemins && chemins.size > 1
        grp.set_attribute(d, 'chemins', JSON.generate(chemins.map { |cp, cf| [cp.map { |q| [q.x.to_f, q.y.to_f, q.z.to_f] }, cf ? true : false] }))
      else
        grp.delete_attribute(d, 'chemins')
      end
      grp.set_attribute(d, 'id', id)
      grp.set_attribute(d, 'pts', JSON.generate(pts.map { |q| [q.x.to_f, q.y.to_f, q.z.to_f] }))
      grp.set_attribute(d, 'ferme', ferme ? true : false)
      grp.set_attribute(d, 'p', JSON.generate(p_vers_json(p)))
      grp.set_attribute(d, 'i', i)
    end

    def self.construire(pts, ferme, p)
      model = Sketchup.active_model
      model.start_operation(p[:couches] ? 'Dessiner un mur composé (métré)' : 'Dessiner un mur (métré)', true)
      begin
        id = "#{Time.now.to_i}#{rand(100_000)}"
        noms = couches_de(p).each_with_index.map do |(type, hm, dg, dd, ecm, bas), i|
          g = construire_couche(pts, ferme, type, hm, dg, dd, bas.to_f)
          marquer(g, id, pts, ferme, p, i)
          "#{g.name} (#{ecm} cm)"
        end
        fus = ((!p[:couches] && p[:type] && p[:type][0] == 'Cloison') || p[:cloison]) ? fusionner(id) : 0
        noms << "fusionnée avec #{fus} cloison(s) reliée(s)" if fus > 0
        model.commit_operation
        Sketchup.status_text = "Créé : #{noms.join(' + ')}"
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Le mur n'a pas pu être créé (#{ex.message}). Vérifiez que le tracé ne se recoupe pas.")
      end
    end

    # ---- Modifier un mur déjà dessiné ----
    # Tous les murs mémorisés du modèle : { id => { id:, pts:, ferme:, p:, groupes: [] } }
    def self.murs_du_modele(model = Sketchup.active_model)
      res = {}
      model.entities.grep(Sketchup::Group).each do |g|
        id = g.get_attribute('a2m_mur', 'id') or next
        r = (res[id] ||= { id: id, groupes: [] })
        r[:groupes] << g
        next if r[:pts]
        begin
          r[:pts] = JSON.parse(g.get_attribute('a2m_mur', 'pts')).map { |x, y, z| Geom::Point3d.new(x, y, z) }
          r[:ferme] = g.get_attribute('a2m_mur', 'ferme') ? true : false
          r[:j] = JSON.parse(g.get_attribute('a2m_mur', 'p'))
          ch = g.get_attribute('a2m_mur', 'chemins')
          r[:chemins] = JSON.parse(ch).map { |cp, cf| [cp.map { |x, y, z| Geom::Point3d.new(x, y, z) }, cf ? true : false] } if ch
        rescue StandardError
          r[:pts] = nil
        end
      end
      res.select { |_, r| r[:pts] }
    end

    def self.mur_de(ent, murs)
      return nil unless ent.respond_to?(:get_attribute)
      id = ent.get_attribute('a2m_mur', 'id')
      id && murs[id]
    end

    def self.distance_segment(q, a, b)
      dx = b.x - a.x; dy = b.y - a.y
      l2 = dx * dx + dy * dy
      t = l2 < 1e-12 ? 0.0 : [[((q.x - a.x) * dx + (q.y - a.y) * dy) / l2, 0.0].max, 1.0].min
      Math.hypot(q.x - (a.x + t * dx), q.y - (a.y + t * dy))
    end

    def self.chemins_de(r) r[:chemins] || [[r[:pts], r[:ferme]]] end

    # Épaisseur totale d'un mur mémorisé, en pouces
    def self.epaisseur_po(r)
      j = r[:j]
      (j['compose'] ? j['couches'].sum { |c| c[1].to_f } : j['e'].to_f) / 2.54
    rescue StandardError
      0.0
    end

    # Comme relies?, mais une cloison qui s'arrête contre la FACE d'une autre (et non sur son axe) compte aussi :
    # la tolérance est la demi-épaisseur de la cloison touchée + 5 cm
    def self.relies_large?(a, b, marge = 2.0)
      relies?(a, b, marge + epaisseur_po(b) / 2.0) || relies?(b, a, marge + epaisseur_po(a) / 2.0)
    end

    def self.relies?(a, b, tol = 0.4)
      touche = lambda do |u, v|
        segs = chemins_de(v).flat_map do |cp, cf|
          l = cp.each_cons(2).to_a
          l << [cp[-1], cp[0]] if cf
          l
        end
        chemins_de(u).any? { |cp, _cf| cp.any? { |q| segs.any? { |s, e| distance_segment(q, s, e) < tol } } }
      end
      touche.call(a, b) || touche.call(b, a)
    end

    def self.signature(r)
      (r[:j]['compose'] ? r[:j]['couches'].map { |t, e, _h| [t, e.to_f] } : [[r[:j]['type'], r[:j]['e'].to_f]]).inspect
    end

    # Le mur et, si demandé, tous ceux qui lui sont reliés (de proche en proche) avec la même composition
    def self.famille(depart, murs)
      sig = signature(depart)
      vus = { depart[:id] => depart }
      file = [depart]
      until file.empty?
        cour = file.shift
        murs.each_value do |m|
          next if vus[m[:id]] || signature(m) != sig || !relies?(cour, m)
          vus[m[:id]] = m
          file << m
        end
      end
      vus.values
    end

    # Reconstruit un mur avec de nouveaux réglages (mêmes tracé, même emplacement)
    def self.reconstruire(r, p)
      r[:groupes].each { |g| g.erase! if g.valid? }
      nv = []
      ch = chemins_de(r)
      couches_de(p).each_with_index do |(type, hm, dg, dd, _e, bas), i|
        gs = ch.map { |cp, cf| construire_couche(cp, cf, type, hm, dg, dd, bas.to_f) }
        gs = unir(gs, type) if gs.size > 1
        gs.each { |g| marquer(g, r[:id], ch[0][0], ch[0][1], p, i, ch) }
        nv.concat(gs)
      end
      nv
    end

    # Fusionne plusieurs groupes de même couche en un seul (union de solides). Si SketchUp refuse, ils restent côte à côte
    # (toujours rattachés au même mur, donc toujours modifiables ensemble).
    def self.unir(gs, type)
      return gs unless gs.all? { |g| g.respond_to?(:manifold?) && g.manifold? }
      res = gs[0]
      gs[1..-1].each_with_index do |g, k|
        u = (res.union(g) rescue nil)
        return ([res] + gs[(k + 1)..-1]).select(&:valid?) unless u
        res = u
      end
      l, _ = A2M::Balises.balise(Sketchup.active_model, type[1], (A2M::Balises::LISTE.find { |n, _, _| n == type[1] } || [])[2])
      res.layer = l
      res.name = "#{type[4]} #{Sketchup.active_model.active_entities.grep(Sketchup::Group).count { |x| x.name.start_with?(type[4]) }}"
      A2M::Hachures.poser(res, Sketchup.active_model)
      [res]
    end

    # Deux réglages sont équivalents s'ils sont identiques, ou s'ils ne diffèrent que par le côté (0 = couches à droite du tracé,
    # 1 = à gauche) pour une composition symétrique (plaque + cloison + plaque) : l'empreinte est alors la même, au décalage du tracé près
    def self.meme_reglage?(a, b)
      return true if a == b
      return false unless a['compose'] && b['compose']
      return false unless a.reject { |k, _| k == 'cote' } == b.reject { |k, _| k == 'cote' }
      return false unless [a['cote'].to_i, b['cote'].to_i].all? { |c| c == 0 || c == 1 }
      a['couches'] == a['couches'].reverse
    end

    # Copie du mur x exprimée avec les réglages (côté) de la cible : son tracé est décalé de façon que l'empreinte ne bouge pas
    def self.aligne(x, cible_j)
      return x if x[:j] == cible_j || x[:j]['cote'].to_i == cible_j['cote'].to_i
      j = x[:j]
      t = epaisseur_po(x)
      avant = j['couches'][0...j['ref'].to_i].sum { |c| (c[1].to_f / 100.0).m }
      delta = (t - 2 * avant) * (j['cote'].to_i == 1 ? 1.0 : -1.0)
      ch = chemins_de(x).map do |cp, cf|
        z = cp[0].z
        [decale(cp, delta, cf).map { |px, py| Geom::Point3d.new(px, py, z) }, cf]
      end
      x.merge(chemins: ch, pts: ch[0][0], ferme: ch[0][1])
    end

    # Cloison qui vient d'être dessinée : elle absorbe les cloisons reliées de même réglage (leurs tracés sont gardés)
    def self.fusionner(id)
      murs = murs_du_modele
      nv = murs[id] or return 0
      voisins = murs.values.select { |m| m[:id] != id && meme_reglage?(m[:j], nv[:j]) && relies_large?(nv, aligne(m, nv[:j])) }.map { |m| aligne(m, nv[:j]) }
      return 0 if voisins.empty?
      tout = { id: id, groupes: nv[:groupes] + voisins.flat_map { |m| m[:groupes] }, j: nv[:j],
               chemins: chemins_de(nv) + voisins.flat_map { |m| chemins_de(m) } }
      tout[:pts], tout[:ferme] = tout[:chemins][0]
      reconstruire(tout, p_de(nv[:j]))
      voisins.size
    end

    def self.resume_j(j)
      j['compose'] ? 'composée ' + j['couches'].map { |c| "#{c[0].sub('Doublage : plaque de plâtre', 'plaque').sub('Doublage : isolant', 'isolant')} #{c[1]}" }.join(' + ') + " (h #{j['couches'].map { |c| c[2].to_f }.max} m, côté #{j['cote']}, réf #{j['ref']})" : "#{j['type']} ép. #{j['e']} cm, h #{j['h']} m, tracé #{j['trace']}"
    end

    # Explique pourquoi des cloisons proches ne fusionnent pas
    def self.diagnostic_cloisons(cand)
      lignes = []
      cand.combination(2).each do |a, b|
        next unless relies_large?(a, b, 12.0)   # à moins de ~30 cm l'une de l'autre
        if !meme_reglage?(a[:j], b[:j])
          lignes << "• Réglages différents : [#{resume_j(a[:j])}] / [#{resume_j(b[:j])}]"
        elsif !relies_large?(a, aligne(b, a[:j]))
          lignes << '• Réglage identique mais trop éloignées (écart de plus de ~5 cm à la face)'
        end
      end
      return "Aucune paire de cloisons proches (moins de 30 cm) n'a été trouvée entre les cloisons reconnues.\nLes autres cloisons ne sont peut-être pas reconnues : seules les cloisons droites (balise A2M_CLOISON) ou dessinées avec les outils le sont." if lignes.empty?
      lignes.uniq.first(5).join("\n")
    end

    TYPES_CLOISON = ['Cloison', 'Doublage : plaque de plâtre', 'Doublage : isolant']

    def self.cloison?(j)
      if j['compose']
        j['couches'].any? { |c| c[0] == 'Cloison' } && j['couches'].all? { |c| TYPES_CLOISON.include?(c[0]) }
      else
        j['type'] == 'Cloison'
      end
    end

    # Fusionne après coup les cloisons qui se touchent (celles de la sélection, ou toutes si rien n'est sélectionné).
    # Les anciennes cloisons droites sont reprises au passage. Dit franchement ce qui a été fait ou refusé.
    def self.fusionner_cloisons
      m = Sketchup.active_model
      sel = m.selection.grep(Sketchup::Group)
      m.start_operation('Fusionner les cloisons (métré)', true)
      begin
        (sel.empty? ? m.entities.grep(Sketchup::Group) : sel).each do |g|
          adopter(g) if g.valid? && g.layer && g.layer.name == 'A2M_CLOISON'
        end
        murs = murs_du_modele(m)
        ids_sel = sel.map { |g| g.get_attribute('a2m_mur', 'id') }.compact
        cand = murs.values.select { |r| cloison?(r[:j]) && (sel.empty? || ids_sel.include?(r[:id])) }
        if cand.size < 2
          m.abort_operation
          UI.messagebox("Moins de deux cloisons trouvées#{sel.empty? ? '' : ' dans la sélection'}. Rien à fusionner.\n(Seules les cloisons droites ou dessinées avec les outils sont reconnues.)")
          return
        end
        vus = {}
        fusionnees = 0; compo = 0; refus = 0
        cand.each do |dep|
          next if vus[dep[:id]]
          fam = [dep]; vus[dep[:id]] = true; file = [dep]
          until file.empty?
            c = file.shift
            cand.each do |x|
              next if vus[x[:id]] || !meme_reglage?(x[:j], dep[:j])
              xa = aligne(x, dep[:j])
              next unless relies_large?(c, xa)
              vus[x[:id]] = true; fam << xa; file << xa
            end
          end
          next if fam.size < 2
          tout = { id: dep[:id], groupes: fam.flat_map { |x| x[:groupes] }, j: dep[:j], chemins: fam.flat_map { |x| chemins_de(x) } }
          tout[:pts], tout[:ferme] = tout[:chemins][0]
          nb = reconstruire(tout, p_de(dep[:j]))
          compo += 1
          fusionnees += fam.size
          refus += 1 if nb.size > couches_de(p_de(dep[:j])).size
        end
        rep = compo > 0 ? (A2M::Suivi.repercer_toutes(m) rescue [0, ['erreur']]) : [0, []]
        m.commit_operation
        msg = if compo.zero?
          "Aucune cloison à fusionner (#{cand.size} cloisons reconnues).\n" + diagnostic_cloisons(cand)
        else
          "#{fusionnees} cloisons réunies en #{compo} ensemble(s)."
        end
        msg += "\n\nAttention : dans #{refus} ensemble(s), SketchUp a refusé l'union des volumes : les cloisons restent côte à côte (liées, modifiables ensemble)." if refus > 0
        msg += "\n\n#{rep[0]} ouverture(s) repercée(s) à la place de leur porte ou fenêtre." if rep[0] > 0
        msg += "\n\nÀ refaire à la main (non repercées) : #{rep[1].join(', ')}." if rep[1].any?
        UI.messagebox(msg)
      rescue StandardError => ex
        m.abort_operation
        UI.messagebox("La fusion n'a pas pu se faire (#{ex.message}).")
      end
    end

    # Un groupe de mur (balise d'un type de mur) qu'on peut proposer à la modification, même sans mémoire
    def self.mur_possible?(e)
      return false unless e.is_a?(Sketchup::Group) && e.valid? && e.layer
      return true if e.get_attribute('a2m_mur', 'id')
      TYPES.any? { |t| t[1] == e.layer.name }
    end

    # Mur dessiné avant la mémoire des réglages : si c'est un mur droit (rectangle en plan, ouvertures éventuelles comprises),
    # on retrouve son tracé (axe), son épaisseur et sa hauteur. Renvoie true si la mémoire a été posée.
    def self.adopter(g)
      return true if g.get_attribute('a2m_mur', 'id')
      type = TYPES.find { |t| t[1] == g.layer.name } or return false
      tr = g.transformation
      faces = g.entities.grep(Sketchup::Face)
      zmin = faces.map { |f| f.vertices.map { |v| (tr * v.position).z }.min }.min or return false
      bas = faces.select { |f| (tr * f.normal).z < -0.99 && f.vertices.all? { |v| ((tr * v.position).z - zmin).abs < 0.05 } }
      return false if bas.empty?
      pts = bas.flat_map { |f| f.vertices.map { |v| tr * v.position } }
      boucles = bas.map { |f| f.outer_loop.vertices.map { |v| tr * v.position } }
      # direction principale : le plus long côté
      longest = boucles.flat_map { |b| b.each_with_index.map { |q, i| [q, b[(i + 1) % b.size]] } }.max_by { |a, b| a.distance(b) }
      d = longest[1] - longest[0]
      d.z = 0
      return false if d.length < 0.1
      d.normalize!
      perp = Geom::Vector3d.new(-d.y, d.x, 0)
      ok = boucles.all? do |b|
        b.each_with_index.all? do |q, i|
          e = b[(i + 1) % b.size] - q
          e.z = 0
          e.length < 0.01 || e.normalize.dot(d).abs > 0.995 || e.normalize.dot(perp).abs > 0.995
        end
      end
      return false unless ok
      us = pts.map { |q| (q - pts[0]).dot(d) }; vs = pts.map { |q| (q - pts[0]).dot(perp) }
      u0, u1 = us.minmax; v0, v1 = vs.minmax
      ep = (v1 - v0).to_f * 2.54
      return false if ep < 0.5 || ep > 80 || (u1 - u0) < (v1 - v0)
      haut = (g.bounds.max.z - g.bounds.min.z).to_f * 0.0254
      vm = (v0 + v1) / 2.0
      a = pts[0].offset(d, u0).offset(perp, vm); b = pts[0].offset(d, u1).offset(perp, vm)
      a.z = zmin; b.z = zmin
      id = "#{Time.now.to_i}#{rand(100_000)}"
      p = { type: type, h: haut.round(3), e: ep.round(1), trace: 0 }
      marquer(g, id, [a, b], false, p, 0)
      true
    rescue StandardError
      false
    end

    # Réglages mémorisés → paramètres complets pour couches_de
    def self.p_de(j)
      if j['compose']
        p_compose(j).merge(type: ['Mur composé'], h: j['couches'].map { |c| c[2].to_f }.max, e: j['couches'].sum { |c| c[1].to_f }.round(1))
      else
        { type: type_nomme(j['type']), h: j['h'].to_f, e: j['e'].to_f, trace: j['trace'].to_i }
      end
    end

    # Refait le mur avec un nouveau tracé (mêmes réglages)
    def self.refaire_trace(id, chemins)
      m = Sketchup.active_model
      r = murs_du_modele(m)[id] or return false
      r[:chemins] = chemins.size > 1 ? chemins : nil
      r[:pts], r[:ferme] = chemins[0]
      m.start_operation('Modifier le tracé du mur (métré)', true)
      begin
        reconstruire(r, p_de(r[:j]))
        m.commit_operation
        true
      rescue StandardError => ex
        m.abort_operation
        UI.messagebox("Le tracé n'a pas pu être modifié (#{ex.message}). Vérifiez que le tracé ne se recoupe pas.")
        false
      end
    end

    def self.modifier(ent)
      murs = murs_du_modele
      r = mur_de(ent, murs)
      if r.nil? && mur_possible?(ent) && adopter(ent)
        murs = murs_du_modele
        r = mur_de(ent, murs)
        Sketchup.status_text = 'Mur ancien repris comme un mur droit simple (son tracé est son axe).'
      end
      unless r
        UI.messagebox("Ce mur ne peut pas être repris automatiquement : il n'est pas droit (angle, tour fermé…) ou n'a pas gardé ses réglages.\n\nRetracez-le une fois avec « Dessiner un mur » : il pourra ensuite être modifié ici, tracé compris.")
        return
      end
      return @fen_modif.bring_to_front if @fen_modif && (@fen_modif.visible? rescue false)
      c = p_compose(r[:j])
      cs = c[:couches].map { |x| { 'type' => x[:type][0], 'e' => x[:e], 'h' => x[:h], 'b' => x[:b].to_f } }
      couleurs = {}
      TYPES.each { |t| couleurs[t[0]] = A2M::Compositions::COULEURS[t[1]] || [190, 190, 190] }
      nb = famille(r, murs).size
      donnees = { 'n' => cs.size, 'cote' => c[:cote], 'ref' => c[:ref], 'couches' => cs, 'couleurs' => couleurs,
                  'types' => TYPES.map { |t| [t[0], t[3], t[2]] }, 'defaut' => COMPO_DEFAUT,
                  'cotes' => ['Intérieur à droite du tracé', 'Intérieur à gauche du tracé', 'Tracé dans l\'axe de la couche d\'insertion'] }
      corps = CORPS_COMPOSE.sub('Dessiner le mur', 'Appliquer à ce mur')
                           .sub('<button id="annuler"', '<button id="trace" type="button" class="puce">Modifier le tracé…</button><button id="annuler"')
                           .sub('<button id="go"', "<button id=\"tous\" type=\"button\" class=\"puce\">Appliquer aux #{nb} murs reliés de même composition</button><button id=\"go\"")
      js = SCRIPT_COMPOSE + "\nel('trace').addEventListener('click', function () { sketchup.trace(''); });\nel('tous').addEventListener('click', function () { etat.tous = true; el('go').click(); etat.tous = false; });\n"
      html = A2M::Panneau.page('Modifier le mur', 'Changez les couches, la couche d’insertion ou le côté, puis appliquez', corps, js, donnees)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : modifier le mur', 'A2M_Panneau_Modif', html, 640, 720)
      @fen_modif = dlg
      dlg.add_action_callback('ok') do |_ctx, json|
        d = (JSON.parse(json.to_s) rescue nil)
        next unless d
        couches = d['c'].map { |x| { type: type_nomme(x['type']), e: x['e'].to_f, h: x['h'].to_f, b: x['b'].to_f } }
        ref = [[d['ref'].to_i, 0].max, couches.size - 1].min
        p = { couches: couches, cote: d['cote'].to_i, ref: ref, type: ['Mur composé'], h: couches.map { |x| x[:h] }.max, e: couches.sum { |x| x[:e] }.round(1) }
        dlg.close
        UI.start_timer(0.1, false) do
          m = Sketchup.active_model
          cibles = d['tous'] ? famille(r, murs_du_modele(m)) : [murs_du_modele(m)[r[:id]]].compact
          m.start_operation('Modifier un mur (métré)', true)
          begin
            nouveaux = cibles.flat_map { |x| reconstruire(x, p) }
            m.commit_operation
            m.selection.clear
            nouveaux.each { |g| m.selection.add(g) }
            Sketchup.status_text = "#{cibles.size} mur(s) modifié(s)."
          rescue StandardError => ex
            m.abort_operation
            UI.messagebox("Le mur n'a pas pu être modifié (#{ex.message}).")
          end
        end
      end
      dlg.add_action_callback('trace') do |_ctx, _x|
        dlg.close
        UI.start_timer(0.1, false) { Sketchup.active_model.select_tool(OutilTrace.new(r[:id])) }
      end
      dlg.add_action_callback('annuler') { |_ctx, _x| dlg.close }
      dlg.set_on_closed { @fen_modif = nil }
      dlg.show
    end

    # Commande : un mur est déjà sélectionné → sa fenêtre s'ouvre ; sinon on clique le mur à modifier
    def self.modifier_mur
      model = Sketchup.active_model
      murs = murs_du_modele(model)
      sel = model.selection.to_a.find { |e| mur_possible?(e) }
      return modifier(sel) if sel
      model.select_tool(OutilModifier.new)
    end

    # Déplace, ajoute ou supprime les points du tracé d'un mur déjà dessiné ; le mur est refait à chaque geste
    class OutilTrace
      PRISE = 12 # pixels

      def initialize(id)
        @id = id
        @sel = nil; @surv = nil; @cur = nil
        @ip = Sketchup::InputPoint.new
      end

      def activate
        charger
        maj_statut
      end

      # @cs : liste de tracés [points, fermé] ; un point se désigne par [numéro de tracé, numéro de point]
      def charger
        r = A2M::DessinMurs.murs_du_modele[@id]
        if r
          @cs = A2M::DessinMurs.chemins_de(r).map { |cp, cf| [cp.map { |q| Geom::Point3d.new(q.x, q.y, q.z) }, cf] }
        else
          Sketchup.active_model.select_tool(nil)
        end
      end

      def maj_statut
        Sketchup.status_text = 'Tracé du mur : cliquez un point puis son nouvel emplacement ; cliquez sur un tronçon pour ajouter un point ; Suppr sur un point le retire ; Échap pour terminer.'
      end

      def deactivate(view) view.invalidate end

      def segments
        res = []
        @cs.each_with_index do |(pts, ferme), c|
          n = pts.size
          (0...(ferme ? n : n - 1)).each { |i| res << [c, i, pts[i], pts[(i + 1) % n]] }
        end
        res
      end

      def ecran(pt, view) q = view.screen_coords(pt); [q.x, q.y] end

      def survol(x, y, view)
        @cs.each_with_index do |(pts, _f), c|
          pts.each_with_index do |q, i|
            a = ecran(q, view)
            return [:point, c, i] if Math.hypot(a[0] - x, a[1] - y) < PRISE
          end
        end
        segments.each do |c, i, a, b|
          sa = ecran(a, view); sb = ecran(b, view)
          d = A2M::DessinMurs.distance_segment(Geom::Point3d.new(x, y, 0), Geom::Point3d.new(sa[0], sa[1], 0), Geom::Point3d.new(sb[0], sb[1], 0))
          return [:segment, c, i, x, y] if d < PRISE
        end
        nil
      end

      def onMouseMove(_flags, x, y, view)
        if @sel
          @ip.pick(view, x, y)
          q = @ip.position
          @cur = Geom::Point3d.new(q.x, q.y, @cs[@sel[0]][0][@sel[1]].z)
        else
          @surv = survol(x, y, view)
        end
        view.invalidate
      end

      def onLButtonDown(_flags, x, y, view)
        if @sel
          return unless @cur
          @cs[@sel[0]][0][@sel[1]] = @cur
          appliquer(view)
        else
          s = survol(x, y, view) or return
          if s[0] == :point
            @sel = [s[1], s[2]]
          else
            c, i = s[1], s[2]
            pts = @cs[c][0]
            a = pts[i]
            pk = view.pickray(x, y)
            q = Geom.intersect_line_plane(pk, [a, Geom::Vector3d.new(0, 0, 1)]) || a
            q = Geom::Point3d.new(q.x, q.y, a.z)
            pts.insert(i + 1, q)
            @sel = [c, i + 1]
          end
          @cur = @cs[@sel[0]][0][@sel[1]]
        end
        view.invalidate
      end

      def onKeyDown(key, _rpt, _flags, view)
        return false unless key == 46 && @surv && @surv[0] == :point && @cs[@surv[1]][0].size > 2 # Suppr
        @cs[@surv[1]][0].delete_at(@surv[2]); @surv = nil
        appliquer(view)
        true
      end

      def onCancel(_reason, view)
        if @sel
          charger; @sel = nil; view.invalidate
        else
          Sketchup.active_model.select_tool(nil)
        end
      end

      def appliquer(view)
        @sel = nil
        A2M::DessinMurs.refaire_trace(@id, @cs.map { |pts, f| [pts.map { |q| Geom::Point3d.new(q.x, q.y, q.z) }, f] })
        charger
        view.invalidate
      end

      def draw(view)
        return unless @cs
        view.line_width = 2
        view.drawing_color = 'orange'
        @cs.each_with_index do |(pts0, ferme), c|
          pts = pts0.each_with_index.map { |q, i| @sel == [c, i] && @cur ? @cur : q }
          pts += [pts[0]] if ferme
          view.draw(GL_LINE_STRIP, pts)
          pts0.each_with_index do |q, i|
            coul = @sel == [c, i] ? 'red' : (@surv && @surv[0] == :point && @surv[1] == c && @surv[2] == i ? 'blue' : 'orange')
            view.draw_points([@sel == [c, i] && @cur ? @cur : q], 10, 2, coul)
          end
        end
      end

      def getExtents
        bb = Geom::BoundingBox.new
        (@cs || []).each { |pts, _f| pts.each { |q| bb.add(q) } }
        bb.add(@cur) if @cur
        bb
      end
    end

    class OutilModifier
      def activate
        Sketchup.status_text = 'Modifier un mur : cliquez sur le mur à modifier (Échap pour quitter).'
      end

      def onSetCursor() false end

      def onLButtonDown(_flags, x, y, view)
        ph = view.pick_helper
        ph.do_pick(x, y)
        e = ph.best_picked
        e = ph.all_picked.find { |q| A2M::DessinMurs.mur_possible?(q) } unless A2M::DessinMurs.mur_possible?(e)
        if A2M::DessinMurs.mur_possible?(e)
          Sketchup.active_model.select_tool(nil)
          UI.start_timer(0, false) { A2M::DessinMurs.modifier(e) }
        else
          UI.beep
          Sketchup.status_text = 'Cet objet n\'est pas un mur (balise de mur, cloison, doublage…).'
        end
      end

      def onCancel(_r, _v) Sketchup.active_model.select_tool(nil) end
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
        (@reglages[p[:cle] || :compose] ||= {})[:cote] = COTES_COMPOSE[p[:cote]]
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
        while (etat.c.length < etat.n) { var d = D.defaut[Math.min(etat.c.length, D.defaut.length - 1)]; etat.c.push({ type: d[0], e: d[1], h: d[2], b: 0 }); }
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
          l.style.cssText = 'display:grid;grid-template-columns:96px 1fr 60px 60px 60px;gap:6px;align-items:center;margin-bottom:6px;padding:6px;border-radius:10px;border:2px solid ' + (r ? '#e07838' : 'transparent') + ';background:' + (r ? '#fdeedd' : 'transparent');
          var bi = document.createElement('button'); bi.type = 'button'; bi.className = 'puce' + (r ? ' rempli' : ''); bi.textContent = r ? '★ Insertion' : 'Insérer ici';
          bi.addEventListener('click', function () { etat.ref = i; rendre(); });
          var sb = document.createElement('select'); sb.style.cssText = 'padding:7px;border:2px solid #d8d0c6;border-radius:8px;background:#fff;min-width:0';
          D.types.forEach(function (t) { var o = document.createElement('option'); o.value = t[0]; o.textContent = t[0]; sb.appendChild(o); }); sb.value = k.type;
          sb.addEventListener('change', function () { k.type = sb.value; var d = D.types.filter(function (t) { return t[0] === sb.value; })[0]; if (d) { k.e = d[1]; k.h = d[2]; } rendre(); });
          var ep = document.createElement('input'); ep.type = 'text'; ep.value = k.e; ep.title = 'Épaisseur (cm)'; ep.style.cssText = 'font-size:13px;padding:6px;text-align:center'; ep.addEventListener('input', function () { k.e = num(ep.value); });
          ep.addEventListener('change', rendre);
          var hh = document.createElement('input'); hh.type = 'text'; hh.value = k.h; hh.title = 'Hauteur (m)'; hh.style.cssText = 'font-size:13px;padding:6px;text-align:center'; hh.addEventListener('input', function () { k.h = num(hh.value); });
          var bb = document.createElement('input'); bb.type = 'text'; bb.value = k.b || 0; bb.title = 'Descend plus bas que le tracé de (cm)'; bb.style.cssText = 'font-size:13px;padding:6px;text-align:center'; bb.addEventListener('input', function () { k.b = num(bb.value); });
          [bi, sb, ep, hh, bb].forEach(function (n) { l.appendChild(n); }); L.appendChild(l);
        });
        var cap = document.createElement('div'); cap.className = 'petit'; cap.textContent = 'Colonnes : insertion · type · épaisseur (cm) · hauteur (m) · descend plus bas (cm, ex. enduit sous le mur).'; L.appendChild(cap);
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

    # Cloison composée : plaque + ossature (rail et montant) + plaque, par exemple 13 + 48 + 13 mm = 74 mm
    COMPO_CLOISON = [['Doublage : plaque de plâtre', 1.3, 2.50], ['Cloison', 4.8, 2.50], ['Doublage : plaque de plâtre', 1.3, 2.50]]

    def self.lancer_cloison() lancer_compose(true) end

    def self.lancer_compose(cloison = false)
      cle = cloison ? :cloison : :compose
      fen = cloison ? @fen_cloison : @fen_compose
      return fen.bring_to_front if fen && (fen.visible? rescue false)
      r = @reglages[cle] || {}
      prec = r[:couches] || (cloison ? COMPO_CLOISON : [COMPO_DEFAUT[0], COMPO_DEFAUT[1], COMPO_DEFAUT[2], COMPO_DEFAUT[3]])
      cs = prec.map { |t, e, h, b| { 'type' => t, 'e' => e, 'h' => h, 'b' => b.to_f } }
      n = [[r[:n] || cs.size, 1].max, 5].min
      ref = r[:ref] || (cloison ? 1 : index_insertion(cs.map { |c| c['type'] }))
      r = { cote: COTES_COMPOSE[2] }.merge(r) if cloison
      couleurs = {}
      TYPES.each { |t| couleurs[t[0]] = A2M::Compositions::COULEURS[t[1]] || [190, 190, 190] }
      donnees = { 'n' => n, 'cote' => COTES_COMPOSE.index(r[:cote]) || 0, 'ref' => [ref, n - 1].min, 'couches' => cs, 'couleurs' => couleurs,
                  'types' => TYPES.map { |t| [t[0], t[3], t[2]] }, 'defaut' => COMPO_DEFAUT,
                  'cotes' => ['Intérieur à droite du tracé', 'Intérieur à gauche du tracé', 'Tracé dans l\'axe de la couche d\'insertion'] }
      html = A2M::Panneau.page(cloison ? 'Cloison composée' : 'Mur composé',
                               cloison ? 'Choisissez vos couches (plaque, ossature, isolant…) : le tracé suit l\'axe de la couche choisie' : 'Choisissez les couches et celle par laquelle le mur est inséré',
                               CORPS_COMPOSE.sub('Dessiner le mur', cloison ? 'Dessiner la cloison' : 'Dessiner le mur'), SCRIPT_COMPOSE, donnees)
      dlg = A2M::Panneau.fenetre(cloison ? 'Métré Atelier 2M : cloison composée' : 'Métré Atelier 2M : mur composé', cloison ? 'A2M_Panneau_Cloison' : 'A2M_Panneau_Compose', html, 620, 700)
      cloison ? (@fen_cloison = dlg) : (@fen_compose = dlg)
      dlg.add_action_callback('ok') do |_ctx, json|
        d = (JSON.parse(json.to_s) rescue nil)
        next unless d
        couches = d['c'].map { |c| { type: TYPES.find { |x| x[0] == c['type'] } || TYPES[0], e: c['e'].to_f, h: c['h'].to_f, b: c['b'].to_f } }
        cote = d['cote'].to_i
        ref = [[d['ref'].to_i, 0].max, couches.size - 1].min
        @reglages[cle] = { n: couches.size, cote: COTES_COMPOSE[cote], ref: ref, couches: couches.map { |c| [c[:type][0], c[:e], c[:h], c[:b]] } }
        p = { couches: couches, cote: cote, ref: ref, cle: cle, cloison: cloison, type: [cloison ? 'Cloison composée' : 'Mur composé'], h: couches.map { |c| c[:h] }.max, e: couches.sum { |c| c[:e] }.round(1) }
        dlg.close
        UI.start_timer(0, false) { Sketchup.active_model.select_tool(Outil.new(p)) }
      end
      dlg.add_action_callback('annuler') { |_ctx, _x| dlg.close }
      dlg.set_on_closed { cloison ? (@fen_cloison = nil) : (@fen_compose = nil) }
      dlg.show
    end

    # ---- L'outil : clics successifs ; Entrée ou double-clic termine ; clic sur le premier point ferme le tour ----
    class Outil
      def initialize(p)
        @p = p; @pts = []; @pt = A2M::Pointeur.new; @rep = nil; @rep_att = false
      end

      def activate
        maj_statut
      end

      def maj_statut
        lib = @p[:couches] ? "Mur composé (#{@p[:couches].map { |c| c[:e] }.join(' + ')} cm)" : "#{@p[:type][0]} — h #{@p[:h]} m, ép. #{@p[:e]} cm"
        Sketchup.status_text = "#{lib}, #{A2M::DessinMurs.lib_cote(@p).downcase} (Tab pour changer). Cliquez les points du tracé (accrochages SketchUp) ; tapez une longueur puis Entrée ; " \
                               'flèche haut ou clic droit = partir d\'un repère (point + direction + distance) ; Ctrl ou clic droit = axes verrouillés ou tracé libre, Maj = bloquer la direction, flèche droite = axe rouge, flèche gauche = axe vert ; clic sur le 1er point (carré vert) pour fermer ; double-clic ou Entrée pour finir ; Échap pour annuler.'
        Sketchup.vcb_label = 'Longueur'
      end

      def deactivate(view) view.invalidate end
      def resume(view) maj_statut; view.invalidate end

      def onMouseMove(_flags, x, y, view)
        if @rep_att
          @pt.bouger(view, x, y, [])
          return view.invalidate
        end
        base = @rep ? [@rep] : @pts
        q = @pt.bouger(view, x, y, base)
        Sketchup.vcb_value = base[-1].distance(q).to_l.to_s if base.any?
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
        if key == 38 && !@rep && !@rep_att   # flèche haut (R est pris par SketchUp : rectangle)
          return true if rpt > 1
          demarrer_repere(view)
          return true
        end
        @pt.touche_bas(key, rpt, view, @rep ? [@rep] : @pts)
      end
      def onKeyUp(key, _rpt, _flags, view) @pt.touche_haut(key, view) end
      def getMenu(menu)
        menu.add_item('Partir d\'un repère (point + direction + distance)  ↑') { demarrer_repere(Sketchup.active_model.active_view) } unless @rep || @rep_att
        @pt.menu(menu)
      end

      def demarrer_repere(view)
        @rep_att = true
        Sketchup.status_text = 'Repère : cliquez le point de référence (accrochages SketchUp), puis visez la direction et tapez la distance, Entrée. Échap pour annuler.'
        view.invalidate
      end

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
        if @rep_att
          @pt.bouger(view, _x, _y, []) 
          q = @pt.pos || @pt.ip.position
          @rep = Geom::Point3d.new(q.x, q.y, @pts.empty? ? q.z : @pts[0].z)
          @rep_att = false
          @pt.valider
          Sketchup.vcb_label = 'Distance'
          Sketchup.status_text = 'Repère posé. Visez la direction (flèche droite = axe rouge, flèche gauche = axe vert, ou Maj pour la bloquer), tapez la distance puis Entrée. Échap pour annuler le repère.'
          view.invalidate
          return
        end
        return UI.beep if @rep
        ajouter(@pt.pos || @pt.ip.position, view, @pt.ferme?)
      end

      def onLButtonDoubleClick(_flags, _x, _y, view)
        terminer(view)
      end

      def onReturn(view) terminer(view) end

      def onUserText(text, view)
        l = text.to_l rescue nil
        if @rep
          return UI.beep unless l && @pt.pos
          dir = @pt.pos - @rep
          return UI.beep if dir.length < 0.001
          dir.length = l
          q = @rep.offset(dir)
          @rep = nil
          @pt.vider(view)
          Sketchup.vcb_label = 'Longueur'
          ajouter(q, view)
          maj_statut
          return
        end
        return UI.beep if @rep_att
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
        if @rep || @rep_att
          @rep = nil; @rep_att = false; @pt.vider(view); maj_statut; view.invalidate
          return
        end
        @pts.empty? ? Sketchup.active_model.select_tool(nil) : reset(view)
      end

      def draw(view)
        if @rep
          @pt.dessiner(view, [@rep], 'orange')
          if @pt.pos
            view.line_width = 1; view.drawing_color = 'orange'
            view.line_stipple = '-'
            view.draw(GL_LINES, [@rep, @pt.pos])
            view.line_stipple = ''
          end
          view.draw_points([@rep], 9, 2, 'orange') rescue nil
          return
        end
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
        bb.add(@rep) if @rep
        bb
      end
    end
  end
end
