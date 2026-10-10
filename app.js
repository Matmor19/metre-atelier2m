
/* ============ Utilitaires ============ */
const LS = 'metre2m.';
const PAGE = document.body.dataset.page || 'saisie';
/* Style du tableau du métré */
(function () {
  const css = `
    table.metre{width:100%;table-layout:fixed;border-collapse:collapse;font-size:14px;background:var(--card)}
    table.metre th{text-align:left;font-size:12px;text-transform:uppercase;letter-spacing:.03em;color:var(--mut);padding:8px 8px;border-bottom:2px solid var(--line)}
    table.metre td{padding:9px 8px;border-bottom:1px solid var(--line);vertical-align:middle;overflow-wrap:anywhere}
    table.metre th.num,table.metre td.num{text-align:right;font-variant-numeric:tabular-nums;font-weight:600;white-space:nowrap}
    table.metre td.detail{font-size:12.5px;color:var(--mut)}
    table.metre td.act{text-align:center;padding-left:0;padding-right:4px}
    table.metre tr.lot td{background:var(--line);color:var(--acc2);font-weight:700;font-size:13px;padding:8px}
    table.metre tr.lot .muted{font-weight:400}
    table.metre tbody tr:not(.lot):hover td{background:rgba(47,111,176,.06)}
    table.metre .btn.small{min-height:30px;padding:4px 9px}
    table.metre td.numl{font-weight:700;color:var(--acc2);white-space:nowrap}
    table.metre tr.lot .lotnum{display:inline-block;min-width:2.2em;font-weight:700;color:var(--acc2)}
    table.metre .gen-choix{display:inline-block;margin-left:12px;font-size:12px;font-weight:400;color:var(--mut);cursor:pointer;white-space:nowrap}
    table.metre .gen-choix input{width:auto;height:auto;margin:0 4px 0 0;padding:0;vertical-align:middle;accent-color:var(--acc2)}
    table.metre tr.gen td{background:#fbfaf8;font-size:13px;line-height:1.4;padding:8px 12px 10px 40px;border-bottom:1px solid var(--line,#e5e5e5)}
    table.metre .gen-titre{color:var(--acc2);font-weight:700;margin-bottom:4px}
    table.metre .gen-s{margin-top:6px}
    table.metre .gen-sec ul{margin:2px 0 0;padding-left:18px}
    table.metre .gen-sec li{margin:1px 0}
    table.metre .poignee{cursor:grab;touch-action:none;user-select:none;color:var(--mut);padding:0 10px 0 2px;font-size:16px;letter-spacing:-2px}
    table.metre tr.lot.cible-avant td{box-shadow:inset 0 3px 0 var(--acc2)}
    table.metre tr.lot.cible-apres td{box-shadow:inset 0 -3px 0 var(--acc2)}
    table.metre tr.ligne.cible-avant td{box-shadow:inset 0 3px 0 var(--acc2)}
    table.metre tr.ligne.cible-apres td{box-shadow:inset 0 -3px 0 var(--acc2)}
    table.metre td.pu,table.metre td.mt{text-align:right;white-space:nowrap;font-variant-numeric:tabular-nums}
    table.metre tfoot td{font-weight:700;border-top:2px solid var(--line);padding-top:10px}
    body.en-glisse{cursor:grabbing;user-select:none}
    /* Fenêtre du métré : couleurs différentes de la saisie (orange de la charte) */
    body[data-page="tableau"]{background:#fdf3ea}
    body[data-page="tableau"] header{background:#E07838}
    body[data-page="tableau"] .btn{background:#E07838}
    body[data-page="tableau"] .btn.sec{background:transparent;color:#B9561A;border-color:#E07838}
    body[data-page="tableau"] .card{border-color:#f0c9ab}
    body[data-page="tableau"] table.metre tr.lot td{background:#fbe3d2;color:#9a4413}
    @media (prefers-color-scheme: dark){ body[data-page="tableau"]{background:#2a1d15} body[data-page="tableau"] table.metre tr.lot td{background:#3d2a1e;color:#f5b58a} }
  `;
  const s = document.createElement('style');
  s.textContent = css;
  document.head.appendChild(s);
})();

const UNITES = ['m²', 'm³', 'ml', 'u', 'forfait'];
const ORANGE = 'E07838';   // couleur de la charte Atelier 2M (exports)
const $ = id => document.getElementById(id);
function lsGet(k, d) { try { const v = localStorage.getItem(LS + k); return v ? JSON.parse(v) : d; } catch (e) { return d; } }
function lsSet(k, v) { try { localStorage.setItem(LS + k, JSON.stringify(v)); return true; } catch (e) { return false; } }
const esc = s => String(s ?? '').replace(/[&<>"']/g, c => ({'&':'&amp;','<':'&lt;','>':'&gt;','"':'&quot;',"'":'&#39;'}[c]));
const num = v => { const n = parseFloat(String(v ?? '').replace(',', '.')); return isFinite(n) ? n : 0; };
const fmt = n => (Math.round(n * 100) / 100).toLocaleString('fr-FR', { maximumFractionDigits: 2 });
const uid = () => Math.random().toString(36).slice(2, 8) + Date.now().toString(36);

/* ============ Données ============ */
let BIB = null;                       // bibliothèque (lots + ouvrages)
let GEN = null;                       // généralités construction neuve (generalites.json)
let GEN_REN = null;                   // généralités rénovation (generalites_renovation.json)
let GEN_EXT = null;                   // généralités extension (generalites_extension.json)
let chantiers = lsGet('chantiers', []);
let courantId = lsGet('courant', null);
let lotCourant = null;

function lignesDe(id) { return lsGet('lignes.' + id, []); }
// Pendant la revue, les lignes calculées sont recueillies ici au lieu d'être enregistrées dans le métré
let _revueCollecte = null;
function sauverLignes(id, L) { if (_revueCollecte) { _revueCollecte[id] = (_revueCollecte[id] || []).concat(L); return true; } const ok = lsSet('lignes.' + id, L); marquerChantier(id); return ok; }
function libLot(id) { const l = BIB.lots.find(x => x.id === id); return l ? l.nom : id; }

async function post(corps) {
  const url = lsGet('url', ''), tok = lsGet('jeton', '');
  const r = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'text/plain;charset=utf-8' },
    body: JSON.stringify({ token: tok, ...corps }) });
  return r.json();
}

async function chargerBibliotheque() {
  try {
    const r = await fetch('bibliotheque.json', { cache: 'no-cache' });
    BIB = await r.json();
  } catch (e) {
    BIB = lsGet('bib', null);   // hors ligne : dernière copie connue
  }
  // Modifications faites dans l'application et pas encore envoyées sur Drive : elles prévalent
  if (lsGet('bib_modifiee', false) && lsGet('bib', null)) BIB = lsGet('bib', null);
  // Généralités par lot (texte fixe). Hors ligne : dernière copie connue.
  try {
    const g = await fetch('generalites.json', { cache: 'no-cache' });
    GEN = await g.json();
    lsSet('gen', GEN);
  } catch (e) {
    GEN = lsGet('gen', null) || {};
  }
  try {
    const g = await fetch('generalites_renovation.json', { cache: 'no-cache' });
    GEN_REN = await g.json();
    lsSet('gen_ren', GEN_REN);
  } catch (e) {
    GEN_REN = lsGet('gen_ren', null) || {};
  }
  try {
    const g = await fetch('generalites_extension.json', { cache: 'no-cache' });
    GEN_EXT = await g.json();
    lsSet('gen_ext', GEN_EXT);
  } catch (e) {
    GEN_EXT = lsGet('gen_ext', null) || {};
  }
}

// Type de travaux d'un chantier : 'neuf' (par défaut), 'renovation' ou 'extension'
const TYPES_TRAVAUX = ['neuf', 'renovation', 'extension'];
function travauxDe(id) {
  const c = chantiers.find(x => x.id === id);
  return c && TYPES_TRAVAUX.includes(c.travaux) ? c.travaux : 'neuf';
}
// Généralités d'un lot selon le type de travaux du chantier (courant par défaut)
function genDuLot(lotId, id = courantId) {
  const t = travauxDe(id);
  const src = t === 'renovation' ? GEN_REN : (t === 'extension' ? GEN_EXT : GEN);
  return (src && src[lotId]) || null;
}
// Généralités d'un lot : affichées et imprimées seulement si le lot est coché dans le chantier
function genActif(id, lotId) {
  const c = chantiers.find(x => x.id === id);
  return !!(c && c.gen && c.gen[lotId] && genDuLot(lotId, id));
}
// Choix « Construction neuve / Rénovation » du chantier courant
function basculerTravaux(valeur) {
  const c = chantiers.find(x => x.id === courantId);
  if (!c) return;
  c.travaux = TYPES_TRAVAUX.includes(valeur) ? valeur : 'neuf';
  lsSet('chantiers', chantiers);
  marquerChantier(courantId);
  renderMetre();
}
function genHtml(lotId, numLot) {
  const g = genDuLot(lotId);
  if (!g) return '';
  let h = `<div class="gen-bloc"><div class="gen-titre">${numLot}.0 · Généralités : ${esc(g.titre)}</div>`;
  g.sections.forEach((s, k) => {
    h += `<div class="gen-sec"><div class="gen-s"><strong>${numLot}.${k + 1} ${esc(s.titre)}</strong></div><ul>${s.points.map(p => `<li>${esc(p)}</li>`).join('')}</ul></div>`;
  });
  return h + '</div>';
}
function basculerGen(id, lotId, on) {
  const c = chantiers.find(x => x.id === id);
  if (!c) return;
  c.gen = Object.assign({}, c.gen, { [lotId]: !!on });
  lsSet('chantiers', chantiers);
  marquerChantier(id);
  renderMetre();
}

// Si le script est joignable, la bibliothèque maîtresse (Drive) remplace la copie locale.
async function synchroBibliotheque() {
  if (!lsGet('url', '') || !lsGet('jeton', '')) return;
  if (lsGet('bib_modifiee', false)) {
    // Des modifications locales attendent d'être envoyées : on les envoie, sans rien écraser
    try {
      const j = await post({ action: 'sauver_bibliotheque', bibliotheque: BIB });
      if (j.ok) lsSet('bib_modifiee', false);
    } catch (e) { /* pas de réseau : elles restent sur l'appareil */ }
    return;
  }
  try {
    const j = await post({ action: 'lire_bibliotheque' });
    if (j.ok && j.bibliotheque && j.bibliotheque.ouvrages) {
      // La version livrée avec l'application (fichier bibliotheque.json) est plus récente que celle de Drive :
      // elle est envoyée sur Drive, au lieu d'être remplacée par l'ancienne.
      const locale = (BIB && BIB.revision) || 0;
      const distante = j.bibliotheque.revision || 0;
      if (locale > distante) {
        const s = await post({ action: 'sauver_bibliotheque', bibliotheque: BIB });
        if (s.ok) { lsSet('bib', BIB); remplirLots(); renderOuvrages(); }
        return;
      }
      BIB = j.bibliotheque;
      lsSet('bib', BIB);
      if (!lotCourant) lotCourant = BIB.lots[0].id;
      remplirLots(); renderOuvrages();
    }
  } catch (e) { /* pas de réseau : on garde la copie locale */ }
}

// Ouvrages proposés (libres) pas encore envoyés : renvoyés dès que possible.
async function envoyerPropositions() {
  if (!lsGet('url', '') || !lsGet('jeton', '')) return;
  const file = lsGet('file_libres', []);
  for (const it of file.filter(x => !x.envoye)) {
    try {
      const j = await post({ action: 'proposer_ouvrage_libre', ouvrage: it.ouvrage });
      if (j.ok) it.envoye = true; else break;
    } catch (e) { break; }
  }
  lsSet('file_libres', file);
}

/* ============ Calcul des quantités ============ */
// Modes de métré : même calcul que l'unité (produit des cotes), seuls les noms des cotes changent
const MESURES = {
  'm²': [{ id: 'lxl', nom: 'Longueur × Largeur', cotes: ['Longueur', 'Largeur'] },
         { id: 'lxh', nom: 'Longueur × Hauteur', cotes: ['Longueur', 'Hauteur'] }],
  'm³': [{ id: 'lxlxh', nom: 'Longueur × Largeur × Hauteur', cotes: ['Longueur', 'Largeur', 'Hauteur'] }],
  'ml': [{ id: 'l', nom: 'Longueur', cotes: ['Longueur'] }],
  'u': [{ id: 'nombre', nom: 'Nombre', cotes: [] }],
  'forfait': [{ id: 'forfait', nom: 'Forfait', cotes: [] }]
};
function modeDe(unite, id) { return (MESURES[unite] || []).find(m => m.id === id) || null; }
function optionsMesure(unite, actuel) {
  return (MESURES[unite] || []).map(m => `<option value="${m.id}" ${m.id === actuel ? 'selected' : ''}>${esc(m.nom)}</option>`).join('');
}
// Champs de saisie d'un mode : nombre + une case par cote, avec le nom demandé
function champsPourMode(unite, id) {
  const m = modeDe(unite, id);
  if (!m) return null;
  return [{ cle: 'nombre', libelle: 'Nombre' }, ...m.cotes.map((c, i) => ({ cle: 'cote' + (i + 1), libelle: c + ' (m)' }))];
}

function calcul(o, v) {
  const n = (v.nombre === '' || v.nombre == null) ? 1 : num(v.nombre);
  const c1 = num(v.cote1), c2 = num(v.cote2), c3 = num(v.cote3);
  switch (o.unite) {
    case 'm²': return n * c1 * c2;
    case 'm³': return n * c1 * c2 * c3;
    case 'ml': return n * c1;
    default:   return n;               // u, forfait
  }
}

// Champs affichés pour un ouvrage du catalogue
function champsDe(o) {
  const c = o.champs.map(x => ({ ...x }));
  if (o.saisie === 'menuiseries') {
    c.push({ cle: 'largeur_cm', libelle: 'Largeur (cm)' },
           { cle: 'hauteur_cm', libelle: 'Hauteur (cm)' },
           { cle: 'options', libelle: 'Options (couleur, vitrage, poignée…)', texte: true });
  }
  return c;
}

function lireForm(f, champs) {
  const v = {};
  for (const ch of champs) {
    const raw = f.elements[ch.cle].value.trim();
    v[ch.cle] = ch.texte ? raw : raw.replace(',', '.');
  }
  return v;
}

// Couleurs des cotes (repère visuel pour SketchUp) : Longueur vert, Largeur rouge, Hauteur bleu
const COTE_COULEUR = { Longueur: '#2e7d32', Largeur: '#c62828', Hauteur: '#1565c0' };
function categorieCote(nom) {
  if (['Longueur', 'L'].includes(nom)) return 'Longueur';
  if (['Largeur', 'l', 'larg.'].includes(nom)) return 'Largeur';
  if (['Hauteur', 'h', 'H', 'haut.'].includes(nom)) return 'Hauteur';
  return null;
}
// Morceaux du détail : nom de la cote (L, l, H… ou Longueur, Largeur, Hauteur) et valeur
function detailMorceaux(l) {
  const noms = { nombre: 'nb', cote1: 'L', cote2: 'l', cote3: 'h', largeur_cm: 'larg.', hauteur_cm: 'haut.' };
  const o = BIB && BIB.ouvrages.find(x => x.id === l.ouvrage);
  const mode = o && o.mesure ? modeDe(o.unite, o.mesure) : null;
  if (mode) mode.cotes.forEach((c, i) => { noms['cote' + (i + 1)] = c[0]; });   // L, l ou H selon le mode
  return Object.entries(l.valeurs)
    .filter(([k, v]) => v !== '' && v != null)
    .map(([k, v]) => ({ nom: noms[k] || '', v }));
}
// Texte simple (exports CSV, Excel)
function detail(l) {
  let t = detailMorceaux(l).map(m => (m.nom ? m.nom + ' ' : '') + m.v).join(' × ');
  if (l.surface) t += ` (surface ${fmt(l.surface)} m²)`;
  return t;
}
// Version colorée (écran et impressions) : chaque cote a sa couleur
function detailHtml(l) {
  let t = detailMorceaux(l).map(m => {
    const txt = (m.nom ? m.nom + ' ' : '') + esc(String(m.v));
    const c = COTE_COULEUR[categorieCote(m.nom)];
    return c ? `<span style="color:${c};font-weight:700">${txt}</span>` : txt;
  }).join(' × ');
  if (l.surface) t += ` (surface ${fmt(l.surface)} m²)`;
  return t;
}

/* ============ Affichage ============ */
function route(nom) {
  const vues = { chantiers: 'vChantiers', metre: 'vMetre', tableau: 'vTableau', config: 'vConfig', reglages: 'vReglages', biblio: 'vBiblio' };
  if (PAGE === 'tableau') nom = 'tableau';
  for (const k of Object.keys(vues)) $(vues[k]).classList.toggle('hidden', k !== nom);
  if (nom === 'metre' || nom === 'tableau') compterLignes();
}

function compterLignes() {
  const n = courantId ? lignesDe(courantId).length : 0;
  $('nbLignes').textContent = n;
  $('nbLignes2').textContent = n;
}

function ouvrirTableau() {
  window.open('tableau.html', 'metre2m-tableau');
}

function renderChantiers() {
  $('titre').textContent = 'Métré Atelier 2M';
  const actifs = chantiers.filter(c => !c.supprime && !c.archive);
  const archives = chantiers.filter(c => !c.supprime && c.archive);
  const carte = c => `<div class="card"><div class="row" style="justify-content:space-between;align-items:center">
        <div><strong>${esc(c.nom)}</strong><div class="muted">${lignesDe(c.id).length} ligne(s)</div></div>
        <div class="row" style="flex:0 0 auto;gap:6px">
          ${c.archive
            ? `<button class="btn small sec" data-restaurer="${esc(c.id)}">Restaurer</button><button class="btn small danger" data-supprimer="${esc(c.id)}">Supprimer</button>`
            : `<button class="btn small" data-ouvrir="${esc(c.id)}">Ouvrir</button>
               <button class="btn small sec" data-dupliquer="${esc(c.id)}">Dupliquer</button>
               <button class="btn small sec" data-archiver="${esc(c.id)}">Archiver</button>`}
        </div></div></div>`;
  $('listeChantiers').innerHTML = (actifs.length ? actifs.map(carte).join('')
    : '<p class="muted">Aucun chantier pour l\'instant. Créez-en un ci-dessus.</p>')
    + (archives.length ? `<details style="margin-top:16px"><summary class="muted">Archives (${archives.length})</summary>${archives.map(carte).join('')}</details>` : '');
}

// Archiver, restaurer, supprimer, dupliquer : toutes les actions passent par la synchronisation
function archiverChantier(id, archive) {
  const c = chantiers.find(x => x.id === id);
  if (!c) return;
  c.archive = archive;
  lsSet('chantiers', chantiers);
  marquerChantier(id);
  renderChantiers();
}
function supprimerChantier(id) {
  const c = chantiers.find(x => x.id === id);
  if (!c) return;
  if (!confirm('Supprimer définitivement le chantier « ' + c.nom + ' » et toutes ses lignes ?')) return;
  // Suppression marquée : les autres appareils la reçoivent et retirent le chantier
  c.supprime = true;
  c.archive = false;
  lsSet('chantiers', chantiers);
  lsSet('lignes.' + id, []);
  marquerChantier(id);
  if (courantId === id) { courantId = null; lsSet('courant', null); }
  renderChantiers();
}
// Copie complète (lots et lignes) dans un nouveau chantier
function dupliquerChantier(id) {
  const src = chantiers.find(x => x.id === id);
  if (!src) return;
  const nom = prompt('Nom du nouveau chantier :', 'Copie de ' + src.nom);
  if (!nom || !nom.trim()) return;
  const nouveau = { id: 'c' + uid(), nom: nom.trim(), client: null, lots: [...(src.lots || [])] };
  const lignes = lignesDe(id).map(l => Object.assign({}, l, { uid: uid() }));
  chantiers.push(nouveau);
  lsSet('chantiers', chantiers);
  lsSet('lignes.' + nouveau.id, lignes);
  marquerChantier(nouveau.id);
  ouvrirChantier(nouveau.id);
}

function remplirLots() {
  $('selLot').innerHTML = BIB.lots.map(l => `<option value="${esc(l.id)}">${esc(l.nom)}</option>`).join('');
  if (!lotCourant) lotCourant = BIB.lots[0].id;
  $('selLot').value = lotCourant;
}

function renderOuvrages() {
  const q = $('recherche').value.trim().toLowerCase();
  const liste = BIB.ouvrages.filter(o => !o.supprime && o.lot === lotCourant && (!q || o.designation.toLowerCase().includes(q)));
  const lignes = liste.map(o => `<div class="ouv" data-ouv="${esc(o.id)}"><span>${esc(o.designation)}</span><span class="tag">${esc(o.unite)}</span></div>`).join('');
  $('listeOuvrages').innerHTML = (lignes || '<p class="muted" style="padding:12px">Aucun ouvrage trouvé dans ce lot.</p>')
    + '<div style="padding:12px"><button class="btn sec" id="bLibre2">+ Ouvrage libre dans ce lot</button></div>';
}

/* ============ Lots du chantier et numérotation ============ */
// Ordre des lots = ordre dans lequel ils ont été ajoutés au métré (pas l'ordre de la bibliothèque)
function lotsDuChantier(id) {
  const c = chantiers.find(x => x.id === id);
  const liste = c && Array.isArray(c.lots) ? [...c.lots] : [];
  for (const l of lignesDe(id)) if (!liste.includes(l.lot)) liste.push(l.lot);
  return liste.filter(lid => BIB.lots.some(x => x.id === lid));
}
function sauverLotsDuChantier(id, liste) {
  const c = chantiers.find(x => x.id === id);
  if (!c) return;
  c.lots = liste;
  lsSet('chantiers', chantiers);
  marquerChantier(id);
}
function ajouterLotSiAbsent(id, lotId) {
  const liste = lotsDuChantier(id);
  if (!liste.includes(lotId)) sauverLotsDuChantier(id, [...liste, lotId]);
}
// Numéro de chaque ligne : 01.1, 01.2, 02.1…
function numeroLignes(id) {
  const L = lignesDe(id);
  const map = {};
  lotsDuChantier(id).forEach((lotId, i) => {
    L.filter(l => l.lot === lotId).forEach((l, k) => {
      map[l.uid] = String(i + 1).padStart(2, '0') + '.' + (k + 1);
    });
  });
  return map;
}
function insererLot(lotId, apresId) {
  const liste = lotsDuChantier(courantId).filter(x => x !== lotId);
  const idx = apresId ? liste.indexOf(apresId) + 1 : 0;
  liste.splice(idx, 0, lotId);
  sauverLotsDuChantier(courantId, liste);
  renderMetre();
}
function retirerLot(lotId) {
  if (lignesDe(courantId).some(l => l.lot === lotId)) return;
  sauverLotsDuChantier(courantId, lotsDuChantier(courantId).filter(x => x !== lotId));
  renderMetre();
}
function dessinerPanneauLot() {
  if (PAGE !== 'tableau' || !courantId) return;
  let p = $('panneauLot');
  if (!p) {
    p = document.createElement('div');
    p.id = 'panneauLot';
    p.className = 'card';
    $('tableMetre').closest('.card').insertAdjacentElement('beforebegin', p);
  }
  const deja = lotsDuChantier(courantId);
  const dispo = BIB.lots.filter(l => !deja.includes(l.id));
  p.innerHTML = `<strong>Ajouter un lot au métré</strong>
    <div class="row" style="margin-top:8px">
      <div><label for="lotNouveau">Lot</label><select id="lotNouveau">${dispo.length
        ? dispo.map(l => `<option value="${esc(l.id)}">${esc(l.nom)}</option>`).join('')
        : '<option value="">Tous les lots sont déjà dans le métré</option>'}</select></div>
      <div><label for="lotPlace">Placer</label><select id="lotPlace"><option value="">En premier</option>${deja
        .map(id => `<option value="${esc(id)}">Après « ${esc(libLot(id))} »</option>`).join('')}</select></div>
      <div style="flex:0 0 auto"><button class="btn" id="btnAjouterLot" ${dispo.length ? '' : 'disabled'}>Insérer</button></div>
    </div>`;
}
/* ============ Glisser-déposer des lots (souris et tactile) ============ */
// glisse = { type: 'lot', lot } (un lot entier) ou { type: 'ligne', uid } (un ouvrage du métré)
let glisse = null;
function cibleSous(x, y) {
  const el = document.elementFromPoint(x, y);
  return el ? el.closest('tr.lot[data-lot], tr.ligne[data-uid]') : null;
}
function marquerCible(tr, y) {
  document.querySelectorAll('.cible-avant, .cible-apres').forEach(t => t.classList.remove('cible-avant', 'cible-apres'));
  if (!tr) return;
  if (glisse.type === 'lot') {
    if (!tr.classList.contains('lot') || tr.dataset.lot === glisse.lot) return;
  } else {
    if (tr.dataset.uid === glisse.uid) return;
    if (tr.classList.contains('lot')) { tr.classList.add('cible-avant'); return; }  // en-tête : début du lot
  }
  const r = tr.getBoundingClientRect();
  tr.classList.add(y < r.top + r.height / 2 ? 'cible-avant' : 'cible-apres');
}
document.addEventListener('pointerdown', e => {
  const p = e.target.closest('[data-glisser], [data-glisser-ligne]');
  if (!p || PAGE !== 'tableau') return;
  e.preventDefault();
  glisse = p.dataset.glisserLigne
    ? { type: 'ligne', uid: p.dataset.glisserLigne }
    : { type: 'lot', lot: p.dataset.glisser };
  document.body.classList.add('en-glisse');
});
document.addEventListener('pointermove', e => {
  if (!glisse) return;
  marquerCible(cibleSous(e.clientX, e.clientY), e.clientY);
});
function finGlisse(e) {
  if (!glisse) return;
  const g = glisse;
  const tr = e.type === 'pointerup' ? cibleSous(e.clientX, e.clientY) : null;
  const apres = !!tr && tr.classList.contains('cible-apres');
  glisse = null;
  document.body.classList.remove('en-glisse');
  document.querySelectorAll('.cible-avant, .cible-apres').forEach(t => t.classList.remove('cible-avant', 'cible-apres'));
  if (!tr) return;
  if (g.type === 'lot') {
    if (!tr.classList.contains('lot') || tr.dataset.lot === g.lot) return;
    const liste = lotsDuChantier(courantId).filter(x => x !== g.lot);
    let idx = liste.indexOf(tr.dataset.lot);
    if (apres) idx += 1;
    liste.splice(idx, 0, g.lot);
    sauverLotsDuChantier(courantId, liste);
    renderMetre();
  } else {
    deplacerLigne(g.uid, tr, apres);
  }
}
// Déplace un ouvrage du métré : il change de lot si besoin. La numérotation se recalcule
// toute seule, puisqu'elle suit l'ordre des lignes dans chaque lot.
function deplacerLigne(uid, tr, apres) {
  const L = lignesDe(courantId);
  const src = L.find(l => l.uid === uid);
  if (!src) return;
  const lotCible = tr.dataset.lot;
  const reste = L.filter(l => l.uid !== uid);
  let idx;
  if (tr.dataset.uid) {
    if (tr.dataset.uid === uid) return;
    idx = reste.findIndex(l => l.uid === tr.dataset.uid);
    idx = idx < 0 ? reste.length : idx + (apres ? 1 : 0);
  } else {
    idx = reste.findIndex(l => l.lot === lotCible);   // en-tête de lot : en tête du lot
    if (idx < 0) idx = reste.length;
  }
  src.lot = lotCible;
  reste.splice(idx, 0, src);
  sauverLignes(courantId, reste);
  renderMetre();
}
document.addEventListener('pointerup', finGlisse);
document.addEventListener('pointercancel', finGlisse);

