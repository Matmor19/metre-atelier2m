/**
 * MÉTRÉ ATELIER 2M — script Apps Script SÉPARÉ du Kanban.
 * - Lit le Kanban en LECTURE SEULE (aucune écriture sur ses fichiers).
 * - N'écrit que dans son propre dossier "Métré Atelier 2M".
 * - Toutes les requêtes doivent porter le jeton TOKEN (propriété du script).
 *
 * Mise en place :
 * 1. script.google.com > Nouveau projet > coller ce code > enregistrer.
 * 2. Paramètres du projet > Propriétés du script > ajouter TOKEN = une longue chaîne aléatoire.
 * 3. Déployer > Nouveau déploiement > Application Web
 *    Exécuter en tant que : Moi / Accès : Tout le monde.
 * 4. Copier l'URL du déploiement (se termine par /exec) et la donner à l'application.
 */

var DOSSIER_METRE = 'Métré Atelier 2M';
var DOSSIER_CHANTIERS = 'Chantiers';
var FICHIER_BIBLIO = 'bibliotheque.json';
var FICHIER_LISTES = 'listes.json';                           // listes déroulantes du configurateur (réglages)
var KANBAN_JSON_ID = '144ah2a5Y0rD64P4GW7wkQKRC0pUbK7JI'; // lecture seule
var DOSSIER_CLIENTS_KANBAN = 'Kanban Atelier 2M - Clients'; // documents envoyés depuis le Kanban
var NOM_IMAGE_PG = 'IMAGE PG';
var VERSION_SCRIPT = '2026-10-29';                               // image de la page de garde

function reponse_(obj) {
  return ContentService.createTextOutput(JSON.stringify(obj))
    .setMimeType(ContentService.MimeType.JSON);
}

function verifierJeton_(jeton) {
  var attendu = PropertiesService.getScriptProperties().getProperty('TOKEN');
  return attendu && jeton === attendu;
}

function dossierMetre_() {
  var it = DriveApp.getFoldersByName(DOSSIER_METRE);
  return it.hasNext() ? it.next() : DriveApp.createFolder(DOSSIER_METRE);
}

function dossierChantiers_() {
  var parent = dossierMetre_();
  var it = parent.getFoldersByName(DOSSIER_CHANTIERS);
  return it.hasNext() ? it.next() : parent.createFolder(DOSSIER_CHANTIERS);
}

function dossierSketchup_() {
  var parent = dossierMetre_();
  var it = parent.getFoldersByName('SketchUp');
  return it.hasNext() ? it.next() : parent.createFolder('SketchUp');
}

function fichierDans_(dossier, nom) {
  var it = dossier.getFilesByName(nom);
  return it.hasNext() ? it.next() : null;
}

function lireJson_(dossier, nom, defaut) {
  var f = fichierDans_(dossier, nom);
  return f ? JSON.parse(f.getBlob().getDataAsString()) : defaut;
}

function ecrireJson_(dossier, nom, obj) {
  var txt = JSON.stringify(obj);
  var f = fichierDans_(dossier, nom);
  if (f) f.setContent(txt);
  else dossier.createFile(nom, txt, 'application/json');
}

/* ---------- Requêtes ---------- */

function doGet(e) {
  // Simple contrôle de présence : l'application ne lit que par POST.
  // Ouvrir l'adresse /exec dans le navigateur montre la version publiée : « sketchup: true » = envoi depuis SketchUp accepté
  return reponse_({ ok: true, service: 'metre-atelier2m', version: VERSION_SCRIPT, sketchup: true });
}

