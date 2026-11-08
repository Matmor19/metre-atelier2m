# encoding: UTF-8
# Métré Atelier 2M : vues 2D d'un objet (dessus et face), à sa vraie géométrie, avec ses couleurs et textures d'origine.
# L'objet est copié loin du modèle, photographié en projection parallèle (sans perspective), puis tout est remis comme avant :
# le modèle, la caméra et le style ne changent pas. Les images sont en PNG à fond transparent.
require 'sketchup.rb'
require 'fileutils'

module A2M
  module VueObjet
    LOIN = 100_000.0            # pouces : hors de portée de tout le reste du modèle
    LARGEUR_IMAGE = 1400
    OPTIONS = { 'RenderMode' => 3, 'DrawSilhouettes' => true, 'EdgeDisplayMode' => true, 'DrawGround' => false, 'DrawHorizon' => false,
                'DisplayInstanceAxes' => false, 'DisplaySectionPlanes' => false, 'DisplayWatermarks' => false }.freeze
    # clé => [libellé, direction de l'œil par rapport à l'objet, haut de l'écran]
    VUES = { 'dessus' => ['Vue de dessus', [0, 0, 1], [0, 1, 0]], 'face' => ['Vue de face', [0, -1, 0], [0, 0, 1]] }.freeze

    def self.dossier
      base = ENV['USERPROFILE'] || ENV['HOME'] || Dir.home
      doc = File.join(base, 'Documents')
      File.join(File.directory?(doc) ? doc : base, 'Atelier 2M', 'Vues 2D').tr('\\', '/')
    end

    def self.nom_fichier(n) n.to_s.gsub(/[\\\/:*?"<>|]/, '-').strip.gsub(/\s+/, '_') end

    # Photographie l'instance déjà posée au loin ; renvoie la liste des fichiers écrits
    def self.photographier(model, inst, base, cles, suffixe = '')
      view = model.active_view
      b = inst.bounds
      c = b.center
      aspect = view.vpheight > 0 ? view.vpwidth.to_f / view.vpheight : 1.6
      larg = LARGEUR_IMAGE; haut = (larg / aspect).round
      ecrits = []
      cles.each do |cle|
        lib, dir, up = VUES[cle]
        v = Geom::Vector3d.new(*dir)
        u = Geom::Vector3d.new(*up)
        # étendue de l'objet dans le plan de l'image
        droite = u.cross(v.reverse); droite.normalize!
        pts = (0..7).map { |i| b.corner(i) }
        w = pts.map { |p| (p - c).dot(droite) }; h = pts.map { |p| (p - c).dot(u) }
        ew = w.max - w.min; eh = h.max - h.min
        hauteur = [eh, ew / aspect].max * 1.12
        hauteur = 1.0 if hauteur < 1.0
        eye = c.offset(v, [b.diagonal * 2, 100].max)
        cam = Sketchup::Camera.new(eye, c, u)
        cam.perspective = false
        cam.height = hauteur
        view.camera = cam
        f = "#{base}_#{cle}#{suffixe}.png"
        FileUtils.mkdir_p(File.dirname(f))
        ok = view.write_image(filename: f, width: larg, height: haut, antialias: true, transparent: true)
        if ok && File.exist?(f)
          ecrits << f
          # Taille réelle de l'image (pouces) : permet de la reposer à l'échelle exacte de l'objet
          File.write(f.sub(/\.png\z/, '.dim'), "#{(hauteur * aspect).round(4)} #{hauteur.round(4)} #{ew.round(4)} #{eh.round(4)}") rescue nil
        end
      end
      ecrits
    end

    # Version blanche : toutes les faces en blanc uni (textures et couleurs retirées), arêtes conservées.
    # Appelée seulement à l'intérieur de l'opération annulée à la fin : le modèle n'en garde rien.
    def self.blanchir(ent, blanc)
      return unless ent && ent.valid?
      ent.material = nil rescue nil
      ents = ent.is_a?(Sketchup::Group) ? ent.entities : (ent.respond_to?(:definition) ? ent.definition.entities : nil)
      return unless ents
      ents.each do |e|
        if e.is_a?(Sketchup::Face) then e.material = blanc; e.back_material = blanc
        elsif e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) then blanchir(e, blanc)
        end
      end
    end

    # Images aux couleurs d'origine, puis les mêmes en version blanche (suffixe _blanc)
    def self.deux_versions(model, inst, base, cles)
      res = photographier(model, inst, base, cles)
      blanc = model.materials.add('A2M_blanc_temporaire')
      blanc.color = Sketchup::Color.new(255, 255, 255)
      blanchir(inst, blanc)
      res + photographier(model, inst, base, cles, '_blanc')
    rescue StandardError
      res || []
    end

    # Cadre commun : état sauvegardé, instance au loin fournie par le bloc, tout restauré à la fin
    def self.avec_objet_au_loin(model)
      view = model.active_view
      cam0 = view.camera
      sauve = { eye: cam0.eye, target: cam0.target, up: cam0.up, persp: cam0.perspective?, fov: (cam0.perspective? ? cam0.fov : nil), height: (cam0.perspective? ? nil : cam0.height) }
      ro = model.rendering_options
      anciennes = OPTIONS.keys.map { |k| [k, (ro[k] rescue nil)] }
      bg = ro['BackgroundColor'] rescue nil
      ombres = model.shadow_info['DisplayShadows'] rescue nil
      section = model.entities.active_section_plane rescue nil
      model.start_operation('Vue 2D de l\'objet', true)
      begin
        model.entities.active_section_plane = nil rescue nil
        OPTIONS.each { |k, v| ro[k] = v rescue nil }
        ro['BackgroundColor'] = Sketchup::Color.new(255, 255, 255) rescue nil
        model.shadow_info['DisplayShadows'] = false rescue nil
        yield
      ensure
        model.abort_operation
        anciennes.each { |k, v| ro[k] = v unless v.nil? }
        ro['BackgroundColor'] = bg if bg
        model.shadow_info['DisplayShadows'] = ombres unless ombres.nil?
        model.entities.active_section_plane = section if section rescue nil
        cam = Sketchup::Camera.new(sauve[:eye], sauve[:target], sauve[:up])
        cam.perspective = sauve[:persp]
        sauve[:persp] ? (cam.fov = sauve[:fov] if sauve[:fov]) : (cam.height = sauve[:height] if sauve[:height])
        view.camera = cam
      end
    end

    # À partir d'une définition de composant (rangement en bibliothèque)
    def self.generer(defn, base, cles = VUES.keys)
      model = Sketchup.active_model
      res = []
      avec_objet_au_loin(model) do
        inst = model.entities.add_instance(defn, Geom::Transformation.translation([LOIN, LOIN, 0]))
        res = deux_versions(model, inst, base, cles)
      end
      res
    rescue StandardError => ex
      Sketchup.status_text = "Vue 2D impossible : #{ex.message}"
      []
    end

    # À partir d'un groupe ou composant du modèle (copie placée au loin)
    def self.generer_entite(ent, base, cles = VUES.keys)
      model = Sketchup.active_model
      res = []
      avec_objet_au_loin(model) do
        c = ent.copy
        c.layer = model.layers[0]
        d = Geom::Point3d.new(LOIN, LOIN, 0) - Geom::Point3d.new(c.bounds.center.x, c.bounds.center.y, c.bounds.min.z)
        c.transform!(Geom::Transformation.translation(d))
        c.make_unique if c.respond_to?(:make_unique) && c.is_a?(Sketchup::Group)
        res = deux_versions(model, c, base, cles)
      end
      res
    rescue StandardError => ex
      Sketchup.status_text = "Vue 2D impossible : #{ex.message}"
      []
    end

    # Pose l'image 2D d'un objet de la bibliothèque sur le plan, à l'échelle de l'objet.
    # base : chemin sans extension (…/objet) ; cle : 'dessus' ou 'face' ; blanc : version blanche ;
    # echelle_x / echelle_z : rapport taille voulue / taille d'origine. Renvoie le groupe posé, ou nil.
    def self.poser_image(model, base, cle, blanc, echelle_x = 1.0, echelle_z = 1.0)
      f = "#{base}_#{cle}#{blanc ? '_blanc' : ''}.png"
      dim = f.sub(/\.png\z/, '.dim')
      return nil unless File.exist?(f) && File.exist?(dim)
      w, h = File.read(dim).split.map(&:to_f)
      return nil unless w && h && w > 0 && h > 0
      sx = echelle_x.to_f > 0 ? echelle_x.to_f : 1.0
      sz = cle == 'dessus' ? sx : (echelle_z.to_f > 0 ? echelle_z.to_f : sx)
      grp = model.active_entities.add_group
      grp.name = "Image 2D #{File.basename(base)} (#{cle}#{blanc ? ', blanc' : ''})"
      img = grp.entities.add_image(f, ORIGIN, w * sx, h * sz)
      img.transform!(Geom::Transformation.translation([-w * sx / 2, -h * sz / 2, 0]))
      grp.transform!(Geom::Transformation.rotation(ORIGIN, X_AXIS, 90.degrees)) if cle != 'dessus'
      grp.layer = model.layers[A2M::Plan2D::TAG] || model.layers.add(A2M::Plan2D::TAG) if defined?(A2M::Plan2D::TAG)
      grp
    end

    # Commande : l'élément sélectionné (groupe ou composant) → deux images dans Documents/Atelier 2M/Vues 2D
    def self.lancer
      model = Sketchup.active_model
      sel = model.selection.to_a.select { |e| e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance) }
      return UI.messagebox('Sélectionnez un groupe ou un composant (un meuble, une menuiserie…) puis relancez la commande.') if sel.empty?
      fichiers = []
      sel.each_with_index do |e, i|
        nom = e.name.to_s.empty? ? (e.respond_to?(:definition) ? e.definition.name : '') : e.name
        nom = "objet_#{i + 1}" if nom.to_s.strip.empty?
        fichiers.concat(generer_entite(e, File.join(dossier, nom_fichier(nom))))
      end
      if fichiers.empty?
        UI.messagebox('Les vues 2D n\'ont pas pu être créées.')
      else
        UI.messagebox("#{fichiers.size} image(s) créée(s) dans :\n#{dossier}\n\n#{fichiers.map { |f| File.basename(f) }.join("\n")}")
        UI.openURL("file:///#{dossier}") rescue nil
      end
    end
  end
end