document.addEventListener('click', e => {
  if (e.target.closest('#btnAjouterLot')) {
    const lot = $('lotNouveau').value;
    if (lot) insererLot(lot, $('lotPlace').value || null);
    return;
  }
  const r = e.target.closest('[data-retirer-lot]');
  if (r) { if (confirm('Retirer ce lot vide du métré ?')) retirerLot(r.dataset.retirerLot); }
});

// Prix indicatif HT d'un ouvrage du métré (moyenne des devis), ou null
// Choix du prix dans le métré : moyen (par défaut), bas, haut ou unique.
// Si le prix choisi n'existe pas, on prend le suivant dans l'ordre ci-dessous.
const REPLI_PRIX = { moyen: ['moyen', 'unique'], bas: ['min', 'moyen', 'unique'], haut: ['max', 'moyen', 'unique'], unique: ['unique', 'moyen'] };
const LIBELLES_PRIX = [['moyen', 'Moyen', 'moyen'], ['bas', 'Bas', 'min'], ['haut', 'Haut', 'max'], ['unique', 'Unique', 'unique'], ['devis', 'Devis', null]];
function prixSelon(p, choix) {
  if (!p) return null;
  if (choix && choix.startsWith('devis:')) {          // un prix précis saisi dans « Ajouter un prix de devis »
    const v = devisDe(p)[parseInt(choix.slice(6), 10)];
    if (v != null) return v;
    choix = 'moyen';
  }
  for (const champ of (REPLI_PRIX[choix] || REPLI_PRIX.moyen)) if (p[champ] != null) return p[champ];
  return null;
}
// Clé de choix d'une ligne : « devis » suit le numéro de devis choisi (devisNum)
function cleChoix(l) {
  return l.prix === 'devis' ? 'devis:' + (l.devisNum || 0) : (l.prix || 'moyen');
}
function prixUnitaire(l) {
  const o = BIB && BIB.ouvrages.find(x => x.id === l.ouvrage);
  return o ? prixSelon(o.prix_indicatif, cleChoix(l)) : null;
}
function optionsPrix(l, montants) {
  const o = BIB && BIB.ouvrages.find(x => x.id === l.ouvrage);
  const p = (o && o.prix_indicatif) || {};
  const choisi = (l.prix || 'moyen');
  const liste = devisDe(p);
  return LIBELLES_PRIX.map(([cle, lib, champ]) => {
    let suite = '';
    if (montants) {
      const v = cle === 'devis' ? (liste.length ? liste[Math.min(l.devisNum || 0, liste.length - 1)] : null) : p[champ];
      suite = v != null ? ' ' + fmt(v) : ' (—)';
    } else if (cle === 'devis' && !liste.length) suite = ' (—)';
    return `<option value="${cle}" ${cle === choisi ? 'selected' : ''}>${lib}${suite}</option>`;
  }).join('');
}
// Liste des devis (seconde liste, affichée seulement quand « Devis » est choisi)
function optionsDevis(l, montants) {
  const o = BIB && BIB.ouvrages.find(x => x.id === l.ouvrage);
  const liste = devisDe((o && o.prix_indicatif) || {});
  const num = Math.min(l.devisNum || 0, Math.max(liste.length - 1, 0));
  return liste.map((v, i) => `<option value="${i}" ${i === num ? 'selected' : ''}>Devis ${i + 1}${montants ? ' ' + fmt(v) : ''}</option>`).join('');
}
// Réglage « Afficher les prix » (désactivé par défaut) : contrôle le tableau et les exports
function prixAffiches() { return lsGet('prix', false) === true; }

function renderMetre() {
  if (!courantId) return;
  const L = lignesDe(courantId);
  const lots = lotsDuChantier(courantId);
  const nums = numeroLignes(courantId);
  const avecPrix = prixAffiches();
  compterLignes();
  dessinerPanneauLot();
  if ($('btnPrix')) $('btnPrix').textContent = avecPrix ? 'Masquer les prix' : 'Afficher les prix';
  if ($('selTravaux')) $('selTravaux').value = travauxDe(courantId);
  if ($('dateLimite')) $('dateLimite').value = (chantiers.find(x => x.id === courantId) || {}).dateLimite || '';
  const nc = avecPrix ? 8 : 7;
  const colonnes = avecPrix
    ? '<col style="width:9%"><col style="width:25%"><col style="width:7%"><col style="width:9%"><col style="width:18%"><col style="width:11%"><col style="width:9%"><col style="width:9%"><col style="width:7%">'
    : '<col style="width:9%"><col style="width:33%"><col style="width:8%"><col style="width:11%"><col style="width:18%"><col style="width:12%"><col style="width:9%">';
  let total = 0, sansPrix = 0;
  let h = `<table class="metre">
    <colgroup>${colonnes}</colgroup>
    <thead><tr><th>N°</th><th>Désignation</th><th>Unité</th><th class="num">Quantité</th><th>Détail</th><th>Prix</th>${avecPrix ? '<th class="num">P.U. HT ind.</th><th class="num">Montant HT ind.</th>' : ''}<th></th></tr></thead><tbody>`;
  lots.forEach((lotId, i) => {
    const lot = BIB.lots.find(x => x.id === lotId);
    const ls = L.filter(l => l.lot === lotId);
    const vide = ls.length === 0;
    const aGen = !!genDuLot(lotId);
    const coche = aGen && genActif(courantId, lotId);
    h += `<tr class="lot" data-lot="${esc(lotId)}"><td colspan="${nc}"><span class="poignee" data-glisser="${esc(lotId)}" title="Glisser pour déplacer le lot">⋮⋮</span><span class="lotnum">${String(i + 1).padStart(2, '0')}</span> ${esc(lot ? lot.nom : lotId)}
      <span class="muted">(${vide ? 'aucune ligne' : ls.length + ' ligne' + (ls.length > 1 ? 's' : '')})</span>
      ${vide ? `<button class="btn small sec" data-retirer-lot="${esc(lotId)}">Retirer</button>` : ''}
      ${aGen ? `<label class="gen-choix"><input type="checkbox" data-gen="${esc(lotId)}" ${coche ? 'checked' : ''}> Généralités dans le métré</label>` : ''}</td></tr>`;
    if (coche) h += `<tr class="gen"><td colspan="${nc}">${genHtml(lotId, i + 1)}</td></tr>`;
    for (const l of ls) {
      const pu = prixUnitaire(l);
      const mt = pu != null ? l.quantite * pu : null;
      if (mt != null) total += mt; else sansPrix++;
      h += `<tr class="ligne" data-uid="${esc(l.uid)}" data-lot="${esc(lotId)}">
        <td class="numl"><span class="poignee" data-glisser-ligne="${esc(l.uid)}" title="Glisser pour déplacer l'ouvrage">⋮⋮</span>${nums[l.uid]}</td>
        <td>${esc(l.designation)}</td>
        <td>${esc(l.unite)}</td>
        <td class="num">${fmt(l.quantite)}</td>
        <td class="detail">${detailHtml(l)}</td>
        <td><select class="choix" data-choix-prix="${esc(l.uid)}" title="Prix à utiliser" style="width:100%;min-height:30px;padding:2px 4px;font-size:12px">${optionsPrix(l, avecPrix)}</select>${l.prix === 'devis' && devisDe((BIB.ouvrages.find(x => x.id === l.ouvrage) || {}).prix_indicatif || {}).length ? `<select class="choix" data-choix-devis="${esc(l.uid)}" title="Devis à utiliser" style="width:100%;min-height:30px;padding:2px 4px;font-size:12px;margin-top:4px">${optionsDevis(l, avecPrix)}</select>` : ''}</td>
        ${avecPrix ? `<td class="pu">${pu != null ? fmt(pu) : '—'}</td><td class="mt">${mt != null ? fmt(mt) : '—'}</td>` : ''}
        <td class="act"><button class="btn small danger" data-sup="${esc(l.uid)}" title="Supprimer">✕</button></td>
      </tr>`;
    }
  });
  if (!lots.length) h += `<tr><td colspan="${nc}" class="muted">Aucune ligne. Retournez à la saisie pour ajouter des ouvrages.</td></tr>`;
  h += '</tbody>';
  if (avecPrix && L.length) {
    h += `<tfoot><tr><td colspan="${nc - 2}">Total indicatif HT${sansPrix ? ` (${sansPrix} ligne(s) sans prix non comptée(s))` : ''}</td>
      <td class="mt">${fmt(total)} €</td><td></td></tr></tfoot>`;
  }
  h += '</table>';
  $('tableMetre').innerHTML = h;
}

/* ============ Assistant électricité (repères NF C 15-100) ============ */
// Règles par type de local (pour un logement). Clés = désignations exactes du lot Électricité.
// Repères courants : à vérifier avec le guide Consuel et l'installateur avant utilisation.
const ELEC_REGLES = {
  "Séjour": { "Prise de courant 16 A": 5, "Prise TV ou antenne": 1, "Prise RJ45 (réseau)": 1, "Point lumineux plafonnier": 1, "Interrupteur simple": 2 },
  "Chambre": { "Prise de courant 16 A": 3, "Prise RJ45 (réseau)": 1, "Point lumineux plafonnier": 1, "Interrupteur simple": 1, "Détecteur autonome de fumée": 1 },
  "Cuisine": { "Prise de courant 16 A": 6, "Ligne spécialisée (cuisson, four, lave-linge, lave-vaisselle)": 2, "Point lumineux plafonnier": 1, "Interrupteur simple": 1 },
  "Salle de bains": { "Prise de courant 16 A": 1, "Point lumineux plafonnier": 1, "Interrupteur simple": 1, "Liaison équipotentielle de salle d'eau": 1 },
  "Salle d'eau": { "Prise de courant 16 A": 1, "Point lumineux plafonnier": 1, "Interrupteur simple": 1, "Liaison équipotentielle de salle d'eau": 1 },
  "WC": { "Point lumineux plafonnier": 1, "Interrupteur simple": 1 },
  "Entrée / dégagement": { "Point lumineux plafonnier": 1, "Interrupteur simple": 2, "Prise de courant 16 A": 1 },
  "Bureau": { "Prise de courant 16 A": 4, "Prise RJ45 (réseau)": 1, "Point lumineux plafonnier": 1, "Interrupteur simple": 1 },
  "Buanderie / cellier": { "Prise de courant 16 A": 2, "Ligne spécialisée (cuisson, four, lave-linge, lave-vaisselle)": 1, "Point lumineux plafonnier": 1, "Interrupteur simple": 1 },
  "Garage": { "Prise de courant 16 A": 2, "Point lumineux plafonnier": 1, "Interrupteur simple": 1 },
  "Dressing": { "Point lumineux plafonnier": 1, "Interrupteur simple": 1 },
  "Mezzanine": { "Point lumineux plafonnier": 1, "Interrupteur simple": 1, "Prise de courant 16 A": 1 },
  "Cage d'escalier": { "Point lumineux plafonnier": 1, "Interrupteur simple": 2 },
  "Cave": { "Point lumineux plafonnier": 1, "Interrupteur simple": 1 },
  "Extérieur (terrasse)": { "Prise extérieure étanche": 1, "Éclairage extérieur (applique ou borne)": 1 }
};
// Désignations proposées dans le menu « Pièce » -> règle à appliquer
const ELEC_PIECE_TYPES = {
  "Entrée": "Entrée / dégagement", "Dégagement": "Entrée / dégagement",
  "Toilette": "WC", "Salle d'eau": "Salle d'eau", "Salle de bain": "Salle de bains",
  "Chambre": "Chambre", "Salon": "Séjour", "Séjour": "Séjour", "Pièce de vie": "Séjour",
  "Cuisine": "Cuisine", "Dressing": "Dressing", "Cellier": "Buanderie / cellier",
  "Buanderie": "Buanderie / cellier", "Cellier buanderie": "Buanderie / cellier",
  "Mezzanine": "Mezzanine", "Cage d'escalier": "Cage d'escalier", "Cave": "Cave", "Garage": "Garage",
  "Terrasse extérieure": "Extérieur (terrasse)"
};
// Numéro ou nom ajouté après la désignation (« Chambre 2 », « Salle d'eau parentale »)
const ELEC_QUALIFS = ['', '1', '2', '3', '4', '5', 'parentale'];
function nomPiece(p) { return p.type + (p.qualif ? ' ' + p.qualif : ''); }
// Quantités à partir de la liste des pièces : points, circuits, différentiels, tableau, câbles
function elecCalcul(pieces) {
  const totaux = {};
  const ajouter = (d, n) => { totaux[d] = (totaux[d] || 0) + n; };
  let points = 0, nbPieces = 0;
  for (const p of pieces) {
    nbPieces += p.nb;
    for (const [d, n] of Object.entries(ELEC_REGLES[ELEC_PIECE_TYPES[p.type]] || {})) {
      ajouter(d, n * p.nb);
      if (!/Ligne spécialisée|Liaison|Détecteur/.test(d)) points += n * p.nb;
    }
  }
  // Circuits (repères courants) : éclairage 1,5 mm² max 8 points ; prises 2,5 mm² max 8 prises ;
  // un circuit par appareil spécialisé ; un circuit VMC. Différentiels 30 mA : au moins 2, puis 1 pour 8 circuits.
  const nbPoints = totaux['Point lumineux plafonnier'] || 0;
  const nbPrises = (totaux['Prise de courant 16 A'] || 0) + (totaux['Prise extérieure étanche'] || 0);
  const nbSpec = totaux['Ligne spécialisée (cuisson, four, lave-linge, lave-vaisselle)'] || 0;
  const cEcl = nbPoints ? Math.ceil(nbPoints / 8) : 0;
  const cPri = nbPrises ? Math.ceil(nbPrises / 8) : 0;
  const circuits = cEcl + cPri + nbSpec + 1;
  const ddr = Math.max(2, Math.ceil(circuits / 8));
  // Tableau : disjoncteurs + différentiels (2 modules chacun) + branchement (2 modules), réserve de 20 %
  const modules = Math.ceil((circuits + 2 * ddr + 2) * 1.2);
  const tableau = modules <= 12 ? 'Tableau électrique 12 modules avec protections'
    : modules <= 24 ? 'Tableau électrique 24 modules avec protections'
    : modules <= 36 ? 'Tableau électrique 36 modules avec protections'
    : modules <= 48 ? 'Tableau électrique 48 modules avec protections'
    : 'Tableau électrique 4 rangées (logement > 100 m²)';
  ajouter(tableau, 1);
  ajouter('Disjoncteur de branchement', 1);
  ajouter('Disjoncteur divisionnaire (1 par circuit)', circuits);
  ajouter('Interrupteur différentiel 30 mA', ddr);
  ajouter('Mise à la terre (piquet de terre)', 1);
  // Câbles par circuit : longueurs moyennes estimées (à remplacer par les longueurs réelles du plan)
  if (cEcl) ajouter('Câble circuit éclairage 1,5 mm² (ml)', cEcl * 15);
  if (cPri) ajouter('Câble circuit prises 2,5 mm² (ml)', cPri * 30);
  if (nbSpec) ajouter('Câble circuit spécialisé 2,5 ou 6 mm² (ml)', nbSpec * 20);
  ajouter('Câble circuit VMC 1,5 mm² (ml)', 15);
  if (points) ajouter('Câblage en gaine ICTA', points * 3);   // estimation : 3 ml par point ou prise
  totaux.__resume = { circuits, ddr, modules, tableau: tableau.match(/\d+ modules|4 rangées/)[0] };
  return totaux;
}
// Crée les lignes du lot Électricité (les lignes générées précédemment sont remplacées)
function genererElec() {
  const c = chantiers.find(x => x.id === courantId);
  const pieces = (c && c.elec && c.elec.pieces) || [];
  if (!pieces.length) { sauverLignes(courantId, lignesDe(courantId).filter(l => !l.auto)); renderMetre(); return 'Ajoutez d\'abord les pièces.'; }
  const totaux = elecCalcul(pieces);
  const r = totaux.__resume; delete totaux.__resume;
  ajouterLotSiAbsent(courantId, 'electricite');
  const L = lignesDe(courantId).filter(l => !l.auto);
  const manquants = [];
  let nb = 0;
  for (const [des, n] of Object.entries(totaux)) {
    const o = BIB.ouvrages.find(x => x.lot === 'electricite' && !x.supprime && x.designation === des);
    if (!o) { manquants.push(des); continue; }
    const valeurs = o.unite === 'ml' ? { nombre: '1', cote1: String(n) } : { nombre: String(n) };
    L.push({ uid: uid(), lot: 'electricite', ouvrage: o.id, designation: o.designation, unite: o.unite,
             valeurs, quantite: calcul(o, valeurs), surface: null, prix: 'moyen', auto: true, cree: new Date().toISOString() });
    nb++;
  }
  sauverLignes(courantId, L);
  renderMetre();
  let msg = nb + ' ligne(s) générée(s) : ' + r.circuits + ' circuits, ' + r.ddr + ' différentiel(s) 30 mA, tableau ' + r.tableau + '.';
  if (manquants.length) msg += ' Non trouvées dans la bibliothèque : ' + manquants.join(', ');
  return msg;
}
function ouvrirAssistantElec(message) { ouvrirConfigurateur(message); }

/* ============ Configurateur des pièces (électricité, plâtrerie, sols, plinthes) ============ */
// Une seule liste de pièces par chantier (c.elec.pieces). Chaque pièce porte ses murs, portes et placards, saisis en brut.
// Les murs des pièces d'eau (salle d'eau, salle de bain) passent automatiquement en hydrofuge : pas de déduction à faire.
const PLAT_PLAFOND = 'Plafond suspendu BA13';
const PLAT_PLAFOND_HYDRO = "Plafond hydrofuge BA13 (salle d'eau)";
const PLAT_CLOISON_HYDRO = "Cloison hydrofuge BA13 (salle d'eau)";
const PLAT_DOUBLAGE_HYDRO = "Doublage hydrofuge BA13 sur mur (pièce d'eau)";
const PLAT_EAU = /Salle d'eau|Salle de bain/;
const PORTE_AUTO = 'Automatique (selon la largeur)';
// Équipements proposés selon la pièce (désignations exactes de la bibliothèque, lot Plomberie & sanitaire ou Cuisine)
const EQUIP_DOUCHE = ['Douche italienne avec receveur extra-plat', 'Bac de douche composite 140 x 80', 'Colonne de douche thermostatique avec douchette', 'Robinetterie douche (mitigeur)', 'Pare-douche en verre', 'Siphon de sol douche', 'Receveur extra-plat 140×100', 'Receveur extra-plat 120×100', 'Receveur 90×90'];
const EQUIP_VASQUE = ['Meuble simple vasque + miroir', 'Meuble double vasque + miroirs', 'Lavabo avec robinetterie', 'Lavabo vasque', 'Robinetterie lavabo'];
const EQUIP_CHAUFFE = ['Sèche-serviette', 'Sèche-serviette électrique'];
const EQUIP_WC = ['WC suspendu avec bâti-support', 'WC posé', 'Lave-main séparé'];
const EQUIP_CUISINE = ['Évier inox un bac', 'Évier en granit', 'Évier et robinetterie cuisine', 'Robinetterie de cuisine', 'Robinet de cuisine avec douchette', 'Lave-vaisselle encastrable', 'Alimentation et évacuation lave-vaisselle', 'Alimentation et évacuation machine à laver'];
const EQUIP_BUANDERIE = ['Alimentation et évacuation machine à laver', 'Alimentation et évacuation lave-vaisselle', 'Évier inox un bac', 'Évier en granit'];
function equipOptions(p) {
  if (p.type === 'Salle de bain') return ['Baignoire avec robinetterie', 'Baignoire acrylique (installation)', ...EQUIP_DOUCHE, ...EQUIP_VASQUE, ...EQUIP_CHAUFFE, ...EQUIP_WC];
  if (p.type === "Salle d'eau") return [...EQUIP_DOUCHE, ...EQUIP_VASQUE, ...EQUIP_CHAUFFE, ...EQUIP_WC];
  if (p.type === 'Toilette') return EQUIP_WC;
  if (p.type === 'Cuisine') return EQUIP_CUISINE;
  if (p.type === 'Buanderie' || p.type === 'Cellier' || p.type === 'Cellier buanderie') return EQUIP_BUANDERIE;
  return [];
}
function platPlinthe(sol) {
  if (/carrelage/i.test(sol)) return 'Plinthes carrelées';
  if (/parquet/i.test(sol)) return 'Plinthes bois';
  return 'Plinthes MDF';
}
// Périmètre saisi, sinon estimé : 4 × racine carrée de la surface (pièce supposée carrée)
// Pièce rectangulaire (longueur × largeur) : surface et périmètre exacts. Sinon périmètre saisi, sinon estimé.
function piecePerimExact(p) { return num(p.longueur) > 0 && num(p.largeur) > 0; }
function platPerim(p) {
  if (piecePerimExact(p)) return 2 * (num(p.longueur) + num(p.largeur));
  return num(p.perim) > 0 ? num(p.perim) : 4 * Math.sqrt(num(p.surf));
}
// Plinthes : périmètre moins la largeur des portes, passages libres et placards posés au sol (pas de plinthe à ces endroits)
function platPlinthesMl(p) {
  const passages = [...(p.portes || []), ...(p.ouvertures || []), ...(p.placards || [])].reduce((a, x) => a + num(x.largeur) * (num(x.nb) || 1), 0);
  return Math.max(0, platPerim(p) - passages);
}
// Bloc-porte fin de chantier choisi selon la largeur saisie (en m, ou en cm si > 10)
function porteAuto(largeur) {
  let l = num(largeur); if (l > 10) l = l / 100;
  return l >= 0.83 ? 'Bloc-porte fin de chantier 83×204' : l >= 0.73 ? 'Bloc-porte fin de chantier 73×204' : 'Bloc-porte fin de chantier 63×204';
}
function piecesDe(c) {
  c.elec = c.elec || { pieces: [] };
  c.elec.pieces = c.elec.pieces || [];
  return c.elec.pieces;
}
function platDe(c) {
  if (!c.plat) c.plat = { hauteur: '2.50' };
  return c.plat;
}
function platListe(re, unite, exclure) {
  return BIB.ouvrages
    .filter(o => !o.supprime && o.unite === unite && re.test(o.designation) && !(exclure && exclure.test(o.designation)))
    .map(o => o.designation).filter((d, i, t) => t.indexOf(d) === i);
}
const platSols = () => platListe(/parquet|carrelage|sol |vinyle|moquette|béton ciré|pierre|résine/i, 'm²',
  /extérieur|chape|dépose|protection|plinthe|mural|vitrification|support|sur isolant/i);
