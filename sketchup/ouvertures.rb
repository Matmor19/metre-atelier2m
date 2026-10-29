# encoding: UTF-8
# Métré Atelier 2M : percement des ouvertures dans les murs (et les couches de doublage derrière)
require 'sketchup.rb'

module A2M
  module Ouvertures
    TYPES = [
      ['Fenêtre',             'A2M_FENETRE',       100, 125, 215],
      ['Porte-fenêtre / baie', 'A2M_PORTE_FENETRE', 240, 215, 215],
      ['Porte d\'entrée',     'A2M_PORTE_ENTREE',   90, 215, 215],
      ['Porte intérieure (cloison ou refend)', 'A2M_PORTE_INT', 83, 204, 204],
      ['Ouverture seule (sans menuiserie)', nil,     90, 215, 215]
    ]
    @r = {}
    @inverse = false   # sens de Group#subtract vérifié au premier perçage (le mur doit perdre du volume)
    class SensInverse < StandardError; end

    AUTO = '(automatique : la pièce la plus proche)'
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
      rep = UI.inputbox(['Type', 'Largeur (cm)', 'Hauteur (cm)', 'Hauteur sous linteau (cm), depuis le bas du mur cliqué',
                         'Nombre de couches à percer (mur + doublages)', 'Poser une menuiserie de réservation balisée ?',
                         'Appui / seuil : allège abaissée de (cm) sur les 2 premières couches',
                         'Pièce de rattachement'],
                        [t[0], (g[:l] || t[2]).to_s, (g[:h] || t[3]).to_s, (g[:lin] || t[4]).to_s, (g[:n] || @r[:n] || 1).to_s, @r[:res] || 'Oui', (g[:appui] || (t[1] == 'A2M_PORTE_INT' ? 0 : 5)).to_s, @r[:piece] || AUTO],
                        [TYPES.map(&:first).join('|'), '', '', '', '1|2|3|4', 'Oui|Non', '', ([AUTO] + (pcs = pieces_du_modele)).join('|')], 'Créer une ouverture (Métré Atelier 2M)')
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
      { type: type, l: l, h: h, lin: lin, n: [[rep[4].to_i, 1].max, 4].min, res: rep[5] == 'Oui' && type[1], appui: appui, piece: piece }
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
    def self.couches(depart, dir, n)
      model = Sketchup.active_model
      vus = []; pt = depart; parcours = 0.0
      30.times do
        hit = model.raytest([pt, dir])
        break unless hit
        parcours += pt.distance(hit[0])
        break if parcours > 3.m
        g = haut_de(hit[1])
        vus << g if g && !vus.include?(g)
        break if vus.size >= n
        pt = hit[0].offset(dir, 0.02)
      end
      vus
    end

    # Perce : boîte de découpe (largeur × hauteur, 3 m de profondeur) soustraite de chaque couche ; nom et balise conservés
    def self.percer(o, p, essai = 0)
      model = Sketchup.active_model
      cibles = couches(o[:centre].offset(o[:n], 0.5.cm), o[:n].reverse, p[:n])
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
        # Menuiserie de réservation : un panneau fin balisé, à la taille de l'ouverture, pour l'extraction du métré
        if p[:res]
          r = ents.add_group
          c1 = b.offset(n.reverse, 5.cm)
          fr = r.entities.add_face([c1, c1.offset(u, l), c1.offset(u, l).offset(Z_AXIS, h), c1.offset(Z_AXIS, h)])
          fr.pushpull(-5.cm) rescue nil
          tagm, _ = A2M::Balises.balise(model, p[:type][1], (A2M::Balises::LISTE.find { |x, _, _| x == p[:type][1] } || [])[2])
          r.layer = tagm
          r.name = "#{p[:type][0]} #{p[:l].round} × #{p[:h].round}#{p[:piece] ? ' – ' + p[:piece] : ''}"
          # Pièce choisie : gardée sur la menuiserie, l'extraction la rattache à cette pièce
          r.set_attribute('a2m', 'piece', p[:piece]) if p[:piece]
        end
        model.commit_operation
        msg = "Ouverture #{p[:l].round} × #{p[:h].round} cm percée dans #{cibles.size - echecs.size} couche(s)."
        msg += "\nNon percé (le groupe n'est pas un solide) : #{echecs.join(', ')}" if echecs.any?
        msg += "\nSeulement #{cibles.size} couche(s) trouvée(s) sur #{p[:n]} demandée(s)." if cibles.size < p[:n]
        echecs.any? || cibles.size < p[:n] ? UI.messagebox(msg) : Sketchup.status_text = msg
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
