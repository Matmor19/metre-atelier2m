# encoding: UTF-8
# Métré Atelier 2M : hachures de coupe par type de couche (SketchUp 2027 et plus)
# Une fenêtre montre, pour chaque type de couche (mur, isolant, plaque, cloison, chape…), l'aperçu de sa hachure ;
# un clic sur une couche ouvre la galerie des hachures (celles du modèle et toute la bibliothèque de SketchUp),
# la couleur de fond, l'angle et l'échelle se règlent à côté. Tout s'applique tout de suite dans la vue.
# Chaque couche a sa propre hachure dans le modèle (« A2M · Murs périphériques »…), enregistrée aussi en fichier .skh
# dans Documents\Atelier 2M\Hachures : elle est rechargée toute seule dans les autres modèles.
require 'sketchup.rb'
require 'json'
require 'digest'
require 'fileutils'

module A2M
  module Hachures
    CLE = 'A2M_Metre'
    AUCUNE = '(aucune hachure)'
    PREFIXE = 'A2M · '
    # Balises qui donnent des volumes coupés
    BALISES = %w[A2M_MUR_PERI A2M_MUR_SOUB A2M_MUR_REFEND A2M_MUR_PIGNON A2M_DOUBLAGE A2M_ISOLANT_DOUBLAGE A2M_CLOISON
                 A2M_ISOLANT_SOL A2M_CHAPE A2M_PLANELLE A2M_ISOLANT_PLANELLE A2M_SEMELLE A2M_PIECE A2M_TOITURE A2M_TOITURE_2 A2M_TOITURE_3 A2M_TOITURE_4]

    def self.disponible?(model = Sketchup.active_model)
      model.respond_to?(:hatch_patterns) && Sketchup::Group.method_defined?(:hatch_pattern=)
    end

    def self.dossier
      d = File.join(File.dirname(A2M::Bibliotheque.dossier), 'Hachures')
      FileUtils.mkdir_p(File.join(d, 'apercus'))
      d
    end

    # Réglages : { balise => { 'nom' => hachure du modèle, 'fichier' => .skh, 'source' => motif choisi } }
    # (ancienne forme : { balise => nom de la hachure })
    def self.reglages
      r = JSON.parse(Sketchup.read_default(CLE, 'hachures', '{}').to_s) rescue {}
      r.each_with_object({}) { |(b, v), h| h[b] = v.is_a?(Hash) ? v : { 'nom' => v.to_s, 'source' => v.to_s } }
    end

    def self.enregistrer(r)
      Sketchup.write_default(CLE, 'hachures', JSON.generate(r))
    end

    def self.libelle(b)
      (A2M::Balises::LISTE.find { |n, _, _| n == b } || [nil, b])[1].to_s.sub(/\s*\(.*\)\s*\z/, '')
    end

    def self.nom_couche(b) "#{PREFIXE}#{libelle(b)}" end

    # Hachure d'une couche dans ce modèle ; rechargée depuis son fichier .skh si le modèle ne l'a pas encore
    def self.motif_couche(model, b, r = reglages)
      x = r[b] or return nil
      hp = model.hatch_patterns
      m = hp[x['nom'].to_s] rescue nil
      return m if m
      f = x['fichier'].to_s
      return nil if f.empty? || !File.exist?(f)
      hp.add(x['nom'], f)
    rescue StandardError
      nil
    end

    # Pose la hachure réglée pour la balise de ce groupe (appelée par les outils de dessin)
    def self.poser(ent, model = Sketchup.active_model)
      return unless disponible?(model) && ent && ent.layer
      m = motif_couche(model, ent.layer.name)
      ent.hatch_pattern = m if m
    rescue StandardError
      nil
    end

    # Tous les groupes et composants de cette balise (3 niveaux d'imbrication)
    def self.objets(model, b)
      res = []
      fouiller = lambda do |ents, prof|
        ents.each do |e|
          next unless e.is_a?(Sketchup::Group) || e.is_a?(Sketchup::ComponentInstance)
          if e.layer && e.layer.name == b then res << e
          elsif prof < 3 then fouiller.call(e.is_a?(Sketchup::Group) ? e.entities : e.definition.entities, prof + 1)
          end
        end
      end
      fouiller.call(model.entities, 0)
      res
    end

    # ---- Galerie : hachures du modèle et bibliothèque de SketchUp, avec leur aperçu ----
    def self.fichiers_bibliotheque
      dirs = []
      dirs << (Sketchup.get_resource_path('../HatchPatterns') rescue nil)
      dirs << (Sketchup.get_resource_path('HatchPatterns') rescue nil)
      dirs << File.join(File.dirname(Sketchup.find_support_file('Materials').to_s), 'HatchPatterns') rescue nil
      dirs.compact.select { |d| File.directory?(d) }.uniq.flat_map { |d| Dir.glob(File.join(d, '**', '*.skh')) }.uniq.sort
    end

    def self.png_en_texte(f)
      return nil unless f && File.exist?(f)
      'data:image/png;base64,' + [File.binread(f)].pack('m0')
    end

    def self.apercu_motif(m, cle)
      f = File.join(dossier, 'apercus', "#{cle}.png")
      img = m.thumbnail_image
      img.save_file(f) if img
      png_en_texte(f)
    rescue StandardError
      nil
    end

    # Aperçu d'un fichier .skh : gardé en cache ; pour le fabriquer, la hachure est chargée un instant puis retirée
    def self.apercu_fichier(model, chemin)
      f = File.join(dossier, 'apercus', Digest::MD5.hexdigest("#{chemin}|#{File.mtime(chemin).to_i}") + '.png')
      return png_en_texte(f) if File.exist?(f)
      hp = model.hatch_patterns
      tmp = "A2M apercu #{rand(1_000_000)}"
      m = hp.add(tmp, chemin)
      img = m.thumbnail_image
      img.save_file(f) if img
      hp.remove(m)
      png_en_texte(f)
    rescue StandardError
      nil
    end

    def self.galerie(model)
      vus = {}
      liste = []
      model.hatch_patterns.each do |m|
        next if m.name.start_with?(PREFIXE) || m.name.start_with?('A2M apercu')
        vus[m.name.downcase] = true
        liste << { 'cle' => "m:#{m.name}", 'nom' => m.name, 'img' => apercu_motif(m, 'modele_' + Digest::MD5.hexdigest(m.name)), 'ou' => 'Modèle' }
      end
      fichiers_bibliotheque.each do |f|
        nom = File.basename(f, '.skh')
        next if vus[nom.downcase]
        vus[nom.downcase] = true
        liste << { 'cle' => "f:#{f}", 'nom' => nom, 'img' => apercu_fichier(model, f), 'ou' => File.basename(File.dirname(f)) }
      end
      liste
    end

    def self.etat(model)
      r = reglages
      couches = BALISES.map do |b|
        m = motif_couche(model, b, r)
        d = { 'balise' => b, 'libelle' => libelle(b), 'source' => r[b] && r[b]['source'], 'nb' => objets(model, b).size }
        if m
          c = m.fill_color
          d.merge!('img' => apercu_motif(m, 'couche_' + b), 'couleur' => format('#%02x%02x%02x', c.red, c.green, c.blue),
                   'angle' => m.rotation_angle.round(1), 'echelle' => m.uv_scale[0].round(3))
        end
        d
      end
      { 'couches' => couches, 'style' => (model.rendering_options['SectionCutFilled'] ? true : false) }
    end

    # Hachure d'une couche remplacée par le motif choisi (copie propre à la couche, réglable sans toucher aux autres)
    def self.choisir(model, b, cle)
      r = reglages
      hp = model.hatch_patterns
      ancien = hp[nom_couche(b)] rescue nil
      if cle.to_s.empty?
        objets(model, b).each { |e| e.hatch_pattern = nil rescue nil }
        hp.remove(ancien) if ancien
        r.delete(b)
        enregistrer(r)
        return
      end
      source = if cle.start_with?('f:') then cle[2..-1]
               else
                 m = hp[cle[2..-1]] or raise 'hachure introuvable'
                 t = File.join(dossier, "source_#{Digest::MD5.hexdigest(m.name)}.skh")
                 m.write(t) or raise "copie de « #{m.name} » impossible"
                 t
               end
      ancien.name = "#{nom_couche(b)} (remplacée #{rand(1_000_000)})" if ancien
      nouveau = hp.add(nom_couche(b), source)
      objets(model, b).each { |e| e.hatch_pattern = nouveau }
      hp.remove(ancien) if ancien
      f = File.join(dossier, "#{b}.skh")
      nouveau.write(f)
      r[b] = { 'nom' => nouveau.name, 'fichier' => f, 'source' => cle.sub(/\A[mf]:/, '').then { |s| File.basename(s, '.skh') } }
      enregistrer(r)
    end

    def self.regler_motif(model, b, couleur, angle, echelle)
      m = motif_couche(model, b) or return
      m.fill_color = Sketchup::Color.new(couleur) if couleur.to_s =~ /\A#\h{6}\z/
      m.rotation_angle = angle.to_f
      e = echelle.to_f
      m.set_uv_scale(e, e) if e > 0
      x = reglages[b]
      m.write(x['fichier']) if x && !x['fichier'].to_s.empty?
      # Les objets reprennent la hachure modifiée (rafraîchit la vue)
      objets(model, b).each { |o| o.hatch_pattern = m }
    end

    # ---- Fenêtre ----
    def self.regler
      model = Sketchup.active_model
      return UI.messagebox('Les hachures de coupe demandent SketchUp 2027 ou plus récent.') unless disponible?(model)
      if @dlg && @dlg.visible?
        @dlg.bring_to_front
        return
      end
      @dlg = UI::HtmlDialog.new(dialog_title: 'Hachures de coupe par couche', preferences_key: 'A2M_Metre_Hachures', scrollable: false,
                                resizable: true, width: 900, height: 640, min_width: 640, min_height: 420, style: UI::HtmlDialog::STYLE_DIALOG)
      @dlg.set_html(html)
      envoyer = lambda do |quoi, donnees|
        @dlg.execute_script("recevoir(#{JSON.generate(quoi)}, #{JSON.generate(donnees)})")
      end
      operation = lambda do |nom, &bloc|
        m = Sketchup.active_model
        m.start_operation(nom, true)
        begin
          bloc.call(m)
          m.commit_operation
        rescue StandardError => ex
          m.abort_operation
          UI.messagebox("Hachure non modifiée (#{ex.message}).")
        end
        envoyer.call('etat', etat(m))
      end
      @dlg.add_action_callback('pret') do |_c|
        m = Sketchup.active_model
        envoyer.call('etat', etat(m))
        UI.start_timer(0.1, false) { envoyer.call('galerie', galerie(m)) }
      end
      @dlg.add_action_callback('choisir') do |_c, b, cle|
        operation.call('Hachure de coupe (métré)') { |m| choisir(m, b, cle) }
      end
      @dlg.add_action_callback('regler') do |_c, b, couleur, angle, echelle|
        operation.call('Réglage de hachure (métré)') { |m| regler_motif(m, b, couleur, angle, echelle) }
      end
      @dlg.add_action_callback('style') do |_c|
        m = Sketchup.active_model
        m.rendering_options['SectionCutFilled'] = true
        envoyer.call('etat', etat(m))
      end
      @dlg.add_action_callback('fermer') { |_c| @dlg.close }
      @dlg.show
    end

    def self.html
      <<~HTML
        <!doctype html><html lang="fr"><head><meta charset="utf-8"><style>
        :root{--o:#E07838;--g:#3C3C3C;--f:#F6F3EF;--l:#e2dbd3}
        *{box-sizing:border-box}
        body{margin:0;font:13px "Segoe UI",Arial,sans-serif;background:var(--f);color:var(--g);display:flex;flex-direction:column;height:100vh}
        header{padding:10px 14px;border-bottom:1px solid var(--l);display:flex;gap:10px;align-items:center}
        header b{font-size:15px;flex:1}
        #alerte{display:none;background:#fff3e6;border:1px solid var(--o);border-radius:6px;padding:6px 10px;margin:8px 14px 0}
        #alerte button{margin-left:8px}
        main{flex:1;display:flex;min-height:0}
        #couches{width:320px;overflow:auto;border-right:1px solid var(--l);padding:8px}
        .c{display:flex;align-items:center;gap:10px;padding:6px;border-radius:8px;cursor:pointer;border:2px solid transparent}
        .c:hover{background:#fff}
        .c.sel{border-color:var(--o);background:#fff}
        .vig{width:52px;height:52px;border:1px solid var(--l);border-radius:6px;background:#fff center/cover no-repeat;flex:none;display:flex;align-items:center;justify-content:center;font-size:10px;color:#a99}
        .c .t{flex:1;min-width:0}
        .c .t b{display:block;font-weight:600;white-space:nowrap;overflow:hidden;text-overflow:ellipsis}
        .c .t span{font-size:11.5px;color:#8a7f75}
        #droite{flex:1;display:flex;flex-direction:column;min-width:0}
        #reglage{padding:10px 14px;border-bottom:1px solid var(--l);display:flex;gap:16px;align-items:center;flex-wrap:wrap}
        #reglage h3{margin:0;font-size:14px;width:100%}
        #reglage label{display:flex;align-items:center;gap:6px}
        #reglage input[type=number]{width:70px;padding:3px}
        #reglage input[type=color]{width:40px;height:26px;padding:0;border:1px solid var(--l)}
        #gal{flex:1;overflow:auto;padding:10px 14px;display:grid;grid-template-columns:repeat(auto-fill,minmax(96px,1fr));gap:10px;align-content:start}
        .m{cursor:pointer;text-align:center;border-radius:8px;padding:4px;border:2px solid transparent}
        .m:hover{background:#fff}
        .m.sel{border-color:var(--o);background:#fff}
        .m .vig{width:100%;height:76px}
        .m span{display:block;font-size:11px;margin-top:3px;word-break:break-word}
        .m i{display:block;font-size:10px;color:#a99;font-style:normal}
        #filtre{padding:4px 8px;border:1px solid var(--l);border-radius:6px;width:180px}
        footer{padding:8px 14px;border-top:1px solid var(--l);display:flex;gap:10px;align-items:center}
        footer span{flex:1;color:#8a7f75;font-size:11.5px}
        button{font:inherit;padding:5px 12px;border-radius:6px;border:1px solid #cfc6bc;background:#fff;cursor:pointer}
        button.p{background:var(--o);border-color:var(--o);color:#fff}
        .vide{color:#8a7f75;padding:20px}
        </style></head><body>
        <header><b>Hachures de coupe par couche</b><input id="filtre" placeholder="Chercher une hachure…"></header>
        <div id="alerte">Le style actif n'a pas « Remplissage de coupe » : les hachures ne se verront pas en coupe.<button id="btnStyle">L'activer</button></div>
        <main>
          <div id="couches"></div>
          <div id="droite">
            <div id="reglage"><div class="vide">Cliquez sur une couche à gauche pour choisir sa hachure.</div></div>
            <div id="gal"><div class="vide">Chargement des hachures…</div></div>
          </div>
        </main>
        <footer><span>Chaque changement s'applique tout de suite à toutes les couches de ce type et à tout ce que vous dessinerez ensuite, dans tous vos modèles. Ctrl+Z annule.</span><button class="p" onclick="sketchup.fermer()">Fermer</button></footer>
        <script>
        var E={couches:[]}, G=null, sel=null;
        function esc(s){return String(s==null?'':s).replace(/[&<>"]/g,function(c){return {'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;'}[c]})}
        function vig(img,t){return img?'<div class="vig" style="background-image:url('+img+')"></div>':'<div class="vig">'+(t||'aucune')+'</div>'}
        function couche(){return E.couches.filter(function(c){return c.balise===sel})[0]}
        function dessiner(){
          document.getElementById('alerte').style.display=E.style?'none':'block';
          document.getElementById('couches').innerHTML=E.couches.map(function(c){
            return '<div class="c'+(c.balise===sel?' sel':'')+'" data-b="'+c.balise+'">'+vig(c.img)+'<div class="t"><b>'+esc(c.libelle)+'</b><span>'+
              (c.source?esc(c.source):'aucune hachure')+(c.nb?' · '+c.nb+' objet(s) dans ce modèle':'')+'</span></div></div>';
          }).join('');
          document.querySelectorAll('.c').forEach(function(d){d.onclick=function(){sel=d.dataset.b;dessiner();}});
          var c=couche(), r=document.getElementById('reglage');
          if(!c){r.innerHTML='<div class="vide">Cliquez sur une couche à gauche pour choisir sa hachure.</div>';}
          else if(!c.img){r.innerHTML='<h3>'+esc(c.libelle)+' : choisissez une hachure ci-dessous</h3>';}
          else{
            r.innerHTML='<h3>'+esc(c.libelle)+' : '+esc(c.source)+'</h3>'+
              '<label>Couleur de fond <input type="color" id="coul" value="'+c.couleur+'"></label>'+
              '<label>Angle <input type="number" id="ang" step="5" value="'+c.angle+'"> °</label>'+
              '<label>Échelle <input type="number" id="ech" step="0.25" min="0.05" value="'+c.echelle+'"></label>'+
              '<button onclick="sketchup.choisir(sel,\\'\\')">Retirer la hachure</button>';
            ['coul','ang','ech'].forEach(function(id){document.getElementById(id).onchange=function(){
              sketchup.regler(sel,document.getElementById('coul').value,document.getElementById('ang').value,document.getElementById('ech').value);
            }});
          }
          galerie();
        }
        function galerie(){
          var g=document.getElementById('gal');
          if(!G){return;}
          var c=couche(), f=document.getElementById('filtre').value.toLowerCase();
          var l=G.filter(function(m){return !f||m.nom.toLowerCase().indexOf(f)>=0||m.ou.toLowerCase().indexOf(f)>=0});
          if(!l.length){g.innerHTML='<div class="vide">Aucune hachure trouvée.</div>';return;}
          g.innerHTML=l.map(function(m){
            return '<div class="m'+(c&&c.source===m.nom?' sel':'')+'" data-k="'+esc(m.cle)+'">'+vig(m.img,'sans aperçu')+'<span>'+esc(m.nom)+'</span><i>'+esc(m.ou)+'</i></div>';
          }).join('');
          document.querySelectorAll('.m').forEach(function(d){d.onclick=function(){
            if(!sel){alert('Choisissez d\\'abord une couche à gauche.');return;}
            sketchup.choisir(sel,d.dataset.k);
          }});
        }
        function recevoir(q,d){ if(q==='etat'){E=d;dessiner();} else {G=d;galerie();} }
        document.getElementById('filtre').oninput=galerie;
        document.getElementById('btnStyle').onclick=function(){sketchup.style()};
        sketchup.pret();
        </script></body></html>
      HTML
    end

    # Commande : applique les hachures réglées à tous les groupes et composants balisés du modèle
    def self.appliquer
      model = Sketchup.active_model
      return UI.messagebox('Les hachures de coupe demandent SketchUp 2027 ou plus récent.') unless disponible?(model)
      r = reglages
      return UI.messagebox('Aucune hachure réglée : Extensions > Métré Atelier 2M > Hachures de coupe par couche.') if r.empty?
      manque = []; n = 0
      model.start_operation('Hachures de coupe (métré)', true)
      r.each_key do |b|
        m = motif_couche(model, b, r)
        unless m
          manque << libelle(b)
          next
        end
        objets(model, b).each { |e| e.hatch_pattern = m; n += 1 }
      end
      model.commit_operation
      msg = "Hachures posées sur #{n} groupe(s) ou composant(s)."
      msg += "\nIntrouvables (à choisir à nouveau) : #{manque.uniq.join(', ')}" if manque.any?
      UI.messagebox(msg)
    rescue StandardError => ex
      model.abort_operation rescue nil
      UI.messagebox("Hachures non posées (#{ex.message}).")
    end
  end
end