const platCloisons = () => platListe(/cloison/i, 'm²', /démolition|dépose|hydrofuge|gaine/i);
const platDoublages = () => platListe(/doublage/i, 'm²', /hydrofuge/i);
const platPortes = () => platListe(/porte|galandage/i, 'u',
  /extérieur|entrée|service|garage|palière|fenêtre|seuil|dépose|démolition|placard|huisserie|quincaillerie/i);
const platPlacards = () => platListe(/façade de placard/i, 'm²');

// Calcule toutes les quantités à partir des pièces (et de la hauteur), puis crée les lignes des lots concernés
function genererPlat() {
  const c = chantiers.find(x => x.id === courantId);
  if (!c) return 'Ouvrez d\'abord un chantier.';
  const P = platDe(c), pieces = piecesDe(c);
  const H = num(P.hauteur) || 2.5;
  const totaux = {}, manquants = [], puisages = [];
  const add = (des, q) => { if (des && q > 0) totaux[des] = (totaux[des] || 0) + q; };
  let dedTot = 0, murPeint = 0;
  for (const p of pieces) {
    const nb = num(p.nb) || 1, nom = nomPiece(p), eau = PLAT_EAU.test(p.type);
    const surf = num(p.surf) * nb;
    if (!(surf > 0)) manquants.push('surface de ' + nom);
    else {
      add(eau ? PLAT_PLAFOND_HYDRO : PLAT_PLAFOND, surf);
      add('Peinture plafond deux couches', surf);
      if (!p.sol) manquants.push('revêtement de sol de ' + nom);
      else { add(p.sol, surf); add(platPlinthe(p.sol), platPlinthesMl(p) * nb); }
    }
    // Équipements sanitaires et de cuisine (nombre saisi × nombre de pièces)
    // Chaque équipement reste une ligne par pièce, pour savoir où il se trouve
    for (const x of p.equip || []) puisages.push({ des: x.type, q: (num(x.nb) || 1) * nb, piece: nom });
    // Murs bruts : linéaire × hauteur. Ouvertures (portes, fenêtres, passages libres) de plus de 2 m² déduites
    // proportionnellement des cloisons et doublages de la pièce. En pièce d'eau, tout passe en hydrofuge.
    const cloi = p.cloisons || [], doub = p.doublages || [];
    const cloiBrut = cloi.reduce((a, x) => a + num(x.ml) * H * nb, 0);
    const doubBrut = doub.reduce((a, x) => a + num(x.ml) * H * nb, 0);
    const brut = cloiBrut + doubBrut;
    let ded = 0, dedAll = 0;
    for (const x of [...(p.portes || []), ...(p.fenetres || []), ...(p.ouvertures || []), ...(p.placards || [])]) {
      const une = num(x.largeur) * num(x.hauteur);   // surface d'une ouverture
      const total = une * (num(x.nb) || 1) * nb;
      dedAll += total;   // peinture : toutes les ouvertures sont déduites
      if (une >= 2) ded += total;   // plâtrerie : seules les ouvertures de 2 m² ou plus (une à une)
    }
    ded = Math.min(ded, brut);
    dedTot += ded;
    const f = brut > 0 ? (brut - ded) / brut : 0;
    for (const x of cloi) add(eau ? PLAT_CLOISON_HYDRO : x.type, num(x.ml) * H * nb * f);
    for (const x of doub) add(eau ? PLAT_DOUBLAGE_HYDRO : x.type, num(x.ml) * H * nb * f);
    // Peinture : cloison peinte des deux faces, doublage d'une face (même déduction des ouvertures)
    // Peinture : toutes les ouvertures déduites, au prorata de chaque type de mur
    if (brut > 0) murPeint += (2 * cloiBrut + doubBrut) * Math.max(0, brut - dedAll) / brut;
    for (const x of p.portes || []) {
      add(x.type === PORTE_AUTO ? porteAuto(x.largeur) : x.type, num(x.nb) * nb);
      if (P.peintPortes) add('Peinture portes et huisseries', num(x.nb) * nb);
    }
    for (const x of p.placards || []) add(x.type, num(x.nb) * num(x.largeur) * num(x.hauteur) * nb);
  }
  add('Peinture acrylique murs deux couches', murPeint);
  if (!Object.keys(totaux).length && !puisages.length) { sauverLignes(courantId, lignesDe(courantId).filter(l => !l.plat)); renderMetre(); return 'Ajoutez d\'abord des pièces et leurs murs, portes ou placards.'; }
  const L = lignesDe(courantId).filter(l => !l.plat);
  let nb = 0;
  for (const [des, q] of Object.entries(totaux)) {
    const o = BIB.ouvrages.find(x => !x.supprime && x.designation === des);
    if (!o) { manquants.push(des); continue; }
    ajouterLotSiAbsent(courantId, o.lot);
    // Quantité selon l'unité : m² = surface, ml = longueur, u = nombre
    const valeurs = o.unite === 'm²' ? { nombre: '1', cote1: q.toFixed(2), cote2: '1' }
      : o.unite === 'ml' ? { nombre: '1', cote1: q.toFixed(2) }
      : { nombre: String(Math.round(q)) };
    L.push({ uid: uid(), lot: o.lot, ouvrage: o.id, designation: o.designation, unite: o.unite,
             valeurs, quantite: calcul(o, valeurs), surface: null, prix: 'moyen', plat: true, cree: new Date().toISOString() });
    nb++;
  }
  // Eau de pluie : WC et lave-linge uniquement (jamais douche, lavabo, évier, lave-vaisselle) ; une plaque par point, par pièce
  if (projetDe(c).equip && projetDe(c).equip.cuve === 'interieur') {
    const oPl = BIB.ouvrages.find(x => !x.supprime && x.designation === 'Plaque « eau non potable » à chaque point de soutirage');
    if (!oPl) manquants.push('Plaque « eau non potable »');
    else for (const pu of pieces) {
      const n = pointsEauPluiePiece(pu);
      if (!(n > 0)) continue;
      ajouterLotSiAbsent(courantId, oPl.lot);
      const valeurs = { nombre: String(n) };
      L.push({ uid: uid(), lot: oPl.lot, ouvrage: oPl.id, designation: `Plaque « eau non potable » (WC et lave-linge) – ${nomPiece(pu)}`,
               unite: oPl.unite, valeurs, quantite: calcul(oPl, valeurs), surface: null, prix: 'moyen', plat: true, cree: new Date().toISOString() });
      nb++;
    }
  }
  // Équipements par pièce : « Point de puisage » pour la robinetterie, évier, lavabo, douche, baignoire
  const PUISAGE = /Robinet|Robinetterie|Évier|Lavabo|Douche|Mitigeur|Baignoire/i;
  for (const pu of puisages) {
    const o = BIB.ouvrages.find(x => !x.supprime && x.designation === pu.des);
    if (!o) { manquants.push(pu.des); continue; }
    ajouterLotSiAbsent(courantId, o.lot);
    const valeurs = o.unite === 'ml' ? { nombre: '1', cote1: String(pu.q) } : { nombre: String(Math.round(pu.q)) };
    L.push({ uid: uid(), lot: o.lot, ouvrage: o.id, designation: PUISAGE.test(o.designation) ? `Point de puisage – ${pu.piece} : ${o.designation}` : `${o.designation} – ${pu.piece}`,
             unite: o.unite, valeurs, quantite: calcul(o, valeurs), surface: null, prix: 'moyen', plat: true, cree: new Date().toISOString() });
    nb++;
  }
  sauverLignes(courantId, L);
  renderMetre();
  let msg = nb + ' ligne(s) plâtrerie, sols, plinthes, portes et équipements générée(s).';
  const estimees = pieces.filter(p => num(p.surf) > 0 && !piecePerimExact(p) && !(num(p.perim) > 0)).map(p => nomPiece(p));
  if (estimees.length) msg += ' Périmètre estimé (saisissez longueur et largeur pour un calcul exact) : ' + estimees.join(', ') + '.';
  if (dedTot > 0) msg += ' Ouvertures de 2 m² ou plus déduites des murs : ' + fmt(dedTot) + ' m².';
  const uniques = manquants.filter((d, i, t) => t.indexOf(d) === i);
  if (uniques.length) msg += ' À compléter : ' + uniques.join(' ; ') + '.';
  return msg;
}
function ouvrirConfigurateur(message) {
  const c = chantiers.find(x => x.id === courantId);
  if (!c) return;
  const P = platDe(c), pieces = piecesDe(c);
  const opt = (liste, val) => `<option value="">— choisir —</option>` + liste.map(d => `<option ${d === val ? 'selected' : ''}>${esc(d)}</option>`).join('');
  const optPortes = () => `<option value="">— choisir —</option><option>${esc(PORTE_AUTO)}</option>` + platPortes().map(d => `<option>${esc(d)}</option>`).join('');
  const subListe = (items, i, cat, texte) => items.map((x, k) => `<div class="ouv"><span>${texte(x)}</span><button type="button" class="btn small danger" data-pldel="${i}:${cat}:${k}">✕</button></div>`).join('');
  const carte = (p, i) => {
    const eau = PLAT_EAU.test(p.type);
    return `<div style="border:1px solid #d9cfe6;border-radius:10px;padding:10px;margin:10px 0">
      <div class="row" style="justify-content:space-between;align-items:center">
        <strong>${esc(nomPiece(p))}${eau ? ' · pièce d\'eau (murs hydrofuges)' : ''}</strong>
        <button type="button" class="btn small danger" data-pldel="${i}">Supprimer la pièce</button>
      </div>
      <div class="row" style="flex-wrap:wrap;gap:6px;margin-top:6px">
        <label style="font-size:12px">Nombre <input data-plrow="${i}:nb" inputmode="numeric" value="${esc(p.nb)}" style="width:60px"></label>
        <label style="font-size:12px">Longueur m <input data-plrow="${i}:longueur" inputmode="decimal" value="${esc(p.longueur || '')}" style="width:70px"></label>
        <label style="font-size:12px">Largeur m <input data-plrow="${i}:largeur" inputmode="decimal" value="${esc(p.largeur || '')}" style="width:70px"></label>
        <label style="font-size:12px">Surface m² <input data-plrow="${i}:surf" inputmode="decimal" value="${esc(p.surf || '')}" style="width:80px"></label>
        <label style="font-size:12px">Périmètre ml <input data-plrow="${i}:perim" inputmode="decimal" value="${esc(p.perim || '')}" placeholder="auto" style="width:80px"></label>
        <select data-plrow="${i}:sol" style="flex:1;min-width:160px">${opt(platSols(), p.sol || '')}</select>
      </div>
      ${equipOptions(p).length ? `<p class="muted" style="margin:10px 0 2px">Équipements (nombre)</p>
      ${subListe(p.equip || [], i, 'equip', x => `${esc(x.type)} × ${num(x.nb)}`)}
      <div class="row" style="margin-top:4px;flex-wrap:wrap"><select id="pl_${i}_equip_type" style="flex:1;min-width:200px">${opt(equipOptions(p))}</select><input id="pl_${i}_equip_nb" inputmode="numeric" value="1" placeholder="Nb" style="width:60px"><button type="button" class="btn sec small" data-pladd="${i}:equip">+ Équipement</button></div>` : ''}
      <p class="muted" style="margin:10px 0 2px">Murs (linéaire brut, hauteur ${num(P.hauteur) || 2.5} m)</p>
      ${subListe(p.cloisons || [], i, 'cloisons', x => `Cloison · ${esc(x.type)} · ${fmt(num(x.ml))} ml`)}
      <div class="row" style="margin-top:4px"><select id="pl_${i}_cloisons_type" style="flex:1">${opt(platCloisons())}</select><input id="pl_${i}_cloisons_ml" inputmode="decimal" placeholder="ml" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:cloisons">+ Cloison</button></div>
      ${subListe(p.doublages || [], i, 'doublages', x => `Doublage · ${esc(x.type)} · ${fmt(num(x.ml))} ml`)}
      <div class="row" style="margin-top:4px"><select id="pl_${i}_doublages_type" style="flex:1">${opt(platDoublages())}</select><input id="pl_${i}_doublages_ml" inputmode="decimal" placeholder="ml" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:doublages">+ Doublage</button></div>
      ${subListe(p.portes || [], i, 'portes', x => `Porte · ${esc(x.type)} · ${num(x.nb)} × ${fmt(num(x.largeur))} × ${fmt(num(x.hauteur))} m`)}
      <div class="row" style="margin-top:4px;flex-wrap:wrap"><select id="pl_${i}_portes_type" style="flex:1;min-width:180px">${optPortes()}</select><input id="pl_${i}_portes_nb" inputmode="numeric" value="1" placeholder="Nb" style="width:60px"><input id="pl_${i}_portes_l" inputmode="decimal" placeholder="Larg. m" style="width:80px"><input id="pl_${i}_portes_h" inputmode="decimal" placeholder="Haut. m" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:portes">+ Porte</button></div>
      ${subListe(p.fenetres || [], i, 'fenetres', x => `Fenêtre · ${num(x.nb)} × ${fmt(num(x.largeur))} × ${fmt(num(x.hauteur))} m`)}
      <div class="row" style="margin-top:4px;flex-wrap:wrap"><span class="muted" style="flex:1;min-width:180px">Fenêtre (déduite des murs si ≥ 2 m²)</span><input id="pl_${i}_fenetres_nb" inputmode="numeric" value="1" placeholder="Nb" style="width:60px"><input id="pl_${i}_fenetres_l" inputmode="decimal" placeholder="Larg. m" style="width:80px"><input id="pl_${i}_fenetres_h" inputmode="decimal" placeholder="Haut. m" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:fenetres">+ Fenêtre</button></div>
      ${subListe(p.ouvertures || [], i, 'ouvertures', x => `Ouverture libre · ${num(x.nb)} × ${fmt(num(x.largeur))} × ${fmt(num(x.hauteur))} m`)}
      <div class="row" style="margin-top:4px;flex-wrap:wrap"><span class="muted" style="flex:1;min-width:180px">Ouverture libre (passage)</span><input id="pl_${i}_ouvertures_nb" inputmode="numeric" value="1" placeholder="Nb" style="width:60px"><input id="pl_${i}_ouvertures_l" inputmode="decimal" placeholder="Larg. m" style="width:80px"><input id="pl_${i}_ouvertures_h" inputmode="decimal" placeholder="Haut. m" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:ouvertures">+ Ouverture</button></div>
      ${subListe(p.placards || [], i, 'placards', x => `Placard · ${esc(x.type)} · ${num(x.nb)} × ${fmt(num(x.largeur))} × ${fmt(num(x.hauteur))} m`)}
      <div class="row" style="margin-top:4px;flex-wrap:wrap"><select id="pl_${i}_placards_type" style="flex:1;min-width:180px">${opt(platPlacards())}</select><input id="pl_${i}_placards_nb" inputmode="numeric" value="1" placeholder="Nb" style="width:60px"><input id="pl_${i}_placards_l" inputmode="decimal" placeholder="Larg. m" style="width:80px"><input id="pl_${i}_placards_h" inputmode="decimal" placeholder="Haut. m" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:placards">+ Placard</button></div>
    </div>`;
  };
  $('cfgPieces').innerHTML = `<h2 style="margin:18px 0 4px;font-size:18px">Pièces, murs, portes et équipements</h2>
    <p class="muted">Saisissez chaque pièce une seule fois, avec ses murs, portes et placards en brut. Le calcul distingue seul les pièces d'eau d'après leur nom.</p>
    <label for="plH">Hauteur sous plafond (m)</label>
    <input id="plH" inputmode="decimal" value="${esc(P.hauteur)}">
    <label style="display:flex;align-items:center;gap:8px;margin-top:8px;font-size:14px"><input type="checkbox" id="plPeint" ${P.peintPortes ? 'checked' : ''} style="width:auto;height:auto;margin:0"> Portes peintes sur place (sinon fournies prépeintes)</label>
    <h3 style="margin:14px 0 4px;font-size:15px">Ajouter une pièce</h3>
    <div class="row">
      <select id="plType" style="flex:1">${Object.keys(ELEC_PIECE_TYPES).map(t => `<option>${esc(t)}</option>`).join('')}</select>
      <select id="plQual" style="width:130px">${ELEC_QUALIFS.map(q => `<option value="${esc(q)}">${q || '(aucun)'}</option>`).join('')}</select>
    </div>
    <div class="row" style="margin-top:6px">
      <input id="plNb" inputmode="numeric" value="1" placeholder="Nombre" style="width:90px">
      <input id="plSurf" inputmode="decimal" placeholder="Surface (m²)" style="flex:1">
      <input id="plPerim" inputmode="decimal" placeholder="Périmètre (ml, facultatif)" style="flex:1">
    </div>
    <div class="row" style="margin-top:6px">
      <input id="plL" inputmode="decimal" placeholder="Longueur (m)" style="flex:1">
      <input id="plLa" inputmode="decimal" placeholder="Largeur (m)" style="flex:1">
    </div>
    <p class="muted" style="margin:2px 0 0">Longueur et largeur donnent la surface et le périmètre exacts.</p>
    <select id="plSol" style="width:100%;margin-top:6px">${opt(platSols())}</select>
    <div class="row" style="margin-top:6px"><button type="button" class="btn sec" id="plAjPiece">Ajouter ou mettre à jour la pièce</button></div>
    <h3 style="margin:14px 0 0;font-size:15px">Pièces et leurs murs</h3>
    ${pieces.map(carte).join('') || '<p class="muted">Aucune pièce.</p>'}
`;
}
function sauverPlat(c) { lsSet('chantiers', chantiers); marquerChantier(c.id); synchroConfig(); }
// Mise à jour automatique du métré à partir du configurateur (électricité, plâtrerie, sanitaires, fiche projet)
let _synchroT = null;
function synchroConfig() {
  if (!courantId) return;
  clearTimeout(_synchroT);
  _synchroT = setTimeout(() => {
    majQuantitesAuto(chantiers.find(x => x.id === courantId));
    if ($('cfgStatut')) $('cfgStatut').textContent = 'Configurateur enregistré. Rien n\'est ajouté au métré : saisissez vos lignes, puis utilisez « Revue complète avant édition ».';
  }, 300);
}
// Revue complète : calcule ce que le configurateur demande, et propose d'ajouter chaque ligne manquante (oui / non)
function revueConfigurateur() {
  const c = chantiers.find(x => x.id === courantId);
  if (!c) return;
  _revueCollecte = {};
  try { genererElec(); genererPlat(); ficheVersMetre(); }
  finally { var col = _revueCollecte; _revueCollecte = null; }
  const existantes = lignesDe(courantId);
  const dejaLa = l => existantes.some(x => x.uid === l.uid || (x.ouvrage === l.ouvrage && x.designation === l.designation));
  const props = [], vus = new Set();
  for (const L of Object.values(col)) for (const l of L) {
    if (!l.ouvrage || dejaLa(l)) continue;
    const cle = l.ouvrage + '|' + l.designation;
    if (vus.has(cle)) continue;
    vus.add(cle); props.push(l);
  }
  let h = `<h2 style="margin:0 0 6px;font-size:18px">Revue complète avant édition</h2>`;
  if (!props.length) {
    h += `<p class="muted">Rien à ajouter : tout ce que vous avez saisi dans le configurateur est déjà dans le métré, ou il n'y a rien à calculer.</p>`;
  } else {
    h += `<p class="muted" style="font-size:13px">Cochez les lignes à ajouter au métré. Les lignes non cochées ne seront pas ajoutées.</p>`;
    const par = {};
    props.forEach((l, i) => { (par[l.lot] = par[l.lot] || []).push([l, i]); });
    for (const [lot, items] of Object.entries(par)) {
      h += `<h3 style="font-size:14px;margin:12px 0 4px">${esc(libLot(lot))}</h3>`;
      for (const [l, i] of items) {
        h += `<label style="display:flex;gap:8px;align-items:flex-start;padding:6px 0;border-bottom:1px solid #eee;font-size:14px">
          <input type="checkbox" data-rev="${i}" style="margin-top:3px"><span style="flex:1">${esc(l.designation)}</span>
          <span class="muted" style="white-space:nowrap">${l.quantite ? fmt(Number(l.quantite)) + ' ' + esc(l.unite) : 'à saisir'}</span></label>`;
      }
    }
    h += `<div class="row" style="margin-top:12px;gap:8px"><button type="button" id="revAjouter" class="btn">Ajouter les lignes cochées</button><button type="button" id="revFermer" class="btn sec">Fermer</button></div>`;
  }
  if (!props.length) h += `<div class="row" style="margin-top:12px"><button type="button" id="revFermer" class="btn sec">Fermer</button></div>`;
  $('sheet').innerHTML = h;
  ouvrirModal();
  if ($('revFermer')) $('revFermer').onclick = fermer;
  if ($('revAjouter')) $('revAjouter').onclick = () => {
    const coches = [...document.querySelectorAll('[data-rev]')].filter(x => x.checked).map(x => props[+x.dataset.rev]);
    const L = lignesDe(courantId).concat(coches);
    sauverLignes(courantId, L);
    renderMetre();
    fermer();
    if ($('cfgStatut')) $('cfgStatut').textContent = coches.length + ' ligne(s) ajoutée(s) au métré après revue.';
  };
}
if ($('btnRevue')) $('btnRevue').addEventListener('click', revueConfigurateur);
// Retire du métré, dans tous les chantiers, les lignes générées automatiquement (les lignes saisies à la main restent)
function retirerLignesAuto() {
  const n = chantiers.reduce((a, c) => a + lignesDe(c.id).filter(l => l.auto || l.plat || l.projet).length, 0);
  if (!n) { if ($('cfgStatut')) $('cfgStatut').textContent = 'Aucune ligne générée automatiquement à retirer.'; return; }
  if (!confirm(n + ' ligne(s) générée(s) automatiquement seront retirées de tous les chantiers. Vos lignes saisies à la main ne sont pas touchées. Continuer ?')) return;
  for (const c of chantiers) {
    const L = lignesDe(c.id), garde = L.filter(l => !(l.auto || l.plat || l.projet));
    if (garde.length !== L.length) sauverLignes(c.id, garde);
  }
  renderMetre();
  if ($('cfgStatut')) $('cfgStatut').textContent = n + ' ligne(s) générée(s) retirée(s). Vos lignes saisies à la main sont conservées.';
}
if ($('btnRetirerAuto')) $('btnRetirerAuto').addEventListener('click', retirerLignesAuto);
// Ajoute une pièce, ou met à jour celle qui existe déjà (même nom et même numéro) : pas de doublon, murs conservés
function ajouterPiece(c, p) {
  const L = piecesDe(c);
  const deja = L.find(x => x.type === p.type && (x.qualif || '') === (p.qualif || ''));
  if (deja) Object.assign(deja, p);
  else L.push(Object.assign(p, { equip: [], cloisons: [], doublages: [], portes: [], fenetres: [], ouvertures: [], placards: [] }));
}
if ($('vConfig')) $('vConfig').addEventListener('click', e => {
  const c = chantiers.find(x => x.id === courantId);
  if (!c) return;
  const v = id => ($(id) ? $(id).value.trim() : '');
  // Ajout d'un mur, d'une porte ou d'un placard dans une pièce
  const ajout = e.target.closest('[data-pladd]');
  if (ajout) {
    const [i, cat] = ajout.dataset.pladd.split(':');
    const p = piecesDe(c)[parseInt(i, 10)]; if (!p) return;
    const pre = `pl_${i}_${cat}_`;
    if (cat === 'cloisons' || cat === 'doublages') {
      if (v(pre + 'type')) p[cat].push({ type: v(pre + 'type'), ml: v(pre + 'ml') });
    } else if (cat === 'portes') {
      if (v(pre + 'type')) p.portes.push({ type: v(pre + 'type'), nb: v(pre + 'nb') || '1', largeur: v(pre + 'l'), hauteur: v(pre + 'h') });
    } else if (cat === 'equip') {
      if (v(pre + 'type')) {
        p.equip = p.equip || [];
        p.equip.push({ type: v(pre + 'type'), nb: v(pre + 'nb') || '1' });
      }
    } else if (cat === 'fenetres' || cat === 'ouvertures') {
      if (v(pre + 'l') && v(pre + 'h')) {
        p[cat] = p[cat] || [];
        p[cat].push({ type: cat === 'fenetres' ? 'Fenêtre' : 'Ouverture libre', nb: v(pre + 'nb') || '1', largeur: v(pre + 'l'), hauteur: v(pre + 'h') });
      }
    } else if (cat === 'placards') {
      if (v(pre + 'type')) p.placards.push({ type: v(pre + 'type'), nb: v(pre + 'nb') || '1', largeur: v(pre + 'l'), hauteur: v(pre + 'h') });
    }
    sauverPlat(c); ouvrirConfigurateur(); return;
  }
  // Suppression d'une pièce (« i ») ou d'un élément de pièce (« i:cat:k »)
  const del = e.target.closest('[data-pldel]');
  if (del) {
    const parts = del.dataset.pldel.split(':');
    const L = piecesDe(c);
    if (parts.length === 1) L.splice(parseInt(parts[0], 10), 1);
    else L[parseInt(parts[0], 10)][parts[1]].splice(parseInt(parts[2], 10), 1);
    sauverPlat(c); ouvrirConfigurateur(); return;
  }
  const b = e.target.closest('button[id^="pl"]');
  if (!b || !$('plH')) return;
  const P = platDe(c);
  P.hauteur = v('plH') || P.hauteur;
  if (b.id === 'plGenElec' || b.id === 'plGen') { sauverPlat(c); revueConfigurateur(); return; }
  if (b.id === 'plAjPiece') {
    if (!v('plType')) return;
    const pc = { type: v('plType'), qualif: v('plQual'), nb: v('plNb') || '1', surf: v('plSurf'), perim: v('plPerim'), longueur: v('plL'), largeur: v('plLa'), sol: v('plSol') };
    if (num(pc.longueur) > 0 && num(pc.largeur) > 0) {
      pc.surf = (num(pc.longueur) * num(pc.largeur)).toFixed(2);
      pc.perim = (2 * (num(pc.longueur) + num(pc.largeur))).toFixed(2);
    }
    ajouterPiece(c, pc);
  }
  else return;
  sauverPlat(c);
  ouvrirConfigurateur();
});
// Modification directe d'une pièce (nombre, surface, périmètre, sol) ou de la hauteur
if ($('vConfig')) $('vConfig').addEventListener('change', e => {
  const c = chantiers.find(x => x.id === courantId); if (!c) return;
  if (e.target.id === 'plPeint') { platDe(c).peintPortes = e.target.checked; sauverPlat(c); return; }
  if (e.target.id === 'plH') { platDe(c).hauteur = e.target.value.trim() || platDe(c).hauteur; sauverPlat(c); return; }
  const t = e.target.dataset.plrow; if (!t) return;
  const [i, champ] = t.split(':');
  const p = piecesDe(c)[parseInt(i, 10)]; if (!p) return;
  p[champ] = e.target.value.trim();
  if (num(p.longueur) > 0 && num(p.largeur) > 0) {
    p.surf = (num(p.longueur) * num(p.largeur)).toFixed(2);
    p.perim = (2 * (num(p.longueur) + num(p.largeur))).toFixed(2);
    sauverPlat(c);
    ouvrirConfigurateur();
    return;
  }
  sauverPlat(c);
});

