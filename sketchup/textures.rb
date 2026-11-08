# encoding: UTF-8
# Métré Atelier 2M : bibliothèque de textures extérieures pour la présentation client.
# Ne touche jamais au métré : les textures sont seulement visuelles.
require 'sketchup.rb'
require 'base64'
require 'json'
require 'tmpdir'

module A2M
  module Textures
    CLE = 'A2M_Textures'
    DOSSIER = File.join(File.dirname(__FILE__), 'textures').tr('\\', '/')
    # [titre, dossiers de textures, balises du métré concernées (vide = sélection seulement)]
    CATEGORIES = [
      ['Enduits',             %w[enduits],              %w[A2M_MUR_PERI A2M_MUR_SOUB A2M_MUR_PIGNON]],
      ['Parements, bardages', %w[parements bardages],   %w[A2M_MUR_PERI A2M_MUR_PIGNON]],
      ['Menuiseries (RAL)',   %w[ral],                  %w[A2M_FENETRE A2M_PORTE_FENETRE A2M_PORTE_ENTREE]],
      ['Vitrages',            %w[vitrages],             %w[A2M_FENETRE A2M_PORTE_FENETRE A2M_PORTE_ENTREE]],
      ['Toiture',             %w[tuiles],               %w[A2M_TOITURE A2M_TOITURE_2 A2M_TOITURE_3 A2M_TOITURE_4]],
      ['Zinguerie',           %w[zinguerie],            []],
      ['Appuis et seuils',    %w[appuis_seuils],        []],
      ['Gros œuvre',          %w[gros_oeuvre],          []],
      ['Isolants',            %w[isolants],             []],
      ['Panneaux, doublages', %w[panneaux],             []],
      ['Bois brut',           %w[bois],                 []],
      ['Sols',                %w[sols],                 []],
      ['Extérieurs',          %w[exterieurs],           []]
    ]

    # Nom affiché : « ral_9010_blanc_pur » -> « RAL 9010 blanc pur »
    def self.nom_affiche(nom)
      texte = nom.tr('_', ' ').sub(/\Aral /, 'RAL ')
      texte.sub(/\A./) { |c| c.upcase }
    end

    def self.textures(cat)
      cat[1].flat_map do |d|
        Dir.glob("#{DOSSIER}/#{d}/*.jpg").sort.map { |f| [d, File.basename(f, '.jpg')] }
      end
    end

    # Matériau SketchUp créé une seule fois par texture, réutilisé ensuite
    def self.materiau(model, dossier, nom)
      titre = "A2M_Tex_#{dossier}_#{nom}"
      mat = model.materials[titre]
      unless mat
        mat = model.materials.add(titre)
        mat.texture = "#{DOSSIER}/#{dossier}/#{nom}.jpg"
      end
      mat
    end

    # Éléments balisés du métré (groupes et composants), y compris dans d'autres groupes
    def self.balises_trouves(ents, balises, trouves = [], avec_tapees = false)
      ents.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        if balises.include?(e.layer.name) || (avec_tapees && e.get_attribute('a2m', 'tapee'))
          trouves << e
        else
          balises_trouves(e.entities, balises, trouves, avec_tapees)
        end
      end
      trouves
    end

    MENUISERIES = %w[A2M_FENETRE A2M_PORTE_FENETRE A2M_PORTE_ENTREE].freeze

    # Toutes les faces d'un élément, avec leur repère (groupes et composants imbriqués)
    def self.faces_avec_repere(ents, tr, sortie = [], nom = '')
      ents.each do |e|
        case e
        when Sketchup::Face then sortie << [e, tr, nom]
        when Sketchup::Group then faces_avec_repere(e.entities, tr * e.transformation, sortie, e.name)
        when Sketchup::ComponentInstance then faces_avec_repere(e.definition.entities, tr * e.transformation, sortie, e.name)
        end
      end
      sortie
    end

    # Vitrage d'une menuiserie : faces planes perpendiculaires à l'épaisseur (le plus petit côté),
    # situées à l'intérieur du contour. Le cadre, lui, touche le contour extérieur.
    def self.vitrages_de(elem)
      ents = elem.is_a?(Sketchup::ComponentInstance) ? elem.definition.entities : elem.entities
      faces = faces_avec_repere(ents, Geom::Transformation.new)
      pts = faces.flat_map { |f, tr| f.vertices.map { |v| v.position.transform(tr).to_a } }
      return [] if pts.empty?
      mins = (0..2).map { |i| pts.map { |p| p[i] }.min }
      maxs = (0..2).map { |i| pts.map { |p| p[i] }.max }
      prof = (0..2).min_by { |i| maxs[i] - mins[i] }   # épaisseur = plus petit côté
      autres = (0..2).to_a - [prof]
      marge = 0.5.cm
      faces.select do |f, tr, groupe|
        next false if %w[Soubassement Panneau].include?(groupe)   # panneaux pleins : pas du vitrage
        n = f.normal.transform(tr)
        next false if n.length.zero?
        next false unless (n.to_a[prof] / n.length).abs > 0.99
        fp = f.vertices.map { |v| v.position.transform(tr).to_a }
        autres.all? do |a|
          fp.map { |p| p[a] }.min > mins[a] + marge && fp.map { |p| p[a] }.max < maxs[a] - marge
        end
      end
    end

    def self.appliquer(index, dossier, nom, couche = nil)
      model = Sketchup.active_model
      couche = nil if couche.to_s.empty?
      cat = CATEGORIES[index]
      return unless cat && cat[1].include?(dossier) && nom =~ /\A[a-z0-9_]+\z/
      sel = model.selection.to_a.select { |e| e.respond_to?(:material=) }
      if couche && !MENUISERIES.include?(couche)
        return appliquer_couche(model, couche, dossier, nom)
      end
      # Menuiseries : la couleur RAL reprend aussi les tapées d'isolation
      cibles = couche ? A2M::Hachures.objets(model, couche) : (sel.empty? ? balises_trouves(model.entities, cat[2], [], dossier == 'ral') : sel)
      if cibles.empty?
        UI.messagebox('Rien à texturer. Sélectionnez les éléments (zinguerie, appuis, seuils…), ou balisez-les avec les balises du métré.')
        return
      end
      mat = materiau(model, dossier, nom)
      model.start_operation('Appliquer une texture', true)
      nb = 0
      cibles.each do |e|
        if e.is_a?(Sketchup::Face)
          e.material = mat
          nb += 1
        elsif MENUISERIES.include?(e.layer.name) && %w[ral vitrages].include?(dossier)
          # Menuiserie : le vitrage ou le cadre (tout le reste) reçoit la texture, pas l'autre partie
          vitres = vitrages_de(e)
          if dossier == 'vitrages'
            vitres.each { |f, _| f.material = mat; nb += 1 }
          else
            toutes = faces_avec_repere(e.is_a?(Sketchup::ComponentInstance) ? e.definition.entities : e.entities, Geom::Transformation.new)
            cadre = toutes.map(&:first) - vitres.map(&:first)
            cadre = toutes.map(&:first) if cadre.empty?
            cadre.each { |f| f.material = mat; nb += 1 }
          end
        else
          e.material = mat
          nb += 1
        end
      end
      model.commit_operation
      if dossier == 'vitrages' && nb.zero?
        UI.messagebox('Aucun vitrage détecté sur ces menuiseries. Sélectionnez la face vitrée et cliquez à nouveau la texture.')
        return
      end
      Sketchup.status_text = "#{nb} face(s) ou élément(s) : #{nom_affiche(nom)}"
    end

    # Une couche (balise) reçoit la texture : tous ses objets, et les prochains qui seront dessinés
    def self.appliquer_couche(model, couche, dossier, nom)
      mat = materiau(model, dossier, nom)
      A2M::TexturesAuto.enregistrer(couche, mat.name)
      cibles = A2M::Hachures.objets(model, couche)
      model.start_operation('Texture de la couche (métré)', true)
      n = cibles.sum { |e| A2M::TexturesAuto.appliquer(e, model, true) }
      model.commit_operation
      Sketchup.status_text = cibles.empty? ? "#{nom_affiche(nom)} : aucun objet pour l'instant, elle sera posée sur les prochains." : "#{cibles.size} objet(s) : #{nom_affiche(nom)}"
      n
    end

    def self.retirer_couche(couche)
      model = Sketchup.active_model
      A2M::TexturesAuto.enregistrer(couche, nil)
      model.start_operation('Retirer la texture de la couche (métré)', true)
      A2M::Hachures.objets(model, couche).each { |e| A2M::TexturesAuto.effacer(e) }
      model.commit_operation
    end

    # Couches proposées : nom, libellé, nombre d'objets dans le modèle, texture actuelle
    def self.couches_page(model = Sketchup.active_model)
      (A2M::Hachures::BALISES + MENUISERIES).uniq.map do |b|
        t = A2M::TexturesAuto.nom_couche(b)
        { 'b' => b, 'lib' => A2M::Hachures.libelle(b), 'nb' => (A2M::Hachures.objets(model, b).size rescue 0), 'tex' => t.sub(/\AA2M_Tex_[a-z_]+?_/, '') }
      end
    end

    # Mes textures : matières A2M_ rangées dans Mes éléments > Textures, plus celles du modèle ouvert
    def self.mes_textures
      res = {}
      (A2M::MesElements.liste['els'] rescue []).select { |e| e['tex'] }.each { |e| res[e['nom']] = e['img'].to_s }
      model = Sketchup.active_model
      model.materials.to_a.select { |m| m.name =~ /\Aa2m_/i && !m.name.start_with?('A2M_Tex_') }.each do |m|
        nom = A2M::MesElements.nettoyer(m.name)
        next if res[nom] && !res[nom].empty?
        img = ''
        begin
          if m.texture
            f = File.join(Dir.tmpdir, "a2m_mat_#{nom.gsub(/[^A-Za-z0-9]/, '_')}.png")
            m.texture.write(f)
            img = 'data:image/png;base64,' + Base64.strict_encode64(File.binread(f)) if File.size(f) < 400_000
          else
            c = m.color
            img = "color:rgb(#{c.red},#{c.green},#{c.blue})"
          end
        rescue StandardError
          img = ''
        end
        res[nom] = img
      end
      res.sort_by { |n, _| n.downcase }
    end

    # Une matière « Mes textures » : sur la couche choisie, sinon sur la sélection (ou pot de peinture)
    def self.appliquer_mes(nom, couche)
      model = Sketchup.active_model
      couche = nil if couche.to_s.empty?
      fic = File.join(A2M::MesElements.dossier, A2M::MesElements::TEX, A2M::MesElements.nettoyer(nom) + '.skm')
      mat = model.materials[nom] || (File.exist?(fic) ? model.materials.load(fic) : nil)
      return UI.messagebox("Matière introuvable : #{nom}") unless mat
      if couche && !MENUISERIES.include?(couche)
        A2M::TexturesAuto.enregistrer(couche, mat.name)
        cibles = A2M::Hachures.objets(model, couche)
        model.start_operation('Texture de la couche (métré)', true)
        cibles.each { |e| A2M::TexturesAuto.appliquer(e, model, true) }
        model.commit_operation
        Sketchup.status_text = "#{cibles.size} objet(s) : #{nom}"
      else
        A2M::MesElements.appliquer_texture(nom)
      end
    end

    def self.html
      onglets = CATEGORIES.each_with_index.map { |c, i| "<button class=\"onglet\" data-i=\"#{i}\">#{c[0]}</button>" }.join
      sections = CATEGORIES.each_with_index.map do |cat, i|
        vignettes = textures(cat).map do |d, nom|
          chemin = File.join(DOSSIER, 'miniatures', d, nom + '.jpg')
          img = File.exist?(chemin) ? Base64.strict_encode64(File.binread(chemin)) : ''
          "<button data-i=\"#{i}\" data-d=\"#{d}\" data-n=\"#{nom}\" title=\"#{nom_affiche(nom)}\"><img src=\"data:image/jpeg;base64,#{img}\" alt=\"\"><span>#{nom_affiche(nom)}</span></button>"
        end.join
        "<section data-i=\"#{i}\"><p class=\"aide\">#{cat[2].empty? ? 'Sélectionnez les éléments avant de cliquer une texture.' : 'Sans sélection : s\'applique à tous les éléments balisés de cette catégorie. Avec une sélection : à la sélection.'}</p><div class=\"grille\">#{vignettes}</div></section>"
      end.join
      mes = mes_textures
      onglets += "<button class=\"onglet\" data-i=\"mes\">Mes textures (#{mes.size})</button>"
      vign = mes.map do |nom, img|
        pic = img.start_with?('data:') ? "<img src=\"#{img}\" alt=\"\">" : "<div style=\"width:100px;height:100px;border-radius:6px;margin:0 auto 5px;background:#{img.start_with?('color:') ? img[6..-1] : '#ddd'}\"></div>"
        "<button data-i=\"mes\" data-d=\"mes\" data-n=\"#{nom}\" title=\"#{nom}\">#{pic}<span>#{nom.sub(/\AA2M_/, '').tr('_', ' ')}</span></button>"
      end.join
      sections += "<section data-i=\"mes\"><p class=\"aide\">Vos matières A2M_ (Mes éléments > Textures et modèle ouvert). Choisissez la couche à gauche, puis cliquez la matière.</p><div class=\"grille\">#{vign.empty? ? 'Aucune matière A2M_ trouvée.' : vign}</div></section>"
      <<~HTML
        <!doctype html><html lang="fr"><head><meta charset="utf-8"><style>
        :root{--o:#E07838;--g:#3C3C3C;--f:#F6F3EF}
        *{box-sizing:border-box}
        body{margin:0;padding:10px;font:12px "Segoe UI",Arial,sans-serif;background:var(--f);color:var(--g);user-select:none}
        .cadre{display:flex;gap:14px;align-items:flex-start}
        .gauche{width:250px;flex:none;position:sticky;top:10px;max-height:94vh;overflow:auto;padding-right:4px}
        .droite{flex:1;min-width:0}
        h3{margin:0 0 8px;font-size:13px;color:var(--o)}
        .lc{display:block;width:100%;text-align:left;border:2px solid #e3dbd1;background:#fff;border-radius:10px;padding:8px 10px;margin-bottom:6px;cursor:pointer;font:inherit}
        .lc small{display:block;color:#8a7f75;font-size:11px;margin-top:2px}
        .lc.sel{border-color:var(--o);background:#fdeedd}
        .lc.sel b{color:#c9672f}
        .onglets{display:flex;flex-wrap:wrap;gap:6px;margin-bottom:10px}
        .onglet{border:1px solid #d6cdc3;background:#fff;border-radius:16px;padding:5px 11px;cursor:pointer;font:inherit}
        .onglet.actif{background:var(--o);border-color:var(--o);color:#fff}
        section{display:none}
        section.actif{display:block}
        .aide{color:#6f665e;font-size:11.5px;margin:0 0 8px}
        .grille{display:grid;grid-template-columns:repeat(auto-fill,minmax(112px,1fr));gap:10px}
        .grille button{border:0;background:#fff;border-radius:9px;padding:6px;cursor:pointer;text-align:center;box-shadow:0 1px 3px rgba(0,0,0,.12);transition:transform .14s,box-shadow .14s}
        .grille button:hover{transform:translateY(-2px);box-shadow:0 6px 12px rgba(224,120,56,.35)}
        .grille img{width:100px;height:100px;object-fit:cover;border-radius:6px;display:block;margin:0 auto 5px}
        .grille span{font-size:11px;line-height:1.25;display:block}
        </style></head><body>
        <div class="cadre"><div class="gauche"><h3>1. Choisissez la couche</h3><div id="liste"></div><button id="retirer" type="button" class="onglet" style="display:none;margin-top:8px">Retirer la texture de cette couche</button></div>
        <div class="droite"><h3>2. Cliquez la texture</h3><div id="ccouche" class="aide"></div><div class="onglets">#{onglets}</div>
        #{sections}</div></div>
        <script>
        var COUCHES=#{JSON.generate(couches_page).gsub('</', '<\\/')}, courant='';
        function remplir(){
          var L=document.getElementById('liste');
          var h='<button type="button" class="lc'+(courant===''?' sel':'')+'" data-b=""><b>Sélection</b><small>ou toutes les couches de la catégorie</small></button>';
          COUCHES.forEach(function(c){h+='<button type="button" class="lc'+(courant===c.b?' sel':'')+'" data-b="'+c.b+'"><b>'+c.lib+'</b><small>'+c.nb+' objet(s)'+(c.tex?' · '+c.tex:' · pas de texture')+'</small></button>'});
          L.innerHTML=h;
          L.querySelectorAll('.lc').forEach(function(b){b.onclick=function(){courant=b.dataset.b; remplir()}});
          info();
        }
        function info(){
          var c=COUCHES.filter(function(x){return x.b===courant})[0];
          document.getElementById('retirer').style.display=c&&c.tex?'':'none';
          document.getElementById('ccouche').innerHTML=c?('Couche choisie : <b>'+c.lib+'</b>. Cliquez une texture : elle est posée sur les '+c.nb+' objet(s) de cette couche et sur les prochains que vous dessinerez.'):'Aucune couche choisie : la texture va sur la sélection, ou sur les éléments balisés de la catégorie.';
        }
        document.getElementById('retirer').onclick=function(){if(courant) sketchup.retirer(courant)};
        function majCouches(d){COUCHES=d; remplir()}
        remplir();
        function montrer(i){
          document.querySelectorAll('.onglet').forEach(function(b){b.classList.toggle('actif', b.dataset.i==i)});
          document.querySelectorAll('section').forEach(function(s){s.classList.toggle('actif', s.dataset.i==i)});
        }
        document.querySelectorAll('.onglet').forEach(function(b){b.addEventListener('click',function(){montrer(b.dataset.i)})});
        document.querySelectorAll('.grille button').forEach(function(b){
          b.addEventListener('click',function(){
            sketchup.appliquer(JSON.stringify({i:b.dataset.i,d:b.dataset.d,n:b.dataset.n,c:courant}));
          });
        });
        montrer(0);
        </script></body></html>
      HTML
    end

    def self.ouvrir
      if @dlg && @dlg.visible?
        @dlg.bring_to_front
        return
      end
      @dlg = UI::HtmlDialog.new(dialog_title: 'Textures extérieures Atelier 2M', preferences_key: CLE + '2', scrollable: true,
                                resizable: true, width: 940, height: 700, min_width: 640, min_height: 400,
                                style: UI::HtmlDialog::STYLE_DIALOG)
      @dlg.set_html(html)
      @dlg.add_action_callback('appliquer') do |_ctx, json|
        d = JSON.parse(json) rescue nil
        if d
          UI.start_timer(0, false) do
            d['d'] == 'mes' ? appliquer_mes(d['n'], d['c']) : appliquer(d['i'].to_i, d['d'], d['n'], d['c'])
            @dlg.execute_script("majCouches(#{JSON.generate(couches_page)})") rescue nil
          end
        end
      end
      @dlg.add_action_callback('retirer') do |_ctx, couche|
        UI.start_timer(0, false) do
          retirer_couche(couche.to_s)
          @dlg.execute_script("majCouches(#{JSON.generate(couches_page)})") rescue nil
        end
      end
      @dlg.show
    end
  end
end
