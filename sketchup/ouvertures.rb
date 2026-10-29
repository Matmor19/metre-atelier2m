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
      ['Porte intérieure (cloison ou refend)', 'A2M_PORTE_INT', 83, 204, 204],
      ['Ouverture libre (passage sans porte)', nil,  90, 215, 215]
    ]
    @r = {}
    @inverse = false   # sens de Group#subtract vérifié au premier perçage (le mur doit perdre du volume)
    class SensInverse < StandardError; end

    AUTO = '(automatique : la pièce la plus proche)'
    A_CHOISIR = '— à choisir —'
    # Choix des menuiseries extérieures, mêmes codes que le configurateur (rien n'est choisi d'office)
    CHOIX_ME = { 'mat' => [['pvc', "PVC"], ['alu', "Aluminium"], ['bois', "Bois"], ['mixte', "Mixte bois/aluminium"], ['acier', "Acier"]], 'vantaux' => [['1', "1 vantail"], ['2', "2 vantaux"], ['3', "3 vantaux"], ['4', "4 vantaux"]], 'ouvrant' => [['francaise', "Ouvrant à la française"], ['anglaise', "Ouvrant à l'anglaise"], ['oscillo', "Oscillo-battant"], ['abattant', "Abattant"], ['coulissante', "Coulissante"], ['galandage', "Coulissante à galandage"], ['translation', "Coulissante à translation"], ['fixe', "Châssis fixe"], ['guillotine', "Ouvrant à guillotine"], ['basculant', "Ouvrant basculant"], ['pivotant', "Ouvrant pivotant"]], 'vitrage' => [['simple', "Simple vitrage"], ['double', "Double vitrage standard"], ['vir', "Double vitrage VIR"], ['triple', "Triple vitrage"]], 'ferm' => [['vr-manuel', "Volet roulant manuel"], ['vr-motor', "Volet roulant motorisé"], ['vr-solaire', "Volet roulant solaire"], ['vb-pvc', "Volet battant ou coulissant PVC"], ['vb-alu', "Volet battant ou coulissant alu"], ['vb-bois', "Volet battant ou coulissant bois"], ['brise', "Brise-soleil orientable"], ['screen', "Store screen extérieur"], ['banne', "Store banne"]] }

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
      rep = UI.inputbox(['Type', 'Largeur (cm)', 'Hauteur (cm)', 'Hauteur sous linteau (cm), depuis le bas du mur cliqué',
                         'Nombre de couches à percer (mur + doublages)', 'Menuiserie posée dans l\'ouverture',
                         'Appui / seuil : allège abaissée de (cm) sur les 2 premières couches',
                         'Pièce de rattachement'],
                        [t[0], (g[:l] || t[2]).to_s, (g[:h] || t[3]).to_s, (g[:lin] || t[4]).to_s, (g[:n] || @r[:n] || 1).to_s, res0, (g[:appui] || (t[1] == 'A2M_PORTE_INT' ? 0 : 5)).to_s, @r[:piece] || AUTO],
                        [TYPES.map(&:first).join('|'), '', '', '', '1|2|3|4', menus.join('|'), '', ([AUTO] + (pcs = pieces_du_modele)).join('|')], 'Créer une ouverture (Métré Atelier 2M)')
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
        appui = 0 if type[1] == 'A2M_PORTE_INT' && appui == 5
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
      me = pose ? choix_menuiserie(type[1], obj && obj['choix']) : nil
      { type: type, l: l, h: h, lin: lin, n: [[rep[4].to_i, 1].max, 4].min, res: pose && type[1], obj: obj, appui: appui, piece: piece, me: me }
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
    def self.couches(depart, dir, n)
      model = Sketchup.active_model
      vus = []; pt = depart; parcours = 0.0; fin = 0.0
      40.times do
        hit = model.raytest([pt, dir])
        break unless hit
        parcours += pt.distance(hit[0])
        break if parcours > 3.m
        g = haut_de(hit[1])
        if vus.size >= n
          break unless g == vus.last
          fin = parcours
        else
          vus << g if g && !vus.include?(g)
          fin = parcours if g == vus.last
        end
        pt = hit[0].offset(dir, 0.02)
        parcours += 0.02
      end
      [vus, fin]
    end

    # Perce : boîte de découpe (largeur × hauteur, 3 m de profondeur) soustraite de chaque couche ; nom et balise conservés
    def self.percer(o, p, essai = 0)
      model = Sketchup.active_model
      cibles, prof = couches(o[:centre].offset(o[:n], 0.5.cm), o[:n].reverse, p[:n])
      prof -= 0.5.cm
      if cibles.empty?
        UI.messagebox('Aucun mur trouvé derrière le point cliqué.')
        return
      end
      model.start_operation('Créer une ouverture (métré)', true)
      begin
        ents = model.active_entities
        u, n, b = o[:u], o[:n], o[:bas]
        l = (p[:l] / 100.0).m; h = (p[:h] / 100.0).m
        c0 = b.offset(n, 5.cm)
        echecs = []
        cibles.each_with_index do |g, i|
          # Mur maçonné et isolant (2 premières couches) : allège abaissée pour l'appui ou le seuil ; plaque et couches suivantes : à la cote
          bas_i = i < 2 && p[:appui].to_f > 0 ? c0.offset(Z_AXIS, -(p[:appui] / 100.0).m) : c0
          haut_i = h + (c0.z - bas_i.z)
          rect = [bas_i, bas_i.offset(u, l), bas_i.offset(u, l).offset(Z_AXIS, haut_i), bas_i.offset(Z_AXIS, haut_i)]
          cut = ents.add_group
          f = cut.entities.add_face(rect)
          f.reverse! if f.normal.dot(n) > 0     # la normale vers l'intérieur du mur
          f.pushpull(3.m)
          nom = g.name; tag = g.layer
          vol = g.volume rescue -1
          res = @inverse ? g.subtract(cut) : cut.subtract(g)
          if res
            raise SensInverse if vol > 0 && (res.volume rescue 0) > vol + 1
            res.name = nom; res.layer = tag
          else
            echecs << (nom.to_s.empty? ? 'groupe sans nom' : nom)
            cut.erase! if cut.valid?
          end
        end
        # Menuiserie de la bibliothèque : étirée à la taille percée (profils inchangés), posée à 5 cm du nu extérieur
        # (porte intérieure : au milieu de l'épaisseur percée)
        if p[:res] && p[:obj]
          nd = A2M::Bibliotheque.definition_etiree(p[:obj], p[:l], p[:h], model)
          ur = Z_AXIS.cross(n).normalize            # de gauche à droite, vu de l'extérieur
          org = u.dot(ur) > 0 ? b : b.offset(u, l)
          ep = nd.bounds.height
          recul = p[:type][1] == 'A2M_PORTE_INT' && prof > 0 ? [(prof - ep) / 2.0, 0].max : 5.cm
          r = ents.add_instance(nd, Geom::Transformation.axes(org.offset(n.reverse, recul), ur, n.reverse, Z_AXIS))
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
        A2M::Plinthes.enregistrer(empreinte, genre, model) if prof > 0
        plin = genre == 'fenetre' ? [] : A2M::Plinthes.regenerer_autour(empreinte)
        model.commit_operation
        msg = "Ouverture" #{p[:l].round} × #{p[:h].round} cm percée dans #{cibles.size - echecs.size} couche(s)."
        msg += "\nRevêtements prolongés jusqu'à l'axe de la porte : #{sols.join(', ')}" if sols.any?
        msg += "\nPlinthes recoupées : #{plin.join(', ')}" if plin.any?
        msg += "\nNon percé (le groupe n'est pas un solide) : #{echecs.join(', ')}" if echecs.any?
        msg += "\nSeulement #{cibles.size} couche(s) trouvée(s) sur #{p[:n]} demandée(s)." if cibles.size < p[:n]
        echecs.any? || cibles.size < p[:n] || plin.any? ? UI.messagebox(msg) : Sketchup.status_text = msg
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