/* ============ Fiche projet (dimensions et calculs) ============ */
const FICHE_OUV = { 'ouvrant': 'Ouvrant à la française', 'oscillo': 'Oscillo-battant', 'coulissant': 'Coulissant', 'porte': 'Porte', 'porte-fenetre': 'Porte-fenêtre' };
const FICHE_MAT = { 'PVC': 'PVC', 'alu': 'Aluminium', 'bois': 'Bois' };
const FICHE_VOLET = { 'aucun': 'Pas de volet', 'battant': 'Volet battant', 'roulant': 'Volet roulant' };
const FICHE_TOIT = { 'deux-pans': 'Deux pans', 'monopente': 'Monopente', 'plat': 'Toit plat (pente minimale 3,5 %)' };
// Choix de la fiche : « — à choisir — » par défaut, rien n'est proposé tant que vous n'avez pas choisi
const CHOIX_VIDE = ['', '— à choisir —'];
const FICHE_CHARP = { aucune: 'Aucune (je saisis moi-même)', fermette: 'Fermettes industrielles (selon la pente)', traditionnelle: 'Charpente traditionnelle' };
const FICHE_ECRAN = { aucun: 'Aucun (je saisis moi-même)', hpv: 'Écran de sous-toiture HPV', pare: 'Pare-pluie et sous-toiture' };
const FICHE_ISO_TOIT = { aucune: 'Aucune (je saisis moi-même)', rampant: 'Isolation des rampants (laine de roche)', combles: 'Isolation de combles perdus (ouate soufflée)', laine: 'Laine de verre entre chevrons' };
const FICHE_DESC = { pvc: 'PVC', alu: 'Aluminium', zinc: 'Zinc' };
// Équipements de la maison : chaque choix ou quantité peut déclencher des ouvrages de la bibliothèque
const EQ_SEL = [
  ['vmc', 'VMC', [['aucune', 'Aucune'], ['simple', 'Simple flux'], ['double', 'Double flux']]],
  ['anc', 'Assainissement individuel (fosse)', [['oui', 'Oui'], ['non', 'Non']]],
  ['poele', 'Poêle', [['bois', 'Poêle à bois'], ['granules', 'Poêle à granulés'], ['non', 'Non']]],
  ['poele_conduit', 'Poêle à granulés : type de conduit', [['simple', 'Simple Ø 80 ou 100 (tubage flexible)'], ['conc80', 'Concentrique 80/125'], ['conc100', 'Concentrique 100/150']]],
  ['chauffage', 'Chauffage principal', [['aucun', 'Aucun'], ['pac-eau', 'Pompe à chaleur air/eau'], ['pac-air', 'Pompe à chaleur air/air réversible'], ['gaz', 'Chaudière gaz à condensation']]],
  ['plancher', 'Plancher chauffant', [['aucun', 'Aucun'], ['elec', 'Électrique'], ['hydro', 'Hydraulique']]],
  ['radiateurs', 'Radiateurs', [['aucun', 'Aucun'], ['eau', 'Eau chaude'], ['elec', 'Électriques']]],
  ['clim', 'Climatisation', [['aucune', 'Aucune'], ['split', 'Split (unités murales)'], ['gainable', 'Système gainable']]],
  ['clim_grp', 'Type de groupe extérieur (split)', [['mono', 'Mono-split (1 unité intérieure)'], ['bi', 'Bi-split (2 unités intérieures)'], ['tri', 'Tri-split (3 unités intérieures)'], ['quadri', 'Quadri-split (4 unités intérieures)'], ['multi', 'Multi-split (5 unités intérieures et plus)']]],
  ['eau_chaude', 'Production d\'eau chaude', [['aucun', 'Aucune'], ['thermo', 'Chauffe-eau thermodynamique'], ['elec', 'Chauffe-eau électrique 200 L']]],
  ['thermo_type', 'Chauffe-eau thermodynamique : type d\'installation', [['ambiant', 'Sur air ambiant (local non chauffé de plus de 20 m³, hors gel)'], ['gaine', 'Gainé sur air extérieur'], ['split', 'Split (unité extérieure)'], ['extrait', 'Sur air extrait VMC']]],
  ['thermo_litres', 'Chauffe-eau thermodynamique : capacité', [['100', '100 L (1 à 3 personnes)'], ['150', '150 L (2 à 4 personnes)'], ['200', '200 L (3 à 5 personnes)'], ['250', '250 L (5 à 7 personnes)'], ['270', '270 L (5 personnes et plus)']]],
  ['adouc', 'Adoucisseur d\'eau', [['non', 'Non'], ['oui', 'Oui']]],
  ['cuve', 'Cuve de récupération d\'eau de pluie : usage', [['non', 'Non'], ['exterieur', 'Extérieur uniquement (jardin, lavage voiture)'], ['interieur', 'Relié aux WC et au lave-linge']]],
  ['cuve_pose', 'Cuve : pose', [['horssol', 'Hors-sol'], ['enterree', 'Enterrée']]],
  ['cuve_litres', 'Cuve : capacité', [['1000', '1 000 L'], ['2000', '2 000 L'], ['3000', '3 000 L'], ['5000', '5 000 L'], ['10000', '10 000 L']]],
  ['piscine', 'Piscine enterrée', [['non', 'Non'], ['oui', 'Oui']]],
  ['portail_moto', 'Portail motorisé', [['non', 'Non'], ['oui', 'Oui']]],
  ['borne', 'Borne de recharge véhicule électrique', [['non', 'Non'], ['oui', 'Oui']]],
  ['alarme', 'Alarme intrusion', [['non', 'Non'], ['oui', 'Oui']]],
  ['visio', 'Visiophone ou interphone', [['non', 'Non'], ['oui', 'Oui']]]
];
const EQ_NUM = [
  ['nb_rad', 'Nombre de radiateurs'],
  ['nb_seche', 'Nombre de sèche-serviettes'],
  ['thermo_gaine', 'Chauffe-eau gainé : longueur de gaine d\'air (m)'],
  ['thermo_liaison', 'Chauffe-eau split : longueur de liaison frigorifique (m)'],
  ['poele_air', 'Poêle : longueur de gaine de prise d\'air extérieur (m)'],
  ['cuve_reseau', 'Cuve reliée aux WC et au lave-linge : longueur du réseau eau de pluie (m)'],
  ['cuve_tranchee', 'Cuve : distance cuve – maison, tranchée et raccordement PVC (m)'],
  ['nb_clim', 'Nombre de pièces climatisées (unités murales ou bouches)'],
  ['clim_gaine', 'Longueur de gaines de soufflage, système gainable (m)'],
  ['nb_portail', 'Nombre de portails'],
  ['nb_eclairage', 'Nombre de points d\'éclairage extérieur'],
  ['anc_epand', 'Assainissement : longueur de tranchées d\'épandage (m)']
];
// Valeurs des équipements, telles qu'elles servent aux conditions et aux quantités des ouvrages
function equipCtx(p) {
  const eq = p.equip || {}, o = { un: 1 };
  for (const [k] of EQ_SEL) o[k] = eq[k] || '';
  for (const [k] of EQ_NUM) o[k] = num(eq[k]);
  o.chauff_on = eq.chauffage && eq.chauffage !== 'aucun' ? 1 : 0;
  o.eau_chaude_on = eq.eau_chaude && eq.eau_chaude !== 'aucun' ? 1 : 0;
  o.anc_fosse = eq.anc === 'oui' ? 1 : 0;
  // Cuve de récupération : « oui » (ancien choix) = usage extérieur
  const cuveExt = eq.cuve === 'exterieur' || eq.cuve === 'oui', cuveInt = eq.cuve === 'interieur';
  o.cuve_on = cuveExt || cuveInt ? 1 : 0;
  o.cuve_ext_n = cuveExt ? 1 : 0;
  o.cuve_int_n = cuveInt ? 1 : 0;
  o.cuve_key = (cuveExt || cuveInt) && eq.cuve_pose && eq.cuve_litres ? eq.cuve_pose + '|' + eq.cuve_litres : '';
  o.cuve_reseau = cuveInt ? num(eq.cuve_reseau) : 0;
  // Terrassement : fouille = 1,8 × volume de la cuve (marge de travail), remblai = 0,8 × volume, déblais évacués = volume
  const litres = cuveExt || cuveInt ? num(eq.cuve_litres) : 0, m3 = litres / 1000;
  const enterree = (cuveExt || cuveInt) && eq.cuve_pose === 'enterree';
  o.cuve_fouille = enterree ? m3 * 1.8 : 0;
  o.cuve_remblai = enterree ? m3 * 0.8 : 0;
  o.cuve_evac = enterree ? m3 : 0;
  o.cuve_tranchee = cuveExt || cuveInt ? num(eq.cuve_tranchee) : 0;
  // Poêles : bois (conduit Poujoulat isolé) ou granulés (conduit simple ou concentrique) ; « oui » = ancien choix, traité comme bois
  const pb = eq.poele === 'bois' || eq.poele === 'oui', pg = eq.poele === 'granules';
  o.poele_bois_n = pb ? 1 : 0;
  o.poele_gran_n = pg ? 1 : 0;
  o.poele_n = pb || pg ? 1 : 0;
  o.conduit_bois_ml = pb ? num(eq.poeleHaut) : 0;
  o.conduit_gran_ml = pg ? num(eq.poeleHaut) : 0;
  o.poele_conduit = pg ? (eq.poele_conduit || '') : '';
  // Chauffe-eau thermodynamique : n'existe que si « thermodynamique » est choisi dans la production d'eau chaude
  const thermo = eq.eau_chaude === 'thermo';
  o.thermo_type = thermo ? (eq.thermo_type || '') : '';
  o.thermo_key = thermo && eq.thermo_type && eq.thermo_litres ? eq.thermo_type + '|' + eq.thermo_litres : '';
  // Unités extérieures : une par unité murale (split), une pour le gainable ; pas en plus d'une pompe à chaleur air/air
  // Nombre de groupes extérieurs = unités intérieures ÷ capacité du groupe (mono 1, bi 2, tri 3, quadri 4, multi 5)
  const capacite = { mono: 1, bi: 2, tri: 3, quadri: 4, multi: 5 }[eq.clim_grp];
  const sansPac = eq.chauffage !== 'pac-air';
  o.clim_ext = eq.clim === 'split' && capacite && sansPac ? Math.ceil(num(eq.nb_clim) / capacite) : 0;
  o.clim_gainable_ext = eq.clim === 'gainable' && sansPac ? 1 : 0;
  return o;
}
const FICHE_COUVERTINE = { alu: 'Aluminium', acier: 'Acier laqué 75/100e' };
const FICHE_ETANCH = { pvc: 'Membrane PVC blanche', gravillonnee: 'Étanchéité gravillonnée', bitume: 'Étanchéité bitume deux couches' };
const ETANCH_DESIG = {
  pvc: 'Membrane d\'étanchéité PVC blanche sur support OSB',
  gravillonnee: 'Étanchéité toiture-terrasse gravillonnée',
  bitume: 'Étanchéité toiture-terrasse bitume deux couches'
};
const FICHE_GOUT = { pvc: 'PVC', alu: 'Aluminium', zinc: 'Zinc demi-ronde' };
const FICHE_COUV = {
  'tuile-meca-tc': 'Tuiles mécaniques terre cuite', 'tuile-meca-beton': 'Tuiles mécaniques béton',
  'tuile-plate-tc': 'Tuiles plates terre cuite', 'ardoise': 'Ardoise naturelle ou fibrociment',
  'zinc': 'Zinc à joint debout', 'alu': 'Aluminium à joint debout',
  'bac-isole': 'Bac acier isolé (sandwich)', 'bac-non-isole': 'Bac acier non isolé'
};
// Anciens choix de la fiche (avant la liste élargie) : ramenés au nouveau nom
function couvDe(toit) {
  const v = toit.couverture || '';
  return { tuiles: 'tuile-meca-tc', bac: 'bac-non-isole' }[v] || v;
}
// Désignations de la bibliothèque utilisées pour générer les lignes
const MENU_DESIG = {
  'ouvrant': { 'PVC': 'Fenêtre PVC double vitrage (châssis)', 'alu': 'Fenêtre aluminium à rupture de pont thermique', 'bois': 'Fenêtre bois double vitrage' },
  'oscillo': { 'PVC': 'Fenêtre PVC double vitrage (châssis)', 'alu': 'Fenêtre aluminium à rupture de pont thermique', 'bois': 'Fenêtre bois double vitrage' },
  'coulissant': { 'PVC': 'Baie coulissante', 'alu': 'Baie coulissante', 'bois': 'Baie coulissante' },
  'porte': { 'PVC': "Porte d'entrée (bloc-porte extérieur)", 'alu': "Porte d'entrée (bloc-porte extérieur)", 'bois': "Porte d'entrée (bloc-porte extérieur)" },
  'porte-fenetre': { 'PVC': 'Porte-fenêtre PVC ou alu', 'alu': 'Porte-fenêtre PVC ou alu', 'bois': 'Porte-fenêtre PVC ou alu' }
};
const VOLET_DESIG = { 'battant-bois': 'Volet battant bois', 'battant-alu': 'Volet battant aluminium', 'roulant': 'Volet roulant électrique' };
const COUV_DESIG = {
  'tuile-meca-tc': 'Couverture en tuiles mécaniques à emboîtement (surface développée)',
  'tuile-meca-beton': 'Couverture en tuiles béton (surface développée)',
  'tuile-plate-tc': 'Couverture en tuiles plates (surface développée)',
  'ardoise': 'Couverture en ardoises naturelles ou fibrociment',
  'zinc': 'Couverture en zinc à joint debout (surface développée)',
  'alu': 'Couverture en aluminium à joint debout (surface développée)',
  'bac-isole': 'Couverture en bac acier isolé (panneau sandwich, surface développée)',
  'bac-non-isole': 'Couverture en bac acier à joint debout (surface développée)'
};
const ALIM_VOLET = 'Alimentation volet roulant électrique';
const FICHE_LOTS_MUR = ['gros-oeuvre', 'ossature-bois', 'isolation-thermique', 'doublages-cloisons-plafonds', 'revetements-muraux', 'peinture-finitions'];
const DES_FOND_FOUILLE = 'Fouilles en tranchée pour semelles filantes';
const DES_FOND_SEMELLE = 'Semelles filantes en béton armé';
const FICHE_FONDS_DEF = { largeur: '0.5', hauteur: '0.4', profondeur: '0.8' };

