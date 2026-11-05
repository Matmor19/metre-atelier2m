# encoding: UTF-8
# Métré Atelier 2M : fiche pièce — cliquez dans une pièce, sa fiche s'affiche (surface, périmètre, murs à peindre,
# plinthes, menuiseries, portes, appareillage) avec un bouton pour envoyer le métré
require 'sketchup.rb'
require 'json'

module A2M
  module FichePiece
    HAUTEUR_DEFAUT = 2.5   # m, sous plafond par défaut pour les estimations

    CORPS = <<~'HTML'
      <div id="vide" class="petit" style="padding:30px 0;text-align:center">Cliquez dans une pièce du modèle pour voir sa fiche.</div>
      <div id="fiche" style="display:none">
        <div id="titre" style="font-size:20px;font-weight:600;margin-bottom:8px"></div>
        <div class="grille" id="cartes"></div>
        <h2>Menuiseries extérieures</h2><div id="menus"></div>
        <h2>Portes intérieures</h2><div id="portes"></div>
        <h2>Appareillage électrique</h2><div id="elec"></div>
        <div class="petit" id="note"></div>
      </div>
      <div id="bas"><div id="msg"></div><button type="button" id="go">Envoyer au métré</button></div>
    HTML

    SCRIPT = <<~'JS'
      var D = __DONNEES__;
      function el(id) { return document.getElementById(id); }
      function esc(t) { var d = document.createElement('div'); d.textContent = t; return d.innerHTML; }
      function nb(x) { return (Math.round(x * 100) / 100).toLocaleString('fr-FR'); }
      function liste(id, l, vide) { el(id).innerHTML = l.length ? l.map(function (t) { return '<div style="padding:4px 0;border-top:1px solid #e2dbd3">' + esc(t) + '</div>'; }).join('') : '<div class="petit" style="margin:0">' + vide + '</div>'; }
      function rendre() {
        el('vide').style.display = D.nom ? 'none' : ''; el('fiche').style.display = D.nom ? '' : 'none';
        if (!D.nom) return;
        el('titre').textContent = D.nom;
        var g = el('cartes'); g.innerHTML = '';
        D.cartes.forEach(function (k) {
          var d = document.createElement('div'); d.className = 'carte'; d.style.cursor = 'default';
          d.innerHTML = '<div style="font-size:20px;font-weight:600;color:#E07838">' + esc(k[1]) + '</div><span>' + esc(k[0]) + '</span>'; g.appendChild(d);
        });
        liste('menus', D.menus, 'Aucune'); liste('portes', D.portes, 'Aucune'); liste('elec', D.elec, 'Aucun');
        el('note').textContent = D.note;
      }
      el('go').addEventListener('click', function () { sketchup.envoi(); });
      function maj(n) { D = n; rendre(); }
      rendre();
    JS

    def self.nb(x) x.to_f.round(2).to_s.sub('.', ',') end

    # Point (x, y en m) dans le polygone ?
    def self.dedans?(x, y, poly)
      d = false
      j = poly.size - 1
      poly.each_with_index do |(xi, yi), i|
        xj, yj = poly[j]
        d = !d if ((yi > y) != (yj > y)) && (x < (xj - xi) * (y - yi) / (yj - yi) + xi)
        j = i
      end
      d
    end

    def self.fiche_de(nom)
      res = A2M::Extraction.extraire
      pc = res['pieces'].find { |p| p['nom'] == nom }
      return { 'nom' => nil } unless pc
      h = HAUTEUR_DEFAUT
      surf = pc['surf'].to_f; per = pc['perim'].to_f
      ouv = pc['menus'].sum { |m| m['nb'] * m['l'].to_f * m['h'].to_f / 10_000.0 } + pc['portesInt'].sum { |p| p['nb'] * p['l'].to_f * 204 / 10_000.0 }
      larg_portes = pc['portesInt'].sum { |p| p['nb'] * p['l'].to_f / 100.0 }
      cartes = [['Surface', "#{nb(surf)} m²"], ['Périmètre', "#{nb(per)} ml"],
                ['Murs à peindre', "#{nb(per * h - ouv)} m²"], ['Plafond', "#{nb(surf)} m²"], ['Plinthes', "#{nb([per - larg_portes, 0].max)} ml"],
                ['Volume', "#{nb(surf * h)} m³"]]
      menus = pc['menus'].map { |m| "#{m['nb']} × #{m['type']} #{m['l']} × #{m['h']} cm" }
      portes = pc['portesInt'].map { |p| "#{p['nb']} × porte #{p['l']} cm" }
      elec = (pc['app'] || {}).map { |k, v| "#{v} × #{k}" }
      { 'nom' => nom, 'cartes' => cartes, 'menus' => menus, 'portes' => portes, 'elec' => elec,
        'note' => "Murs, plafond, plinthes et volume sont estimés avec #{nb(h)} m sous plafond ; le métré exact est celui du configurateur." }
    end

    class Outil
      def activate
        Sketchup.status_text = 'Fiche pièce : cliquez dans une pièce. Échap pour quitter.'
        A2M::FichePiece.ouvrir
      end

      def deactivate(view) view.invalidate end
      def onSetCursor() UI.set_cursor(632) end

      def onLButtonDown(_flags, x, y, view)
        ip = view.inputpoint(x, y)
        return unless ip.position
        px = ip.position.x.to_m; py = ip.position.y.to_m
        A2M::Extraction.extraire
        trouve = A2M::Extraction.polys.find { |_n, poly| poly.size >= 3 && A2M::FichePiece.dedans?(px, py, poly) }
        if trouve
          A2M::FichePiece.afficher(trouve[0])
        else
          Sketchup.status_text = 'Aucune pièce à cet endroit (il faut une face A2M_PIECE : outil « Créer les pièces »).'
        end
      end
    end

    def self.afficher(nom)
      @nom = nom
      d = fiche_de(nom)
      @fen.execute_script("maj(#{JSON.generate(d).gsub('</', '<\/')})") if @fen
      Sketchup.status_text = "Fiche pièce : #{nom}"
    end

    def self.ouvrir
      if @fen && (@fen.visible? rescue false)
        @fen.bring_to_front
        return
      end
      html = A2M::Panneau.page('Fiche pièce', 'Cliquez dans une pièce du modèle', CORPS, SCRIPT,
                               'nom' => nil, 'cartes' => [], 'menus' => [], 'portes' => [], 'elec' => [], 'note' => '')
      dlg = A2M::Panneau.fenetre('Métré Atelier 2M : fiche pièce', 'A2M_Panneau_Fiche', html, 400, 640)
      @fen = dlg
      dlg.add_action_callback('envoi') { |_c| UI.start_timer(0, false) { A2M::Envoi.lancer } }
      dlg.set_on_closed { @fen = nil }
      dlg.show
    end

    def self.lancer
      Sketchup.active_model.select_tool(Outil.new)
    end
  end
end
