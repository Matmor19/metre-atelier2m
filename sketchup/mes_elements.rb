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

    def self.dossier
      base = ENV['USERPROFILE'] || ENV['HOME'] || Dir.home
      doc = File.join(base, 'Documents')
      File.join(File.directory?(doc) ? doc : base, 'Atelier 2M', 'Mes éléments')
    end

    def self.nettoyer(nom) nom.to_s.strip.gsub(%r{[\\/:*?"<>|]}, '_') end

    def self.liste
      d = dossier
      FileUtils.mkdir_p(d) rescue nil
      cats = (CATEGORIES + Dir.children(d).select { |x| File.directory?(File.join(d, x)) }).uniq
      els = []
      cats.each do |c|
        Dir.glob(File.join(d, c, '*.skp')).sort.each do |f|
          png = f.sub(/\.skp\z/, '.png')
          img = File.exist?(png) ? 'data:image/png;base64,' + Base64.strict_encode64(File.binread(png)) : ''
          els << { 'cat' => c, 'nom' => File.basename(f, '.skp'), 'img' => img }
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

    def self.poser(cat, nom)
      fic = File.join(dossier, nettoyer(cat), nettoyer(nom) + '.skp')
      return UI.messagebox('Fichier introuvable : ' + fic) unless File.exist?(fic)
      model = Sketchup.active_model
      d = model.definitions.load(fic)
      model.place_component(d, true)    # pose au clic, répétable ; Échap pour finir
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
      <div id="bas"><div id="msg"></div><button type="button" id="dossier" style="background:#fff;color:#3C3C3C;border:2px solid #d8d0c6;border-radius:10px;padding:8px 12px;cursor:pointer">Ouvrir le dossier</button><button type="button" id="go">Ajouter</button></div>
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
          b.addEventListener('click', function () { sketchup.poser(JSON.stringify({ cat: t.cat, nom: t.nom })); });
          g.appendChild(b);
        });
        el('vide').textContent = l.length ? 'Cliquez un élément pour le poser (clic dans le modèle, Échap pour finir).' : 'Rien ici pour l\'instant : ajoutez votre premier élément ci-dessous.';
      }
      el('go').addEventListener('click', function () { sketchup.ajouter(JSON.stringify({ nom: el('nom').value, cat: el('cat').value })); });
      el('dossier').addEventListener('click', function () { sketchup.dossier(''); });
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
      dlg.add_action_callback('dossier') { |_c, _x| FileUtils.mkdir_p(dossier); UI.openURL('file:///' + dossier.tr('\\', '/')) }
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
