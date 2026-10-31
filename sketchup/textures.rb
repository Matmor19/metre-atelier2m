# encoding: UTF-8
# Métré Atelier 2M : bibliothèque de textures extérieures pour la présentation client.
# Ne touche jamais au métré : les textures sont seulement visuelles.
require 'sketchup.rb'
require 'base64'
require 'json'

module A2M
  module Textures
    CLE = 'A2M_Textures'
    DOSSIER = File.join(File.dirname(__FILE__), 'textures').tr('\\', '/')
    # [titre, dossiers de textures, balises du métré concernées (vide = sélection seulement)]
    CATEGORIES = [
      ['Enduits',             %w[enduits],              %w[A2M_MUR_PERI A2M_MUR_SOUB A2M_MUR_PIGNON]],
      ['Parements, bardages', %w[parements bardages],   %w[A2M_MUR_PERI A2M_MUR_PIGNON]],
      ['Menuiseries (RAL)',   %w[ral],                  %w[A2M_FENETRE A2M_PORTE_FENETRE A2M_PORTE_ENTREE]],
      ['Vitrages',            %w[vitrages],             []],
      ['Toiture',             %w[tuiles],               %w[A2M_TOITURE A2M_TOITURE_2 A2M_TOITURE_3 A2M_TOITURE_4]],
      ['Zinguerie',           %w[zinguerie],            []],
      ['Appuis et seuils',    %w[appuis_seuils],        []]
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
    def self.balises_trouves(ents, balises, trouves = [])
      ents.each do |e|
        next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
        if balises.include?(e.layer.name)
          trouves << e
        else
          balises_trouves(e.entities, balises, trouves)
        end
      end
      trouves
    end

    def self.appliquer(index, dossier, nom)
      model = Sketchup.active_model
      cat = CATEGORIES[index]
      return unless cat && cat[1].include?(dossier) && nom =~ /\A[a-z0-9_]+\z/
      sel = model.selection.to_a.select { |e| e.respond_to?(:material=) }
      cibles = sel.empty? ? balises_trouves(model.entities, cat[2]) : sel
      if cibles.empty?
        UI.messagebox('Rien à texturer. Sélectionnez les éléments (zinguerie, appuis, seuils…), ou balisez-les avec les balises du métré.')
        return
      end
      mat = materiau(model, dossier, nom)
      model.start_operation('Appliquer une texture', true)
      cibles.each { |e| e.material = mat }
      model.commit_operation
      Sketchup.status_text = "#{cibles.size} élément(s) : #{nom_affiche(nom)}"
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
      <<~HTML
        <!doctype html><html lang="fr"><head><meta charset="utf-8"><style>
        :root{--o:#E07838;--g:#3C3C3C;--f:#F6F3EF}
        *{box-sizing:border-box}
        body{margin:0;padding:10px;font:12px "Segoe UI",Arial,sans-serif;background:var(--f);color:var(--g);user-select:none}
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
        <div class="onglets">#{onglets}</div>
        #{sections}
        <script>
        function montrer(i){
          document.querySelectorAll('.onglet').forEach(function(b){b.classList.toggle('actif', b.dataset.i==i)});
          document.querySelectorAll('section').forEach(function(s){s.classList.toggle('actif', s.dataset.i==i)});
        }
        document.querySelectorAll('.onglet').forEach(function(b){b.addEventListener('click',function(){montrer(b.dataset.i)})});
        document.querySelectorAll('.grille button').forEach(function(b){
          b.addEventListener('click',function(){
            sketchup.appliquer(JSON.stringify({i:b.dataset.i,d:b.dataset.d,n:b.dataset.n}));
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
      @dlg = UI::HtmlDialog.new(dialog_title: 'Textures extérieures Atelier 2M', preferences_key: CLE, scrollable: true,
                                resizable: true, width: 560, height: 620, min_width: 360, min_height: 300,
                                style: UI::HtmlDialog::STYLE_DIALOG)
      @dlg.set_html(html)
      @dlg.add_action_callback('appliquer') do |_ctx, json|
        d = JSON.parse(json) rescue nil
        if d
          UI.start_timer(0, false) { appliquer(d['i'].to_i, d['d'], d['n']) }
        end
      end
      @dlg.show
    end
  end
end