function projetDe(c) {
  if (!c.projet) c.projet = { epaisseur: 30, murs: [], ouvertures: [], toiture: { type: 'deux-pans', surface: 0, pente: 30, couverture: '' }, choix: { murs: '', tableaux: '', finition: '' }, fond: Object.assign({}, FICHE_FONDS_DEF) };
  if (!c.projet.fond) c.projet.fond = Object.assign({}, FICHE_FONDS_DEF);
  if (!c.projet.equip) c.projet.equip = {};
  if (!c.projet.cuisine) c.projet.cuisine = { bas: '', haut: '', plan: '', plan_ml: '' };
  if (!c.projet.chantier) c.projet.chantier = { eau: '', elec: '', base: '', grue: '', bennes: '', bennesTri: '' };
  if (c.projet.choix.finition === undefined) c.projet.choix.finition = '';
  if (!c.projet.soub) c.projet.soub = { hauteur: '0.60' };
  if (!c.projet.terrain) c.projet.terrain = { surface: '', perimetre: '' };
  if (!c.projet.plancher) c.projet.plancher = { type: 'hourdis', surface: '', ep: '4', retombee: '220', portee: '', entraxe: '0.60' };
  return c.projet;
}
// Calculs : murs moins ouvertures de plus de 2 m², tableaux (2 côtés × hauteur × épaisseur),
// toiture développée, fondations (murs porteurs × dimensions de la semelle et de la fouille)
function projetCalcul(p) {
  const e = num(p.epaisseur) / 100;
  const r = { murs: [], brut: 0, deduit: 0, net: 0, tableaux: 0, ouvs: [], toiture: 0, linP: 0, semelle: 0, fouille: 0 };
  for (const m of p.murs) {
    const brut = num(m.longueur) * num(m.hauteur);
    const ded = p.ouvertures.filter(o => o.mur === m.id).reduce((s, o) => { const a = num(o.largeur) * num(o.hauteur); return s + (a >= 2 ? a : 0); }, 0);
    r.murs.push({ m, brut, ded });
    r.brut += brut;
    if (m.porteur !== false) r.linP += num(m.longueur);
  }
  for (const o of p.ouvertures) {
    const aire = num(o.largeur) * num(o.hauteur);
    const tab = 2 * num(o.hauteur) * e;
    if (aire >= 2) r.deduit += aire;
    r.tableaux += tab;
    r.ouvs.push({ o, aire, tab, deduit: aire >= 2 });
  }
  r.net = Math.max(0, r.brut - r.deduit);
  const pente = p.toiture.type === 'plat' ? (num(p.toiture.pente) || 3.5) : num(p.toiture.pente);
  const S = num(p.toiture.surface);
  // Surface de couverture saisie (3D) : utilisée telle quelle ; sinon calcul à partir de la surface au sol et de la pente
  r.toiture = num(p.toiture.surfCouv) > 0 ? num(p.toiture.surfCouv) : (pente > 0 ? S / Math.cos(Math.atan(pente / 100)) : S);
  const f = p.fond || FICHE_FONDS_DEF;
  r.semelle = r.linP * num(f.largeur) * num(f.hauteur);
  r.fouille = r.linP * num(f.largeur) * num(f.profondeur);
  // Soubassement : murs porteurs × hauteur du soubassement
  r.soubS = r.linP * num((p.soub || {}).hauteur);
  // Plancher bas
  const pl = p.plancher || {};
  r.plS = num(pl.surface);
  r.hourdis = 0; r.dalleC = 0; r.solives = 0;
  if (pl.type === 'hourdis') { r.hourdis = r.plS; r.dalleC = r.plS * num(pl.ep) / 100; }
  if (pl.type === 'solivage' && r.plS > 0 && num(pl.portee) > 0) {
    // Solives parallèles à la portée : nombre = largeur / entraxe + 1, longueur = portée
    const largeurPerp = r.plS / num(pl.portee);
    const ent = num(pl.entraxe) || 0.6;
    r.nbSol = Math.ceil(largeurPerp / ent) + 1;
    r.solives = r.nbSol * num(pl.portee);
  }
  return r;
}
// Grandeurs calculées à partir du dessin (fiche projet et configurateur), utilisées par les ouvrages « qte »
function ctxQuantites(c) {
  const p = projetDe(c), r = projetCalcul(p), pieces = piecesDe(c);
  const surfPieces = pieces.reduce((a, x) => a + num(x.surf) * (num(x.nb) || 1), 0);
  return {
    surface_terrain: num(p.terrain.surface),
    perimetre_terrain: num(p.terrain.perimetre),
    surface_facades: r.brut,
    surface_plancher: r.plS > 0 ? r.plS : surfPieces,
    surface_pieces: surfPieces,
    surface_emprise: r.plS > 0 ? r.plS : surfPieces,
    surface_soubassement: r.soubS,
    surface_toiture: r.toiture,
    surface_toiture_plan: num(p.toiture.surface),
    ml_egout: num(p.toiture.egout),
    ml_rive: num(p.toiture.rive),
    // Menuiseries : appuis de fenêtre = largeur des fenêtres (ouvrant, oscillo, coulissant ; pas les portes)
    ml_appuis: p.ouvertures.filter(o => ['ouvrant','oscillo','coulissant'].includes(o.type)).reduce((a, o) => a + num(o.largeur), 0),
    appuis_fen: p.choix.appuis_fen || '',
    // Installation de chantier : clôture = périmètre moins 3 m de passage voiture
    cloture_ml: Math.max(0, num(p.terrain.perimetre) - 3),
    chan_eau: p.chantier.eau || '',
    chan_elec: p.chantier.elec || '',
    chan_base: p.chantier.base || '',
    chan_grue: p.chantier.grue || '',
    chan_benne: num(p.chantier.bennes),
    chan_benne_tri: num(p.chantier.bennesTri),
    ml_meubles_bas: num(p.cuisine.bas),
    ml_meubles_haut: num(p.cuisine.haut),
    ml_plan: num(p.cuisine.plan_ml),
    plan_cuisine: p.cuisine.plan || '',
    ml_faite: num(p.toiture.faite),
    ml_rive_egout: num(p.toiture.egout) + num(p.toiture.rive),
    ml_acrotere: num(p.toiture.acrotere),
    ...equipCtx(p),
    ml_arete: num(p.toiture.arete),
    cuve_points: (p.equip || {}).cuve === 'interieur' ? pointsEauPluie(c) : 0,
    nb_douille: (p.toiture.type !== 'plat' && /^tuile/.test(couvDe(p.toiture))) ? ventilationNb(p) : 0,
    nb_sortie125: (p.toiture.type !== 'plat' && /^tuile/.test(couvDe(p.toiture))) ? 0 : ventilationNb(p),
    ml_noue: num(p.toiture.noue),
    couverture: p.toiture.type === 'plat' ? '' : couvDe(p.toiture),
    // Gros œuvre : mêmes grandeurs que celles utilisées par la génération automatique du métré
    fond_fouille: r.fouille,
    fond_semelle: r.semelle,
    drain_ml: (p.murs || []).reduce((a, m) => a + num(m.longueur), 0),
    decap_m2: num(p.terrain.decap),
    res_eau_ml: num(p.terrain.resEau),
    res_eu_ml: num(p.terrain.resEu),
    res_ep_ml: num(p.terrain.resEp),
    res_elec_ml: num(p.terrain.resElec),
    res_tranchee_ml: num(p.terrain.resEau) + num(p.terrain.resEu) + num(p.terrain.resEp) + num(p.terrain.resElec),
    rig_ml: num(p.fond.rigLin),
    rig_m3: num(p.fond.rigLin) * num(p.fond.rigHt) * num(p.fond.rigLarg),
    soub_s: r.soubS,
    lin_porteur: r.linP,
    plan_hourdis: r.hourdis,
    plan_dalle: r.dalleC,
    elev_net: r.net,
    finit_net: r.net,
    murs_choix: p.choix.murs || '',
    finition_choix: p.choix.finition || '',
    // Pièces : mêmes totaux que la génération plâtrerie / sols / peinture / portes (clé « des:: » + désignation)
    ...((() => {
      const d = {};
      const ajD = (k, v) => { if (v > 0) d[k] = (d[k] || 0) + v; };
      for (const pc of pieces) {
        const nb = num(pc.nb) || 1, surf = num(pc.surf) * nb, eau = PLAT_EAU.test(pc.type);
        if (surf > 0) {
          ajD('des::' + (eau ? PLAT_PLAFOND_HYDRO : PLAT_PLAFOND), surf);
          ajD('des::Peinture plafond deux couches', surf);
          if (pc.sol) { ajD('des::' + pc.sol, surf); ajD('des::' + platPlinthe(pc.sol), platPlinthesMl(pc)); }
        }
        for (const x of pc.portes || []) {
          const t = x.type === PORTE_AUTO ? porteAuto(x.largeur) : x.type;
          ajD('des::' + t, num(x.nb) * nb);
          ajD('des::Peinture portes et huisseries', num(x.nb) * nb);
        }
      }
      return d;
    })()),
    nb_descentes: num(p.toiture.nbDesc),
    ml_descentes: num(p.toiture.nbDesc) * num(p.toiture.hautDesc),
    gouttiere: p.toiture.gouttiere || '',
    descente: p.toiture.descente || '',
    couvertine: p.toiture.couvertine || '',
    ecran: p.toiture.ecran || '',
    iso_toit: p.toiture.isoToit || '',
    charpente_variante: p.toiture.charpente === 'fermette' ? (p.toiture.type || 'deux-pans') + '|' + penteBande(p)
      : (p.toiture.charpente === 'traditionnelle' ? 'traditionnelle' : 'aucune'),
    toit_type: p.toiture.type || 'deux-pans',
    pente_bande: penteBande(p),
    linP: r.linP,
    linMurs: p.murs.reduce((a, m) => a + num(m.longueur), 0)
  };
}
// Points de soutirage d'eau de pluie : un par WC et un par machine à laver (pièces et leurs équipements)
function pointsEauPluiePiece(x) {
  const nb = num(x.nb) || 1;
  let n = x.type === 'Toilette' ? nb : 0;
  for (const e of x.equip || []) {
    const k = num(e.nb) || 1;
    if (x.type !== 'Toilette' && /^WC /.test(e.type)) n += k * nb;
    if (/machine à laver/.test(e.type)) n += k * nb;
  }
  return n;
}
function pointsEauPluie(c) { return piecesDe(c).reduce((a, x) => a + pointsEauPluiePiece(x), 0); }
// Sorties de toit de ventilation : primaire (obligatoire) + VMC + fosse (assainissement individuel)
function ventilationNb(p) {
  const eq = p.equip || {};
  return 1 + (eq.vmc === 'simple' || eq.vmc === 'double' ? 1 : 0) + (eq.anc === 'oui' ? 1 : 0);
}
// Bande de pente du toit, pour choisir la bonne variante de charpente (« <30 », « 30-45 », « >45 », « plat »)
function penteBande(p) {
  if (p.toiture.type === 'plat') return 'plat';
  const pente = num(p.toiture.pente);
  return pente < 30 ? '<30' : pente <= 45 ? '30-45' : '>45';
}
// Valeurs de saisie d'un ouvrage à partir de sa source de quantité (null si l'ouvrage n'en a pas)
function qteValeur(o, ctx) {
  if (!o || !o.qte || ctx[o.qte] === undefined) return null;
  // Variante : l'ouvrage ne vaut que si la condition de la fiche est remplie (si : égal, sin : différent)
  if (o.si && String(ctx[o.si.cle]) !== String(o.si.val)) return null;
  if (o.sin && String(ctx[o.sin.cle]) === String(o.sin.val)) return null;
  const v = ctx[o.qte];
  if (!(v > 0)) return null;
  if (o.unite === 'm²') return { nombre: '1', cote1: v.toFixed(2), cote2: '1' };
  if (o.unite === 'm³') return { nombre: '1', cote1: v.toFixed(3), cote2: '1', cote3: '1' };
  if (o.unite === 'ml') return { nombre: '1', cote1: v.toFixed(2) };
  return { nombre: String(Math.round(v)) };
}
// Recalcule les lignes dont la quantité vient de la configuration (sauf celles modifiées à la main)
function majQuantitesAuto(c) {
  if (!c) return;
  const ctx = ctxQuantites(c);
  const L = lignesDe(courantId);
  let change = false;
  for (const l of L) {
    if (!l.qteAuto) continue;
    const o = BIB.ouvrages.find(x => x.id === l.ouvrage);
    const valeurs = qteValeur(o, ctx);
    if (!valeurs) continue;
    l.valeurs = valeurs;
    l.quantite = calcul(o, valeurs);
    change = true;
  }
  if (change) sauverLignes(courantId, L);
}
function sauverFiche(c) { lsSet('chantiers', chantiers); marquerChantier(c.id); synchroConfig(); }
function ouvrirFiche() { ouvrirConfig(); }
function ouvrirConfig() {
  if (!courantId) { alert('Ouvrez d\'abord un chantier.'); return; }
  ficheRendre();
  ouvrirConfigurateur();
  route('config');
  synchroConfig();
}
if ($('vConfig')) {
  $('vConfig').addEventListener('change', ficheChange);
  $('vConfig').addEventListener('click', ficheClick);
}
function ficheListeMur() {
  return BIB.ouvrages.filter(o => !o.supprime && o.unite === 'm²' && FICHE_LOTS_MUR.includes(o.lot))
    .map(o => o.designation).filter((d, i, t) => t.indexOf(d) === i);
}
// Finitions de façade : enduits, bardages, peintures et lasures extérieurs
function ficheListeFinition() {
  return BIB.ouvrages.filter(o => !o.supprime && o.unite === 'm²' && /enduit (extérieur|de façade)|bardage|peinture (extérieure|de façade)|lasure/i.test(o.designation))
    .map(o => o.designation).filter((d, i, t) => t.indexOf(d) === i);
}
function ficheRendre() {
  const c = chantiers.find(x => x.id === courantId); if (!c) return;
  const p = projetDe(c);
  const sel = (opts, val) => opts.map(([v, t]) => `<option value="${esc(v)}" ${v === val ? 'selected' : ''}>${esc(t)}</option>`).join('');
  const optListe = (liste, val) => `<option value="" ${!val ? 'selected' : ''}>— choisir —</option>` + liste.map(d => `<option value="${esc(d)}" ${d === val ? 'selected' : ''}>${esc(d)}</option>`).join('');
  const carte = (titre, contenu) => `<section style="background:#fff;border:2px solid #6a1b9a;border-radius:10px;padding:12px;margin-bottom:12px"><h3 style="margin:0 0 8px;color:#6a1b9a;font-size:16px">${titre}</h3>${contenu}</section>`;
  const champ = (lib, html) => `<div style="min-width:0"><label style="display:block;margin:6px 0 4px;font-size:15px;color:var(--fg);font-weight:600">${lib}</label>${html}</div>`;
  const inp = (attrs, val, w) => `<input ${attrs} value="${esc(val ?? '')}" style="width:${w || '100%'};padding:10px;border:1px solid var(--mut);border-radius:8px;background:var(--card);color:var(--fg);font-size:16px">`;
  const sel2 = (attrs, opts, val) => `<select ${attrs} style="width:100%;padding:6px;border:1px solid #c9b8dc;border-radius:6px">${sel(opts, val)}</select>`;

  const murs = p.murs.map(m => `<div style="display:grid;grid-template-columns:2fr 1fr 1fr auto auto;gap:6px;align-items:end;margin-bottom:6px">
      ${champ('Nom', inp(`data-k="mur" data-id="${m.id}" data-champ="nom"`, m.nom))}
      ${champ('Longueur (m)', inp(`data-k="mur" data-id="${m.id}" data-champ="longueur" inputmode="decimal"`, m.longueur))}
      ${champ('Hauteur (m)', inp(`data-k="mur" data-id="${m.id}" data-champ="hauteur" inputmode="decimal"`, m.hauteur))}
      <label style="font-size:12px;padding-bottom:8px"><input type="checkbox" data-k="mur" data-id="${m.id}" data-champ="porteur" ${m.porteur !== false ? 'checked' : ''}> Porteur</label>
      <button type="button" class="btn small danger" data-action="delmur" data-id="${m.id}">✕</button></div>`).join('')
    || '<p style="color:#6b5a7a">Aucun mur. Ajoutez un mur par segment (une hauteur par segment si elle change).</p>';
  const ouvs = p.ouvertures.map(o => `<div style="border:1px dashed #c9b8dc;border-radius:8px;padding:8px;margin-bottom:8px">
      <div style="display:grid;grid-template-columns:2fr 1fr;gap:6px">
        ${champ('Nom', inp(`data-k="ouv" data-id="${o.id}" data-champ="nom"`, o.nom))}
        ${champ('Sur le mur', sel2(`data-k="ouv" data-id="${o.id}" data-champ="mur"`, p.murs.map(m => [m.id, m.nom]), o.mur))}
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr 1fr 1fr;gap:6px">
        ${champ('Type', sel2(`data-k="ouv" data-id="${o.id}" data-champ="type"`, Object.entries(FICHE_OUV), o.type))}
        ${champ('Largeur (m)', inp(`data-k="ouv" data-id="${o.id}" data-champ="largeur" inputmode="decimal"`, o.largeur))}
        ${champ('Hauteur (m)', inp(`data-k="ouv" data-id="${o.id}" data-champ="hauteur" inputmode="decimal"`, o.hauteur))}
        ${champ('Matériau', sel2(`data-k="ouv" data-id="${o.id}" data-champ="materiau"`, Object.entries(FICHE_MAT), o.materiau))}
      </div>
      <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:6px;align-items:end">
        ${champ('Volet', sel2(`data-k="ouv" data-id="${o.id}" data-champ="volet"`, Object.entries(FICHE_VOLET), o.volet))}
        ${o.volet === 'battant' ? champ('Matériau du volet', sel2(`data-k="ouv" data-id="${o.id}" data-champ="matvolet"`, [['bois', 'Bois'], ['alu', 'Aluminium']], o.matvolet)) : '<div></div>'}
        ${o.volet === 'roulant' ? `<label style="font-size:13px"><input type="checkbox" data-k="ouv" data-id="${o.id}" data-champ="electrique" ${o.electrique ? 'checked' : ''}> Électrique (motorisé)</label>` : '<div></div>'}
      </div>
      <div style="margin-top:6px;font-size:13px">
        <label><input type="checkbox" data-k="ouv" data-id="${o.id}" data-champ="securit" ${o.securit ? 'checked' : ''}> Verre sécurit</label>
        &nbsp;&nbsp;<label><input type="checkbox" data-k="ouv" data-id="${o.id}" data-champ="opaque" ${o.opaque ? 'checked' : ''}> Verre opaque</label>
        &nbsp;&nbsp;<button type="button" class="btn small danger" data-action="delouv" data-id="${o.id}">Supprimer</button>
      </div></div>`).join('')
    || '<p style="color:#6b5a7a">Aucune menuiserie. Ajoutez-les une à une.</p>';
  const toit = p.toiture;
  const plat = toit.type === 'plat';
  const choix = (attrs, entries, val) => sel2(attrs, [CHOIX_VIDE, ...entries], val || '');
  const contenuToit = `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
      ${champ('Type de toiture', sel2('data-k="toit" data-champ="type"', Object.entries(FICHE_TOIT), toit.type))}
      ${champ('Surface au sol couverte (m²)', inp('data-k="toit" data-champ="surface" inputmode="decimal"', toit.surface))}
      ${champ('Surface de couverture (m², pente comprise, prise dans la 3D) — facultatif', inp('data-k="toit" data-champ="surfCouv" inputmode="decimal" placeholder="calculée si vide"', toit.surfCouv || ''))}
      ${champ(plat ? 'Pente (%), minimum 3,5 %' : 'Pente (%)', inp('data-k="toit" data-champ="pente" inputmode="decimal"', plat && !toit.pente ? '3.5' : toit.pente))}
      ${plat ? champ('Étanchéité (partie courante)', choix('data-k="toit" data-champ="etancheite"', Object.entries(FICHE_ETANCH), toit.etancheite))
             : champ('Couverture', choix('data-k="toit" data-champ="couverture"', Object.entries(FICHE_COUV), couvDe(toit)))}
      ${plat ? champ('Relevés d\'acrotère, linéaire (m)', inp('data-k="toit" data-champ="acrotere" inputmode="decimal"', toit.acrotere)) : '<div></div>'}
      ${plat ? champ('Coiffe et couvertine d\'acrotère', choix('data-k="toit" data-champ="couvertine"', Object.entries(FICHE_COUVERTINE), toit.couvertine)) : '<div></div>'}
      ${champ('Longueur d\'égout, côtés gouttières (m)', inp('data-k="toit" data-champ="egout" inputmode="decimal"', toit.egout))}
      ${champ('Longueur de rives, pignons (m)', inp('data-k="toit" data-champ="rive" inputmode="decimal"', toit.rive))}
      ${champ('Longueur de faîtage (m)', inp('data-k="toit" data-champ="faite" inputmode="decimal"', toit.faite))}
      ${plat ? '<div></div>' : champ('Longueur d\'arêtiers (m)', inp('data-k="toit" data-champ="arete" inputmode="decimal"', toit.arete))}
      ${plat ? '<div></div>' : champ('Longueur de noues (m)', inp('data-k="toit" data-champ="noue" inputmode="decimal"', toit.noue))}
      ${champ('Matériau des gouttières', choix('data-k="toit" data-champ="gouttiere"', Object.entries(FICHE_GOUT), toit.gouttiere))}
      ${champ(plat ? 'Nombre d\'évacuations d\'eau pluviale (unité)' : 'Nombre de descentes d\'eau (unité)', inp('data-k="toit" data-champ="nbDesc" inputmode="decimal"', toit.nbDesc))}
      ${champ('Hauteur des descentes (m)', inp('data-k="toit" data-champ="hautDesc" inputmode="decimal"', toit.hautDesc))}
      ${champ('Matériau des descentes', choix('data-k="toit" data-champ="descente"', Object.entries(FICHE_DESC), toit.descente))}
      ${champ('Charpente', choix('data-k="toit" data-champ="charpente"', Object.entries(FICHE_CHARP), toit.charpente))}
      ${champ('Écran de sous-toiture', choix('data-k="toit" data-champ="ecran"', Object.entries(FICHE_ECRAN), toit.ecran))}
      ${champ('Isolation de toiture', choix('data-k="toit" data-champ="isoToit"', Object.entries(FICHE_ISO_TOIT), toit.isoToit))}
    </div>
    <div class="muted" style="font-size:12px;margin-top:6px">Un ouvrage n'est proposé dans le métré que lorsque son choix est fait ici. Les champs laissés « — à choisir — » ne créent rien.</div>`;
  const eq = p.equip || {};
  const lignesEq = EQ_SEL.map(([k, lib, opts]) => champ(lib, choix(`data-k="equip" data-champ="${k}"`, opts, eq[k]))).join('')
    + EQ_NUM.map(([k, lib]) => champ(lib, inp(`data-k="equip" data-champ="${k}" inputmode="decimal"`, eq[k]))).join('')
    + (eq.poele === 'bois' || eq.poele === 'granules' ? champ('Hauteur du conduit, du poêle à la sortie de toit (m)', inp('data-k="equip" data-champ="poeleHaut" inputmode="decimal"', eq.poeleHaut)) : '');
  const contenuEquip = `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">${lignesEq}</div>
    <div class="muted" style="font-size:12px;margin-top:6px">Un ouvrage n'est proposé que si son équipement est choisi ici. Un champ vide ne crée rien. La ventilation primaire est toujours prévue.</div>`;
  const fd = p.fond;
  const contenuFond = `<div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:6px">
      ${champ('Largeur de semelle (m)', inp('data-k="fond" data-champ="largeur" inputmode="decimal"', fd.largeur))}
      ${champ('Hauteur de semelle (m)', inp('data-k="fond" data-champ="hauteur" inputmode="decimal"', fd.hauteur))}
      ${champ('Profondeur de fouille (m)', inp('data-k="fond" data-champ="profondeur" inputmode="decimal"', fd.profondeur))}
    </div><p style="font-size:12px;color:#6b5a7a;margin:6px 0 0">Calcul sur les murs cochés « Porteur ».</p>
    <p style="font-size:13px;margin:10px 0 4px"><strong>Fouilles en rigoles (linéaire saisi à la main)</strong></p>
    <div style="display:grid;grid-template-columns:1fr 1fr 1fr;gap:6px">
      ${champ('Linéaire de rigoles (ml)', inp('data-k="fond" data-champ="rigLin" inputmode="decimal"', fd.rigLin || ''))}
      ${champ('HT, hauteur de fouille (m)', inp('data-k="fond" data-champ="rigHt" inputmode="decimal"', fd.rigHt || ''))}
      ${champ('Largeur de la rigole (m)', inp('data-k="fond" data-champ="rigLarg" inputmode="decimal"', fd.rigLarg || ''))}
    </div>`;
  const contenuPlancher = (() => {
    const pl = p.plancher;
    return `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
      ${champ('Type de plancher', sel2('data-k="plan" data-champ="type"', [['hourdis', 'Hourdis avec dalle de compression'], ['solivage', 'Solivage bois']], pl.type))}
      ${champ('Surface du plancher (m²)', inp('data-k="plan" data-champ="surface" inputmode="decimal"', pl.surface))}
      ${pl.type === 'hourdis' ? champ('Épaisseur de la dalle de compression (cm)', inp('data-k="plan" data-champ="ep" inputmode="decimal"', pl.ep)) : ''}
      ${pl.type === 'solivage' ? champ('Retombée des solives (mm)', sel2('data-k="plan" data-champ="retombee"', [['145', '145 mm'], ['175', '175 mm'], ['220', '220 mm']], pl.retombee)) : ''}
      ${pl.type === 'solivage' ? champ('Portée des solives (m)', inp('data-k="plan" data-champ="portee" inputmode="decimal"', pl.portee)) : ''}
      ${pl.type === 'solivage' ? champ('Entraxe des solives (m)', inp('data-k="plan" data-champ="entraxe" inputmode="decimal"', pl.entraxe)) : ''}
    </div><p style="font-size:12px;color:#6b5a7a;margin:6px 0 0">${pl.type === 'solivage'
      ? 'Solivage : OSB 9 mm en fond, isolant entre solives (épaisseur = retombée), OSB 21 mm support de revêtement de sol.'
      : 'Hourdis : plancher à poutrelles et hourdis, avec dalle de compression en béton.'}</p>`;
  })();
  const contenuSoub = `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
      ${champ('Hauteur du soubassement (m)', inp('data-k="soub" data-champ="hauteur" inputmode="decimal"', p.soub.hauteur))}
    </div><p style="font-size:12px;color:#6b5a7a;margin:6px 0 0">Calcul sur les murs porteurs : enduit hydrofuge, membrane Delta-MS et solin aluminium en tête.</p>`;
  $('cfgFiche').innerHTML = `<div>
    <h2 style="margin:0 0 8px;font-size:18px">Terrain, dimensions, structure et soubassement</h2>
    ${carte('0. Terrain', `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
      <div style="grid-column:1/-1;display:flex;gap:8px;align-items:flex-end;flex-wrap:wrap"><div style="flex:1;min-width:220px">${champ('Référence du dossier Kanban', inp('data-k="kref" placeholder="ex. 003-02-2026"', c.kanbanRef || '', '100%'))}</div><button type="button" class="btn sec" data-action="kanbanSurface" style="margin-bottom:2px">Reprendre la surface du Kanban</button></div>
      ${champ('Surface du terrain (m²)', inp('data-k="terr" data-champ="surface" inputmode="decimal"', p.terrain.surface))}
      ${champ('Périmètre du terrain (ml)', inp('data-k="terr" data-champ="perimetre" inputmode="decimal"', p.terrain.perimetre))}
      ${champ('Surface à décaper (m²)', inp('data-k="terr" data-champ="decap" inputmode="decimal"', p.terrain.decap || ''))}
      ${champ('Longueur eau potable (ml)', inp('data-k="terr" data-champ="resEau" inputmode="decimal"', p.terrain.resEau || ''))}
      ${champ('Longueur eaux usées (ml)', inp('data-k="terr" data-champ="resEu" inputmode="decimal"', p.terrain.resEu || ''))}
      ${champ('Longueur eaux pluviales (ml)', inp('data-k="terr" data-champ="resEp" inputmode="decimal"', p.terrain.resEp || ''))}
      ${champ('Longueur électricité (ml)', inp('data-k="terr" data-champ="resElec" inputmode="decimal"', p.terrain.resElec || ''))}
    </div><p style="font-size:12px;color:#6b5a7a;margin:6px 0 0">Sert à la clôture et aux protections du chantier.</p>`)}
    ${carte('0 bis. Installation de chantier (forfaits à ajouter ou non)', champ('Branchement provisoire d\'eau', `<select data-k="chant" data-champ="eau" style="width:100%;padding:6px">${['', 'oui', 'non'].map(v => `<option value="${v}" ${(p.chantier.eau || '') === v ? 'selected' : ''}>${{ '': '— à choisir —', oui: 'Oui', non: 'Non' }[v]}</option>`).join('')}</select>`)
      + champ('Branchement provisoire d\'électricité', `<select data-k="chant" data-champ="elec" style="width:100%;padding:6px">${['', 'oui', 'non'].map(v => `<option value="${v}" ${(p.chantier.elec || '') === v ? 'selected' : ''}>${{ '': '— à choisir —', oui: 'Oui', non: 'Non' }[v]}</option>`).join('')}</select>`)
      + champ('Base de vie (bungalow ou conteneur)', `<select data-k="chant" data-champ="base" style="width:100%;padding:6px">${['', 'oui', 'non'].map(v => `<option value="${v}" ${(p.chantier.base || '') === v ? 'selected' : ''}>${{ '': '— à choisir —', oui: 'Oui', non: 'Non' }[v]}</option>`).join('')}</select>`)
      + champ('Grue de chantier', `<select data-k="chant" data-champ="grue" style="width:100%;padding:6px">${['', 'oui', 'non'].map(v => `<option value="${v}" ${(p.chantier.grue || '') === v ? 'selected' : ''}>${{ '': '— à choisir —', oui: 'Oui', non: 'Non' }[v]}</option>`).join('')}</select>`)
      + champ('Nombre de bennes à gravats', inp('data-k="chant" data-champ="bennes" inputmode="numeric"', p.chantier.bennes, '120px'))
      + champ('Nombre de bennes à déchets triés', inp('data-k="chant" data-champ="bennesTri" inputmode="numeric"', p.chantier.bennesTri, '120px')))}
    ${carte('1. Épaisseur du mur (pour les tableaux)', champ('Épaisseur totale du mur (cm)', inp('data-k="epais" inputmode="decimal"', p.epaisseur, '160px')))}
    ${carte('2. Murs (longueur et hauteur)', murs + '<button type="button" class="btn sec" data-action="addmur" style="margin-top:6px">+ Ajouter un mur</button>')}
    ${carte('3. Menuiseries', ouvs + '<button type="button" class="btn sec" data-action="addouv">+ Ajouter une menuiserie</button>')}
    ${carte('4. Toiture', contenuToit)}
    ${carte('4 bis. Équipements de la maison (sorties de toit)', contenuEquip)}
    ${carte('5. Fondations', contenuFond)}
    ${carte('5 bis. Soubassement (mur au-dessus des fondations)', contenuSoub)}
    ${carte('5 ter. Plancher bas', contenuPlancher)}
    ${carte('6 bis. Cuisine (linéaires et plan de travail)', champ('Meubles bas (ml)', inp('data-k="cuis" data-champ="bas" inputmode="decimal"', p.cuisine.bas, '160px'))
      + champ('Meubles hauts (ml)', inp('data-k="cuis" data-champ="haut" inputmode="decimal"', p.cuisine.haut, '160px'))
      + champ('Plan de travail', `<select data-k="cuis" data-champ="plan" style="width:100%;padding:6px">${['', 'stratifie', 'quartz'].map(v => `<option value="${v}" ${(p.cuisine.plan || '') === v ? 'selected' : ''}>${{ '': '— à choisir —', stratifie: 'Stratifié', quartz: 'Quartz' }[v]}</option>`).join('')}</select>`)
      + champ('Longueur du plan de travail (ml)', inp('data-k="cuis" data-champ="plan_ml" inputmode="decimal"', p.cuisine.plan_ml, '160px')))}
    ${carte('6. Ouvrages à utiliser dans le métré', champ('Matériau des murs (élévation)', `<select data-k="choix" data-champ="murs" style="width:100%;padding:6px">${optListe(ficheListeMur(), p.choix.murs)}</select>`)
      + champ('Finition extérieure (enduit, bardage, peinture…)', `<select data-k="choix" data-champ="finition" style="width:100%;padding:6px">${optListe(ficheListeFinition(), p.choix.finition)}</select>`)
      + champ('Tableaux de menuiseries', `<select data-k="choix" data-champ="tableaux" style="width:100%;padding:6px">${optListe(ficheListeMur(), p.choix.tableaux)}</select>`)
      + champ('Appuis de fenêtre', `<select data-k="choix" data-champ="appuis_fen" style="width:100%;padding:6px">${['', 'beton', 'beton-pierre', 'alu', 'acier'].map(v => `<option value="${v}" ${(p.choix.appuis_fen || '') === v ? 'selected' : ''}>${{ '': '— à choisir —', beton: 'Béton', 'beton-pierre': 'Béton ton pierre', alu: 'Aluminium', acier: 'Acier laqué 75/100e' }[v]}</option>`).join('')}</select>`))}
    ${carte('Résultats des calculs', '<div id="ficheResume"></div>')}
</div>`;
  ficheResume();
}
function ficheResume() {
  const c = chantiers.find(x => x.id === courantId); if (!c || !$('ficheResume')) return;
  const p = projetDe(c), r = projetCalcul(p);
  const ligne = (a, b, gras) => `<tr><td style="padding:4px 0;${gras ? 'font-weight:700' : ''}">${a}</td><td style="text-align:right;padding:4px 0;${gras ? 'font-weight:700;color:#6a1b9a' : ''}">${b}</td></tr>`;
  $('ficheResume').innerHTML = `<table style="width:100%;border-collapse:collapse">
    ${ligne('Murs (longueur × hauteur)', fmt(r.brut) + ' m²')}
    ${ligne('Ouvertures de plus de 2 m² déduites', '− ' + fmt(r.deduit) + ' m²')}
    ${ligne('Élévation nette des murs (finition)', fmt(r.net) + ' m²', true)}
    ${ligne('Tableaux de menuiseries (2 côtés × hauteur × épaisseur)', fmt(r.tableaux) + ' m²', true)}
    ${ligne('Toiture (surface développée)', fmt(r.toiture) + ' m²', true)}
    ${ligne('Linéaire des murs porteurs', fmt(r.linP) + ' ml')}
    ${ligne('Fouilles en tranchée', fmt(r.fouille) + ' m³', true)}
    ${ligne('Semelles filantes béton', fmt(r.semelle) + ' m³', true)}
    ${ligne('Soubassement : surface des murs porteurs', fmt(r.soubS) + ' m²', true)}
    ${p.plancher.type === 'hourdis' ? ligne('Plancher hourdis', fmt(r.hourdis) + ' m²', true) + ligne('Dalle de compression', fmt(r.dalleC) + ' m³', true) : ''}
    ${p.plancher.type === 'solivage' ? ligne('Solives bois', fmt(r.solives) + ' ml', true) + ligne('Isolant entre solives et OSB 9 mm de fond', fmt(r.plS) + ' m²', true) + ligne('OSB 21 mm support de revêtement de sol', fmt(r.plS) + ' m²', true) : ''}
  </table>
  ${r.ouvs.length ? `<p style="font-size:12px;color:#6b5a7a;margin:8px 0 0">${r.ouvs.map(x => `${esc(x.o.nom)} : ${fmt(x.aire)} m² · tableau ${fmt(x.tab)} m²${x.deduit ? ' · déduite des murs' : ''}`).join('<br>')}</p>` : ''}`;
}
function ficheChange(e) {
  const t = e.target, k = t.dataset.k; if (!k) return;
  const c = chantiers.find(x => x.id === courantId); if (!c) return;
  const p = projetDe(c);
  const val = t.type === 'checkbox' ? t.checked : t.value;
  const champ = t.dataset.champ;
  if (k === 'epais') p.epaisseur = val;
  else if (k === 'mur') { const m = p.murs.find(x => x.id === t.dataset.id); if (m) m[champ] = val; }
  else if (k === 'ouv') { const o = p.ouvertures.find(x => x.id === t.dataset.id); if (o) o[champ] = val; }
  else if (k === 'toit') p.toiture[champ] = val;
  else if (k === 'fond') p.fond[champ] = val;
  else if (k === 'soub') p.soub[champ] = val;
  else if (k === 'terr') p.terrain[champ] = val;
  else if (k === 'plan') p.plancher[champ] = val;
  else if (k === 'choix') p.choix[champ] = val;
  else if (k === 'equip') { p.equip = p.equip || {}; p.equip[champ] = val; }
  else if (k === 'cuis') p.cuisine[champ] = val;
  else if (k === 'chant') p.chantier[champ] = val;
  else if (k === 'kref') { c.kanbanRef = String(val).trim(); }
  sauverFiche(c);
  const refaire = (k === 'equip' && champ === 'poele') || (k === 'ouv' && ['volet', 'type'].includes(champ)) || (k === 'toit' && champ === 'type') || (k === 'plan' && champ === 'type');
  if (refaire) ficheRendre(); else ficheResume();
}
// Lecture seule du Kanban : même adresse que le Kanban utilise pour lire ses dossiers
const KANBAN_LECTURE = 'https://script.google.com/macros/s/AKfycbwLGYVnT9HvYgLJNzEP1QCa8b-BQw18eZ0vse2hXixZT4LwrFv3-bt4X4i--gX8eqDoKw/exec';
function kanbanSurface(c) {
  const msg = t => { if ($('cfgStatut')) $('cfgStatut').textContent = t; };
  const ref = (c.kanbanRef || '').trim();
  if (!ref) { msg('Saisissez d\'abord la référence du dossier Kanban (ex. 003-02-2026).'); return; }
  msg('Lecture du Kanban…');
  fetch(KANBAN_LECTURE).then(r => r.json()).then(db => {
    const card = [...(db.cards || []), ...(db.archived || [])].find(x => x.ref === ref);
    if (!card) { msg('Aucun dossier Kanban avec la référence ' + ref + '.'); return; }
    let m2 = card.faisa && card.faisa.surface ? Math.round(card.faisa.surface) : NaN;
    if (!(m2 > 0)) m2 = parseFloat(String(card.contenance || '').replace(/\s/g, '').replace(',', '.').replace(/[^\d.]/g, ''));
    if (!(m2 > 0)) { msg('Le dossier ' + ref + ' n\'a pas de contenance enregistrée dans le Kanban.'); return; }
    projetDe(c).terrain.surface = String(m2);
    sauverFiche(c);
    ficheRendre();
    setTimeout(() => msg('Surface du terrain reprise du Kanban (dossier ' + ref + ') : ' + m2 + ' m².'), 500);
  }).catch(() => msg('Kanban injoignable pour le moment. Réessayez plus tard.'));
}
function ficheClick(e) {
  const b = e.target.closest('[data-action]'); if (!b) return;
  const c = chantiers.find(x => x.id === courantId); if (!c) return;
  const p = projetDe(c), a = b.dataset.action;
  if (a === 'kanbanSurface') { kanbanSurface(c); return; }
  if (a === 'addmur') p.murs.push({ id: 'm' + uid(), nom: 'Mur ' + (p.murs.length + 1), longueur: '', hauteur: '', porteur: true });
  else if (a === 'delmur') p.murs = p.murs.filter(m => m.id !== b.dataset.id);
  else if (a === 'addouv') p.ouvertures.push({ id: 'o' + uid(), nom: 'Menuiserie ' + (p.ouvertures.length + 1), mur: p.murs[0] ? p.murs[0].id : '', type: 'ouvrant', largeur: '', hauteur: '', materiau: 'PVC', volet: 'aucun', matvolet: 'alu', electrique: false, securit: false, opaque: false });
  else if (a === 'delouv') p.ouvertures = p.ouvertures.filter(o => o.id !== b.dataset.id);
  sauverFiche(c);
  ficheRendre();
}
// Ajoute au métré les lignes calculées (les lignes précédentes de la fiche sont remplacées)
function ficheVersMetre() {
  const c = chantiers.find(x => x.id === courantId); if (!c) return;
  const p = projetDe(c), r = projetCalcul(p);
  const L = lignesDe(courantId).filter(l => !l.projet);
  const manquants = []; let nb = 0;
  // Quantité selon l'unité de l'ouvrage (m², m³, ml ou unité)
  const valeursPour = (unite, q) => {
    if (unite === 'm²') return { nombre: '1', cote1: q.toFixed(2), cote2: '1' };
    if (unite === 'm³') return { nombre: '1', cote1: q.toFixed(3), cote2: '1', cote3: '1' };
    if (unite === 'ml') return { nombre: '1', cote1: q.toFixed(2) };
    return { nombre: String(q) };
  };
  const ajouter = (des, q, designation) => {
    if (!des) { if (q > 0) manquants.push('(choix non fait)'); return; }
    const o = BIB.ouvrages.find(x => !x.supprime && x.designation === des);
    if (!o) { manquants.push(des); return; }
    if (!(q > 0)) return;
    const valeurs = valeursPour(o.unite, q);
    ajouterLotSiAbsent(courantId, o.lot);
    L.push({ uid: uid(), lot: o.lot, ouvrage: o.id, designation: designation || o.designation, unite: o.unite,
             valeurs, quantite: calcul(o, valeurs), surface: null, prix: 'moyen', projet: true, cree: new Date().toISOString() });
    nb++;
  };
  // Fondations
  ajouter(DES_FOND_FOUILLE, r.fouille, 'Fouilles en tranchée pour semelles filantes (murs porteurs)');
  ajouter(DES_FOND_SEMELLE, r.semelle, 'Semelles filantes en béton armé (murs porteurs)');
  // Soubassement : enduit hydrofuge, membrane Delta-MS et solin aluminium en tête
  ajouter('Enduit hydrofuge sur mur de soubassement (face extérieure)', r.soubS, 'Enduit hydrofuge sur mur de soubassement');
  ajouter('Membrane de protection et drainage Delta-MS sur mur de soubassement', r.soubS, 'Membrane Delta-MS sur mur de soubassement');
  ajouter('Solin en aluminium fixé en tête de mur de soubassement', r.linP, 'Solin aluminium fixé en tête de soubassement');
  // Plancher bas
  if (p.plancher.type === 'hourdis' && r.plS > 0) {
    ajouter('Plancher à poutrelles et hourdis béton d\'étage', r.hourdis, 'Plancher à hourdis avec dalle de compression');
    ajouter('Dalle de compression béton armé (sur hourdis)', r.dalleC, 'Dalle de compression ' + num(p.plancher.ep) + ' cm');
  }
  if (p.plancher.type === 'solivage' && r.plS > 0 && r.solives > 0) {
    const ret = p.plancher.retombee;
    const solive = { '145': 'Solives bois 145×45 (plancher)', '175': 'Solives 175×45 (plancher, ossature)', '220': 'Solives bois 220×45 (plancher)' }[ret];
    ajouter(solive, r.solives, 'Solives bois ' + ret + ' mm, entraxe ' + num(p.plancher.entraxe) + ' m');
    ajouter('Isolation entre solives de plancher', r.plS, 'Isolation entre solives, épaisseur ' + ret + ' mm');
    ajouter('Panneau OSB 9 mm en sous-face de solivage (fond de plancher)', r.plS, 'OSB 9 mm en fond de plancher');
    ajouter('Support de parquet : OSB 21 mm', r.plS, 'OSB 21 mm support de revêtement de sol');
  }
  // Élévation, finition, tableaux, toiture
  ajouter(p.choix.murs, r.net, 'Élévation des murs (ouvertures de plus de 2 m² déduites)');
  ajouter(p.choix.finition, r.net, 'Finition des murs (surface nette)');
  ajouter(p.choix.tableaux, r.tableaux, 'Tableaux de menuiseries (2 côtés)');
  if (p.toiture.type === 'plat') { if (p.toiture.etancheite) ajouter(ETANCH_DESIG[p.toiture.etancheite], r.toiture, 'Étanchéité de la partie courante du toit plat'); }
  else if (couvDe(p.toiture)) ajouter(COUV_DESIG[couvDe(p.toiture)], r.toiture);
  for (const o of p.ouvertures) {
    const dims = `${fmt(num(o.largeur))} × ${fmt(num(o.hauteur))} m`;
    const opts = [o.securit ? 'verre sécurit' : '', o.opaque ? 'verre opaque' : ''].filter(Boolean).join(', ');
    const ouv = MENU_DESIG[o.type] && MENU_DESIG[o.type][o.materiau];
    ajouter(ouv, 1, `${o.nom} – ${FICHE_OUV[o.type]} ${FICHE_MAT[o.materiau]} ${dims}${opts ? ' – ' + opts : ''}`);
    if (o.volet === 'battant') ajouter(VOLET_DESIG['battant-' + (o.matvolet || 'alu')], 1, `Volet battant ${o.matvolet === 'bois' ? 'bois' : 'aluminium'} – ${o.nom}`);
    if (o.volet === 'roulant') {
      ajouter(VOLET_DESIG.roulant, 1, `Volet roulant – ${o.nom}`);
      if (o.electrique) ajouter(ALIM_VOLET, 1, `Alimentation volet roulant – ${o.nom}`);
    }
  }
  sauverLignes(courantId, L);
  renderMetre();
  let msg = nb + ' ligne(s) ajoutée(s) au métré.';
  if (manquants.length) msg += ' À compléter : ' + manquants.filter((d, i, t) => t.indexOf(d) === i).join(' ; ');
  return msg;
}

