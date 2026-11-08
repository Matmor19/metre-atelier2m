# encoding: UTF-8
# Métré Atelier 2M : toiture qui suit exactement le contour des murs (squelette droit : tous les pans ont la même pente)
# Calcul purement géométrique en mètres (listes [x, y]) : sans SketchUp, donc vérifiable à part.
module A2M
  module Squelette
    EPS = 1e-7

    def self.aire(p) p.each_with_index.sum { |(x1, y1), i| x2, y2 = p[(i + 1) % p.size]; x1 * y2 - x2 * y1 } / 2.0 end

    # Contour propre : sans doublons ni points alignés, sens inverse des aiguilles d'une montre
    def self.nettoyer(pts, tol = 1e-4)
      p = pts.map { |x, y| [x.to_f, y.to_f] }
      loop do
        n = p.size
        break if n < 3
        garde = (0...n).reject do |i|
          a = p[(i - 1) % n]; b = p[i]; c = p[(i + 1) % n]
          (b[0] - a[0]).abs < tol && (b[1] - a[1]).abs < tol ||
            ((b[0] - a[0]) * (c[1] - b[1]) - (b[1] - a[1]) * (c[0] - b[0])).abs < tol * [Math.hypot(b[0] - a[0], b[1] - a[1]), Math.hypot(c[0] - b[0], c[1] - b[1])].max &&
              ((b[0] - a[0]) * (c[0] - b[0]) + (b[1] - a[1]) * (c[1] - b[1])) > 0
        end
        break if garde.size == n
        p = garde.map { |i| p[i] }
      end
      p.reverse! if aire(p) < 0
      p
    end

    # Décalage vers l'extérieur d de chaque côté (angles vifs) ; d < 0 : vers l'intérieur
    def self.decaler(p, d)
      n = p.size
      lignes = (0...n).map do |i|
        a = p[i]; b = p[(i + 1) % n]
        dx = b[0] - a[0]; dy = b[1] - a[1]; l = Math.hypot(dx, dy)
        nx = dy / l; ny = -dx / l                      # normale extérieure (contour anti-horaire)
        [a[0] + nx * d, a[1] + ny * d, dx / l, dy / l]
      end
      (0...n).map do |i|
        x1, y1, dx1, dy1 = lignes[(i - 1) % n]; x2, y2, dx2, dy2 = lignes[i]
        det = dx1 * dy2 - dy1 * dx2
        t = ((x2 - x1) * dy2 - (y2 - y1) * dx2) / det
        [x1 + dx1 * t, y1 + dy1 * t]
      end
    end

    Sommet = Struct.new(:q, :v, :el, :er, :prev, :next, :noeud, :vivant)

    # Pans : [[ [x, y, z], … ], …] pour un contour anti-horaire ; z = pente × temps, 0 à l'égout
    def self.toit(contour, pente)
      p = nettoyer(contour)
      n = p.size
      raise 'contour trop petit' if n < 3
      aretes = (0...n).map do |i|
        a = p[i]; b = p[(i + 1) % n]
        dx = b[0] - a[0]; dy = b[1] - a[1]; l = Math.hypot(dx, dy)
        d = [dx / l, dy / l]; nn = [-d[1], d[0]]
        { d: d, n: nn, c: nn[0] * a[0] + nn[1] * a[1] }
      end
      noeuds = []; cles = {}
      noeud = lambda do |pt, t|
        k = [(pt[0] * 1e5).round, (pt[1] * 1e5).round, (t * 1e5).round]
        cles[k] ||= (noeuds << [pt[0], pt[1], t]; noeuds.size - 1)
      end
      vitesse = lambda do |e1, e2|
        n1 = aretes[e1][:n]; n2 = aretes[e2][:n]
        den = 1 + n1[0] * n2[0] + n1[1] * n2[1]
        den < 1e-6 ? [0.0, 0.0] : [(n1[0] + n2[0]) / den, (n1[1] + n2[1]) / den]
      end
      sommets = (0...n).map do |i|
        el = (i - 1) % n; er = i
        Sommet.new([p[i][0], p[i][1]], vitesse.call(el, er), el, er, nil, nil, noeud.call(p[i], 0.0), true)
      end
      sommets.each_with_index { |s, i| s.prev = sommets[(i - 1) % n]; s.next = sommets[(i + 1) % n] }
      tous = sommets.dup
      arcs = []   # [noeud a, noeud b, arête gauche, arête droite]
      # position d'un sommet à l'instant t : q est la position « à t = 0 » (q + v·t)
      pos = ->(s, t) { [s.q[0] + s.v[0] * t, s.q[1] + s.v[1] * t] }
      # q a été défini à t = 0 pour les sommets d'origine ; pour les nouveaux, on stocke q = P - v·t
      cycle = lambda do |s|
        r = [s]; x = s.next
        while x != s
          r << x; x = x.next
          raise 'cycle invalide' if r.size > 10_000
        end
        r
      end
      t_now = 0.0
      garde = 0
      loop do
        garde += 1
        raise 'calcul trop long' if garde > 20 * n + 200
        vivants = tous.select(&:vivant)
        break if vivants.empty?
        # cycles de 2 sommets : arête du faîtage, et fin
        vus = {}
        vivants.each do |s|
          next if vus[s]
          c = cycle.call(s); c.each { |x| vus[x] = true }
          if c.size <= 2
            if c.size == 2
              a, b = c
              arcs << [a.noeud, b.noeud, a.el, a.er] if a.noeud != b.noeud
            end
            c.each { |x| x.vivant = false }
          end
        end
        vivants = tous.select(&:vivant)
        break if vivants.empty?
        meilleur = nil
        vivants.each do |a|
          # arête a → a.next
          b = a.next
          e = aretes[a.er]
          dv = [(b.v[0] - a.v[0]) * e[:d][0] + (b.v[1] - a.v[1]) * e[:d][1]]
          if dv[0] < -EPS
            dq = (b.q[0] - a.q[0]) * e[:d][0] + (b.q[1] - a.q[1]) * e[:d][1]
            t = -dq / dv[0]
            meilleur = [t, :arete, a] if t >= t_now - 1e-9 && (meilleur.nil? || t < meilleur[0] - 1e-12)
          end
          # sommet rentrant : coupe une arête
          l = aretes[a.el][:d]; r = aretes[a.er][:d]
          next unless l[0] * r[1] - l[1] * r[0] < -1e-9 && (a.v[0].abs + a.v[1].abs) > 0
          vivants.each do |x|
            e2 = x.er
            next if e2 == a.el || e2 == a.er
            en = aretes[e2]
            den = en[:n][0] * a.v[0] + en[:n][1] * a.v[1] - 1.0
            next if den.abs < EPS
            t = (en[:c] - (en[:n][0] * a.q[0] + en[:n][1] * a.q[1])) / den
            next if t < t_now - 1e-9
            pt = [a.q[0] + a.v[0] * t, a.q[1] + a.v[1] * t]
            xa = pos.call(x, t); ya = pos.call(x.next, t)
            s = en[:d][0] * (pt[0] - xa[0]) + en[:d][1] * (pt[1] - xa[1])
            lg = en[:d][0] * (ya[0] - xa[0]) + en[:d][1] * (ya[1] - xa[1])
            next unless s >= -1e-6 && s <= lg + 1e-6
            meilleur = [t, :coupe, a, x] if meilleur.nil? || t < meilleur[0] - 1e-12
          end
        end
        raise 'aucun événement : contour trop complexe' unless meilleur
        t = [meilleur[0], t_now].max
        t_now = t
        case meilleur[1]
        when :arete
          a = meilleur[2]; b = a.next
          pt = pos.call(a, t)
          nd = noeud.call(pt, t)
          arcs << [a.noeud, nd, a.el, a.er] if a.noeud != nd
          arcs << [b.noeud, nd, b.el, b.er] if b.noeud != nd
          m = Sommet.new(nil, vitesse.call(a.el, b.er), a.el, b.er, a.prev, b.next, nd, true)
          m.q = [pt[0] - m.v[0] * t, pt[1] - m.v[1] * t]
          a.vivant = false; b.vivant = false
          if a.prev == b
            m.prev = m; m.next = m
          else
            a.prev.next = m; b.next.prev = m
          end
          tous << m
        when :coupe
          r = meilleur[2]; x = meilleur[3]; y = x.next
          pt = [r.q[0] + r.v[0] * t, r.q[1] + r.v[1] * t]
          nd = noeud.call(pt, t)
          arcs << [r.noeud, nd, r.el, r.er] if r.noeud != nd
          e = x.er
          v1 = Sommet.new(nil, vitesse.call(e, r.er), e, r.er, nil, nil, nd, true)
          v2 = Sommet.new(nil, vitesse.call(r.el, e), r.el, e, nil, nil, nd, true)
          [v1, v2].each { |v| v.q = [pt[0] - v.v[0] * t, pt[1] - v.v[1] * t] }
          rp = r.prev; rn = r.next
          # cycle A : x → v1 → rn … ; cycle B : rp → v2 → y …
          x.next = v1; v1.prev = x; v1.next = rn; rn.prev = v1
          rp.next = v2; v2.prev = rp; v2.next = y; y.prev = v2
          r.vivant = false
          tous << v1 << v2
        end
      end
      # Un pan par côté : on enchaîne les arcs qui touchent ce côté
      noeuds_orig = (0...n).map { |i| noeud.call(p[i], 0.0) }
      (0...n).map do |i|
        segs = arcs.select { |_a, _b, g, d| g == i || d == i }.map { |a, b, _g, _d| [a, b] }
        segs << [noeuds_orig[i], noeuds_orig[(i + 1) % n]]
        adj = Hash.new { |h, k| h[k] = [] }
        segs.each { |a, b| adj[a] << b; adj[b] << a }
        depart = noeuds_orig[i]; chaine = [depart]; prec = nil; cur = depart
        (segs.size + 2).times do
          suiv = adj[cur].find { |x| x != prec && !(chaine.include?(x) && x != depart) } 
          suiv = adj[cur].find { |x| x != prec } if suiv.nil?
          break if suiv.nil?
          # première étape : suivre le côté d'origine vers son point d'arrivée
          if prec.nil?
            suiv = noeuds_orig[(i + 1) % n]
          end
          break if suiv == depart
          chaine << suiv
          prec = cur; cur = suiv
        end
        chaine.map { |k| [noeuds[k][0], noeuds[k][1], noeuds[k][2] * pente] }
      end.select { |f| f.size >= 3 }
    end
  end
end
