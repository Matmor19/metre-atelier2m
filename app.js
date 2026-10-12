
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
    table.metre tr.lot td{background:#E07838;color:#fff;font-weight:700;font-size:13px;padding:8px;text-transform:uppercase;letter-spacing:.02em}
    table.metre tr.lot .muted{font-weight:400;color:#fff;opacity:.9;text-transform:none}
    @media print{button[data-desig]{display:none !important}}
    table.metre tr.lot .poignee{color:#fff}
    table.metre tr.lot .gen-choix{color:#fff;text-transform:none}
    table.metre tr.lot .btn{color:#E07838;border-color:#fff;background:#fff}
    table.metre tbody tr:not(.lot):hover td{background:rgba(47,111,176,.06)}
    table.metre .btn.small{min-height:30px;padding:4px 9px}
    table.metre td.numl{font-weight:700;color:var(--acc2);white-space:nowrap}
    table.metre tr.lot .lotnum{display:inline-block;min-width:2.2em;font-weight:700;color:#fff}
    table.metre .gen-choix{display:inline-block;margin-left:12px;font-size:12px;font-weight:400;color:var(--mut);cursor:pointer;white-space:nowrap}
    table.metre .gen-choix input{width:auto;height:auto;margin:0 4px 0 0;padding:0;vertical-align:middle;accent-color:var(--acc2)}
    table.metre tr.gen td{background:#fbfaf8;font-size:13px;line-height:1.4;padding:8px 12px 10px 40px;border-bottom:1px solid var(--line,#e5e5e5)}
    table.metre .gen-titre{color:var(--acc2);font-weight:700;margin-bottom:4px}
    table.metre .gen-s{margin-top:6px}
    table.metre .gen-sec ul{margin:2px 0 0;padding-left:18px}
    table.metre .gen-sec li{margin:1px 0}
    table.metre .poignee{cursor:grab;touch-action:none;user-select:none;color:var(--mut);display:inline-flex;align-items:center;justify-content:center;min-width:44px;min-height:44px;margin:-10px 0 -10px -6px;font-size:24px;line-height:1;letter-spacing:-3px;border-radius:8px}
    table.metre .poignee:active{background:rgba(31,58,95,.12)}
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
    body[data-page="tableau"] table.metre tr.lot td{background:#E07838;color:#fff}
    @media (prefers-color-scheme: dark){ body[data-page="tableau"]{background:#2a1d15} }
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

// Ajoute les ouvrages de soutènement et de muret s'ils manquent (copie du téléphone comprise)
function assurerOuvragesSoutenement() {
  if (!BIB || !Array.isArray(BIB.ouvrages)) return false;
  let change = false;
  for (const t of SOUT_TYPES) {
    if (BIB.ouvrages.some(o => o.id === t.idOuv)) continue;
    BIB.ouvrages.push({ id: t.idOuv, lot: t.lot, designation: t.designation, unite: 'm²', type: 'commun', saisie: 'metre', mesure: 'lxh', champs: champsPourMode('m²', 'lxh'), version: 1 });
    change = true;
  }
  const plusGrand = Math.max(BIB.prochainNumero || 0, ...BIB.ouvrages.map(o => parseInt(String(o.id).slice(4), 10) || 0));
  if (plusGrand > (BIB.prochainNumero || 0)) { BIB.prochainNumero = plusGrand; change = true; }
  if (change) lsSet('bib', BIB);
  return change;
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
  assurerOuvragesSoutenement();
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
      const ajoutes = assurerOuvragesSoutenement();
      lsSet('bib', BIB);
      if (ajoutes) { const s2 = await post({ action: 'sauver_bibliotheque', bibliotheque: BIB }); if (s2.ok) lsSet('bib_modifiee', false); }
      if (!lotCourant) lotCourant = BIB.lots[0].id;
      remplirLots(); renderOuvrages();
      // Sur la page du métré, les lignes reprennent les textes de la bibliothèque reçue du Drive
      if (PAGE === 'tableau' && courantId) renderMetre();
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
         { id: 'lxh', nom: 'Longueur × Hauteur', cotes: ['Longueur', 'Hauteur'] },
         { id: 'surface', nom: 'Surface (saisie directe)', cotes: ['Surface'], surface: true }],
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
  return [{ cle: 'nombre', libelle: 'Nombre' }, ...m.cotes.map((c, i) => ({ cle: 'cote' + (i + 1), libelle: m.surface ? 'Surface (m²)' : c + ' (m)' }))];
}
// Cases à relier pour un ouvrage : celles de son mode (sans le nombre), sinon les cotes par défaut
function champsCotesOuv(unite, mesure) {
  const m = mesure ? champsPourMode(unite, mesure) : null;
  return m ? m.filter(x => x.cle !== 'nombre') : champsBib(unite);
}

function calcul(o, v) {
  const n = (v.nombre === '' || v.nombre == null) ? 1 : num(v.nombre);
  const c1 = num(v.cote1), c2 = num(v.cote2), c3 = num(v.cote3);
  switch (o.unite) {
    case 'm²': return o.mesure === 'surface' ? n * c1 : n * c1 * c2;
    case 'm³': return n * c1 * c2 * c3;
    case 'ml': return n * c1;
    default:   return n;               // u, forfait
  }
}

// Champs affichés pour un ouvrage du catalogue
function champsDe(o) {
  // Ouvrage lié à un autre : pas de « Nombre », les cotes viennent de l'ouvrage source
  const c = o.champs.filter(x => !((o.liePar || o.lieConfig) && x.cle === 'nombre')).map(x => ({ ...x }));
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
  const v0 = l.valeurs || {};
  if (v0.src === TXT_SURFACE && v0.cote1 && v0.cote3) {
    const nb0 = num(v0.nombre) > 0 ? num(v0.nombre) : 1;
    return (nb0 !== 1 ? fmt(nb0) + ' × ' : '') + TXT_SURFACE + ' ' + fmt(num(v0.cote1)) + ' m² × hauteur ' + fmt(num(v0.cote3)) + ' m';
  }
  let t = detailMorceaux(l).map(m => (m.nom ? m.nom + ' ' : '') + m.v).join(' × ');
  if (l.surface) t += ` (surface ${fmt(l.surface)} m²)`;
  return t;
}
// Version colorée (écran et impressions) : chaque cote a sa couleur
// Détail d'une surface donnée en m² : seulement ce texte
const TXT_SURFACE = 'Surface mesurée suivant plan';
// Ouverture déduite des murs à partir de cette surface (m²), partout dans le calcul et les libellés
const SEUIL_DEDUCTION = 1.5;
// Murs de soutènement et muret de jardin : surface nette (longueur × hauteur), aucune ouverture déduite
const SOUT_TYPES = [
  { id: 'beton', nom: 'Mur de soutènement béton armé', idOuv: 'OUV-0881', designation: 'Mur de soutènement béton armé (surface nette)', lot: 'terrassement-vrd' },
  { id: 'aggl', nom: 'Mur de soutènement en aggloméré de ciment', idOuv: 'OUV-0882', designation: 'Mur de soutènement en aggloméré de ciment (surface nette)', lot: 'terrassement-vrd' },
  { id: 'muret', nom: 'Muret de jardin', idOuv: 'OUV-0883', designation: 'Muret de jardin (surface nette)', lot: 'amenagement-exterieur' }
];
function detailHtml(l) {
  const v = l.valeurs || {};
  // Texte du détail corrigé à la main (ligne sans formule de cotes)
  if (l.detailTexte && !avecFormule(l)) return esc(l.detailTexte);
  // Plateforme saisie en surface × hauteur : surface mesurée suivant plan, puis × hauteur
  if (v.src === TXT_SURFACE && v.cote1 && v.cote3) {
    const nb = num(v.nombre) > 0 ? num(v.nombre) : 1;
    return (nb !== 1 ? esc(fmt(nb)) + ' × ' : '') + esc(TXT_SURFACE) + ' ' + esc(fmt(num(v.cote1))) + ' m² × hauteur ' + esc(fmt(num(v.cote3))) + ' m';
  }
  if (v.mode === 'plan' || (v.src && /^(Surface du configurateur|Surface mesurée|Calcul suivant plan)/.test(v.src))) return esc(TXT_SURFACE);
  // Surface nette des murs : on liste chaque mur (dimensions prises dans le configurateur du chantier)
  if (v.src && /^(Calcul du configurateur : )?murs, surface nette/.test(v.src)) {
    const c = chantiers.find(x => x.id === courantId);
    const typeLigne = v.typeMur || '';
    const murs = c ? projetDe(c).murs.filter(m => (m.type || '') === typeLigne && num(m.longueur) > 0 && num(m.hauteur) > 0) : [];
    // Mêmes couleurs que dans les formules : longueur en vert, hauteur en bleu
    const liste = murs.map((m, i) => `${esc(m.nom || 'Mur ' + (i + 1))} : <span style="color:${COTE_COULEUR.Longueur};font-weight:700">${esc(fmt(num(m.longueur)))} m</span> × <span style="color:${COTE_COULEUR.Hauteur};font-weight:700">${esc(fmt(num(m.hauteur)))} m</span>${m.deduire === true ? ' · ouvertures déduites' : ''}`).join(' ; ');
    return esc(v.src.replace(/^Calcul du configurateur : /, '')) + (liste ? `<br><span style="font-size:11.5px">${liste}</span>` : '');
  }
  if (v.src) return esc(v.src.replace(/^Calcul du configurateur : /, ''));
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
  for (const k of Object.keys(vues)) { const el = $(vues[k]); if (el) el.classList.toggle('hidden', k !== nom); }
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
        <div><strong>${esc(c.nom)}</strong><div class="muted">${c.client && c.client.ref ? 'Kanban ' + esc(c.client.ref) + ' · ' : ''}${lignesDe(c.id).length} ligne(s)</div></div>
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

// En-tête de saisie (lot + recherche) figé sous la barre du haut
function figerEntete() {
  const h = document.querySelector('header'), c = $('blocFige');
  if (c) c.style.top = (h ? h.offsetHeight : 0) + 'px';
}
window.addEventListener('resize', figerEntete);
// Lot choisi dans la saisie : en surbrillance orange
function colorerLot() {
  const s = $('selLot'); if (!s) return;
  s.style.background = '#E07838'; s.style.color = '#fff'; s.style.borderColor = '#E07838'; s.style.fontWeight = '700';
}
function remplirLots() {
  $('selLot').innerHTML = BIB.lots.map(l => `<option value="${esc(l.id)}">${esc(l.nom)}</option>`).join('');
  if (!lotCourant) lotCourant = BIB.lots[0].id;
  $('selLot').value = lotCourant;
  colorerLot();
}

function renderOuvrages() {
  figerEntete();
  const q = $('recherche').value.trim().toLowerCase();
  const liste = BIB.ouvrages.filter(o => !o.supprime && o.lot === lotCourant && (!q || o.designation.toLowerCase().includes(q)));
  const lignes = liste.map(o => `<div class="ouv" data-ouv="${esc(o.id)}"><span>${esc(o.designation)} <span class="muted" style="font-size:12px">· ${esc(o.id)}</span></span><span class="tag">${esc(o.unite)}</span></div>`).join('');
  $('listeOuvrages').innerHTML = (lignes || '<p class="muted" style="padding:12px">Aucun ouvrage trouvé dans ce lot.</p>')
    + '<div style="padding:12px"><button class="btn sec" id="bLibre2">+ Ouvrage libre dans ce lot</button></div>';
}

/* ============ Lots du chantier et numérotation ============ */
// Ordre des lots = ordre dans lequel ils ont été ajoutés au métré (pas l'ordre de la bibliothèque)
function lotsDuChantier(id) {
  if (!BIB) return [];
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
  if (_revueCollecte) return;   // calcul interne du configurateur : aucune ligne n'est gardée, le lot ne doit pas revenir
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

// Mise à jour automatique : les lignes déjà au métré qui correspondent à un ouvrage du configurateur
// sont mises à jour sur place (même place, même numéro). Rien n'est ajouté ni supprimé ici.
let _majConfigEnCours = false;
// Valeur d'une case du configurateur, lue à l'adresse qu'utilise ficheChange
const BLOC_CFG = { toit: 'toiture', fond: 'fond', soub: 'soub', terr: 'terrain', plan: 'plancher', choix: 'choix', equip: 'equip', cuis: 'cuisine', chant: 'chantier' };
function valeurLien(c, l) {
  if (!c || !l) return undefined;
  const p = projetDe(c);
  if (l.k === 'epais') return p.epaisseur;
  if (l.k === 'piece') {
    // Liaison par nom (type + numéro ou nom) : chaque chantier retrouve sa propre pièce ; sinon ancienne liaison par position
    const liste = piecesDe(c);
    const pc = l.type !== undefined ? liste.find(x => x.type === l.type && (x.qualif || '') === (l.qualif || '')) : liste[l.idx];
    return pc ? pc[l.champ] : undefined;
  }
  if (l.k === 'mur') { const m = (p.murs || []).find(x => x.id === l.id); return m ? m[l.champ] : undefined; }
  if (l.k === 'ouv') { const x = (p.ouvertures || []).find(y => y.id === l.id); return x ? x[l.champ] : undefined; }
  if (l.k === 'pleine') { const e = pleinesDe(p.fond).find(y => y.id === l.id); return e ? e[l.champ] : undefined; }
  const b = p[BLOC_CFG[l.k]];
  return b ? b[l.champ] : undefined;
}
// Cotes reliées une à une à des cases du configurateur : { cote1: '0.8', … } (seulement celles qui ont une valeur)
function valeursCotes(o, c) {
  const out = {};
  if (!o || !o.cotes || !c) return out;
  for (const cle of Object.keys(o.cotes)) {
    const v = valeurLien(c, o.cotes[cle]);
    if (v !== undefined && v !== null && v !== '') out[cle] = String(v);
  }
  return out;
}
// Sources « configurateur » possibles pour les cotes d'un ouvrage (L, l, h)
const SOURCES_CONFIG = [
  { cle: 'massif_m3', libelle: 'Massif de fondation (longueur, largeur, hauteur)' },
  { cle: 'fond_fouille', libelle: 'Fouille en tranchée des semelles filantes (rigoles)' }
];
// Cotes (cote1..3) d'un ouvrage lié : configurateur, ou dernière ligne de l'ouvrage source. Null si rien.
function coteSource(o, id, uidExclu) {
  if (o.lieConfig) {
    const c = chantiers.find(x => x.id === id);
    if (!c) return null;
    const v = qteValeur({ qte: o.lieConfig, unite: o.unite }, ctxQuantites(c));
    return v && v.cote1 != null && v.cote1 !== '' ? { nombre: v.nombre ?? '1', cote1: v.cote1, cote2: v.cote2 ?? '', cote3: v.cote3 ?? '' } : null;
  }
  if (!o.liePar) return null;
  const src = lignesDe(id).slice().reverse().find(y => y.ouvrage === o.liePar && y.uid !== uidExclu);
  if (!src || !src.valeurs || src.valeurs.cote1 == null || src.valeurs.cote1 === '') return null;
  return { cote1: src.valeurs.cote1, cote2: src.valeurs.cote2 ?? '', cote3: src.valeurs.cote3 ?? '' };
}
// Liaison permanente : une ligne dont l'ouvrage « reprend les cotes » d'un autre suit les cotes de sa dernière ligne
function majLignesLiees(id) {
  if (!id || !BIB || _revueCollecte) return;
  let L = lignesDe(id), ch = false;
  for (let passe = 0; passe < 3; passe++) {
    let change = false;
    L = L.map(x => {
      const o = BIB.ouvrages.find(y => y.id === x.ouvrage);
      if (!o || o.liePar === o.id) return x;
      const cs = (o.liePar || o.lieConfig) ? coteSource(o, id, x.uid) : null;
      const fromCotes = valeursCotes(o, chantiers.find(c => c.id === id));
      if (!cs && !Object.keys(fromCotes).length) return x;
      const nv = Object.assign({}, x.valeurs);
      delete nv.src; delete nv.mode;
      if (cs) {
        nv.nombre = cs.nombre != null ? cs.nombre : '1';   // nombre : celui du configurateur, sinon 1
        ['cote1', 'cote2', 'cote3'].forEach(k => { nv[k] = cs[k] != null ? cs[k] : ''; });
      }
      Object.assign(nv, fromCotes);   // cotes reliées une à une : elles l'emportent
      if (nv.nombre == null || nv.nombre === '') nv.nombre = '1';
      const q = calcul(o, nv);
      const marque = o.liePar || o.lieConfig || o.id;   // marque la ligne comme liée (même si ses valeurs ne changent pas)
      if (JSON.stringify(nv) === JSON.stringify(x.valeurs) && Math.abs(num(q) - num(x.quantite)) < 1e-9) {
        if (x.lienDe === marque) return x;
        ch = true;
        return Object.assign({}, x, { lienDe: marque });
      }
      change = true; ch = true;
      return Object.assign({}, x, { valeurs: nv, quantite: q, lienDe: marque });
    });
    if (!change) break;
  }
  if (ch) sauverLignes(id, L);
}
// Nettoyage du libellé « (rigoles) » : ne dépend pas de la reconnaissance des lignes
function nettoyerSuffixeRigoles(id) {
  if (_revueCollecte || !id) return;
  const L = lignesDe(id);
  let ch = false;
  const N = L.map(x => {
    if (typeof x.designation === 'string' && /\s*\(rigoles\)$/.test(x.designation)) {
      ch = true;
      return Object.assign({}, x, { designation: x.designation.replace(/\s*\(rigoles\)$/, '') });
    }
    return x;
  });
  if (ch) sauverLignes(id, N);
}
function majLignesDepuisConfigurateur(c) {
  // Jamais pendant une revue (la revue a sa propre collecte)
  if (!c || _majConfigEnCours || _revueCollecte || !BIB) return;
  _majConfigEnCours = true;
  try {
    const L = lignesDe(c.id);
    if (!L.length) return;
    const col = {};
    _revueCollecte = {};
    try { genererElec(); genererPlat(); ficheVersMetre(); }
    finally { Object.assign(col, _revueCollecte); _revueCollecte = null; }
    // Ancien suffixe « (rigoles) » ignoré : les anciennes lignes restent reconnues
    const cleL = l => l.ouvrage + '|' + String(l.designation || '').replace(/\s*\(rigoles\)$/, '');
    const sig = v => ['nombre', 'cote1', 'cote2', 'cote3'].map(k => num(v && v[k])).join('|');
    const uids = new Set(L.map(x => x.uid));
    // Lignes du configurateur (sans quantité automatique) que le configurateur ne produit plus : retirées de CE chantier
    const produitesC = new Set();
    for (const arr of Object.values(col)) for (const l of arr) if (l.ouvrage && !uids.has(l.uid)) produitesC.add(cleL(l));
    const sansSource = new Set(L.filter(x => (x.projet || x.auto || x.plat) && !x.qteAuto && x.ouvrage && !produitesC.has(cleL(x))).map(x => x.uid));
    const Lk = sansSource.size ? L.filter(x => !sansSource.has(x.uid)) : L;
    if (sansSource.size) sauverLignes(c.id, Lk);
    // Propositions du configurateur qui ne sont pas des copies des lignes déjà présentes
    const vus = new Set(), fresh = [];
    for (const arr of Object.values(col)) for (const l of arr) {
      if (!l.ouvrage || uids.has(l.uid)) continue;
      const k = cleL(l) + JSON.stringify(l.valeurs);
      if (vus.has(k)) continue;
      vus.add(k); fresh.push(l);
    }
    const pool = {};
    for (const x of Lk) if (x.ouvrage) (pool[cleL(x)] = pool[cleL(x)] || []).push(x);
    const remplacer = new Map();
    for (const l of fresh) {
      const ex = pool[cleL(l)] && pool[cleL(l)].shift();
      if (!ex) continue;
      // Le texte du détail (src) compte aussi : un libellé corrigé dans l'application met à jour la ligne existante
      if (sig(ex.valeurs) !== sig(l.valeurs) || (ex.valeurs || {}).src !== (l.valeurs || {}).src || Math.abs(num(ex.quantite) - num(l.quantite)) > 1e-9 || !ex.projet || ex.designation !== l.designation) {
        // On garde prix, surface, uid, date de création ; on met à jour ce que calcule le configurateur
        remplacer.set(ex.uid, Object.assign({}, ex, { designation: l.designation, unite: l.unite, valeurs: l.valeurs, quantite: l.quantite, projet: true, qteAuto: l.qteAuto || ex.qteAuto }));
      }
    }
    if (!remplacer.size) return;
    const nouvelles = Lk.map(x => remplacer.has(x.uid) ? remplacer.get(x.uid) : x);
    sauverLignes(c.id, nouvelles);
  } finally { _majConfigEnCours = false; }
}
// Texte des lignes reprises de la bibliothèque : mis à jour quand l'ouvrage est renommé dans la bibliothèque.
// Les lignes du configurateur (libellé calculé, « – Pièce ») gardent leur texte.
function rafraichirDesignations(id) {
  if (_revueCollecte || !id || !BIB) return;
  const L = lignesDe(id);
  let change = false;
  const nouvelles = L.map(l => {
    if (!l.ouvrage || l.projet || l.plat || l.auto || l.libre || String(l.designation || '').includes(' – ')) return l;
    const o = BIB.ouvrages.find(x => x.id === l.ouvrage && !x.supprime);
    if (!o || !o.designation || o.designation === l.designation) return l;
    change = true;
    return Object.assign({}, l, { designation: o.designation });
  });
  if (change) sauverLignes(id, nouvelles);
}
function renderMetre() {
  if (!courantId || !BIB) return;
  nettoyerSuffixeRigoles(courantId);
  rafraichirDesignations(courantId);
  majLignesDepuisConfigurateur(chantiers.find(x => x.id === courantId));
  majLignesLiees(courantId);
  majQuantitesAuto(chantiers.find(x => x.id === courantId));
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
  // Colonne N° élargie : la poignée de déplacement (44 px) et le numéro doivent tenir côte à côte
  const colonnes = avecPrix
    ? '<col style="width:20%"><col style="width:18%"><col style="width:9%"><col style="width:6%"><col style="width:13%"><col style="width:10%"><col style="width:8%"><col style="width:9%"><col style="width:7%">'
    : '<col style="width:20%"><col style="width:26%"><col style="width:11%"><col style="width:8%"><col style="width:17%"><col style="width:12%"><col style="width:6%">';
  let total = 0, sansPrix = 0;
  let h = `<table class="metre">
    <colgroup>${colonnes}</colgroup>
    <thead><tr><th>N°</th><th>Désignation</th><th class="num">Quantité</th><th>Unité</th><th>Détail</th><th>Prix</th>${avecPrix ? '<th class="num">P.U. HT ind.</th><th class="num">Montant HT ind.</th>' : ''}<th></th></tr></thead><tbody>`;
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
      // Surlignage « saisie manuelle » : une ligne d'un ouvrage relié (configurateur, ligne source ou cotes liées) n'en est pas une
      const oRelie = BIB.ouvrages.find(y => y.id === l.ouvrage);
      const ouvrageRelie = !!(oRelie && (oRelie.lieConfig || oRelie.liePar || oRelie.cotes));
      const manuelle = !(l.projet || l.auto || l.plat || l.qteAuto || l.lien || l.lienDe || ouvrageRelie);
      h += `<tr class="ligne${manuelle ? ' ligne-manuelle' : ''}" data-uid="${esc(l.uid)}" data-lot="${esc(lotId)}">
        <td class="numl"><span class="poignee" data-glisser-ligne="${esc(l.uid)}" title="Glisser pour déplacer l'ouvrage">⋮⋮</span>${nums[l.uid]}</td>
        <td>${esc(l.designation)}</td>
        <td class="num">${fmt(l.quantite)}</td>
        <td>${esc(l.unite)}</td>
        <td class="detail">${detailHtml(l)}${!avecFormule(l) ? ` <button class="btn small sec" data-desig="${esc(l.uid)}" title="Modifier le détail de cette ligne" style="margin-left:4px;min-height:28px;padding:2px 7px">✎</button>` : ''}</td>
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
  const nbManuelles = lignesDe(courantId).filter(l => !(l.projet || l.auto || l.plat || l.qteAuto)).length;
  if (nbManuelles) h = `<p class="legende-manuel"><span class="pastille"></span> Surbrillance : lignes saisies à la main (les autres viennent du configurateur)</p>` + h;
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
// Menuiseries extérieures (fenêtres, portes-fenêtres, portes d'entrée) rattachées à une pièce
function menusDe(piece) {
  if (!piece.menus) piece.menus = [];
  // Ancien format (fenêtres saisies en simple nombre et dimensions) : converti en menuiseries
  if (piece.fenetres && piece.fenetres.length) {
    for (const f of piece.fenetres) piece.menus.push({ id: 'm' + uid(), type: 'ouvrant', nb: f.nb || '1', largeur: f.largeur || '', hauteur: f.hauteur || '', materiau: '', volet: 'aucun', matvolet: '', electrique: false, securit: false, opaque: false, appui: '' });
    piece.fenetres = [];
  }
  return piece.menus;
}
// Liste à plat de toutes les menuiseries du chantier, avec leur pièce et leur nombre total
function menusCalcul(c) {
  const L = [];
  const pcs = Array.isArray(c) ? c : piecesDe(c);
  for (const pc of pcs) for (const m of menusDe(pc)) L.push({ piece: pc, m, nb: (num(m.nb) || 1) * (num(pc.nb) || 1) });
  return L;
}
// Appuis de fenêtre : longueur par type d'appui, pris dans chaque menuiserie
function appuisCtx(c) {
  const out = { ml_appuis_beton: 0, ml_appuis_beton_pierre: 0, ml_appuis_alu: 0, ml_appuis_acier: 0 };
  for (const x of menusCalcul(c)) {
    if (!['ouvrant', 'oscillo', 'coulissant'].includes(x.m.type)) continue;
    const k = 'ml_appuis_' + String(x.m.appui || '').replace('-', '_');
    if (k in out) out[k] += num(x.m.largeur) * x.nb;
  }
  return out;
}
function piecesDe(c) {
  c.elec = c.elec || { pieces: [] };
  c.elec.pieces = c.elec.pieces || [];
  return c.elec.pieces;
}
function platDe(c) {
  if (!c.plat) c.plat = { hauteur: '' };
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
  const H = num(P.hauteur);
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
    // Murs bruts : linéaire × hauteur. Ouvertures (portes, fenêtres, passages libres) de plus de 1,50 m² déduites
    // proportionnellement des cloisons et doublages de la pièce. En pièce d'eau, tout passe en hydrofuge.
    const cloi = p.cloisons || [], doub = p.doublages || [];
    const cloiBrut = cloi.reduce((a, x) => a + num(x.ml) * H * nb, 0);
    const doubBrut = doub.reduce((a, x) => a + num(x.ml) * H * nb, 0);
    const brut = cloiBrut + doubBrut;
    let ded = 0, dedAll = 0;
    for (const x of [...(p.portes || []), ...menusDe(p), ...(p.ouvertures || []), ...(p.placards || [])]) {
      const une = num(x.largeur) * num(x.hauteur);   // surface d'une ouverture
      const total = une * (num(x.nb) || 1) * nb;
      dedAll += total;   // peinture : toutes les ouvertures sont déduites
      if (une >= SEUIL_DEDUCTION) ded += total;   // plâtrerie : seules les ouvertures de 1,50 m² ou plus (une à une)
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
    const valeurs = o.unite === 'm²' ? { nombre: '1', cote1: q.toFixed(2), cote2: '1', src: TXT_SURFACE }
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
  if (dedTot > 0) msg += ' Ouvertures de 1,50 m² ou plus déduites des murs : ' + fmt(dedTot) + ' m².';
  const uniques = manquants.filter((d, i, t) => t.indexOf(d) === i);
  if (uniques.length) msg += ' À compléter : ' + uniques.join(' ; ') + '.';
  return msg;
}
// Après suppression d'une pièce : retire du métré de CE chantier les lignes que le configurateur produisait et qui n'ont plus de source.
// Les lignes saisies à la main ne sont jamais touchées ; les autres chantiers ne sont pas concernés.
function retirerLignesSansSource(c) {
  if (!c || !BIB) return 0;
  const L = lignesDe(c.id);
  if (!L.some(x => x.projet || x.auto || x.plat || x.qteAuto)) return 0;
  _revueCollecte = {};
  try { genererElec(); genererPlat(); ficheVersMetre(); }
  finally { var col = _revueCollecte; _revueCollecte = null; }
  const cleL = l => l.ouvrage + '|' + String(l.designation || '').replace(/\s*\(rigoles\)$/, '');
  // Seules les lignes NOUVELLES comptent : le générateur remet aussi les lignes déjà au métré (même numéro), qui ne prouvent rien
  const numeros = new Set(L.map(x => x.uid));
  const produites = new Set();
  for (const arr of Object.values(col)) for (const l of arr) if (l.ouvrage && !numeros.has(l.uid)) produites.add(cleL(l));
  const ctx = ctxQuantites(c);
  const garde = L.filter(l => {
    if (!(l.projet || l.auto || l.plat || l.qteAuto)) return true;      // saisie à la main : gardée
    if (produites.has(cleL(l))) return true;                             // encore produite par le configurateur
    if (l.qteAuto) { const o = BIB.ouvrages.find(x => x.id === l.ouvrage); if (o && qteValeur(o, ctx)) return true; }
    return false;                                                        // plus de source : retirée
  });
  const retires = L.length - garde.length;
  if (retires) sauverLignes(c.id, garde);
  return retires;
}
function ouvrirConfigurateur() {
  const c = chantiers.find(x => x.id === courantId);
  if (!c) return;
  const P = platDe(c), pieces = piecesDe(c);
  const opt = (liste, val) => `<option value="">— choisir —</option>` + liste.map(d => `<option ${d === val ? 'selected' : ''}>${esc(d)}</option>`).join('');
  const optPortes = () => `<option value="">— choisir —</option><option>${esc(PORTE_AUTO)}</option>` + platPortes().map(d => `<option>${esc(d)}</option>`).join('');
  const subListe = (items, i, cat, texte) => items.map((x, k) => `<div class="ouv"><span>${texte(x)}</span><button type="button" class="btn small danger" data-pldel="${i}:${cat}:${k}">✕</button></div>`).join('');
  const carte = (p, i) => {
    const eau = PLAT_EAU.test(p.type);
    return `<div class="sousbloc" style="padding:10px;margin:10px 0">
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
      <p class="muted" style="margin:10px 0 2px">Murs (linéaire brut, hauteur ${num(P.hauteur) ? num(P.hauteur) + ' m' : 'à saisir'})</p>
      ${subListe(p.cloisons || [], i, 'cloisons', x => `Cloison · ${esc(x.type)} · ${fmt(num(x.ml))} ml`)}
      <div class="row" style="margin-top:4px"><select id="pl_${i}_cloisons_type" style="flex:1">${opt(platCloisons())}</select><input id="pl_${i}_cloisons_ml" inputmode="decimal" placeholder="ml" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:cloisons">+ Cloison</button></div>
      ${subListe(p.doublages || [], i, 'doublages', x => `Doublage · ${esc(x.type)} · ${fmt(num(x.ml))} ml`)}
      <div class="row" style="margin-top:4px"><select id="pl_${i}_doublages_type" style="flex:1">${opt(platDoublages())}</select><input id="pl_${i}_doublages_ml" inputmode="decimal" placeholder="ml" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:doublages">+ Doublage</button></div>
      ${subListe(p.portes || [], i, 'portes', x => `Porte · ${esc(x.type)} · ${num(x.nb)} × ${fmt(num(x.largeur))} × ${fmt(num(x.hauteur))} m`)}
      <div class="row" style="margin-top:4px;flex-wrap:wrap"><select id="pl_${i}_portes_type" style="flex:1;min-width:180px">${optPortes()}</select><input id="pl_${i}_portes_nb" inputmode="numeric" placeholder="1" placeholder="Nb" style="width:60px"><input id="pl_${i}_portes_l" inputmode="decimal" placeholder="Larg. m" style="width:80px"><input id="pl_${i}_portes_h" inputmode="decimal" placeholder="Haut. m" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:portes">+ Porte</button></div>
      ${menusDe(p).length ? '<p class="muted" style="margin:10px 0 2px">Menuiseries extérieures de la pièce</p>' : ''}
      ${menusDe(p).map((x, k) => `<div class="ouv"><span>${esc(FICHE_OUV[x.type] || x.type)} · ${num(x.nb)} × ${fmt(num(x.largeur))} × ${fmt(num(x.hauteur))} m${x.materiau ? ' · ' + esc(FICHE_MAT[x.materiau]) + (finTxt(x.fin, x.ral) ? ' · ' + esc(finTxt(x.fin, x.ral)) : '') : ''}${x.appui ? ' · appui ' + esc(APPUI_LIB[x.appui] || x.appui) : ''}</span><span style="display:flex;gap:6px;flex:0 0 auto"><button type="button" class="btn small" data-valider-menu="${i}:${k}">Valider</button><button type="button" class="btn small danger" data-pldel="${i}:menus:${k}">✕</button></span></div>`).join('')}
      <div class="sousbloc" style="padding:8px;margin:8px 0"><strong style="display:block;margin-bottom:4px">Ajouter une menuiserie extérieure</strong>
        <label style="display:block;font-size:14px;margin:4px 0">Type</label><select id="pl_${i}_menus_type" style="width:100%">${Object.entries(FICHE_OUV).map(([k, t]) => `<option value="${k}">${t}</option>`).join('')}</select>
        <div class="row" style="gap:6px;flex-wrap:wrap"><div style="flex:1;min-width:90px"><label style="display:block;font-size:14px;margin:4px 0">Nombre</label><input id="pl_${i}_menus_nb" inputmode="numeric" placeholder="1"></div>
        <div style="flex:1;min-width:90px"><label style="display:block;font-size:14px;margin:4px 0">Largeur (m)</label><input id="pl_${i}_menus_l" inputmode="decimal" placeholder="ex. 1,20"></div>
        <div style="flex:1;min-width:90px"><label style="display:block;font-size:14px;margin:4px 0">Hauteur (m)</label><input id="pl_${i}_menus_h" inputmode="decimal" placeholder="ex. 1,35"></div></div>
        <label style="display:block;font-size:14px;margin:4px 0">Matériau</label><select id="pl_${i}_menus_mat" style="width:100%">${optionsListe(matsPour('ouvrant'), 'PVC')}</select>
        <label style="display:block;font-size:14px;margin:4px 0">Finition</label><select id="pl_${i}_menus_fin" style="width:100%">${optionsListe(finsPour('PVC'), 'std')}</select>
        <select id="pl_${i}_menus_ral" style="width:100%;display:none;margin-top:4px">${ralOptions('')}</select>
        <label style="display:block;font-size:14px;margin:4px 0">Volet</label><select id="pl_${i}_menus_volet" style="width:100%">${Object.entries(FICHE_VOLET).map(([k, t]) => `<option value="${k}">${t}</option>`).join('')}</select>
        <div id="pl_${i}_menus_volbox" style="display:none;border-left:3px solid #E07838;padding-left:8px;margin:4px 0">
          <label style="display:block;font-size:14px;margin:4px 0">Matériau du volet</label><select id="pl_${i}_menus_matvolet" style="width:100%">${optionsListe(matsPour('ouvrant'), 'alu')}</select>
          <label style="display:block;font-size:14px;margin:4px 0">Finition du volet</label><select id="pl_${i}_menus_finvolet" style="width:100%">${optionsListe(finsPour('alu'), 'std')}</select>
          <select id="pl_${i}_menus_ralvolet" style="width:100%;display:none;margin-top:4px">${ralOptions('')}</select>
        </div>
        <label style="display:block;font-size:14px;margin:4px 0">Appui de fenêtre</label><select id="pl_${i}_menus_appui" style="width:100%">${Object.entries(APPUI_LIB).map(([k, t]) => `<option value="${k}">${t}</option>`).join('')}</select>
        <div style="margin:6px 0"><label style="font-size:14px;margin-right:12px"><input type="checkbox" id="pl_${i}_menus_elec" style="width:auto;height:auto"> Volet roulant motorisé</label>
        <label style="font-size:14px;margin-right:12px"><input type="checkbox" id="pl_${i}_menus_securit" style="width:auto;height:auto"> Verre sécurit</label>
        <label style="font-size:14px"><input type="checkbox" id="pl_${i}_menus_opaque" style="width:auto;height:auto"> Verre opaque</label></div>
        <button type="button" class="btn sec small" data-pladd="${i}:menus">+ Ajouter cette menuiserie</button></div>
      ${subListe(p.ouvertures || [], i, 'ouvertures', x => `Ouverture libre · ${num(x.nb)} × ${fmt(num(x.largeur))} × ${fmt(num(x.hauteur))} m`)}
      <div class="row" style="margin-top:4px;flex-wrap:wrap"><span class="muted" style="flex:1;min-width:180px">Ouverture libre (passage)</span><input id="pl_${i}_ouvertures_nb" inputmode="numeric" placeholder="1" placeholder="Nb" style="width:60px"><input id="pl_${i}_ouvertures_l" inputmode="decimal" placeholder="Larg. m" style="width:80px"><input id="pl_${i}_ouvertures_h" inputmode="decimal" placeholder="Haut. m" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:ouvertures">+ Ouverture</button></div>
      ${subListe(p.placards || [], i, 'placards', x => `Placard · ${esc(x.type)} · ${num(x.nb)} × ${fmt(num(x.largeur))} × ${fmt(num(x.hauteur))} m`)}
      <div class="row" style="margin-top:4px;flex-wrap:wrap"><select id="pl_${i}_placards_type" style="flex:1;min-width:180px">${opt(platPlacards())}</select><input id="pl_${i}_placards_nb" inputmode="numeric" placeholder="1" placeholder="Nb" style="width:60px"><input id="pl_${i}_placards_l" inputmode="decimal" placeholder="Larg. m" style="width:80px"><input id="pl_${i}_placards_h" inputmode="decimal" placeholder="Haut. m" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:placards">+ Placard</button></div>
    </div>`;
  };
  const carteEquip = (p, i) => `<div class="sousbloc" style="padding:10px;margin:10px 0">
        <strong>${esc(nomPiece(p))}</strong>
      ${equipOptions(p).length ? `<p class="muted" style="margin:10px 0 2px">Équipements (nombre)</p>
      ${subListe(p.equip || [], i, 'equip', x => `${esc(x.type)} × ${num(x.nb)}`)}
      <div class="row" style="margin-top:4px;flex-wrap:wrap"><select id="pl_${i}_equip_type" style="flex:1;min-width:200px">${opt(equipOptions(p))}</select><input id="pl_${i}_equip_nb" inputmode="numeric" placeholder="1" placeholder="Nb" style="width:60px"><button type="button" class="btn sec small" data-pladd="${i}:equip">+ Équipement</button></div>` : ''}
    </div>`;
  $('cfgPieces').innerHTML = `<div class="bloc">${lotTitre('B. Liste des pièces de la maison (sans l\'équipement)')}
    <p class="muted">Saisissez chaque pièce une seule fois, avec ses murs, portes et placards en brut. Le calcul distingue seul les pièces d'eau d'après leur nom.</p>
    <label for="plH">Hauteur sous plafond (m)</label>
    <input id="plH" inputmode="decimal" value="${esc(P.hauteur)}" placeholder="ex. 2,50">
    <label style="display:flex;align-items:center;gap:8px;margin-top:8px;font-size:14px"><input type="checkbox" id="plPeint" ${P.peintPortes ? 'checked' : ''} style="width:auto;height:auto;margin:0"> Portes peintes sur place (sinon fournies prépeintes)</label>
    <h3 style="margin:14px 0 4px;font-size:15px">Ajouter une pièce</h3>
    <p class="muted" style="margin:0 0 8px">Remplissez les cases utiles, puis appuyez sur « Ajouter ou mettre à jour la pièce ». Une case vide reste vide : rien n'est calculé à sa place.</p>
    <div class="row" style="flex-wrap:wrap;gap:8px">
      <div style="flex:2;min-width:180px"><label for="plType" style="display:block;font-size:15px;font-weight:600;margin:6px 0 4px;color:var(--fg)">Type de pièce</label><select id="plType" style="width:100%"><option value="">— à choisir —</option>${Object.keys(ELEC_PIECE_TYPES).map(t => `<option>${esc(t)}</option>`).join('')}</select></div>
      <div style="flex:1;min-width:140px"><label for="plQual" style="display:block;font-size:15px;font-weight:600;margin:6px 0 4px;color:var(--fg)">Numéro ou nom (si plusieurs pièces du même type)</label><select id="plQual" style="width:100%">${ELEC_QUALIFS.map(q => `<option value="${esc(q)}">${q || '(aucun)'}</option>`).join('')}</select></div>
    </div>
    <div class="row" style="flex-wrap:wrap;gap:8px">
      <div style="flex:1;min-width:120px"><label for="plNb" style="display:block;font-size:15px;font-weight:600;margin:6px 0 4px;color:var(--fg)">Nombre de pièces identiques</label><input id="plNb" inputmode="numeric" placeholder="1"></div>
      <div style="flex:1;min-width:120px"><label for="plSurf" style="display:block;font-size:15px;font-weight:600;margin:6px 0 4px;color:var(--fg)">Surface (m²)</label><input id="plSurf" inputmode="decimal" placeholder="ex. 12"></div>
      <div style="flex:1;min-width:120px"><label for="plPerim" style="display:block;font-size:15px;font-weight:600;margin:6px 0 4px;color:var(--fg)">Périmètre (ml), facultatif</label><input id="plPerim" inputmode="decimal" placeholder="calculé si vide"></div>
    </div>
    <p class="muted" style="margin:10px 0 4px"><strong>Pièce rectangulaire ?</strong> Au lieu de la surface, vous pouvez saisir la longueur et la largeur : la surface (longueur × largeur) et le périmètre (2 × (longueur + largeur)) se calculent tout seuls. Exemple : 3 m sur 2 m donnent 6 m² et 10 ml.</p>
    <div class="row" style="flex-wrap:wrap;gap:8px">
      <div style="flex:1;min-width:120px"><label for="plL" style="display:block;font-size:15px;font-weight:600;margin:6px 0 4px;color:var(--fg)">Longueur (m)</label><input id="plL" inputmode="decimal"></div>
      <div style="flex:1;min-width:120px"><label for="plLa" style="display:block;font-size:15px;font-weight:600;margin:6px 0 4px;color:var(--fg)">Largeur (m)</label><input id="plLa" inputmode="decimal"></div>
    </div>
    <div style="margin-top:8px"><label for="plSol" style="display:block;font-size:15px;font-weight:600;margin:6px 0 4px;color:var(--fg)">Revêtement de sol</label><select id="plSol" style="width:100%">${opt(platSols())}</select></div>
    <div class="row" style="margin-top:10px"><button type="button" class="btn sec" id="plAjPiece">Ajouter ou mettre à jour la pièce</button></div>
    <h3 style="margin:14px 0 0;font-size:15px">Pièces et leurs murs</h3>
    ${pieces.map(carte).join('') || '<p class="muted">Aucune pièce.</p>'}
    </div>`;
  $('cfgEquip').innerHTML = `<div class="bloc">${lotTitre('13. Équipements')}
    <p class="muted">Équipements de chaque pièce (douche, lavabo, évier, lave-vaisselle…), saisis pièce par pièce.</p>
    ${pieces.filter(p => equipOptions(p).length).map(carteEquip).join('') || '<p class="muted">Aucune pièce ne reçoit d\'équipement pour le moment.</p>'}
    </div>`;
}
function sauverPlat(c) { lsSet('chantiers', chantiers); marquerChantier(c.id); synchroConfig(); }
// Mise à jour automatique du métré à partir du configurateur (électricité, plâtrerie, sanitaires, fiche projet)
let _synchroT = null;
function synchroConfig() {
  if (!courantId) return;
  clearTimeout(_synchroT);
  _synchroT = setTimeout(() => {
    majQuantitesAuto(chantiers.find(x => x.id === courantId));
    majLignesDepuisConfigurateur(chantiers.find(x => x.id === courantId));
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
  const cleL = l => l.ouvrage + '|' + l.designation;
  // Lignes venant du configurateur (les lignes saisies à la main ne sont jamais touchées)
  const estAuto = l => !!(l.projet || l.auto || l.plat || l.qteAuto);
  const dejaLa = l => existantes.some(x => x.uid === l.uid || (!estAuto(x) && cleL(x) === cleL(l)));
  const reste = {};
  for (const x of existantes) if (estAuto(x)) (reste[cleL(x)] = reste[cleL(x)] || []).push(x);
  const sig = v => ['nombre', 'cote1', 'cote2', 'cote3'].map(k => num(v && v[k])).join('|');
  const props = [], vus = new Set();
  for (const L of Object.values(col)) for (const l of L) {
    if (!l.ouvrage) continue;
    // Une ligne déjà présente dans le métré (même numéro) n'est pas une nouvelle proposition
    if (existantes.some(x => x.uid === l.uid)) continue;
    const cle = cleL(l);
    if (vus.has(cle + JSON.stringify(l.valeurs))) continue;
    vus.add(cle + JSON.stringify(l.valeurs));
    const ex = reste[cle] && reste[cle].shift();
    if (ex) {
      // Ligne déjà au métré : mise à jour seulement si la quantité ou les cotes ont changé
      if (sig(ex.valeurs) !== sig(l.valeurs) || Math.abs(num(ex.quantite) - num(l.quantite)) > 1e-9) props.push({ maj: ex, neuf: l });
      continue;
    }
    if (dejaLa(l)) continue;
    props.push({ neuf: l });
  }
  let h = `<h2 style="margin:0 0 6px;font-size:18px">Revue complète avant édition</h2>`;
  if (!props.length) {
    h += `<p class="muted">Rien à ajouter ni à mettre à jour : le métré correspond déjà au configurateur.</p>`;
  } else {
    h += `<p class="muted" style="font-size:13px">Cochez les lignes à ajouter ou à mettre à jour. Les lignes non cochées ne changent pas.</p>`;
    const par = {};
    props.forEach((it, i) => { (par[it.neuf.lot] = par[it.neuf.lot] || []).push([it, i]); });
    for (const [lot, items] of Object.entries(par)) {
      h += `<h3 style="font-size:14px;margin:12px 0 4px">${esc(libLot(lot))}</h3>`;
      for (const [it, i] of items) {
        const l = it.neuf;
        const libelle = it.maj
          ? `Mettre à jour : ${esc(l.designation)} <span class="muted">(${fmt(num(it.maj.quantite))} → ${fmt(num(l.quantite))} ${esc(l.unite)})</span>`
          : esc(l.designation);
        h += `<label style="display:flex;gap:8px;align-items:flex-start;padding:6px 0;border-bottom:1px solid #eee;font-size:14px">
          <input type="checkbox" data-rev="${i}" style="margin-top:3px"><span style="flex:1">${libelle}</span>
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
    // Mise à jour : la ligne existante garde sa place et son numéro, seules les valeurs changent
    const maj = new Map(coches.filter(it => it.maj).map(it => [it.maj.uid, it.neuf]));
    const L = lignesDe(courantId).map(x => maj.has(x.uid) ? Object.assign({}, maj.get(x.uid), { uid: x.uid, cree: x.cree }) : x)
      .concat(coches.filter(it => !it.maj).map(it => it.neuf));
    sauverLignes(courantId, L);
    renderMetre();
    fermer();
    if ($('cfgStatut')) $('cfgStatut').textContent = coches.length + ' ligne(s) ajoutée(s) ou mise(s) à jour au métré après revue.';
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
  else L.push(Object.assign(p, { equip: [], cloisons: [], doublages: [], portes: [], menus: [], ouvertures: [], placards: [] }));
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
    } else if (cat === 'menus') {
      const g = id => { const el = document.getElementById(pre + id); return el ? el.value.trim() : ''; };
      const ck = id => { const el = document.getElementById(pre + id); return !!(el && el.checked); };
      if (g('type') && g('l') && g('h')) {
        menusDe(p).push({ id: 'm' + uid(), type: g('type'), nb: g('nb') || '1', largeur: g('l'), hauteur: g('h'), materiau: g('mat'), fin: g('fin'), ral: g('ral'), volet: g('volet') || 'aucun', matvolet: g('matvolet'), finvolet: g('finvolet'), ralvolet: g('ralvolet'), electrique: ck('elec'), securit: ck('securit'), opaque: ck('opaque'), appui: g('appui') });
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
  const vm = e.target.closest('[data-valider-menu]');
  if (vm) {
    const [i, k] = vm.dataset.validerMenu.split(':').map(x => parseInt(x, 10));
    const pc = piecesDe(c)[i]; const m = pc && menusDe(pc)[k];
    if (m) { const msg = validerMenu(c, pc, m); $('cfgStatut').textContent = msg; }
    return;
  }
  const del = e.target.closest('[data-pldel]');
  if (del) {
    const parts = del.dataset.pldel.split(':');
    const L = piecesDe(c);
    if (parts.length === 1) { L.splice(parseInt(parts[0], 10), 1); retirerLignesSansSource(c); }
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
// Options qui dépendent du choix : matériau selon le type, finition selon le matériau, RAL selon la finition
if ($('vConfig')) $('vConfig').addEventListener('change', e => {
  const m = e.target.id && e.target.id.match(/^pl_(\d+)_menus_(type|mat|fin|volet|matvolet|finvolet|ral|ralvolet)$/);
  if (!m) return;
  const g = s => document.getElementById('pl_' + m[1] + '_menus_' + s);
  const ajuste = (sel, liste, defaut) => { const v = sel.value; sel.innerHTML = optionsListe(liste, liste.some(([k]) => k === v) ? v : defaut); };
  if (m[2] === 'type' || m[2] === 'mat') {
    ajuste(g('mat'), matsPour(g('type').value), 'PVC');
    ajuste(g('fin'), finsPour(g('mat').value), g('mat').value === 'bois' ? 'brut' : 'std');
  }
  if (m[2] === 'matvolet' || m[2] === 'finvolet') {
    ajuste(g('finvolet'), finsPour(g('matvolet').value), g('matvolet').value === 'bois' ? 'brut' : 'std');
  }
  if (m[2] === 'volet') g('volbox').style.display = g('volet').value === 'aucun' ? 'none' : '';
  if (m[2] === 'ral' || m[2] === 'fin' || m[2] === 'mat' || m[2] === 'type') g('ral').style.display = g('fin').value === 'ral' ? '' : 'none';
  if (m[2] === 'finvolet' || m[2] === 'matvolet' || m[2] === 'volet') g('ralvolet').style.display = g('finvolet').value === 'ral' ? '' : 'none';
});
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
const RAL_LISTE = [["RAL 1000", "Green beige"], ["RAL 1001", "Beige"], ["RAL 1002", "Sand yellow"], ["RAL 1003", "Signal yellow"], ["RAL 1004", "Golden yellow"], ["RAL 1005", "Honey yellow"], ["RAL 1006", "Maize yellow"], ["RAL 1007", "Daffodil yellow"], ["RAL 1011", "Brown beige"], ["RAL 1012", "Lemon yellow"], ["RAL 1013", "Oyster white"], ["RAL 1014", "Ivory"], ["RAL 1015", "Light ivory"], ["RAL 1016", "Sulfur yellow"], ["RAL 1017", "Saffron yellow"], ["RAL 1018", "Zinc yellow"], ["RAL 1019", "Grey beige"], ["RAL 1020", "Olive yellow"], ["RAL 1021", "Colza yellow"], ["RAL 1023", "Traffic yellow"], ["RAL 1024", "Ochre yellow"], ["RAL 1026", "Luminous yellow"], ["RAL 1027", "Curry"], ["RAL 1028", "Melon yellow"], ["RAL 1032", "Broom yellow"], ["RAL 1033", "Dahlia yellow"], ["RAL 1034", "Pastel yellow"], ["RAL 1035", "Pearl beige"], ["RAL 1036", "Pearl gold"], ["RAL 1037", "Sun yellow"], ["RAL 2000", "Yellow orange"], ["RAL 2001", "Red orange"], ["RAL 2002", "Blood orange"], ["RAL 2003", "Pastel orange"], ["RAL 2004", "Pure orange"], ["RAL 2005", "Luminous orange"], ["RAL 2007", "Luminous bright orange"], ["RAL 2008", "Bright red orange"], ["RAL 2009", "Traffic orange"], ["RAL 2010", "Signal orange"], ["RAL 2011", "Deep orange"], ["RAL 2012", "Salmon orange"], ["RAL 2013", "Pearl orange"], ["RAL 3000", "Flame red"], ["RAL 3001", "Signal red"], ["RAL 3002", "Carmine red"], ["RAL 3003", "Ruby red"], ["RAL 3004", "Purple red"], ["RAL 3005", "Wine red"], ["RAL 3007", "Black red"], ["RAL 3009", "Oxide red"], ["RAL 3011", "Brown red"], ["RAL 3012", "Beige red"], ["RAL 3013", "Tomato red"], ["RAL 3014", "Antique pink"], ["RAL 3015", "Light pink"], ["RAL 3016", "Coral red"], ["RAL 3017", "Rose"], ["RAL 3018", "Strawberry red"], ["RAL 3020", "Traffic red"], ["RAL 3022", "Salmon pink"], ["RAL 3024", "Luminous red"], ["RAL 3026", "Luminous bright red"], ["RAL 3027", "Raspberry red"], ["RAL 3028", "Pure red"], ["RAL 3031", "Orient red"], ["RAL 3032", "Pearl ruby red"], ["RAL 3033", "Pearl pink"], ["RAL 4001", "Red lilac"], ["RAL 4002", "Red violet"], ["RAL 4003", "Heather violet"], ["RAL 4004", "Claret violet"], ["RAL 4005", "Blue lilac"], ["RAL 4006", "Traffic purple"], ["RAL 4007", "Purple violet"], ["RAL 4008", "Signal violet"], ["RAL 4009", "Pastel violet"], ["RAL 4010", "Telemagenta"], ["RAL 4011", "Pearl violet"], ["RAL 4012", "Pearl blackberry"], ["RAL 5000", "Violet blue"], ["RAL 5001", "Green blue"], ["RAL 5002", "Ultramarine blue"], ["RAL 5003", "Sapphire blue"], ["RAL 5004", "Black blue"], ["RAL 5005", "Signal blue"], ["RAL 5007", "Brilliant blue"], ["RAL 5008", "Grey blue"], ["RAL 5009", "Azure blue"], ["RAL 5010", "Gentian blue"], ["RAL 5011", "Steel blue"], ["RAL 5012", "Light blue"], ["RAL 5013", "Cobalt blue"], ["RAL 5014", "Pigeon blue"], ["RAL 5015", "Sky blue"], ["RAL 5017", "Traffic blue"], ["RAL 5018", "Turquoise blue"], ["RAL 5019", "Capri blue"], ["RAL 5020", "Ocean blue"], ["RAL 5021", "Water blue"], ["RAL 5022", "Night blue"], ["RAL 5023", "Distant blue"], ["RAL 5024", "Pastel blue"], ["RAL 5025", "Pearl gentian"], ["RAL 5026", "Pearl night blue"], ["RAL 6000", "Patina green"], ["RAL 6001", "Emerald green"], ["RAL 6002", "Leaf green"], ["RAL 6003", "Olive green"], ["RAL 6004", "Blue green"], ["RAL 6005", "Moss green"], ["RAL 6006", "Grey olive"], ["RAL 6007", "Bottle green"], ["RAL 6008", "Brown green"], ["RAL 6009", "Fir green"], ["RAL 6010", "Grass green"], ["RAL 6011", "Reseda green"], ["RAL 6012", "Black green"], ["RAL 6013", "Reed green"], ["RAL 6014", "Yellow olive"], ["RAL 6015", "Black olive"], ["RAL 6016", "Turquoise green"], ["RAL 6017", "May green"], ["RAL 6018", "Yellow green"], ["RAL 6019", "Pastel green"], ["RAL 6020", "Chromium green"], ["RAL 6021", "Pale green"], ["RAL 6022", "Brown olive"], ["RAL 6024", "Traffic green"], ["RAL 6025", "Fern green"], ["RAL 6026", "Opal green"], ["RAL 6027", "Light green"], ["RAL 6028", "Pine green"], ["RAL 6029", "Mint green"], ["RAL 6031", "Bronze green"], ["RAL 6032", "Signal green"], ["RAL 6033", "Mint turquoise"], ["RAL 6034", "Pastel turquoise"], ["RAL 6035", "Pearl green"], ["RAL 6036", "Pearl opal green"], ["RAL 6037", "Pure green"], ["RAL 6038", "Luminous green"], ["RAL 6039", "Fibrous green"], ["RAL 7000", "Squirrel grey"], ["RAL 7001", "Silver grey"], ["RAL 7002", "Olive grey"], ["RAL 7003", "Moss grey"], ["RAL 7004", "Signal grey"], ["RAL 7005", "Mouse grey"], ["RAL 7006", "Beige grey"], ["RAL 7008", "Khaki grey"], ["RAL 7009", "Green grey"], ["RAL 7010", "Tarpaulin grey"], ["RAL 7011", "Iron grey"], ["RAL 7012", "Basalt grey"], ["RAL 7013", "Brown grey or NATO olive"], ["RAL 7015", "Slate grey"], ["RAL 7016", "Anthracite grey"], ["RAL 7021", "Black grey"], ["RAL 7022", "Umbra grey"], ["RAL 7023", "Concrete grey"], ["RAL 7024", "Graphite grey"], ["RAL 7026", "Granite grey"], ["RAL 7030", "Stone grey"], ["RAL 7031", "Blue grey"], ["RAL 7032", "Pebble grey"], ["RAL 7033", "Cement grey"], ["RAL 7034", "Yellow grey"], ["RAL 7035", "Light grey"], ["RAL 7036", "Platinum grey"], ["RAL 7037", "Dusty grey"], ["RAL 7038", "Agate grey"], ["RAL 7039", "Quartz grey"], ["RAL 7040", "Window grey"], ["RAL 7042", "Traffic grey A"], ["RAL 7043", "Traffic grey B"], ["RAL 7044", "Silk grey"], ["RAL 7045", "Telegrey 1"], ["RAL 7046", "Telegrey 2"], ["RAL 7047", "Telegrey 4"], ["RAL 7048", "Pearl mouse grey"], ["RAL 8000", "Green brown"], ["RAL 8001", "Ochre brown"], ["RAL 8002", "Signal brown"], ["RAL 8003", "Clay brown"], ["RAL 8004", "Copper brown"], ["RAL 8007", "Fawn brown"], ["RAL 8008", "Olive brown"], ["RAL 8011", "Nut brown"], ["RAL 8012", "Red brown"], ["RAL 8014", "Sepia brown"], ["RAL 8015", "Chestnut brown"], ["RAL 8016", "Mahogany brown"], ["RAL 8017", "Chocolate brown"], ["RAL 8019", "Grey brown"], ["RAL 8022", "Black brown"], ["RAL 8023", "Orange brown"], ["RAL 8024", "Beige brown"], ["RAL 8025", "Pale brown"], ["RAL 8028", "Terra brown"], ["RAL 8029", "Pearl copper"], ["RAL 9001", "Cream"], ["RAL 9002", "Grey white"], ["RAL 9003", "Signal white"], ["RAL 9004", "Signal black"], ["RAL 9005", "Jet black"], ["RAL 9006", "White aluminium"], ["RAL 9007", "Grey aluminium"], ["RAL 9010", "Pure white"], ["RAL 9011", "Graphite black"], ["RAL 9012", "Clean room white"], ["RAL 9016", "Traffic white"], ["RAL 9017", "Traffic black"], ["RAL 9018", "Papyrus white"], ["RAL 9022", "Pearl light grey"], ["RAL 9023", "Pearl dark grey"]];
// Matériaux possibles selon le type (le coulissant n'existe pas en bois)
function matsPour(type) {
  return type === 'coulissant' ? [['PVC', 'PVC'], ['alu', 'Aluminium']] : [['PVC', 'PVC'], ['alu', 'Aluminium'], ['bois', 'Bois']];
}
// Finitions : bois = brut, teinté ou RAL ; PVC / alu = standard (blanc) ou RAL
function finsPour(mat) {
  return mat === 'bois' ? [['brut', 'Bois brut'], ['teinte', 'Bois teinté'], ['ral', 'Couleur RAL']] : [['std', 'Standard (blanc)'], ['ral', 'Couleur RAL']];
}
function optionsListe(liste, val) { return liste.map(([k, t]) => `<option value="${k}" ${k === val ? 'selected' : ''}>${t}</option>`).join(''); }
function ralOptions(val) { return '<option value="">— choisir la couleur —</option>' + RAL_LISTE.map(([k, t]) => `<option value="${k}" ${k === val ? 'selected' : ''}>${k} · ${t}</option>`).join(''); }
// Texte ajouté à la désignation et à l'affichage : finition et couleur RAL
function finTxt(fin, ral) {
  if (fin === 'brut') return 'bois brut';
  if (fin === 'teinte') return 'bois teinté';
  if (fin === 'ral') return ral ? ral : 'couleur RAL à choisir';
  return '';
}
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
const DES_MASSIF = 'Fouille pour puits ou massif de fondation';
const DES_SEMELLE_ISO = 'Semelles isolées en béton armé';
const DES_PLATEFORME = 'Fouille en pleine masse (dallage, plateforme)';
const DES_DIVERS = 'Fouille pour trou divers';
const FICHE_FONDS_DEF = { largeur: '', hauteur: '' };

// Types de murs proposés : élévations de la bibliothèque, puis murs de soutènement et muret
function typesMurs() {
  const elev = [...new Set(BIB.ouvrages.filter(o => !o.supprime && o.qte === 'elev_net').map(o => o.designation))];
  return elev.concat(SOUT_TYPES.map(t => t.designation));
}
function projetDe(c) {
  if (!c.projet) c.projet = { epaisseur: '', murs: [], ouvertures: [], toiture: { type: '', surface: '', pente: '', couverture: '' }, choix: { murs: '', tableaux: '', finition: '' }, fond: Object.assign({}, FICHE_FONDS_DEF) };
  if (!c.projet.fond) c.projet.fond = Object.assign({}, FICHE_FONDS_DEF);
  if (!c.projet.equip) c.projet.equip = {};
  // Ancienne liste séparée des murs de soutènement : reprise dans la liste « Murs » (une seule liste)
  if (Array.isArray(c.projet.soutenement)) {
    for (const s of c.projet.soutenement) c.projet.murs.push({ id: 'm' + uid(), nom: 'Mur ' + (c.projet.murs.length + 1), longueur: s.longueur || '', hauteur: s.hauteur || '', porteur: false, type: (SOUT_TYPES.find(t => t.id === s.type) || SOUT_TYPES[0]).designation, deduire: false });
    delete c.projet.soutenement;
  }
  if (!c.projet.cuisine) c.projet.cuisine = { bas: '', haut: '', plan: '', plan_ml: '' };
  if (!c.projet.chantier) c.projet.chantier = { eau: '', elec: '', base: '', grue: '', bennes: '', bennesTri: '' };
  if (c.projet.choix.finition === undefined) c.projet.choix.finition = '';
  if (!c.projet.soub) c.projet.soub = { hauteur: '' };
  if (!c.projet.terrain) c.projet.terrain = { surface: '', perimetre: '' };
  if (!c.projet.plancher) c.projet.plancher = { type: '', surface: '', ep: '', retombee: '', portee: '', entraxe: '' };
  return c.projet;
}
// Calculs : murs moins ouvertures de plus de 1,50 m², tableaux (2 côtés × hauteur × épaisseur),
// toiture développée, fondations (murs porteurs × dimensions de la semelle et de la fouille)
const APPUI_LIB = { '': 'Pas d\'appui', 'beton': 'Béton', 'beton-pierre': 'Béton ton pierre', 'alu': 'Aluminium', 'acier': 'Acier laqué 75/100e' };
// Valider une menuiserie : ses lignes entrent directement dans le métré (sans passer par la revue)
function validerMenu(c, pc, m) {
  const lieu = nomPiece(pc);
  const dims = `${fmt(num(m.largeur))} × ${fmt(num(m.hauteur))} m`;
  _revueCollecte = {};
  let col;
  try { ficheVersMetre(); } finally { col = _revueCollecte; _revueCollecte = null; }
  const propres = (col[c.id] || []).filter(l => l.lot === 'menuiseries-exterieures' && (
    (l.designation.startsWith(lieu + ' – ' + FICHE_OUV[m.type]) && l.designation.includes(dims)) ||
    (l.designation.endsWith(' – ' + lieu) && (m.volet === 'battant' || m.volet === 'roulant'))));
  const L = lignesDe(c.id);
  const dejaLa = l => L.some(x => x.uid === l.uid || (x.ouvrage === l.ouvrage && x.designation === l.designation));
  const nouvelles = propres.filter(l => !dejaLa(l));
  if (!propres.length) return 'Cette menuiserie ne donne aucune ligne : vérifiez le type, la largeur et la hauteur.';
  if (!nouvelles.length) return 'Cette menuiserie est déjà dans le métré.';
  sauverLignes(c.id, L.concat(nouvelles));
  renderMetre();
  return nouvelles.length + ' ligne(s) de la menuiserie ajoutée(s) au métré.';
}
function piecesCourantes() {
  const c = chantiers.find(x => x.id === courantId);
  return c ? piecesDe(c) : [];
}
function projetCalcul(p) {
  const r = { murs: [], brut: 0, deduit: 0, net: 0, tableaux: 0, ouvs: [], toiture: 0, linP: 0, linSoub: 0, soubS: 0, semelle: 0, fouille: 0 };
  // Épaisseur du mur fini : moyenne des murs périphériques, pondérée par leur longueur
  let sEp = 0, sLong = 0;
  for (const m of p.murs) {
    const brut = surfaceMur(m);
    r.murs.push({ m, brut, ded: 0 });
    r.brut += brut;
    if (m.cat === 'soub') r.linSoub += num(m.longueur);
    else if (m.porteur !== false) r.linP += num(m.longueur);
    if ((m.cat || 'peri') === 'peri' && num(m.epMur) > 0 && num(m.longueur) > 0) { sEp += num(m.epMur) * num(m.longueur); sLong += num(m.longueur); }
  }
  const e = sLong > 0 ? sEp / sLong / 100 : 0;
  r.epMoy = e;
  // Menuiseries rattachées aux pièces : chacune compte pour son nombre (nb × pièces identiques)
  for (const x of menusCalcul(piecesCourantes())) {
    const aire = num(x.m.largeur) * num(x.m.hauteur);
    const tab = 2 * num(x.m.hauteur) * e * x.nb;
    if (aire >= SEUIL_DEDUCTION) r.deduit += aire * x.nb;
    r.tableaux += tab;
    r.ouvs.push({ o: { nom: nomPiece(x.piece) + ' · ' + FICHE_OUV[x.m.type] }, aire, tab, deduit: aire >= SEUIL_DEDUCTION, nb: x.nb });
  }
  // Ouvertures : déduites seulement des murs dont la case « Déduire les ouvertures » est cochée, au prorata de leur surface
  const cochés = r.murs.filter(x => x.m.deduire === true);
  const brutCochés = cochés.reduce((a, x) => a + x.brut, 0);
  for (const x of cochés) x.menu = brutCochés > 0 ? Math.min(x.brut, r.deduit * x.brut / brutCochés) : 0;
  r.deduitMenuiseries = r.deduit;
  // Ouverture libre (m²) : s'ajoute à la part des menuiseries, sans règle de seuil
  for (const x of r.murs) x.ded = Math.min(x.brut, (x.menu || 0) + Math.max(0, num(x.m.ouvLibre)));
  r.deduit = r.murs.reduce((a, x) => a + x.ded, 0);
  r.net = Math.max(0, r.brut - r.deduit);
  // Surfaces nettes : soubassement à part, élévation par type de mur (sans type = choix du chantier), finitions par mur
  r.parType = {}; r.parSoub = {}; r.parFin = {};
  for (const x of r.murs) {
    const net = x.brut - x.ded;
    const k = x.m.type || '';
    if (x.m.cat === 'soub') { r.parSoub[k] = (r.parSoub[k] || 0) + net; r.soubS += net; }
    else r.parType[k] = (r.parType[k] || 0) + net;
    if (x.m.finition && net > 0) r.parFin[x.m.finition] = (r.parFin[x.m.finition] || 0) + net;
  }
  const pente = num(p.toiture.pente);
  const S = num(p.toiture.surface);
  // Surface de couverture saisie (3D) : utilisée telle quelle ; sinon calcul à partir de la surface au sol et de la pente
  r.toiture = num(p.toiture.surfCouv) > 0 ? num(p.toiture.surfCouv) : (pente > 0 ? S / Math.cos(Math.atan(pente / 100)) : S);
  const f = p.fond || FICHE_FONDS_DEF;
  // Si des rigoles sont saisies (bloc Terrassement), leur linéaire, largeur et HT servent aux semelles et fouilles
  const rig = num(f.rigLin) > 0;
  r.fondLin = rig ? num(f.rigLin) : r.linP;
  r.fdimLarg = rig && num(f.rigLarg) > 0 ? num(f.rigLarg) : num(f.largeur);
  r.fdimProf = num(f.rigHt);  // hauteur de fouille = HT de la rigole
  // Hauteur de semelle : avec des rigoles, c'est la HT du terrassement (hauteur de fouille).
  r.semHaut = rig && num(f.rigHt) > 0 ? num(f.rigHt) : num(f.hauteur);
  r.semelle = r.fondLin * r.fdimLarg * r.semHaut;
  r.fouille = r.fondLin * r.fdimLarg * r.fdimProf;
  // Soubassement : murs porteurs × hauteur du soubassement
  // Plancher bas
  const pl = p.plancher || {};
  r.plS = num(pl.surface);
  r.hourdis = 0; r.dalleC = 0; r.solives = 0;
  if (pl.type === 'hourdis') { r.hourdis = r.plS; r.dalleC = r.plS * num(pl.ep) / 100; }
  if (pl.type === 'solivage' && r.plS > 0 && num(pl.portee) > 0) {
    // Solives parallèles à la portée : nombre = largeur / entraxe + 1, longueur = portée
    const largeurPerp = r.plS / num(pl.portee);
    const ent = num(pl.entraxe);
    r.nbSol = ent > 0 ? Math.ceil(largeurPerp / ent) + 1 : 0;
    r.solives = r.nbSol * num(pl.portee);
  }
  return r;
}
// Grandeurs calculées à partir du dessin (fiche projet et configurateur), utilisées par les ouvrages « qte »
// Dimensions des semelles filantes = dimensions de la fouille en tranchée validée dans le métré (terrassement)
function semellesDuTerrassement(c) {
  // Dimensions lues directement dans le configurateur (rigoles du terrassement), sans passer par le métré
  const p = projetDe(c), r = projetCalcul(p);
  if (!(num((p.fond || {}).rigLin) > 0)) return { sem_lin: '', sem_larg: '', sem_haut: '', fond_semelle: 0 };
  const L = r.fondLin, W = r.fdimLarg, H = r.fdimProf;
  return { sem_lin: L, sem_larg: W, sem_haut: H, fond_semelle: L * W * H };
}
// Proposition de quantité pour un type de fouille : seulement s'il n'y en a qu'une (jamais de somme de plusieurs fouilles)
function uneSeuleFouille(fd, usage, valide, valeur) {
  const e = fouilleUnique(fd, usage, valide);
  return e ? valeur(e) : 0;
}
function fouilleUnique(fd, usage, valide) {
  const es = pleinesDe(fd).filter(e => e.usage === usage && valide(e));
  return es.length === 1 ? es[0] : null;
}
function ctxQuantites(c) {
  const p = projetDe(c), r = projetCalcul(p), pieces = piecesDe(c);
  const rigOk = num((p.fond || {}).rigLin) > 0;
  const surfPieces = pieces.reduce((a, x) => a + num(x.surf) * (num(x.nb) || 1), 0);
  return {
    surface_terrain: num(p.terrain.surface),
    perimetre_terrain: num(p.terrain.perimetre),
    surface_facades: r.brut,
    murs_par_type: Object.assign({}, r.parType || {}),
    surface_plancher: r.plS > 0 ? r.plS : surfPieces,
    surface_pieces: surfPieces,
    surface_emprise: r.plS > 0 ? r.plS : surfPieces,
    surface_soubassement: r.soubS,
    surface_toiture: r.toiture,
    surface_toiture_plan: num(p.toiture.surface),
    ml_egout: num(p.toiture.egout),
    ml_rive: num(p.toiture.rive),
    // Menuiseries : appuis de fenêtre = largeur des fenêtres (ouvrant, oscillo, coulissant ; pas les portes)
    ...appuisCtx(chantiers.find(x => x.id === courantId)),
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
    // Fouilles et semelles : seulement si des rigoles sont saisies dans le terrassement (sinon rien n'est proposé)
    fond_fouille: rigOk ? r.fouille : '',
    // Semelles isolées : nombre de massifs de fondation saisis dans le terrassement (0 = aucun, rien n'est proposé)
    semi_nb: uneSeuleFouille(p.fond, 'massif', e => num(e.nb) > 0 && num(e.L) > 0 && num(e.l) > 0 && num(e.h) > 0, e => num(e.nb)),
    // Volumes des fouilles en pleine masse saisies dans le configurateur (pour proposer la quantité dans le métré)
    massif_m3: uneSeuleFouille(p.fond, 'massif', e => num(e.nb) > 0 && num(e.L) > 0 && num(e.l) > 0 && num(e.h) > 0, e => num(e.nb) * num(e.L) * num(e.l) * num(e.h)),
    massif_dims: (() => { const e = fouilleUnique(p.fond, 'massif', e => num(e.nb) > 0 && num(e.L) > 0 && num(e.l) > 0 && num(e.h) > 0);
      return e ? { nb: num(e.nb), L: num(e.L), l: num(e.l), h: num(e.h) } : null; })(),
    plat_m3: uneSeuleFouille(p.fond, 'plateforme', e => num(e.s) > 0 && num(e.h) > 0, e => num(e.s) * num(e.h)),
    fond_lin: rigOk ? r.fondLin : '', fond_larg: rigOk ? r.fdimLarg : '', fond_prof: rigOk ? r.fdimProf : '',
    // Semelles filantes : reprises UNIQUEMENT de la ligne « Fouilles en tranchée » déjà validée dans le métré (terrassement).
    // Sans cette ligne, rien n'est proposé : la saisie demande les dimensions.
    ...semellesDuTerrassement(c),
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
    charpente_variante: p.toiture.charpente === 'fermette' ? (p.toiture.type || '') + '|' + penteBande(p)
      : (p.toiture.charpente === 'traditionnelle' ? 'traditionnelle' : 'aucune'),
    toit_type: p.toiture.type || '',
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
// Mention affichée dans le détail du métré pour une quantité calculée par le configurateur
const SRC_QTE = {
  surface_terrain: 'surface du terrain', surface_facades: 'surface des façades', surface_plancher: 'surface de plancher',
  surface_pieces: 'surface des pièces', surface_emprise: 'emprise au sol', surface_soubassement: 'surface du soubassement',
  surface_toiture: 'surface de toiture (pente comprise)', surface_toiture_plan: 'surface de toiture (projection)',
  elev_net: 'murs, surface nette', finit_net: 'surface nette des murs',
  soub_s: 'murs de soubassement', plan_hourdis: 'plancher à hourdis', plan_dalle: 'dalle de compression (surface × épaisseur)',
  fond_semelle: 'semelles filantes (linéaire × largeur × hauteur)', cuve_fouille: 'fouille de la cuve',
  cuve_remblai: 'remblai de la cuve', cuve_evac: 'évacuation des terres de la cuve',
  massif_m3: 'fouilles pour massifs de fondation (terrassement)', plat_m3: 'fouilles en pleine masse, plateforme (terrassement)'
};
const SRC_SURF = new Set(['surface_terrain', 'surface_facades', 'surface_plancher', 'surface_pieces', 'surface_emprise',
  'surface_soubassement', 'surface_toiture', 'surface_toiture_plan']);
// Quantités données directement en surface ou en volume dans le configurateur (pas de calcul à partir de L, l, h)
const SRC_PLAN = new Set(['plat_m3']);
function srcTxt(qte) {
  if (qte === 'decap_m2' || SRC_SURF.has(qte) || SRC_PLAN.has(qte)) return TXT_SURFACE;
  return 'Calcul du configurateur : ' + (SRC_QTE[qte] || 'quantité calculée');
}
function qteValeur(o, ctx) {
  if (!o || !o.qte || ctx[o.qte] === undefined) return null;
  // Variante : l'ouvrage ne vaut que si la condition de la fiche est remplie (si : égal, sin : différent)
  // Murs typés : l'ouvrage se remplit avec la surface nette des murs de ce type
  if (o.si && o.si.cle === 'murs_choix' && ctx.murs_par_type && ctx.murs_par_type[o.si.val] !== undefined) {
    const surf = ctx.murs_par_type[o.si.val];
    if (!(surf > 0)) return null;
    return { nombre: '1', cote1: surf.toFixed(2), cote2: '1', src: srcTxt('elev_net'), typeMur: o.si.val };
  }
  if (o.si && String(ctx[o.si.cle]) !== String(o.si.val)) return null;
  if (o.sin && String(ctx[o.sin.cle]) === String(o.sin.val)) return null;
  const v = ctx[o.qte];
  if (!(v > 0)) return null;
  // Massif : calcul à partir de nombre, longueur, largeur, hauteur (affichés dans le détail, sans libellé)
  if (o.qte === 'massif_m3') { const d = ctx.massif_dims; return d ? { nombre: String(d.nb), cote1: String(d.L), cote2: String(d.l), cote3: String(d.h) } : null; }
  if (o.qte === 'fond_fouille') return { nombre: '1', cote1: String(ctx.fond_lin), cote2: String(ctx.fond_larg), cote3: String(ctx.fond_prof) };
  // Semelles isolées : même détail que le massif de fondation (nombre, longueur, largeur, hauteur)
  if (o.qte === 'semi_nb') { const d = ctx.massif_dims; return d ? { nombre: String(d.nb), cote1: String(d.L), cote2: String(d.l), cote3: String(d.h) } : null; }
  if (o.qte === 'fond_semelle') return { nombre: '1', cote1: String(ctx.sem_lin), cote2: String(ctx.sem_larg), cote3: String(ctx.sem_haut) };
  if (o.unite === 'm²' && SRC_SURF.has(o.qte) || o.qte === 'decap_m2') return { nombre: '1', cote1: v.toFixed(2), cote2: '1', mode: 'plan', src: srcTxt(o.qte) };
  if (o.unite === 'm²' && SRC_QTE[o.qte]) return { nombre: '1', cote1: v.toFixed(2), cote2: '1', src: srcTxt(o.qte) };
  if (o.unite === 'm³' && SRC_QTE[o.qte]) return { nombre: '1', cote1: v.toFixed(3), cote2: '1', cote3: '1', src: srcTxt(o.qte) };
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
  const garde = [];
  for (const l of L) {
    if (!l.qteAuto) { garde.push(l); continue; }
    const o = BIB.ouvrages.find(x => x.id === l.ouvrage);
    // Ouvrage supprimé de la bibliothèque : la ligne issue du configurateur est retirée de ce chantier
    if (o && o.supprime) { change = true; continue; }
    const valeurs = qteValeur(o, ctx);
    if (!valeurs) {
      // Plus de source dans le configurateur (mur supprimé, finition changée, valeur effacée) : la ligne issue du configurateur est retirée
      if (o) { change = true; continue; }
      garde.push(l); continue;
    }
    const avant = JSON.stringify([l.valeurs, l.quantite]);
    l.valeurs = valeurs;
    l.quantite = calcul(o, valeurs);
    if (JSON.stringify([l.valeurs, l.quantite]) !== avant) change = true;
    garde.push(l);
  }
  if (change) sauverLignes(courantId, garde);
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
// Murs de la bibliothèque (lot gros œuvre) : parois en m²
function ficheListeMurGO() {
  return BIB.ouvrages.filter(o => !o.supprime && o.unite === 'm²' && o.lot === 'gros-oeuvre' && /mur|élévation/i.test(o.designation) && !/hydrofuge|membrane|étanchéité|enduit|drainage/i.test(o.designation))
    .map(o => o.designation).filter((d, i, t) => t.indexOf(d) === i);
}
// Finitions : recherche dans toute la bibliothèque (m²)
function ficheListeFinition() {
  return BIB.ouvrages.filter(o => !o.supprime && o.unite === 'm²' && /enduit|bardage|crépi|peinture|lasure|revêtement|parement|plaque|placo|papier|tapisserie|lambris|vêture|finition/i.test(o.designation) && !/carrelage|faïence|doublage/i.test(o.designation))
    .map(o => o.designation).filter((d, i, t) => t.indexOf(d) === i);
}
// Protections des murs enterrés (soubassement) : toute la bibliothèque (m²)
function ficheListeProtection() {
  return BIB.ouvrages.filter(o => !o.supprime && o.unite === 'm²' && /hydrofuge|membrane|étanchéité|drainage|enterré|protection/i.test(o.designation))
    .map(o => o.designation).filter((d, i, t) => t.indexOf(d) === i);
}
// Surface nette d'un mur : rectangle (longueur × hauteur), ou pignon (triangle : base = linéaire, hauteur = linéaire/2 × pente)
// Demi-pignon : la moitié d'un pignon (toit monopente)
function surfaceMur(m) {
  if (m.cat === 'pignon') {
    const L = num(m.longueur), h = (L / 2) * num(m.pente) / 100;
    return (num(m.nb) + num(m.nbDemi) / 2) * (L / 2) * h;
  }
  return num(m.longueur) * num(m.hauteur);
}
function lotTitre(t) { return `<h2 class="lot-titre">${t}</h2>`; }
// Fouilles en pleine masse : liste (plusieurs lignes possibles). Ancien choix unique converti.
function pleinesDe(fd) {
  if (!Array.isArray(fd.pleines)) {
    fd.pleines = fd.pleine ? [{ id: 'p1', usage: fd.pleine, nb: fd.massifNb || '', L: fd.massifL || '', l: fd.massifLarg || '', h: fd.massifH || '' }] : [];
    delete fd.pleine; delete fd.massifNb; delete fd.massifL; delete fd.massifLarg; delete fd.massifH;
  }
  return fd.pleines;
}
function ficheRendre() {
  const c = chantiers.find(x => x.id === courantId); if (!c) return;
  const p = projetDe(c);
  const sel = (opts, val) => opts.map(([v, t]) => `<option value="${esc(v)}" ${v === val ? 'selected' : ''}>${esc(t)}</option>`).join('');
  const optListe = (liste, val) => `<option value="" ${!val ? 'selected' : ''}>— choisir —</option>` + liste.map(d => `<option value="${esc(d)}" ${d === val ? 'selected' : ''}>${esc(d)}</option>`).join('');
  const carte = (titre, contenu, src) => `<section ${src ? `data-source="${src}"` : ''} class="sousbloc" style="padding:12px;margin-bottom:12px"><h3 style="margin:0 0 8px;font-size:16px">${titre}</h3>${contenu}</section>`;
  const champ = (lib, html) => `<div style="min-width:0"><label style="display:block;margin:6px 0 4px;font-size:15px;color:var(--fg);font-weight:600">${lib}</label>${html}</div>`;
  const inp = (attrs, val, w) => `<input ${attrs} value="${esc(val ?? '')}" style="width:${w || '100%'};padding:10px;border:1px solid var(--mut);border-radius:8px;background:var(--card);color:var(--fg);font-size:16px">`;
  const sel2 = (attrs, opts, val) => `<select ${attrs} style="width:100%;padding:6px;border:1px solid #c9b8dc;border-radius:6px">${sel(opts, val)}</select>`;

  const optListe2 = (liste, sel, vide) => `<option value="">${vide}</option>` + liste.map(t => `<option value="${esc(t)}" ${sel === t ? 'selected' : ''}>${esc(t)}</option>`).join('');
  const rangeMur = m => {
    const id = `data-k="mur" data-id="${m.id}"`;
    const pig = m.cat === 'pignon', soub = m.cat === 'soub', refend = m.cat === 'refend';
    const selMat = `<select ${id} data-champ="type" style="width:100%;padding:6px">${optListe2(ficheListeMurGO(), m.type || '', '— choisir le mur de la bibliothèque —')}</select>`;
    const selFin = refend ? '' : `<select ${id} data-champ="finition" style="width:100%;padding:6px">${soub ? optListe2(ficheListeProtection(), m.finition || '', 'Sans protection') : optListe2(ficheListeFinition(), m.finition || '', 'Sans finition')}</select>`;
    const dimensions = pig
      ? `<div style="display:grid;grid-template-columns:2fr 1fr 1fr 1fr auto;gap:6px;align-items:end">
          ${champ('Nom', inp(`${id} data-champ="nom"`, m.nom))}
          ${champ('Linéaire (m)', inp(`${id} data-champ="longueur" inputmode="decimal"`, m.longueur))}
          ${champ('Pente (%)', inp(`${id} data-champ="pente" inputmode="decimal"`, m.pente))}
          ${champ('Nombre de pignons', inp(`${id} data-champ="nb" inputmode="numeric"`, m.nb))}
          <button type="button" class="btn small danger" data-action="delmur" data-id="${m.id}">✕</button></div>
         ${champ('Nombre de demi-pignons (toit monopente)', inp(`${id} data-champ="nbDemi" inputmode="numeric"`, m.nbDemi, '160px'))}`
      : `<div style="display:grid;grid-template-columns:2fr 1fr 1fr auto;gap:6px;align-items:end">
          ${champ('Nom', inp(`${id} data-champ="nom"`, m.nom))}
          ${champ('Longueur (m)', inp(`${id} data-champ="longueur" inputmode="decimal"`, m.longueur))}
          ${champ('Hauteur (m)', inp(`${id} data-champ="hauteur" inputmode="decimal"`, m.hauteur))}
          <button type="button" class="btn small danger" data-action="delmur" data-id="${m.id}">✕</button></div>`;
    return `<div style="border-bottom:1px solid var(--line);padding-bottom:8px;margin-bottom:8px">
      ${dimensions}
      <div style="display:grid;grid-template-columns:1fr 1fr;gap:6px;margin-top:6px">
        ${champ('Mur (bibliothèque, lot gros œuvre)', selMat)}
        ${refend ? '' : champ(soub ? 'Protection des murs enterrés' : 'Finition', selFin)}
      </div>
      <div style="display:flex;gap:14px;flex-wrap:wrap;align-items:end;margin-top:6px;font-size:13px">
        <label><input type="checkbox" ${id} data-champ="deduire" ${m.deduire === true ? 'checked' : ''}> Déduire les menuiseries extérieures</label>
        ${m.cat === 'peri' || !m.cat ? champ('Épaisseur du mur fini (cm)', inp(`${id} data-champ="epMur" inputmode="decimal" placeholder="ex. 35"`, m.epMur, '120px')) : ''}
        ${champ('Ouverture libre (m²)', inp(`${id} data-champ="ouvLibre" inputmode="decimal"`, m.ouvLibre, '120px'))}
      </div></div>`;
  };
  const blocMurs = cat => p.murs.filter(m => (m.cat || 'peri') === cat).map(rangeMur).join('')
    || '<p style="color:#6b5a7a;margin:0">Aucun mur.</p>';
  const ajouterMur = (cat, texte) => `<button type="button" class="btn sec" data-action="addmur" data-cat="${cat}" style="margin-top:6px">${texte}</button>`;
  const menusResume = (() => {
    const pcs = piecesDe(c).filter(x => menusDe(x).length);
    const lignes = pcs.map(pc => `<p style="margin:8px 0 2px"><strong>${esc(nomPiece(pc))}</strong></p>` + menusDe(pc).map(m => `<div class="ouv" style="font-size:14px;min-height:0;padding:6px 0">${esc(FICHE_OUV[m.type] || m.type)} · ${num(m.nb)} × ${fmt(num(m.largeur))} × ${fmt(num(m.hauteur))} m · ${esc(FICHE_MAT[m.materiau] || 'matériau à choisir')}${finTxt(m.fin, m.ral) ? ' · ' + esc(finTxt(m.fin, m.ral)) : ''} · appui ${esc(APPUI_LIB[m.appui] || 'à choisir')}</div>`).join('')).join('');
    const anciennes = p.ouvertures.length ? `<p style="color:#b42318;font-weight:600;margin:10px 0 2px">À rattacher à une pièce (pas encore comptées dans le métré) :</p>` + p.ouvertures.map(o => `<div class="ouv" style="font-size:14px;min-height:0;padding:6px 0">${esc(o.nom)} · ${esc(FICHE_OUV[o.type] || o.type)} · ${num(o.largeur)} × ${num(o.hauteur)} m <button type="button" class="btn small danger" data-action="delouv" data-id="${o.id}">Supprimer</button></div>`).join('') : '';
    return (lignes || '<p class="muted">Aucune menuiserie saisie. Saisissez-les dans chaque pièce, bloc B.</p>') + anciennes;
  })();
  const toit = p.toiture;
  const plat = toit.type === 'plat';
  const choix = (attrs, entries, val) => sel2(attrs, [CHOIX_VIDE, ...entries], val || '');
  const lot = (t) => `<h2 style="margin:20px 0 8px;padding:8px 12px;border-radius:10px;background:var(--acc);color:#fff;font-size:17px">${t}</h2>`;
  const contenuCharp = `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
            ${champ('Type de toiture', choix('data-k="toit" data-champ="type"', Object.entries(FICHE_TOIT), toit.type))}
            ${champ('Surface au sol couverte (m²)', inp('data-k="toit" data-champ="surface" inputmode="decimal"', toit.surface))}
            ${champ('Surface de couverture (m², pente comprise, prise dans la 3D) — facultatif', inp('data-k="toit" data-champ="surfCouv" inputmode="decimal" placeholder="calculée si vide"', toit.surfCouv || ''))}
            ${champ(plat ? 'Pente (%), minimum 3,5 %' : 'Pente (%)', inp('data-k="toit" data-champ="pente" inputmode="decimal"' + (plat ? ' placeholder="minimum 3,5"' : ' placeholder="ex. 30"'), toit.pente))}
            ${champ('Charpente', choix('data-k="toit" data-champ="charpente"', Object.entries(FICHE_CHARP), toit.charpente))}
            ${champ('Écran de sous-toiture', choix('data-k="toit" data-champ="ecran"', Object.entries(FICHE_ECRAN), toit.ecran))}
    </div>`;
  const contenuIso = `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
      ${champ('Isolation de toiture', choix('data-k="toit" data-champ="isoToit"', Object.entries(FICHE_ISO_TOIT), toit.isoToit))}
    </div><p style="font-size:12px;color:#6b5a7a;margin:6px 0 0">Les autres isolations se choisissent dans le métré.</p>`;
  const contenuCouv = `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
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
    </div>`;
  const eq = p.equip || {};
  const EQ_GRP = {
    elec: ['portail_moto', 'nb_portail', 'borne', 'alarme', 'visio', 'nb_eclairage'],
    plomb: ['eau_chaude', 'thermo_type', 'thermo_litres', 'thermo_gaine', 'thermo_liaison', 'adouc', 'cuve', 'cuve_pose', 'cuve_litres', 'cuve_reseau', 'cuve_tranchee', 'piscine', 'anc', 'anc_epand'],
    chauf: ['vmc', 'poele', 'poele_conduit', 'poele_air', 'chauffage', 'plancher', 'radiateurs', 'nb_rad', 'nb_seche', 'clim', 'clim_grp', 'nb_clim', 'clim_gaine']
  };
  const rendreEq = g => EQ_SEL.filter(x => EQ_GRP[g].includes(x[0])).map(([k, lib, opts]) => champ(lib, choix(`data-k="equip" data-champ="${k}"`, opts, eq[k]))).join('')
    + EQ_NUM.filter(x => EQ_GRP[g].includes(x[0])).map(([k, lib]) => champ(lib, inp(`data-k="equip" data-champ="${k}" inputmode="decimal"`, eq[k]))).join('')
    + (g === 'chauf' && (eq.poele === 'bois' || eq.poele === 'granules') ? champ('Hauteur du conduit, du poêle à la sortie de toit (m)', inp('data-k="equip" data-champ="poeleHaut" inputmode="decimal"', eq.poeleHaut)) : '');
  const contenuElec = `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">${rendreEq('elec')}</div>`;
  const contenuPlomb = `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">${rendreEq('plomb')}</div>`;
  const contenuChauf = `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">${rendreEq('chauf')}</div>
    <div class="muted" style="font-size:12px;margin-top:6px">Un ouvrage n'est proposé que si son équipement est choisi ici. Un champ vide ne crée rien. La ventilation primaire est toujours prévue.</div>`;
  const fd = p.fond;
  // Longueur des semelles : calculée (pas saisie), à partir des rigoles si elles sont renseignées, sinon des murs porteurs
  const lonSemelles = projetCalcul(p).fondLin;
  const rigoleActive = num(fd.rigLin) > 0;
  // Avec des rigoles, longueur, largeur et hauteur viennent du bloc Terrassement : pas de champ en double ici.
  // Règle : pas de semelle filante béton armé sans fouille en rigole (bloc 1 Terrassement).
  const contenuFond = rigoleActive ? '' : `<p style="font-size:13px;color:#6b5a7a;margin:0">Pas de semelles filantes sans fouille en rigole : renseignez d'abord le linéaire, la largeur et la HT dans le bloc 1 Terrassement.</p>
`; const contenuRig = `    <p style="font-size:13px;margin:10px 0 4px"><strong>Fouilles en rigoles (linéaire saisi à la main)</strong></p>
    <p style="font-size:12px;color:#6b5a7a;margin:0 0 8px">Sans linéaire de rigoles, il n'y a ni fouille ni semelles filantes dans le gros œuvre. La largeur et la HT saisies ici servent aux semelles et à la fouille.</p>
    <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(150px,1fr));gap:6px">
      ${champ('Linéaire de rigoles (ml)', inp('data-k="fond" data-champ="rigLin" inputmode="decimal"', fd.rigLin || ''))}
      ${champ('HT, hauteur de fouille (m)', inp('data-k="fond" data-champ="rigHt" inputmode="decimal"', fd.rigHt || ''))}
      ${champ('Largeur de la rigole (m)', inp('data-k="fond" data-champ="rigLarg" inputmode="decimal"', fd.rigLarg || ''))}
    </div>
    <p style="font-size:13px;margin:12px 0 4px"><strong>Fouilles en pleine masse</strong></p>
    <p style="font-size:12px;color:#6b5a7a;margin:0 0 4px">Ajoutez une ligne par fouille. Pour un massif, le nombre crée aussi les semelles isolées du gros œuvre.</p>
    ${pleinesDe(fd).map(e => `<div ${(e.usage || 'massif') === 'massif' ? 'data-source="massif_m3"' : ''} style="border:1px solid #e0c9a6;border-radius:8px;padding:8px;margin-top:6px;background:#fff">
      ${champ('Usage', `<select data-k="pleine" data-id="${esc(e.id)}" data-champ="usage" style="width:100%">${[['plateforme', 'Plateforme / dallage'], ['massif', 'Massif de fondation'], ['divers', 'Trou divers (ex. cuve)']].map(([v, l]) => `<option value="${v}"${(e.usage || 'massif') === v ? ' selected' : ''}>${l}</option>`).join('')}</select>`)}
      <div style="display:grid;grid-template-columns:repeat(auto-fit,minmax(110px,1fr));gap:6px;margin-top:6px">
        ${(e.usage || 'massif') === 'plateforme'
          ? champ('Surface (m²)', inp(`data-k="pleine" data-id="${esc(e.id)}" data-champ="s" inputmode="decimal"`, e.s || ''))
            + champ('Hauteur (m)', inp(`data-k="pleine" data-id="${esc(e.id)}" data-champ="h" inputmode="decimal"`, e.h || ''))
          : champ('Nombre (massifs)', inp(`data-k="pleine" data-id="${esc(e.id)}" data-champ="nb" inputmode="decimal"`, e.nb || ''))
            + champ('Longueur (m)', inp(`data-k="pleine" data-id="${esc(e.id)}" data-champ="L" inputmode="decimal"`, e.L || ''))
            + champ('Largeur (m)', inp(`data-k="pleine" data-id="${esc(e.id)}" data-champ="l" inputmode="decimal"`, e.l || ''))
            + champ('Hauteur (m)', inp(`data-k="pleine" data-id="${esc(e.id)}" data-champ="h" inputmode="decimal"`, e.h || ''))}
      </div>
      <button type="button" class="btn small danger" data-action="delpleine" data-id="${esc(e.id)}" style="margin-top:6px">✕ Supprimer cette fouille</button>
    </div>`).join('')}
    <button type="button" class="btn sec" data-action="addpleine" style="margin-top:8px">+ Ajouter une fouille en pleine masse</button>
    </div>`;
  const contenuPlancher = (() => {
    const pl = p.plancher;
    return `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
      ${champ('Type de plancher', sel2('data-k="plan" data-champ="type"', [CHOIX_VIDE, ['hourdis', 'Hourdis avec dalle de compression'], ['solivage', 'Solivage bois']], pl.type || ''))}
      ${champ('Surface du plancher (m²)', inp('data-k="plan" data-champ="surface" inputmode="decimal"', pl.surface))}
      ${pl.type === 'hourdis' ? champ('Épaisseur de la dalle de compression (cm)', inp('data-k="plan" data-champ="ep" inputmode="decimal" placeholder="ex. 4"', pl.ep)) : ''}
      ${pl.type === 'solivage' ? champ('Retombée des solives (mm)', sel2('data-k="plan" data-champ="retombee"', [CHOIX_VIDE, ['145', '145 mm'], ['175', '175 mm'], ['220', '220 mm']], pl.retombee || '')) : ''}
      ${pl.type === 'solivage' ? champ('Portée des solives (m)', inp('data-k="plan" data-champ="portee" inputmode="decimal"', pl.portee || '')) : ''}
      ${pl.type === 'solivage' ? champ('Entraxe des solives (m)', inp('data-k="plan" data-champ="entraxe" inputmode="decimal" placeholder="ex. 0,60"', pl.entraxe || '')) : ''}
    </div><p style="font-size:12px;color:#6b5a7a;margin:6px 0 0">${pl.type === 'solivage'
      ? 'Solivage : OSB 9 mm en fond, isolant entre solives (épaisseur = retombée), OSB 21 mm support de revêtement de sol.'
      : 'Hourdis : plancher à poutrelles et hourdis, avec dalle de compression en béton.'}</p>`;
  })();
  $('cfgFiche').innerHTML = `<div class="bloc">${lotTitre('A. Terrain')}
    ${carte('Terrain et accès', `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
      <div style="grid-column:1/-1;display:flex;gap:8px;align-items:flex-end;flex-wrap:wrap"><div style="flex:1;min-width:220px">${champ('Référence du dossier Kanban', inp('data-k="kref" placeholder="ex. 003-02-2026"', refKanbanDe(c), '100%'))}</div></div>
      ${champ('Surface du terrain (m²)', inp('data-k="terr" data-champ="surface" inputmode="decimal"', p.terrain.surface))}
      ${champ('Périmètre du terrain (ml)', inp('data-k="terr" data-champ="perimetre" inputmode="decimal"', p.terrain.perimetre))}
      ${champ('Surface à décaper (m²)', inp('data-k="terr" data-champ="decap" inputmode="decimal"', p.terrain.decap || ''))}
      ${champ('Longueur eau potable (ml)', inp('data-k="terr" data-champ="resEau" inputmode="decimal"', p.terrain.resEau || ''))}
      ${champ('Longueur eaux usées (ml)', inp('data-k="terr" data-champ="resEu" inputmode="decimal"', p.terrain.resEu || ''))}
      ${champ('Longueur eaux pluviales (ml)', inp('data-k="terr" data-champ="resEp" inputmode="decimal"', p.terrain.resEp || ''))}
      ${champ('Longueur électricité (ml)', inp('data-k="terr" data-champ="resElec" inputmode="decimal"', p.terrain.resElec || ''))}
    </div><p style="font-size:12px;color:#6b5a7a;margin:6px 0 0">Sert à la clôture et aux protections du chantier.</p>`)}
    </div>`;
  surfaceAuto(c);
  $('cfgFicheSuite').innerHTML = `    <div class="bloc">${lotTitre('0. Installation de chantier')}
    ${carte('Installation de chantier (forfaits à ajouter ou non)', champ('Branchement provisoire d\'eau', `<select data-k="chant" data-champ="eau" style="width:100%;padding:6px">${['', 'oui', 'non'].map(v => `<option value="${v}" ${(p.chantier.eau || '') === v ? 'selected' : ''}>${{ '': '— à choisir —', oui: 'Oui', non: 'Non' }[v]}</option>`).join('')}</select>`)
      + champ('Branchement provisoire d\'électricité', `<select data-k="chant" data-champ="elec" style="width:100%;padding:6px">${['', 'oui', 'non'].map(v => `<option value="${v}" ${(p.chantier.elec || '') === v ? 'selected' : ''}>${{ '': '— à choisir —', oui: 'Oui', non: 'Non' }[v]}</option>`).join('')}</select>`)
      + champ('Base de vie (bungalow ou conteneur)', `<select data-k="chant" data-champ="base" style="width:100%;padding:6px">${['', 'oui', 'non'].map(v => `<option value="${v}" ${(p.chantier.base || '') === v ? 'selected' : ''}>${{ '': '— à choisir —', oui: 'Oui', non: 'Non' }[v]}</option>`).join('')}</select>`)
      + champ('Grue de chantier', `<select data-k="chant" data-champ="grue" style="width:100%;padding:6px">${['', 'oui', 'non'].map(v => `<option value="${v}" ${(p.chantier.grue || '') === v ? 'selected' : ''}>${{ '': '— à choisir —', oui: 'Oui', non: 'Non' }[v]}</option>`).join('')}</select>`)
      + champ('Nombre de bennes à gravats', inp('data-k="chant" data-champ="bennes" inputmode="numeric"', p.chantier.bennes, '120px'))
      + champ('Nombre de bennes à déchets triés', inp('data-k="chant" data-champ="bennesTri" inputmode="numeric"', p.chantier.bennesTri, '120px')))}
    </div>
    <div class="bloc">${lotTitre('1. Terrassement')}
    ${carte('Fouilles en rigoles (linéaire saisi à la main)', contenuRig, 'fond_fouille')}
    </div>
    <div class="bloc">${lotTitre('2. Gros œuvre + matériaux de finition')}
    ${carte('Murs de soubassement (mur au-dessus des fondations)', blocMurs('soub') + ajouterMur('soub', '+ Ajouter un mur de soubassement'))}
    ${carte('Murs périphériques', blocMurs('peri') + ajouterMur('peri', '+ Ajouter un mur périphérique'))}
    ${carte('Murs de refend (sans finition)', blocMurs('refend') + ajouterMur('refend', '+ Ajouter un mur de refend'))}
    ${carte('Murs pignons (demi-pignons pour les toits monopente)', blocMurs('pignon') + ajouterMur('pignon', '+ Ajouter un mur pignon'))}
    ${rigoleActive ? '' : carte('Fondations', contenuFond)}
    ${carte('Plancher bas', contenuPlancher)}
    ${carte('Matériaux (utilisés dans le métré)', champ('Matériau des murs (élévation)', `<select data-k="choix" data-champ="murs" style="width:100%;padding:6px">${optListe(ficheListeMur(), p.choix.murs)}</select>`)
      + champ('Tableaux de menuiseries', `<select data-k="choix" data-champ="tableaux" style="width:100%;padding:6px">${optListe(ficheListeMur(), p.choix.tableaux)}</select>`))}
    </div>
    <div class="bloc">${lotTitre('3. Charpente')}
    ${carte('Toiture : type, surfaces et charpente', contenuCharp)}
    </div>
    <div class="bloc">${lotTitre('4. Couverture')}
    ${carte('Couverture, égouts, faîtage, gouttières, descentes', contenuCouv)}
    </div>
    <div class="bloc">${lotTitre('5. Menuiserie extérieure')}
    ${carte('Menuiseries extérieures : résumé (lecture seule, à saisir dans chaque pièce, bloc B)', menusResume)}
    </div>
    <div class="bloc">${lotTitre('6. Isolation')}
    ${carte('Isolation', contenuIso)}
    </div>
    <div class="bloc">${lotTitre('7. Plâtrerie')}
    ${carte('Cloisons et doublages', '<p class="muted">Les cloisons et doublages se saisissent pièce par pièce, dans le bloc B.</p>')}
    </div>
    <div class="bloc">${lotTitre('8. Électricité')}
    ${carte('Équipements électriques et extérieurs', contenuElec)}
    </div>
    <div class="bloc">${lotTitre('9. Plomberie sanitaire')}
    ${carte('Équipements sanitaires, eau chaude, cuves, assainissement', contenuPlomb)}
    </div>
    <div class="bloc">${lotTitre('10. Revêtements de sol')}
    ${carte('Revêtements de sol', '<p class="muted">Le revêtement de chaque pièce se choisit dans le bloc B, menu « Sol » de la pièce.</p>')}
    </div>
    <div class="bloc">${lotTitre('11. Chauffage, VMC, climatisation')}
    ${carte('Chauffage, ventilation, climatisation', contenuChauf)}
    </div>
    <div class="bloc">${lotTitre('12. Cuisine')}
    ${carte('Cuisine (linéaires et plan de travail)', champ('Meubles bas (ml)', inp('data-k="cuis" data-champ="bas" inputmode="decimal"', p.cuisine.bas, '160px'))
      + champ('Meubles hauts (ml)', inp('data-k="cuis" data-champ="haut" inputmode="decimal"', p.cuisine.haut, '160px'))
      + champ('Plan de travail', `<select data-k="cuis" data-champ="plan" style="width:100%;padding:6px">${['', 'stratifie', 'quartz'].map(v => `<option value="${v}" ${(p.cuisine.plan || '') === v ? 'selected' : ''}>${{ '': '— à choisir —', stratifie: 'Stratifié', quartz: 'Quartz' }[v]}</option>`).join('')}</select>`)
      + champ('Longueur du plan de travail (ml)', inp('data-k="cuis" data-champ="plan_ml" inputmode="decimal"', p.cuisine.plan_ml, '160px')))}
    </div>
`;
  $('cfgResultats').innerHTML = `<div class="bloc">${carte('Résultats des calculs', '<div id="ficheResume"></div>')}</div>`;
  ficheResume();
}
function ficheResume() {
  const c = chantiers.find(x => x.id === courantId); if (!c || !$('ficheResume')) return;
  const p = projetDe(c), r = projetCalcul(p);
  const ligne = (a, b, gras) => `<tr><td style="padding:4px 0;${gras ? 'font-weight:700' : ''}">${a}</td><td style="text-align:right;padding:4px 0;${gras ? 'font-weight:700;color:#6a1b9a' : ''}">${b}</td></tr>`;
  $('ficheResume').innerHTML = `<table style="width:100%;border-collapse:collapse">
    ${ligne('Murs (longueur × hauteur)', fmt(r.brut) + ' m²')}
    ${ligne('Ouvertures de plus de 1,50 m² déduites', '− ' + fmt(r.deduit) + ' m²')}
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
  else if (k === 'pleine') { const e = pleinesDe(p.fond).find(x => x.id === t.dataset.id); if (e) e[champ] = val; }
  else if (k === 'soub') p.soub[champ] = val;
  else if (k === 'terr') p.terrain[champ] = val;
  else if (k === 'plan') p.plancher[champ] = val;
  else if (k === 'choix') p.choix[champ] = val;
  else if (k === 'equip') { p.equip = p.equip || {}; p.equip[champ] = val; }
  else if (k === 'cuis') p.cuisine[champ] = val;
  else if (k === 'chant') p.chantier[champ] = val;
  else if (k === 'kref') { c.kanbanRef = String(val).trim(); sauverFiche(c); surfaceAuto(c); }
  sauverFiche(c);
  const refaire = (k === 'equip' && champ === 'poele') || (k === 'ouv' && ['volet', 'type'].includes(champ)) || (k === 'toit' && champ === 'type') || (k === 'plan' && champ === 'type') || (k === 'pleine' && champ === 'usage');
  if (refaire) ficheRendre(); else ficheResume();
}
// Lecture seule du Kanban : même adresse que le Kanban utilise pour lire ses dossiers
const KANBAN_LECTURE = 'https://script.google.com/macros/s/AKfycbwLGYVnT9HvYgLJNzEP1QCa8b-BQw18eZ0vse2hXixZT4LwrFv3-bt4X4i--gX8eqDoKw/exec';
// Référence Kanban : celle saisie, sinon celle du client Kanban choisi pour ce métré
function refKanbanDe(c) { return (c.kanbanRef || (c.client && c.client.ref) || '').toString().trim(); }
// Surface reprise automatiquement, une seule fois par dossier, et seulement si la surface est encore vide
const _surfEssayee = {};
function surfaceAuto(c) {
  const ref = refKanbanDe(c);
  if (!ref || projetDe(c).terrain.surface || _surfEssayee[c.id + '|' + ref]) return;
  _surfEssayee[c.id + '|' + ref] = true;
  kanbanSurface(c, true);
}
function kanbanSurface(c, silencieux) {
  const msg = t => { if (!silencieux && $('cfgStatut')) $('cfgStatut').textContent = t; };
  const ref = refKanbanDe(c);
  if (!ref) { msg('Saisissez d\'abord la référence du dossier Kanban (ex. 003-02-2026).'); return; }
  msg('Lecture du Kanban…');
  fetch(KANBAN_LECTURE).then(r => r.json()).then(db => {
    const card = [...(db.cards || []), ...(db.archived || [])].find(x => x.ref === ref);
    if (!card) { msg('Aucun dossier Kanban avec la référence ' + ref + '.'); return; }
    if (projetDe(c).terrain.surface) return;
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
  if (a === 'addmur') {
    const cat = b.dataset.cat || 'peri';
    const nomCat = { soub: 'Mur de soubassement', peri: 'Mur périphérique', refend: 'Mur de refend', pignon: 'Mur pignon' }[cat];
    p.murs.push({ id: 'm' + uid(), cat, nom: nomCat + ' ' + (p.murs.length + 1), longueur: '', hauteur: cat === 'soub' ? (p.soub.hauteur || '') : '', pente: '', nb: '', nbDemi: '', porteur: true, type: '', finition: '', ouvLibre: '', deduire: false });
  }
  else if (a === 'delmur') p.murs = p.murs.filter(m => m.id !== b.dataset.id);
  else if (a === 'delouv') p.ouvertures = p.ouvertures.filter(o => o.id !== b.dataset.id);
  else if (a === 'addpleine') pleinesDe(p.fond).push({ id: 'p' + uid(), usage: 'massif', nb: '', L: '', l: '', h: '' });
  else if (a === 'delpleine') p.fond.pleines = pleinesDe(p.fond).filter(e => e.id !== b.dataset.id);
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
  const ajouter = (des, q, designation, valeursFixes, src) => {
    if (!des) { if (q > 0) manquants.push('(choix non fait)'); return; }
    const o = BIB.ouvrages.find(x => !x.supprime && x.designation === des);
    if (!o) { manquants.push(des); return; }
    if (!(q > 0)) return;
    const valeurs = valeursFixes || valeursPour(o.unite, q);
    if (src && (o.unite === 'm²' || o.unite === 'm³')) valeurs.src = 'Calcul du configurateur : ' + src;
    ajouterLotSiAbsent(courantId, o.lot);
    L.push({ uid: uid(), lot: o.lot, ouvrage: o.id, designation: designation || o.designation, unite: o.unite,
             valeurs, quantite: calcul(o, valeurs), surface: null, prix: 'moyen', projet: true, cree: new Date().toISOString(),
             qteAuto: o.qte === 'fond_semelle' ? 'fond_semelle' : undefined });
    nb++;
  };
  // Fondations : uniquement si des fouilles en rigole sont saisies dans le terrassement
  const fdim = p.fond || FICHE_FONDS_DEF;
  // Fouilles en pleine masse (plateforme, massifs, trous divers) : indépendantes des rigoles
  for (const e of pleinesDe(fdim)) {
    const L_ = num(e.L), l_ = num(e.l), h_ = num(e.h), n_ = num(e.nb);
    const dims = { cote1: String(L_), cote2: String(l_), cote3: String(h_) };
    if (e.usage === 'massif') {
      if (!(n_ > 0 && L_ > 0 && l_ > 0 && h_ > 0)) continue;
      ajouter(DES_MASSIF, n_ * L_ * l_ * h_, undefined, { nombre: String(n_), ...dims });
      ajouter(DES_SEMELLE_ISO, n_, undefined, { nombre: String(n_), ...dims });  // une ligne par massif, reprend son détail
    } else if (e.usage === 'plateforme') {
      const S_ = num(e.s), H_ = num(e.h), N_ = 1;  // plateforme : toujours 1, pas de nombre
      if (S_ > 0 && H_ > 0) ajouter(DES_PLATEFORME, N_ * S_ * H_, undefined, { nombre: String(N_), cote1: String(S_), cote2: '1', cote3: String(H_), src: TXT_SURFACE });
    } else if (e.usage === 'divers') {
      if (L_ > 0 && l_ > 0 && h_ > 0) ajouter(DES_DIVERS, L_ * l_ * h_, undefined, { nombre: '1', ...dims });
    }
  }
  // Semelles filantes et fouilles en tranchée : seulement si des rigoles sont saisies
  if (!(num(fdim.rigLin) > 0)) { /* pas de semelles filantes sans terrassement en rigole */ } else {
  ajouter(DES_FOND_FOUILLE, r.fouille, 'Fouilles en tranchée pour semelles filantes',
    { nombre: '1', cote1: String(r.fondLin), cote2: String(r.fdimLarg), cote3: String(r.fdimProf) });
  // OUV-0040 reprend automatiquement les cotes de la ligne OUV-0008 (fouille) si elle existe
  const sf = semellesDuTerrassement(c);
  const cotesSem = sf.sem_lin > 0 ? { cote1: String(sf.sem_lin), cote2: String(sf.sem_larg), cote3: String(sf.sem_haut) }
    : { cote1: String(r.fondLin), cote2: String(r.fdimLarg), cote3: String(r.semHaut) };
  ajouter(DES_FOND_SEMELLE, r.semelle, 'Semelles filantes en béton armé',
    { nombre: '1', ...cotesSem });
  }
  // Soubassement : chaque mur avec son matériau ; solin en tête sur son linéaire
  for (const [t, surf] of Object.entries(r.parSoub || {})) {
    if (!(surf > 0)) continue;
    if (!t) { manquants.push('Matériau du mur de soubassement'); continue; }
    ajouter(t, surf, t, null, SRC_QTE.soub_s);
  }
  ajouter('Solin en aluminium fixé en tête de mur de soubassement', r.linSoub, 'Solin aluminium fixé en tête de soubassement');
  // Plancher bas
  if (p.plancher.type === 'hourdis' && r.plS > 0) {
    ajouter('Plancher à poutrelles et hourdis béton d\'étage', r.hourdis, 'Plancher à hourdis avec dalle de compression', null, SRC_QTE.plan_hourdis);
    ajouter('Dalle de compression béton armé (sur hourdis)', r.dalleC, 'Dalle de compression ' + num(p.plancher.ep) + ' cm', null, SRC_QTE.plan_dalle);
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
  // Une ligne par type de mur ; les murs sans type prennent le « Matériau des murs » du chantier
  for (const [t, surf] of Object.entries(r.parType || {})) {
    if (!(surf > 0)) continue;
    if (t === '') {
      if (!p.choix.murs) { manquants.push('Type de mur (ou choix du matériau des murs)'); continue; }
      ajouter(p.choix.murs, surf, 'Élévation des murs (surface nette)', { nombre: '1', cote1: surf.toFixed(2), cote2: '1', src: 'Calcul du configurateur : ' + SRC_QTE.elev_net, typeMur: '' }, null);
    } else {
      ajouter(t, surf, t, { nombre: '1', cote1: surf.toFixed(2), cote2: '1', src: 'Calcul du configurateur : ' + SRC_QTE.elev_net, typeMur: t }, null);
    }
  }
  // Finitions et protections choisies mur par mur (surface nette de chaque mur)
  for (const [f, surf] of Object.entries(r.parFin || {})) if (surf > 0) ajouter(f, surf, f, null, SRC_QTE.finit_net);
  if (!(r.epMoy > 0) && menusCalcul(c).length) manquants.push('Épaisseur du mur fini (murs périphériques) pour les tableaux');
  ajouter(p.choix.tableaux, r.tableaux, 'Tableaux de menuiseries (2 côtés)', null, 'épaisseur du mur × hauteur des ouvertures');
  if (p.toiture.type === 'plat') { if (p.toiture.etancheite) ajouter(ETANCH_DESIG[p.toiture.etancheite], r.toiture, 'Étanchéité de la partie courante du toit plat', null, SRC_QTE.surface_toiture); }
  else if (couvDe(p.toiture)) ajouter(COUV_DESIG[couvDe(p.toiture)], r.toiture, undefined, null, SRC_QTE.surface_toiture);
  for (const x of menusCalcul(c)) {
    const o = x.m, q = x.nb, lieu = nomPiece(x.piece);
    const dims = `${fmt(num(o.largeur))} × ${fmt(num(o.hauteur))} m`;
    const opts = [o.securit ? 'verre sécurit' : '', o.opaque ? 'verre opaque' : ''].filter(Boolean).join(', ');
    const ouv = MENU_DESIG[o.type] && MENU_DESIG[o.type][o.materiau];
    const finM = finTxt(o.fin, o.ral);
    ajouter(ouv, q, `${lieu} – ${FICHE_OUV[o.type]} ${FICHE_MAT[o.materiau]}${finM ? ' ' + finM : ''} ${dims}${opts ? ' – ' + opts : ''}`);
    const finV = finTxt(o.finvolet, o.ralvolet), matV = FICHE_MAT[o.matvolet || 'alu'] + (finV ? ' ' + finV : '');
    if (o.volet === 'battant') ajouter(VOLET_DESIG['battant-' + (o.matvolet || 'alu')], q, `Volet battant ${matV} – ${lieu}`);
    if (o.volet === 'roulant') {
      ajouter(VOLET_DESIG.roulant, q, `Volet roulant ${matV} – ${lieu}`);
      if (o.electrique) ajouter(ALIM_VOLET, q, `Alimentation volet roulant – ${lieu}`);
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

// Surface du configurateur déjà comptée au métré : même ouvrage ou même source, même quantité, même type de mur
function doublonConfig(o, q, srcAjout, typeAjout) {
  return lignesDe(courantId).find(x => Math.abs(num(x.quantite) - num(q)) < 1e-9
    && (x.lien || x.projet || x.lienDe || (x.valeurs || {}).src)
    && (!(x.valeurs || {}).typeMur || (x.valeurs || {}).typeMur === (typeAjout || ''))
    && (x.ouvrage === o.id || (!!srcAjout && srcAjout !== TXT_SURFACE && (x.valeurs || {}).src === srcAjout))) || null;
}
function ouvrirOuvrage(o, precedent, message) {
  const champs = champsDe(o);
  const cc = chantiers.find(x => x.id === courantId);
  const auto = !precedent && cc ? qteValeur(o, ctxQuantites(cc)) : null;
  // Cases de cotes vierges : la quantité proposée par le configurateur (déjà calculée) est utilisée si rien n'est saisi
  // Cases remplies seulement avec ce que le configurateur fournit : dimensions (fouille), surface (plan) ou quantité
  // Dimensions du configurateur (fouille) ou surface (plan) : reprises. Total calculé : cases vides, la quantité est proposée.
  const dimsConfig = !!auto && (o.qte === 'fond_fouille' || o.qte === 'fond_semelle' || o.qte === 'massif_m3' || o.qte === 'semi_nb' || auto.mode === 'plan');
  const compte = !auto ? {} : dimsConfig ? { ...auto } : auto.src ? (auto.cote1 != null ? { cote1: auto.cote1 ?? '', cote2: auto.cote2 ?? '', cote3: auto.cote3 ?? '' } : auto.nombre != null ? { nombre: auto.nombre } : {}) : (o.unite === 'u' || o.unite === 'forfait') ? { nombre: auto.nombre } : { cote1: auto.cote1 };
  // Ouvrage lié : cotes reprises de la dernière ligne de l'ouvrage source (dans ce chantier)
  let compteLie = null;
  if ((o.liePar || o.lieConfig) && !precedent) compteLie = coteSource(o, courantId, null);
  if (o.cotes && !precedent) {
    const vc = valeursCotes(o, chantiers.find(x => x.id === courantId));
    if (Object.keys(vc).length) compteLie = Object.assign({}, compteLie || {}, vc);
  }
  const v = precedent || compteLie || compte;
  let h = `<h2 style="margin:0 0 4px;font-size:18px">${esc(o.designation)}</h2>`
    + (auto ? `<div class="ok" style="margin-top:8px">Quantité proposée depuis le configurateur${auto.src ? ' : ' + esc(auto.src.replace(/^Calcul suivant plan : |^Calcul du configurateur : |^Surface du configurateur : /, '')) : ' (' + esc(o.qte.replace(/_/g, ' ')) + ')'}. Modifiez-la si besoin : la ligne ne sera plus recalculée.</div>` : '');
  h += `
    <div class="muted">${esc(libLot(o.lot))} · unité : ${esc(o.unite)}</div>`;
  if (o.rappel) h += `<div class="card" style="margin:10px 0 0;background:#fdf4ee;border-color:#E07838"><strong style="font-size:13px">Rappel de mesure</strong><div style="margin-top:4px;white-space:pre-line">${esc(o.rappel)}</div></div>`;
  if (message) h += `<div class="ok" style="margin-top:10px">${esc(message)}</div>`;
  h += `<form id="fOuv">`;
  const modeInit = precedent ? precedent.mode : (auto && auto.mode);
  // Le libellé suit le mode réel de l'ouvrage (ex. Longueur × hauteur), pas un libellé fixe
  const nomModeOuv = (o.mesure && modeDe('m²', o.mesure) && o.mesure !== 'surface') ? modeDe('m²', o.mesure).nom : 'Longueur × largeur';
  if (o.unite === 'm²') h += `<label for="fMesure">Mesure</label>
      <select id="fMesure" name="mesure"><option value="lxl" ${modeInit === 'plan' ? '' : 'selected'}>${esc(nomModeOuv)}</option><option value="plan" ${modeInit === 'plan' ? 'selected' : ''}>Surface mesurée sur plan (forme quelconque)</option></select>`;
  for (const ch of champs) {
    // « Nombre » est facultatif : vide, la quantité compte 1 fois
    const libCase = ch.cle === 'nombre' ? 'Nombre (facultatif, 1 si vide)' : ch.libelle;
    h += `<label for="c_${ch.cle}">${esc(libCase)}</label>
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
  // Rien saisi dans les cotes : on utilise la quantité du configurateur
  const sansCotes = vals => champs.every(ch => ch.texte || String(vals[ch.cle] ?? '').trim() === '');
  const maj = () => {
    const vv0 = lireForm(f, champs);
    const estPlan = !!f.elements.mesure && f.elements.mesure.value === 'plan';
    const q = auto && !precedent && sansCotes(vv0) ? calcul(o, auto) : calcul(o, estPlan ? { ...vv0, cote2: '1' } : vv0);
    let t = `Quantité : ${fmt(q)} ${o.unite}`;
    const vv = lireForm(f, champs);
    if (o.saisie === 'menuiseries' && num(vv.largeur_cm) && num(vv.hauteur_cm))
      t += ` · surface ${fmt(num(vv.nombre || 1) * num(vv.largeur_cm) * num(vv.hauteur_cm) / 10000)} m²`;
    $('apercu').textContent = t;
  };
  // Mode « surface mesurée sur plan » : une seule case (surface), la deuxième cote est fixée à 1
  const majMesure = () => {
    if (!f.elements.mesure) return;
    const plan = f.elements.mesure.value === 'plan';
    const l1 = document.querySelector('label[for="c_cote1"]'), l2 = document.querySelector('label[for="c_cote2"]');
    if (l1) l1.textContent = plan ? 'Surface mesurée sur plan (m²)' : (champs.find(c => c.cle === 'cote1') || {}).libelle;
    if (l2) l2.style.display = plan ? 'none' : '';
    if (f.elements.cote2) { f.elements.cote2.style.display = plan ? 'none' : ''; if (plan) f.elements.cote2.value = ''; }
  };
  if (f.elements.mesure) f.elements.mesure.addEventListener('change', () => { majMesure(); maj(); });
  majMesure();
  f.addEventListener('input', maj);
  maj();
  f.addEventListener('submit', e => {
    e.preventDefault();
    let vals = lireForm(f, champs);
    if (auto && !precedent && sansCotes(vals)) vals = { ...auto };   // quantité du configurateur, sans rien inventer
    else if (f.elements.mesure && f.elements.mesure.value === 'plan') { vals.cote2 = '1'; vals.mode = 'plan'; }
    const manque = champs.filter(ch => !ch.texte && ch.cle !== 'nombre' && String(vals[ch.cle] ?? '').trim() === '');
    if (manque.length) { $('apercu').textContent = 'Quantité à saisir : ' + manque.map(ch => ch.libelle).join(', ') + '.'; return; }
    const q = calcul(o, vals);
    if (!(q > 0)) { $('apercu').textContent = 'Quantité nulle : vérifiez les cotes.'; return; }
    const surface = (o.saisie === 'menuiseries' && num(vals.largeur_cm) && num(vals.hauteur_cm))
      ? num(vals.nombre || 1) * num(vals.largeur_cm) * num(vals.hauteur_cm) / 10000 : null;
    // Garde-fou : une surface du configurateur déjà comptée au métré n'est pas ajoutée sans confirmation
    if (!precedent) {
      const viaConfig = !!vals.src || (!!o.lieConfig && !!compteLie);
      const srcAjout = vals.src || (viaConfig ? srcTxt(o.qte) : '');
      const typeAjout = vals.typeMur || (o.si && o.si.cle === 'murs_choix' ? o.si.val : '');
      const deja = viaConfig ? doublonConfig(o, q, srcAjout, typeAjout) : null;
      if (deja && !confirm(`Cette surface du configurateur est déjà comptée au métré, à la ligne ${numeroLignes(courantId)[deja.uid] || ''} (« ${deja.designation} »). L'ajouter une deuxième fois ?`)) {
        $('apercu').textContent = 'Non ajoutée : cette surface est déjà comptée au métré.';
        return;
      }
    }
    ajouterLotSiAbsent(courantId, o.lot);
    // Cotes reprises telles quelles du lien avec le configurateur : ligne liée (pas une saisie manuelle)
    const lienConfig = !precedent && !!compteLie && ['cote1', 'cote2', 'cote3'].every(k => num(compteLie[k]) === num(vals[k]));
    const L = lignesDe(courantId);
    // Ligne liée à la configuration seulement si la quantité proposée n'a pas été modifiée
    const proposee = !precedent && cc ? qteValeur(o, ctxQuantites(cc)) : null;
    const memeValeur = proposee && Object.keys(proposee).every(k => vals[k] === undefined || num(proposee[k]) === num(vals[k]));
    L.push({ uid: uid(), lot: o.lot, ouvrage: o.id, designation: o.designation, unite: o.unite,
             valeurs: vals, quantite: q, surface, cree: new Date().toISOString(), qteAuto: memeValeur ? o.qte : undefined, lien: lienConfig || undefined });
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
  const idx = $('selClient') ? $('selClient').value : '';
  const client = idx !== '' && CLIENTS[idx] ? pickClient(CLIENTS[idx]) : null;
  if (client) { proposerMetre(client, metresDuClient(client.ref)); return; }
  const nom = $('nomChantier').value.trim();
  if (!nom) { alert('Donnez un nom au chantier.'); return; }
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

$('selLot').onchange = e => { lotCourant = e.target.value; colorerLot(); renderOuvrages(); };
$('recherche').oninput = renderOuvrages;

$('listeOuvrages').addEventListener('click', e => {
  if (e.target.closest('#bLibre2')) { ouvrirModal(); ouvrirLibre(); return; }
  const li = e.target.closest('[data-ouv]');
  if (!li) return;
  const o = BIB.ouvrages.find(x => x.id === li.dataset.ouv);
  if (o) { ouvrirModal(); ouvrirOuvrage(o); }
});

// Formule de cotes affichée dans Détail (L × l, L × H…) : ligne verrouillée. Texte (src, plan) : modifiable.
function avecFormule(l) {
  const v = l.valeurs || {};
  if (v.src || v.mode === 'plan') return false;
  return ['cote1', 'cote2', 'cote3'].some(k => String(v[k] ?? '').trim() !== '');
}
// Texte d'une ligne sans formule (jamais une ligne avec formule de cotes)
$('tableMetre').addEventListener('click', e => {
  const b = e.target.closest('[data-desig]');
  if (!b) return;
  const L = lignesDe(courantId);
  const l = L.find(x => x.uid === b.dataset.desig);
  if (!l) return;
  const tmp = document.createElement('div');
  tmp.innerHTML = detailHtml(l);
  const texte = prompt('Détail de cette ligne (laisser vide pour revenir au texte automatique) :', l.detailTexte || tmp.textContent.trim());
  if (texte === null) return;
  if (texte.trim()) l.detailTexte = texte.trim(); else delete l.detailTexte;
  sauverLignes(courantId, L);
  renderMetre();
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

// Plusieurs métrés pour un même client (référence du Kanban) : reprendre ou créer « CLIENT – nom »
function metresDuClient(ref) {
  return chantiers.filter(c => !c.supprime && !c.archive && c.client && String(c.client.ref) === String(ref));
}
let clientEnAttente = null;
function panneauClient() {
  if (!$('panneauClient')) $('listeChantiers').insertAdjacentHTML('beforebegin', '<div id="panneauClient"></div>');
  return $('panneauClient');
}
function proposerMetre(client, deja) {
  clientEnAttente = client;
  const liste = deja.map(c => `<div class="ouv" style="min-height:0;padding:8px 0"><span><strong>${esc(c.nom)}</strong> · ${lignesDe(c.id).length} ligne(s)</span><button type="button" class="btn small" data-reprendre="${esc(c.id)}">Reprendre</button></div>`).join('');
  const titre = deja.length
    ? `Métrés déjà faits pour ${esc(client.nom)}${client.ref ? ' (réf. ' + esc(client.ref) + ')' : ''}`
    : `Premier métré pour ${esc(client.nom)}${client.ref ? ' (réf. ' + esc(client.ref) + ')' : ''}`;
  const aide = deja.length
    ? 'Reprenez un métré existant, ou créez-en un nouveau. Donnez-lui un nom court, par exemple « garage ».'
    : 'Donnez un nom à ce métré, par exemple « maison ». Vous pourrez en créer d\'autres ensuite pour ce même client.';
  panneauClient().innerHTML = `<div class="card" style="border:2px solid #E07838">
    <strong>${titre}</strong>
    ${liste}
    <p class="muted" style="margin:10px 0 4px">${aide}</p>
    <label for="suffixeMetre" style="display:block;font-weight:600;margin:6px 0 4px">Nom du nouveau métré</label>
    <div class="row" style="align-items:center;gap:6px"><span style="white-space:nowrap">${esc(client.nom)} – </span><input id="suffixeMetre" placeholder="ex. garage" style="flex:1"></div>
    <div class="row" style="margin-top:10px;gap:8px"><button type="button" class="btn" data-creer-metre>Créer ce métré</button><button type="button" class="btn sec" data-fermer-panneau>Annuler</button></div>
  </div>`;
}
document.addEventListener('click', e => {
  const pn = $('panneauClient');
  if (!pn || !pn.contains(e.target)) return;
  const r = e.target.closest('[data-reprendre]');
  if (r) { pn.innerHTML = ''; ouvrirChantier(r.dataset.reprendre); return; }
  if (e.target.closest('[data-fermer-panneau]')) { pn.innerHTML = ''; return; }
  if (e.target.closest('[data-creer-metre]') && clientEnAttente) {
    const suffixe = ($('suffixeMetre').value || '').trim();
    if (!suffixe) { alert('Donnez un nom au nouveau métré, par exemple « garage ».'); return; }
    const nom = clientEnAttente.nom + ' – ' + suffixe;
    if (chantiers.some(c => !c.supprime && c.nom === nom)) { alert('Un métré porte déjà ce nom.'); return; }
    const c = { id: 'c' + uid(), nom, client: clientEnAttente };
    chantiers.push(c);
    lsSet('chantiers', chantiers);
    marquerChantier(c.id);
    pn.innerHTML = '';
    ouvrirChantier(c.id);
  }
});

// Lien depuis la fiche client du Kanban : ouvre (ou crée) le chantier de ce client
async function ouvrirDepuisClient(ref) {
  if (!lsGet('clients', []).length) await actualiserClients(true);
  remplirSelectClients();
  const cl = lsGet('clients', []).find(x => String(x.ref) === String(ref));
  if (!cl) { alert('Client introuvable dans le Kanban : ' + ref); return; }
  route('chantiers'); renderChantiers(); proposerMetre(pickClient(cl), metresDuClient(ref));
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
      corps += `<tr><td class="n">${esc(l.num)}</td><td>${esc(l.designation)}</td>
        <td class="num">${fmt(l.quantite)}</td><td>${esc(l.unite)}</td><td class="det">${l.detailHtml}</td>
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
    <thead><tr><th>N°</th><th>Désignation</th><th>Quantité</th><th>Unité</th><th>Détail</th>${d.avecPrix ? '<th>P.U. HT ind.</th><th>Montant HT ind.</th>' : ''}</tr></thead>
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
        <td class="n">${esc(l.num)}</td><td>${esc(l.designation)}</td>
        <td class="num">${fmt(l.quantite)}</td><td>${esc(l.unite)}</td><td class="det">${l.detailHtml}</td>
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
        <thead><tr><th>N°</th><th>Désignation</th><th>Quantité</th><th>Unité</th><th>Détail</th>${cdpgf ? '<th>P.U. HT</th><th>Montant HT</th><th>TVA %</th>' : ''}</tr></thead>
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

/* ============ CDPGF à remplir : PDF avec cases de prix et calculs (lu par Adobe Acrobat Reader) ============ */
const PDFLIB_URL = 'https://cdnjs.cloudflare.com/ajax/libs/pdf-lib/1.17.1/pdf-lib.min.js';
const ACROBAT_URL = 'https://get.adobe.com/fr/reader/';
// Fonctions de calcul écrites dans le PDF (JavaScript lu par Acrobat)
const PDF_CALC_AIDE = "function n(v){var x=parseFloat(String(v==null?'':v).replace(/\\s/g,'').replace(',','.'));return isNaN(x)?0:x;}"
  + "function f(x){return (Math.round(x*100)/100).toFixed(2).replace('.',',');}";
function chargerPdfLib() {
  return new Promise((ok, ko) => {
    if (window.PDFLib) return ok(window.PDFLib);
    const s = document.createElement('script');
    s.src = PDFLIB_URL;
    s.onload = () => ok(window.PDFLib);
    s.onerror = () => ko(new Error('pdf-lib'));
    document.head.appendChild(s);
  });
}
// Les polices PDF standard n'acceptent que certains caractères : les autres deviennent « ? »
function texteFormulaire(s) {
  return String(s == null ? '' : s).replace(/œ/g, 'oe').replace(/Œ/g, 'OE').replace(/\s+/g, ' ')
    .replace(/[^ -~ -ÿ–—‘’“”•…€]/g, '?');
}
function decoupeTexte(s, police, taille, largeur) {
  const mots = texteFormulaire(s).split(' ').filter(Boolean);
  const lignes = [];
  let cur = '';
  for (const m of mots) {
    const essai = cur ? cur + ' ' + m : m;
    if (!cur || police.widthOfTextAtSize(essai, taille) <= largeur) cur = essai;
    else { lignes.push(cur); cur = m; }
  }
  if (cur) lignes.push(cur);
  return lignes.length ? lignes : [''];
}
const fmtQte = q => String(Math.round(Number(q || 0) * 1000) / 1000).replace('.', ',');
const nomFichierPdf = s => String(s || 'metre').normalize('NFD').replace(/[̀-ͯ]/g, '').replace(/[^A-Za-z0-9]+/g, '_').replace(/^_|_$/g, '');

async function pdfCdpgfFormulaire() {
  let PL;
  try { PL = await chargerPdfLib(); }
  catch (e) { alert('Export impossible : la bibliothèque PDF se charge depuis internet. Vérifiez la connexion, puis réessayez.'); return; }
  const d = donneesDocument();
  const lots = d.lots.filter(l => l.lignes.length);
  if (!lots.length) { alert('Aucune ligne dans ce métré.'); return; }
  const { PDFDocument, StandardFonts, rgb, PDFName, PDFHexString, PDFBool, TextAlignment } = PL;
  const doc = await PDFDocument.create();
  const helv = await doc.embedFont(StandardFonts.Helvetica);
  const helvB = await doc.embedFont(StandardFonts.HelveticaBold);
  const form = doc.getForm();
  const W = 595.28, H = 841.89, M = 40, BAS = 58, LARG = W - 2 * M;
  const ORANGE = rgb(0xE0 / 255, 0x78 / 255, 0x38 / 255), GRIS = rgb(0.42, 0.42, 0.42), NOIR = rgb(0.17, 0.17, 0.17);
  const CREME = rgb(1, 0.98, 0.95), GRIS_CLAIR = rgb(0.92, 0.92, 0.92), BLANC = rgb(1, 1, 1), TRAIT = rgb(0.85, 0.85, 0.85);
  const C = { n: 34, des: 217, qte: 52, unite: 30, pu: 62, mont: 68, tva: 52 };
  const X = {};
  let acc = M;
  for (const k of ['n', 'des', 'qte', 'unite', 'pu', 'mont', 'tva']) { X[k] = acc; acc += C[k]; }
  let page, y, contexteTable = false;
  const ordreCalcul = [];
  const nouvellePage = () => { page = doc.addPage([W, H]); y = H - M; };
  const ecrire = (s, x, yy, taille, police, couleur) => page.drawText(texteFormulaire(s), { x, y: yy, size: taille, font: police || helv, color: couleur || NOIR });
  const ecrireDroite = (s, xFin, yy, taille, police, couleur) => {
    const t = texteFormulaire(s);
    page.drawText(t, { x: xFin - (police || helv).widthOfTextAtSize(t, taille), y: yy, size: taille, font: police || helv, color: couleur || NOIR });
  };
  const enteteTable = () => {
    const h = 18;
    page.drawRectangle({ x: M, y: y - h, width: LARG, height: h, color: ORANGE });
    const titres = { n: 'N°', des: 'Désignation', qte: 'Quantité', unite: 'Unité', pu: 'P.U. HT', mont: 'Montant HT', tva: 'TVA %' };
    for (const k of Object.keys(titres)) ecrire(titres[k], X[k] + 3, y - 12, 8, helvB, BLANC);
    y -= h + 2;
  };
  // Paragraphe avec retour à la ligne automatique et saut de page
  const ligne = (s, x, largeur, taille, police, couleur) => {
    const il = taille * 1.35;
    for (const t of decoupeTexte(s, police || helv, taille, largeur)) {
      if (y - il < BAS) { nouvellePage(); if (contexteTable) enteteTable(); }
      y -= il;
      ecrire(t, x, y, taille, police, couleur);
    }
  };
  const champ = (nom, x, yy, w, h, opts) => {
    const f = form.createTextField(nom);
    f.addToPage(page, { x, y: yy, width: w, height: h, borderColor: ORANGE, borderWidth: 0.5, backgroundColor: opts.fond || CREME });
    f.setFontSize(9);
    f.setAlignment(opts.align === undefined ? TextAlignment.Right : opts.align);
    if (opts.valeur) f.setText(opts.valeur);
    if (opts.lecture) f.enableReadOnly();
    return f;
  };
  // Case de saisie réservée aux nombres : Acrobat refuse les lettres
  const saisieNombre = f => {
    const widget = f.acroField.getWidgets()[0];
    const act = doc.context.obj({});
    act.set(PDFName.of('S'), PDFName.of('JavaScript'));
    act.set(PDFName.of('JS'), PDFHexString.fromText("AFNumber_Keystroke(2,0,0,0,'',true);"));
    const aa = doc.context.obj({});
    aa.set(PDFName.of('K'), act);
    widget.dict.set(PDFName.of('AA'), aa);
    return f;
  };
  // Script de calcul attaché à un champ (exécuté par Acrobat à chaque modification)
  const calcul = (f, js) => {
    const widget = f.acroField.getWidgets()[0];
    const act = doc.context.obj({});
    act.set(PDFName.of('S'), PDFName.of('JavaScript'));
    act.set(PDFName.of('JS'), PDFHexString.fromText(PDF_CALC_AIDE + js));
    const aa = doc.context.obj({});
    aa.set(PDFName.of('C'), act);
    widget.dict.set(PDFName.of('AA'), aa);
    ordreCalcul.push(f.acroField.ref);
  };

  // ---- Page de garde ----
  nouvellePage();
  contexteTable = false;
  let logo = null;
  try { logo = await doc.embedPng(await (await fetch(new URL('logo.png', location.href).href, { cache: 'no-cache' })).arrayBuffer()); } catch (e) {}
  if (logo) { const s = logo.scaleToFit(150, 46); page.drawImage(logo, { x: M, y: y - s.height, width: s.width, height: s.height }); }
  else ecrire(ATELIER.nom, M, y - 20, 18, helvB, ORANGE);
  ecrireDroite(ATELIER.adresse, W - M, y - 10, 8, helv, GRIS);
  ecrireDroite(ATELIER.tel + ' · ' + ATELIER.mail, W - M, y - 22, 8, helv, GRIS);
  ecrireDroite(ATELIER.web, W - M, y - 34, 8, helv, GRIS);
  y -= 58;
  page.drawRectangle({ x: M, y: y - 3, width: LARG, height: 3, color: ORANGE });
  y -= 36;
  ecrire('CDPGF À REMPLIR', M, y, 9, helvB, ORANGE);
  y -= 26;
  ecrire(d.titre, M, y, 22, helvB, NOIR);
  y -= 22;
  ecrire('Établi le ' + d.date, M, y, 9, helv, GRIS);
  y -= 26;
  const cl = d.client || {};
  const dl = (chantiers.find(x => x.id === courantId) || {}).dateLimite;
  const infos = [['Nom', cl.nom], ['Référence', cl.ref], ['Adresse du chantier', cl.cadr], ['Nature du projet', cl.nat],
    ['Réponse attendue avant le', dl ? new Date(dl + 'T12:00').toLocaleDateString('fr-FR', { weekday: 'long', day: 'numeric', month: 'long', year: 'numeric' }) : '']];
  const largeurLabel = Math.max(...infos.map(([k]) => helvB.widthOfTextAtSize(k + ' : ', 9))) + 8;
  for (const [k, v] of infos) if (v) { ecrire(k + ' : ', M, y, 9, helvB, GRIS); ecrire(v, M + largeurLabel, y, 9, helv, NOIR); y -= 14; }
  y -= 24;
  ecrire('Lots concernés', M, y, 10, helvB, ORANGE);
  y -= 16;
  for (const lot of lots) ligne(lot.num + ' · ' + lot.nom + ' (' + lot.lignes.length + (lot.lignes.length > 1 ? ' lignes)' : ' ligne)'), M + 10, LARG - 10, 9, helv, NOIR);
  y -= 26;
  ecrire("Mode d'emploi", M, y, 10, helvB, ORANGE);
  y -= 16;
  ligne('1. Ce document se remplit avec Adobe Acrobat Reader, gratuit : ' + ACROBAT_URL, M, LARG, 9, helv, NOIR);
  ligne("2. Il ne fonctionne qu'avec ce logiciel : le calcul des montants et des totaux n'est pas fait par les lecteurs de navigateur.", M, LARG, 9, helv, NOIR);
  ligne('3. Remplissez uniquement les cases « P.U. HT » (prix unitaire) et « TVA % » de chaque ligne. Les quantités sont figées.', M, LARG, 9, helv, NOIR);
  ligne('4. Les montants, les totaux HT, la TVA et le total TTC se calculent automatiquement.', M, LARG, 9, helv, NOIR);
  ligne('5. Une fois rempli, enregistrez le fichier (Fichier > Enregistrer) avant de le renvoyer.', M, LARG, 9, helv, NOIR);
  ligne('Les taux de TVA du lot (TVA 1, 2 et 3) sont affichés en haut de chaque lot : ils sont repris automatiquement de la colonne « TVA % ».', M, LARG, 9, helv, NOIR);

  // ---- Une section par lot ----
  lots.forEach((lot, k) => {
    nouvellePage();
    contexteTable = true;
    ecrire('ATELIER 2M · CDPGF · ' + d.titre, M, y - 9, 7.5, helv, GRIS);
    y -= 26;
    ecrire('Lot ' + lot.num + ' · ' + lot.nom, M, y - 16, 16, helvB, NOIR);
    y -= 30;
    // Taux de TVA du lot, repris des lignes (même calcul que plus bas)
    ecrire('Taux de TVA du lot :', M, y - 12, 9, helvB, ORANGE);
    const topTVA = [1, 2, 3].map(t => {
      const xx = M + 125 + (t - 1) * 118;
      ecrire(`TVA ${t} :`, xx, y - 12, 9, helvB, NOIR);
      const f = champ(`L${k}_TOP${t}`, xx + 44, y - 15, 40, 15, { align: TextAlignment.Center, fond: GRIS_CLAIR });
      ecrire('%', xx + 88, y - 12, 9, helv, NOIR);
      return f;
    });
    y -= 26;
    if (lot.gen) {
      const g = genDuLot(lot.id);
      if (g) {
        ligne('Généralités : ' + g.titre, M, LARG, 9, helvB, ORANGE);
        for (const sct of g.sections) {
          ligne(sct.titre, M, LARG, 8, helvB, NOIR);
          for (const p of sct.points) ligne('• ' + p, M + 8, LARG - 8, 7.6, helv, GRIS);
        }
        y -= 6;
      }
    }
    enteteTable();
    const noms = [];
    lot.lignes.forEach((l, i) => {
      const des = decoupeTexte(l.designation, helvB, 8.5, C.des - 8);
      const det = l.detail ? decoupeTexte(l.detail, helv, 7.2, C.des - 8) : [];
      const rh = Math.max(24, 8 + des.length * 10.5 + det.length * 8.8 + 4);
      if (y - rh < BAS) { nouvellePage(); enteteTable(); }
      const bas = y - rh;
      page.drawLine({ start: { x: M, y: bas }, end: { x: M + LARG, y: bas }, thickness: 0.5, color: TRAIT });
      ecrire(l.num, X.n + 3, y - 11, 8, helvB, ORANGE);
      des.forEach((t, j) => ecrire(t, X.des + 3, y - 11 - j * 10.5, 8.5, helvB, NOIR));
      det.forEach((t, j) => ecrire(t, X.des + 3, y - 11 - des.length * 10.5 - 2 - j * 8.8, 7.2, helv, GRIS));
      ecrire(l.unite, X.unite + 4, bas + rh / 2 - 3, 8, helv, NOIR);
      const fy = bas + (rh - 15) / 2;
      const nq = `L${k}_${i}_Q`, nu = `L${k}_${i}_PU`, nm = `L${k}_${i}_M`, nt = `L${k}_${i}_T`;
      champ(nq, X.qte + 2, fy, C.qte - 4, 15, { valeur: fmtQte(l.quantite), lecture: true, fond: GRIS_CLAIR });
      saisieNombre(champ(nu, X.pu + 2, fy, C.pu - 4, 15, {}));
      const fm = champ(nm, X.mont + 2, fy, C.mont - 4, 15, { fond: GRIS_CLAIR });
      saisieNombre(champ(nt, X.tva + 2, fy, C.tva - 4, 15, { align: TextAlignment.Center }));
      noms.push({ q: nq, pu: nu, m: nm, t: nt, fm });
      y = bas;
    });
    // Montant de chaque ligne : quantité × prix unitaire
    for (const o of noms) {
      calcul(o.fm, `var pv=String(getField("${o.pu}").value).replace(/\\s/g,'');if(pv===''){event.value='';}else{event.value=f(n(getField("${o.q}").value)*n(getField("${o.pu}").value));}`);
    }
    // Totaux du lot
    if (y - 110 < BAS) { nouvellePage(); enteteTable(); }
    y -= 8;
    ecrire('Total HT du lot', X.des + 3, y - 12, 9, helvB, NOIR);
    const fHT = champ(`L${k}_HT`, X.mont + 2, y - 15, C.mont - 4, 15, { fond: GRIS_CLAIR });
    y -= 22;
    const somme = noms.map(o => `if(String(getField("${o.m}").value).replace(/\\s/g,'')!==''){s+=n(getField("${o.m}").value);}`).join('');
    calcul(fHT, `var s=0;${somme}event.value=f(s);`);
    const fTVA = [1, 2, 3].map(t => {
      ecrire(`TVA ${t} : taux repris des lignes et montant de la TVA`, X.des + 3, y - 12, 8, helv, NOIR);
      const ftx = champ(`L${k}_TX${t}`, X.tva + 2, y - 15, C.tva - 4, 15, { align: TextAlignment.Center, fond: GRIS_CLAIR });
      const fmt = champ(`L${k}_MT${t}`, X.mont + 2, y - 15, C.mont - 4, 15, { fond: GRIS_CLAIR });
      y -= 22;
      return { t, ftx, fmt };
    });
    // Taux : le 1er taux trouvé dans les lignes devient TVA 1, le 2e TVA 2, le 3e TVA 3
    const listeTaux = noms.map(q => `if(String(getField("${q.t}").value).replace(/\\s/g,'')!==''){var v=n(getField("${q.t}").value);if(r.indexOf(v)<0){r.push(v);}}`).join('');
    for (const o of fTVA) {
      calcul(o.ftx, `var r=[];${listeTaux}event.value=(r.length>=${o.t})?String(r[${o.t - 1}]).replace('.',','):'';`);
    }
    topTVA.forEach((f, i) => calcul(f, `var r=[];${listeTaux}event.value=(r.length>=${i + 1})?String(r[${i}]).replace('.',','):'';`));
    for (const o of fTVA) {
      const cumuls = noms.map(q => `if(String(getField("${q.t}").value).replace(/\\s/g,'')!==''&&n(getField("${q.t}").value)===r&&String(getField("${q.m}").value).replace(/\\s/g,'')!==''){s+=n(getField("${q.m}").value);}`).join('');
      calcul(o.fmt, `var tx=String(getField("L${k}_TX${o.t}").value).replace(/\\s/g,'');if(tx===''){event.value='';}else{var r=n(tx),s=0;${cumuls}event.value=f(s*r/100);}`);
    }
    ecrire('Total TTC du lot', X.des + 3, y - 12, 9, helvB, NOIR);
    const fTTC = champ(`L${k}_TTC`, X.mont + 2, y - 15, C.mont - 4, 15, { fond: GRIS_CLAIR });
    y -= 22;
    calcul(fTTC, `event.value=f(n(getField("L${k}_HT").value)${fTVA.map(o => `+n(getField("L${k}_MT${o.t}").value)`).join('')});`);
    y -= 8;
    ligne('Indiquez les prix unitaires HT et le taux de TVA de chaque ligne. Les montants et les totaux se calculent automatiquement dans Adobe Acrobat Reader.', M, LARG, 7.5, helv, GRIS);
  });

  // Pied de page : numéro de page et rappel du logiciel
  const pages = doc.getPages();
  pages.forEach((p, i) => {
    p.drawText(texteFormulaire(`Page ${i + 1} / ${pages.length} · Calculs : Adobe Acrobat Reader (gratuit) ${ACROBAT_URL}`), { x: M, y: 24, size: 6.8, font: helv, color: GRIS });
  });
  // Ordre des calculs : montants, puis TVA, puis totaux
  const CO = doc.context.obj([]);
  ordreCalcul.forEach(r => CO.push(r));
  form.acroForm.dict.set(PDFName.of('CO'), CO);
  form.acroForm.dict.set(PDFName.of('NeedAppearances'), PDFBool.True);
  form.updateFieldAppearances(helv);

  const octets = await doc.save();
  const url = URL.createObjectURL(new Blob([octets], { type: 'application/pdf' }));
  const a = document.createElement('a');
  a.href = url;
  a.download = 'CDPGF_a_remplir_' + nomFichierPdf(d.titre) + '.pdf';
  document.body.appendChild(a);
  a.click();
  a.remove();
  setTimeout(() => URL.revokeObjectURL(url), 5000);
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
  const m = [['N°', 'Désignation', 'Quantité', 'Unité', 'Détail', ...(avecPrix ? ['P.U. HT ind.', 'Montant HT ind.'] : [])]];
  const lignesLot = [], lignesLigne = [];
  for (const lot of d.lots) {
    lignesLot.push(m.length);
    m.push([lot.num + ' · ' + lot.nom, '', '', '', lot.lignes.length ? '' : '(aucune ligne)', ...(avecPrix ? [''] : []), ...(avecPrix ? [''] : [])].slice(0, nc));
    for (const l of lot.lignes) {
      lignesLigne.push(m.length);
      m.push([l.num, l.designation, l.quantite, l.unite, l.detail, ...(avecPrix ? [l.pu ?? '', l.montant ?? ''] : [])]);
    }
  }
  let ligneTotal = null;
  if (avecPrix) {
    ligneTotal = m.length;
    m.push(['', 'TOTAL INDICATIF HT (prix moyens de référence, à valider)', '', '', '', '', d.total]);
  }
  const ws2 = XL.utils.aoa_to_sheet(m);
  ws2['!cols'] = [{ wch: 9 }, { wch: 60 }, { wch: 12 }, { wch: 10 }, { wch: 48 }, ...(avecPrix ? [{ wch: 14 }, { wch: 16 }] : [])];
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
$('btnCdpgf').insertAdjacentHTML('afterend', ' <button class="btn small sec" id="btnCdpgfPdf">CDPGF à remplir (PDF)</button>');
$('btnCdpgfPdf').onclick = pdfCdpgfFormulaire;


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

// Récupérer la bibliothèque telle qu'elle est sur le Drive (remplace la copie de cet appareil)
if ($('btnRecupBib')) $('btnRecupBib').onclick = async () => {
  if (!lsGet('url', '') || !lsGet('jeton', '')) { alert("Enregistrez d'abord l'adresse et le jeton."); return; }
  if (!confirm('La bibliothèque de cet appareil sera remplacée par celle du Drive. Les modifications faites ici et non envoyées seront perdues. Continuer ?')) return;
  try {
    const j = await post({ action: 'lire_bibliotheque' });
    if (!j.ok || !j.bibliotheque || !j.bibliotheque.ouvrages) { alert('Le Drive n\'a pas renvoyé de bibliothèque.'); return; }
    BIB = j.bibliotheque; assurerOuvragesSoutenement(); lsSet('bib', BIB); lsSet('bib_modifiee', false);
    remplirLots(); renderOuvrages(); renderBiblio();
    alert('Bibliothèque récupérée du Drive (révision ' + (BIB.revision || '?') + ').');
  } catch (e) { alert('Récupération impossible pour le moment (réseau).'); }
};

// Prendre la version livrée avec l'application (bibliotheque.json) et l'envoyer sur le Drive
if ($('btnFichierBib')) $('btnFichierBib').onclick = async () => {
  if (!lsGet('url', '') || !lsGet('jeton', '')) { alert("Enregistrez d'abord l'adresse et le jeton."); return; }
  if (!confirm('La bibliothèque de cet appareil et celle du Drive seront remplacées par la version livrée avec l\'application. Continuer ?')) return;
  try {
    const r = await fetch('bibliotheque.json', { cache: 'no-cache' });
    const fichier = await r.json();
    const j = await post({ action: 'sauver_bibliotheque', bibliotheque: fichier });
    if (!j.ok) { alert('Refus du Drive : ' + (j.erreur || 'erreur inconnue') + '. Rien n\'a été modifié.'); return; }
    BIB = fichier; assurerOuvragesSoutenement(); lsSet('bib', BIB); lsSet('bib_modifiee', false);
    remplirLots(); renderOuvrages(); renderBiblio();
    alert('Version livrée (révision ' + (BIB.revision || '?') + ') envoyée sur le Drive.');
  } catch (e) { alert('Envoi impossible pour le moment (réseau).'); }
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
    return `<div class="ouv" data-edit="${esc(o.id)}"><span>${esc(o.designation)}<div class="muted" style="font-size:12px"><strong>${esc(o.id)}</strong> · ${esc(libLot(o.lot))}</div></span>
      <span class="tag">${esc(o.unite)} · ${p && (p.moyen != null || p.unique != null) ? fmt(p.moyen != null ? p.moyen : p.unique) + ' € HT' : 'sans prix'}</span></div>`;
  }).join('') || '<p class="muted" style="padding:12px">Aucun ouvrage.</p>';
  // Ouvrages supprimés (restaurables) : en bas de la liste
  const supprimes = BIB.ouvrages.filter(o => o.supprime && (!lot || o.lot === lot));
  if (supprimes.length) {
    $('biblioListe').innerHTML += `<details style="padding:0 12px 12px"><summary class="muted">Supprimés (${supprimes.length})</summary>` +
      supprimes.map(o => `<div class="ouv" style="padding:8px 0"><label style="display:flex;gap:8px;align-items:center;flex:1;min-width:0"><input type="checkbox" data-purge-cb="${esc(o.id)}" style="width:auto;height:auto"><span>${esc(o.designation)}</span></label>
        <button class="btn small sec" data-restaurer-ouv="${esc(o.id)}">Restaurer</button></div>`).join('')
      + `<div style="margin-top:10px"><button class="btn small danger" data-purger-ouv>Supprimer définitivement les ouvrages cochés</button></div></details>`;
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

let COTES_EDIT = {};   // liaisons des cotes en cours d'édition dans la fiche
function formulaireOuvrage(o, lotChoisi, cotesInit, draftRestaure) {
  // Nouvel ouvrage : on reprend le lot choisi dans la bibliothèque
  const v = o || { designation: '', lot: lotChoisi || lotCourant || BIB.lots[0].id, unite: 'u' };
  COTES_EDIT = JSON.parse(JSON.stringify(cotesInit || (o && o.cotes) || {}));
  const mesureCour = draftRestaure && draftRestaure.mesure !== undefined ? draftRestaure.mesure : v.mesure;
  const blocCotes = `<div class="card" style="margin-top:10px"><strong>Cotes reliées au configurateur (case par case)</strong>
      <p class="muted" style="margin:4px 0 6px;font-size:12px">Pour chaque cote, cliquez « Choisir », puis la case du configurateur qui donne cette valeur. Elle est reprise dans le métré et suit le configurateur.</p>
      ${champsCotesOuv(v.unite, mesureCour).map(ch => { const L = COTES_EDIT[ch.cle]; return `<div class="row" style="align-items:center;gap:8px;margin-top:6px"><span style="flex:1;min-width:0"><strong>${esc(ch.libelle)}</strong> : ${L ? esc(L.lib) : '<span class="muted">non relié</span>'}</span><button type="button" class="btn small sec" data-lien="${esc(ch.cle)}">Choisir</button>${L ? `<button type="button" class="btn small sec" data-effacer="${esc(ch.cle)}">Effacer</button>` : ''}</div>`; }).join('') || '<p class="muted" style="margin:6px 0 0">Choisissez d\'abord l\'unité : les cotes apparaîtront ici.</p>'}
    </div>`;
  const p = (o && o.prix_indicatif) || {};
  const devis = devisDe(p);
  const val = x => (x != null ? String(Math.round(x * 100) / 100).replace('.', ',') : '');
  $('sheet').innerHTML = `<h2 style="margin:0 0 6px;font-size:18px">${o ? 'Modifier l\'ouvrage' : 'Nouvel ouvrage'}</h2>${o ? `<p class="muted" style="font-size:13px;margin:0 0 8px">Numéro : <strong>${esc(o.id)}</strong></p>` : ''}
    <form id="fBib">
      <label for="b_des">Désignation</label><input id="b_des" name="designation" required value="${esc(v.designation)}">
      <label for="b_lot">Lot</label><select id="b_lot" name="lot">${BIB.lots.map(l => `<option value="${esc(l.id)}" ${l.id === v.lot ? 'selected' : ''}>${esc(l.nom)}</option>`).join('')}</select>
      <label for="b_unite">Unité de mesure</label><select id="b_unite" name="unite">${UNITES.map(u => `<option ${u === v.unite ? 'selected' : ''}>${u}</option>`).join('')}</select>
      <label for="b_mesure">Mode de métré (cotes demandées)</label><select id="b_mesure" name="mesure">${optionsMesure(v.unite, mesureCour)}</select>
      <label for="b_lie">Reprend les cotes de l'ouvrage (liaison permanente)</label>
      <select id="b_lie" name="lie"><option value="">— aucun —</option>${BIB.ouvrages.filter(x => !x.supprime && (!o || x.id !== o.id)).slice().sort((a, b) => a.designation.localeCompare(b.designation, 'fr')).map(x => `<option value="${esc(x.id)}" ${o && o.liePar === x.id ? 'selected' : ''}>${esc(x.designation)} · ${esc(x.id)}</option>`).join('')}</select>
      ${blocCotes}
      <p class="muted" style="margin:4px 0 8px;font-size:12px">Si vous choisissez un ouvrage, les cotes (longueur, largeur, hauteur) de cet ouvrage sont reprises automatiquement dans le métré et suivent ses modifications.</p>
      <label for="b_rappel">Formule de rappel (explication, affichée à la saisie)</label>
      <textarea id="b_rappel" name="rappel" rows="3" placeholder="ex. Longueur du mur × hauteur sous plafond, déduire les ouvertures ≥ 1,50 m²" style="width:100%;padding:10px;border:1px solid var(--line);border-radius:8px;background:var(--card);color:var(--fg);font:inherit">${esc(v.rappel || '')}</textarea>
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
  // Changer le mode : la fiche se réaffiche avec les cases du nouveau mode (les autres liaisons sont gardées)
  $('b_mesure').addEventListener('change', () => {
    const ok = new Set(champsCotesOuv($('b_unite').value, $('b_mesure').value).map(x => x.cle));
    const liens = {}; for (const k in COTES_EDIT) if (ok.has(k)) liens[k] = COTES_EDIT[k];
    reouvrirFormulaire(o, lotChoisi, liens, capturerBrouillon());
  });
  if (o && $('bSupprOuv')) $('bSupprOuv').onclick = () => supprimerOuvrage(o.id);
  document.querySelectorAll('[data-lien]').forEach(b => b.onclick = () => {
    if (!courantId) { alert('Ouvrez d\'abord un chantier : le configurateur sert à choisir.'); return; }
    const cle = b.dataset.lien, ch = champsCotesOuv(v.unite, mesureCour).find(x => x.cle === cle);
    window.CHOIX_CONF = { mode: 'cote', cote: cle, ouvId: o ? o.id : null, lot: (o && o.lot) || lotChoisi || lotCourant, draft: capturerBrouillon(), liens: JSON.parse(JSON.stringify(COTES_EDIT)) };
    fermer();
    ouvrirConfig();
    activerBandeauChoix('Cliquez la case du configurateur pour : ' + (ch ? ch.libelle : cle));
  });
  document.querySelectorAll('[data-effacer]').forEach(b => b.onclick = () => {
    const liens = JSON.parse(JSON.stringify(COTES_EDIT)); delete liens[b.dataset.effacer];
    reouvrirFormulaire(o, lotChoisi, liens, capturerBrouillon());
  });
}
// Brouillon de la fiche (ce qui est tapé, pour ne rien perdre pendant le choix)
function capturerBrouillon() {
  const d = {};
  for (const el of $('fBib').elements) if (el.name) d[el.name] = el.value;
  return d;
}
// Réouvre la fiche avec le brouillon et les liaisons
function reouvrirFormulaire(o, lotChoisi, liens, brouillon) {
  route('biblio');
  ouvrirModal();
  formulaireOuvrage(o, lotChoisi, liens, brouillon);
  const f = $('fBib');
  for (const [k, val] of Object.entries(brouillon || {})) { if (f.elements[k] && k !== 'lieconf' && k !== 'lie') f.elements[k].value = val; }
  if (f.elements.lieconf) f.elements.lieconf.value = (brouillon && brouillon.lieconf) || '';
  if (f.elements.lie) f.elements.lie.value = (brouillon && brouillon.lie) || '';
}

// Choix dans le configurateur : bandeau en bas, clic sur la case, retour à la fiche
function activerBandeauChoix(texte) {
  let b = $('bandeauChoix');
  if (!b) {
    b = document.createElement('div');
    b.id = 'bandeauChoix';
    b.style.cssText = 'position:fixed;left:0;right:0;bottom:0;z-index:60;background:#E07838;color:#fff;padding:12px 16px;font-weight:600;box-shadow:0 -2px 8px rgba(0,0,0,.2)';
    b.innerHTML = '<span id="bandeauTexte"></span> <button type="button" id="bAnnulChoix" class="btn sec" style="margin-left:8px;background:#fff">Annuler</button>';
    document.body.appendChild(b);
    $('bAnnulChoix').onclick = () => retourBibliotheque(null, null);
  }
  $('bandeauTexte').textContent = texte || 'Cliquez sur la case à reprendre.';
  b.style.display = 'block';
}
// Retour à la fiche d'ouvrage. Mode « source » : massif ou rigoles. Mode « cote » : une cote reliée à une case.
function retourBibliotheque(src, lien) {
  const ch = window.CHOIX_CONF;
  window.CHOIX_CONF = null;
  if ($('bandeauChoix')) $('bandeauChoix').style.display = 'none';
  if (!ch) return;
  const o = ch.ouvId ? BIB.ouvrages.find(x => x.id === ch.ouvId) : null;
  if (ch.mode === 'cote') {
    const liens = ch.liens || {};
    if (lien) liens[ch.cote] = lien;
    reouvrirFormulaire(o, ch.lot, liens, ch.draft);
    return;
  }
  route('biblio');
  ouvrirModal();
  formulaireOuvrage(o, ch.lot);
  const f = $('fBib');
  for (const [k, v] of Object.entries(ch.draft)) { if (f.elements[k] && k !== 'lieconf' && k !== 'lie') f.elements[k].value = v; }
  if (f.elements.lie) f.elements.lie.value = ch.draft.lie || '';
}
// Clic dans le configurateur pendant le choix
document.addEventListener('click', e => {
  if (!window.CHOIX_CONF) return;
  if (window.CHOIX_CONF.mode === 'cote') {
    e.preventDefault(); e.stopPropagation();
    const msg = t => { if ($('bandeauTexte')) $('bandeauTexte').textContent = t; };
    // Clic sur le libellé : on prend la case qui est dans le même bloc
    let cliquee = e.target;
    if (cliquee.tagName === 'LABEL' && cliquee.parentElement) cliquee = cliquee.parentElement.querySelector('input,select,textarea') || cliquee;
    const t = cliquee.closest ? cliquee.closest('input,select,textarea') : null;
    if (!t || !(t.dataset.k || t.dataset.plrow)) { msg('Cliquez une case de saisie du configurateur (une case où l\'on tape une valeur).'); return; }
    if (t.tagName !== 'INPUT' || !['decimal', 'numeric'].includes(t.getAttribute('inputmode'))) { msg('Cette case n\'est pas un nombre : cliquez une case où l\'on tape une valeur.'); return; }
    const lab = t.parentElement && t.parentElement.querySelector('label');
    const libChamp = lab ? lab.textContent.trim() : (t.dataset.champ || t.dataset.k);
    let lien, titre = '';
    if (t.dataset.plrow) {
      const [i, champ] = t.dataset.plrow.split(':');
      const c = chantiers.find(x => x.id === courantId);
      const pc = c ? piecesDe(c)[parseInt(i, 10)] : null;
      lien = pc ? { k: 'piece', type: pc.type, qualif: pc.qualif || '', champ } : { k: 'piece', idx: parseInt(i, 10), champ };
      titre = 'Pièce « ' + ((pc && nomPiece(pc)) || ('n°' + (parseInt(i, 10) + 1))) + ' »';
    } else {
      lien = { k: t.dataset.k, champ: t.dataset.champ || '' };
      if (t.dataset.id) lien.id = t.dataset.id;
      if (t.dataset.k === 'pleine') {
        // Fouille en pleine masse : numéro et usage de la fouille
        const c = chantiers.find(x => x.id === courantId);
        const liste = c ? pleinesDe(projetDe(c).fond) : [];
        const i = liste.findIndex(x => x.id === t.dataset.id);
        const usages = { massif: 'massif de fondation', plateforme: 'plateforme / dallage', divers: 'trou divers' };
        titre = i >= 0 ? 'Fouille n°' + (i + 1) + ' (' + (usages[liste[i].usage] || liste[i].usage || 'massif de fondation') + ')' : 'Fouille en pleine masse';
      } else {
        const h3 = t.closest('section') && t.closest('section').querySelector('h3');
        titre = h3 ? h3.textContent.trim() : '';
      }
    }
    lien.lib = [titre, libChamp].filter(Boolean).join(' · ');
    retourBibliotheque(null, lien);
    return;
  }
  const t = e.target.closest('[data-source]');
  if (!t) return;
  e.preventDefault(); e.stopPropagation();
  retourBibliotheque(t.dataset.source, null);
}, true);

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
  const lie = f.elements.lie ? f.elements.lie.value : '';
  const lieConf = '';   // ancien choix « source configurateur » : remplacé par les cotes reliées une à une
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
    if (lie && lie !== o.id) o.liePar = lie; else delete o.liePar;
    if (lieConf) o.lieConfig = lieConf; else delete o.lieConfig;
    if (Object.keys(COTES_EDIT).length) o.cotes = JSON.parse(JSON.stringify(COTES_EDIT)); else delete o.cotes;
    o.designation = des; o.lot = lot; o.unite = unite;
    o.version = (o.version || 1) + 1;
    if (prix) o.prix_indicatif = prix; else delete o.prix_indicatif;
  } else {
    const n = Math.max(BIB.prochainNumero || 0, 0, ...BIB.ouvrages.map(o => parseInt(o.id.slice(4), 10))) + 1;
    BIB.prochainNumero = n;
    const o = { id: 'OUV-' + String(n).padStart(4, '0'), lot, designation: des, unite, type: 'commun', saisie: 'metre', champs: (mesure ? champsPourMode(unite, mesure) : champsBib(unite)), version: 1 };
    if (mesure) o.mesure = mesure;
    if (rappel) o.rappel = rappel;
    if (lie) o.liePar = lie;
    if (lieConf) o.lieConfig = lieConf;
    if (Object.keys(COTES_EDIT).length) o.cotes = JSON.parse(JSON.stringify(COTES_EDIT));
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
  if (e.target.closest('[data-purger-ouv]')) {
    const cochés = new Set([...document.querySelectorAll('[data-purge-cb]:checked')].map(x => x.dataset.purgeCb));
    if (!cochés.size) { alert('Cochez d\'abord les ouvrages à supprimer définitivement.'); return; }
    if (!confirm(cochés.size + ' ouvrage(s) coché(s) seront supprimés définitivement de la bibliothèque (plus restaurables). Continuer ?')) return;
    // Les numéros ne sont jamais réutilisés : on garde le plus grand numéro déjà attribué
    BIB.prochainNumero = Math.max(BIB.prochainNumero || 0, ...BIB.ouvrages.map(o => parseInt(o.id.slice(4), 10) || 0));
    BIB.ouvrages = BIB.ouvrages.filter(o => !(o.supprime && cochés.has(o.id)));
    sauverBibliotheque(); renderBiblio();
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

// Champs remplis du configurateur : fond vert 6eea9f (mis à jour à la saisie et à chaque affichage)
(function () {
  const f = document.getElementById('vConfig');
  if (!f) return;
  const marque = el => { if (el.matches && el.matches('input:not([type=checkbox]):not([type=button]),select,textarea')) el.classList.toggle('rempli', el.value !== ''); };
  const toutes = () => f.querySelectorAll('input,select,textarea').forEach(marque);
  new MutationObserver(toutes).observe(f, { childList: true, subtree: true });
  f.addEventListener('input', e => marque(e.target));
  f.addEventListener('change', e => marque(e.target));
})();
