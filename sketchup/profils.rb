# encoding: UTF-8
# Métré Atelier 2M : bibliothèque de profils (sections dessinées une fois, réutilisées partout)
#  - un profil = une ou plusieurs parties dans le même plan : la principale (plinthe, planelle, couvertine…)
#    et des parties « isolant » ; repère : w = 0 au nu de pose (côté mur ou côté extérieur), w vers l'intérieur ; h = 0 en bas ;
#  - créé depuis un dessin (faces verticales) ou par ses cotes (rectangle, L, U, T) ;
#  - utilisé par les outils Plinthes et Planelles, ou seul : balayé le long d'un tracé (lignes, face, groupe).
# Rangé dans index.json de la bibliothèque d'objets (avec les plinthes et planelles déjà rangées).
require 'sketchup.rb'
require 'json'

module A2M
  module Profils
    CATEGORIES = ['Plinthe', 'Planelle', 'Couvertine', 'Appui, seuil', 'Corniche, bandeau', 'Rive, habillage', 'Autre']
    BALISE = { 'Plinthe' => 'A2M_PLINTHE', 'Planelle' => 'A2M_PLANELLE' }
    FORMES = ['Rectangle', 'L, retour en pied', 'L, retour en tête', 'U (retours en pied et en tête)', 'T (retour au milieu)']
    SANS = '(aucune balise)'
    @r = {}

    # ---- Lecture et rangement ----
    def self.categorie(o)
      o['categorie'] || { 'A2M_PLINTHE' => 'Plinthe', 'A2M_PLANELLE' => 'Planelle' }[o['balise']] || 'Autre'
    end

    # Parties d'un profil : [[rôle, points]] ; rôle 'principal' ou 'isolant'
    def self.parties(o)
      if o['profils']
        o['profils'].map { |t, pts| [t.to_s =~ /isol/i ? 'isolant' : 'principal', pts] }
      elsif o['profil']
        [['principal', o['profil']]]
      else
        []
      end
    end

    def self.tous(cat = nil)
      liste = (A2M::Bibliotheque.objets rescue []).select { |o| o['profils'] || o['profil'] }
      cat ? liste.sort_by { |o| [categorie(o) == cat ? 0 : 1, o['nom'].to_s] } : liste.sort_by { |o| [categorie(o), o['nom'].to_s] }
    end

    def self.libelle(o) "#{o['nom']} (#{categorie(o)})" end

    def self.trouver(lib) tous.find { |o| libelle(o) == lib || o['nom'] == lib } end

    def self.enregistrer(nom, cat, parts)
      liste = A2M::Bibliotheque.objets
      if liste.any? { |o| o['nom'] == nom }
        return false unless UI.messagebox("« #{nom} » existe déjà dans la bibliothèque. Le remplacer ?", MB_YESNO) == IDYES
        liste.reject! { |o| o['nom'] == nom }
      end
      h = parts.flat_map { |_, p| p.map(&:last) }.max.to_f
      w = parts.flat_map { |_, p| p.map(&:first) }.max.to_f
      liste << { 'nom' => nom, 'type' => "#{cat} (profil)", 'categorie' => cat, 'balise' => BALISE[cat],
                 'profils' => parts.map { |r, p| [r, p.map { |a, b| [a.to_f, b.to_f] }] }, 'h0' => h, 'l0' => w, 'version' => 2 }
      A2M::Bibliotheque.sauver_index(liste.sort_by { |o| [o['type'].to_s, o['nom'].to_s] })
      true
    end

    # ---- Création ----
    # Faces verticales sélectionnées (ou dans les groupes sélectionnés), dans le même plan
    def self.faces_selection(sel)
      faces = sel.grep(Sketchup::Face).select { |f| f.normal.z.abs < 0.1 }.map { |f| [f, Geom::Transformation.new] }
      sel.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }.each do |g|
        ents = g.is_a?(Sketchup::Group) ? g.entities : g.definition.entities
        ents.grep(Sketchup::Face).each { |f| faces << [f, g.transformation] if f.normal.transform(g.transformation).z.abs < 0.1 }
      end
      faces
    end

    def self.depuis_dessin(faces, nu_long = true)
      r = A2M::Planelles.profils_depuis(faces, nu_long)
      r && r.map { |t, pts| [t[1] =~ /ISOLANT/ ? 'isolant' : 'principal', pts] }
    end

    # Profil par ses cotes (cm) : h hauteur, e épaisseur, r longueur du retour (au-delà de l'épaisseur), er épaisseur du retour, iso isolant
    def self.parametrique(forme, h, e, r, er, iso)
      c = ->(v) { (v.to_f / 100.0).m }
      h, e, r, er, iso = [h, e, r, er, iso].map { |v| c.call(v) }
      pts = case forme
            when FORMES[1] then [[0, 0], [e + r, 0], [e + r, er], [e, er], [e, h], [0, h]]
            when FORMES[2] then [[0, 0], [e, 0], [e, h - er], [e + r, h - er], [e + r, h], [0, h]]
            when FORMES[3] then [[0, 0], [e + r, 0], [e + r, er], [e, er], [e, h - er], [e + r, h - er], [e + r, h], [0, h]]
            when FORMES[4]
              m = (h - er) / 2.0
              [[0, 0], [e, 0], [e, m], [e + r, m], [e + r, m + er], [e, m + er], [e, h], [0, h]]
            else [[0, 0], [e, 0], [e, h], [0, h]]
            end
      parts = [['principal', pts]]
      if iso > 0
        # Isolant contre le dos de la partie verticale, entre les retours
        b = [FORMES[1], FORMES[3]].include?(forme) ? er : 0
        t = [FORMES[2], FORMES[3]].include?(forme) ? h - er : h
        if forme == FORMES[4]
          m = (h - er) / 2.0       # T : isolant au-dessous et au-dessus du retour
          parts << ['isolant', [[e, 0], [e + iso, 0], [e + iso, m], [e, m]]]
          parts << ['isolant', [[e, m + er], [e + iso, m + er], [e + iso, h], [e, h]]]
        elsif t > b
          parts << ['isolant', [[e, b], [e + iso, b], [e + iso, t], [e, t]]]
        end
      end
      parts
    end

    # ---- Balayage le long d'un tracé ----
    # Tracé ordonné depuis la sélection : lignes bout à bout, contour d'une face, ou dessus d'un groupe. Retour [points, fermé ?]
    def self.trace(sel)
      if (f = sel.grep(Sketchup::Face).find { |x| x.normal.z.abs > 0.9 })
        pts = f.outer_loop.vertices.map(&:position)
        return [ccw(pts), true]
      end
      if (g = sel.find { |e| e.is_a?(Sketchup::Group) && A2M::Planelles.contour(e) })
        pts, _z0, z1 = A2M::Planelles.contour(g)
        return [pts.map { |q| Geom::Point3d.new(q.x, q.y, z1) }, true]
      end
      aretes = sel.grep(Sketchup::Edge)
      return nil if aretes.empty?
      reste = aretes.dup
      # Départ : une extrémité qui n'a qu'une arête (tracé ouvert), sinon n'importe laquelle (tracé fermé)
      compte = Hash.new(0); aretes.each { |e| e.vertices.each { |v| compte[v] += 1 } }
      v = compte.find { |_, n| n == 1 }&.first || aretes[0].start
      chaine = [v]
      until reste.empty?
        e = reste.find { |x| x.vertices.include?(v) }
        break unless e
        reste.delete(e)
        v = e.other_vertex(v)
        chaine << v
      end
      ferme = chaine.size > 2 && chaine[0] == chaine[-1]
      chaine.pop if ferme
      pts = chaine.map(&:position)
      [ferme ? ccw(pts) : pts, ferme]
    end

    def self.ccw(pts) A2M::DessinMurs.aire(pts.map { |q| [q.x, q.y] }) < 0 ? pts.reverse : pts end

    # Balaye les parties du profil ; cote = +1 : profil à gauche du tracé (intérieur d'un contour fermé), -1 : à droite
    def self.balayer(pts, ferme, parts, cote, dz, balise, nom, model)
      res = []
      parts.each do |role, prof|
        grp = model.active_entities.add_group
        ents = grp.entities
        if ferme
          depart = Geom::Point3d.new((pts[0].x + pts[1].x) / 2.0, (pts[0].y + pts[1].y) / 2.0, pts[0].z)
          chemin = [depart] + pts[1..-1] + [pts[0], depart]
        else
          depart = pts[0]; chemin = pts
        end
        d = chemin[1] - chemin[0]; d = Geom::Vector3d.new(d.x, d.y, 0).normalize
        m = Z_AXIS.cross(d).normalize
        m.reverse! if cote < 0
        face = ents.add_face(prof.map { |w, h| depart.offset(m, w).offset(Z_AXIS, h + dz) })
        raise 'profil invalide (face non créée)' unless face
        face.followme(ents.add_edges(chemin))
        ents.grep(Sketchup::Edge).select { |e| e.valid? && e.faces.empty? }.each(&:erase!)
        tag = role == 'isolant' && balise == 'A2M_PLANELLE' ? 'A2M_ISOLANT_PLANELLE' : balise
        if tag
          l, _ = A2M::Balises.balise(model, tag, (A2M::Balises::LISTE.find { |x, _, _| x == tag } || [])[2])
          grp.layer = l
          A2M::Hachures.poser(grp, model)
        end
        grp.name = role == 'isolant' ? "#{nom} – isolant" : nom
        res << grp
      end
      res
    end

    # ---- Commande : la bibliothèque de profils ----
    ACTIONS = ['Balayer un profil le long du tracé sélectionné', 'Ranger le profil dessiné (faces sélectionnées)',
               'Créer un profil par ses cotes (rectangle, L, U, T)', 'Voir la liste des profils']

    def self.gerer
      rep = UI.inputbox(['Que faire ?'], [@r[:action] || ACTIONS[0]], [ACTIONS.join('|')], "Bibliothèque de profils : #{tous.size} profil(s)")
      return unless rep
      @r[:action] = rep[0]
      case ACTIONS.index(rep[0])
      when 0 then balayer_commande
      when 1 then ranger_dessin
      when 2 then creer
      else
        l = tous
        UI.messagebox(l.empty? ? 'Aucun profil pour l\'instant.' : "Profils de la bibliothèque :\n" + l.map { |o| "  • #{libelle(o)}#{parties(o).size > 1 ? ' + isolant' : ''}" }.join("\n"))
      end
    end

    def self.ranger_dessin
      faces = faces_selection(Sketchup.active_model.selection.to_a)
      return UI.messagebox('Sélectionnez la ou les faces verticales du profil (dessinées debout), ou leur groupe.') if faces.empty?
      rep = UI.inputbox(['Nom du profil', 'Catégorie', 'Nu de pose (côté mur ou côté extérieur)'], ['', @r[:cat] || CATEGORIES[0], 'Le plus long bord vertical'],
                        ['', CATEGORIES.join('|'), 'Le plus long bord vertical|Le côté opposé'], 'Ranger le profil dessiné')
      return unless rep && !rep[0].to_s.strip.empty?
      @r[:cat] = rep[1]
      parts = depuis_dessin(faces, rep[2] == 'Le plus long bord vertical')
      return UI.messagebox('Profil illisible : dessinez des faces verticales dans un même plan.') unless parts
      UI.messagebox("Profil « #{rep[0].strip} » rangé (#{rep[1]}#{parts.size > 1 ? ', avec isolant' : ''}).") if enregistrer(rep[0].strip, rep[1], parts)
    end

    def self.creer
      p = @r[:param] || {}
      rep = UI.inputbox(['Nom du profil', 'Catégorie', 'Forme', 'Hauteur (cm)', 'Épaisseur (cm)', 'Retour : longueur au-delà de l\'épaisseur (cm)',
                         'Retour : épaisseur (cm)', 'Isolant derrière (cm, 0 = aucun)'],
                        ['', p[:cat] || 'Planelle', p[:forme] || FORMES[1], (p[:h] || 20).to_s, (p[:e] || 5).to_s, (p[:r] || 10).to_s, (p[:er] || 5).to_s, (p[:iso] || 0).to_s],
                        ['', CATEGORIES.join('|'), FORMES.join('|'), '', '', '', '', ''], 'Créer un profil par ses cotes')
      return unless rep && !rep[0].to_s.strip.empty?
      h, e, r, er, iso = rep[3..7].map { |v| v.to_s.tr(',', '.').to_f }
      return UI.messagebox('Hauteur et épaisseur supérieures à 0.') if h <= 0 || e <= 0
      return UI.messagebox('Le retour doit avoir une longueur et une épaisseur.') if rep[2] != FORMES[0] && (r <= 0 || er <= 0 || er >= h)
      @r[:param] = { cat: rep[1], forme: rep[2], h: h, e: e, r: r, er: er, iso: iso }
      parts = parametrique(rep[2], h, e, r, er, iso)
      UI.messagebox("Profil « #{rep[0].strip} » créé et rangé (#{rep[1]}, #{rep[2]}).") if enregistrer(rep[0].strip, rep[1], parts)
    end

    def self.balayer_commande
      model = Sketchup.active_model
      t = trace(model.selection.to_a)
      return UI.messagebox("Sélectionnez le tracé : des lignes bout à bout, une face horizontale (son contour) ou un groupe (le contour de son dessus).") unless t
      pts, ferme = t
      l = tous
      return UI.messagebox('La bibliothèque de profils est vide : rangez ou créez d\'abord un profil.') if l.empty?
      libs = l.map { |o| libelle(o) }
      cotes = ferme ? ['Vers l\'intérieur du contour', 'Vers l\'extérieur du contour'] : ['À gauche du tracé', 'À droite du tracé']
      bal = [SANS] + A2M::Balises::LISTE.map(&:first)
      rep = UI.inputbox(['Profil', 'Le profil part', 'Décalage vertical (cm)', 'Balise'],
                        [libs.include?(@r[:profil]) ? @r[:profil] : libs[0], cotes[0], (@r[:dz] || 0).to_s, @r[:bal] || SANS],
                        [libs.join('|'), cotes.join('|'), '', bal.join('|')], "Balayer un profil (#{ferme ? 'contour fermé' : 'tracé ouvert'}, #{pts.size} points)")
      return unless rep
      @r.merge!(profil: rep[0], dz: rep[2], bal: rep[3])
      o = l[libs.index(rep[0])]
      balise = rep[3] == SANS ? BALISE[categorie(o)] : rep[3]
      model.start_operation('Balayer un profil (métré)', true)
      begin
        g = balayer(pts, ferme, parties(o), rep[1] == cotes[0] ? 1 : -1, (rep[2].to_s.tr(',', '.').to_f / 100.0).m, balise, o['nom'], model)
        model.commit_operation
        long = (0...(ferme ? pts.size : pts.size - 1)).sum { |k| pts[k].distance(pts[(k + 1) % pts.size]) } * 0.0254
        Sketchup.status_text = "#{o['nom']} balayé sur #{long.round(2)} ml (#{g.size} volume(s))."
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Balayage impossible (#{ex.message}).")
      end
    end
  end
end
