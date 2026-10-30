# encoding: UTF-8
# Métré Atelier 2M : percement des ouvertures dans les murs (et les couches de doublage derrière)
require 'sketchup.rb'
require 'json'

module A2M
  module Ouvertures
    TYPES = [
      ['Fenêtre',             'A2M_FENETRE',       100, 125, 215],
      ['Porte-fenêtre / baie', 'A2M_PORTE_FENETRE', 240, 215, 215],
      ['Porte d\'entrée',     'A2M_PORTE_ENTREE',   90, 215, 215],
      ['Ouverture libre (passage sans porte)', nil,  90, 215, 215]
    ]
    @r = {}
    @inverse = false   # sens de Group#subtract vérifié au premier perçage (le mur doit perdre du volume)
    class SensInverse < StandardError; end

    AUTO = '(automatique : la pièce la plus proche)'
    A_CHOISIR = '— à choisir —'
    # Choix des menuiseries extérieures, mêmes codes que le configurateur (rien n'est choisi d'office)
    CHOIX_ME = { 'mat' => [['pvc', "PVC"], ['alu', "Aluminium"], ['bois', "Bois"], ['mixte', "Mixte bois/aluminium"], ['acier', "Acier"]], 'vantaux' => [['1', "1 vantail"], ['2', "2 vantaux"], ['3', "3 vantaux"], ['4', "4 vantaux"]], 'ouvrant' => [['francaise', "Ouvrant à la française"], ['anglaise', "Ouvrant à l'anglaise"], ['oscillo', "Oscillo-battant"], ['abattant', "Abattant"], ['coulissante', "Coulissante"], ['galandage', "Coulissante à galandage"], ['translation', "Coulissante à translation"], ['fixe', "Châssis fixe"], ['guillotine', "Ouvrant à guillotine"], ['basculant', "Ouvrant basculant"], ['pivotant', "Ouvrant pivotant"]], 'vitrage' => [['simple', "Simple vitrage"], ['double', "Double vitrage standard"], ['vir', "Double vitrage VIR"], ['triple', "Triple vitrage"]], 'ferm' => [['vr-manuel', "Volet roulant manuel"], ['vr-motor', "Volet roulant motorisé"], ['vr-solaire', "Volet roulant solaire"], ['vb-pvc', "Volet battant ou coulissant PVC"], ['vb-alu', "Volet battant ou coulissant alu"], ['vb-bois', "Volet battant ou coulissant bois"], ['brise', "Brise-soleil orientable"], ['screen', "Store screen extérieur"], ['banne', "Store banne"]] }

    AUCUN_AS = 'Aucun'
    # Réservation sous l'ouverture (allège abaissée) par défaut : appui sous les fenêtres 5 cm,
    # seuil sous les portes d'entrée et portes-fenêtres 7 cm, rien pour un passage libre
    def self.reservation(tag)
      { 'A2M_FENETRE' => 5, 'A2M_PORTE_FENETRE' => 7, 'A2M_PORTE_ENTREE' => 7 }[tag] || 0
    end
    RES_SIMPLE = 'Réservation simple (panneau balisé)'
    RES_AUCUNE = 'Aucune'
    BIB = 'Bibliothèque : '

    # Choix enregistrés avec un objet de la bibliothèque (codes) : remis en libellés pour la fiche
    def self.libelles(choix)
      res = {}
      (choix || {}).each do |c, v|
        next if c == 'volet'
        x = (CHOIX_ME[c] || []).find { |k, _| k == v }
        res[c] = x[1] if x
      end
      res['ferm'] = 'Aucune' if choix && choix['volet'] == 'non'
      res
    end

    def self.choix_menuiserie(tag, depuis_objet = nil)
      return nil unless %w[A2M_FENETRE A2M_PORTE_FENETRE A2M_PORTE_ENTREE].include?(tag)
      porte = tag == 'A2M_PORTE_ENTREE'
      champs = porte ? %w[mat vantaux] : %w[mat vantaux ouvrant vitrage ferm]
      libs = { 'mat' => 'Matériau', 'vantaux' => 'Nombre de vantaux', 'ouvrant' => 'Type d\'ouvrant', 'vitrage' => 'Vitrage', 'ferm' => 'Fermeture (volet, store…)' }
      prec = depuis_objet ? libelles(depuis_objet) : (@r[:me] || {})
      listes = champs.map { |c| ([A_CHOISIR] + (c == 'ferm' ? ['Aucune'] : []) + CHOIX_ME[c].map(&:last)).join('|') }
      defauts = champs.map { |c| prec[c] || A_CHOISIR }
      rep = UI.inputbox(champs.map { |c| libs[c] }, defauts, listes, depuis_objet ? 'Menuiserie : choix de l\'objet de la bibliothèque (modifiables)' : 'Menuiserie : choix pour le configurateur (facultatif)')
      return {} unless rep
      @r[:me] = Hash[champs.zip(rep)]
      res = {}
      champs.each_with_index do |c, i|
        v = rep[i]
        next if v == A_CHOISIR
        if c == 'ferm'
          res['volet'] = v == 'Aucune' ? 'non' : 'oui'
          code = CHOIX_ME['ferm'].find { |_, l| l == v }
          res['ferm'] = code[0] if code
        else
          code = CHOIX_ME[c].find { |_, l| l == v }
          res[c] = code[0] if code
        end
      end
      res
    end
    # Noms des pièces déjà présentes dans le modèle (groupes balisés A2M_PIECE)
    def self.pieces_du_modele
      noms = []
      fouiller = lambda do |ents, prof|
        ents.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          noms << e.name.to_s.strip if e.layer && e.layer.name == 'A2M_PIECE' && !e.name.to_s.strip.empty?
          fouiller.call(e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities, prof + 1) if prof < 3
        end
      end
      fouiller.call(Sketchup.active_model.entities, 0)
      noms.uniq.sort
    end

    def self.demander
      t = TYPES.find { |x| x[0] == @r[:type] } || TYPES[0]
      g = @r[t[0]] || {}
      objs = (A2M::Bibliotheque.objets_de(TYPES.map { |x| x[1] }.compact) rescue [])
      menus = [RES_SIMPLE, RES_AUCUNE] + objs.map { |o| "#{BIB}#{o['nom']} (#{o['type']})" }
      res0 = { 'Oui' => RES_SIMPLE, 'Non' => RES_AUCUNE }[@r[:res]] || @r[:res]
      res0 = RES_SIMPLE unless menus.include?(res0)
      # Appuis et seuils de la bibliothèque (types « Appui de fenêtre » et « Seuil »)
      aps = (A2M::Bibliotheque.objets.select { |o| o['fichier'] && A2M::Bibliotheque.appui_ou_seuil?(o) } rescue [])
      asl = [AUCUN_AS] + aps.map { |o| "#{o['nom']} (#{o['type']})" }
      rep = UI.inputbox(['Type', 'Largeur (cm)', 'Hauteur (cm)', 'Hauteur sous linteau (cm), depuis le bas du mur cliqué',
                         'Nombre de couches à percer (mur + doublages)', 'Menuiserie posée dans l\'ouverture',
                         'Réservation appui / seuil (cm) : allège abaissée sur les 2 premières couches (fenêtre 5, porte 7)',
                         'Pièce de rattachement', 'Appui ou seuil posé sous l\'ouverture', 'Appui ou seuil : débord sur la façade (cm)'],
                        [t[0], (g[:l] || t[2]).to_s, (g[:h] || t[3]).to_s, (g[:lin] || t[4]).to_s, (g[:n] || @r[:n] || 1).to_s, res0, (g[:appui] || reservation(t[1])).to_s, @r[:piece] || AUTO,
                         asl.include?(g[:as]) ? g[:as] : AUCUN_AS, (g[:debord] || 4).to_s],
                        [TYPES.map(&:first).join('|'), '', '', '', '1|2|3|4', menus.join('|'), '', ([AUTO] + (pcs = pieces_du_modele)).join('|'), asl.join('|'), ''], 'Créer une ouverture (Métré Atelier 2M)')
      return nil unless rep
      type = TYPES.find { |x| x[0] == rep[0] }
      l, h, lin = rep[1..3].map { |v| v.to_s.tr(',', '.').to_f }
      if l <= 0 || h <= 0 || lin < h
        UI.messagebox('Largeur et hauteur supérieures à 0, et hauteur sous linteau au moins égale à la hauteur de l\'ouverture.')
        return nil
      end
      appui = [rep[6].to_s.tr(',', '.').to_f, 0].max
      # Type changé dans la liste : ses propres valeurs par défaut (porte intérieure : pas d'appui, 1 couche)
      if rep[0] != t[0] && !@r[type[0]]
        l, h, lin = type[2].to_f, type[3].to_f, type[4].to_f if rep[1].to_f == t[2] && rep[2].to_f == t[3] && rep[3].to_f == t[4]
        appui = reservation(type[1]) if appui == reservation(t[1])
      end
      @r[:type] = type[0]; @r[:n] = rep[4].to_i; @r[:res] = rep[5]; @r[type[0]] = { l: l, h: h, lin: lin, n: rep[4].to_i, appui: appui }
      piece = rep[7].to_s == AUTO ? nil : rep[7].to_s
      @r[:piece] = rep[7].to_s
      obj = rep[5].start_with?(BIB) ? objs[menus.index(rep[5]) - 2] : nil
      if obj && obj['balise'] != type[1]
        UI.messagebox("« #{obj['nom']} » est rangé comme #{obj['type']} : choisissez ce type d'ouverture, ou un autre objet.")
        return nil
      end
      if obj && type[1].nil?
        UI.messagebox('Une ouverture libre ne reçoit pas de menuiserie.')
        return nil
      end
      pose = rep[5] != RES_AUCUNE
      # Composant dynamique : ses autres réglages (épaisseurs, nombre de vantaux, options…) choisis pour cette ouverture
      opts = obj ? A2M::Bibliotheque.demander_options(obj) : {}
      return nil if opts.nil?
      me = pose ? choix_menuiserie(type[1], obj && obj['choix']) : nil
      as_obj = rep[8] == AUCUN_AS ? nil : aps[asl.index(rep[8]) - 1]
      debord = rep[9].to_s.tr(',', '.').to_f
      @r[type[0]] = (@r[type[0]] || {}).merge(as: rep[8], debord: debord)
      { type: type, l: l, h: h, lin: lin, n: [[rep[4].to_i, 1].max, 4].min, res: pose && type[1], obj: obj, opts: opts, appui: appui, piece: piece, me: me,
        as_obj: as_obj, debord: debord }
    end

    def self.lancer
      p = demander
      Sketchup.active_model.select_tool(Outil.new(p)) if p
    end

    # Groupe (ou composant) de premier niveau qui contient l'élément touché
    def self.haut_de(chemin)
      ents = Sketchup.active_model.active_entities
      chemin.find { |e| (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.parent == (ents.respond_to?(:parent) ? ents.parent : nil) } ||
        chemin.find { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
    end

    # Les n premiers groupes traversés par un rayon partant de l'extérieur, vers l'intérieur du mur
    # Retourne aussi la profondeur percée : du point de départ jusqu'à la sortie de la dernière couche
    # Bornes : pour chaque couche, distances d'entrée et de sortie depuis le départ. Les menuiseries suivies sont traversées sans compter.
    # contigu : on s'arrête dès qu'un vide de plus de 2 cm sépare deux couches (porte intérieure : la cloison seule)
    def self.couches(depart, dir, n, contigu = false)
      model = Sketchup.active_model
      vus = []; pt = depart; parcours = 0.0; fin = 0.0; bornes = {}
      40.times do
        hit = model.raytest([pt, dir])
        break unless hit
        parcours = (hit[0] - depart).dot(dir)
        break if parcours > 3.m
        g = haut_de(hit[1])
        g = nil if g && g.get_attribute('a2m', 'ouv')
        if g.nil?
          pt = hit[0].offset(dir, 0.02)
          next
        end
        if vus.size >= n
          break unless g == vus.last
          fin = parcours
        else
          break if contigu && vus.any? && !vus.include?(g) && parcours - fin > 2.cm
          vus << g unless vus.include?(g)
          fin = parcours if g == vus.last
        end
        (bornes[g] ||= [parcours, parcours])[1] = parcours if vus.include?(g)
        pt = hit[0].offset(dir, 0.02)
      end
      [vus, fin, vus.map { |g| bornes[g] }]
    end

    def self.inverse?() @inverse end
    def self.inverser!() @inverse = !@inverse end

    # Identifiant durable d'un mur (gardé d'une découpe à l'autre, contrairement aux identifiants de SketchUp)
    def self.mur_id(g)
      id = g.get_attribute('a2m', 'mur_id')
      return id if id
      id = "M#{Time.now.to_f.to_s.tr('.', '')}#{rand(1000)}"
      g.set_attribute('a2m', 'mur_id', id)
      id
    end

    def self.attributs(g)
      h = {}
      (g.attribute_dictionary('a2m') || {}).each_pair { |k, v| h[k] = v }
      h
    end

    # Découpe les couches derrière l'ouverture o ; chaque mur percé garde la liste de ses trous (« trous »)
    # Retour : couches (pour reboucher), échecs, profondeur percée, nombre de couches trouvées
    def self.decouper(o, p, id, model)
      cibles, prof, bornes = couches(o[:centre].offset(o[:n], 0.5.cm), o[:n].reverse, p[:n], p[:contigu])
      prof -= 0.5.cm
      return nil if cibles.empty?
      ents = model.active_entities
      u, n, b = o[:u], o[:n], o[:bas]
      l = (p[:l] / 100.0).m; h = (p[:h] / 100.0).m
      c0 = b.offset(n, 5.cm)
      echecs = []; recs = []
      cibles.each_with_index do |g, i|
        # Mur maçonné et isolant (2 premières couches) : allège abaissée pour l'appui ou le seuil ; plaque et couches suivantes : à la cote
        bas_i = i < 2 && p[:appui].to_f > 0 ? c0.offset(Z_AXIS, -(p[:appui] / 100.0).m) : c0
        haut_i = h + (c0.z - bas_i.z)
        rect = [bas_i, bas_i.offset(u, l), bas_i.offset(u, l).offset(Z_AXIS, haut_i), bas_i.offset(Z_AXIS, haut_i)]
        mid = mur_id(g)
        att = attributs(g)
        cut = ents.add_group
        f = cut.entities.add_face(rect)
        f.reverse! if f.normal.dot(n) > 0     # la normale vers l'intérieur du mur
        f.pushpull(3.m)
        nom = g.name; tag = g.layer
        vol = g.volume rescue -1
        bb0 = g.bounds
        res = @inverse ? g.subtract(cut) : cut.subtract(g)
        if res
          # Le mur percé perd du volume et reste dans son encombrement (sinon c'est la boîte de découpe qui a été gardée)
          bb1 = res.bounds
          dehors = bb1.min.x < bb0.min.x - 0.1 || bb1.min.y < bb0.min.y - 0.1 || bb1.min.z < bb0.min.z - 0.1 ||
                   bb1.max.x > bb0.max.x + 0.1 || bb1.max.y > bb0.max.y + 0.1 || bb1.max.z > bb0.max.z + 0.1
          raise SensInverse if dehors || (vol > 0 && (res.volume rescue 0) > vol + 1)
          res.name = nom; res.layer = tag
          att.each { |k, v| res.set_attribute('a2m', k, v) }
          trous = (JSON.parse(att['trous'] || '[]') rescue [])
          res.set_attribute('a2m', 'trous', JSON.generate((trous + [id]).uniq)) if id
          e0, e1 = bornes[i].map { |d| d - 0.5.cm + 5.cm }   # profondeurs d'entrée et de sortie depuis le plan de découpe
          recs << { 'mur' => mid, 'rect' => rect.map(&:to_a), 'n' => n.to_a, 'e0' => e0.to_f, 'e1' => e1.to_f }
        else
          echecs << (nom.to_s.empty? ? 'groupe sans nom' : nom)
          cut.erase! if cut.valid?
        end
      end
      { couches: recs, echecs: echecs, prof: prof, nb: cibles.size }
    end

    # Perce : boîte de découpe (largeur × hauteur, 3 m de profondeur) soustraite de chaque couche ; nom et balise conservés
    def self.percer(o, p, essai = 0)
      model = Sketchup.active_model
      model.start_operation('Créer une ouverture (métré)', true)
      begin
        ents = model.active_entities
        u, n, b = o[:u], o[:n], o[:bas]
        l = (p[:l] / 100.0).m; h = (p[:h] / 100.0).m
        id = "O#{Time.now.to_f.to_s.tr('.', '')}#{rand(1000)}"
        dec = decouper(o, p, p[:res] ? id : nil, model)
        unless dec
          model.abort_operation
          UI.messagebox('Aucun mur trouvé derrière le point cliqué.')
          return
        end
        echecs = dec[:echecs]; prof = dec[:prof]; nb = dec[:nb]
        # Menuiserie de la bibliothèque : étirée à la taille percée (profils inchangés), posée à 5 cm du nu extérieur
        # (porte intérieure : au milieu de l'épaisseur percée)
        if p[:res] && p[:obj]
          ur = Z_AXIS.cross(n).normalize            # de gauche à droite, vu de l'extérieur
          org = u.dot(ur) > 0 ? b : b.offset(u, l)
          r = A2M::Bibliotheque.instance_pour(ents, p[:obj], p[:l], p[:h], org, ur, n.reverse, ->(_ep) { 0 }, model, p[:opts])
          alerte = A2M::Bibliotheque.alerte!
        elsif p[:res]
          # Menuiserie de réservation : un panneau fin balisé, à la taille de l'ouverture, pour l'extraction du métré
          r = ents.add_group
          c1 = b.offset(n.reverse, 5.cm)
          cadre = 5.cm
          ext = [c1, c1.offset(u, l), c1.offset(u, l).offset(Z_AXIS, h), c1.offset(Z_AXIS, h)]
          i0 = c1.offset(u, cadre).offset(Z_AXIS, cadre)
          int = [i0, i0.offset(u, l - 2 * cadre), i0.offset(u, l - 2 * cadre).offset(Z_AXIS, h - 2 * cadre), i0.offset(Z_AXIS, h - 2 * cadre)]
          fr = r.entities.add_face(ext)
          vit = r.entities.add_face(int)
          fr = r.entities.grep(Sketchup::Face).max_by(&:area) if fr.nil? || !fr.valid?
          # Cadre en épaisseur ; vitrage au milieu ; un montant par vantail supplémentaire
          (r.entities.grep(Sketchup::Face).find { |x| x != vit && x.valid? } || fr).pushpull(-7.cm) rescue nil
          nv = ((p[:me] || {})['vantaux'] || '1').to_i
          (1...nv).each do |k|
            x0 = i0.offset(u, (l - 2 * cadre) * k / nv)
            r.entities.add_line(x0, x0.offset(Z_AXIS, h - 2 * cadre))
          end
        end
        if p[:res] && prof > 0
          # Toutes les menuiseries : face intérieure au nu intérieur de la dernière couche percée
          d = r.respond_to?(:definition) ? r.definition : r.entities.parent
          fond = (0..7).map { |i| -((A2M::Bibliotheque.boite_visible(d).corner(i).transform(r.transformation)) - b).dot(n) }.max
          dep = prof - fond
          r.transform!(Geom::Transformation.translation(Geom::Vector3d.new(-n.x * dep, -n.y * dep, 0))) if dep.abs > 0.01
        end
        # Appui ou seuil de la bibliothèque : 1 pièce, ou 2, 3… pièces égales, centrées sous l'ouverture, dessus au bas de la menuiserie
        annexes = p[:as_obj] ? poser_appuis(ents, o, p, model) : []
        if p[:res]
          r.set_attribute('a2m', 'me', JSON.generate(p[:me])) if p[:me] && !p[:me].empty?
          tagm, _ = A2M::Balises.balise(model, p[:type][1], (A2M::Balises::LISTE.find { |x, _, _| x == p[:type][1] } || [])[2])
          r.layer = tagm
          r.name = "#{p[:obj] ? p[:obj]['nom'] : p[:type][0]} #{p[:l].round} × #{p[:h].round}#{p[:piece] ? ' – ' + p[:piece] : ''}"
          # Pièce choisie : gardée sur la menuiserie, l'extraction la rattache à cette pièce
          r.set_attribute('a2m', 'piece', p[:piece]) if p[:piece]
        end
        # Porte intérieure : les revêtements de sol des deux pièces sont prolongés jusqu'à l'axe de l'épaisseur percée
        libre = p[:type][1].nil?
        sols = (p[:type][1] == 'A2M_PORTE_INT' || libre) && prof > 0 ? ajuster_sols(o, p, prof) : []
        # Empreinte de l'ouverture enregistrée ; plinthes des pièces voisines recoupées (portes et passages, pas les fenêtres)
        genre = p[:type][1] == 'A2M_FENETRE' ? 'fenetre' : (libre ? 'libre' : 'porte')
        empreinte = [o[:bas], o[:bas].offset(u, l), o[:bas].offset(u, l).offset(n, -prof), o[:bas].offset(n, -prof)]
        A2M::Plinthes.enregistrer(empreinte, genre, model, p[:res] ? id : nil) if prof > 0
        plin = genre == 'fenetre' ? [] : A2M::Plinthes.regenerer_autour(empreinte)
        # Menuiserie suivie : si elle est déplacée, l'ouverture la suit ; si elle est supprimée, le mur est rebouché
        A2M::Suivi.lier(r, o, p, id, dec[:couches], empreinte, genre, annexes) if p[:res] && r
        model.commit_operation
        msg = "Ouverture #{p[:l].round} × #{p[:h].round} cm percée dans #{nb - echecs.size} couche(s)."
        msg += "\nRevêtements prolongés jusqu'à l'axe de la porte : #{sols.join(', ')}" if sols.any?
        msg += "\nPlinthes recoupées : #{plin.join(', ')}" if plin.any?
        msg += "\n#{alerte}" if alerte
        msg += "\nNon percé (le groupe n'est pas un solide) : #{echecs.join(', ')}" if echecs.any?
        msg += "\nSeulement #{nb} couche(s) trouvée(s) sur #{p[:n]} demandée(s)." if nb < p[:n]
        echecs.any? || nb < p[:n] || plin.any? || alerte ? UI.messagebox(msg) : Sketchup.status_text = msg
      rescue SensInverse
        model.abort_operation
        @inverse = !@inverse
        return percer(o, p, essai + 1) if essai < 1
        UI.messagebox('Le perçage n\'a pas donné le résultat attendu : rien n\'a été modifié.')
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("L'ouverture n'a pas pu être créée (#{ex.message}).")
      end
    end

    def self.poser_appuis(ents, o, p, model)
      obj = p[:as_obj]
      k, lg = A2M::Etirement.decoupe(p[:l], obj['longueurs'] || A2M::Bibliotheque::LONGUEURS[obj['type']] || [p[:l]])
      return [] unless k
      n = o[:n]; u = o[:u]; b = o[:bas]
      ur = Z_AXIS.cross(n).normalize
      l = (p[:l] / 100.0).m
      gauche = u.dot(ur) > 0 ? b : b.offset(u, l)
      h0 = obj['h0'].to_f
      depart = gauche.offset(ur, (l - k * (lg / 100.0).m) / 2.0).offset(Z_AXIS, -h0)
      (0...k).map do |i|
        org = depart.offset(ur, i * (lg / 100.0).m)
        a = A2M::Bibliotheque.instance_pour(ents, obj, lg, h0 * 2.54, org, ur, n.reverse, ->(_e) { -(p[:debord].to_f / 100.0).m }, model, {}, false)
        a.name = "#{obj['nom']} #{lg.round} cm#{k > 1 ? " (#{i + 1}/#{k})" : ''}"
        a.set_attribute('a2m', 'appui_de', p[:type][0])
        a
      end
    end

    # ---- Revêtements de sol (groupes A2M_PIECE) prolongés sous la porte, jusqu'à l'axe de l'épaisseur ----
    def self.pieces_monde
      res = []
      fouiller = lambda do |ents, tr, prof|
        ents.each do |e|
          next unless e.is_a?(Sketchup::Group)
          t2 = tr * e.transformation
          res << [e, t2] if e.layer && e.layer.name == 'A2M_PIECE'
          fouiller.call(e.entities, t2, prof + 1) if prof < 3
        end
      end
      fouiller.call(Sketchup.active_model.entities, Geom::Transformation.new, 0)
      res
    end

    def self.dessus(g)
      hs = g.entities.grep(Sketchup::Face).select { |f| f.normal.z > 0.99 }
      return nil if hs.empty?
      zt = hs.map { |f| f.vertices[0].position.z }.max
      [hs.select { |f| (f.vertices[0].position.z - zt).abs < 0.01 }, zt]
    end

    def self.dedans(px, py, poly)
      d = false; j = poly.size - 1
      poly.each_with_index { |(xi, yi), i| xj, yj = poly[j]; d = !d if ((yi > py) != (yj > py)) && (px < (xj - xi) * (py - yi) / (yj - yi + 1e-12) + xi); j = i }
      d
    end

    # Pièce dont le revêtement est sous le point (plan) et à peu près au niveau du bas de la porte
    def self.piece_sous(pt, zporte)
      pieces_monde.find do |g, tr|
        ds = dessus(g); next false unless ds
        faces, zt = ds
        zw = (tr * Geom::Point3d.new(0, 0, zt)).z
        next false if (zw - zporte).abs > 0.3.m
        faces.any? { |f| dedans(pt.x, pt.y, f.outer_loop.vertices.map { |v| q = tr * v.position; [q.x, q.y] }) }
      end
    end

    # Ajoute la bande sous la porte au revêtement, puis reconstruit le volume d'un seul tenant (surface et linéaire justes)
    def self.prolonger(g, tr, rect_monde)
      inv = tr.inverse
      faces, zt = dessus(g)
      zmin = g.entities.grep(Sketchup::Face).flat_map { |f| f.vertices.map { |v| v.position.z } }.min
      ep = zt - zmin
      loc = rect_monde.map { |q| q2 = q.transform(inv); Geom::Point3d.new(q2.x, q2.y, zt) }
      nf = g.entities.add_face(loc)
      nf.reverse! if nf && nf.normal.z < 0
      # Arêtes de jonction entre faces du dessus coplanaires : effacées pour ne faire qu'une face
      g.entities.grep(Sketchup::Edge).select { |e| e.faces.size == 2 && e.faces.all? { |f| f.normal.z > 0.99 } && (e.start.position.z - zt).abs < 0.01 }.each(&:erase!)
      top = g.entities.grep(Sketchup::Face).select { |f| f.normal.z > 0.99 && (f.vertices[0].position.z - zt).abs < 0.01 }.max_by(&:area)
      ext = top.outer_loop.vertices.map(&:position)
      trous = top.loops.reject(&:outer?).map { |lp| lp.vertices.map(&:position) }
      g.entities.clear!
      f = g.entities.add_face(ext)
      trous.each { |t| h = g.entities.add_face(t); h.erase! if h && h.valid? }
      f = g.entities.grep(Sketchup::Face).max_by(&:area)
      f.reverse! if f.normal.z < 0
      f.pushpull(-ep) if ep > 0.04   # revêtement dessiné en simple face : il reste une face
      true
    end

    def self.ajuster_sols(o, p, prof)
      l = (p[:l] / 100.0).m
      u, n, b = o[:u], o[:n], o[:bas]
      z = b.z
      demi = prof / 2.0
      res = []
      # Côté cliqué : du nu de la cloison jusqu'à l'axe ; côté opposé : de l'axe jusqu'à l'autre nu
      [[0.0, demi, n, 10.cm], [demi, prof, n.reverse, prof + 10.cm]].each do |d0, d1, _cote, sonde|
        centre = b.offset(u, l / 2.0)
        test = sonde == 10.cm ? centre.offset(n, 10.cm) : centre.offset(n, -sonde)
        g, tr = piece_sous(test, z)
        next unless g
        a = b.offset(n, -d0); c = b.offset(n, -d1)
        rect = [a, a.offset(u, l), c.offset(u, l), c]
        begin
          res << g.name if prolonger(g, tr, rect)
        rescue StandardError
          res << "#{g.name} (à reprendre à la main)"
        end
      end
      res
    end

    # Outil : 1) clic sur un point de référence sur la face extérieure du mur ;
    #         2) déplacer la souris le long du mur pour le sens, taper la distance (ou cliquer) : l'ouverture est percée
    class Outil
      def initialize(p) @p = p; @ip = Sketchup::InputPoint.new; @ref = nil end
      def activate() statut end
      def resume(view) statut; view.invalidate end
      def deactivate(view) view.invalidate end
      def statut
        Sketchup.status_text = @ref ? "Déplacez la souris dans le sens voulu le long du mur, tapez la distance depuis le point de référence jusqu'au bord de l'ouverture puis Entrée (ou cliquez). Échap pour recommencer." :
                                      "#{@p[:type][0]} #{@p[:l].round} × #{@p[:h].round} cm#{@p[:piece] ? ' (' + @p[:piece] + ')' : ''}, linteau à #{@p[:lin].round} cm, #{@p[:n]} couche(s), appui #{@p[:appui]} cm : cliquez un point de référence sur la face du mur (un angle, un bord de baie…)."
        Sketchup.vcb_label = 'Distance'
      end

      def onMouseMove(_f, x, y, view)
        @ip.pick(view, x, y)
        if @ref
          v = @ip.position - @ref[:pt]
          d = v.dot(@ref[:u])
          @sens = d >= 0 ? 1 : -1
          @dist = d.abs
          Sketchup.vcb_value = @dist.to_l.to_s
        end
        view.invalidate
      end

      def onLButtonDown(_f, x, y, view)
        if @ref.nil?
          ph = view.pick_helper; ph.do_pick(x, y)
          chemin = ph.path_at(0) || []
          face = @ip.face
          return UI.beep unless face
          n = (@ip.transformation * face.normal).normalize
          return UI.messagebox('Cliquez sur une face verticale du mur.') if n.z.abs > 0.2
          n = Geom::Vector3d.new(n.x, n.y, 0).normalize
          mur = A2M::Ouvertures.haut_de(chemin)
          zbas = mur ? mur.bounds.min.z : @ip.position.z
          @ref = { pt: @ip.position, n: n, u: Z_AXIS.cross(n).normalize, zbas: zbas }
          statut
        else
          poser(@dist || 0)
        end
        view.invalidate
      end

      def onUserText(text, view)
        d = text.to_l rescue nil
        return UI.beep unless d && @ref
        poser(d)
        view.invalidate
      end

      def ouverture(d)
        u = @ref[:u].clone; u.reverse! if (@sens || 1) < 0
        l = (@p[:l] / 100.0).m
        z = @ref[:zbas] + ((@p[:lin] - @p[:h]) / 100.0).m
        depart = @ref[:pt].offset(u, d)
        # Le bord de départ est toujours le plus proche du point de référence ; la base est ramenée sur le plan de la face
        bas = Geom::Point3d.new(depart.x, depart.y, z)
        { bas: bas, u: u, n: @ref[:n], centre: bas.offset(u, l / 2.0).offset(Z_AXIS, (@p[:h] / 200.0).m) }
      end

      def poser(d)
        A2M::Ouvertures.percer(ouverture(d), @p)
        @ref = nil; @dist = nil
        statut
      end

      def onCancel(_r, view) @ref ? (@ref = nil; statut) : Sketchup.active_model.select_tool(nil); view.invalidate end

      def draw(view)
        @ip.draw(view) if @ip.display?
        return unless @ref && @dist
        o = ouverture(@dist)
        l = (@p[:l] / 100.0).m; h = (@p[:h] / 100.0).m
        b = o[:bas].offset(o[:n], 1.mm)
        pts = [b, b.offset(o[:u], l), b.offset(o[:u], l).offset(Z_AXIS, h), b.offset(Z_AXIS, h), b]
        view.line_width = 2; view.drawing_color = 'red'
        view.draw(GL_LINE_STRIP, pts)
        view.line_width = 1; view.drawing_color = 'gray'; view.line_stipple = '-'
        view.draw(GL_LINES, [@ref[:pt], Geom::Point3d.new(b.x, b.y, @ref[:pt].z)])
        view.line_stipple = ''
      end

      def getExtents
        bb = Geom::BoundingBox.new
        bb.add(@ref[:pt]) if @ref
        bb.add(@ip.position) if @ip.valid?
        bb
      end
    end
  end
end
