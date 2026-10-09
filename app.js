
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
let chantiers = lsGet('chantiers', []);
let courantId = lsGet('courant', null);
let lotCourant = null;

function lignesDe(id) { return lsGet('lignes.' + id, []); }
function sauverLignes(id, L) { const ok = lsSet('lignes.' + id, L); marquerChantier(id); return ok; }
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

function detail(l) {
  const noms = { nombre: 'nb', cote1: 'L', cote2: 'l', cote3: 'h', largeur_cm: 'larg.', hauteur_cm: 'haut.' };
  let t = Object.entries(l.valeurs)
    .filter(([k, v]) => v !== '' && v != null)
    .map(([k, v]) => (noms[k] ? noms[k] + ' ' : '') + v)
    .join(' × ');
  if (l.surface) t += ` (surface ${fmt(l.surface)} m²)`;
  return t;
}

/* ============ Affichage ============ */
function route(nom) {
  const vues = { chantiers: 'vChantiers', metre: 'vMetre', tableau: 'vTableau', reglages: 'vReglages', biblio: 'vBiblio' };
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
    h += `<tr class="lot" data-lot="${esc(lotId)}"><td colspan="${nc}"><span class="poignee" data-glisser="${esc(lotId)}" title="Glisser pour déplacer le lot">⋮⋮</span><span class="lotnum">${String(i + 1).padStart(2, '0')}</span> ${esc(lot ? lot.nom : lotId)}
      <span class="muted">(${vide ? 'aucune ligne' : ls.length + ' ligne' + (ls.length > 1 ? 's' : '')})</span>
      ${vide ? `<button class="btn small sec" data-retirer-lot="${esc(lotId)}">Retirer</button>` : ''}</td></tr>`;
    for (const l of ls) {
      const pu = prixUnitaire(l);
      const mt = pu != null ? l.quantite * pu : null;
      if (mt != null) total += mt; else sansPrix++;
      h += `<tr class="ligne" data-uid="${esc(l.uid)}" data-lot="${esc(lotId)}">
        <td class="numl"><span class="poignee" data-glisser-ligne="${esc(l.uid)}" title="Glisser pour déplacer l'ouvrage">⋮⋮</span>${nums[l.uid]}</td>
        <td>${esc(l.designation)}</td>
        <td>${esc(l.unite)}</td>
        <td class="num">${fmt(l.quantite)}</td>
        <td class="detail">${esc(detail(l))}</td>
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

/* ============ Fenêtre de saisie (ouvrage du catalogue) ============ */
function fermer() { $('modal').classList.remove('open'); }
function ouvrirModal() { $('modal').classList.add('open'); }

function ouvrirOuvrage(o, precedent, message) {
  const champs = champsDe(o);
  const v = precedent || { nombre: '1' };
  let h = `<h2 style="margin:0 0 4px;font-size:18px">${esc(o.designation)}</h2>
    <div class="muted">${esc(libLot(o.lot))} · unité : ${esc(o.unite)}</div>`;
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
    const q = calcul(o, vals);
    if (!(q > 0)) { $('apercu').textContent = 'Quantité nulle : vérifiez les cotes.'; return; }
    const surface = (o.saisie === 'menuiseries' && num(vals.largeur_cm) && num(vals.hauteur_cm))
      ? num(vals.nombre || 1) * num(vals.largeur_cm) * num(vals.hauteur_cm) / 10000 : null;
    ajouterLotSiAbsent(courantId, o.lot);
    const L = lignesDe(courantId);
    L.push({ uid: uid(), lot: o.lot, ouvrage: o.id, designation: o.designation, unite: o.unite,
             valeurs: vals, quantite: q, surface, cree: new Date().toISOString() });
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
    num: pad2(i + 1),
    nom: libLot(lotId),
    lignes: L.filter(l => l.lot === lotId).map(l => {
      const pu = avecPrix ? prixUnitaire(l) : null;
      const montant = pu != null ? l.quantite * pu : null;
      if (montant != null) total += montant;
      return { num: nums[l.uid], designation: l.designation, unite: l.unite,
               quantite: l.quantite, detail: detail(l), pu, montant };
    })
  }));
  return { titre: c.nom, client: c.client || null, date: new Date().toLocaleDateString('fr-FR'), lots,
           avecPrix, total };
}

function htmlImpression(d, logo) {
  const cl = d.client || {};
  const ligne = (label, val) => val ? `<tr><th class="k">${esc(label)}</th><td>${esc(val)}</td></tr>` : '';
  const surf = cl.surf ? `${cl.surf} m²` : '';
  let corps = '';
  const nc = d.avecPrix ? 7 : 5;
  for (const lot of d.lots) {
    corps += `<tr class="lot"><td colspan="${nc}">${esc(lot.num)} · ${esc(lot.nom)}${lot.lignes.length ? '' : ' <span class="vide">(aucune ligne)</span>'}</td></tr>`;
    for (const l of lot.lignes) {
      corps += `<tr><td class="n">${esc(l.num)}</td><td>${esc(l.designation)}</td><td>${esc(l.unite)}</td>
        <td class="num">${fmt(l.quantite)}</td><td class="det">${esc(l.detail)}</td>
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

async function imprimerPdf() {
  // La fenêtre est ouverte tout de suite (sinon le navigateur la bloque), puis remplie.
  const w = window.open('', 'metre2m-impression');
  if (!w) { alert("La fenêtre d'impression est bloquée. Autorisez les fenêtres pour ce site, puis réessayez."); return; }
  w.document.write('<p style="font-family:sans-serif;padding:20px">Préparation du document…</p>');
  const logo = new URL('logo.png', location.href).href;
  let avecLogo = false;
  try { avecLogo = (await fetch(logo, { method: 'HEAD', cache: 'no-cache' })).ok; } catch (e) {}
  w.document.open();
  w.document.write(htmlImpression(donneesDocument(), avecLogo ? logo : ''));
  w.document.close();
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
$('btnPdf').insertAdjacentHTML('afterend', ' <button class="btn small sec" id="btnPrix"></button>');
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
    if (o.unite !== unite || !o.champs) o.champs = champsBib(unite);
    o.designation = des; o.lot = lot; o.unite = unite;
    o.version = (o.version || 1) + 1;
    if (prix) o.prix_indicatif = prix; else delete o.prix_indicatif;
  } else {
    const n = Math.max(0, ...BIB.ouvrages.map(o => parseInt(o.id.slice(4), 10))) + 1;
    const o = { id: 'OUV-' + String(n).padStart(4, '0'), lot, designation: des, unite, type: 'commun', saisie: 'metre', champs: champsBib(unite), version: 1 };
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
  synchroniserChantiers();
  envoyerPropositions();
  if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
})();
