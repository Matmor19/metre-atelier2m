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
        <button type="button" class="carte" id="dernier"><div class="vignette" style="font-size:34px">⬇️</div><span id="dernier_txt">Dernier téléchargement</span></button>
        <button type="button" class="carte" id="fichier"><div class="vignette" style="font-size:34px">📂</div><span>Choisir un fichier .skp</span></button>
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
        if o['cache'] && e.respond_to?(:hidden?) && e.hidden?
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
