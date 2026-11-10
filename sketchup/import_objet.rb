# encoding: UTF-8
# Métré Atelier 2M : importer un objet (3D Warehouse ou fichier .skp), le nettoyer, puis le ranger dans la bibliothèque
# Chaîne : recherche / fichier  →  import au point 0  →  nettoyage (balises, géométrie parasite, matières inutiles)
#          →  « Paramétrer un objet » (axe, type, étirement, vignette 2D aux couleurs d'origine, rangement)
require 'sketchup.rb'
require 'json'
require 'uri'

module A2M
  module ImportObjet
    ENTREPOT = 'https://3dwarehouse.sketchup.com/search/?q=%s&domain=live'

    CORPS = <<~'HTML'
      <h2>1. Trouver l'objet</h2>
      <div style="display:flex;gap:8px">
        <input type="text" id="q" placeholder="Ex. : fenêtre PVC 2 vantaux, porte d'entrée, canapé…" autocomplete="off" style="flex:1;font:13px 'Segoe UI',Arial,sans-serif;text-align:left;padding:8px 12px">
        <button type="button" class="puce" id="chercher">Chercher sur la 3D Warehouse</button>
      </div>
      <div class="petit">Le site s'ouvre dans votre navigateur : téléchargez le modèle en .skp (bouton « Télécharger »), puis revenez ici.</div>
      <h2>2. Récupérer le fichier</h2>
      <div class="grille">
        <button type="button" class="carte" id="dernier"><div class="vignette"><svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1" stroke-linejoin="round" stroke-linecap="round"><path d="M24 4 V22 M17 15 L24 22 L31 15" stroke="#E07838" stroke-width="1.6"/><rect x="8" y="26" width="32" height="10" rx="2" fill="#fff"/><path d="M14 31 H34"/></svg></div><span id="dernier_txt">Dernier téléchargement</span></button>
        <button type="button" class="carte" id="fichier"><div class="vignette"><svg viewBox="0 0 48 40" width="60" height="50" fill="none" stroke="#3C3C3C" stroke-width="1" stroke-linejoin="round"><path d="M6 12 V32 H42 V16 H22 L18 10 H8 Q6 10 6 12 Z" fill="#E6C58F"/><path d="M6 20 H42"/></svg></div><span>Choisir un fichier .skp</span></button>
      </div>
      <h2>3. Nettoyage automatique</h2>
      <div class="puces" id="nett"></div>
      <div class="petit">Cliquez une pastille pour la décocher. Le nettoyage ne touche que l'objet importé.</div>
      <div class="apercu" style="padding:10px 12px;margin-top:14px;font-size:12px;color:#6f665e">Ensuite : vous placez l'axe, choisissez le type d'objet (fenêtre, porte…) puis il est rangé dans la bibliothèque avec sa vignette aux couleurs d'origine.</div>
      <div id="bas"><div id="msg">Choisissez d'abord un fichier .skp.</div></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      var opts = {}; D.nettoyages.forEach(function (n) { opts[n.cle] = true; });
      function puces() {
        var c = el('nett'); c.innerHTML = '';
        D.nettoyages.forEach(function (n) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (opts[n.cle] ? ' rempli' : ''); b.textContent = n.libelle;
          b.addEventListener('click', function () { opts[n.cle] = !opts[n.cle]; puces(); }); c.appendChild(b);
        });
      }
      el('dernier_txt').textContent = D.dernier ? 'Dernier téléchargement : ' + D.dernier : 'Aucun .skp récent dans Téléchargements';
      if (!D.dernier) el('dernier').style.opacity = .5;
      function chercher() { var t = el('q').value.trim(); if (t) sketchup.chercher(t); }
      el('chercher').addEventListener('click', chercher);
      el('q').addEventListener('keydown', function (e) { if (e.key === 'Enter') chercher(); });
      el('dernier').addEventListener('click', function () { if (D.dernier) sketchup.importer(JSON.stringify({ source: 'dernier', opts: opts })); });
      el('fichier').addEventListener('click', function () { sketchup.importer(JSON.stringify({ source: 'fichier', opts: opts })); });
      puces();
    JS

    NETTOYAGES = [
      { 'cle' => 'balises',  'libelle' => 'Balises remises à « Sans balise »' },
      { 'cle' => 'cache',    'libelle' => 'Éléments masqués supprimés' },
      { 'cle' => 'parasites', 'libelle' => 'Cotes, textes, guides supprimés' },
      { 'cle' => 'aretes',   'libelle' => 'Arêtes isolées supprimées' },
      { 'cle' => 'inutiles', 'libelle' => 'Composants, matières et styles inutilisés purgés' }
    ].freeze

    def self.dernier_telechargement
      base = ENV['USERPROFILE'] || ENV['HOME'] || ''
      f = Dir.glob(File.join(base, 'Downloads', '*.skp')).max_by { |p| File.mtime(p) }
      f && (Time.now - File.mtime(f)) < 6 * 3600 ? f : nil
    rescue StandardError
      nil
    end

    # Un élément masqué n'est effacé que s'il est vraiment parasite. Les arêtes masquées (diagonales d'un maillage de tuile,
    # d'une coque, d'une surface courbe) et les faces qui les touchent font partie de la forme : les effacer troue l'objet.
    def self.effacable_masque?(e)
      case e
      when Sketchup::Edge then false
      when Sketchup::Face then e.edges.all? { |x| x.faces.size <= 1 }   # face isolée seulement
      else true
      end
    end

    # Nettoie une définition (et ses sous-composants) ; renvoie le nombre d'éléments retirés
    def self.nettoyer(defn, o, vus = {})
      return 0 if vus[defn]
      vus[defn] = true
      n = 0
      model = defn.model
      a_effacer = []
      defn.entities.each do |e|
        if o['balises'] && e.respond_to?(:layer=) && e.layer != model.layers[0]
          e.layer = model.layers[0]
        end
        if o['cache'] && e.respond_to?(:hidden?) && e.hidden? && effacable_masque?(e)
          a_effacer << e
        elsif o['parasites'] && (e.is_a?(Sketchup::ConstructionPoint) || e.is_a?(Sketchup::ConstructionLine) || e.is_a?(Sketchup::Text) || e.is_a?(Sketchup::Dimension))
          a_effacer << e
        elsif o['aretes'] && e.is_a?(Sketchup::Edge) && e.faces.empty?
          a_effacer << e
        end
      end
      defn.entities.erase_entities(a_effacer.select(&:valid?)) unless a_effacer.empty?
      n += a_effacer.size
      defn.entities.each do |e|
        n += nettoyer(e.definition, o, vus) if e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
      end
      n
    end

    # ---- Contrôler et préparer un objet déjà dans le modèle (sans passer par un fichier) ----
    def self.faces_de(defn, vus = {}, acc = [])
      return acc if vus[defn]
      vus[defn] = true
      defn.entities.each do |e|
        if e.is_a?(Sketchup::Face) then acc << e
        elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) then faces_de(e.definition, vus, acc)
        end
      end
      acc
    end

    # Referme les petits trous (3 ou 4 arêtes de bord) : faces supprimées par erreur dans un maillage.
    # Les grandes ouvertures (dessous d'une coque, bout ouvert) ont plus d'arêtes et sont laissées telles quelles.
    def self.combler_trous(defn)
      ents = defn.entities
      bord = ents.grep(Sketchup::Edge).select { |e| e.faces.size == 1 }
      par_sommet = Hash.new { |h, k| h[k] = [] }
      bord.each { |e| par_sommet[e.start] << e; par_sommet[e.end] << e }
      vus = {}; n = 0
      bord.each do |e0|
        next if vus[e0]
        chaine = [e0]; sommets = [e0.start]; v = e0.end; ok = true
        while v != e0.start
          suivantes = par_sommet[v].reject { |x| x == chaine.last }
          if suivantes.size != 1 || chaine.size > 4 then ok = false; break end
          x = suivantes[0]
          chaine << x; sommets << v
          v = (x.start == v ? x.end : x.start)
        end
        next unless ok && chaine.size.between?(3, 4)
        chaine.each { |x| vus[x] = true }
        pts = sommets.map(&:position)
        begin
          ents.add_face(pts)
        rescue StandardError
          ents.add_face(pts[0], pts[1], pts[2]) rescue nil
          ents.add_face(pts[0], pts[2], pts[3]) rescue nil if pts.size == 4
        end
        n += 1
      end
      n
    end

    # Met toutes les faces d'une même pièce dans le même sens (arête parcourue en sens inverse par ses deux faces),
    # puis tourne la pièce entière pour que les faces regardent vers l'extérieur. Renvoie le nombre de faces retournées.
    def self.orienter_faces(defn)
      faces = defn.entities.grep(Sketchup::Face)
      vus = {}; retournees = 0
      faces.each do |seed|
        next if vus[seed] || !seed.valid?
        vus[seed] = true
        piece = [seed]; file = [seed]
        until file.empty?
          f = file.shift
          f.edges.each do |e|
            fs = e.faces
            next unless fs.size == 2
            g = fs[0] == f ? fs[1] : fs[0]
            next if vus[g]
            vus[g] = true
            if e.reversed_in?(f) == e.reversed_in?(g)
              g.reverse!; retournees += 1
            end
            piece << g; file << g
          end
        end
        centre = Geom::BoundingBox.new
        piece.each { |f| centre.add(f.bounds) }
        c = centre.center
        s = piece.sum { |f| f.normal.dot(f.bounds.center - c) * f.area }
        if s < 0
          piece.each(&:reverse!)
          retournees += piece.size
        end
      end
      retournees
    end

    def self.controler
      model = Sketchup.active_model
      sel = model.selection.to_a
      return UI.messagebox('Sélectionnez l\'objet à contrôler (groupe ou composant, ou ses morceaux), puis relancez la commande.') if sel.empty?
      rapport = []; alertes = []
      model.start_operation('Contrôler et préparer un objet', true)
      begin
        # 1. Un seul objet : les morceaux sélectionnés sont réunis dans un composant
        inst = sel.size == 1 && (sel[0].is_a?(Sketchup::Group) || sel[0].is_a?(Sketchup::ComponentInstance)) ? sel[0] : nil
        if inst.nil?
          g = model.active_entities.add_group(sel)
          inst = g.to_component
          rapport << "#{sel.size} morceaux réunis en un seul composant"
        elsif inst.is_a?(Sketchup::Group)
          inst = inst.to_component
          rapport << 'Groupe transformé en composant'
        end
        if inst.definition.count_instances > 1
          inst.make_unique
          rapport << 'Copie indépendante créée (les autres exemplaires ne sont pas touchés)'
        end
        d = inst.definition
        # 2. Nettoyage (mêmes réglages que l'import)
        o = { 'balises' => true, 'cache' => true, 'parasites' => true, 'aretes' => true, 'inutiles' => true }
        inst.layer = model.layers[0]
        n = nettoyer(d, o)
        rapport << "#{n} élément(s) parasite(s) retiré(s) (masqués, cotes, textes, guides, arêtes isolées)" if n > 0
        # 3. Faces : trous refermés, toutes les faces dans le même sens (vers l'extérieur), puis couleur à l'extérieur
        comblees = combler_trous(d)
        rapport << "#{comblees} petit(s) trou(s) refermé(s) (faces manquantes)" if comblees > 0
        retournees = orienter_faces(d)
        faces = faces_de(d)
        av = 0.0; ar = 0.0
        faces.each { |f| next unless f.valid?; av += f.area if f.material; ar += f.area if f.back_material && f.material.nil? }
        if ar > av && ar > 0
          faces.each { |f| f.reverse! if f.valid? }
          retournees += faces.size
        end
        rapport << "#{retournees} face(s) retournée(s) (sens des faces rendu cohérent, couleur à l'extérieur)" if retournees > 0
        # 4. Taille réelle
        bb = d.bounds
        dims = [bb.width, bb.height, bb.depth].map { |x| (x.to_f * 2.54).round(1) }
        plus_grand = dims.max
        if plus_grand > 600 || plus_grand < 3
          rep = UI.inputbox(["Taille douteuse : #{dims[0]} × #{dims[1]} × #{dims[2]} cm. Plus grande dimension réelle (cm)"], [plus_grand.round], 'Mettre l\'objet à l\'échelle')
          if rep && rep[0].to_f > 0 && rep[0].to_f != plus_grand
            k = rep[0].to_f / plus_grand
            inst.transform!(Geom::Transformation.scaling(inst.bounds.center, k))
            rapport << "Mis à l'échelle (× #{k.round(3)})"
            bb = d.bounds
            dims = [bb.width, bb.height, bb.depth].map { |x| (x.to_f * 2.54 * k).round(1) }
          end
        end
        rapport << "Dimensions : #{dims[0]} × #{dims[1]} × #{dims[2]} cm (largeur × profondeur × hauteur)"
        # 5. Poids du modèle
        nf = faces.size
        alertes << "Objet lourd (#{nf} faces) : le modèle risque de ramer. Cherchez une version plus légère ou simplifiez-le." if nf > 60_000
        rapport << "#{nf} faces"
        # 6. Échelle non uniforme sur l'instance
        sc = inst.transformation.to_a
        ex = Math.sqrt(sc[0]**2 + sc[1]**2 + sc[2]**2); ey = Math.sqrt(sc[4]**2 + sc[5]**2 + sc[6]**2); ez = Math.sqrt(sc[8]**2 + sc[9]**2 + sc[10]**2)
        if [ex, ey, ez].max - [ex, ey, ez].min > 0.001
          alertes << 'L\'objet a été étiré de façon inégale (déformé). Vérifiez ses proportions.'
        end
        # 7. Nom
        nom = d.name.to_s
        if nom.empty? || nom =~ /\A(#|sprite|component|composant)/i
          alertes << "Nom peu clair (« #{nom} ») : renommez la définition dans « Infos sur l'entité » avant de la ranger."
        end
        purger(model)
        rapport << 'Matières, composants et styles inutilisés purgés'
        model.commit_operation
      rescue StandardError => ex
        model.abort_operation
        return UI.messagebox("Contrôle impossible : #{ex.message}")
      end
      model.selection.clear
      model.selection.add(inst)
      txt = "Objet contrôlé et préparé :\n\n- " + rapport.join("\n- ")
      txt += "\n\nÀ vérifier vous-même :\n- " + alertes.join("\n- ") if alertes.any?
      txt += "\n\nLe ranger maintenant dans la bibliothèque (avec ses images 2D) ?"
      A2M::Bibliotheque.parametrer if UI.messagebox(txt, MB_YESNO) == IDYES
    end

    def self.purger(model)
      model.definitions.purge_unused
      model.materials.purge_unused
      model.styles.purge_unused rescue nil
    end

    def self.importer(chemin, o)
      model = Sketchup.active_model
      model.start_operation('Importer un objet', true)
      begin
        defn = model.definitions.load(chemin)
        inst = model.active_entities.add_instance(defn, Geom::Transformation.new)
        inst.make_unique
        n = nettoyer(inst.definition, o)
        purger(model) if o['inutiles']
        model.commit_operation
        model.selection.clear
        model.selection.add(inst)
        Sketchup.active_model.active_view.zoom(inst)
        UI.messagebox("« #{File.basename(chemin, '.skp')} » importé et nettoyé (#{n} élément(s) retiré(s)).\nPlacez maintenant l'axe : deux clics sur le bord bas de la face avant, vue de l'extérieur (coin gauche, puis coin droit). Échap : détection automatique.")
        model.select_tool(OutilAxe.new do |dir|
          A2M::Bibliotheque.axe_impose = dir
          A2M::Bibliotheque.parametrer
        end)
      rescue StandardError => ex
        model.abort_operation
        UI.messagebox("Import impossible : #{ex.message}")
      end
    end


    # Outil « Axe » : deux clics sur le bord bas de la face avant (coin gauche, puis coin droit, vu de l'extérieur)
    class OutilAxe
      def initialize(&suite)
        @suite = suite; @p1 = nil; @ip = Sketchup::InputPoint.new
      end

      def activate
        message
      end

      def message
        Sketchup.status_text = @p1 ? 'Axe : cliquez le coin BAS DROIT de la face avant (Échap : détection automatique)' :
                                     'Axe : cliquez le coin BAS GAUCHE de la face avant, vue de l\'extérieur (Échap : détection automatique)'
      end

      def onMouseMove(_f, x, y, view)
        @ip.pick(view, x, y)
        view.tooltip = @ip.tooltip
        view.invalidate
      end

      def onLButtonDown(_f, x, y, view)
        @ip.pick(view, x, y)
        return unless @ip.valid?
        if @p1.nil?
          @p1 = @ip.position
          message
        else
          v = @ip.position - @p1
          dir = Geom::Vector3d.new(v.x, v.y, 0)
          return Sketchup.status_text = 'Choisissez un point plus à droite, au même niveau.' if dir.length < 0.4
          terminer(dir)
        end
      end

      def onCancel(_r, _v)
        terminer(nil)
      end

      def draw(view)
        pt = @ip.valid? ? @ip.position : nil
        @ip.draw(view) if pt
        return unless @p1 && pt
        view.line_stipple = ''
        view.line_width = 3
        view.drawing_color = Sketchup::Color.new(224, 120, 56)
        view.draw_lines(@p1, pt)
      end

      def terminer(dir)
        return if @fini
        @fini = true
        Sketchup.active_model.select_tool(nil)
        UI.start_timer(0, false) { @suite.call(dir) }
      end
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      d = dernier_telechargement
      html = A2M::Panneau.page('Importer un objet', 'Depuis la 3D Warehouse ou un fichier .skp, nettoyé et rangé dans la bibliothèque', CORPS, SCRIPT,
                               'nettoyages' => NETTOYAGES, 'dernier' => d && File.basename(d))
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : importer un objet', 'A2M_Panneau_Import', html, 520, 640)
      @fen = dlg
      dlg.add_action_callback('chercher') do |_c, t|
        UI.openURL(format(ENTREPOT, URI.encode_www_form_component(t.to_s)))
      end
      dlg.add_action_callback('importer') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        next unless r
        chemin = r['source'] == 'dernier' ? dernier_telechargement : UI.openpanel('Fichier SketchUp à importer', File.join(ENV['USERPROFILE'].to_s, 'Downloads'), 'SketchUp|*.skp||')
        UI.start_timer(0, false) { importer(chemin, r['opts'] || {}) } if chemin && File.exist?(chemin)
      end
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
