# encoding: UTF-8
# Métré Atelier 2M : cartouches et chartes — votre identité (logo, coordonnées, couleurs) et les champs de vos cartouches
# (projet, client, phase, indice…), enregistrés en fichiers .json dans « Documents/Atelier 2M/Cartouches ».
# On peut en créer autant qu'on veut ; le cartouche actif sert au dossier client et aux feuilles LayOut.
require 'sketchup.rb'
require 'json'
require 'base64'
require 'fileutils'

module A2M
  module Cartouches
    CHAMPS_DEFAUT = [
      { 'libelle' => 'Projet', 'defaut' => '' }, { 'libelle' => 'Client', 'defaut' => '' }, { 'libelle' => 'Adresse du chantier', 'defaut' => '' },
      { 'libelle' => 'Phase', 'defaut' => 'APD' }, { 'libelle' => 'Plan', 'defaut' => '' }, { 'libelle' => 'Échelle', 'defaut' => '1/100' },
      { 'libelle' => 'Indice', 'defaut' => 'A' }, { 'libelle' => 'Dessiné par', 'defaut' => '' }
    ].freeze

    ATELIER2M = {
      'id' => 'atelier2m', 'nom' => 'Atelier 2M (modèle de base)', 'integre' => true,
      'societe' => ['Atelier 2M · Dessin d\'architecture', '29 avenue Thiers, 19100 Brive-la-Gaillarde', '06 59 98 68 81 · contact@atelier2m.com', 'www.atelier2m.com'],
      'couleur' => '#E07838', 'fond' => '#F9DCC0', 'logo' => '', 'champs' => CHAMPS_DEFAUT
    }.freeze

    CORPS = <<~'HTML'
      <div style="display:flex;gap:8px;margin-bottom:8px;flex-wrap:wrap">
        <button type="button" class="puce" id="nouveau">+ Nouveau</button>
        <button type="button" class="puce" id="dupliquer">Dupliquer</button>
        <button type="button" class="puce" id="supprimer">Supprimer</button>
      </div>
      <div class="puces" id="liste"></div>
      <div id="edit">
        <h2>Nom du cartouche</h2><input type="text" id="nom" style="text-align:left;font-size:14px">
        <h2>Votre société (4 lignes : nom, adresse, contact, site)</h2>
        <input type="text" class="s" style="text-align:left;font-size:13px;margin-bottom:5px"><input type="text" class="s" style="text-align:left;font-size:13px;margin-bottom:5px">
        <input type="text" class="s" style="text-align:left;font-size:13px;margin-bottom:5px"><input type="text" class="s" style="text-align:left;font-size:13px">
        <h2>Couleurs et logo</h2>
        <div style="display:flex;gap:14px;align-items:center;flex-wrap:wrap">
          <label class="petit" style="margin:0">Accent <input type="color" id="couleur"></label>
          <label class="petit" style="margin:0">Fond <input type="color" id="fond"></label>
          <button type="button" class="puce" id="logo">Choisir mon logo…</button>
          <button type="button" class="puce" id="nologo">Logo par défaut</button>
        </div>
        <h2>Champs du cartouche</h2>
        <div id="champs"></div>
        <button type="button" class="puce" id="ajchamp" style="margin-top:6px">+ Ajouter un champ</button>
        <h2>Aperçu</h2>
        <div class="apercu" id="apercu"></div>
      </div>
      <div id="bas"><div id="msg"></div><button type="button" class="puce" id="actif">Utiliser ce cartouche</button><button type="button" id="go">Enregistrer</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      var cur = null;
      function el(id) { return document.getElementById(id); }
      function esc(t) { var d = document.createElement('div'); d.textContent = t; return d.innerHTML; }
      function lire() {
        if (!cur) return;
        cur.nom = el('nom').value; cur.couleur = el('couleur').value; cur.fond = el('fond').value;
        var s = document.querySelectorAll('input.s'); cur.societe = []; for (var i = 0; i < s.length; i++) cur.societe.push(s[i].value);
        var l = document.querySelectorAll('#champs .ch'); cur.champs = [];
        for (var j = 0; j < l.length; j++) { var v = l[j].querySelectorAll('input'); if (v[0].value.trim()) cur.champs.push({ libelle: v[0].value, defaut: v[1].value }); }
      }
      function apercu() {
        if (!cur) return;
        var lg = cur.logo ? '<image href="' + cur.logo + '" x="8" y="8" width="60" height="44" preserveAspectRatio="xMidYMid meet"/>' :
          '<path d="M14 48 V14 L38 38" fill="none" stroke="#6B6B6B" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/><path d="M38 38 L62 14 V48" fill="none" stroke="' + cur.couleur + '" stroke-width="5" stroke-linecap="round" stroke-linejoin="round"/>';
        var s = '<svg viewBox="0 0 420 118" style="width:100%;height:auto"><rect x="1" y="1" width="418" height="116" fill="#fff" stroke="#9C8F84"/><rect x="1" y="1" width="130" height="116" fill="' + cur.fond + '"/>' + lg +
          '<text x="8" y="76" font-size="9" font-weight="600" fill="#3C3C3C">' + esc(cur.societe[0] || '') + '</text><text x="8" y="88" font-size="7" fill="#6f665e">' + esc(cur.societe[1] || '') + '</text><text x="8" y="98" font-size="7" fill="#6f665e">' + esc(cur.societe[2] || '') + '</text><text x="8" y="108" font-size="7" fill="#6f665e">' + esc(cur.societe[3] || '') + '</text>';
        cur.champs.slice(0, 8).forEach(function (c, i) {
          var x = 140 + (i % 2) * 140, y = 14 + Math.floor(i / 2) * 26;
          s += '<text x="' + x + '" y="' + y + '" font-size="6.5" fill="#8a7f75">' + esc(c.libelle.toUpperCase()) + '</text><text x="' + x + '" y="' + (y + 11) + '" font-size="9.5" fill="#3C3C3C">' + esc(c.defaut || '—') + '</text>';
        });
        s += '<rect x="1" y="112" width="418" height="5" fill="' + cur.couleur + '"/></svg>';
        el('apercu').innerHTML = s;
      }
      function champs() {
        var c = el('champs'); c.innerHTML = '';
        cur.champs.forEach(function (ch, i) {
          var d = document.createElement('div'); d.className = 'ch'; d.style.cssText = 'display:flex;gap:6px;margin-bottom:5px';
          d.innerHTML = '<input type="text" style="text-align:left;font-size:12px;flex:1" placeholder="Intitulé"><input type="text" style="text-align:left;font-size:12px;flex:1" placeholder="Valeur par défaut"><button type="button" class="puce" style="padding:2px 9px">×</button>';
          var v = d.querySelectorAll('input'); v[0].value = ch.libelle; v[1].value = ch.defaut || '';
          v[0].addEventListener('input', function () { lire(); apercu(); }); v[1].addEventListener('input', function () { lire(); apercu(); });
          d.querySelector('button').addEventListener('click', function () { lire(); cur.champs.splice(i, 1); champs(); apercu(); });
          c.appendChild(d);
        });
      }
      function rendre() {
        var l = el('liste'); l.innerHTML = '';
        D.liste.forEach(function (c) {
          var b = document.createElement('button'); b.type = 'button'; b.className = 'puce' + (cur && cur.id === c.id ? ' rempli' : '');
          b.textContent = c.nom + (c.id === D.actif ? ' ✔' : ''); b.addEventListener('click', function () { lire(); cur = JSON.parse(JSON.stringify(c)); rendre(); }); l.appendChild(b);
        });
        el('edit').style.display = cur ? '' : 'none';
        if (!cur) return;
        el('nom').value = cur.nom; el('couleur').value = cur.couleur; el('fond').value = cur.fond;
        var s = document.querySelectorAll('input.s'); for (var i = 0; i < s.length; i++) s[i].value = cur.societe[i] || '';
        champs(); apercu();
        el('msg').textContent = cur.integre ? 'Modèle de base : « Enregistrer » crée votre copie' : '';
      }
      ['nom', 'couleur', 'fond'].forEach(function (i) { el(i).addEventListener('input', function () { lire(); apercu(); }); });
      document.querySelectorAll('input.s').forEach(function (e) { e.addEventListener('input', function () { lire(); apercu(); }); });
      el('nouveau').addEventListener('click', function () { lire(); cur = { id: 'n' + Date.now(), nom: 'Mon cartouche', societe: ['', '', '', ''], couleur: '#E07838', fond: '#F9DCC0', logo: '', champs: D.champs }; D.liste.push(cur); cur = JSON.parse(JSON.stringify(cur)); rendre(); });
      el('dupliquer').addEventListener('click', function () { if (!cur) return; lire(); var c = JSON.parse(JSON.stringify(cur)); c.id = 'n' + Date.now(); c.nom += ' (copie)'; delete c.integre; D.liste.push(c); cur = JSON.parse(JSON.stringify(c)); rendre(); });
      el('supprimer').addEventListener('click', function () { if (cur && !cur.integre) { sketchup.supprimer(cur.id); } });
      el('ajchamp').addEventListener('click', function () { lire(); cur.champs.push({ libelle: '', defaut: '' }); champs(); });
      el('logo').addEventListener('click', function () { lire(); sketchup.logo(); });
      el('nologo').addEventListener('click', function () { lire(); cur.logo = ''; apercu(); });
      el('go').addEventListener('click', function () { lire(); if (cur) { if (cur.integre) { cur.id = 'n' + Date.now(); delete cur.integre; } sketchup.enregistrer(JSON.stringify(cur)); } });
      el('actif').addEventListener('click', function () { lire(); if (cur) { if (cur.integre) { sketchup.actif(cur.id); } else { sketchup.enregistrer(JSON.stringify(cur)); sketchup.actif(cur.id); } } });
      function maj(n, choisi) { D = n; var c = D.liste.find(function (x) { return x.id === (choisi || (cur && cur.id)); }) || D.liste.find(function (x) { return x.id === D.actif; }) || D.liste[0]; cur = c ? JSON.parse(JSON.stringify(c)) : null; rendre(); }
      function logo_choisi(d) { if (cur) { cur.logo = d; apercu(); } }
      maj(D, D.actif);
    JS

    def self.dossier
      base = (ENV['USERPROFILE'] || ENV['HOME'] || Dir.home).tr('\\', '/')
      doc = File.join(base, 'Documents')
      File.join(File.directory?(doc) ? doc : base, 'Atelier 2M', 'Cartouches')
    end

    def self.liste
      FileUtils.mkdir_p(dossier) rescue nil
      perso = Dir.glob('*.json', base: dossier).sort.map { |f| JSON.parse(File.read(File.join(dossier, f), encoding: 'UTF-8')) rescue nil }.compact
      [ATELIER2M.dup.merge('champs' => CHAMPS_DEFAUT.map(&:dup))] + perso
    end

    def self.actif_id() Sketchup.read_default('A2M_Metre', 'cartouche', 'atelier2m').to_s end

    # Cartouche actif (celui du modèle de base si le choix a disparu)
    def self.actif
      l = liste
      l.find { |c| c['id'] == actif_id } || l[0]
    end

    def self.valeur_champ(c, libelle)
      (c['champs'] || []).find { |x| x['libelle'].to_s.downcase == libelle.downcase }&.dig('defaut').to_s
    end

    def self.enregistrer(c)
      FileUtils.mkdir_p(dossier)
      c['id'] = c['id'].to_s.gsub(/[^\w\-]/, '')
      File.write(File.join(dossier, "#{c['id']}.json"), JSON.pretty_generate(c), encoding: 'UTF-8')
    end

    def self.donnees
      { 'liste' => liste, 'actif' => actif['id'], 'champs' => CHAMPS_DEFAUT }
    end

    def self.pousser(choisi = nil)
      @fen.execute_script("maj(#{JSON.generate(donnees).gsub('</', '<\/')}, #{JSON.generate(choisi)})") if @fen
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      html = A2M::Panneau.page('Cartouches et charte', 'Votre identité et les champs de vos cartouches — autant de modèles que voulu', CORPS, SCRIPT, donnees)
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : cartouches', 'A2M_Panneau_Cartouches', html, 520, 800)
      @fen = dlg
      dlg.add_action_callback('enregistrer') do |_c, json|
        c = (JSON.parse(json.to_s) rescue nil)
        if c
          c.delete('integre')
          enregistrer(c)
          pousser(c['id'])
        end
      end
      dlg.add_action_callback('supprimer') do |_c, id|
        f = File.join(dossier, "#{id.to_s.gsub(/[^\w\-]/, '')}.json")
        File.delete(f) if File.exist?(f)
        Sketchup.write_default('A2M_Metre', 'cartouche', 'atelier2m') if actif_id == id
        pousser
      end
      dlg.add_action_callback('actif') do |_c, id|
        Sketchup.write_default('A2M_Metre', 'cartouche', id.to_s)
        pousser(id)
      end
      dlg.add_action_callback('logo') do |_c|
        UI.start_timer(0, false) do
          f = UI.openpanel('Choisir votre logo (PNG, JPG ou SVG)', '', 'Images|*.png;*.jpg;*.jpeg;*.svg||')
          if f && File.exist?(f)
            mime = { '.png' => 'image/png', '.jpg' => 'image/jpeg', '.jpeg' => 'image/jpeg', '.svg' => 'image/svg+xml' }[File.extname(f).downcase] || 'image/png'
            d = "data:#{mime};base64,#{Base64.strict_encode64(File.binread(f))}"
            @fen.execute_script("logo_choisi(#{JSON.generate(d)})") if @fen
          end
        end
      end
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end
  end
end
