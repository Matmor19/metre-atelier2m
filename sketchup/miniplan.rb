# encoding: UTF-8
# Métré Atelier 2M : mini-plan fidèle. Tranche réelle du modèle à hauteur de coupe (murs, portes, fenêtres, meubles tels que dessinés),
# renvoyée au panneau sous forme de tracés vectoriels en cm. Rien n'est redessiné à la main : c'est la géométrie du modèle.
require 'sketchup.rb'
require 'json'

module A2M
  module MiniPlan
    IGNORER = %w[A2M_TOITURE A2M_COUVERTURE A2M_CHARPENTE A2M_GOUTTIERE A2M_DESCENTE A2M_ZINGUERIE A2M_COTES A2M_PLAN].freeze
    PROFONDEUR = 5

    def self.ignorer?(nom)
      n = nom.to_s
      IGNORER.any? { |p| n.start_with?(p) } || n.start_with?('A2M_Plan') || n.start_with?('A2M_COTES')
    end

    # Points d'intersection (pouces) du contour d'une face avec le plan z = zc, appariés deux à deux le long de la droite de section
    def self.segments_face(f, t, zc)
      pts = []
      f.loops.each do |lp|
        vs = lp.vertices.map { |v| t * v.position }
        vs.each_with_index do |a, i|
          b = vs[(i + 1) % vs.size]
          da = a.z - zc; db = b.z - zc
          next if (da > 0) == (db > 0)
          k = da / (da - db)
          pts << [a.x + (b.x - a.x) * k, a.y + (b.y - a.y) * k]
        end
      end
      return [] if pts.size < 2 || pts.size.odd?
      dx = pts.map(&:first).minmax; dy = pts.map(&:last).minmax
      ax = (dx[1] - dx[0]) >= (dy[1] - dy[0]) ? 0 : 1
      pts.sort_by! { |p| p[ax] }
      pts.each_slice(2).to_a
    end

    def self.cle(p) [(p[0] * 25.4).round(0), (p[1] * 25.4).round(0)] end   # précision 1/25 mm

    # Chaîne les segments en contours ; renvoie des tracés « M x y L … Z »
    def self.chainer(segs)
      return [] if segs.empty?
      pts = {}
      voisins = Hash.new { |h, k| h[k] = [] }
      segs.each_with_index do |(a, b), i|
        ka = cle(a); kb = cle(b)
        next if ka == kb
        pts[ka] = a; pts[kb] = b
        voisins[ka] << [kb, i]; voisins[kb] << [ka, i]
      end
      pris = {}
      chemins = []
      voisins.keys.each do |dep|
        voisins[dep].each do |(suiv0, i0)|
          next if pris[i0]
          pris[i0] = true
          chemin = [dep, suiv0]
          cur = suiv0
          loop do
            nxt = voisins[cur].find { |(_k, j)| !pris[j] }
            break unless nxt
            pris[nxt[1]] = true
            chemin << nxt[0]
            cur = nxt[0]
            break if cur == dep
          end
          chemins << chemin
        end
      end
      chemins.map do |ch|
        ferme = ch.first == ch.last
        ch = ch[0...-1] if ferme
        d = ch.each_with_index.map { |k, i| p = pts[k]; format('%s%.1f %.1f', i.zero? ? 'M' : 'L', p[0] * 2.54, -p[1] * 2.54) }.join(' ')
        [d + (ferme ? ' Z' : ''), ferme]
      end
    end

    # Parcourt les entités visibles et renvoie les segments de la tranche, regroupés par famille
    def self.tranche(model, zc)
      fam = { 'murs' => [], 'ouv' => [], 'autres' => [] }
      pieces = []
      parc = lambda do |ents, t, prof, famille|
        ents.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          next if e.hidden? || !e.layer.visible?
          nom = e.layer.name
          next if ignorer?(nom)
          tt = t * e.transformation
          f = famille
          f = 'murs' if nom.start_with?('A2M_MUR')
          f = 'ouv' if nom.start_with?('A2M_PORTE') || nom.start_with?('A2M_FENETRE')
          sous = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          if nom == 'A2M_PIECE'
            fc = sous.grep(Sketchup::Face).max_by(&:area)
            if fc
              pieces << fc.outer_loop.vertices.map { |v| p = tt * v.position; [p.x * 2.54, -p.y * 2.54] }
            end
            next
          end
          bb = sous.respond_to?(:parent) && sous.parent.respond_to?(:bounds) ? sous.parent.bounds : nil
          if bb
            zs = (0..7).map { |i| (tt * bb.corner(i)).z }
            next if zs.min > zc || zs.max < zc
          end
          sous.grep(Sketchup::Face).each do |fc|
            fam[f] += segments_face(fc, tt, zc).map { |s| s } unless fc.normal.z.abs > 0.999
          end
          parc.call(sous, tt, prof + 1, f) if prof < PROFONDEUR
        end
      end
      parc.call(model.entities, Geom::Transformation.new, 0, 'autres')
      [fam, pieces]
    end

    def self.donnees(coupe_cm = 120.0)
      model = Sketchup.active_model
      sol = A2M::Plan2D.sol_auto(model)
      zc = (sol + coupe_cm) / 2.54 + 0.01
      fam, pieces = tranche(model, zc)
      res = { 'sol' => sol, 'cut' => coupe_cm }
      res['pieces'] = pieces.map { |pl| 'M' + pl.map { |x, y| format('%.1f %.1f', x, y) }.join(' L') + ' Z' }
      res['murs'] = chainer(fam['murs']).map { |d, f| { 'd' => d, 'f' => f } }
      res['ouv'] = chainer(fam['ouv']).map { |d, f| { 'd' => d, 'f' => f } }
      res['autres'] = chainer(fam['autres']).map { |d, f| { 'd' => d, 'f' => f } }
      bb = model.bounds
      res['bb'] = bb.empty? ? [0, 0, 100, 100] : [bb.min.x * 2.54, -bb.max.y * 2.54, bb.max.x * 2.54, -bb.min.y * 2.54]
      res
    end
  end
end
