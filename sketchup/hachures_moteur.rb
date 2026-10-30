# encoding: UTF-8
# Métré Atelier 2M : moteur des hachures (sans SketchUp)
#  - lecture des fichiers .pat (format AutoCAD : *NOM, puis une ligne par famille de traits) ;
#  - recherche du carreau qui se répète sans raccord visible ;
#  - dessin du carreau en image PNG : couleur et transparence du trait, couleur et transparence du fond, épaisseur.
require 'zlib'

module A2M
  module MotifPat
    # Famille : [angle, x0, y0, dx, dy, [tirets…]] ; motif : { 'nom', 'description', 'familles', 'ref' }
    # Texte d'un fichier .pat (UTF-8, ou Windows-1252 pour les fichiers venus d'AutoCAD)
    def self.texte_fichier(chemin)
      t = File.binread(chemin).sub(/\A\xEF\xBB\xBF/n, '')
      u = t.dup.force_encoding('UTF-8')
      u.valid_encoding? ? u : t.force_encoding('Windows-1252').encode('UTF-8', invalid: :replace, undef: :replace)
    end

    # nom_defaut : nom donné au motif quand le fichier commence directement par les traits (sans ligne *NOM)
    def self.lire(texte, nom_defaut = nil)
      motifs = []
      cour = nil
      texte.to_s.encode('UTF-8', invalid: :replace, undef: :replace).each_line do |l|
        l = l.sub(/;.*/, '').strip
        next if l.empty?
        if l.start_with?('*')
          nom, desc = l[1..-1].split(',', 2).map { |x| x.to_s.strip }
          cour = { 'nom' => nom, 'description' => desc.to_s.empty? ? nom : desc, 'familles' => [] }
          motifs << cour
        else
          v = l.split(',').map { |x| Float(x.strip) rescue nil }
          next if v.size < 5 || v.compact.size != v.size
          unless cour
            next unless nom_defaut
            cour = { 'nom' => nom_defaut, 'description' => nom_defaut, 'familles' => [] }
            motifs << cour
          end
          cour['familles'] << [v[0], v[1], v[2], v[3], v[4], v[5..-1] || []]
        end
      end
      motifs.select! { |m| m['familles'].any? { |f| f[4].abs > 1e-9 } }
      motifs.each { |m| m['ref'] = reference(m['familles']) }
      motifs
    end

    # Écartement de référence : le plus petit écart entre deux traits d'une même famille
    def self.reference(familles)
      familles.map { |f| f[4].abs }.select { |x| x > 1e-9 }.min || 1.0
    end

    # Plus petite longueur T > 0 telle que le motif d'une famille se répète en se décalant de T dans la direction w
    # (:libre : n'importe quelle longueur convient, trait continu parallèle à w)
    def self.periode(f, wx, wy)
      a = f[0] * Math::PI / 180.0
      ux, uy = Math.cos(a), Math.sin(a)
      nx, ny = -uy, ux
      dx, dy = f[3], f[4]
      tirets = f[5]
      pp = tirets.sum(&:abs)
      wn = wx * nx + wy * ny
      wu = wx * ux + wy * uy
      if wn.abs < 1e-9
        return :libre if tirets.empty? || pp < 1e-9
        return pp / wu.abs
      end
      1.upto(400) do |k|
        t = k * (dy / wn).abs
        ks = t * wn / dy
        return t if tirets.empty? || pp < 1e-9
        r = (t * wu - ks * dx) % pp
        return t if r < 1e-4 * pp || pp - r < 1e-4 * pp
      end
      nil
    end

    # Commun multiple (à peu près) d'une liste de longueurs
    def self.commun(ps, ref)
      ps = ps.compact.reject { |p| p == :libre }
      return ref if ps.empty?
      ps.sort.each do |p0|
        1.upto(60) do |m|
          t = p0 * m
          return t if ps.all? { |p| x = t / p; (x - x.round).abs < 2e-3 * [x, 1].max }
        end
      end
      nil
    end

    # Carreau qui se répète : [largeur, hauteur] en unités du motif (approché si le motif ne se répète pas vite)
    def self.carreau(m)
      ref = m['ref']
      fam = m['familles'].select { |f| f[4].abs > 1e-9 }
      tx = commun(fam.map { |f| periode(f, 1, 0) }, ref)
      ty = commun(fam.map { |f| periode(f, 0, 1) }, ref)
      tx = 24 * ref if tx.nil? || tx > 80 * ref
      ty = 24 * ref if ty.nil? || ty > 80 * ref
      [tx, ty]
    end

    # Traits d'une famille dans le rectangle [x0,x1]×[y0,y1] : liste de segments [[xa,ya,xb,yb], …] (point : xa=xb, ya=yb)
    def self.segments(f, x0, y0, x1, y1)
      a = f[0] * Math::PI / 180.0
      ux, uy = Math.cos(a), Math.sin(a)
      nx, ny = -uy, ux
      ox, oy, dx, dy, tirets = f[1], f[2], f[3], f[4], f[5]
      return [] if dy.abs < 1e-9
      coins = [[x0, y0], [x1, y0], [x1, y1], [x0, y1]]
      pn = coins.map { |x, y| x * nx + y * ny }
      pu = coins.map { |x, y| x * ux + y * uy }
      on = ox * nx + oy * ny
      ka, kb = [(pn.min - on) / dy, (pn.max - on) / dy].minmax
      pp = tirets.sum(&:abs)
      res = []
      (ka.floor..kb.ceil).each do |k|
        bx = ox + k * (dx * ux + dy * nx)
        by = oy + k * (dx * uy + dy * ny)
        bu = bx * ux + by * uy
        ta = pu.min - bu; tb = pu.max - bu
        if tirets.empty? || pp < 1e-9
          res << [bx + ta * ux, by + ta * uy, bx + tb * ux, by + tb * uy]
        else
          t = (ta / pp).floor * pp
          garde = 0
          while t < tb && garde < 20_000
            tirets.each do |d|
              if d >= 0 && t + d >= ta && t <= tb
                res << [bx + t * ux, by + t * uy, bx + (t + d) * ux, by + (t + d) * uy]
              end
              t += d.abs
            end
            garde += 1
          end
        end
      end
      res
    end

    def self.hex(c)
      c = c.to_s.sub('#', '')
      c = '000000' unless c =~ /\A\h{6}\z/
      [c[0, 2].hex, c[2, 2].hex, c[4, 2].hex]
    end

    # Carreau en PNG. o : 'trait', 'trait_op' (0-100), 'fond', 'fond_op' (0-100), 'ep' (épaisseur en % de l'écartement)
    # Retour : [png, largeur, hauteur] (largeur et hauteur du carreau en unités du motif)
    def self.png(m, o, maxpx = 512)
      tx, ty = carreau(m)
      ref = m['ref']
      ppu = maxpx / [tx, ty].max.to_f
      ppu = [ppu, 160.0 / ref].min if tx / ref < 2 && ty / ref < 2   # motifs très simples : carreau répété plusieurs fois
      rep = [(maxpx / (tx * ppu)).floor, 1].max
      rep2 = [(maxpx / (ty * ppu)).floor, 1].max
      tx *= rep; ty *= rep2
      w = [(tx * ppu).round, 2].max; h = [(ty * ppu).round, 2].max
      sx = w / tx; sy = h / ty
      r = [o['ep'].to_f / 100.0 * ref * (sx + sy) / 2.0 / 2.0, 0.6].max
      cov = Array.new(w * h, 0.0)
      marge = (r + 2) / [sx, sy].min
      m['familles'].each do |f|
        segments(f, -marge, -marge, tx + marge, ty + marge).each do |xa, ya, xb, yb|
          point = (xa - xb).abs < 1e-12 && (ya - yb).abs < 1e-12
          trait(cov, w, h, xa * sx, (ty - ya) * sy, xb * sx, (ty - yb) * sy, point ? [r * 2.2, 1.3].max : r)
        end
      end
      lc = hex(o['trait']); la = o['trait_op'].to_f / 100.0
      fc = hex(o['fond']); fa = o['fond_op'].to_f / 100.0
      lignes = Array.new(h) do |y|
        rang = "\0".b
        w.times do |x|
          c = cov[y * w + x] * la
          a = c + fa * (1 - c)
          if a <= 0
            rang << "\0\0\0\0".b
          else
            px = (0..2).map { |i| ((lc[i] * c + fc[i] * fa * (1 - c)) / a).round.clamp(0, 255) }
            rang << [px[0], px[1], px[2], (a * 255).round].pack('C4')
          end
        end
        rang
      end
      [encoder(w, h, lignes.join), tx, ty]
    end

    # Trait antialiasé : petits disques posés tous les demi-pixels (un point isolé = un disque)
    def self.trait(cov, w, h, xa, ya, xb, yb, r)
      l = Math.hypot(xb - xa, yb - ya)
      n = [(l / 0.5).ceil, 0].max
      (0..n).each do |i|
        t = n.zero? ? 0 : i.to_f / n
        cx = xa + (xb - xa) * t; cy = ya + (yb - ya) * t
        x0 = (cx - r - 1).floor; x1 = (cx + r + 1).ceil
        y0 = (cy - r - 1).floor; y1 = (cy + r + 1).ceil
        next if x1 < 0 || y1 < 0 || x0 >= w || y0 >= h
        (([y0, 0].max)..([y1, h - 1].min)).each do |py|
          ddy = py + 0.5 - cy
          base = py * w
          (([x0, 0].max)..([x1, w - 1].min)).each do |px|
            c = r + 0.5 - Math.hypot(px + 0.5 - cx, ddy)
            next if c <= 0
            c = 1.0 if c > 1
            cov[base + px] = c if c > cov[base + px]
          end
        end
      end
    end

    def self.encoder(w, h, brut)
      ch = ->(t, s) { [s.bytesize].pack('N') + t.b + s + [Zlib.crc32(t.b + s)].pack('N') }
      "\x89PNG\r\n\x1a\n".b + ch.call('IHDR', [w, h, 8, 6, 0, 0, 0].pack('N2C5')) +
        ch.call('IDAT', Zlib::Deflate.deflate(brut)) + ch.call('IEND', ''.b)
    end

    # Fichiers d'une archive .zip : { nom => contenu } (lecture du répertoire central)
    def self.dezipper(data)
      data = data.b
      fin = data.rindex("PK\x05\x06".b) or return {}
      n = data[fin + 10, 2].unpack1('v')
      pos = data[fin + 16, 4].unpack1('V')
      res = {}
      n.times do
        break unless data[pos, 4] == "PK\x01\x02".b
        meth = data[pos + 10, 2].unpack1('v')
        cs = data[pos + 20, 4].unpack1('V')
        ln, lx, lc = data[pos + 28, 6].unpack('v3')
        loc = data[pos + 42, 4].unpack1('V')
        nom = data[pos + 46, ln].force_encoding('UTF-8')
        pos += 46 + ln + lx + lc
        next unless data[loc, 4] == "PK\x03\x04".b
        n2, x2 = data[loc + 26, 4].unpack('v2')
        brut = data[loc + 30 + n2 + x2, cs]
        res[nom] = case meth
                   when 0 then brut
                   when 8 then (Zlib::Inflate.new(-Zlib::MAX_WBITS).inflate(brut) rescue nil)
                   end
      end
      res.compact
    end
  end
end
