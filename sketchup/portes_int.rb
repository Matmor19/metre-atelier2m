# encoding: UTF-8
# Métré Atelier 2M : outil Porte intérieure (bloc-porte de passage dans une cloison ou un refend)
#  - la porte se choisit par son vantail (63, 73, 83, 93, 103 × 204) ; la réservation est le vantail + le jeu de l'huisserie ;
#  - toute l'épaisseur est percée (couches jointives : plaque, ossature, plaque, ou refend et doublages), pas plus loin ;
#  - le bloc est centré dans l'épaisseur ; Tab choisit le sens (poussant droit ou gauche, de ce côté ou de l'autre) ;
#  - choix du configurateur (destination, âme, type, finition, pose) gardés sur la porte et repris à l'extraction.
require 'sketchup.rb'
require 'json'

module A2M
  module PortesInt
    DIMS = ['63×204', '73×204', '83×204', '93×204', '103×204']
    AUTRE = 'Autre (cotes ci-dessous)'
    AC = '— à choisir —'
    # Mêmes libellés que le configurateur du métré (rien n'est choisi d'office)
    CHOIX = [
      ['dest', 'Destination', ['à galandage', 'de communication', 'acoustique', 'de service isothermique', 'technique coupe-feu EI30', 'palière thermique', 'palière acoustique', 'palière blindage de sécurité', 'fin de chantier', 'palière coupe-feu']],
      ['ame', 'Âme', ['âme alvéolaire', 'âme pleine', 'âme tubulaire']],
      ['type', 'Type de vantail', ['isoplane', 'postformé', 'vitré']],
      ['fin', 'Finition', ['rive droite', 'recouvrement']],
      ['pose', 'Pose', ['pose traditionnelle', 'pose fin de chantier', 'pose rénovation']]
    ]
    # Sens : [côté poussant (:ici = côté cliqué), paumelles vues du côté poussant]
    SENS = [[:ici, 'droite'], [:ici, 'gauche'], [:autre, 'droite'], [:autre, 'gauche']]
    RES_SIMPLE = 'Réservation simple (huisserie balisée)'
    RES_AUCUNE = 'Aucune (seulement le passage)'
    BIB = 'Bibliothèque : '
    @r = {}

    def self.lib_sens(s)
      "Poussant #{s[1] == 'droite' ? 'droit' : 'gauche'}, #{s[0] == :ici ? 'depuis ce côté' : 'depuis l\'autre côté'}"
    end

    def self.demander
      objs = (A2M::Bibliotheque.objets_de(['A2M_PORTE_INT']) rescue [])
      menus = [RES_SIMPLE, RES_AUCUNE] + objs.map { |o| "#{BIB}#{o['nom']}" }
      pcs = A2M::Ouvertures.pieces_du_modele
      auto = A2M::Ouvertures::AUTO
      libs = ['Bloc-porte (vantail)', 'Vantail, largeur si autre (cm)', 'Vantail, hauteur si autre (cm)',
              'Réservation : jeu total en largeur (cm), huisserie comprise', 'Réservation : jeu en hauteur (cm)',
              'Menuiserie posée', 'Pièce de rattachement'] + CHOIX.map { |_, l, _| l }
      defs = [@r[:dim] || '83×204', (@r[:vl] || 83).to_s, (@r[:vh] || 204).to_s, (@r[:jl] || 7).to_s, (@r[:jh] || 4).to_s,
              menus.include?(@r[:menu]) ? @r[:menu] : (objs.any? ? menus[2] : RES_SIMPLE), pcs.include?(@r[:piece]) ? @r[:piece] : auto] +
             CHOIX.map { |k, _, _| (@r[:choix] || {})[k] || AC }
      listes = [(DIMS + [AUTRE]).join('|'), '', '', '', '', menus.join('|'), ([auto] + pcs).join('|')] +
               CHOIX.map { |_, _, v| ([AC] + v).join('|') }
      rep = UI.inputbox(libs, defs, listes, 'Porte intérieure (Métré Atelier 2M)')
      return nil unless rep
      if rep[0] == AUTRE
        vl, vh = rep[1].tr(',', '.').to_f, rep[2].tr(',', '.').to_f
      else
        vl, vh = rep[0].split('×').map(&:to_f)
      end
      jl, jh = rep[3].tr(',', '.').to_f, rep[4].tr(',', '.').to_f
      return UI.messagebox('Le vantail doit avoir une largeur et une hauteur supérieures à 0.') && nil if vl <= 0 || vh <= 0
      choix = {}
      CHOIX.each_with_index { |(k, _, _), i| choix[k] = rep[7 + i] unless rep[7 + i] == AC }
      @r = { dim: rep[0], vl: vl, vh: vh, jl: jl, jh: jh, menu: rep[5], piece: rep[6], choix: choix }
      obj = rep[5].start_with?(BIB) ? objs[menus.index(rep[5]) - 2] : nil
      opts = obj ? A2M::Bibliotheque.demander_options(obj) : {}
      return nil if opts.nil?
      dim = rep[0] == AUTRE ? "#{vl.round}×#{vh.round}" : rep[0]
      { type: ['Porte intérieure', 'A2M_PORTE_INT'], l: vl + jl, h: vh + jh, lin: vh + jh, vl: vl, vh: vh, n: 6, contigu: true,
        appui: 0, res: rep[5] != RES_AUCUNE ? 'A2M_PORTE_INT' : nil, obj: obj, opts: opts,
        piece: rep[6] == auto ? nil : rep[6], bp: choix.merge('dim' => dim) }
    end

    def self.lancer
      p = demander
      Sketchup.active_model.select_tool(Outil.new(p)) if p
    end

    # Transformation de l'objet : centré sur le trou (largeur et épaisseur), posé au sol du trou,
    # tourné vers le côté poussant, retourné en miroir si ses paumelles ne sont pas du côté voulu
    def self.transfo(defn, obj, base, v_pousse, paumelles)
      bv = A2M::Bibliotheque.boite_visible(defn)
      t = Geom::Transformation.translation(Geom::Vector3d.new(-bv.center.x, -bv.center.y, -bv.min.z))
      # Repère commun : côté regardé à la paramétrisation vers -Y (celui qui pousse)
      t = Geom::Transformation.rotation(ORIGIN, Z_AXIS, Math::PI) * t if (obj && obj['ext_y']) == 'max'
      t = Geom::Transformation.scaling(-1, 1, 1) * t if obj && (obj['paumelles'] || 'droite') != paumelles
      x = Z_AXIS.cross(v_pousse).normalize
      Geom::Transformation.axes(base, x, v_pousse.reverse, Z_AXIS) * t
    end

    # Cotes données à l'objet : composant dynamique = son vantail ; objet étiré = sa taille + l'écart de vantail
    def self.cotes(obj, p)
      return [p[:vl], p[:vh]] if obj['mode'] == 'dynamique'
      l0 = obj['l0'].to_f * 2.54; h0 = obj['h0'].to_f * 2.54
      return [p[:l], p[:h]] unless obj['vl0']
      [l0 + p[:vl] - obj['vl0'].to_f, h0 + p[:vh] - obj['vh0'].to_f]
    end

    def self.poser(o, p, sens, essai = 0)
      model = Sketchup.active_model
      model.start_operation('Poser une porte intérieure (métré)', true)
      begin
        ents = model.active_entities
        u, n, b = o[:u], o[:n], o[:bas]
        id = "O#{Time.now.to_f.to_s.tr('.', '')}#{rand(1000)}"
        dec = A2M::Ouvertures.decouper(o, p, p[:res] ? id : nil, model)
        unless dec
          model.abort_operation
          return UI.messagebox('Aucune cloison trouvée derrière le point cliqué.')
        end
        prof = dec[:prof]
        l = (p[:l] / 100.0).m; h = (p[:h] / 100.0).m
        base = b.offset(u, l / 2.0).offset(n, -prof / 2.0)           # milieu du trou, au sol, au milieu de l'épaisseur
        v_pousse = sens[0] == :ici ? n : n.reverse
        alerte = nil; r = nil
        if p[:res] && p[:obj]
          a, c = cotes(p[:obj], p)
          r = A2M::Bibliotheque.instance_pour(ents, p[:obj], a, c, ORIGIN, X_AXIS, Y_AXIS, ->(_e) { 0 }, model, p[:opts], false)
          alerte = A2M::Bibliotheque.alerte!
          r.transformation = transfo(r.definition, p[:obj], base, v_pousse, sens[1])
        elsif p[:res]
          # Huisserie de réservation : cadre à la taille du trou, sur toute l'épaisseur percée
          r = ents.add_group
          e = [prof, 1.cm].max; m = 4.cm
          x = Z_AXIS.cross(v_pousse).normalize
          o0 = base.offset(x, -l / 2.0).offset(v_pousse, e / 2.0)
          ext = [o0, o0.offset(x, l), o0.offset(x, l).offset(Z_AXIS, h), o0.offset(Z_AXIS, h)]
          i0 = o0.offset(x, m)
          int = [i0, i0.offset(x, l - 2 * m), i0.offset(x, l - 2 * m).offset(Z_AXIS, h - m), i0.offset(Z_AXIS, h - m)]
          f = r.entities.add_face(ext); r.entities.add_face(int).erase! rescue nil
          f = r.entities.grep(Sketchup::Face).max_by(&:area)
          f.reverse! if f.normal.dot(v_pousse) > 0
          f.pushpull(e)
        end
        if r
          tag, _ = A2M::Balises.balise(model, 'A2M_PORTE_INT', (A2M::Balises::LISTE.find { |x, _, _| x == 'A2M_PORTE_INT' } || [])[2])
          r.layer = tag
          bp = p[:bp].merge('pousse' => "poussant #{sens[1] == 'droite' ? 'droit' : 'gauche'}")
          r.set_attribute('a2m', 'bp', JSON.generate(bp))
          r.set_attribute('a2m', 'sens', JSON.generate([sens[0].to_s, sens[1]]))
          r.set_attribute('a2m', 'piece', p[:piece]) if p[:piece]
          r.name = "Porte #{bp['dim']} #{bp['pousse']}#{p[:piece] ? ' – ' + p[:piece] : ''}"
        end
        sols = prof > 0 ? A2M::Ouvertures.ajuster_sols(o, p, prof) : []
        empreinte = [b, b.offset(u, l), b.offset(u, l).offset(n, -prof), b.offset(n, -prof)]
        A2M::Plinthes.enregistrer(empreinte, 'porte', model, r ? id : nil) if prof > 0
        plin = A2M::Plinthes.regenerer_autour(empreinte)
        A2M::Suivi.lier(r, o, p, id, dec[:couches], empreinte, 'porte') if r
        model.commit_operation
        msg = "Porte #{p[:bp]['dim']} : réservation #{p[:l].round} × #{p[:h].round} cm percée dans #{dec[:nb] - dec[:echecs].size} couche(s) (#{(prof.to_f * 2.54).round(1)} cm)."
        msg += "\nRevêtements prolongés jusqu'à l'axe de la porte : #{sols.join(', ')}" if sols.any?
        msg += "\nPlinthes recoupées : #{plin.join(', ')}" if plin.any?
        msg += "\n#{alerte}" if alerte
        msg += "\nNon percé (le groupe n'est pas un solide) : #{dec[:echecs].join(', ')}" if dec[:echecs].any?
        dec[:echecs].any? || alerte ? UI.messagebox(msg) : Sketchup.status_text = msg
      rescue A2M::Ouvertures::SensInverse
        model.abort_operation
        A2M::Ouvertures.inverser!
        return poser(o, p, sens, essai + 1) if essai < 1
        UI.messagebox('Le perçage n\'a pas donné le résultat attendu : rien n\'a été modifié.')
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("La porte n'a pas pu être posée (#{ex.message}).")
      end
    end

    # Même pointage que l'outil Ouverture (point de référence, sens le long du mur, distance tapée),
    # plus Tab pour le sens d'ouverture, dessiné au sol
    class Outil < A2M::Ouvertures::Outil
      def initialize(p) super(p); @s = 0 end

      def statut
        sens = A2M::PortesInt.lib_sens(A2M::PortesInt::SENS[@s])
        Sketchup.status_text = @ref ? "#{sens} (Tab pour changer). Déplacez la souris le long de la cloison, tapez la distance jusqu'au bord de la réservation puis Entrée (ou cliquez). Échap pour recommencer." :
                                      "Porte #{@p[:bp]['dim']}, réservation #{@p[:l].round} × #{@p[:h].round} cm — #{sens} (Tab). Cliquez un point de référence sur la face de la cloison (un angle, un bord…)."
        Sketchup.vcb_label = 'Distance'
      end

      def onKeyDown(key, rpt, _f, view)
        return false unless key == 9
        return true if rpt > 1
        @s = (@s + 1) % A2M::PortesInt::SENS.size
        statut; view.invalidate
        true
      end

      def poser(d)
        A2M::PortesInt.poser(ouverture(d), @p, A2M::PortesInt::SENS[@s])
        @ref = nil; @dist = nil
        statut
      end

      def draw(view)
        super
        return unless @ref && @dist
        o = ouverture(@dist)
        s = A2M::PortesInt::SENS[@s]
        l = (@p[:l] / 100.0).m; vl = (@p[:vl] / 100.0).m
        v_p = s[0] == :ici ? o[:n] : o[:n].reverse          # vers celui qui pousse
        x = Z_AXIS.cross(v_p).normalize                       # sa droite
        ep = 7.cm
        milieu = o[:bas].offset(o[:u], l / 2.0).offset(o[:n], -ep / 2.0)
        cote_ouvre = milieu.offset(v_p, -ep / 2.0)            # le vantail s'ouvre de l'autre côté
        pivot = cote_ouvre.offset(x, (s[1] == 'droite' ? 1 : -1) * vl / 2.0)
        ferme = Geom::Vector3d.new(-x.x, -x.y, 0); ferme.reverse! if s[1] == 'gauche'
        pts = (0..12).map do |i|
          a = Math::PI / 2 * i / 12.0
          dv = Geom::Vector3d.new(ferme.x * Math.cos(a) - v_p.x * Math.sin(a), ferme.y * Math.cos(a) - v_p.y * Math.sin(a), 0)
          pivot.offset(dv, vl)
        end
        view.line_width = 2; view.drawing_color = 'DarkOrange'
        view.draw(GL_LINES, [pivot, pts[-1]])
        view.line_width = 1; view.line_stipple = '-'
        view.draw(GL_LINE_STRIP, pts)
        view.line_stipple = ''
        sp = view.screen_coords(o[:centre])
        view.draw_text(Geom::Point3d.new(sp.x + 16, sp.y + 12, 0), "#{A2M::PortesInt.lib_sens(s)}  (Tab)", color: 'DimGray', size: 10) rescue nil
      end
    end
  end
end
