# encoding: UTF-8
# Métré Atelier 2M : bibliothèque d'objets (menuiseries, portes, coulissants, plinthes)
# Un objet dessiné (ou une bibliothèque externe éclatée) est « paramétré » : repère remis droit,
# lignes d'étirement au milieu des vitrages ou des panneaux, choix du configurateur.
# À la pose, l'objet est étiré à la largeur et à la hauteur voulues SANS déformer les profils :
# les points situés après une ligne d'étirement glissent, ils ne sont jamais mis à l'échelle.
require 'json'
require 'fileutils'
require 'uri'

module A2M
  # ---- Calcul pur de l'étirement (sans SketchUp : testable seul) ; unités : pouces ----
  module Etirement
    TOL = 0.04          # 1 mm : deux points plus proches sont à la même cote
    MIN_TROU = 1.97     # 5 cm : en dessous, ce n'est pas un vitrage ni un panneau
    MARGE = 0.39        # 1 cm : ce qui doit rester d'un vitrage quand on rétrécit

    # Cotes distinctes, triées
    def self.valeurs(xs)
      res = []
      xs.map(&:to_f).sort.each { |x| res << x if res.empty? || x - res[-1] > TOL }
      res
    end

    # Intervalles sans aucun point entre deux cotes voisines : [début, fin]
    def self.trous(vals)
      vals.each_cons(2).map { |a, b| [a, b] }
    end

    # Lignes proposées : au milieu des n plus grands trous (n = nombre de vantaux),
    # ou de tous les trous au moins moitié aussi grands que le plus grand. Retour : [[position, largeur du trou]]
    def self.lignes_auto(xs, n = nil)
      t = trous(valeurs(xs)).select { |a, b| b - a >= MIN_TROU }
      return [] if t.empty?
      if n && n > 0
        t = t.sort_by { |a, b| -(b - a) }.first(n)
      else
        m = t.map { |a, b| b - a }.max
        t = t.select { |a, b| b - a >= 0.5 * m }
      end
      t.sort.map { |a, b| [(a + b) / 2.0, b - a] }
    end

    # Lignes données par l'utilisateur : on retrouve le trou qui contient chacune (largeur 0 : la ligne traverse un détail)
    def self.lignes_depuis(positions, xs)
      t = trous(valeurs(xs))
      positions.map(&:to_f).sort.map do |s|
        tr = t.find { |a, b| s > a + TOL && s < b - TOL }
        [s, tr ? tr[1] - tr[0] : 0.0]
      end
    end

    # Écart total partagé entre les lignes, au prorata de la largeur de leur trou (vantaux égaux : parts égales)
    def self.deltas(lignes, total)
      return [] if lignes.empty?
      w = lignes.map { |_, l| l.to_f }
      s = w.sum
      s > 0 ? w.map { |x| total * x / s } : w.map { total / lignes.size.to_f }
    end

    # Rétrécir n'est possible que tant qu'il reste au moins 1 cm de chaque vitrage ou panneau
    def self.possible?(lignes, ds)
      lignes.zip(ds).all? { |(_, w), d| d >= 0 || (w > 0 && w + d >= MARGE) }
    end

    # Appui ou seuil pour une ouverture de largeur l (cm), comme le configurateur du métré :
    # la plus petite longueur de la gamme qui couvre ; au-delà de la plus grande, largeur divisée en 2, 3… parts égales
    def self.decoupe(l, longueurs)
      ls = longueurs.map(&:to_f).select { |x| x > 0 }.sort
      return nil if ls.empty?
      k = 1
      k += 1 while l.to_f / k > ls[-1] && k < 20
      [k, ls.find { |x| x >= l.to_f / k - 1e-9 } || ls[-1]]
    end

    # Déplacement d'un point placé à la cote x : somme des écarts des lignes situées avant lui
    def self.decale(x, lignes, ds)
      d = 0.0
      lignes.each_with_index { |(s, _), i| d += ds[i] if x > s }
      d
    end
  end

  module Bibliotheque
    DICO = 'a2m_obj'
    # [libellé, balise du métré, sous-dossier]
    TYPES = [
      ['Fenêtre',                            'A2M_FENETRE',       'Fenetres'],
      ['Porte-fenêtre, baie ou coulissant',  'A2M_PORTE_FENETRE', 'Portes-fenetres'],
      ['Porte d\'entrée',                    'A2M_PORTE_ENTREE',  'Portes d\'entree'],
      ['Porte intérieure de passage',        'A2M_PORTE_INT',     'Portes interieures'],
      ['Appui de fenêtre',                   nil,                 'Appuis'],
      ['Seuil',                              nil,                 'Seuils'],
      ['Façade de placard',                  nil,                 'Placards'],
      ['Plinthe (profil)',                   'A2M_PLINTHE',       'Plinthes'],
      ['Planelle (profil)',                  'A2M_PLANELLE',      'Planelles'],
      ['Mobilier, cuisine, sanitaire',       nil,                 'Mobilier'],
      ['Autre objet (hors métré)',           nil,                 'Divers']
    ]
    NOUVEAU_TYPE = 'Nouveau type…'
    # Gammes de longueurs proposées par défaut (mêmes que le configurateur : gamme Tendance)
    LONGUEURS = { 'Appui de fenêtre' => [40, 50, 60, 70, 80, 90, 100, 105, 110, 120, 130, 140, 150, 160, 170, 180, 190, 200, 210, 220, 230, 240, 250, 280, 300, 360],
                  'Seuil' => [90, 110, 130, 150, 190, 220, 250] }

    def self.appui_ou_seuil?(o) LONGUEURS.key?(o['type'].to_s) || o['longueurs'] end

    def self.fiche_longueurs(o_type, prec = nil)
      def_l = (prec || LONGUEURS[o_type] || []).map { |x| x.to_f % 1 == 0 ? x.to_i : x }.join(' ; ')
      rep = UI.inputbox(["Longueurs disponibles (cm, séparées par ;) : la plus courte qui couvre l'ouverture est posée, en 2, 3… parts égales au-delà de la plus longue"],
                        [def_l], "#{o_type} : longueurs de la gamme")
      return nil unless rep
      rep[0].to_s.split(/[;\s]+/).map { |v| v.tr(',', '.').to_f }.select { |x| x > 0 }.uniq.sort
    end
    DC = 'dynamic_attributes'
    AUCUN = '(aucun : taille fixe)'

    # Types de la liste : ceux d'origine, puis ceux que vous avez ajoutés (types.json du dossier de la bibliothèque)
    def self.types
      f = File.join(dossier, 'types.json')
      persos = File.exist?(f) ? (JSON.parse(File.read(f, encoding: 'UTF-8')) rescue []) : []
      TYPES + persos.map { |n| [n, nil, nom_fichier(n)] }
    end

    def self.ajouter_type(nom)
      f = File.join(dossier, 'types.json')
      persos = File.exist?(f) ? (JSON.parse(File.read(f, encoding: 'UTF-8')) rescue []) : []
      return if persos.include?(nom) || TYPES.any? { |t| t[0] == nom }
      FileUtils.mkdir_p(dossier)
      File.write(f, JSON.pretty_generate(persos + [nom]), encoding: 'UTF-8')
    end
    EXT_VERS_MOI = 'Le côté que je regarde (vue actuelle)'
    EXT_OPPOSE = 'Le côté opposé'

    # ---- Dossier et fiche index.json ----
    def self.dossier
      d = Sketchup.read_default('A2M_Metre', 'dossier_biblio').to_s
      return d unless d.empty?
      base = ENV['USERPROFILE'] || ENV['HOME'] || Dir.home
      doc = File.join(base, 'Documents')
      File.join(File.directory?(doc) ? doc : base, 'Atelier 2M', 'Bibliothèque SketchUp')
    end

    def self.index_chemin() File.join(dossier, 'index.json') end

    def self.objets
      f = index_chemin
      return [] unless File.exist?(f)
      (JSON.parse(File.read(f, encoding: 'UTF-8')) rescue [])
    end

    def self.sauver_index(liste)
      FileUtils.mkdir_p(dossier)
      File.write(index_chemin, JSON.pretty_generate(liste), encoding: 'UTF-8')
    end

    def self.objets_de(balises)
      objets.select { |o| balises.include?(o['balise']) && o['fichier'] && File.exist?(File.join(dossier, o['fichier'])) }
    end

    def self.nom_fichier(nom) nom.to_s.gsub(/[\\\/:*?"<>|]+/, '-').strip[0, 80] end

    # ---- Parcours de la géométrie ----
    # Élément masqué (variante cachée d'un composant dynamique, balise éteinte) : ignoré dans les mesures
    def self.cache?(e)
      (e.respond_to?(:hidden?) && e.hidden?) || (e.respond_to?(:layer) && e.layer && !e.layer.visible?)
    end

    # Encombrement de ce qui se voit seulement (les composants dynamiques gardent des pièces cachées)
    def self.boite_visible(defn)
      bb = Geom::BoundingBox.new
      ajout = lambda do |ents, tr, prof|
        ents.each do |e|
          next if cache?(e)
          case e
          when Sketchup::Edge then bb.add(tr * e.start.position); bb.add(tr * e.end.position)
          when Sketchup::Group then ajout.call(e.entities, tr * e.transformation, prof + 1) if prof < 10
          when Sketchup::ComponentInstance then ajout.call(e.definition.entities, tr * e.transformation, prof + 1) if prof < 10
          end
        end
      end
      ajout.call(defn.entities, Geom::Transformation.new, 0)
      bb.empty? ? defn.bounds : bb
    end

    def self.points(ents, tr, acc)
      ents.each do |e|
        next if cache?(e)
        case e
        when Sketchup::Edge then e.vertices.each { |v| acc << tr * v.position }
        when Sketchup::Group then points(e.entities, tr * e.transformation, acc)
        when Sketchup::ComponentInstance
          b = boite_visible(e.definition)
          8.times { |i| acc << tr * (e.transformation * b.corner(i)) }
        end
      end
      acc
    end

    def self.faces(ents, tr, &blk)
      ents.each do |e|
        if e.is_a?(Sketchup::Face) then blk.call(e, tr)
        elsif e.is_a?(Sketchup::Group) then faces(e.entities, tr * e.transformation, &blk)
        elsif e.is_a?(Sketchup::ComponentInstance) then faces(e.definition.entities, tr * e.transformation, &blk)
        end
      end
    end

    # Sous-composants « grands » (un vantail, un dormant, un profil…) changés en groupes pour être étirés ;
    # les petits (poignée, paumelle, crémone, roulette) restent des composants : ils sont seulement déplacés
    def self.ouvrir_sous_composants(ents, l0, h0)
      ents.grep(Sketchup::ComponentInstance).each do |ci|
        b = ci.bounds
        next unless b.width > 0.2 * l0 || b.depth > 0.2 * h0 || b.height > 0.2 * l0
        g = ents.add_group
        ci2 = g.entities.add_instance(ci.definition, ci.transformation)
        g.layer = ci.layer; g.name = ci.name.to_s.empty? ? ci.definition.name : ci.name
        g.material = ci.material if ci.material
        ci.erase!
        ci2.explode
      end
      ents.grep(Sketchup::Group).each { |g| g.make_unique; ouvrir_sous_composants(g.entities, l0, h0) }
    end

    # Repère de l'objet : X = largeur (de gauche à droite vu de l'extérieur), Y = profondeur (vers l'intérieur), Z = hauteur
    def self.repere(inst, ext_vers_moi, view)
      aires = Hash.new(0.0)
      faces(inst.definition.entities, inst.transformation) do |f, t|
        n = f.normal.transform(t)
        next if n.length < 1e-6
        n.normalize!
        next if n.z.abs > 0.3
        a = Math.atan2(n.y, n.x)
        a += Math::PI if a < 0
        aires[(a * 180 / Math::PI).round % 180] += f.area
      end
      return nil if aires.empty?
      k = aires.max_by { |_, v| v }[0] * Math::PI / 180
      y = Geom::Vector3d.new(Math.cos(k), Math.sin(k), 0)
      cam = view.camera.direction
      y.reverse! if y.dot(Geom::Vector3d.new(cam.x, cam.y, 0)) < 0   # Y s'éloigne de celui qui regarde
      y.reverse! unless ext_vers_moi
      x = y * Z_AXIS
      t0 = Geom::Transformation.axes(ORIGIN, x, y, Z_AXIS)
      pts = points(inst.definition.entities, inst.transformation, []).map { |q| t0.inverse * q }
      o = Geom::Point3d.new(pts.map(&:x).min, pts.map(&:y).min, pts.map(&:z).min)
      Geom::Transformation.axes(o.transform(t0), x, y, Z_AXIS)
    end

    def self.cm(x) (x.to_f * 2.54).round(1) end
    def self.pouces(cm) cm.to_f / 2.54 end
    def self.liste_cm(txt) txt.to_s.split(/[;\s]+/).map { |v| v.tr(',', '.') }.reject(&:empty?).map { |v| pouces(v) } end

    # ---- Commande : paramétrer la sélection, ou tous les objets éclatés d'une balise ----
    def self.parametrer
      model = Sketchup.active_model
      sel = model.selection.to_a
      if sel.empty?
        noms = model.layers.map(&:name).sort
        rep = UI.inputbox(['Balise (calque) où sont les objets éclatés'], [noms.first], [noms.join('|')], 'Paramétrer des objets pour la bibliothèque')
        return unless rep
        lots = regrouper(model, rep[0])
        return UI.messagebox("Aucun objet trouvé sur la balise « #{rep[0]} » (au premier niveau du modèle).") if lots.empty?
        UI.messagebox("#{lots.size} objet(s) trouvé(s) sur « #{rep[0]} ».\nIls vont être présentés un par un : regardez-les de préférence depuis l'extérieur.\nAnnulez une fiche pour arrêter.")
      else
        lots = [sel]
      end
      faits = []
      lots.each do |ents|
        r = parametrer_lot(model, ents)
        break if r.nil?
        faits << r if r.is_a?(String)
      end
      UI.messagebox("Objets rangés dans la bibliothèque :\n" + faits.join("\n") + "\n\nDossier : #{dossier}") if faits.any?
    end

    # Géométrie libre d'une balise : morceaux reliés, puis morceaux dont les boîtes se touchent réunis (dormant + vitrage + poignée…)
    def self.regrouper(model, nom_balise)
      ents = model.active_entities.select { |e| e.layer && e.layer.name == nom_balise && (e.is_a?(Sketchup::Edge) || e.is_a?(Sketchup::Face) || e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) }
      vus = {}; lots = []
      ents.each do |e|
        next if vus[e]
        lot = (e.is_a?(Sketchup::Edge) || e.is_a?(Sketchup::Face)) ? e.all_connected : [e]
        lot.each { |x| vus[x] = true }
        bb = Geom::BoundingBox.new; lot.each { |x| bb.add(x.bounds) }
        lots << [lot, bb]
      end
      touche = lambda do |a, b|
        t = 0.39
        a.min.x <= b.max.x + t && b.min.x <= a.max.x + t && a.min.y <= b.max.y + t && b.min.y <= a.max.y + t && a.min.z <= b.max.z + t && b.min.z <= a.max.z + t
      end
      loop do
        fusion = false
        lots.each_with_index do |(l1, b1), i|
          j = lots.each_index.find { |k| k > i && touche.call(b1, lots[k][1]) }
          next unless j
          l2, b2 = lots.delete_at(j)
          b1.add(b2); l1.concat(l2)
          fusion = true
          break
        end
        break unless fusion
      end
      lots.map(&:first)
    end

    def self.fiche(defaut_nom)
      me = A2M::Ouvertures::CHOIX_ME
      ac = A2M::Ouvertures::A_CHOISIR
      prec = @fiche || {}
      libs = ['Nom de l\'objet', 'Type', 'Face extérieure (vue de la rue, côté pose)', 'Nombre de vantaux (menuiseries)',
              'Matériau', 'Type d\'ouvrant', 'Vitrage', 'Fermeture (volet, store…)']
      defs = [defaut_nom, prec[1] || TYPES[0][0], prec[2] || EXT_VERS_MOI, prec[3] || ac, prec[4] || ac, prec[5] || ac, prec[6] || ac, prec[7] || ac]
      listes = ['', (types.map(&:first) + [NOUVEAU_TYPE]).join('|'), [EXT_VERS_MOI, EXT_OPPOSE].join('|'),
                ([ac] + me['vantaux'].map(&:last)).join('|'), ([ac] + me['mat'].map(&:last)).join('|'),
                ([ac] + me['ouvrant'].map(&:last)).join('|'), ([ac] + me['vitrage'].map(&:last)).join('|'),
                ([ac, 'Aucune'] + me['ferm'].map(&:last)).join('|')]
      rep = UI.inputbox(libs, defs, listes, 'Paramétrer l\'objet sélectionné (bibliothèque Atelier 2M)')
      return nil unless rep
      if rep[1] == NOUVEAU_TYPE
        rn = UI.inputbox(['Nom du nouveau type (ex. : Escalier, Garde-corps, Poêle…)'], [''], 'Nouveau type d\'objet')
        return nil unless rn && !rn[0].to_s.strip.empty?
        ajouter_type(rn[0].to_s.strip)
        rep[1] = rn[0].to_s.strip
      end
      @fiche = rep
      choix = {}
      { 'vantaux' => 3, 'mat' => 4, 'ouvrant' => 5, 'vitrage' => 6 }.each do |c, i|
        code = me[c].find { |_, l| l == rep[i] }
        choix[c] = code[0] if code
      end
      if rep[7] == 'Aucune' then choix['volet'] = 'non'
      elsif (code = me['ferm'].find { |_, l| l == rep[7] }) then choix['volet'] = 'oui'; choix['ferm'] = code[0]
      end
      { nom: rep[0].to_s.strip.empty? ? defaut_nom : rep[0].to_s.strip, type: types.find { |t| t[0] == rep[1] } || TYPES[-1],
        ext: rep[2] == EXT_VERS_MOI, vantaux: (choix['vantaux'] || 0).to_i, choix: choix }
    end

    # Porte intérieure : dimension du vantail de l'objet (repère du métré) et côté des paumelles, vu du côté regardé
    def self.fiche_porte(nom, l0, h0)
      m = nom.to_s.match(/(\d{2,3})\s*[x×X*]\s*(\d{3})/)
      rep = UI.inputbox(['Vantail de cet objet : largeur (cm)', 'Vantail : hauteur (cm)', 'Paumelles, vu du côté que vous regardez (côté poussant)'],
                        [m ? m[1] : cm(l0).round.to_s, m ? m[2] : '204', 'à droite'], ['', '', 'à droite|à gauche'], "#{nom} : porte intérieure")
      return nil unless rep
      { 'vl0' => rep[0].tr(',', '.').to_f, 'vh0' => rep[1].tr(',', '.').to_f, 'paumelles' => rep[2] == 'à gauche' ? 'gauche' : 'droite' }
    end

    # Un objet : retourne son nom (rangé), :passe (laissé de côté) ou nil (arrêt demandé)
    def self.parametrer_lot(model, ents)
      view = model.active_view
      model.selection.clear
      model.selection.add(ents)
      view.zoom(model.selection) rescue nil
      inst0 = ents.size == 1 && (ents[0].is_a?(Sketchup::Group) || ents[0].is_a?(Sketchup::ComponentInstance)) ? ents[0] : nil
      nom0 = inst0 ? (inst0.name.to_s.empty? ? (inst0.respond_to?(:definition) ? inst0.definition.name : 'Objet') : inst0.name) : 'Objet'
      f = fiche(nom0)
      return nil unless f
      return parametrer_plinthe(model, ents, f) if %w[A2M_PLINTHE A2M_PLANELLE].include?(f[:type][1])
      return parametrer_dynamique(model, inst0, f) if inst0.is_a?(Sketchup::ComponentInstance) && dynamique?(inst0)
      model.start_operation('Paramétrer un objet (bibliothèque)', true)
      begin
        g = inst0 || model.active_entities.add_group(ents)
        inst = g.is_a?(Sketchup::Group) ? g.to_component : g
        inst.make_unique if inst.definition.count_instances > 1
        d = inst.definition
        d.attribute_dictionaries.delete('dynamic_attributes') if d.attribute_dictionaries
        inst.attribute_dictionaries.delete('dynamic_attributes') if inst.attribute_dictionaries
        t = repere(inst, f[:ext], view)
        raise 'objet sans face verticale (vitrage, panneau) : impossible de trouver sa face avant' unless t
        # Géométrie remise dans le repère de l'objet : origine en bas, à gauche, devant
        d.entities.transform_entities(t.inverse * inst.transformation, d.entities.to_a)
        inst.transformation = t
        bb = boite_visible(d)
        l0, p0, h0 = bb.width, bb.height, bb.depth
        ouvrir_sous_composants(d.entities, l0, h0)
        pts = points(d.entities, Geom::Transformation.new, [])
        xs = pts.map(&:x); zs = pts.map(&:z)
        lx = A2M::Etirement.lignes_auto(xs, f[:vantaux] > 0 ? f[:vantaux] : nil)
        lz = A2M::Etirement.lignes_auto(zs, nil)
        # Lignes montrées en guides rouges, modifiables
        loop do
          guides = lx.map { |s, _| d.entities.add_cline(Geom::Point3d.new(s, -2, -4), Geom::Point3d.new(s, -2, h0 + 4)) } +
                   lz.map { |s, _| d.entities.add_cline(Geom::Point3d.new(-4, -2, s), Geom::Point3d.new(l0 + 4, -2, s)) }
          view.refresh rescue view.invalidate
          rep = UI.inputbox(["Lignes d'étirement en LARGEUR (cm depuis le bord gauche, séparées par ;)", "Lignes d'étirement en HAUTEUR (cm depuis le bas)"],
                            [lx.map { |s, _| cm(s) }.join(' ; '), lz.map { |s, _| cm(s) }.join(' ; ')], ['', ''],
                            "#{f[:nom]} : #{cm(l0)} × #{cm(h0)} cm, profondeur #{cm(p0)} cm (guides en pointillés)")
          guides.each { |c| c.erase! if c.valid? }
          raise Interrupt unless rep
          nx = A2M::Etirement.lignes_depuis(liste_cm(rep[0]), xs)
          nz = A2M::Etirement.lignes_depuis(liste_cm(rep[1]), zs)
          coupe = (nx + nz).select { |_, w| w <= 0 }
          if nx.empty? && nz.empty?
            next unless UI.messagebox('Aucune ligne d\'étirement : l\'objet gardera toujours sa taille. Continuer ?', MB_YESNO) == IDYES
          elsif coupe.any?
            next unless UI.messagebox("La ou les lignes à #{coupe.map { |s, _| cm(s) }.join(' ; ')} cm traversent un détail : il sera allongé.\nGarder quand même ?", MB_YESNO) == IDYES
          elsif rep[0] == lx.map { |s, _| cm(s) }.join(' ; ') && rep[1] == lz.map { |s, _| cm(s) }.join(' ; ')
            nx, nz = lx, lz
          end
          lx, lz = nx, nz
          break
        end
        balise = f[:type][1]
        info = { 'nom' => f[:nom], 'type' => f[:type][0], 'balise' => balise, 'vantaux' => f[:vantaux], 'choix' => f[:choix],
                 'l0' => l0.to_f, 'h0' => h0.to_f, 'p0' => p0.to_f, 'lx' => lx, 'lz' => lz, 'version' => 1 }
        if balise == 'A2M_PORTE_INT'
          fp = fiche_porte(f[:nom], l0, h0)
          raise Interrupt unless fp
          info.merge!(fp)
        end
        if LONGUEURS.key?(f[:type][0])
          ls = fiche_longueurs(f[:type][0])
          raise Interrupt unless ls
          info['longueurs'] = ls
        end
        info.each { |k, v| d.set_attribute(DICO, k, v.is_a?(Hash) || v.is_a?(Array) ? JSON.generate(v) : v) }
        d.name = model.definitions.unique_name(f[:nom])
        inst.name = f[:nom]
        if balise
          tag, _ = A2M::Balises.balise(model, balise, (A2M::Balises::LISTE.find { |x, _, _| x == balise } || [])[2])
          inst.layer = tag
          inst.set_attribute('a2m', 'me', JSON.generate(f[:choix])) if f[:choix].any?
        end
        model.commit_operation
      rescue Interrupt
        model.abort_operation
        return :passe
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("#{f[:nom]} : paramétrage impossible (#{ex.message}).")
        return :passe
      end
      ranger(d, f[:type], f[:nom], info)
    end

    # Enregistre le composant (.skp) et sa fiche dans le dossier de la bibliothèque
    def self.ranger(d, type, nom, info)
      rel = File.join(type[2], nom_fichier(nom) + '.skp')
      chemin = File.join(dossier, rel)
      liste = objets
      if File.exist?(chemin) || liste.any? { |o| o['nom'] == nom }
        return :passe unless UI.messagebox("« #{nom} » existe déjà dans la bibliothèque. Le remplacer ?", MB_YESNO) == IDYES
        liste.reject! { |o| o['nom'] == nom }
      end
      FileUtils.mkdir_p(File.dirname(chemin))
      d.save_as(chemin)
      d.save_thumbnail(chemin.sub(/\.skp\z/, '.png')) rescue nil
      liste << info.merge('fichier' => rel)
      sauver_index(liste.sort_by { |o| [o['type'].to_s, o['nom'].to_s] })
      return "#{nom} (#{type[0]}, #{cm(info['l0'])} × #{cm(info['h0'])} cm, composant dynamique : #{info['attr_l'] ? 'largeur réglable' : 'largeur fixe'}, #{info['attr_h'] ? 'hauteur réglable' : 'hauteur fixe'})" if info['mode'] == 'dynamique'
      "#{nom} (#{type[0]}, #{cm(info['l0'])} × #{cm(info['h0'])} cm, #{info['lx'].size} ligne(s) en largeur, #{info['lz'].size} en hauteur)"
    end

    # Plinthe : on ne garde que son profil (la section), posé ensuite par l'outil Plinthes
    def self.parametrer_plinthe(model, ents, f)
      face = nil; tr = Geom::Transformation.new
      fv = ents.grep(Sketchup::Face).select { |x| x.normal.z.abs < 0.1 }
      if fv.size == 1
        face = fv[0]
      else
        g = ents.find { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
        cand = []
        if g
          tr = g.transformation
          cand = (g.is_a?(Sketchup::Group) ? g.entities : g.definition.entities).grep(Sketchup::Face)
        else
          cand = ents.grep(Sketchup::Face)
        end
        bb = Geom::BoundingBox.new; ents.each { |e| bb.add(e.bounds) }
        axe = bb.width >= bb.height ? X_AXIS : Y_AXIS   # longueur de la plinthe : la plus grande dimension en plan
        face = cand.select { |x| n = x.normal.transform(tr); n.length > 0 && n.normalize.dot(axe).abs > 0.99 }.max_by(&:area)
      end
      unless face
        UI.messagebox("#{f[:nom]} : sélectionnez la face de la section de la plinthe, ou un morceau de plinthe droit.")
        return :passe
      end
      profil = A2M::Plinthes.profil_depuis(face, tr)
      return :passe unless profil
      h = profil.map(&:last).max; e = profil.map(&:first).max
      liste = objets
      if liste.any? { |o| o['nom'] == f[:nom] }
        return :passe unless UI.messagebox("« #{f[:nom]} » existe déjà dans la bibliothèque. Le remplacer ?", MB_YESNO) == IDYES
        liste.reject! { |o| o['nom'] == f[:nom] }
      end
      liste << { 'nom' => f[:nom], 'type' => f[:type][0], 'balise' => f[:type][1], 'profil' => profil.map { |w, z| [w.to_f, z.to_f] }, 'h0' => h.to_f, 'l0' => e.to_f, 'version' => 1 }
      sauver_index(liste.sort_by { |o| [o['type'].to_s, o['nom'].to_s] })
      "#{f[:nom]} (profil de plinthe #{cm(h)} × #{cm(e)} cm)"
    end

    def self.plinthes() objets.select { |o| o['balise'] == 'A2M_PLINTHE' && o['profil'] } end

    # ---- Composants dynamiques : gardés entiers (réglages, options, animation au clic) ----
    def self.dynamique?(e)
      !!(e.attribute_dictionary(DC) || (e.respond_to?(:definition) && e.definition.attribute_dictionary(DC)))
    end

    def self.attributs_dc(inst)
      h = {}
      [inst.definition, inst].each { |o| (o.attribute_dictionary(DC) || {}).each_pair { |k, v| h[k] = v } }
      h
    end

    # Réglages modifiables par l'utilisateur (fenêtre « Options du composant »), plus lenx / lenz
    def self.reglages_dc(h)
      h.keys.reject { |k| k.start_with?('_') }.sort.map do |k|
        acc = h["_#{k}_access"].to_s
        next nil unless %w[TEXTBOX LIST CHECKBOX].include?(acc) || %w[lenx lenz].include?(k)
        lab = h["_#{k}_formlabel"].to_s
        [k, lab.empty? ? k : lab, h[k]]
      end.compact
    end

    UNITES_LONGUEUR = %w[DEFAULT INCHES FEET MILLIMETERS CENTIMETERS METERS]

    def self.sans_html(t) t.to_s.gsub(/<[^>]*>/, '').gsub('&nbsp;', ' ').strip end

    # Autres réglages du composant (hors largeur et hauteur), lus dans l'objet de la bibliothèque :
    # [clé, libellé, valeur affichée, liste de choix (libellé => valeur) ou nil, réglage de longueur ?]
    def self.options_dc(obj, model = Sketchup.active_model)
      return [] unless obj && obj['mode'] == 'dynamique'
      base = charger(obj, model)
      h = {}
      (base.attribute_dictionary(DC) || {}).each_pair { |k, v| h[k] = v }
      reglages_dc(h).reject { |k, _, _| [obj['attr_l'], obj['attr_h'], 'lenx', 'leny', 'lenz'].include?(k) }.map do |k, lab, v|
        acc = h["_#{k}_access"].to_s
        u = h["_#{k}_units"].to_s
        # Unité « par défaut » : longueur, sauf pour un compte (nombre, quantité…) ou une valeur non numérique
        num = v.is_a?(Numeric) || v.to_s =~ /\A-?\d+(\.\d+)?\z/
        longueur = (UNITES_LONGUEUR.include?(u) && u != 'DEFAULT') || (u == 'DEFAULT' && num && sans_html(lab) !~ /nombre|nb|quantit|compte|count/i)
        choix = nil
        if acc == 'LIST'
          choix = h["_#{k}_options"].to_s.split('&').reject(&:empty?).map { |x| a, b = x.split('=', 2); [(URI.decode_www_form_component(a.to_s) rescue a.to_s), (URI.decode_www_form_component(b.to_s) rescue b.to_s)] }
        elsif acc == 'CHECKBOX'
          choix = [['Oui', 'true'], ['Non', 'false']]
        end
        aff = if choix then (choix.find { |_, val| val.to_s == v.to_s } || [v.to_s])[0]
              elsif longueur then (v.to_f * 2.54).round(2).to_s
              else v.to_s
              end
        [k, sans_html(lab), aff, choix, longueur]
      end
    end

    # Fenêtre des autres réglages : valeurs de l'objet, ou celles de la dernière pose de ce même objet
    def self.demander_options(obj, model = Sketchup.active_model)
      opts = options_dc(obj, model)
      return {} if opts.empty?
      @derniers ||= {}
      prec = @derniers[obj['fichier']] || {}
      libs = opts.map { |_, lab, _, ch, lg| lg ? "#{lab} (cm)" : lab }
      vals = opts.map { |k, _, aff, _, _| prec[k] || aff }
      listes = opts.map { |_, _, _, ch, _| ch ? ch.map(&:first).join('|') : '' }
      rep = UI.inputbox(libs, vals, listes, "#{obj['nom']} : réglages du composant")
      return nil unless rep
      @derniers[obj['fichier']] = Hash[opts.map(&:first).zip(rep)]
      res = {}
      opts.each_with_index do |(k, _, aff, ch, lg), i|
        v = rep[i]
        next if v.to_s == aff.to_s && !prec[k]   # inchangé : le composant garde sa valeur
        res[k] = if ch then (ch.find { |l, _| l == v } || [nil, v])[1]
                 elsif lg then pouces(v.to_s.tr(',', '.').to_f)
                 elsif v.to_s =~ /\A-?\d+([.,]\d+)?\z/ then v.tr(',', '.').to_f
                 else v
                 end
      end
      res
    end
    # Valeur d'un réglage → pouces : réglage de longueur (stocké en pouces), sinon nombre dans une unité devinée
    # en comparant à la taille réelle (cm, mm, m ou pouces)
    def self.facteur(h, k, taille)
      u = h["_#{k}_units"].to_s
      return 1.0 if u.empty? || UNITES_LONGUEUR.include?(u)
      v = h[k].to_s.tr(',', '.').to_f
      return 2.54 if v <= 0 || taille <= 0
      [2.54, 25.4, 0.0254, 1.0].min_by { |f| (v - taille * f).abs / (taille * f) }
    end

    def self.parametrer_dynamique(model, inst, f)
      view = model.active_view
      h = attributs_dc(inst)
      regs = reglages_dc(h)
      b = boite_visible(inst.definition)
      libs = regs.map { |k, l, v| "#{l} (#{k} = #{v})" }
      auto = lambda do |re, defaut|
        r = regs.find { |k, l, _| k != 'lenx' && k != 'lenz' && (l =~ re || k =~ re) } || regs.find { |k, _, _| k == defaut }
        r ? libs[regs.index(r)] : AUCUN
      end
      rep = UI.inputbox(['Réglage du composant qui donne la LARGEUR', 'Réglage du composant qui donne la HAUTEUR'],
                        [auto.call(/larg|width/i, 'lenx'), auto.call(/haut|height/i, 'lenz')],
                        [([AUCUN] + libs).join('|'), ([AUCUN] + libs).join('|')],
                        "#{f[:nom]} : composant dynamique (gardé entier, avec ses options et son animation)")
      return :passe unless rep
      kl = rep[0] == AUCUN ? nil : regs[libs.index(rep[0])][0]
      kh = rep[1] == AUCUN ? nil : regs[libs.index(rep[1])][0]
      fp = f[:type][1] == 'A2M_PORTE_INT' ? fiche_porte(f[:nom], b.width, b.depth) : {}
      return :passe unless fp
      t = repere(inst, f[:ext], view)
      model.start_operation('Paramétrer un composant dynamique (bibliothèque)', true)
      begin
        inst.make_unique if inst.definition.count_instances > 1
        d = inst.definition
        # Les options choisies sur cet exemplaire deviennent celles de l'objet rangé
        (inst.attribute_dictionary(DC) || {}).each_pair { |k, v| d.set_attribute(DC, k, v) }
        ext_y = t && t.yaxis.dot(inst.transformation.yaxis) < 0 ? 'max' : 'min'
        balise = f[:type][1]
        info = { 'nom' => f[:nom], 'type' => f[:type][0], 'balise' => balise, 'mode' => 'dynamique', 'vantaux' => f[:vantaux], 'choix' => f[:choix],
                 'attr_l' => kl, 'attr_h' => kh, 'f_l' => kl && facteur(h, kl, b.width), 'f_h' => kh && facteur(h, kh, b.depth),
                 'u_l' => kl && h["_#{kl}_units"], 'u_h' => kh && h["_#{kh}_units"], 'ext_y' => ext_y,
                 'l0' => b.width.to_f, 'h0' => b.depth.to_f, 'p0' => b.height.to_f, 'version' => 2 }.merge(fp)
        d.set_attribute(DICO, 'info', JSON.generate(info))
        inst.name = f[:nom] if inst.name.to_s.empty?
        if balise
          tag, _ = A2M::Balises.balise(model, balise, (A2M::Balises::LISTE.find { |x, _, _| x == balise } || [])[2])
          inst.layer = tag
          inst.set_attribute('a2m', 'me', JSON.generate(f[:choix])) if f[:choix].any?
        end
        model.commit_operation
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("#{f[:nom]} : paramétrage impossible (#{ex.message}).")
        return :passe
      end
      ranger(d, f[:type], f[:nom], info)
    end

    def self.charger(obj, model)
      base = model.definitions.find { |d| d.get_attribute(DICO, 'source') == obj['fichier'] }
      return base if base
      base = model.definitions.load(File.join(dossier, obj['fichier']))
      base.set_attribute(DICO, 'source', obj['fichier'])
      base
    end

    # Inscrit la largeur et la hauteur dans les réglages du composant puis le fait se redessiner (comme dans « Options du composant »)
    def self.regler_dc(inst, obj, l_cm, h_cm)
      [['attr_l', 'f_l', 'u_l', l_cm], ['attr_h', 'f_h', 'u_h', h_cm]].each do |ka, kf, ku, v|
        k = obj[ka]; next unless k
        val = pouces(v) * (obj[kf] || 1.0).to_f
        val = val.round if obj[ku] == 'INTEGER'
        val = val.round(2).to_s if obj[ku] == 'STRING'
        inst.set_attribute(DC, k, val)
      end
      return false unless defined?($dc_observers) && $dc_observers
      dc = $dc_observers.get_latest_class
      begin
        dc.redraw(inst, false)
      rescue ArgumentError, NoMethodError
        dc.redraw_with_undo(inst)
      end
      true
    rescue StandardError
      false
    end

    # Place un exemplaire : face extérieure de l'objet sur le plan voulu (recul depuis le nu), de gauche à droite vu de l'extérieur
    def self.placer(inst, org, ur, nrev, recul, ext_y)
      b = boite_visible(inst.definition)
      o = org.offset(nrev, recul)
      inst.transformation = if ext_y == 'max'
        Geom::Transformation.axes(o.offset(ur, b.width), ur.reverse, nrev.reverse, Z_AXIS) * Geom::Transformation.translation(Geom::Vector3d.new(-b.min.x, -b.max.y, -b.min.z))
      else
        Geom::Transformation.axes(o, ur, nrev, Z_AXIS) * Geom::Transformation.translation(Geom::Vector3d.new(-b.min.x, -b.min.y, -b.min.z))
      end
    end

    # Exemplaire à la taille voulue : composant dynamique réglé, ou objet étiré. recul : bloc qui reçoit la profondeur de l'objet
    # ajuster : l'encombrement visible doit faire la taille de l'ouverture (menuiseries extérieures) ;
    # sans ajustement, l_cm et h_cm sont les cotes données au composant (porte intérieure : son vantail)
    def self.instance_pour(ents, obj, l_cm, h_cm, org, ur, nrev, recul, model = Sketchup.active_model, opts = {}, ajuster = true)
      dyn = obj['mode'] == 'dynamique'
      if dyn
        inst = ents.add_instance(charger(obj, model), Geom::Transformation.new)
        (opts || {}).each { |k, v| inst.set_attribute(DC, k, v) }   # épaisseurs, nombre de vantaux… choisis à la pose
        unless regler_dc(inst, obj, l_cm, h_cm)
          @alerte = "#{obj['nom']} : l'extension Composants dynamiques n'a pas répondu, l'objet garde sa taille d'origine."
        end
      else
        inst = ents.add_instance(definition_etiree(obj, l_cm, h_cm, model), Geom::Transformation.new)
      end
      # Contrôle de la taille réelle : un objet qui dépasse (seuil, rejingot ou formule comprise dans le composant)
      # est réglé à nouveau pour faire exactement la largeur et la hauteur de l'ouverture
      cl, ch = l_cm.to_f, h_cm.to_f
      (ajuster ? 2 : 0).times do
        b = boite_visible(inst.definition)
        el = b.width.to_f * 2.54 - l_cm.to_f; eh = b.depth.to_f * 2.54 - h_cm.to_f
        # Écart trop grand : ce n'est pas un dépassement (seuil, rejingot) mais un objet mal mesuré : on n'y touche pas
        break if el.abs > 0.25 * l_cm.to_f || eh.abs > 0.25 * h_cm.to_f
        el = 0 if dyn && !obj['attr_l'] || !dyn && (obj['lx'] || []).empty?
        eh = 0 if dyn && !obj['attr_h'] || !dyn && (obj['lz'] || []).empty?
        break if el.abs < 0.2 && eh.abs < 0.2
        cl -= el; ch -= eh
        if dyn then regler_dc(inst, obj, cl, ch)
        else inst.definition = definition_etiree(obj, cl, ch, model)
        end
      end
      b = boite_visible(inst.definition)
      ecart = [b.width.to_f * 2.54 - l_cm.to_f, b.depth.to_f * 2.54 - h_cm.to_f]
      @alerte = [@alerte, "#{obj['nom']} : taille obtenue #{(b.width.to_f * 2.54).round(1)} × #{(b.depth.to_f * 2.54).round(1)} cm au lieu de #{l_cm.round(1)} × #{h_cm.round(1)} cm."].compact.join("\n") if ajuster && ecart.any? { |e| e.abs >= 0.2 }
      placer(inst, org, ur, nrev, recul.call(b.height), obj['ext_y'] || 'min')
      inst
    end

    def self.alerte!() a = @alerte; @alerte = nil; a end

    # ---- Étirement : définition à la taille voulue (réutilisée si elle existe déjà dans le modèle) ----
    def self.definition_etiree(obj, l_cm, h_cm, model = Sketchup.active_model)
      chemin = File.join(dossier, obj['fichier'])
      l = pouces(l_cm); h = pouces(h_cm)
      cle = "v2|#{obj['fichier']}|#{l_cm.round(1)}|#{h_cm.round(1)}"
      deja = model.definitions.find { |d| d.get_attribute(DICO, 'cle') == cle }
      return deja if deja
      base = charger(obj, model)
      lx = obj['lx'] || []; lz = obj['lz'] || []
      dx = A2M::Etirement.deltas(lx, l - obj['l0'].to_f)
      dz = A2M::Etirement.deltas(lz, h - obj['h0'].to_f)
      raise "#{obj['nom']} ne peut pas descendre à #{l_cm.round} × #{h_cm.round} cm (vitrages trop petits)" unless A2M::Etirement.possible?(lx, dx) && A2M::Etirement.possible?(lz, dz)
      if lx.empty? && (l - obj['l0'].to_f).abs > 0.4 || lz.empty? && (h - obj['h0'].to_f).abs > 0.4
        raise "#{obj['nom']} n'a pas de ligne d'étirement dans ce sens : il garde #{cm(obj['l0'])} × #{cm(obj['h0'])} cm"
      end
      nd = model.definitions.add("#{obj['nom']} #{l_cm.round} × #{h_cm.round}")
      i = nd.entities.add_instance(base, Geom::Transformation.new)
      i.explode
      etirer(nd.entities, Geom::Transformation.new, lx, dx, lz, dz)
      (base.attribute_dictionary(DICO) || {}).each_pair { |k, v| nd.set_attribute(DICO, k, v) }
      nd.set_attribute(DICO, 'cle', cle)
      nd.delete_attribute(DICO, 'source')
      nd
    end

    # Glisse les points (jamais d'agrandissement) ; groupes étirés à l'intérieur, composants (quincaillerie) déplacés en bloc
    def self.etirer(ents, tr, lx, dx, lz, dz)
      vec = ->(q) { Geom::Vector3d.new(A2M::Etirement.decale(q.x, lx, dx), 0, A2M::Etirement.decale(q.z, lz, dz)) }
      ents.grep(Sketchup::Group).each do |g|
        g.make_unique
        etirer(g.entities, tr * g.transformation, lx, dx, lz, dz)
      end
      # Arcs et courbes décomposés en simples arêtes : SketchUp (2027) recalcule une courbe dont on déplace les points
      # et la déforme ; décomposée, la géométrie glisse proprement
      ents.grep(Sketchup::Edge).each { |e| e.explode_curve if e.valid? && e.curve }
      ents.grep(Sketchup::ComponentInstance).each do |ci|
        c = tr * ci.bounds.center
        v = vec.call(c).transform(tr.inverse)
        ents.transform_entities(Geom::Transformation.translation(v), ci) if v.length > 0
      end
      vs = ents.grep(Sketchup::Edge).flat_map(&:vertices).uniq
      return if vs.empty?
      vecs = vs.map { |v| vec.call(tr * v.position).transform(tr.inverse) }
      ents.transform_by_vectors(vs, vecs) if vecs.any? { |v| v.length > 0 }
      ents.grep(Sketchup::ConstructionPoint).each(&:erase!)
    end

    # ---- Commande : la bibliothèque (poser un objet hors d'un mur, ouvrir ou changer le dossier) ----
    def self.gerer
      liste = objets
      actions = ['Poser un objet à la taille voulue', 'Longueurs d\'un appui ou d\'un seuil (gamme)', 'Ouvrir le dossier de la bibliothèque', 'Changer de dossier']
      rep = UI.inputbox(['Que faire ?'], [actions[0]], [actions.join('|')], "Bibliothèque d'objets : #{liste.size} objet(s)")
      return unless rep
      case rep[0]
      when actions[1]
        regler_longueurs(liste)
      when actions[2]
        FileUtils.mkdir_p(dossier)
        UI.openURL('file:///' + dossier.tr('\\', '/'))
      when actions[3]
        d = UI.select_directory(title: 'Dossier de la bibliothèque d\'objets', directory: File.directory?(dossier) ? dossier : nil)
        if d
          Sketchup.write_default('A2M_Metre', 'dossier_biblio', d)
          UI.messagebox("Bibliothèque : #{d}\n#{objets.size} objet(s) trouvé(s).")
        end
      else
        poser_libre(liste)
      end
    end

    # Gamme de longueurs d'un appui ou d'un seuil déjà rangé
    def self.regler_longueurs(liste)
      as = liste.select { |o| o['fichier'] && appui_ou_seuil?(o) }
      return UI.messagebox('Aucun appui ni seuil dans la bibliothèque (types « Appui de fenêtre » ou « Seuil »).') if as.empty?
      noms = as.map { |o| "#{o['nom']} (#{o['type']})" }
      rep = UI.inputbox(['Appui ou seuil'], [noms[0]], [noms.join('|')], 'Longueurs de la gamme')
      return unless rep
      o = as[noms.index(rep[0])]
      ls = fiche_longueurs(o['type'], o['longueurs'])
      return unless ls
      l2 = objets.map { |x| x['nom'] == o['nom'] ? x.merge('longueurs' => ls) : x }
      sauver_index(l2)
      UI.messagebox("#{o['nom']} : #{ls.size} longueur(s) enregistrée(s).")
    end

    def self.poser_libre(liste)
      etir = liste.select { |o| o['fichier'] }
      return UI.messagebox("La bibliothèque est vide.\nParamétrez d'abord un objet : sélectionnez-le puis « Paramétrer un objet pour la bibliothèque ».") if etir.empty?
      noms = etir.map { |o| "#{o['type']} – #{o['nom']}" }
      o0 = etir[0]
      rep = UI.inputbox(['Objet', 'Largeur (cm)', 'Hauteur (cm)'], [noms[0], cm(o0['l0']).to_s, cm(o0['h0']).to_s], [noms.join('|'), '', ''], 'Poser un objet de la bibliothèque')
      return unless rep
      obj = etir[noms.index(rep[0])]
      l, h = rep[1].tr(',', '.').to_f, rep[2].tr(',', '.').to_f
      # Objet changé dans la liste sans toucher aux cotes : il garde sa propre taille
      l, h = cm(obj['l0']), cm(obj['h0']) if obj != o0 && l == cm(o0['l0']) && h == cm(o0['h0'])
      model = Sketchup.active_model
      model.start_operation('Poser un objet de la bibliothèque', true)
      begin
        opts = demander_options(obj, model)
        raise Interrupt if opts.nil?
        inst = instance_pour(model.active_entities, obj, l, h, ORIGIN, X_AXIS, Y_AXIS, ->(_ep) { 0 }, model, opts)
        model.commit_operation
        a = alerte!
        UI.messagebox(a) if a
        # L'objet est posé à l'origine et sélectionné : l'outil Déplacer le met où vous voulez
        model.selection.clear
        model.selection.add(inst)
        Sketchup.send_action('selectMoveTool:')
      rescue Interrupt
        model.abort_operation
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox(ex.message)
      end
    end
  end
end