/* ============ Fenêtre de saisie (ouvrage du catalogue) ============ */
function fermer() { $('modal').classList.remove('open'); }
function ouvrirModal() { $('modal').classList.add('open'); }

function ouvrirOuvrage(o, precedent, message) {
  const champs = champsDe(o);
  const cc = chantiers.find(x => x.id === courantId);
  const auto = !precedent && cc ? qteValeur(o, ctxQuantites(cc)) : null;
  const v = precedent || auto || {};   // pas de quantité par défaut : un manque doit se voir dans le métré
  let h = `<h2 style="margin:0 0 4px;font-size:18px">${esc(o.designation)}</h2>`
    + (auto ? `<div class="ok" style="margin-top:8px">Quantité proposée depuis le configurateur (${esc(o.qte.replace(/_/g, ' '))}). Modifiez-la si besoin : la ligne ne sera plus recalculée.</div>` : '');
  h += `
    <div class="muted">${esc(libLot(o.lot))} · unité : ${esc(o.unite)}</div>`;
  if (o.rappel) h += `<div class="card" style="margin:10px 0 0;background:#fdf4ee;border-color:#E07838"><strong style="font-size:13px">Rappel de mesure</strong><div style="margin-top:4px;white-space:pre-line">${esc(o.rappel)}</div></div>`;
  if (message) h += `<div class="ok" style="margin-top:10px">${esc(message)}</div>`;
  h += `<form id="fOuv">`;
  for (const ch of champs) {
    h += `<label for="c_${ch.cle}">${esc(ch.libelle)}</label>
      <input id="c_${ch.cle}" name="${ch.cle}" ${ch.texte ? '' : 'inputmode="decimal"'} value="${esc(v[ch.cle] ?? '')}">`;
  }
  h += `<div class="calc" id="apercu"></div>
    <div class="row" style="margin-top:8px">
      <button type="button" class="btn sec" id="bAnnuler">Fermer</button>
      <button type="submit" class="btn">Valider la ligne</button>
    </div>
    <p class="muted" style="margin-top:14px"><a href="#" id="bLibre">Ouvrage libre (enrichit la bibliothèque)</a></p>
  </form>`;
  $('sheet').innerHTML = h;
  const f = $('fOuv');
  const maj = () => {
    const q = calcul(o, lireForm(f, champs));
    let t = `Quantité : ${fmt(q)} ${o.unite}`;
    const vv = lireForm(f, champs);
    if (o.saisie === 'menuiseries' && num(vv.largeur_cm) && num(vv.hauteur_cm))
      t += ` · surface ${fmt(num(vv.nombre || 1) * num(vv.largeur_cm) * num(vv.hauteur_cm) / 10000)} m²`;
    $('apercu').textContent = t;
  };
  f.addEventListener('input', maj);
  maj();
  f.addEventListener('submit', e => {
    e.preventDefault();
    const vals = lireForm(f, champs);
    const manque = champs.filter(ch => !ch.texte && String(vals[ch.cle] ?? '').trim() === '');
    if (manque.length) { $('apercu').textContent = 'Quantité à saisir : ' + manque.map(ch => ch.libelle).join(', ') + '.'; return; }
    const q = calcul(o, vals);
    if (!(q > 0)) { $('apercu').textContent = 'Quantité nulle : vérifiez les cotes.'; return; }
    const surface = (o.saisie === 'menuiseries' && num(vals.largeur_cm) && num(vals.hauteur_cm))
      ? num(vals.nombre || 1) * num(vals.largeur_cm) * num(vals.hauteur_cm) / 10000 : null;
    ajouterLotSiAbsent(courantId, o.lot);
    const L = lignesDe(courantId);
    // Ligne liée à la configuration seulement si la quantité proposée n'a pas été modifiée
    const proposee = !precedent && cc ? qteValeur(o, ctxQuantites(cc)) : null;
    const memeValeur = proposee && Object.keys(proposee).every(k => vals[k] === undefined || num(proposee[k]) === num(vals[k]));
    L.push({ uid: uid(), lot: o.lot, ouvrage: o.id, designation: o.designation, unite: o.unite,
             valeurs: vals, quantite: q, surface, cree: new Date().toISOString(), qteAuto: memeValeur ? o.qte : undefined });
    sauverLignes(courantId, L);
    renderMetre();
    // La fenêtre se ferme après la validation (un clic de moins)
    fermer();
  });
}

/* ============ Ouvrage libre ============ */
function champsLibre(unite) {
  const u = { 'm²': ['cote1', 'cote2'], 'm³': ['cote1', 'cote2', 'cote3'], 'ml': ['cote1'] }[unite] || [];
  return [{ cle: 'nombre', libelle: 'Nombre' }, ...u.map((c, i) => ({ cle: c, libelle: `Cote ${i + 1} (m)` }))];
}

function ouvrirLibre() {
  const lots = BIB.lots.map(l => `<option value="${esc(l.id)}" ${l.id === lotCourant ? 'selected' : ''}>${esc(l.nom)}</option>`).join('');
  $('sheet').innerHTML = `<h2 style="margin:0 0 4px;font-size:18px">Ouvrage libre</h2>
    <p class="muted">Il entre dans le métré tout de suite et est proposé à la bibliothèque. Il ne deviendra officiel qu'après votre validation.</p>
    <form id="fLibre">
      <label for="l_des">Désignation</label><input id="l_des" name="designation" required>
      <label for="l_lot">Lot</label><select id="l_lot" name="lot">${lots}</select>
      <label for="l_unite">Unité</label><select id="l_unite" name="unite">${UNITES.map(u => `<option>${u}</option>`).join('')}</select>
      <div id="l_champs"></div>
      <div class="calc" id="apercuL"></div>
      <div class="row" style="margin-top:8px">
        <button type="button" class="btn sec" id="bAnnulerL">Annuler</button>
        <button type="submit" class="btn">Ajouter au métré</button>
      </div>
    </form>`;
  const f = $('fLibre');
  const dessinerChamps = () => {
    const unite = f.elements.unite.value;
    const champs = champsLibre(unite);
    $('l_champs').innerHTML = champs.map(c => `<label for="l_${c.cle}">${esc(c.libelle)}</label>
      <input id="l_${c.cle}" name="${c.cle}" inputmode="decimal" value="${c.cle === 'nombre' ? '1' : ''}">`).join('');
    majLibre();
  };
  const majLibre = () => {
    const unite = f.elements.unite.value;
    const v = {};
    for (const c of champsLibre(unite)) v[c.cle] = f.elements[c.cle].value.trim().replace(',', '.');
    $('apercuL').textContent = `Quantité : ${fmt(calcul({ unite }, v))} ${unite}`;
  };
  f.elements.unite.addEventListener('change', dessinerChamps);
  f.addEventListener('input', majLibre);
  dessinerChamps();
  f.addEventListener('submit', e => {
    e.preventDefault();
    const unite = f.elements.unite.value;
    const champs = champsLibre(unite);
    const v = {};
    for (const c of champs) v[c.cle] = f.elements[c.cle].value.trim().replace(',', '.');
    const q = calcul({ unite }, v);
    if (!(q > 0)) { $('apercuL').textContent = 'Quantité nulle : vérifiez les cotes.'; return; }
    const lot = f.elements.lot.value;
    const designation = f.elements.designation.value.trim();
    const ouvrage = { id: 'LIBRE-' + uid(), lot, designation, unite, type: 'commun', saisie: 'metre', champs: champs.map(c => ({ cle: c.cle, libelle: c.libelle })), propose_le: new Date().toISOString() };
    ajouterLotSiAbsent(courantId, lot);
    const L = lignesDe(courantId);
    L.push({ uid: uid(), lot, ouvrage: ouvrage.id, designation, unite, valeurs: v, quantite: q, surface: null, libre: true, cree: new Date().toISOString() });
    sauverLignes(courantId, L);
    const file = lsGet('file_libres', []);
    file.push({ ouvrage, envoye: false });
    lsSet('file_libres', file);
    renderMetre();
    fermer();
    envoyerPropositions();
  });
}

/* ============ Chantiers ============ */
function ouvrirChantier(id) {
  courantId = id;
  lsSet('courant', id);
  const c = chantiers.find(x => x.id === id);
  $('titre').textContent = c ? (PAGE === 'tableau' ? 'Métré du chantier · ' : '') + c.nom : 'Métré';
  remplirLots();
  route(PAGE === 'tableau' ? 'tableau' : 'metre');
  renderOuvrages();
  renderMetre();
}

/* ============ Synchronisation des chantiers (Drive) ============ */
// Par chantier, on garde : maj (version connue sur Drive) et modifie (modifications pas encore envoyées)
function syncLire() { return lsGet('sync', {}); }
function syncEcrire(x) { lsSet('sync', x); }
function syncStatut(texte) { const e = $('syncStatut'); if (e) e.textContent = texte; }
function syncConfigOk() { return !!(lsGet('url', '') && lsGet('jeton', '')); }

// Appelé après chaque modification d'un chantier ou de ses lignes : envoi rapide
function marquerChantier(id) {
  const x = syncLire();
  x[id] = Object.assign({}, x[id], { modifie: true });
  syncEcrire(x);
  clearTimeout(marquerChantier.t);
  marquerChantier.t = setTimeout(envoyerChantiers, 3000);
}