function doPost(e) {
  var lock = LockService.getScriptLock();
  try {
    var data = JSON.parse(e.postData.contents);
    if (!verifierJeton_(data.token)) return reponse_({ ok: false, erreur: 'non autorisé' });

    switch (data.action) {
      case 'lire_bibliotheque':
        return reponse_({ ok: true, bibliotheque: lireJson_(dossierMetre_(), FICHIER_BIBLIO, null) });

      case 'sauver_bibliotheque': {
        // Initialisation ou mise à jour. Refus si la bibliothèque envoyée est plus petite
        // que celle de Drive : aucun ouvrage ne doit disparaître par accident.
        lock.waitLock(20000);
        var dos = dossierMetre_();
        var actuelle = lireJson_(dos, FICHIER_BIBLIO, null);
        var nouvelle = data.bibliotheque;
        // Seuls les ouvrages actifs comptent (les ouvrages supprimés peuvent être purgés)
        var actifs = function (b) { return (b && b.ouvrages || []).filter(function (o) { return !o.supprime; }).length; };
        // Réduction refusée, sauf si l'application confirme une suppression voulue (confirmer_reduction)
        if (actuelle && actifs(nouvelle) < actifs(actuelle) && data.confirmer_reduction !== true) {
          return reponse_({ ok: false, erreur: 'refus : bibliothèque réduite', reduction: actifs(actuelle) - actifs(nouvelle) });
        }
        ecrireJson_(dos, FICHIER_BIBLIO, nouvelle);
        return reponse_({ ok: true });
      }

      case 'lire_listes':
        return reponse_({ ok: true, listes: lireJson_(dossierMetre_(), FICHIER_LISTES, null) });

      case 'sauver_listes': {
        // Réglages des listes déroulantes : remplacés tels quels (pas de suppression de chantier ni de bibliothèque)
        lock.waitLock(20000);
        ecrireJson_(dossierMetre_(), FICHIER_LISTES, data.listes || {});
        return reponse_({ ok: true });
      }

      case 'proposer_ouvrage_libre': {
        // Un ouvrage libre n'entre jamais directement dans la bibliothèque :
        // il est mis dans la file "a_valider", vérifiée ensuite par l'application.
        lock.waitLock(20000);
        var dos2 = dossierMetre_();
        var bib = lireJson_(dos2, FICHIER_BIBLIO, { schema: 2, lots: [], ouvrages: [], a_valider: [] });
        bib.a_valider = bib.a_valider || [];
        bib.a_valider.push({
          id: 'LIBRE-' + new Date().getTime(),
          propose_le: new Date().toISOString(),
          ouvrage: data.ouvrage
        });
        ecrireJson_(dos2, FICHIER_BIBLIO, bib);
        return reponse_({ ok: true });
      }

      case 'lister_chantiers': {
        var liste = [];
        var it = dossierChantiers_().getFiles();
        while (it.hasNext()) {
          var f = it.next();
          liste.push({ id: f.getName().replace(/\.json$/, ''), fichier: f.getName(), maj: f.getLastUpdated().toISOString() });
        }
        return reponse_({ ok: true, chantiers: liste });
      }

      case 'lire_chantier': {
        var c = lireJson_(dossierChantiers_(), data.id + '.json', null);
        return reponse_({ ok: true, chantier: c });
      }

      case 'sauver_chantier': {
        // Contrôle de conflit : si le chantier a été modifié ailleurs depuis la lecture,
        // on ne écrase pas et on renvoie la version serveur.
        lock.waitLock(20000);
        var dossier = dossierChantiers_();
        var nom = data.chantier.id + '.json';
        var serveur = lireJson_(dossier, nom, null);
        if (serveur && data.base_maj && serveur.maj && serveur.maj !== data.base_maj) {
          return reponse_({ ok: false, conflit: true, serveur: serveur });
        }
        data.chantier.maj = new Date().toISOString();
        ecrireJson_(dossier, nom, data.chantier);
        return reponse_({ ok: true, maj: data.chantier.maj });
      }

      case 'image_pg': {
        // LECTURE SEULE : cherche « IMAGE PG » dans le dossier du client (Kanban), sans rien modifier
        var racine = DriveApp.getRootFolder().getFoldersByName(DOSSIER_CLIENTS_KANBAN);
        if (!racine.hasNext()) return reponse_({ ok: true, image: null });
        var nomDossier = (data.ref + ' ' + data.nom).trim().replace(/[\/\\]/g, '-');
        var dossiers = racine.next().getFoldersByName(nomDossier);
        if (!dossiers.hasNext()) return reponse_({ ok: true, image: null, erreur: 'dossier client introuvable' });
        var fichiers = dossiers.next().getFiles();
        while (fichiers.hasNext()) {
          var fi = fichiers.next();
          var nomFi = fi.getName().toUpperCase();
          if (nomFi === NOM_IMAGE_PG || nomFi.indexOf(NOM_IMAGE_PG + '.') === 0) {
            var octets = fi.getBlob();
            return reponse_({ ok: true, image: { mime: octets.getContentType(), base64: Utilities.base64Encode(octets.getBytes()), nom: fi.getName() } });
          }
        }
        return reponse_({ ok: true, image: null, erreur: 'IMAGE PG introuvable' });
      }

      case 'importer_clients': {
        // LECTURE SEULE du Kanban : on lit le fichier, on ne renvoie que les champs utiles.
        var kanban = JSON.parse(DriveApp.getFileById(KANBAN_JSON_ID).getBlob().getDataAsString());
        var cartes = (kanban.cards || kanban.cartes || []).map(function (k) {
          return { id: k.id, ref: k.ref, nom: k.nom, tel: k.tel, mail: k.mail,
                   addr: k.addr, cadr: k.cadr, nat: k.nat, surf: k.surf, resume: k.resume };
        });
        return reponse_({ ok: true, clients: cartes });
      }

      /* ---- Extension SketchUp : dépôt d'une extraction, lue ensuite par le configurateur ---- */
      case 'deposer_sketchup': {
        var dsk = dossierSketchup_();
        var nomD = Utilities.formatDate(new Date(), 'Europe/Paris', 'yyyy-MM-dd_HH-mm-ss') + '_' +
          String((data.extraction && data.extraction.modele) || 'modele').replace(/[^\w\-]+/g, '_').slice(0, 60) + '.json';
        dsk.createFile(nomD, JSON.stringify(data.extraction), 'application/json');
        return reponse_({ ok: true, fichier: nomD });
      }

      case 'lister_sketchup': {
        var depots = [];
        var itd = dossierSketchup_().getFiles();
        while (itd.hasNext()) {
          var fd = itd.next();
          depots.push({ fichier: fd.getName(), maj: fd.getLastUpdated().toISOString() });
        }
        depots.sort(function (a, b) { return a.fichier < b.fichier ? 1 : -1; });
        return reponse_({ ok: true, depots: depots.slice(0, 20) });
      }

      case 'lire_sketchup': {
        var fl = fichierDans_(dossierSketchup_(), data.fichier);
        return reponse_({ ok: true, extraction: fl ? JSON.parse(fl.getBlob().getDataAsString()) : null });
      }

      default:
        return reponse_({ ok: false, erreur: 'action inconnue' });
    }
  } catch (err) {
    return reponse_({ ok: false, erreur: String(err) });
  } finally {
    try { lock.releaseLock(); } catch (x) {}
  }
}
