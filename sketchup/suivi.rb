# encoding: UTF-8
# Métré Atelier 2M : ouvertures liées à leur menuiserie
#  - menuiserie déplacée (ou tournée) : le mur est rebouché à l'ancienne place et percé à la nouvelle ;
#  - menuiserie supprimée : le mur est rebouché ;
#  - menuiserie copiée : la copie perce sa propre ouverture.
# Chaque menuiserie garde (attribut a2m/ouv) ses réglages de perçage et les trous faits dans chaque couche ;
# chaque mur garde la liste de ses trous (a2m/trous) : rien n'est rebouché deux fois, même après une annulation.
require 'sketchup.rb'
require 'json'
require 'fileutils'

module A2M
  module Suivi
    @cache = {}       # menuiserie -> données (lisibles même après sa suppression)
    @registre = {}    # identifiant d'ouverture -> menuiserie
    @attente = {}
    @occupe = false
    TOL = 0.04        # 1 mm

    # ---- Attache ----
    class ObsMenuiserie < Sketchup::EntityObserver
      def onChangeEntity(e) A2M::Suivi.plus_tard(e, :change) end
      def onEraseEntity(e) A2M::Suivi.plus_tard(e, :efface) end
    end

    class ObsAjout < Sketchup::EntitiesObserver
      def onElementAdded(_ents, e)
        A2M::Suivi.plus_tard(e, :ajout) if A2M::Suivi.suivie?(e)
      end
      # Déplacement : selon les versions de SketchUp, signalé ici plutôt que par l'observateur de la menuiserie
      def onElementModified(_ents, e)
        A2M::Suivi.plus_tard(e, :change) if A2M::Suivi.suivie?(e)
      end
    end

    def self.suivie?(e)
      (e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)) && e.valid? && !e.get_attribute('a2m', 'ouv').nil?
    rescue StandardError
      false
    end

    # ---- Journal (Documents\Atelier 2M\journal_ouvertures.txt) : ce que le suivi a fait, pour comprendre un souci ----
    def self.journal(txt)
      f = File.join(File.dirname(A2M::Bibliotheque.dossier), 'journal_ouvertures.txt')
      FileUtils.mkdir_p(File.dirname(f))
      File.open(f, 'a:UTF-8') { |io| io.puts "#{Time.now.strftime('%d/%m %H:%M:%S')}  #{txt}" }
    rescue StandardError
      nil
    end

    # Les changements notés sont traités une fois l'action de l'utilisateur terminée (déplacement lâché, suppression validée)
    class ObsModele < Sketchup::ModelObserver
      def onTransactionCommit(_m) A2M::Suivi.apres_action end
    end

    class ObsAppli < Sketchup::AppObserver
      def onNewModel(m) A2M::Suivi.surveiller(m) end
      def onOpenModel(m) A2M::Suivi.surveiller(m) end
    end

    OBS = ObsMenuiserie.new
    OBS_AJOUT = ObsAjout.new
    OBS_MODELE = ObsModele.new

    def self.demarrer
      Sketchup.add_observer(ObsAppli.new)
      surveiller(Sketchup.active_model)
    end

    # Toutes les menuiseries suivies du modèle, jusqu'à 3 niveaux de groupes
    def self.surveiller(model)
      return unless model
      @cache = {}; @registre = {}
      model.entities.add_observer(OBS_AJOUT)
      model.add_observer(OBS_MODELE)
      fouiller = lambda do |ents, prof|
        ents.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          if e.get_attribute('a2m', 'ouv') then attacher(e)
          elsif prof < 3 then fouiller.call(e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities, prof + 1)
          end
        end
      end
      fouiller.call(model.entities, 0)
    end

    def self.attacher(r)
      d = donnees(r)
      return unless d
      r.remove_observer(OBS) rescue nil
      r.add_observer(OBS)
      @cache[r] = d
      @registre[d['id']] = r
    end

    def self.donnees(r) JSON.parse(r.get_attribute('a2m', 'ouv').to_s) rescue nil end

    def self.ecrire(r, d)
      r.set_attribute('a2m', 'ouv', JSON.generate(d))
      @cache[r] = d
      @registre[d['id']] = r
    end

    def self.t_tab(t) t.to_a.map { |v| v.to_f.round(4) } end

    # Commande de secours : reboucher puis repercer à la place actuelle de la menuiserie sélectionnée
    def self.recaler
      model = Sketchup.active_model
      sel = model.selection.to_a.select { |e| suivie?(e) }
      return UI.messagebox('Sélectionnez une ou plusieurs menuiseries posées avec l\'outil Ouverture (version 2.4 ou plus).') if sel.empty?
      sel.each do |r|
        d = donnees(r)
        journal("recaler « #{r.name} » (#{d['id']})")
        operation(model, 'Recaler l\'ouverture') do
          reboucher(model, d)
          recouper(model, r, d)
        end
        attacher(r)
      end
      Sketchup.status_text = "#{sel.size} ouverture(s) recalée(s) sur leur menuiserie."
    rescue StandardError => ex
      journal("ERREUR recaler : #{ex.message}")
      UI.messagebox("Recalage impossible (#{ex.message}).")
    end

    # Commande : poser un objet de la bibliothèque sur une ouverture existante (vide ou déjà équipée).
    # L'objet prend les dimensions exactes de l'ouverture, se pose au nu intérieur, et reprend son suivi.
    def self.poser_sur
      model = Sketchup.active_model
      r = model.selection.to_a.find { |e| suivie?(e) }
      return UI.messagebox("Sélectionnez l'ouverture (sa réservation ou sa menuiserie), posée avec l'outil Ouverture.") unless r
      d = donnees(r)
      tag = r.layer && r.layer.name
      porte = tag == 'A2M_PORTE_ENTREE'
      objs = (A2M::Bibliotheque.objets_de(A2M::Ouvertures.balises_de(porte ? 'Porte' : 'Fenêtre')) rescue [])
      return UI.messagebox("La bibliothèque n'a pas encore de #{porte ? 'porte' : 'fenêtre ni de baie'} : rangez l'objet d'abord (Paramétrer un objet pour la bibliothèque).") if objs.empty?
      noms = objs.map { |o| "#{o['nom']} (#{o['type']})" }
      pr = d['p']
      rep = UI.inputbox(['Menuiserie (bibliothèque)'], [noms[0]], [noms.join('|')], "Ouverture #{pr['l'].round} × #{pr['h'].round} cm")
      return unless rep
      obj = objs[noms.index(rep[0])]
      t = r.transformation
      bas = Geom::Point3d.new(d['o']['bas']).transform(t)
      u = Geom::Vector3d.new(d['o']['u']).transform(t); u = Geom::Vector3d.new(u.x, u.y, 0).normalize
      n = Geom::Vector3d.new(d['o']['n']).transform(t); n = Geom::Vector3d.new(n.x, n.y, 0).normalize
      emp = d['empreinte'].map { |q| Geom::Point3d.new(q) }
      prof = emp.size == 4 ? emp[0].distance(emp[3]) : 0
      l = (pr['l'] / 100.0).m
      ur = Z_AXIS.cross(n).normalize
      org = u.dot(ur) > 0 ? bas : bas.offset(u, l)
      attrs = {}
      (r.attribute_dictionary('a2m') || {}).each_pair { |k, v| attrs[k] = v }
      @occupe = true
      model.start_operation('Poser une menuiserie sur l\'ouverture', true)
      begin
        ents = r.parent.entities
        nv = A2M::Bibliotheque.instance_pour(ents, obj, pr['l'], pr['h'], org, ur, n.reverse, ->(_e) { 0 }, model, {})
        if prof > 0
          defn = nv.respond_to?(:definition) ? nv.definition : nv.entities.parent
          fond = (0..7).map { |i| -((A2M::Bibliotheque.boite_visible(defn).corner(i).transform(nv.transformation)) - bas).dot(n) }.max
          dp = prof - fond
          nv.transform!(Geom::Transformation.translation(Geom::Vector3d.new(-n.x * dp, -n.y * dp, 0))) if dp.abs > 0.01
        end
        attrs.each { |k, v| nv.set_attribute('a2m', k, v) }
        nv.set_attribute('a2m', 'me', JSON.generate(obj['choix'])) if obj['choix'] && obj['choix'].any?
        lt, _ = A2M::Balises.balise(model, obj['balise'], (A2M::Balises::LISTE.find { |x, _, _| x == obj['balise'] } || [])[2])
        nv.layer = lt
        nv.name = "#{obj['nom']} #{pr['l'].round} × #{pr['h'].round}"
        # Le suivi passe à la nouvelle menuiserie (repère recalculé), l'ancienne est retirée sans reboucher le mur
        inv = nv.transformation.inverse
        d['o'] = { 'bas' => bas.transform(inv).to_a, 'u' => u.transform(inv).to_a, 'n' => n.transform(inv).to_a }
        d['t'] = t_tab(nv.transformation)
        d['p'] = pr.merge('tag' => obj['balise'], 'lib' => obj['type'])
        @cache.delete(r)
        r.erase!
        ecrire(nv, d)
        attacher(nv)
        model.commit_operation
        a = A2M::Bibliotheque.alerte!
        UI.messagebox(a) if a
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("La menuiserie n'a pas pu être posée (#{ex.message}).")
      ensure
        @occupe = false
      end
    end

    # Après une création d'ouverture (dans l'opération de perçage)
    def self.lier(r, o, p, id, couches, empreinte, genre, annexes = [])
      inv = r.transformation.inverse
      d = { 'id' => id, 'genre' => genre, 't' => t_tab(r.transformation), 'couches' => couches,
            'empreinte' => empreinte.map(&:to_a), 'annexes' => annexes.map(&:persistent_id),
            'o' => { 'bas' => o[:bas].transform(inv).to_a, 'u' => o[:u].transform(inv).to_a, 'n' => o[:n].transform(inv).to_a },
            'p' => { 'l' => p[:l], 'h' => p[:h], 'n' => p[:n], 'appui' => p[:appui], 'tag' => p[:type][1], 'lib' => p[:type][0], 'contigu' => p[:contigu] } }
      ecrire(r, d)
      attacher(r)
    end

    # ---- Traitement différé (on ne modifie jamais le modèle pendant un observateur) ----
    def self.plus_tard(e, quoi)
      return if @occupe
      return if quoi == :change && @attente[e] == :ajout
      @attente[e] = quoi unless @attente[e] == :efface
    end

    def self.apres_action
      return if @occupe || @attente.empty? || @minuteur
      @minuteur = UI.start_timer(0, false) { @minuteur = nil; traiter }
    end

    def self.traiter
      lot = @attente; @attente = {}
      return if lot.empty?
      model = Sketchup.active_model
      lot.each do |e, quoi|
        begin
          case quoi
          when :efface
            d = @cache.delete(e)
            # Rien à reboucher si aucun mur n'a ce trou (annulation d'un perçage, par exemple)
            if d && murs_avec(model, d).any?
              operation(model, 'Reboucher l\'ouverture') do
                annexes(model, d).each { |a| a.erase! if a.valid? }   # appui ou seuil supprimés avec la menuiserie
                reboucher(model, d)
              end
            end
          when :change then changer(model, e) if e.valid?
          when :ajout then ajout(model, e) if e.valid?
          end
        rescue StandardError => ex
          journal("ERREUR #{quoi} : #{ex.class} #{ex.message} — #{ex.backtrace.to_a.first(3).join(' | ')}")
          UI.messagebox("L'ouverture n'a pas pu suivre la menuiserie (#{ex.message}).\nRien n'a été modifié. Clic droit sur la menuiserie > ◆ Métré Atelier 2M > Recaler l'ouverture.")
        end
      end
    end

    # Opération « transparente » : fusionnée avec le déplacement ou la suppression (un seul Annuler)
    def self.operation(model, nom)
      @occupe = true
      model.start_operation(nom, true, false, true)
      begin
        yield
        model.commit_operation
      rescue A2M::Ouvertures::SensInverse
        model.abort_operation
        A2M::Ouvertures.inverser!
        model.start_operation(nom, true, false, true)
        yield
        model.commit_operation
      rescue StandardError
        model.abort_operation
        raise
      end
    ensure
      @occupe = false
    end

    def self.changer(model, r)
      d = donnees(r)
      return unless d
      @cache[r] = d
      return if t_tab(r.transformation).zip(d['t']).all? { |a, b| (a - b).abs < 0.001 }   # pas bougé (attribut, balise, annulation…)
      journal("déplacement de « #{r.name} » (#{d['id']}) : #{murs_avec(model, d).size} mur(s) à reboucher")
      delta = r.transformation * Geom::Transformation.new(d['t']).inverse
      operation(model, 'L\'ouverture suit la menuiserie') do
        # Appuis et seuils posés avec la menuiserie : déplacés avec elle
        annexes(model, d).each { |a| a.transform!(delta) }
        reboucher(model, d)
        recouper(model, r, d)
      end
    end

    # Copie (même identifiant qu'une menuiserie existante) : nouvelle ouverture ; retour par Annuler : rien à faire
    def self.ajout(model, r)
      d = donnees(r)
      return unless d
      autre = @registre[d['id']]
      copie = autre && autre != r && autre.valid?
      if copie
        d = d.merge('id' => "O#{Time.now.to_f.to_s.tr('.', '')}#{rand(1000)}", 'couches' => [])
        operation(model, 'Ouverture de la copie') { recouper(model, r, d) }
      elsif murs_avec(model, d).empty? && d['couches'].any?
        operation(model, 'Ouverture de la menuiserie') { recouper(model, r, d) }   # collée après un Couper
      end
      attacher(r)
    end

    def self.annexes(model, d)
      (d['annexes'] || []).map { |pid| model.find_entity_by_persistent_id(pid) rescue nil }.compact.select(&:valid?)
    end

    # ---- Murs ----
    def self.murs(model)
      res = []
      fouiller = lambda do |ents, prof|
        ents.each do |e|
          next unless e.is_a?(Sketchup::Group)
          res << e if e.get_attribute('a2m', 'mur_id')
          fouiller.call(e.entities, prof + 1) if prof < 2
        end
      end
      fouiller.call(model.active_entities, 0)
      res
    end

    def self.trous(g) (JSON.parse(g.get_attribute('a2m', 'trous', '[]')) rescue []) end

    def self.murs_avec(model, d)
      murs(model).select { |g| trous(g).include?(d['id']) }
    end

    # Rebouche : un bloc à la taille exacte du trou (entre les faces de la couche) réuni au mur
    def self.reboucher(model, d)
      tous = murs(model)
      d['couches'].each do |c|
        g = tous.find { |m| m.valid? && m.get_attribute('a2m', 'mur_id') == c['mur'] && trous(m).include?(d['id']) }
        next unless g
        n = Geom::Vector3d.new(c['n'])
        rect = c['rect'].map { |q| Geom::Point3d.new(q).offset(n, -c['e0']) }
        bloc = g.parent.entities.add_group
        f = bloc.entities.add_face(rect)
        f.reverse! if f.normal.dot(n) > 0
        f.pushpull(c['e1'] - c['e0'])
        att = A2M::Ouvertures.attributs(g)
        nom = g.name; tag = g.layer; mat = g.material
        res = g.union(bloc)
        unless res
          journal("  rebouchage impossible dans « #{g.name} » (mur non solide ?)")
          bloc.erase! if bloc.valid?
          raise "le mur « #{g.name} » n'a pas pu être rebouché"
        end
        journal("  rebouché : « #{nom} »")
        res.name = nom; res.layer = tag; res.material = mat if mat
        att.each { |k, v| res.set_attribute('a2m', k, v) }
        res.set_attribute('a2m', 'trous', JSON.generate(trous(res) - [d['id']]))
        nettoyer(res.entities)
      end
      A2M::Plinthes.retirer(d['id'], model)
      emp = d['empreinte'].map { |q| Geom::Point3d.new(q) }
      A2M::Plinthes.regenerer_autour(emp) if d['genre'] != 'fenetre' && emp.size == 4
    end

    # Arêtes laissées entre deux faces dans le même plan (trace du bouchon) : effacées
    def self.nettoyer(ents)
      ents.grep(Sketchup::Edge).each do |e|
        next unless e.valid? && e.faces.size == 2
        f1, f2 = e.faces
        next unless f1.normal.samedirection?(f2.normal)
        next unless f2.vertices.all? { |v| v.position.distance_to_plane(f1.plane) < TOL }
        next unless f1.material == f2.material && f1.back_material == f2.back_material
        e.erase!
      end
    end

    # Perce à la nouvelle place de la menuiserie (sur le mur qu'elle touche maintenant), la recale au nu intérieur
    def self.recouper(model, r, d)
      t = r.transformation
      ol = d['o']; pr = d['p']
      bas = Geom::Point3d.new(ol['bas']).transform(t)
      u = Geom::Vector3d.new(ol['u']).transform(t); u = Geom::Vector3d.new(u.x, u.y, 0).normalize
      n = Geom::Vector3d.new(ol['n']).transform(t); n = Geom::Vector3d.new(n.x, n.y, 0).normalize
      l = (pr['l'] / 100.0).m; h = (pr['h'] / 100.0).m
      milieu = bas.offset(u, l / 2.0).offset(Z_AXIS, h / 2.0)
      # Nu extérieur du mur à la nouvelle place : premier mur touché par un rayon venant de 60 cm devant
      dep = milieu.offset(n, 60.cm); pt = dep; nu = nil
      10.times do
        hit = model.raytest([pt, n.reverse])
        break unless hit
        haut = A2M::Ouvertures.haut_de(hit[1])
        if haut && haut != r && !haut.get_attribute('a2m', 'ouv')
          nu = hit[0]
          break
        end
        pt = hit[0].offset(n.reverse, 0.02)
      end
      d['couches'] = []; d['empreinte'] = []
      if nu.nil? || (nu - dep).dot(n.reverse) > 1.2.m
        Sketchup.status_text = 'Menuiserie déplacée hors d\'un mur : pas d\'ouverture à percer.'
        d['t'] = t_tab(t)
        ecrire(r, d)
        return
      end
      bas = bas.offset(n, (nu - bas).dot(n))
      o = { bas: bas, u: u, n: n, centre: bas.offset(u, l / 2.0).offset(Z_AXIS, h / 2.0) }
      p = { l: pr['l'], h: pr['h'], n: pr['n'], appui: pr['appui'], type: [pr['lib'], pr['tag']], contigu: pr['contigu'] }
      dec = A2M::Ouvertures.decouper(o, p, d['id'], model)
      journal(dec ? "  repercé dans #{dec[:nb]} couche(s), profondeur #{(dec[:prof].to_f * 2.54).round(1)} cm#{dec[:echecs].any? ? ', échecs : ' + dec[:echecs].join(', ') : ''}" : '  aucun mur trouvé à la nouvelle place')
      raise "perçage impossible dans : #{dec[:echecs].join(', ')}" if dec && dec[:echecs].any?
      if dec
        # Face intérieure au nu intérieur de la dernière couche percée
        defn = r.respond_to?(:definition) ? r.definition : r.entities.parent
        prs = (0..7).map { |i| -((A2M::Bibliotheque.boite_visible(defn).corner(i).transform(r.transformation)) - bas).dot(n) }
        # Porte intérieure : centrée dans l'épaisseur ; menuiserie extérieure : face intérieure au nu intérieur
        dp = pr['tag'] == 'A2M_PORTE_INT' ? dec[:prof] / 2.0 - (prs.min + prs.max) / 2.0 : dec[:prof] - prs.max
        r.transform!(Geom::Transformation.translation(Geom::Vector3d.new(-n.x * dp, -n.y * dp, 0))) if dp.abs > 0.01
        d['couches'] = dec[:couches]
        emp = [bas, bas.offset(u, l), bas.offset(u, l).offset(n, -dec[:prof]), bas.offset(n, -dec[:prof])]
        d['empreinte'] = emp.map(&:to_a)
        if dec[:prof] > 0
          A2M::Plinthes.enregistrer(emp, d['genre'], model, d['id'])
          A2M::Plinthes.regenerer_autour(emp) if d['genre'] != 'fenetre'
        end
      end
      inv = r.transformation.inverse
      d['o'] = { 'bas' => bas.transform(inv).to_a, 'u' => u.transform(inv).to_a, 'n' => n.transform(inv).to_a }
      d['t'] = t_tab(r.transformation)
      ecrire(r, d)
    end
  end
end