async function envoyerChantiers() {
  if (!syncConfigOk()) return;
  const x = syncLire();
  for (const c of chantiers) if (!x[c.id]) x[c.id] = { modifie: true };   // anciens chantiers : envoyés une fois
  let envoyes = 0;
  for (const id of Object.keys(x)) {
    if (!x[id].modifie) continue;
    const c = chantiers.find(y => y.id === id);
    if (!c) { delete x[id]; continue; }
    const doc = Object.assign({}, c, { lignes: lignesDe(id) });
    try {
      const j = await post({ action: 'sauver_chantier', chantier: doc, base_maj: x[id].maj || null });
      if (j.ok) { x[id] = { maj: j.maj, modifie: false }; envoyes++; }
      else if (j.conflit) { x[id].conflit = true; syncStatut('Conflit sur « ' + c.nom + ' » : modifié ailleurs. Cliquez sur Synchroniser pour récupérer cette version.'); }
    } catch (e) { syncEcrire(x); syncStatut('Pas de réseau : les modifications seront envoyées plus tard.'); return; }
  }
  syncEcrire(x);
  if (envoyes) syncStatut('Envoyé vers Drive à ' + new Date().toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' }));
}

// Récupère les chantiers modifiés sur un autre appareil (sans écraser les modifications non envoyées)
async function recupererChantiers() {
  if (!syncConfigOk()) return;
  const liste = await post({ action: 'lister_chantiers' });
  if (!liste.ok) { syncStatut('Refus du script : ' + (liste.erreur || 'erreur inconnue')); return; }
  const x = syncLire();
  let recus = 0;
  for (const item of liste.chantiers) {
    const id = item.id;
    if (x[id] && x[id].modifie) continue;
    const j = await post({ action: 'lire_chantier', id });
    const doc = j.ok ? j.chantier : null;
    if (!doc || (x[id] && x[id].maj === doc.maj)) continue;
    const { lignes, ...meta } = doc;
    const i = chantiers.findIndex(c => c.id === id);
    if (i >= 0) chantiers[i] = meta; else chantiers.push(meta);
    lsSet('lignes.' + id, doc.supprime ? [] : (lignes || []));
    x[id] = { maj: doc.maj, modifie: false };
    recus++;
  }
  lsSet('chantiers', chantiers);
  syncEcrire(x);
  if (recus) renderChantiers();
  syncStatut(recus ? recus + ' chantier(s) reçu(s) de Drive' : 'Chantiers à jour');
}

async function synchroniserChantiers() {
  if (!syncConfigOk()) { syncStatut('Renseignez l\'adresse du script et le jeton dans Réglages.'); return; }
  try { await envoyerChantiers(); await recupererChantiers(); }
  catch (e) { syncStatut('Synchronisation impossible pour le moment (réseau).'); }
}

// Bouton « Synchroniser les chantiers » sur la liste des chantiers
function preparerSynchro() {
  if ($('btnSynchro') || !$('listeChantiers')) return;
  $('listeChantiers').insertAdjacentHTML('beforebegin', `<div class="row" style="margin-bottom:12px;align-items:center">
    <button class="btn sec small" id="btnSynchro" style="flex:0 0 auto">Synchroniser les chantiers</button>
    <span class="muted" id="syncStatut"></span></div>`);
  $('btnSynchro').onclick = synchroniserChantiers;
}

/* ============ Événements ============ */
$('btnChantiers').onclick = () => { route('chantiers'); renderChantiers(); };
$('btnReglages').onclick = () => {
  $('urlScript').value = lsGet('url', '');
  $('jeton').value = lsGet('jeton', '');
  if ($('chkPrix')) $('chkPrix').checked = prixAffiches();
  $('titre').textContent = 'Réglages';
  route('reglages');
};

$('btnNouveau').onclick = () => {
  const nom = $('nomChantier').value.trim();
  if (!nom) { alert('Donnez un nom au chantier.'); return; }
  const idx = $('selClient') ? $('selClient').value : '';
  const client = idx !== '' && CLIENTS[idx] ? pickClient(CLIENTS[idx]) : null;
  const c = { id: 'c' + uid(), nom, client };
  chantiers.push(c);
  lsSet('chantiers', chantiers);
  marquerChantier(c.id);
  $('nomChantier').value = '';
  ouvrirChantier(c.id);
};

$('listeChantiers').addEventListener('click', e => {
  const b = e.target.closest('[data-ouvrir]');
  if (b) { ouvrirChantier(b.dataset.ouvrir); return; }
  const d = e.target.closest('[data-dupliquer]');
  if (d) { dupliquerChantier(d.dataset.dupliquer); return; }
  const a = e.target.closest('[data-archiver]');
  if (a) { archiverChantier(a.dataset.archiver, true); return; }
  const r = e.target.closest('[data-restaurer]');
  if (r) { archiverChantier(r.dataset.restaurer, false); return; }
  const x = e.target.closest('[data-supprimer]');
  if (x) supprimerChantier(x.dataset.supprimer);
});

$('ongletSaisie').onclick = () => route('metre');
$('ongletTableau').onclick = ouvrirTableau;
$('ongletSaisie2').onclick = () => window.open('index.html', 'metre2m-saisie');
$('ongletTableau2').onclick = () => route('tableau');

$('selLot').onchange = e => { lotCourant = e.target.value; renderOuvrages(); };
$('recherche').oninput = renderOuvrages;

$('listeOuvrages').addEventListener('click', e => {
  if (e.target.closest('#bLibre2')) { ouvrirModal(); ouvrirLibre(); return; }
  const li = e.target.closest('[data-ouv]');
  if (!li) return;
  const o = BIB.ouvrages.find(x => x.id === li.dataset.ouv);
  if (o) { ouvrirModal(); ouvrirOuvrage(o); }
});

$('tableMetre').addEventListener('click', e => {
  const b = e.target.closest('[data-sup]');
  if (!b) return;
  if (!confirm('Supprimer cette ligne du métré ?')) return;
  sauverLignes(courantId, lignesDe(courantId).filter(l => l.uid !== b.dataset.sup));
  renderMetre();
});

// Case « Généralités dans le métré » de chaque lot
$('tableMetre').addEventListener('change', e => {
  const g = e.target.closest('[data-gen]');
  if (g) basculerGen(courantId, g.dataset.gen, g.checked);
});

// Choix du prix (moyen, bas, haut, unique) pour une ligne du métré
$('tableMetre').addEventListener('change', e => {
  const s = e.target.closest('[data-choix-prix], [data-choix-devis]');
  if (!s) return;
  const uid = s.dataset.choixPrix || s.dataset.choixDevis;
  sauverLignes(courantId, lignesDe(courantId).map(l => {
    if (l.uid !== uid) return l;
    return s.dataset.choixPrix ? Object.assign({}, l, { prix: s.value }) : Object.assign({}, l, { devisNum: parseInt(s.value, 10) });
  }));
  renderMetre();
});

$('modal').addEventListener('click', e => {
  if (e.target.id === 'modal' || e.target.id === 'bAnnuler' || e.target.id === 'bAnnulerL' || e.target.id === 'bBibAnnuler') { fermer(); return; }
  if (e.target.id === 'bLibre') { e.preventDefault(); ouvrirLibre(); }
});

/* ============ Clients (fiches du Kanban, lecture seule) ============ */
let CLIENTS = [];
const pickClient = x => ({
  ref: x.ref || '', nom: x.nom || '', tel: x.tel || '', mail: x.mail || '',
  addr: x.addr || '', cadr: x.cadr || '', nat: x.nat || '',
  surf: x.surf || '', resume: x.resume || ''
});
function remplirSelectClients() {
  const sel = $('selClient');
  if (!sel) return;
  CLIENTS = lsGet('clients', []).slice().sort((a, b) => String(a.nom || '').localeCompare(String(b.nom || ''), 'fr'));
  sel.innerHTML = '<option value="">— Saisie libre —</option>' + CLIENTS.map((c, i) =>
    `<option value="${i}">${esc((c.ref ? c.ref + ' – ' : '') + (c.nom || 'Sans nom'))}</option>`).join('');
}
async function actualiserClients(silencieux) {
  if (!lsGet('url', '') || !lsGet('jeton', '')) {
    if (!silencieux) alert("Renseignez d'abord l'adresse du script et le jeton dans Réglages.");
    return;
  }
  try {
    const j = await post({ action: 'importer_clients' });
    if (j.ok) { lsSet('clients', j.clients); remplirSelectClients(); }
    else if (!silencieux) alert('Refus : ' + (j.erreur || 'erreur inconnue'));
  } catch (e) {
    if (!silencieux) alert('Import impossible pour le moment (réseau).');
  }
}
function preparerClients() {
  const carte = $('nomChantier').closest('.card');
  if (!$('selClient')) {
    carte.insertAdjacentHTML('afterbegin', `<label for="selClient">Client (fiche du Kanban)</label>
      <div class="row"><select id="selClient"></select>
      <button class="btn small sec" id="btnClients" style="flex:0 0 auto">Actualiser</button></div>`);
  }
  $('selClient').onchange = e => {
    const c = CLIENTS[e.target.value];
    if (c) $('nomChantier').value = c.nom || '';
  };
  $('btnClients').onclick = () => actualiserClients(false);
  remplirSelectClients();
  actualiserClients(true);
}

// Lien depuis la fiche client du Kanban : ouvre (ou crée) le chantier de ce client
async function ouvrirDepuisClient(ref) {
  if (!lsGet('clients', []).length) await actualiserClients(true);
  remplirSelectClients();
  const cl = lsGet('clients', []).find(x => String(x.ref) === String(ref));
  if (!cl) { alert('Client introuvable dans le Kanban : ' + ref); return; }
  let c = chantiers.find(x => x.client && String(x.client.ref) === String(ref));
  if (!c) {
    c = { id: 'c' + uid(), nom: cl.nom || ('Chantier ' + ref), client: pickClient(cl) };
    chantiers.push(c);
    lsSet('chantiers', chantiers);
    marquerChantier(c.id);
  }
  ouvrirChantier(c.id);
}

/* ============ Documents : page de garde + métré (Excel et PDF) ============ */
const ATELIER = {
  nom: 'Atelier 2M',
  sous: "Dessin d'architecture",
  adresse: '29 Avenue Thiers, 19100 Brive-la-Gaillarde',
  tel: '06 59 98 68 81',
  mail: 'contact@atelier2m.com',
  web: 'www.atelier2m.com',
};
const pad2 = n => String(n).padStart(2, '0');

function donneesDocument() {
  const c = chantiers.find(x => x.id === courantId) || { nom: 'Métré' };
  const L = lignesDe(courantId);
  const nums = numeroLignes(courantId);
  const avecPrix = prixAffiches();
  let total = 0;
  const lots = lotsDuChantier(courantId).map((lotId, i) => ({
    id: lotId,
    ordre: i + 1,
    num: pad2(i + 1),
    nom: libLot(lotId),
    gen: genActif(courantId, lotId) ? { id: lotId, num: i + 1 } : null,
    lignes: L.filter(l => l.lot === lotId).map(l => {
      const pu = avecPrix ? prixUnitaire(l) : null;
      const montant = pu != null ? l.quantite * pu : null;
      if (montant != null) total += montant;
      return { num: nums[l.uid], designation: l.designation, unite: l.unite,
               quantite: l.quantite, detail: detail(l), detailHtml: detailHtml(l), pu, montant };
    })
  }));
  return { titre: c.nom, client: c.client || null, date: new Date().toLocaleDateString('fr-FR'), lots,
           avecPrix, total };
}

function htmlImpression(d, logo, pg) {
  const cl = d.client || {};
  const ligne = (label, val) => val ? `<tr><th class="k">${esc(label)}</th><td>${esc(val)}</td></tr>` : '';
  const surf = cl.surf ? `${cl.surf} m²` : '';
  let corps = '';
  const nc = d.avecPrix ? 7 : 5;
  for (const lot of d.lots) {
    corps += `<tr class="lot"><td colspan="${nc}">${esc(lot.num)} · ${esc(lot.nom)}${lot.lignes.length ? '' : ' <span class="vide">(aucune ligne)</span>'}</td></tr>`;
    if (lot.gen) corps += `<tr class="gen"><td colspan="${nc}">${genHtml(lot.gen.id, lot.gen.num)}</td></tr>`;
    for (const l of lot.lignes) {
      corps += `<tr><td class="n">${esc(l.num)}</td><td>${esc(l.designation)}</td><td>${esc(l.unite)}</td>
        <td class="num">${fmt(l.quantite)}</td><td class="det">${l.detailHtml}</td>
        ${d.avecPrix ? `<td class="num">${l.pu != null ? fmt(l.pu) : '—'}</td><td class="num">${l.montant != null ? fmt(l.montant) + ' €' : '—'}</td>` : ''}</tr>`;
    }
  }
  const pied = d.avecPrix
    ? `<tfoot><tr class="tot"><td colspan="${nc - 1}">Total indicatif HT (prix moyens de référence, à valider)</td><td class="num">${fmt(d.total)} €</td></tr></tfoot>`
    : '';
  const marque = logo
    ? `<img class="logo" src="${esc(logo)}" alt="Atelier 2M">`
    : `<div class="marque">${esc(ATELIER.nom)}</div>`;
  return `<!doctype html><html lang="fr"><head><meta charset="utf-8">
<title>Métré – ${esc(d.titre)}</title>
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;600;700&display=swap" rel="stylesheet">
<style>
  @page { size: A4; margin: 14mm 14mm 16mm; }
  * { box-sizing: border-box; }
  body { font-family: Montserrat, Arial, sans-serif; color: #2b2b2b; font-size: 9.5pt; margin: 0; }
  .garde { min-height: 265mm; display: flex; flex-direction: column; page-break-after: always; }
  .entete { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 3px solid #E07838; padding-bottom: 5mm; }
  .logo { height: 20mm; display: block; }
  .marque { color: #E07838; font-weight: 700; font-size: 18pt; }
  .sous { color: #8a8a8a; font-size: 9pt; margin-top: 1mm; }
  .contact { text-align: right; color: #6b6b6b; font-size: 8.5pt; line-height: 1.5; }
  .titre { margin: 26mm 0 10mm; }
  .pg { text-align: center; margin: 0 0 8mm; }
  .pg img { width: auto; max-width: 100%; object-fit: contain; }
  .titre small { color: #E07838; font-weight: 600; letter-spacing: .12em; text-transform: uppercase; font-size: 9pt; }
  .titre h1 { font-size: 24pt; margin: 2mm 0 0; font-weight: 700; }
  .bloc { border-left: 4px solid #E07838; background: #fdf4ee; padding: 5mm 6mm; margin-bottom: 6mm; }
  .bloc h2 { font-size: 9.5pt; margin: 0 0 3mm; color: #E07838; text-transform: uppercase; letter-spacing: .08em; }
  .bloc table { width: 100%; border-collapse: collapse; }
  .bloc th.k { width: 36mm; text-align: left; color: #6b6b6b; font-weight: 600; padding: 1.5mm 0; vertical-align: top; }
  .bloc td { padding: 1.5mm 0; vertical-align: top; }
  .pied { margin-top: auto; border-top: 1px solid #ddd; padding-top: 4mm; color: #6b6b6b; font-size: 8.5pt; }
  table.metre { width: 100%; border-collapse: collapse; }
  table.metre thead { display: table-header-group; }
  table.metre th { background: #E07838; color: #fff; text-align: left; padding: 2mm; font-size: 8.5pt; }
  table.metre td { padding: 1.6mm 2mm; border-bottom: 1px solid #e3e3e3; vertical-align: top; }
  table.metre td.n { font-weight: 700; color: #E07838; white-space: nowrap; }
  table.metre td.num { text-align: right; font-variant-numeric: tabular-nums; font-weight: 600; white-space: nowrap; }
  table.metre td.det { color: #6b6b6b; font-size: 8.5pt; }
  table.metre tr.lot td { background: #f4f4f4; font-weight: 700; border-bottom: 1px solid #E07838; padding-top: 3mm; }
  table.metre tr { page-break-inside: avoid; }
  table.metre tr.gen { page-break-inside: auto; }
  table.metre tr.gen td { background: #fbfbfb; border-bottom: none; padding: 2mm 2mm 3mm; font-size: 8.5pt; }
  .gen-titre { color: #E07838; font-weight: 700; font-size: 9pt; margin-bottom: 1.5mm; }
  .gen-sec { margin: 0 0 2mm; }
  .gen-s { color: #2b2b2b; margin-bottom: 0.5mm; }
  .gen-sec ul { margin: 0; padding-left: 5mm; color: #4a4a4a; }
  .gen-sec li { margin: 0 0 0.5mm; }
  .vide { font-weight: 400; color: #8a8a8a; }
  h2.entete-metre { font-size: 13pt; color: #2b2b2b; margin: 0 0 4mm; }
  table.metre tr.tot td { font-weight: 700; border-top: 2px solid #E07838; border-bottom: none; padding-top: 3mm; }
</style></head><body>
<section class="garde">
  <div class="entete">
    <div>${marque}<div class="sous">${esc(ATELIER.sous)}</div></div>
    <div class="contact">${esc(ATELIER.adresse)}<br>${esc(ATELIER.tel)} · ${esc(ATELIER.mail)}<br>${esc(ATELIER.web)}</div>
  </div>
  <div class="titre"><small>Métré estimatif</small><h1>${esc(d.titre)}</h1></div>
  ${pg ? `<div class="pg"><img src="${pg.src}" alt="Projet 3D" style="height:${(265 * pg.pct / 100).toFixed(1)}mm"></div>` : ''}
  <div class="bloc"><h2>Client</h2><table>
    ${ligne('Nom', cl.nom)}${ligne('Référence', cl.ref)}${ligne('Téléphone', cl.tel)}${ligne('Courriel', cl.mail)}
    ${ligne('Adresse du client', cl.addr)}${ligne('Adresse du chantier', cl.cadr)}${ligne('Nature du projet', cl.nat)}
    ${ligne('Surface', surf)}${ligne('Résumé', cl.resume)}
  </table></div>
  <div class="pied">Métré établi le ${esc(d.date)} · ${esc(ATELIER.nom)} · ${esc(ATELIER.mail)}</div>
</section>
<section>
  <h2 class="entete-metre">Détail du métré</h2>
  <table class="metre">
    <thead><tr><th>N°</th><th>Désignation</th><th>Unité</th><th>Quantité</th><th>Détail</th>${d.avecPrix ? '<th>P.U. HT ind.</th><th>Montant HT ind.</th>' : ''}</tr></thead>
    <tbody>${corps}</tbody>${pied}
  </table>
</section>
<script>window.addEventListener('load', function () { setTimeout(function () { window.print(); }, 400); });</script>
</body></html>`;
}

// Documents « par lot » : une page de garde par lot (avec son titre), puis le détail du lot.
// type = 'feuille' : quantités et lignes seules.
// type = 'cdpgf'   : mêmes lignes, avec les généralités du lot et des cases de prix vides pour l'entreprise.
function htmlParLot(d, type, logo) {
  const cl = d.client || {};
  const cdpgf = type === 'cdpgf';
  const titreDoc = cdpgf ? 'CDPGF' : 'Feuille de métré';
  const ligne = (label, val) => val ? `<tr><th class="k">${esc(label)}</th><td>${esc(val)}</td></tr>` : '';
  const marque = logo
    ? `<img class="logo" src="${esc(logo)}" alt="Atelier 2M">`
    : `<div class="marque">${esc(ATELIER.nom)}</div>`;
  const entete = `<div class="entete">
    <div>${marque}<div class="sous">${esc(ATELIER.sous)}</div></div>
    <div class="contact">${esc(ATELIER.adresse)}<br>${esc(ATELIER.tel)} · ${esc(ATELIER.mail)}<br>${esc(ATELIER.web)}</div>
  </div>`;
  const infos = ligne('Nom', cl.nom) + ligne('Référence', cl.ref) + ligne('Adresse du chantier', cl.cadr) + ligne('Nature du projet', cl.nat);
  // Date limite de réponse (CDPGF) : si elle n'est pas renseignée, une ligne est laissée à compléter à la main
  const dl = (chantiers.find(x => x.id === courantId) || {}).dateLimite;
  const dateLim = cdpgf
    ? `<p class="limite">Réponse attendue avant le : <strong>${dl ? esc(new Date(dl + 'T12:00').toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' })) : '………………………………………'}</strong></p>`
    : '';
  const lots = d.lots.filter(lot => lot.lignes.length);
  let corps = '';
  lots.forEach((lot, k) => {
    const dernier = k === lots.length - 1;
    // Page de garde du lot
    corps += `<section class="garde saut">${entete}
      <div class="titre"><small>${esc(titreDoc)} · ${esc(d.titre)}</small><h1>Lot ${esc(lot.num)} · ${esc(lot.nom)}</h1></div>
      ${dateLim}
      <div class="bloc"><h2>Projet</h2><table>${infos}</table></div>
      <div class="pied">${esc(titreDoc)} établi le ${esc(d.date)} · ${esc(ATELIER.nom)} · ${esc(ATELIER.mail)}</div>
    </section>`;
    // Détail du lot (généralités en tête pour le CDPGF)
    const gen = cdpgf ? genHtml(lot.id, lot.ordre) : '';
    const lignes = lot.lignes.map(l => `<tr>
        <td class="n">${esc(l.num)}</td><td>${esc(l.designation)}</td><td>${esc(l.unite)}</td>
        <td class="num">${fmt(l.quantite)}</td><td class="det">${l.detailHtml}</td>
        ${cdpgf ? '<td class="vierge"></td><td class="vierge"></td><td class="vierge petit"></td>' : ''}</tr>`).join('');
    // Totaux : Total HT, puis trois lignes de TVA (un taux par ligne, car un projet peut mélanger plusieurs taux), puis Total TTC
    const lignesTva = [1, 2, 3].map(n => `<tr class="tva"><td colspan="7">TVA ${n} : taux ……… %  ·  montant de la TVA</td><td class="vierge"></td></tr>`).join('');
    const pied = cdpgf
      ? '<tfoot><tr class="tot"><td colspan="7">Total HT du lot</td><td class="vierge"></td></tr>'
        + lignesTva
        + '<tr class="tot"><td colspan="7">Total TTC du lot</td><td class="vierge"></td></tr></tfoot>'
      : '';
    const mention = cdpgf
      ? '<p class="mention">Prix unitaires et montants à indiquer HT. La TVA et le total TTC sont à compléter par l\'entreprise, selon le taux qui lui est applicable pour ces travaux.</p>'
      : '';
    corps += `<section class="contenu${dernier ? '' : ' saut'}">
      <div class="rappel">${esc(d.titre)} · ${esc(titreDoc)} · Lot ${esc(lot.num)}</div>
      <h2 class="entete-metre">Lot ${esc(lot.num)} · ${esc(lot.nom)}</h2>
      ${gen}
      <table class="metre">
        <thead><tr><th>N°</th><th>Désignation</th><th>Unité</th><th>Quantité</th><th>Détail</th>${cdpgf ? '<th>P.U. HT</th><th>Montant HT</th><th>TVA %</th>' : ''}</tr></thead>
        <tbody>${lignes}</tbody>${pied}
      </table>
      ${mention}
    </section>`;
  });
  if (!lots.length) corps = '<section class="garde"><p>Aucune ligne dans ce métré.</p></section>';
  return `<!doctype html><html lang="fr"><head><meta charset="utf-8">
<title>${esc(titreDoc)} – ${esc(d.titre)}</title>
<link href="https://fonts.googleapis.com/css2?family=Montserrat:wght@400;600;700&display=swap" rel="stylesheet">
<style>
  @page { size: A4; margin: 14mm 14mm 16mm; }
  * { box-sizing: border-box; }
  body { font-family: Montserrat, Arial, sans-serif; color: #2b2b2b; font-size: 9.5pt; margin: 0; }
  .saut { page-break-after: always; }
  .garde { min-height: 265mm; display: flex; flex-direction: column; }
  .entete { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 3px solid #E07838; padding-bottom: 5mm; }
  .logo { height: 20mm; display: block; }
  .marque { color: #E07838; font-weight: 700; font-size: 18pt; }
  .sous { color: #8a8a8a; font-size: 9pt; margin-top: 1mm; }
  .contact { text-align: right; color: #6b6b6b; font-size: 8.5pt; line-height: 1.5; }
  .titre { margin: 40mm 0 12mm; }
  .titre small { color: #E07838; font-weight: 600; letter-spacing: .12em; text-transform: uppercase; font-size: 9pt; }
  .titre h1 { font-size: 26pt; margin: 2mm 0 0; font-weight: 700; }
  .bloc { border-left: 4px solid #E07838; background: #fdf4ee; padding: 5mm 6mm; margin-bottom: 6mm; }
  .bloc h2 { font-size: 9.5pt; margin: 0 0 3mm; color: #E07838; text-transform: uppercase; letter-spacing: .08em; }
  .bloc table { width: 100%; border-collapse: collapse; }
  .bloc th.k { width: 40mm; text-align: left; color: #6b6b6b; font-weight: 600; padding: 1.5mm 0; vertical-align: top; }
  .bloc td { padding: 1.5mm 0; vertical-align: top; }
  .pied { margin-top: auto; border-top: 1px solid #ddd; padding-top: 4mm; color: #6b6b6b; font-size: 8.5pt; }
  .rappel { color: #8a8a8a; font-size: 8pt; margin-bottom: 3mm; }
  h2.entete-metre { font-size: 13pt; color: #2b2b2b; margin: 0 0 4mm; }
  .gen-bloc { background: #fbfbfb; border-left: 3px solid #E07838; padding: 3mm 4mm; margin: 0 0 5mm; }
  .gen-titre { color: #E07838; font-weight: 700; font-size: 9pt; margin-bottom: 1.5mm; }
  .gen-sec { margin: 0 0 2mm; }
  .gen-s { margin-bottom: 0.5mm; }
  .gen-sec ul { margin: 0; padding-left: 5mm; color: #4a4a4a; font-size: 8.5pt; }
  .gen-sec li { margin: 0 0 0.5mm; }
  table.metre { width: 100%; border-collapse: collapse; }
  table.metre thead { display: table-header-group; }
  table.metre th { background: #E07838; color: #fff; text-align: left; padding: 2mm; font-size: 8.5pt; }
  table.metre td { padding: 1.6mm 2mm; border-bottom: 1px solid #e3e3e3; vertical-align: top; }
  table.metre td.n { font-weight: 700; color: #E07838; white-space: nowrap; }
  table.metre td.num { text-align: right; font-variant-numeric: tabular-nums; font-weight: 600; white-space: nowrap; }
  table.metre td.det { color: #6b6b6b; font-size: 8.5pt; }
  table.metre td.vierge { height: 8mm; min-width: 22mm; }
  table.metre tr { page-break-inside: avoid; }
  table.metre tr.tot td { font-weight: 700; border-top: 2px solid #E07838; border-bottom: none; padding-top: 3mm; }
  table.metre tr.tva td { font-weight: 600; border-bottom: none; }
  table.metre tr.tot + tr.tva td { border-top: none; }
  table.metre td.petit { min-width: 14mm; }
  .mention { margin: 4mm 0 0; color: #6b6b6b; font-size: 8pt; font-style: italic; }
  .limite { margin: -6mm 0 8mm; font-size: 11pt; color: #2b2b2b; }
  .limite strong { color: #E07838; }
</style></head><body>
${corps}
<script>window.addEventListener('load', function () { setTimeout(function () { window.print(); }, 400); });</script>
</body></html>`;
}

async function imprimerPdf(type) {
  // type : 'global' (métré complet, comme avant), 'feuille' ou 'cdpgf' (une page par lot)
  const mode = type === 'feuille' || type === 'cdpgf' ? type : 'global';
  // La fenêtre est ouverte tout de suite (sinon le navigateur la bloque), puis remplie.
  const w = window.open('', 'metre2m-impression');
  if (!w) { alert("La fenêtre d'impression est bloquée. Autorisez les fenêtres pour ce site, puis réessayez."); return; }
  w.document.write('<p style="font-family:sans-serif;padding:20px">Préparation du document…</p>');
  const logo = new URL('logo.png', location.href).href;
  let avecLogo = false;
  try { avecLogo = (await fetch(logo, { method: 'HEAD', cache: 'no-cache' })).ok; } catch (e) {}
  let html;
  if (mode === 'global') {
    const pg = await imagePG();
    html = htmlImpression(donneesDocument(), avecLogo ? logo : '', pg);
  } else {
    html = htmlParLot(donneesDocument(), mode, avecLogo ? logo : '');
  }
  w.document.open();
  w.document.write(html);
  w.document.close();
}

// Taille de l'image de la page de garde, en % de la hauteur de la page (réglage, 20 % par défaut)
function tailleImagePG() {
  const n = parseInt(lsGet('pg_pct', 20), 10);
  return isFinite(n) ? Math.min(40, Math.max(10, n)) : 20;
}

// Cherche « IMAGE PG » dans le dossier Drive du client du chantier (Kanban)
async function imagePG() {
  const c = chantiers.find(x => x.id === courantId);
  const cl = c && c.client;
  if (!cl || !cl.ref || !cl.nom || !syncConfigOk()) return null;
  try {
    const j = await post({ action: 'image_pg', ref: cl.ref, nom: cl.nom });
    if (j.ok && j.image && j.image.base64) {
      return { src: `data:${j.image.mime};base64,${j.image.base64}`, pct: tailleImagePG() };
    }
    alert("Image « IMAGE PG » introuvable dans le dossier du client sur Drive. Le métré est imprimé sans image.");
  } catch (e) {
    alert("Impossible de récupérer l'image « IMAGE PG » (réseau). Le métré est imprimé sans image.");
  }
  return null;
}

// Réglage de la taille de l'image de page de garde, dans Réglages
function preparerTaillePG() {
  if ($('pgPct') || !$('chkPrix')) return;
  $('chkPrix').closest('.card').insertAdjacentHTML('afterend', `<div class="card">
    <label for="pgPct">Taille de l'image « IMAGE PG » sur la page de garde (% de la page)</label>
    <input id="pgPct" type="number" min="10" max="40" step="1" value="${tailleImagePG()}">
    <p class="muted" style="margin:6px 0 0">Environ 20 % par défaut (un cinquième de la page). Entre 10 et 40.</p></div>`);
  $('pgPct').onchange = e => lsSet('pg_pct', Math.min(40, Math.max(10, parseInt(e.target.value, 10) || 20)));
}

function chargerXlsx() {
  return new Promise((ok, ko) => {
    if (window.XLSX) return ok(window.XLSX);
    const s = document.createElement('script');
    s.src = 'https://cdn.jsdelivr.net/npm/xlsx-js-style@1.2.0/dist/xlsx.bundle.js';
    s.onload = () => ok(window.XLSX);
    s.onerror = () => ko(new Error('chargement impossible'));
    document.head.appendChild(s);
  });
}

async function exporterExcel() {
  let XL;
  try { XL = await chargerXlsx(); }
  catch (e) { alert('Export Excel indisponible : vérifiez la connexion internet.'); return; }
  const d = donneesDocument();
  const cl = d.client || {};
  const orange = { rgb: ORANGE };
  const blanc = { rgb: 'FFFFFF' };
  const wb = XL.utils.book_new();

  // Feuille 1 : page de garde
  const g = [
    [ATELIER.nom], [ATELIER.sous], [ATELIER.adresse], [ATELIER.tel + ' · ' + ATELIER.mail + ' · ' + ATELIER.web], [],
    ['MÉTRÉ ESTIMATIF'], [d.titre], [],
    ['CLIENT'], ['Nom', cl.nom || ''], ['Référence', cl.ref || ''], ['Téléphone', cl.tel || ''], ['Courriel', cl.mail || ''],
    ['Adresse du client', cl.addr || ''], ['Adresse du chantier', cl.cadr || ''], ['Nature du projet', cl.nat || ''],
    ['Surface', cl.surf ? cl.surf + ' m²' : ''], ['Résumé', cl.resume || ''], [],
    ['Métré établi le', d.date],
    ['Prix', d.avecPrix ? 'Prix indicatifs HT (à titre de référence)' : 'Document sans prix']
  ];
  const ws1 = XL.utils.aoa_to_sheet(g);
  ws1['!cols'] = [{ wch: 22 }, { wch: 70 }];
  const style = (ws, addr, s) => { if (!ws[addr]) ws[addr] = { t: 's', v: '' }; ws[addr].s = s; };
  style(ws1, 'A1', { font: { bold: true, sz: 18, color: orange } });
  style(ws1, 'A2', { font: { italic: true, color: { rgb: '8A8A8A' } } });
  style(ws1, 'A6', { font: { bold: true, sz: 11, color: orange } });
  style(ws1, 'A7', { font: { bold: true, sz: 16 } });
  style(ws1, 'A9', { font: { bold: true, color: orange } });
  for (let r = 10; r <= 17; r++) style(ws1, 'A' + r, { font: { bold: true, color: { rgb: '6B6B6B' } } });

  // Feuille 2 : métré détaillé (colonnes de prix seulement si le réglage est activé)
  const avecPrix = d.avecPrix;
  const nc = avecPrix ? 7 : 5;
  const lettres = ['A', 'B', 'C', 'D', 'E', 'F', 'G'].slice(0, nc);
  const m = [['N°', 'Désignation', 'Unité', 'Quantité', 'Détail', ...(avecPrix ? ['P.U. HT ind.', 'Montant HT ind.'] : [])]];
  const lignesLot = [], lignesLigne = [];
  for (const lot of d.lots) {
    lignesLot.push(m.length);
    m.push([lot.num + ' · ' + lot.nom, '', '', '', lot.lignes.length ? '' : '(aucune ligne)', ...(avecPrix ? [''] : []), ...(avecPrix ? [''] : [])].slice(0, nc));
    for (const l of lot.lignes) {
      lignesLigne.push(m.length);
      m.push([l.num, l.designation, l.unite, l.quantite, l.detail, ...(avecPrix ? [l.pu ?? '', l.montant ?? ''] : [])]);
    }
  }
  let ligneTotal = null;
  if (avecPrix) {
    ligneTotal = m.length;
    m.push(['', 'TOTAL INDICATIF HT (prix moyens de référence, à valider)', '', '', '', '', d.total]);
  }
  const ws2 = XL.utils.aoa_to_sheet(m);
  ws2['!cols'] = [{ wch: 9 }, { wch: 60 }, { wch: 10 }, { wch: 12 }, { wch: 48 }, ...(avecPrix ? [{ wch: 14 }, { wch: 16 }] : [])];
  ws2['!merges'] = lignesLot.map(r => ({ s: { r, c: 0 }, e: { r, c: nc - 1 } }));
  for (const c of lettres) style(ws2, c + '1', { font: { bold: true, color: blanc }, fill: { fgColor: orange } });
  for (const r of lignesLot) {
    style(ws2, 'A' + (r + 1), { font: { bold: true }, fill: { fgColor: { rgb: 'F4F4F4' } } });
    for (const c of lettres.slice(1)) style(ws2, c + (r + 1), { fill: { fgColor: { rgb: 'F4F4F4' } }, font: { bold: true } });
  }
  for (const r of lignesLigne) {
    style(ws2, 'A' + (r + 1), { font: { bold: true, color: orange } });
    ws2['D' + (r + 1)].z = '#,##0.00';
    ws2['D' + (r + 1)].s = { font: { bold: true }, alignment: { horizontal: 'right' } };
    style(ws2, 'E' + (r + 1), { font: { color: { rgb: '6B6B6B' }, sz: 9 } });
    if (avecPrix) for (const c of ['F', 'G']) if (ws2[c + (r + 1)] && typeof ws2[c + (r + 1)].v === 'number') {
      ws2[c + (r + 1)].z = '#,##0.00';
      ws2[c + (r + 1)].s = { alignment: { horizontal: 'right' } };
    }
  }
  if (ligneTotal !== null) {
    style(ws2, 'B' + (ligneTotal + 1), { font: { bold: true } });
    style(ws2, 'G' + (ligneTotal + 1), { font: { bold: true }, alignment: { horizontal: 'right' } });
    ws2['G' + (ligneTotal + 1)].z = '#,##0.00';
  }

  XL.utils.book_append_sheet(wb, ws1, 'Page de garde');
  XL.utils.book_append_sheet(wb, ws2, 'Métré');
  const nom = (d.titre || 'metre').replace(/[^\w\-]+/g, '_');
  XL.writeFile(wb, `Metre_${nom}.xlsx`);
}

$('btnCsv').textContent = 'Excel';
$('btnCsv').onclick = exporterExcel;
$('btnCsv').insertAdjacentHTML('afterend', ' <button class="btn small" id="btnPdf">PDF / Imprimer</button>');
$('btnPdf').onclick = imprimerPdf;
// Bouton « Afficher les prix » : même réglage que dans Réglages
$('btnPdf').insertAdjacentHTML('afterend', ' <button class="btn small sec" id="btnPrix">Afficher les prix</button>');
$('btnPrix').insertAdjacentHTML('afterend', ' <button class="btn small sec" id="btnFeuille">Feuille de métré (par lot)</button> <button class="btn small sec" id="btnCdpgf">CDPGF (par lot)</button>');
$('btnFeuille').onclick = () => imprimerPdf('feuille');
$('btnCdpgf').onclick = () => imprimerPdf('cdpgf');


$('btnPrix').insertAdjacentHTML('afterend', ' <select id="selTravaux" title="Type de travaux : détermine les généralités" style="min-height:30px;padding:2px 6px;font-size:12px"><option value="neuf">Construction neuve</option><option value="renovation">Rénovation</option><option value="extension">Extension</option></select>');
$('selTravaux').addEventListener('change', e => basculerTravaux(e.target.value));
$('selTravaux').insertAdjacentHTML('afterend', ' <label style="font-size:12px;color:var(--mut)" title="Date limite de réponse imprimée sur le CDPGF">Réponse avant le <input type="date" id="dateLimite" style="min-height:30px;padding:2px 6px;font-size:12px"></label>');
$('dateLimite').addEventListener('change', e => {
  const c = chantiers.find(x => x.id === courantId);
  if (!c) return;
  c.dateLimite = e.target.value || null;
  lsSet('chantiers', chantiers);
  marquerChantier(courantId);
});
$('btnPrix').onclick = () => { lsSet('prix', !prixAffiches()); renderMetre(); };

// Réglage « Afficher les prix » : enregistré tout de suite, mis à jour dans les deux fenêtres
if ($('chkPrix')) $('chkPrix').onchange = e => { lsSet('prix', e.target.checked); renderMetre(); };

$('btnSauverReglages').onclick = () => {
  lsSet('url', $('urlScript').value.trim());
  lsSet('jeton', $('jeton').value.trim());
  alert('Réglages enregistrés sur cet appareil.');
  synchroBibliotheque();
  envoyerPropositions();
};

$('btnEnvoiBib').onclick = async () => {
  if (!lsGet('url', '') || !lsGet('jeton', '')) { alert("Enregistrez d'abord l'adresse et le jeton."); return; }
  try {
    const j = await post({ action: 'sauver_bibliotheque', bibliotheque: BIB });
    alert(j.ok ? 'Bibliothèque envoyée sur Drive.' : 'Refus : ' + (j.erreur || 'erreur inconnue'));
  } catch (e) { alert('Envoi impossible pour le moment (réseau).'); }
};

/* ============ Bibliothèque : modifier les ouvrages et leurs prix ============ */
const ouvragesLibres = () => BIB.ouvrages.filter(o => !o.supprime);   // les ouvrages supprimés n'apparaissent plus
function champsBib(unite) { return champsLibre(unite).map(c => ({ cle: c.cle, libelle: c.libelle })); }
const aujourdhui = () => new Date().toLocaleDateString('fr-FR');

function ouvrirBiblio() {
  $('titre').textContent = 'Bibliothèque de métré';
  $('biblioLot').innerHTML = '<option value="">Tous les lots</option>' + BIB.lots.map(l => `<option value="${esc(l.id)}">${esc(l.nom)}</option>`).join('');
  $('biblioStatut').classList.add('hidden');
  route('biblio');
  renderBiblio();
}

function renderBiblio() {
  const q = $('biblioRecherche').value.trim().toLowerCase();
  const lot = $('biblioLot').value;
  const liste = ouvragesLibres().filter(o => (!lot || o.lot === lot) && (!q || o.designation.toLowerCase().includes(q)));
  $('biblioListe').innerHTML = liste.map(o => {
    const p = o.prix_indicatif;
    return `<div class="ouv" data-edit="${esc(o.id)}"><span>${esc(o.designation)}<div class="muted" style="font-size:12px">${esc(libLot(o.lot))}</div></span>
      <span class="tag">${esc(o.unite)} · ${p && (p.moyen != null || p.unique != null) ? fmt(p.moyen != null ? p.moyen : p.unique) + ' € HT' : 'sans prix'}</span></div>`;
  }).join('') || '<p class="muted" style="padding:12px">Aucun ouvrage.</p>';
  // Ouvrages supprimés (restaurables) : en bas de la liste
  const supprimes = BIB.ouvrages.filter(o => o.supprime && (!lot || o.lot === lot));
  if (supprimes.length) {
    $('biblioListe').innerHTML += `<details style="padding:0 12px 12px"><summary class="muted">Supprimés (${supprimes.length})</summary>` +
      supprimes.map(o => `<div class="ouv" style="padding:8px 0"><span>${esc(o.designation)}</span>
        <button class="btn small sec" data-restaurer-ouv="${esc(o.id)}">Restaurer</button></div>`).join('') + '</details>';
  }
  $('biblioCompte').textContent = `${liste.length} ouvrage(s) affiché(s) sur ${BIB.ouvrages.length}`;
}

// Prix de devis saisis (« Ajouter un prix de devis ») : ils restent tels quels.
// Un ancien enregistrement (liste « releves ») est repris comme liste de devis.
function devisDe(p) {
  if (Array.isArray(p.devis)) return p.devis.slice();
  if (Array.isArray(p.releves)) return p.releves.slice();
  return [];
}
// Moyen = moyenne du prix bas et du prix haut (ou la seule valeur saisie)
function moyenDe(bas, haut) {
  if (bas != null && haut != null) return Math.round((bas + haut) / 2 * 100) / 100;
  return bas != null ? bas : (haut != null ? haut : null);
}

function formulaireOuvrage(o, lotChoisi) {
  // Nouvel ouvrage : on reprend le lot choisi dans la bibliothèque
  const v = o || { designation: '', lot: lotChoisi || lotCourant || BIB.lots[0].id, unite: 'u' };
  const p = (o && o.prix_indicatif) || {};
  const devis = devisDe(p);
  const val = x => (x != null ? String(Math.round(x * 100) / 100).replace('.', ',') : '');
  $('sheet').innerHTML = `<h2 style="margin:0 0 6px;font-size:18px">${o ? 'Modifier l\'ouvrage' : 'Nouvel ouvrage'}</h2>
    <form id="fBib">
      <label for="b_des">Désignation</label><input id="b_des" name="designation" required value="${esc(v.designation)}">
      <label for="b_lot">Lot</label><select id="b_lot" name="lot">${BIB.lots.map(l => `<option value="${esc(l.id)}" ${l.id === v.lot ? 'selected' : ''}>${esc(l.nom)}</option>`).join('')}</select>
      <label for="b_unite">Unité de mesure</label><select id="b_unite" name="unite">${UNITES.map(u => `<option ${u === v.unite ? 'selected' : ''}>${u}</option>`).join('')}</select>
      <label for="b_mesure">Mode de métré (cotes demandées)</label><select id="b_mesure" name="mesure">${optionsMesure(v.unite, v.mesure)}</select>
      <label for="b_rappel">Formule de rappel (explication, affichée à la saisie)</label>
      <textarea id="b_rappel" name="rappel" rows="3" placeholder="ex. Longueur du mur × hauteur sous plafond, déduire les ouvertures ≥ 2 m²" style="width:100%;padding:10px;border:1px solid var(--line);border-radius:8px;background:var(--card);color:var(--fg);font:inherit">${esc(v.rappel || '')}</textarea>
      <div class="card" style="margin-top:12px">
        <strong>Prix indicatifs HT (€)</strong>
        <div class="row" style="margin-top:8px">
          <div><label for="b_bas">Prix bas</label><input id="b_bas" name="bas" inputmode="decimal" value="${val(p.min)}" placeholder="—"></div>
          <div><label for="b_haut">Prix haut</label><input id="b_haut" name="haut" inputmode="decimal" value="${val(p.max)}" placeholder="—"></div>
          <div><label for="b_moy">Prix moyen (automatique)</label><input id="b_moy" readonly value="${val(p.moyen)}" placeholder="—"></div>
        </div>
        <p class="muted" style="margin:6px 0 0">Le prix moyen se calcule seul à partir du bas et du haut.</p>
        <p class="muted" style="margin:8px 0 0">${devis.length ? 'Prix de devis saisis : ' + devis.map((x, i) => 'Devis ' + (i + 1) + ' = ' + fmt(x) + ' €').join(' · ') : 'Aucun prix de devis saisi.'}</p>
        <label for="b_nouv">Ajouter un prix de devis (HT)</label>
        <input id="b_nouv" name="nouveau" inputmode="decimal" placeholder="ex. 28,50">
        <label for="b_unique">Prix unique (HT)</label>
        <input id="b_unique" name="unique" inputmode="decimal" value="${val(p.unique)}" placeholder="si vous n'avez qu'un prix">
        <p class="muted" style="margin:4px 0 0">Dans le métré, vous choisissez ensuite Moyen, Bas, Haut, Unique ou un devis. Par défaut : Moyen, ou Unique si pas de moyen.</p>
        ${o && o.prix_indicatif ? '<label style="display:flex;gap:8px;align-items:center;color:var(--fg);margin-top:10px"><input type="checkbox" name="effacer" style="width:20px;height:20px;min-height:0"> Supprimer tous les prix de cet ouvrage</label>' : ''}
        <p class="muted" style="margin:8px 0 0">${p.source ? 'Source : ' + esc(p.source) + (p.date ? ' (' + esc(p.date) + ')' : '') : ''}</p>
      </div>
      <div class="row" style="margin-top:12px">
        <button type="button" class="btn sec" id="bBibAnnuler">Annuler</button>
        ${o ? '<button type="button" class="btn danger" id="bSupprOuv">Supprimer</button>' : ''}
        <button type="submit" class="btn">Enregistrer</button>
      </div>
    </form>`;
  const lireSaisie = id => { const t = $(id).value.trim().replace(',', '.'); return t === '' ? null : num(t); };
  const majMoyen = () => { const m = moyenDe(lireSaisie('b_bas'), lireSaisie('b_haut')); $('b_moy').value = m != null ? val(m) : ''; };
  $('b_bas').addEventListener('input', majMoyen);
  $('b_haut').addEventListener('input', majMoyen);
  $('fBib').addEventListener('submit', e => { e.preventDefault(); enregistrerOuvrage(o ? o.id : null); });
  $('b_unite').addEventListener('change', () => { $('b_mesure').innerHTML = optionsMesure($('b_unite').value, null); });
  if (o && $('bSupprOuv')) $('bSupprOuv').onclick = () => supprimerOuvrage(o.id);
}

// Suppression d'un ouvrage de la bibliothèque (il reste restaurable dans « Supprimés »)
function supprimerOuvrage(id) {
  const o = BIB.ouvrages.find(x => x.id === id);
  if (!o) return;
  if (!confirm('Supprimer l\'ouvrage « ' + o.designation + ' » de la bibliothèque ? Vous pourrez le restaurer depuis « Supprimés ».')) return;
  o.supprime = true;
  o.version = (o.version || 1) + 1;
  sauverBibliotheque();
  fermer();
  renderBiblio();
}

function enregistrerOuvrage(id) {
  const f = $('fBib');
  const des = f.elements.designation.value.trim();
  if (!des) { alert('La désignation est obligatoire.'); return; }
  const lot = f.elements.lot.value, unite = f.elements.unite.value;
  const lire = k => { const t = f.elements[k].value.trim().replace(',', '.'); return t === '' ? null : num(t); };
  const bas = lire('bas'), haut = lire('haut'), nouv = lire('nouveau'), unique = lire('unique');
  for (const [valeur, nom] of [[bas, 'Le prix bas'], [haut, 'Le prix haut'], [nouv, 'Le prix de devis'], [unique, 'Le prix unique']]) {
    if (valeur !== null && !(valeur > 0)) { alert(nom + ' doit être un nombre supérieur à 0.'); return; }
  }
  const effacer = f.elements.effacer ? f.elements.effacer.checked : false;
  const mesure = f.elements.mesure ? f.elements.mesure.value : '';
  const rappel = f.elements.rappel ? f.elements.rappel.value.trim() : '';
  const ancien = id ? (BIB.ouvrages.find(x => x.id === id).prix_indicatif || {}) : {};
  let prix = null;
  if (!effacer) {
    const devis = devisDe(ancien).concat(nouv !== null ? [nouv] : []);
    // Le moyen enregistré est gardé, sauf si le bas ou le haut a été modifié
    const inchange = (bas !== null || haut !== null) && bas === (ancien.min ?? null) && haut === (ancien.max ?? null) && ancien.moyen != null;
    prix = { min: bas, max: haut, moyen: inchange ? ancien.moyen : moyenDe(bas, haut), unique, devis,
             source: ancien.source || 'saisie dans l\'application', date: aujourdhui() };
    for (const k of Object.keys(prix)) if (prix[k] === null || (Array.isArray(prix[k]) && !prix[k].length)) delete prix[k];
    if (prix.moyen == null && prix.unique == null && !prix.devis) prix = null;
  }
  if (id) {
    const o = BIB.ouvrages.find(x => x.id === id);
    if (mesure) o.champs = champsPourMode(unite, mesure);
    else if (o.unite !== unite || !o.champs || o.mesure) o.champs = champsBib(unite);
    if (mesure) o.mesure = mesure; else delete o.mesure;
    if (rappel) o.rappel = rappel; else delete o.rappel;
    o.designation = des; o.lot = lot; o.unite = unite;
    o.version = (o.version || 1) + 1;
    if (prix) o.prix_indicatif = prix; else delete o.prix_indicatif;
  } else {
    const n = Math.max(0, ...BIB.ouvrages.map(o => parseInt(o.id.slice(4), 10))) + 1;
    const o = { id: 'OUV-' + String(n).padStart(4, '0'), lot, designation: des, unite, type: 'commun', saisie: 'metre', champs: (mesure ? champsPourMode(unite, mesure) : champsBib(unite)), version: 1 };
    if (mesure) o.mesure = mesure;
    if (rappel) o.rappel = rappel;
    if (prix) o.prix_indicatif = prix;
    BIB.ouvrages.push(o);
  }
  sauverBibliotheque();
}

// Enregistre sur l'appareil, puis envoie sur Drive si la connexion est active
async function sauverBibliotheque() {
  lsSet('bib', BIB);
  lsSet('bib_modifiee', true);
  const statut = $('biblioStatut');
  let texte;
  if (!lsGet('url', '') || !lsGet('jeton', '')) {
    texte = 'Enregistré sur cet appareil. Renseignez le script dans Réglages pour l\'envoyer sur Drive.';
  } else {
    try {
      const j = await post({ action: 'sauver_bibliotheque', bibliotheque: BIB });
      if (j.ok) { lsSet('bib_modifiee', false); texte = 'Enregistré et envoyé sur Drive.'; }
      else texte = 'Drive a refusé l\'envoi : ' + (j.erreur || 'erreur inconnue') + '. Enregistré sur cet appareil.';
    } catch (e) {
      texte = 'Pas de réseau : enregistré sur cet appareil, il sera envoyé plus tard.';
    }
  }
  fermer();
  statut.textContent = texte;
  statut.classList.remove('hidden');
  renderBiblio();
}

$('btnBiblio').onclick = ouvrirBiblio;
$('biblioLot').onchange = renderBiblio;
$('biblioRecherche').oninput = renderBiblio;
$('btnBiblioNouveau').onclick = () => { ouvrirModal(); formulaireOuvrage(null, $('biblioLot').value); };
$('biblioListe').addEventListener('click', e => {
  const r = e.target.closest('[data-restaurer-ouv]');
  if (r) {
    const o = BIB.ouvrages.find(x => x.id === r.dataset.restaurerOuv);
    if (o) { o.supprime = false; o.version = (o.version || 1) + 1; sauverBibliotheque(); renderBiblio(); }
    return;
  }
  const b = e.target.closest('[data-edit]');
  if (!b) return;
  const o = BIB.ouvrages.find(x => x.id === b.dataset.edit);
  if (o) { ouvrirModal(); formulaireOuvrage(o); }
});

/* ============ Synchro entre les deux fenêtres ============ */
window.addEventListener('storage', e => {
  if (!e.key || !e.key.startsWith(LS)) return;
  chantiers = lsGet('chantiers', []);
  courantId = lsGet('courant', courantId);
  if (PAGE === 'tableau' && e.key === LS + 'courant' && courantId) { ouvrirChantier(courantId); return; }
  if (PAGE === 'tableau') renderMetre();
  compterLignes();
});

/* ============ Démarrage ============ */
(async function init() {
  await chargerBibliotheque();
  if (!BIB) { document.body.insertAdjacentHTML('beforeend', '<p class="muted" style="padding:16px">Bibliothèque introuvable.</p>'); return; }
  lotCourant = BIB.lots[0].id;
  remplirLots();
  renderChantiers();
  preparerClients();
  if (courantId && chantiers.find(c => c.id === courantId && !c.supprime)) ouvrirChantier(courantId);
  else route(PAGE === 'tableau' ? 'tableau' : 'chantiers');
  const refClient = new URLSearchParams(location.search).get('client');
  if (refClient) {
    history.replaceState(null, '', location.pathname);
    await ouvrirDepuisClient(refClient);
  }
  synchroBibliotheque();
  preparerSynchro();
  preparerTaillePG();
  synchroniserChantiers();
  envoyerPropositions();
  if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
})();
if ($('btnConfig')) $('btnConfig').onclick = () => ouvrirConfig();
