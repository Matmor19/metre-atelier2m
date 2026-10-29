# encoding: UTF-8
# =============================================================================
#  Métré Atelier 2M : extraction SketchUp vers le configurateur
#  À coller dans la Console Ruby de SketchUp (Fenêtres > Console Ruby), puis Entrée.
#  Produit un fichier .json à importer dans le configurateur
#  (bouton « Importer depuis SketchUp (.json) »).
#
#  Balises (Tags) reconnues : voir la liste BALISES ci-dessous.
#  Rien n'est inventé : un élément sans balise A2M_ n'est pas compté.
# =============================================================================
require 'json'

module A2M
  module Extraction
    VERSION = 1

    # ---- Réglages (laisser nil si vous préférez saisir la valeur dans le configurateur) ----
    HAUTEUR_SOUS_PLAFOND = nil   # m, ex. 2.50 (bloc Plâtrerie et Peinture)
    RIGOLE_LARGEUR       = nil   # m, ex. 0.50 (fouilles en rigoles)
    RIGOLE_HAUTEUR       = nil   # m, ex. 0.60
    DISTANCE_PIECE_MAX   = 1.0   # m : une menuiserie plus loin que ça de toute pièce est signalée

    # ---- Balises ----
    # Murs : un groupe par mur, ou un seul groupe par catégorie contenant tous ses murs (mesurés sur leur dessus).
    # Menuiseries, portes et cloisons (groupe ou composant) : mesurées dans le sens de leur plus longue arête horizontale
    MURS = { 'A2M_MUR_PERI' => 'peri', 'A2M_MUR_SOUB' => 'soub', 'A2M_MUR_REFEND' => 'refend', 'A2M_MUR_PIGNON' => 'pignon' }
    MENUISERIES = { 'A2M_FENETRE' => 'fen', 'A2M_PORTE_FENETRE' => 'pf', 'A2M_PORTE_ENTREE' => 'pe' }
    PORTE_INT = 'A2M_PORTE_INT'
    CLOISON = 'A2M_CLOISON'
    # Doublage des murs périphériques : un groupe pour la plaque de plâtre, un groupe pour l'isolant (facultatif)
    DOUBLAGE = 'A2M_DOUBLAGE'
    ISOLANT_DOUBLAGE = 'A2M_ISOLANT_DOUBLAGE'
    SEMELLE = 'A2M_SEMELLE'
    # Faces : surface (et périmètre pour le terrain et les pièces)
    FACES = %w[A2M_TERRAIN A2M_DECAPAGE A2M_DALLAGE A2M_PLANCHER_ETAGE A2M_PLAFOND A2M_ISOLANT_SOL A2M_CHAPE A2M_ALLEE A2M_PIECE A2M_TOITURE A2M_TOITURE_2 A2M_TOITURE_3 A2M_TOITURE_4]
    # Arêtes (lignes) : linéaire. Faîtage, rive, noue, arêtier et égout sont reconnus tout seuls sur les pans A2M_TOITURE ;
    # ne baliser une ligne à la main que pour forcer un type (elle remplace alors le calcul automatique de ce type).
    LIGNES = %w[A2M_FAITAGE A2M_RIVE A2M_NOUE A2M_ARETIER A2M_EGOUT A2M_RIGOLE A2M_DOUBLAGE A2M_CLOISON
                A2M_CLOTURE A2M_RESEAU_EAU A2M_RESEAU_EU A2M_RESEAU_EP A2M_RESEAU_ELEC]
    ELEC = 'A2M_ELEC'
    PISCINE = 'A2M_PISCINE'
    OBJETS = MURS.keys + MENUISERIES.keys + [PORTE_INT, CLOISON, DOUBLAGE, ISOLANT_DOUBLAGE, SEMELLE, ELEC, PISCINE]

    POUCE2_EN_M2 = 0.0254 * 0.0254

    def self.tag_de(e, herite)
      n = e.layer ? e.layer.name.to_s : ''
      (n.empty? || n == 'Layer0' || n =~ /untagged|sans balise/i) ? herite : n
    end

    def self.nom_de(e)
      n = e.name.to_s.strip
      n = e.definition.name.to_s.strip if n.empty? && e.respond_to?(:definition)
      n
    end

    # Parcourt tout le modèle avec les transformations ; un objet balisé (mur, menuiserie…) ne transmet pas sa balise à son contenu
    def self.parcourir(ents, tr, tag, nom, cont = 0, &bloc)
      ents.each do |e|
        next if e.respond_to?(:hidden?) && e.hidden?
        next if e.respond_to?(:layer) && e.layer && !e.layer.visible?
        t = tag_de(e, tag)
        if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          tr2 = tr * e.transformation
          sous = e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities
          if OBJETS.include?(t)
            bloc.call(:objet, e, tr2, t, nom_de(e), cont)
            parcourir(sous, tr2, nil, nom, e.entityID, &bloc)
          else
            n = nom_de(e)
            parcourir(sous, tr2, t, n.empty? ? nom : n, e.entityID, &bloc)
          end
        elsif e.is_a?(Sketchup::Face)
          bloc.call(:face, e, tr, t, nom, cont)
        elsif e.is_a?(Sketchup::Edge)
          bloc.call(:arete, e, tr, t, nom, cont)
        end
      end
    end

    # Points et arêtes d'un objet, en coordonnées du modèle (mètres)
    def self.geometrie(ents, tr, pts, aretes)
      ents.each do |e|
        if e.is_a?(Sketchup::Group) then geometrie(e.entities, tr * e.transformation, pts, aretes)
        elsif e.is_a?(Sketchup::ComponentInstance) then geometrie(e.definition.entities, tr * e.transformation, pts, aretes)
        elsif e.is_a?(Sketchup::Edge)
          a = tr * e.start.position; b = tr * e.end.position
          pts << a << b; aretes << [a, b]
        end
      end
    end

    # Longueur (sens de la plus longue arête horizontale), épaisseur et hauteur d'un objet, en m
    def self.boite(e, tr)
      pts = []; aretes = []
      geometrie(e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities, tr, pts, aretes)
      return nil if pts.empty?
      horiz = aretes.select { |a, b| (a.z - b.z).abs < 0.5 && a.distance(b) > 0.4 }   # tolérance en pouces
      ref = horiz.max_by { |a, b| a.distance(b) }
      dx, dy = ref ? [ref[1].x - ref[0].x, ref[1].y - ref[0].y] : [1.0, 0.0]
      n = Math.sqrt(dx * dx + dy * dy); n = 1.0 if n.zero?
      ux, uy = dx / n, dy / n
      along = pts.map { |p| p.x * ux + p.y * uy }
      perp  = pts.map { |p| -p.x * uy + p.y * ux }
      zs    = pts.map(&:z)
      { l: (along.max - along.min).to_m, e: (perp.max - perp.min).to_m, h: (zs.max - zs.min).to_m,
        cx: ((pts.map(&:x).max + pts.map(&:x).min) / 2.0).to_m, cy: ((pts.map(&:y).max + pts.map(&:y).min) / 2.0).to_m }
    end

    def self.r2(x) (x.to_f * 100).round / 100.0 end

    # Faces d'un groupe (et de ses sous-groupes), sans les menuiseries ni les autres objets balisés qu'il contient
    def self.faces_de(ents, tr, out)
      ents.each do |e|
        next if e.respond_to?(:hidden?) && e.hidden?
        if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          next if OBJETS.include?(tag_de(e, nil))
          faces_de(e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities, tr * e.transformation, out)
        elsif e.is_a?(Sketchup::Face)
          out << [e, tr]
        end
      end
    end

    # Linéaire (axe du mur) et épaisseur d'un morceau d'empreinte de mur (vue de dessus) :
    #  - morceau en anneau (murs qui font le tour) : linéaire = (contour extérieur + contour intérieur) / 2
    #  - morceau ouvert (refend, pignon, mur isolé) : contour = 2 × linéaire + 2 × épaisseur et surface = linéaire × épaisseur
    def self.empreinte(aire, contour_ext, contour_int)
      if contour_int > 0
        l = (contour_ext + contour_int) / 2.0
      else
        demi = contour_ext / 2.0
        disc = demi * demi - 4.0 * aire
        l = disc > 0 ? (demi + Math.sqrt(disc)) / 2.0 : demi / 2.0
      end
      [l, l > 0 ? aire / l : 0.0]
    end

    # Murs d'un groupe balisé A2M_MUR_… : un seul mur ou tous les murs de la catégorie dans le même groupe.
    # Mesure sur le dessus des murs (les baies ne coupent pas le linéaire) ; pour un pignon, sur le dessous.
    # Une ligne par hauteur de mur trouvée dans le groupe.
    def self.murs_de(e, tr, cat, nom)
      faces = []
      faces_de(e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities, tr, faces)
      return [] if faces.empty?
      zs = faces.flat_map { |f, t| f.vertices.map { |v| (t * v.position).z.to_m } }
      zmin, zmax = zs.min, zs.max
      horiz = faces.map do |f, t|
        nz = (t * f.normal).normalize.z
        next nil if nz.abs < 0.99
        loops = f.loops.map { |lp| lp.edges.sum { |ed| (t * ed.start.position).distance(t * ed.end.position).to_m } }
        z = (t * f.vertices[0].position).z.to_m
        { haut: nz > 0, z: z, aire: f.area(t) * POUCE2_EN_M2, ext: loops[0], int: loops[1..-1].sum }
      end.compact
      dessus = horiz.select { |h| h[:haut] && h[:z] > zmin + 0.05 }
      base = cat == 'pignon' || dessus.empty? ? horiz.select { |h| !h[:haut] && (h[:z] - zmin).abs < 0.02 } : dessus
      parH = Hash.new { |hh, k| hh[k] = { l: 0.0, aire: 0.0 } }
      base.each do |h|
        l, _ep = empreinte(h[:aire], h[:ext], h[:int])
        haut = base.equal?(dessus) ? h[:z] - zmin : zmax - zmin
        k = r2(haut)
        parH[k][:l] += l; parH[k][:aire] += h[:aire]
      end
      parH.select { |_, v| v[:l] > 0.05 }.map do |haut, v|
        { 'cat' => cat, 'nom' => parH.size > 1 ? "#{nom} – hauteur #{haut} m" : nom,
          'longueur' => r2(v[:l]), 'hauteur' => haut, 'epaisseur' => r2(v[:aire] / v[:l]) }
      end
    end

    # Distance (m) d'un point à un polygone 2D (0 si dedans)
    def self.distance_poly(px, py, poly)
      dedans = false
      j = poly.size - 1
      poly.each_with_index do |(xi, yi), i|
        xj, yj = poly[j]
        dedans = !dedans if ((yi > py) != (yj > py)) && (px < (xj - xi) * (py - yi) / (yj - yi + 1e-12) + xi)
        j = i
      end
      return 0.0 if dedans
      poly.each_with_index.map do |(x1, y1), i|
        x2, y2 = poly[(i + 1) % poly.size]
        vx, vy = x2 - x1, y2 - y1
        t = ((px - x1) * vx + (py - y1) * vy) / (vx * vx + vy * vy + 1e-12)
        t = [[t, 0.0].max, 1.0].min
        Math.hypot(px - (x1 + t * vx), py - (y1 + t * vy))
      end.min
    end

    # Classement des bords des pans de toiture (balise A2M_TOITURE…, faces du dessus) :
    #  - bord commun à deux pans : horizontal = faîtage ; incliné = arêtier (saillant) ou noue (rentrant)
    #  - bord d'un seul pan : horizontal en bas = égout ; horizontal en haut = faîtage (monopente) ; incliné = rive
    # Les pans peuvent être dans un même groupe ou dans des groupes séparés : les bords sont rapprochés au centimètre près.
    def self.lignes_toiture(pans)
      res = Hash.new(0.0)
      return res if pans.empty?
      cle = lambda { |a, b| [a, b].map { |q| q.map { |v| (v * 100).round } }.sort }
      # Tous les sommets des pans : un bord est découpé là où un sommet d'un autre pan tombe dessus
      # (ex. faîtage d'une toiture en L, entier d'un côté, en deux morceaux de l'autre)
      sommets = pans.flat_map { |pn| pn[:pts] }.uniq { |q| q.map { |v| (v * 100).round } }
      bords = {}
      pans.each_with_index do |pn, i|
        pts = pn[:pts]
        pts.each_with_index do |a, k|
          b = pts[(k + 1) % pts.size]
          ab = (0..2).map { |j| b[j] - a[j] }
          l2 = ab.sum { |x| x * x }.to_f
          next if l2 < 1e-6
          ts = sommets.map do |q|
            t = (0..2).sum { |j| (q[j] - a[j]) * ab[j] } / l2
            next nil if t <= 1e-4 || t >= 1 - 1e-4
            proj = (0..2).map { |j| a[j] + t * ab[j] }
            Math.sqrt((0..2).sum { |j| (proj[j] - q[j])**2 }) < 0.01 ? t : nil
          end.compact.sort
          coupe = [a] + ts.map { |t| (0..2).map { |j| a[j] + t * ab[j] } } + [b]
          coupe.each_cons(2) do |u, v|
            (bords[cle.call(u, v)] ||= { a: u, b: v, pans: [] })[:pans] << i
          end
        end
      end
      bords.each_value do |bd|
        a, b = bd[:a], bd[:b]
        long = Math.sqrt((0..2).sum { |k| (a[k] - b[k])**2 })
        next if long < 0.01
        horiz = (a[2] - b[2]).abs < 0.02
        ids = bd[:pans].uniq
        if ids.size >= 2
          p1, p2 = pans[ids[0]], pans[ids[1]]
          # Saillant si le centre du pan 1 est sous le plan du pan 2 (normale vers le haut)
          d = (0..2).sum { |k| p2[:n][k] * (p1[:c][k] - p2[:pts][0][k]) }
          if horiz then res[d < 0 ? 'faite' : 'noue'] += long
          else res[d < 0 ? 'arete' : 'noue'] += long end
        else
          pn = pans[ids[0]]
          zs = pn[:pts].map { |q| q[2] }
          if horiz
            z = a[2]
            if (z - zs.min).abs < 0.05 then res['egout'] += long
            elsif (z - zs.max).abs < 0.05 then res['faite'] += long
            else res['rive'] += long end
          else
            res['rive'] += long
          end
        end
      end
      res
    end

    def self.extraire
      m = Sketchup.active_model
      res = { 'format' => 'metre2m-sketchup', 'version' => VERSION, 'modele' => (m.title.to_s.empty? ? 'Sans nom' : m.title),
              'date' => Time.now.strftime('%Y-%m-%d %H:%M'), 'terrain' => {}, 'fond' => {}, 'murs' => [], 'plancher' => {},
              'toiture' => {}, 'toituresSup' => [], 'plat' => {}, 'pieces' => [], 'alertes' => [] }
      surf = Hash.new(0.0); perim = Hash.new(0.0); lin = Hash.new(0.0)
      toits = Hash.new { |h, k| h[k] = { vraie: 0.0, sol: 0.0, pente: 0.0 } }
      pieces = {}; menus = []; portes = []; cloisons = 0.0; pans = []
      sem = { l: 0.0, aire: 0.0, h: 0.0 }; elecs = []; piscines = []
      doub = { plaque: { l: 0.0, aire: 0.0, h: 0.0 }, isolant: { l: 0.0, aire: 0.0, h: 0.0 } }

      # Surfaces horizontales par groupe : dessus et dessous comptés séparément, on garde le plus grand (une dalle n'est comptée qu'une fois)
      hz = Hash.new { |h, k| h[k] = { haut: 0.0, bas: 0.0 } }
      parcourir(m.entities, Geom::Transformation.new, nil, '') do |genre, e, tr, tag, nom, cont|
        next unless tag.to_s.start_with?('A2M_')
        case genre
        when :objet
          b = boite(e, tr)
          next unless b
          if MURS[tag]
            n = nom.to_s.strip.empty? ? { 'peri' => 'Murs périphériques', 'soub' => 'Murs de soubassement', 'refend' => 'Murs de refend', 'pignon' => 'Murs pignons' }[MURS[tag]] : nom
            ms = murs_de(e, tr, MURS[tag], n)
            res['alertes'] << "#{n} : aucune face horizontale trouvée, mur non mesuré" if ms.empty?
            res['murs'].concat(ms)
          elsif MENUISERIES[tag]
            menus << { 'type' => MENUISERIES[tag], 'l' => (b[:l] * 100).round, 'h' => (b[:h] * 100).round, 'x' => b[:cx], 'y' => b[:cy], 'nom' => nom,
                       'piece' => e.get_attribute('a2m', 'piece'), 'choix' => (JSON.parse(e.get_attribute('a2m', 'me', '{}')) rescue {}) }
          elsif tag == PORTE_INT
            portes << { 'l' => (b[:l] * 100).round, 'x' => b[:cx], 'y' => b[:cy], 'piece' => e.get_attribute('a2m', 'piece') }
          elsif tag == CLOISON
            # Cloison : mesurée comme un mur (dessus), même si le groupe contient plusieurs pans ; sinon par sa boîte
            mc = murs_de(e, tr, 'cloison', nom)
            cloisons += mc.empty? ? b[:l] : mc.sum { |x| x['longueur'] }
          elsif tag == ELEC
            # Appareillage : compté par pièce (pièce choisie, sinon la plus proche)
            app = e.get_attribute('a2m', 'app')
            elecs << { 'app' => app, 'x' => b[:cx], 'y' => b[:cy], 'piece' => e.get_attribute('a2m', 'piece') } if app
          elsif tag == PISCINE
            piscines << { 'nom' => nom, 'volume' => (e.manifold? ? e.volume * 0.0254**3 : nil), 'l' => b[:l], 'e' => b[:e] }
          elsif tag == SEMELLE
            # Semelles filantes : linéaire à l'axe, largeur (épaisseur de l'empreinte), hauteur
            murs_de(e, tr, 'semelle', nom).each { |d| sem[:l] += d['longueur']; sem[:aire] += d['longueur'] * d['epaisseur']; sem[:h] = [sem[:h], d['hauteur']].max }
          elsif tag == DOUBLAGE || tag == ISOLANT_DOUBLAGE
            # Mesuré comme un mur : linéaire à l'axe (la face côté pièce pour la plaque), hauteur, épaisseur
            murs_de(e, tr, 'doublage', nom).each do |d|
              cle = tag == DOUBLAGE ? :plaque : :isolant
              doub[cle][:l] += d['longueur']; doub[cle][:aire] += d['longueur'] * d['epaisseur']
              doub[cle][:h] = [doub[cle][:h], d['hauteur']].max
            end
          end
        when :face
          next unless FACES.include?(tag)
          aire = e.area(tr) * POUCE2_EN_M2
          nz = (tr * e.normal).normalize.z rescue e.normal.z
          if tag.start_with?('A2M_TOITURE')
            next if nz.abs < 0.05            # faces verticales (épaisseur, rives) ignorées
            next if nz < 0                    # sous-face ignorée : seul le dessus compte
            t = toits[tag]
            t[:vraie] += aire; t[:sol] += aire * nz.abs
            t[:pente] += aire * Math.tan(Math.acos([nz.abs, 1.0].min)) * 100
            # Contour du pan (coordonnées du modèle, m) pour reconnaître faîtages, rives, noues, arêtiers et égouts
            pts = e.outer_loop.vertices.map { |v| p = tr * v.position; [p.x.to_m, p.y.to_m, p.z.to_m] }
            nv = (tr * e.normal).normalize
            pans << { pts: pts, n: [nv.x, nv.y, nv.z], c: [0, 1, 2].map { |k| pts.sum { |q| q[k] } / pts.size } }
          elsif tag == 'A2M_PIECE'
            next if nz.abs < 0.99            # seule la face horizontale (le sol) compte
            n = nom.to_s.strip; n = 'Pièce sans nom' if n.empty?
            poly = e.outer_loop.vertices.map { |v| p = tr * v.position; [p.x.to_m, p.y.to_m] }
            per = e.outer_loop.edges.sum { |ed| (tr * ed.start.position).distance(tr * ed.end.position).to_m }
            if pieces[n].nil? || aire > pieces[n][:aire]
              pieces[n] = { aire: aire, perim: per, poly: poly }
            end
          elsif tag != 'A2M_TERRAIN'
            next if nz.abs < 0.99
            hz[[tag, cont]][nz > 0 ? :haut : :bas] += aire
          else
            surf[tag] += aire
            perim[tag] += e.outer_loop.edges.sum { |ed| (tr * ed.start.position).distance(tr * ed.end.position).to_m } if tag == 'A2M_TERRAIN'
          end
        when :arete
          next unless LIGNES.include?(tag)
          lin[tag] += (tr * e.start.position).distance(tr * e.end.position).to_m
        end
      end

      hz.each { |(tag, _c), v| surf[tag] += [v[:haut], v[:bas]].max }
      # Terrain, fondations, planchers
      res['terrain']['surface'] = r2(surf['A2M_TERRAIN']) if surf['A2M_TERRAIN'] > 0
      # Périmètre du terrain (sert à la clôture) : la clôture tracée a priorité sur le contour du terrain
      res['terrain']['perimetre'] = r2(lin['A2M_CLOTURE'] > 0 ? lin['A2M_CLOTURE'] : perim['A2M_TERRAIN']) if lin['A2M_CLOTURE'] > 0 || perim['A2M_TERRAIN'] > 0
      { 'resEau' => 'A2M_RESEAU_EAU', 'resEu' => 'A2M_RESEAU_EU', 'resEp' => 'A2M_RESEAU_EP', 'resElec' => 'A2M_RESEAU_ELEC' }.each { |k, t| res['terrain'][k] = r2(lin[t]) if lin[t] > 0 }
      res['terrain']['decap'] = r2(surf['A2M_DECAPAGE']) if surf['A2M_DECAPAGE'] > 0
      # Fouilles en rigoles : semelles A2M_SEMELLE (linéaire, largeur, hauteur), sinon lignes A2M_RIGOLE et réglages du script
      if sem[:l] > 0
        res['fond']['rigLin'] = r2(sem[:l]); res['fond']['rigLarg'] = r2(sem[:aire] / sem[:l]); res['fond']['rigHt'] = r2(sem[:h])
      else
        res['fond']['rigLin'] = r2(lin['A2M_RIGOLE']) if lin['A2M_RIGOLE'] > 0
        res['fond']['rigLarg'] = RIGOLE_LARGEUR if RIGOLE_LARGEUR
        res['fond']['rigHt'] = RIGOLE_HAUTEUR if RIGOLE_HAUTEUR
      end
      res['plancher']['brut'] = r2(surf['A2M_DALLAGE']) if surf['A2M_DALLAGE'] > 0
      res['plancher']['surface'] = r2(surf['A2M_PLANCHER_ETAGE']) if surf['A2M_PLANCHER_ETAGE'] > 0

      # Toitures : surface au sol, surface de couverture (pente comprise), pente moyenne en %
      { 'A2M_TOITURE' => nil, 'A2M_TOITURE_2' => 2, 'A2M_TOITURE_3' => 3, 'A2M_TOITURE_4' => 4 }.each do |tag, num|
        t = toits[tag]
        next unless t[:vraie] > 0
        d = { 'surface' => r2(t[:sol]), 'surfCouv' => r2(t[:vraie]), 'pente' => (t[:pente] / t[:vraie]).round }
        if num then res['toituresSup'] << d.merge('nom' => "Toiture #{num}") else res['toiture'].merge!(d) end
      end
      # Linéaires de toiture : reconnus tout seuls à partir des pans ; une ligne balisée à la main (A2M_FAITAGE…) a priorité pour son type
      auto = lignes_toiture(pans)
      { 'faite' => 'A2M_FAITAGE', 'rive' => 'A2M_RIVE', 'noue' => 'A2M_NOUE', 'arete' => 'A2M_ARETIER', 'egout' => 'A2M_EGOUT' }.each do |k, tag|
        v = lin[tag] > 0 ? lin[tag] : auto[k]
        res['toiture'][k] = r2(v) if v > 0
      end
      res['toitureLignes'] = 'reconnues automatiquement à partir des pans' unless pans.empty?

      # Plâtrerie
      cl = cloisons + lin['A2M_CLOISON']
      res['plat']['cloi_ml'] = r2(cl) if cl > 0
      # Doublage : linéaire et hauteur de la plaque ; épaisseur du doublage donnée pour information (les tableaux ne prennent que la maçonnerie)
      dl = doub[:plaque][:l] > 0 ? doub[:plaque][:l] : lin['A2M_DOUBLAGE']
      res['plat']['doub_ml'] = r2(dl) if dl > 0
      res['plat']['hauteurDoub'] = r2(doub[:plaque][:h]) if doub[:plaque][:h] > 0
      ep = [:plaque, :isolant].sum { |k| doub[k][:l] > 0 ? doub[k][:aire] / doub[k][:l] : 0.0 }
      res['plat']['ep_doublage'] = r2(ep) if ep > 0
      res['plat']['pla_m2'] = r2(surf['A2M_PLAFOND']) if surf['A2M_PLAFOND'] > 0
      # Sans case dans le configurateur : donnés pour information (à reporter au métré)
      res['infos'] = {}
      res['infos']['isolant_sol'] = r2(surf['A2M_ISOLANT_SOL']) if surf['A2M_ISOLANT_SOL'] > 0
      res['infos']['chape'] = r2(surf['A2M_CHAPE']) if surf['A2M_CHAPE'] > 0
      res['infos']['allees'] = r2(surf['A2M_ALLEE']) if surf['A2M_ALLEE'] > 0
      unless piscines.empty?
        res['equip'] = { 'piscine' => 'oui' }
        v = piscines.map { |x| x['volume'] }.compact.sum
        res['infos']['piscine'] = "#{piscines.size} piscine(s)#{v > 0 ? ", volume #{r2(v)} m³" : ''}"
      end
      res['plat']['hauteur'] = HAUTEUR_SOUS_PLAFOND if HAUTEUR_SOUS_PLAFOND

      # Pièces et leurs menuiseries (la plus proche pièce reçoit la menuiserie)
      liste = pieces.map { |n, p| { 'nom' => n, 'surf' => r2(p[:aire]), 'perim' => r2(p[:perim]), 'menus' => [], 'portesInt' => [], poly: p[:poly] } }
      # Pièce indiquée à la création de l'ouverture : prioritaire ; ajoutée à la liste si elle n'y est pas encore
      par_nom = lambda do |n|
        return nil if n.to_s.strip.empty?
        pc = liste.find { |q| q['nom'].downcase == n.to_s.strip.downcase }
        unless pc
          pc = { 'nom' => n.to_s.strip, 'menus' => [], 'portesInt' => [], poly: [] }
          liste << pc
        end
        pc
      end
      proche = lambda do |x, y|
        best = liste.reject { |pc| pc[:poly].empty? }.min_by { |pc| distance_poly(x.to_f, y.to_f, pc[:poly]) }
        best && distance_poly(x.to_f, y.to_f, best[:poly]) <= DISTANCE_PIECE_MAX ? best : nil
      end
      menus.each do |mn|
        pc = par_nom.call(mn['piece']) || proche.call(mn['x'], mn['y'])
        if pc
          ex = pc['menus'].find { |z| z['type'] == mn['type'] && z['l'] == mn['l'] && z['h'] == mn['h'] && z['choix'] == mn['choix'] }
          ex ? ex['nb'] += 1 : pc['menus'] << { 'type' => mn['type'], 'l' => mn['l'], 'h' => mn['h'], 'nb' => 1, 'choix' => mn['choix'] }
        else
          res['alertes'] << "Menuiserie #{mn['nom']} (#{mn['l']} × #{mn['h']} cm) : aucune pièce A2M_PIECE à moins de #{DISTANCE_PIECE_MAX} m"
        end
      end
      portes.each do |pt|
        pc = par_nom.call(pt['piece']) || proche.call(pt['x'], pt['y'])
        if pc
          ex = pc['portesInt'].find { |z| z['l'] == pt['l'] }
          ex ? ex['nb'] += 1 : pc['portesInt'] << { 'l' => pt['l'], 'nb' => 1 }
        else
          res['alertes'] << "Porte intérieure (#{pt['l']} cm) : aucune pièce à moins de #{DISTANCE_PIECE_MAX} m"
        end
      end
      elecs.each do |el|
        pc = par_nom.call(el['piece']) || proche.call(el['x'], el['y'])
        if pc
          pc['app'] ||= Hash.new(0)
          pc['app'][el['app']] += 1
        else
          res['alertes'] << "Appareillage (#{el['app']}) : aucune pièce à moins de #{DISTANCE_PIECE_MAX} m"
        end
      end
      res['pieces'] = liste.map { |pc| pc.reject { |k, _| k == :poly } }
      res['alertes'] << 'Aucune balise A2M_ trouvée dans le modèle.' if res['murs'].empty? && liste.empty? && res['toiture'].empty?
      res
    end

    def self.lancer
      res = extraire
      json = JSON.pretty_generate(res)
      nom = "metre2m_#{res['modele'].gsub(/[^\w\-]+/, '_')}.json"
      chemin = UI.savepanel('Enregistrer l\'extraction pour le configurateur', '', nom)
      if chemin
        chemin += '.json' unless chemin.downcase.end_with?('.json')
        File.write(chemin, json, mode: 'w:UTF-8')
        UI.messagebox("Extraction enregistrée :\n#{chemin}\n\n#{res['murs'].size} mur(s), #{res['pieces'].size} pièce(s)" +
                      (res['alertes'].empty? ? '' : "\n\nÀ vérifier :\n- " + res['alertes'].join("\n- ")))
      end
      puts json
      nil
    end
  end
end

A2M::Extraction.lancer
