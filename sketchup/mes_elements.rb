# encoding: UTF-8
# Métré Atelier 2M : « Mes éléments », votre bibliothèque personnelle (menuiseries, tuiles, zinguerie, mobilier…).
# Ajoutez la sélection en un clic (le point d'insertion est le milieu du bas de l'objet), puis posez-la au clic dans le modèle.
require 'sketchup.rb'
require 'json'
require 'base64'
require 'fileutils'

module A2M
  module MesElements
    CATEGORIES = ['Menuiseries', 'Couverture', 'Zinguerie', 'Charpente', 'Sanitaire', 'Mobilier', 'Divers'].freeze
    TEX = 'Textures'.freeze   # matières A2M_ du modèle : fichiers .skm (taille réelle du motif comprise) rangés dans ce dossier

    def self.dossier
      base = ENV['USERPROFILE'] || ENV['HOME'] || Dir.home
      doc = File.join(base, 'Documents')
      File.join(File.directory?(doc) ? doc : base, 'Atelier 2M', 'Mes éléments').tr('\\', '/')
    end

    def self.nettoyer(nom) nom.to_s.strip.gsub(%r{[\\/:*?"<>|]}, '_') end

    def self.liste
      d = dossier
      FileUtils.mkdir_p(d) rescue nil
      cats = (CATEGORIES + [TEX] + Dir.children(d).select { |x| File.directory?(File.join(d, x)) }).uniq
      els = []
      cats.each do |c|
        Dir.glob(File.join(d, c, c == TEX ? '*.skm' : '*.skp')).sort.each do |f|
          png = f.sub(/\.sk[pm]\z/, '.png')
          img = File.exist?(png) ? 'data:image/png;base64,' + Base64.strict_encode64(File.binread(png)) : ''
          els << { 'cat' => c, 'nom' => File.basename(f, c == TEX ? '.skm' : '.skp'), 'img' => img, 'tex' => c == TEX }
        end
      end
      { 'cats' => cats, 'els' => els, 'dossier' => d }
    end

    def self.ajouter(nom, cat)
      model = Sketchup.active_model
      sel = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      return UI.messagebox('Sélectionnez d\'abord un groupe ou un composant (l\'objet à ranger).') if sel.size != 1
      nom = nettoyer(nom); cat = nettoyer(cat)
      return UI.messagebox('Donnez un nom à l\'élément.') if nom.empty?
      cat = 'Divers' if cat.empty?
      dir = File.join(dossier, cat)
      FileUtils.mkdir_p(dir)
      fic = File.join(dir, nom + '.skp')
      return UI.messagebox("« #{nom} » existe déjà dans #{cat}. Choisissez un autre nom.") if File.exist?(fic)
      e = sel.first
      model.start_operation('Ajouter à Mes éléments', true)
      begin
        d = e.is_a?(Sketchup::Group) ? e.definition : e.definition
        bb = d.bounds
        o = Geom::Point3d.new((bb.min.x + bb.max.x) / 2, (bb.min.y + bb.max.y) / 2, bb.min.z)
        d.entities.transform_entities(Geom::Transformation.translation(Geom::Point3d.new(0, 0, 0) - o), d.entities.to_a)
        d.save_as(fic)
        d.save_thumbnail(fic.sub(/\.skp\z/, '.png')) rescue nil
      ensure
        model.abort_operation     # le modèle reste tel qu'il était
      end
      Sketchup.status_text = "« #{nom} » ajouté à Mes éléments (#{cat})."
      true
    end


    # ---- Textures : matières A2M_ du modèle ouvert -> bibliothèque ----
    # Nom rétabli : préfixe A2M_, espaces -> _, suffixe « #2 » retiré
    def self.nom_tex(n)
      b = n.to_s.strip.sub(/\s*#\d+\z/, '').gsub(/\s+/, '_').gsub(/_+/, '_')
      b = b.sub(/\Aa2m_/i, 'A2M_')
      b
    end

    def self.importer_textures
      model = Sketchup.active_model
      mats = model.materials.to_a.select { |m| m.name =~ /\Aa2m_/i }
      mats = mats.reject { |m| m.name.start_with?('A2M_Tex_') }   # celles de la bibliothèque fournie : déjà proposées par « Textures »
      return UI.messagebox("Aucune matière dont le nom commence par A2M_ dans ce modèle.\\nNommez vos textures A2M_Parpaing, A2M_Enduit_Beige…") if mats.empty?
      dir = File.join(dossier, TEX)
      FileUtils.mkdir_p(dir)
      faits = []; renommes = []; doublons = []; sans = []
      mats.each do |m|
        propre = nom_tex(m.name)
        if propre != m.name
          if model.materials[propre] && model.materials[propre] != m
            doublons << "#{m.name} (existe déjà sous #{propre})"
            next
          end
          renommes << "#{m.name} → #{propre}"
          m.name = propre
        end
        nom = nettoyer(m.name)
        fic = File.join(dir, nom + '.skm')
        begin
          m.save_as(fic)
          png = fic.sub(/\.skm\z/, '.png')
          (m.texture ? m.texture.write(png) : nil) rescue nil
          faits << nom
          sans << nom unless m.texture
        rescue StandardError => ex
          doublons << "#{m.name} : #{ex.message}"
        end
      end
      msg = "#{faits.size} texture(s) enregistrée(s) dans Mes éléments > #{TEX}."
      msg += "\n\nNoms rétablis :\n  " + renommes.join("\n  ") unless renommes.empty?
      msg += "\n\nCouleur unie, sans image : " + sans.join(', ') unless sans.empty?
      msg += "\n\nÀ vérifier :\n  " + doublons.join("\n  ") unless doublons.empty?
      UI.messagebox(msg)
      true
    end

    # Applique la matière à la sélection (groupes, composants, faces) ; sans sélection elle devient la matière active du pot de peinture
    def self.appliquer_texture(nom)
      fic = File.join(dossier, TEX, nettoyer(nom) + '.skm')
      return UI.messagebox('Fichier introuvable : ' + fic) unless File.exist?(fic)
      model = Sketchup.active_model
      mat = model.materials[nom] || model.materials.load(fic)
      sel = model.selection.to_a.select { |e| e.respond_to?(:material=) }
      if sel.empty?
        model.materials.current = mat
        Sketchup.status_text = "« #{nom} » est la matière active : utilisez le pot de peinture."
        Sketchup.send_action('selectPaintTool:')
      else
        model.start_operation('Appliquer une texture', true)
        sel.each { |e| e.material = mat }
        model.commit_operation
        Sketchup.status_text = "« #{nom} » appliquée à #{sel.size} élément(s)."
      end
    end

    # Outil de pose : clic = poser, Tab = tourner de 90°, flèche gauche/droite = miroir, flèche haut/bas = coller au sol ou suivre le point visé
    class Poser
      def initialize(defn)
        @d = defn; @angle = 0; @miroir = 1; @sol = true; @pos = nil
      end

      def activate
        maj_statut
      end

      def maj_statut
        Sketchup.status_text = "Mes éléments : clic = poser ; Tab = tourner de 90° (#{@angle}°) ; flèches gauche/droite = miroir ; flèches haut/bas = #{@sol ? 'collé au sol' : 'suit le point visé'} ; Échap = finir"
      end

      def deactivate(view) view.invalidate end
      def resume(view) maj_statut; view.invalidate end

      def transfo
        return nil unless @pos
        z = @sol ? A2M::Plan2D.sol_auto(Sketchup.active_model).cm : @pos.z
        Geom::Transformation.new(Geom::Point3d.new(@pos.x, @pos.y, z)) * Geom::Transformation.rotation(ORIGIN, Z_AXIS, @angle.degrees) * Geom::Transformation.scaling(@miroir, 1, 1)
      end

      def onMouseMove(_flags, x, y, view)
        ip = view.inputpoint(x, y)
        @pos = ip.position
        view.invalidate
      end

      def onKeyDown(key, rpt, _flags, view)
        return false if rpt > 1
        case key
        when 9 then @angle = (@angle + 90) % 360
        when 37, 39 then @miroir = -@miroir
        when 38, 40 then @sol = !@sol
        else return false
        end
        maj_statut; view.invalidate
        true
      end

      def onLButtonDown(_flags, _x, _y, view)
        t = transfo or return
        model = Sketchup.active_model
        model.start_operation('Poser un élément (Mes éléments)', true)
        model.active_entities.add_instance(@d, t)
        model.commit_operation
        view.invalidate
      end

      def onCancel(_reason, _view) Sketchup.active_model.select_tool(nil) end

      def draw(view)
        t = transfo or return
        bb = @d.bounds
        pts = (0..7).map { |i| t * bb.corner(i) }
        view.line_width = 2
        view.drawing_color = 'orange'
        [[0, 1], [1, 3], [3, 2], [2, 0], [4, 5], [5, 7], [7, 6], [6, 4], [0, 4], [1, 5], [2, 6], [3, 7]].each { |a, b| view.draw(GL_LINES, pts[a], pts[b]) }
      end

      def getExtents
        bb = Geom::BoundingBox.new
        if @pos
          r = @d.bounds.diagonal
          bb.add(@pos.offset(Geom::Vector3d.new(r, r, r))); bb.add(@pos.offset(Geom::Vector3d.new(-r, -r, -r)))
        end
        bb
      end
    end

    def self.poser(cat, nom)
      return appliquer_texture(nom) if cat == TEX
      fic = File.join(dossier, nettoyer(cat), nettoyer(nom) + '.skp')
      return UI.messagebox('Fichier introuvable : ' + fic) unless File.exist?(fic)
      model = Sketchup.active_model
      d = model.definitions.load(fic)
      model.select_tool(Poser.new(d))    # pose au clic, répétable ; Échap pour finir
    end

    CORPS = <<~'HTML'
      <h2>Catégorie</h2>
      <div class="puces" id="cats"></div>
      <h2>Éléments</h2>
      <div class="grille" id="liste"></div>
      <div class="petit" id="vide"></div>
      <h2>Ajouter la sélection</h2>
      <div class="dims" style="grid-template-columns:1fr 1fr;"><div><label>Nom</label><input type="text" id="nom" placeholder="Tuile de rive"></div><div><label>Catégorie</label><input type="text" id="cat" placeholder="Couverture"></div></div>
      <div class="petit">Sélectionnez un groupe ou un composant dans le modèle : son point d'insertion devient le milieu du bas de l'objet. Le modèle n'est pas modifié.</div>
      <div id="bas"><div id="msg"></div><button type="button" id="imptex" style="background:#fff;color:#E07838;border:2px solid #E07838;border-radius:10px;padding:8px 12px;cursor:pointer">Importer les textures A2M_ du modèle</button><button type="button" id="dossier" style="background:#fff;color:#3C3C3C;border:2px solid #d8d0c6;border-radius:10px;padding:8px 12px;cursor:pointer">Ouvrir le dossier</button><button type="button" id="go">Ajouter</button></div>
    HTML
    SCRIPT = <<~'JS'
      var D = __DONNEES__; var cur = null;
      function el(i) { return document.getElementById(i); }
      function rendre() {
        var c = el('cats'); c.innerHTML = '';
        D.cats.forEach(function (k) {
          var n = D.els.filter(function (e) { return e.cat === k; }).length;
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (cur === k ? ' rempli' : ''); b.textContent = k + (n ? ' (' + n + ')' : '');
          b.addEventListener('click', function () { cur = (cur === k ? null : k); el('cat').value = cur || ''; rendre(); }); c.appendChild(b);
        });
        var g = el('liste'); g.innerHTML = '';
        var l = D.els.filter(function (e) { return !cur || e.cat === cur; });
        l.forEach(function (t) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'carte';
          b.innerHTML = '<div class="vignette"></div><span></span>';
          if (t.img) { var i = document.createElement('img'); i.src = t.img; b.querySelector('.vignette').appendChild(i); } else { b.querySelector('.vignette').textContent = '◻'; }
          b.querySelector('span').textContent = t.nom;
          b.addEventListener('click', function () { sketchup.poser(JSON.stringify({ cat: t.cat, nom: t.nom })); }); if (t.tex) b.title = 'Clic : applique la texture à la sélection (ou la prend au pot de peinture)';
          g.appendChild(b);
        });
        el('vide').textContent = l.length ? 'Cliquez un élément, puis cliquez dans le modèle pour le poser : Tab tourne de 90°, flèches gauche/droite font le miroir, Échap termine.' : 'Rien ici pour l\'instant : ajoutez votre premier élément ci-dessous.';
      }
      el('go').addEventListener('click', function () { sketchup.ajouter(JSON.stringify({ nom: el('nom').value, cat: el('cat').value })); });
      el('dossier').addEventListener('click', function () { sketchup.dossier(''); });
      el('imptex').addEventListener('click', function () { sketchup.imptex(''); });
      function maj(d) { D = d; rendre(); el('nom').value = ''; }
      rendre();
    JS

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      html = A2M::Panneau.page('Mes éléments', 'Votre bibliothèque personnelle : tuiles, zinc, menuiseries, mobilier…', CORPS, SCRIPT, liste)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : mes éléments', 'A2M_Panneau_MesElements', html, 480, 700)
      @fen = dlg
      dlg.add_action_callback('poser') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) { poser(r['cat'], r['nom']) } if r
      end
      dlg.add_action_callback('ajouter') do |_c, json|
        r = (JSON.parse(json.to_s) rescue nil)
        UI.start_timer(0, false) do
          if r && ajouter(r['nom'], r['cat'])
            dlg.execute_script("maj(#{JSON.generate(liste)})")
          end
        end
      end
      dlg.add_action_callback('imptex') do |_c, _x|
        UI.start_timer(0, false) { dlg.execute_script("maj(#{JSON.generate(liste)})") if importer_textures }
      end
      dlg.add_action_callback('dossier') { |_c, _x| FileUtils.mkdir_p(dossier); UI.openURL('file:///' + dossier.tr('\\', '/')) }
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
