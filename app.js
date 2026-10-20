
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
    table.metre tr.lot td{background:#E07838;color:#fff;font-weight:700;font-size:15px;padding:12px 10px;text-transform:uppercase;letter-spacing:.02em;border-top:4px solid #8a3f12}
    table.metre tr.lot-sep td{height:34px;padding:0;background:transparent;border:none}
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
    [data-piece].cible-avant{box-shadow:0 -4px 0 var(--acc2)}
    [data-piece].cible-apres{box-shadow:0 4px 0 var(--acc2)}
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
    :root[data-theme="dark"] body[data-page="tableau"]{background:#2a1d15}
    @media (prefers-color-scheme: dark){ :root:not([data-theme="light"]) body[data-page="tableau"]{background:#2a1d15} }
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
// Fondations : chaque fouille du VRD (tranchée pour semelles filantes, massif) entraîne la semelle béton
// du gros œuvre qui va avec, avec les mêmes cotes et la même quantité. Si la fouille disparaît, la semelle aussi.
// Fonction pure : renvoie la nouvelle liste de lignes.
// Massif : aucune semelle automatique, seul l'ouvrage de maçonnerie choisi entre au métré (comme les semelles filantes)
const pairesFondation = () => [[DES_FOND_FOUILLE, 'OUV-0040']];   // semelle filante : liée par identifiant (son nom a été précisé dans la bibliothèque)  // appelée à l'enregistrement, pas au chargement
function alignerFondations(L) {
  if (!BIB || !BIB.ouvrages || !Array.isArray(L)) return L;
  const ouv = d => BIB.ouvrages.find(x => !x.supprime && (x.designation === d || x.id === d));
  let out = L.slice();
  const sources = new Set();
  for (const [fouDes, betDes] of pairesFondation()) {
    const fou = ouv(fouDes);
    if (!fou) continue;
    for (const f of L) {
      if (f.ouvrage !== fou.id || !(f.quantite > 0)) continue;
      // Fouille en rigole sans semelle choisie : rien n'est inséré (une semelle déjà liée est retirée)
      if (fouDes === DES_FOND_FOUILLE && !f.semOuv) continue;
      sources.add(f.uid);
      // Semelle choisie dans le bloc Terrassement (fouille en rigole) ; sinon la semelle par défaut
      const bet = (f.semOuv && ouv(f.semOuv)) || ouv(betDes);
      if (!bet) continue;
      // La semelle déjà liée à cette fouille, ou une semelle issue de l'ancien calcul du configurateur (à reprendre)
      const existant = out.find(x => x.vrd === f.uid) || out.find(x => x.ouvrage === bet.id && !x.vrd && (x.projet || x.qteAuto));
      const ligne = Object.assign({}, existant || {}, { uid: existant ? existant.uid : uid(), lot: bet.lot, ouvrage: bet.id, designation: bet.designation, unite: bet.unite,
        valeurs: JSON.parse(JSON.stringify(f.valeurs || {})), quantite: f.quantite, surface: null, prix: 'moyen', cree: (existant && existant.cree) || new Date().toISOString(),
        vrd: f.uid, projet: undefined, qteAuto: undefined });
      out = existant ? out.map(x => x === existant ? ligne : x) : out.concat([ligne]);
    }
  }
  // Semelle dont la fouille a été supprimée : retirée
  return out.filter(x => !x.vrd || sources.has(x.vrd));
}
function sauverLignes(id, L) { if (_revueCollecte) { _revueCollecte[id] = (_revueCollecte[id] || []).concat(L); return true; } L = alignerFondations(L); const ok = lsSet('lignes.' + id, L); marquerChantier(id); return ok; }
function libLot(id) { const l = BIB.lots.find(x => x.id === id); return l ? l.nom : id; }

async function post(corps) {
  const url = lsGet('url', ''), tok = lsGet('jeton', '');
  const r = await fetch(url, { method: 'POST', headers: { 'Content-Type': 'text/plain;charset=utf-8' },
    body: JSON.stringify({ token: tok, ...corps }) });
  const j = await r.json();
  // Pendant une synchronisation manuelle, chaque requête terminée fait avancer la barre
  if (syncManuelle && syncEnCours) {
    syncReq.fait++;
    if (syncReq.fait > syncReq.total) syncReq.total = syncReq.fait + 1;
    syncAvance(Math.min(99, syncReq.fait / syncReq.total * 100), (syncReq.libelle || 'Synchronisation') + ' : requête ' + syncReq.fait);
  }
  return j;
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
// Données du dossier (étude de faisabilité du Kanban) reprises dans les généralités des lots concernés
function genDossier(lotId) {
  const c = chantiers.find(x => x.id === courantId); if (!c) return [];
  const card = _kanbanDossiers[refKanbanDe(c)]; if (!card) return [];
  const f = card.faisa || {}, e = card.euro || {};
  if (lotId === 'gros-oeuvre') {
    return [`Zone sismique du dossier : ${f.sismicite || 'non renseignée dans le Kanban (à vérifier avant chiffrage)'}. Appliquer les règles parasismiques correspondantes (Eurocode 8 et arrêtés), avec chaînage et ancrages adaptés.`];
  }
  if (lotId === 'charpente-structure-bois' || lotId === 'couverture-zinguerie') {
    const donnees = [e.vent ? `zone de vent ${e.vent}` : null, e.neige ? `zone de neige ${e.neige}` : null,
      (e.alt !== undefined && e.alt !== null && e.alt !== '') ? `altitude ${e.alt} m` : null, e.cat ? `catégorie ${e.cat}` : null].filter(Boolean);
    if (!donnees.length) return ['Zones de vent et de neige non renseignées dans le Kanban (à vérifier avant chiffrage).'];
    const suite = lotId === 'charpente-structure-bois'
      ? 'Charpente à dimensionner pour la zone de neige, la zone de vent et l\'altitude du dossier.'
      : 'Fixations de la couverture, de l\'écran et de la zinguerie adaptées à la zone de vent et à l\'altitude du dossier.';
    return [`Données du dossier : ${donnees.join(', ')}. ${suite}`];
  }
  return [];
}
// Généralités propres au type de charpente choisi (les sections « Fermettes » ne valent que pour la charpente industrielle)
const GEN_CHARP_TYPE = {
  traditionnelle: { titre: 'Charpente traditionnelle : structure, assemblages et pénétrations', points: [
    'Charpente traditionnelle en bois massif ou lamellé-collé traité classe 2 : fermes, pannes (sablières, intermédiaires, faîtière) et chevrons taillés et assemblés selon le DTU 31.1.',
    'Sections et entraxes justifiés par la note de calcul de l\'entreprise, d\'après la portée, les appuis, la pente et les charges de neige et de vent du récapitulatif ci-dessous.',
    'Coyaux, débords d\'égout et bois apparents réalisés selon les choix du récapitulatif ; bois apparents rabotés et traités.',
    'Noues, arêtiers, chevêtres et pénétrations taillés sur mesure, assemblages traditionnels ou quincaillerie structurelle (étriers, sabots, tiges filetées).'
  ] },
  fermette: { titre: 'Fermettes industrielles : pentes et pénétrations', points: [
    'Fermettes industrielles : pente de toiture, géométrie (monopente, 2, 3 ou 4 pans) et appuis selon le récapitulatif ci-dessous ; plan de pose et note de calcul du fabricant.',
    'Pénétrations (jonction de deux sens de toiture) : contrôle de la compatibilité des fermettes avant fabrication.',
    'Chevêtres de cheminée et de trémie, arêtiers et noues en fermettes : à préciser sur le plan de charpente du fabricant.'
  ] },
  terrasse: { titre: 'Toit terrasse : structure porteuse', points: [
    'Structure porteuse du toit terrasse dimensionnée pour la pente minimale de 3,5 %, le poids du complexe d\'étanchéité et les charges de neige du récapitulatif ci-dessous.'
  ] }
};
// Sections des généralités d'un lot, complétées par les données du dossier s'il y en a
function sectionsDuLot(lotId) {
  const g = genDuLot(lotId); if (!g) return [];
  let sections = g.sections;
  if (lotId === 'charpente-structure-bois') {
    const c = chantiers.find(x => x.id === courantId);
    // Une section par type de charpente présent dans les toitures du projet (ex. traditionnelle et fermettes)
    const types = c ? [...new Set(toitsDe(projetDe(c)).map(t => (t.type === 'plat' ? 'terrasse' : charpenteDe(t))).filter(x => GEN_CHARP_TYPE[x]))] : [];
    if (types.length) sections = [...sections.filter(s => !/fermette|traditionnel|terrasse/i.test(s.titre)), ...types.map(x => GEN_CHARP_TYPE[x])];
  }
  const dos = genDossier(lotId);
  return dos.length ? [...sections, { titre: 'Données du dossier (étude de faisabilité)', points: dos }] : sections;
}
// Récapitulatif pour le calcul de charpente de l'entreprise (en tête du lot charpente, sous les généralités)
function recapCharpente(lotId) {
  if (lotId !== 'charpente-structure-bois') return [];
  const c = chantiers.find(x => x.id === courantId); if (!c) return [];
  const p = projetDe(c), t = p.toiture || {}, r = projetCalcul(p);
  const lib = (map, v) => (v ? (map[v] || v) : '');
  const card = _kanbanDossiers[refKanbanDe(c)] || null, f = (card && card.faisa) || {}, e = (card && card.euro) || {};
  const ml = v => (num(v) > 0 ? fmt(num(v)) + ' m' : '');
  const structure = (t) => { const plat = t.type === 'plat', pente = num(t.pente); return [
    ['Type de charpente', plat ? 'Toit terrasse' : lib(FICHE_CHARP, charpenteDe(t))],
    ['Géométrie', plat ? 'Toit plat' : lib(FICHE_TOIT, t.type)],
    ['Pente', pente > 0 ? `${fmt(pente)} % (soit ${fmt(Math.round(Math.atan(pente / 100) * 180 / Math.PI * 10) / 10)}°)` : ''],
    ['Appuis', lib(FICHE_APPUIS, t.appuis)],
    ['Longueur entre appuis (portée)', ml(t.portee)],
    ['Type de versant', plat ? '' : (t.versant === 'avec' ? `Avec coyau${num(t.coyauLong) > 0 ? ' sur ' + fmt(num(t.coyauLong)) + ' cm' : ''}` : lib(FICHE_VERSANT, t.versant))],
    ['Esthétique de l\'égout', plat ? '' : lib(FICHE_EGOUT, t.egoutStyle)],
    ['Chevronnage', charpenteDe(t) === 'traditionnelle' && !plat ? (t.chevronnage ? 'Oui' : 'Non') : ''],
    ['Surface au sol couverte', num(t.surface) > 0 ? fmt(num(t.surface)) + ' m²' : ''],
    ['Surface de couverture (pente comprise)', rampantToit(t) > 0 ? fmt(Math.round(rampantToit(t) * 100) / 100) + ' m²' : '']
  ]; };
  const toitsL = toitsDe(p), plusieurs = toitsL.length > 1;
  const charpente = structure(t);
  const surfaces = [
    ...(plusieurs ? [['Surface de couverture, toutes toitures', r.toiture > 0 ? fmt(Math.round(r.toiture * 100) / 100) + ' m²' : '']] : []),
    ['Couverture', toitPente(p) ? lib(FICHE_COUV, couvDe(t)) : ''],
    ['Écran de sous-toiture', lib(FICHE_ECRAN, t.ecran)]
  ];
  const longueurs = [['Faîtage', ml(t.faite)], ['Rives', ml(t.rive)], ['Égout', ml(t.egout)], ['Arêtiers', ml(t.arete)], ['Noues', ml(t.noue)]];
  const site = [
    ['Zone de vent', e.vent || ''], ['Zone de neige', e.neige || ''], ['Altitude', (e.alt !== undefined && e.alt !== null && e.alt !== '') ? e.alt + ' m' : ''],
    ['Zone sismique', f.sismicite || '']
  ];
  const vide = v => v === '' || v === undefined || v === null;
  if (![...charpente, ...surfaces, ...longueurs].some(([, v]) => !vide(v))) return [];
  const net = L => L.map(([a, v]) => [a, vide(v) ? 'non renseigné' : String(v)]);
  // Groupes : une structure par toiture, puis couverture et longueurs ; les données du site dans un encadré à part
  return [
    ...toitsL.map((tt, i) => ({ titre: plusieurs ? `Structure de la charpente — ${nomToit(tt, i)}` : 'Structure de la charpente', lignes: net(structure(tt)) })),
    { titre: 'Couverture', lignes: net(surfaces) },
    { titre: 'Longueurs', lignes: net(longueurs) },
    { titre: 'Données du site (étude de faisabilité)', lignes: net(site), site: true }
  ];
}
function recapCharpenteHtml(lotId) {
  const G = recapCharpente(lotId); if (!G.length) return '';
  const liste = g => `<div style="font-weight:700;font-size:12px;color:#2b2b2b;margin:6px 0 2px">${esc(g.titre)}</div>${g.lignes.map(([a, v]) => `<div style="font-size:12px;margin:1px 0"><strong>${esc(a)}</strong> : ${esc(v)}</div>`).join('')}`;
  const charp = G.filter(g => !g.site), site = G.find(g => g.site);
  return `<div class="gen-bloc"><div class="gen-titre">Récapitulatif pour le calcul de charpente</div>
    <div style="display:flex;flex-wrap:wrap;gap:12px;align-items:flex-start">
      <div style="flex:2 1 320px;min-width:0">${charp.map(liste).join('')}</div>
      ${site ? `<div style="flex:1 1 220px;min-width:0;border:1.5px solid #E07838;border-radius:8px;padding:6px 10px;background:#fffaf4">${liste(site)}</div>` : ''}
    </div></div>`;
}
function genHtml(lotId, numLot) {
  const g = genDuLot(lotId);
  if (!g) return '';
  let h = `<div class="gen-bloc"><div class="gen-titre">${numLot}.0 · Généralités : ${esc(g.titre)}</div>`;
  sectionsDuLot(lotId).forEach((s, k) => {
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
      actualiserMetre();
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
  // Menuiseries et fermetures : le nombre reprend déjà la quantité, on indique « suivant plan » à la place
  if (l.menBloc) return [{ nom: '', v: 'suivant plan' }];
  // Électricité : les lignes de la norme indiquent « norme NF C 15-100 » ; un ajout hors norme n'a aucun détail
  const oE = BIB && BIB.ouvrages.find(x => x.id === l.ouvrage);
  const elecNorme = !!(oE && oE.lot === 'electricite');
  if (elecNorme) return (l.pieceNv || l.projet || l.auto) ? [{ nom: '', v: 'norme NF C 15-100' }] : [];
  // Appuis de fenêtre : longueur reprise des menuiseries, indiquée suivant plan
  { const oA = BIB && BIB.ouvrages.find(x => x.id === l.ouvrage); if (oA && /^Appui de fenêtre /.test(oA.designation)) return [{ nom: '', v: 'suivant plan' }]; }
  const noms = { nombre: 'nb', cote1: 'L', cote2: 'l', cote3: 'h', largeur_cm: 'larg.', hauteur_cm: 'haut.' };
  const o = BIB && BIB.ouvrages.find(x => x.id === l.ouvrage);
  const mode = l.modeLigne && l.modeLigne !== 'coef' ? modeDe(o.unite, l.modeLigne) : (o && o.mesure ? modeDe(o.unite, o.mesure) : null);
  if (mode) mode.cotes.forEach((c, i) => { noms['cote' + (i + 1)] = c[0]; });   // L, l ou H selon le mode
  if (l.modeLigne === 'coef') { noms.nombre = 'coef.'; noms.cote1 = 'S'; }   // bande à joint : surface S × coefficient
  // Un m² n'a pas de largeur : le « l 1 » enregistré est un simple coefficient neutre (L × 1 = L), on ne l'affiche pas
  const m2 = o && o.unite === 'm²';
  const det = Object.entries(l.valeurs || {})
    .filter(([k, v]) => v !== '' && v != null && !(m2 && k === 'cote2' && String(v) === '1') && !(l.modeLigne === 'lxh' && k === 'nombre') && !(l.modeLigne === 'coef' && k === 'cote2'))
    // Valeurs numériques arrondies à deux décimales (ex. 144,9819 → 144,98), comme partout ailleurs
    .map(([k, v]) => ({ nom: noms[k] || '', v: /^-?\d+([.,]\d+)?$/.test(String(v).trim()) ? fmt(Number(String(v).replace(',', '.'))) : v }));
  return det;
}
// Texte simple (exports CSV, Excel)
function detail(l) {
  // Détail écrit à la main ou par le calcul : même texte à l'écran et dans les exports
  if (l.detailTexte && (l.modeLigne === 'texte' || !avecFormule(l))) return l.detailTexte;
  const v0 = l.valeurs || {};
  // Murs (élévations et soubassements) : même texte que l'écran, sans les cotes techniques (nombre 1, etc.)
  if (v0.src && /^(Calcul du configurateur : )?(murs, surface nette|Longueur × hauteur des murs)/.test(v0.src)) {
    const tmp = document.createElement('div');
    tmp.innerHTML = detailHtml(l).replace(/<br\s*\/?>/gi, ' — ').replace(/ ; /g, ' ; ');
    return tmp.textContent.replace(/\s+/g, ' ').trim();
  }
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
const SEUIL_DEDUCTION = 1;
// Bloc A (ancien configurateur de pièces) : EN VEILLE. Ses données sont conservées ; il ne produit plus aucune ligne.
const PIECES_ANCIEN_VEILLE = true;
// Murs de soutènement et muret de jardin : surface nette (longueur × hauteur), aucune ouverture déduite
const SOUT_TYPES = [
  { id: 'beton', nom: 'Mur de soutènement béton armé', idOuv: 'OUV-0881', designation: 'Mur de soutènement béton armé (surface nette)', lot: 'terrassement-vrd' },
  { id: 'aggl', nom: 'Mur de soutènement en aggloméré de ciment', idOuv: 'OUV-0882', designation: 'Mur de soutènement en aggloméré de ciment (surface nette)', lot: 'terrassement-vrd' },
  { id: 'muret', nom: 'Muret de jardin', idOuv: 'OUV-0883', designation: 'Muret de jardin (surface nette)', lot: 'amenagement-exterieur' }
];
function detailHtml(l) {
  const v = l.valeurs || {};
  // Texte du détail corrigé à la main (ligne sans formule de cotes)
  if (l.detailTexte && (l.modeLigne === 'texte' || !avecFormule(l))) return esc(l.detailTexte);
  // Plateforme saisie en surface × hauteur : surface mesurée suivant plan, puis × hauteur
  if (v.src === TXT_SURFACE && v.cote1 && v.cote3) {
    const nb = num(v.nombre) > 0 ? num(v.nombre) : 1;
    return (nb !== 1 ? esc(fmt(nb)) + ' × ' : '') + esc(TXT_SURFACE) + ' ' + esc(fmt(num(v.cote1))) + ' m² × hauteur ' + esc(fmt(num(v.cote3))) + ' m';
  }
  if (v.mode === 'plan' || (v.src && /^(Surface du configurateur|Surface mesurée|Calcul suivant plan)/.test(v.src))) return esc(TXT_SURFACE);
  // Surface nette des murs : on liste chaque mur (dimensions prises dans le configurateur du chantier)
  if (v.src && /^(Calcul du configurateur : )?(murs, surface nette|Longueur × hauteur des murs)/.test(v.src)) {
    const c = chantiers.find(x => x.id === courantId);
    const typeLigne = v.typeMur || '';
    const murs = c ? projetDe(c).murs.filter(m => (m.type || '') === typeLigne && m.cat !== 'soub' && num(m.longueur) > 0 && num(m.hauteur) > 0) : [];   // les murs de soubassement ont leur propre article
    // Mêmes couleurs que dans les formules : longueur en vert, hauteur en bleu
    const liste = murs.map((m, i) => `${esc(m.nom || 'Mur ' + (i + 1))} : <span style="color:${COTE_COULEUR.Longueur};font-weight:700">${esc(fmt(num(m.longueur)))} m</span> × <span style="color:${COTE_COULEUR.Hauteur};font-weight:700">${esc(fmt(num(m.hauteur)))} m</span>`).join(' ; ');
    return esc(v.src.replace(/^Calcul du configurateur : /, '').replace(/^murs, surface nette$/, 'Longueur × hauteur des murs, moins les menuiseries égales ou supérieures à 1 m²')) + (liste ? `<br><span style="font-size:11.5px">${liste}</span>` : '');
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
  const vues = { chantiers: 'vChantiers', metre: 'vMetre', tableau: 'vTableau', config: 'vConfig', reglages: 'vReglages', biblio: 'vBiblio', import: 'vImport' };
  if (PAGE === 'tableau') nom = 'tableau';
  for (const k of Object.keys(vues)) { const el = $(vues[k]); if (el) el.classList.toggle('hidden', k !== nom); }
  // Onglet en surbrillance : le métré et le tableau d'un chantier appartiennent à « Chantiers »
  const onglet = { chantiers: 'btnChantiers', metre: 'btnChantiers', tableau: 'btnChantiers', config: 'btnConfig', reglages: 'btnReglages' };
  ['btnChantiers', 'btnConfig', 'btnReglages'].forEach(id => { const b = $(id); if (b) b.classList.toggle('actif', onglet[nom] === id); });
  if (nom === 'metre' || nom === 'tableau') compterLignes();
  if (nom === 'config') {
    piecesDepliees.clear();   // à chaque arrivée dans le configurateur, les pièces sont repliées
    renderPiecesNv();         // et redessinées repliées, même si la vue était déjà affichée
    requestAnimationFrame(dessinerOnglets);
  }
}

// Ligne calculée par le configurateur (ou par un de ses blocs) : on peut revenir à son onglet
function origineLigne(l) {
  return !!(l.platNv || l.projet || l.plat || l.auto || l.peiNv || (l.valeurs && l.valeurs.src));
}
// Onglet du configurateur où se fait le calcul, d'après le lot de la ligne
const ONGLET_DU_LOT = { 'installation-chantier': '0', 'terrassement-vrd': '1', 'gros-oeuvre': '2', 'ossature-bois': '2', 'charpente-structure-bois': '3', 'couverture-zinguerie': '4', 'menuiseries-exterieures': '5', 'isolation-thermique': '6', 'doublages-cloisons-plafonds': 'C', 'electricite': '8', 'plomberie-sanitaire': '9', 'revetements-sols': '10', 'chauffage-vmc-climatisation': '11', 'cuisine': '12', 'peinture-finitions': 'D', 'revetements-muraux': 'D' };
function allerAuConfigurateur(lot, mur) {
  ouvrirConfig();
  const onglet = ONGLET_DU_LOT[lot];
  requestAnimationFrame(() => {
    // Le mur d'origine est repéré par sa carte ; sinon l'onglet de la famille de travaux
    const carteMur = mur ? document.querySelector(`#vConfig [data-k="mur"][data-id="${mur}"]`) : null;
    const cible = carteMur ? carteMur.closest('div[style*="border-bottom"]') || carteMur : [...document.querySelectorAll('#vConfig h2.lot-titre')].find(x => onglet && x.textContent.trim().startsWith(onglet + '.'));
    if (cible) cible.scrollIntoView({ behavior: 'smooth', block: 'center' });
  });
}
document.addEventListener('click', e => {
  const b = e.target.closest && e.target.closest('[data-retour]');
  if (b) allerAuConfigurateur(b.dataset.retour, b.dataset.mur);
});
function compterLignes() {
  const n = courantId ? lignesDe(courantId).length : 0;
  $('nbLignes').textContent = n;
  $('nbLignes2').textContent = n;
}

// Métré du chantier : affiché dans la même fenêtre (plus de nouvelle fenêtre)
function ouvrirTableau() {
  renderMetre();
  route('tableau');
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
  const bouton = $('selLotBouton'); if (bouton) { bouton.style.background = '#E07838'; bouton.style.color = '#fff'; bouton.style.borderColor = '#E07838'; bouton.style.fontWeight = '700'; }
}
function remplirLots() {
  $('selLot').innerHTML = BIB.lots.map(l => `<option value="${esc(l.id)}">${esc(l.nom)}</option>`).join('');
  if (!lotCourant) lotCourant = BIB.lots[0].id;
  $('selLot').value = lotCourant;
  colorerLot();
  renderLotMenuSaisie();
}
// Liste déroulante maison du lot (saisie) : même présentation que la bibliothèque (majuscules, un lot sur deux en orange)
function renderLotMenuSaisie() {
  const id = $('selLot').value;
  const lot = BIB.lots.find(l => l.id === id);
  $('selLotTexte').textContent = lot ? String(lot.nom).toUpperCase() : '';
  $('selLotListe').innerHTML = BIB.lots.map((l, i) => {
    const actif = l.id === id;
    const couleur = i % 2 === 0 ? '#E07838' : 'var(--fg)';
    return `<button type="button" data-lot-saisie="${esc(l.id)}" style="display:block;width:100%;text-align:left;padding:12px;min-height:44px;border:0;border-bottom:1px solid var(--line);background:${actif ? 'var(--line)' : 'transparent'};color:${couleur};font-weight:${i % 2 === 0 ? '700' : '400'};font-size:16px;cursor:pointer">${esc(String(l.nom).toUpperCase())}</button>`;
  }).join('');
}
$('selLotBouton').onclick = () => {
  renderLotMenuSaisie();
  $('selLotListe').classList.toggle('hidden');
};
$('selLotListe').addEventListener('click', e => {
  const b = e.target.closest('[data-lot-saisie]');
  if (!b) return;
  $('selLot').value = b.dataset.lotSaisie;
  $('selLotListe').classList.add('hidden');
  $('selLot').dispatchEvent(new Event('change'));   // même traitement que la liste d'origine
});

function renderOuvrages() {
  figerEntete();
  const q = $('recherche').value.trim().toLowerCase();
  const liste = BIB.ouvrages.filter(o => ouvActif(o) && o.lot === lotCourant && (!q || o.designation.toLowerCase().includes(q)));
  const lignes = liste.map(o => `<div class="ouv" data-ouv="${esc(o.id)}"><span>${esc(o.designation)} <span class="muted" style="font-size:12px">· ${esc(o.id)}</span></span><span class="tag">${esc(o.unite)}</span></div>`).join('');
  $('listeOuvrages').innerHTML = (lignes || '<p class="muted" style="padding:12px">Aucun ouvrage trouvé dans ce lot.</p>')
    + '<div style="padding:12px;display:flex;gap:8px;flex-wrap:wrap"><button class="btn sec" id="bLibre2">+ Ouvrage libre dans ce lot</button><button class="btn sec" id="bLigneLibre">+ Ligne libre (titre, unité et quantité libres)</button></div>';
}

/* ============ Lots du chantier et numérotation ============ */
// Ordre des lots = ordre dans lequel ils ont été ajoutés au métré (pas l'ordre de la bibliothèque)
function lotsDuChantier(id) {
  if (!BIB) return [];
  const c = chantiers.find(x => x.id === id);
  const liste = c && Array.isArray(c.lots) ? [...c.lots] : [];
  for (const l of lignesDe(id)) if (!liste.includes(l.lot)) liste.push(l.lot);
  // Ordre des lots = ordre de la bibliothèque (l'installation de chantier est en haut)
  const rang = lid => BIB.lots.findIndex(x => x.id === lid);
  return liste.filter(lid => BIB.lots.some(x => x.id === lid)).sort((a, b) => rang(a) - rang(b));
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
// Ordre des pièces : glisser la poignée ⋮⋮ d'une carte de pièce pour la placer avant ou après une autre
let glissePiece = null, glisseY = null, glisseDefil = null;
// Carte sous le pointeur : l'élément visé, sinon la carte dont la hauteur contient le pointeur (la barre fixe peut recouvrir l'en-tête)
const cartePieceSous = (x, y) => {
  const el = document.elementFromPoint(x, y);
  const t = el ? el.closest('[data-piece]') : null;
  if (t) return t;
  return [...document.querySelectorAll('[data-piece]')].find(c => { const r = c.getBoundingClientRect(); return y >= r.top && y <= r.bottom; }) || null;
};
const effacerCiblesPiece = () => document.querySelectorAll('[data-piece].cible-avant, [data-piece].cible-apres').forEach(t => t.classList.remove('cible-avant', 'cible-apres'));
document.addEventListener('pointerdown', e => {
  const h = e.target.closest('[data-glisser-piece]');
  if (!h) return;
  e.preventDefault();
  glissePiece = h.dataset.glisserPiece;
  document.body.classList.add('en-glisse');
  // Défilement automatique près des bords de l'écran : la carte visée peut être hors de la zone visible
  glisseDefil = setInterval(() => {
    if (glisseY == null) return;
    if (glisseY < 90) window.scrollBy(0, -14);
    else if (glisseY > window.innerHeight - 90) window.scrollBy(0, 14);
  }, 30);
});
document.addEventListener('pointermove', e => {
  if (!glissePiece) return;
  glisseY = e.clientY;
  effacerCiblesPiece();
  const t = cartePieceSous(e.clientX, e.clientY);
  if (!t || t.dataset.piece === glissePiece) return;
  const r = t.getBoundingClientRect();
  t.classList.add(e.clientY < r.top + r.height / 2 ? 'cible-avant' : 'cible-apres');
});
function finGlissePiece(e) {
  if (!glissePiece) return;
  const id = glissePiece;
  glissePiece = null;
  clearInterval(glisseDefil); glisseDefil = null; glisseY = null;
  document.body.classList.remove('en-glisse');
  effacerCiblesPiece();
  if (e.type !== 'pointerup') return;
  const t = cartePieceSous(e.clientX, e.clientY);
  const c = chantiers.find(x => x.id === courantId);
  if (!t || !c || t.dataset.piece === id) return;
  const r = t.getBoundingClientRect();
  const apres = e.clientY >= r.top + r.height / 2;
  const liste = piecesNvDe(c);
  const [piece] = liste.splice(liste.findIndex(p => p.id === id), 1);
  let idx = liste.findIndex(p => p.id === t.dataset.piece);
  if (apres) idx += 1;
  liste.splice(idx, 0, piece);
  sauverLignes(c.id, ordonnerLignesPieces(c));
  lsSet('chantiers', chantiers); marquerChantier(c.id);
  renderPiecesNv(); renderPlatNv(); renderPeinture();
}
document.addEventListener('pointerup', finGlissePiece);
document.addEventListener('pointercancel', finGlissePiece);
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
// Clé de reconnaissance d'une ligne du configurateur (ouvrage + libellé, sans le suffixe « (rigoles) »)
function cleLigneConfig(l) {
  return l.ouvrage + '|' + String(l.designation || '').replace(/\s*\(rigoles\)$/, '');
}
// Saisie à la main d'un ouvrage déjà produit par le configurateur : la saisie prend sa place (une seule ligne).
// Renvoie la ligne du configurateur remplacée, false si l'utilisateur annule, null s'il n'y a rien à remplacer.
function remplacementConfig(L, o, precedent) {
  if (precedent) return null;
  const auto = L.find(x => x.ouvrage === o.id && !x.vrd && (x.projet || x.auto || x.plat || x.qteAuto));
  if (!auto) return null;
  const ok = confirm('Cet ouvrage est déjà produit par le configurateur sur ce chantier. Remplacer cette ligne par votre saisie ? Le configurateur ne la recréera plus.\n\nOK = remplacer · Annuler = ne rien ajouter');
  return ok ? auto : false;
}
function majLignesDepuisConfigurateur(c) {
  // Jamais pendant une revue (la revue a sa propre collecte)
  if (!c || c.metreGele || _majConfigEnCours || _revueCollecte || !BIB) return;
  _majConfigEnCours = true;
  try {
    const L = lignesDe(c.id);
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
    const sansSource = PIECES_ANCIEN_VEILLE ? new Set() : new Set(L.filter(x => (x.projet || x.auto || x.plat) && !x.qteAuto && x.ouvrage && !produitesC.has(cleL(x))).map(x => x.uid));
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
    const estAutoC = x => !!(x.projet || x.auto || x.plat || x.qteAuto);
    for (const x of Lk) if (x.ouvrage && estAutoC(x)) (pool[cleL(x)] = pool[cleL(x)] || []).push(x);
    const remplacer = new Map(), ajouts = [];
    for (const l of fresh) {
      // Ligne du configurateur remplacée par une saisie à la main : on ne la recrée pas
      if (Lk.some(x => x.repris && x.repris === cleL(l))) continue;
      const ex = pool[cleL(l)] && pool[cleL(l)].shift();
      // Nouvelle ligne du configurateur : ajoutée tout de suite au métré
      if (!ex) { ajouts.push(l); continue; }
      // Le texte du détail (src) compte aussi : un libellé corrigé dans l'application met à jour la ligne existante
      if (sig(ex.valeurs) !== sig(l.valeurs) || (ex.valeurs || {}).src !== (l.valeurs || {}).src || Math.abs(num(ex.quantite) - num(l.quantite)) > 1e-9 || !ex.projet || ex.designation !== l.designation) {
        // On garde prix, surface, uid, date de création ; on met à jour ce que calcule le configurateur
        remplacer.set(ex.uid, Object.assign({}, ex, { designation: l.designation, unite: l.unite, valeurs: l.valeurs, quantite: l.quantite, projet: true, qteAuto: l.qteAuto || ex.qteAuto }));
      }
    }
    if (!remplacer.size && !ajouts.length) return;
    // Nouvelles lignes : ajoutées en fin de lot, sauf les tableaux de fenêtres, placés juste sous l'enduit de leur mur (même ouvrage)
    const nouvelles = Lk.map(x => remplacer.has(x.uid) ? remplacer.get(x.uid) : x);
    for (const a of ajouts) {
      const i = a.designation === 'Tableaux de menuiseries (2 côtés)'
        ? nouvelles.reduce((acc, x, k) => (x.ouvrage === a.ouvrage && x.lot === a.lot ? k : acc), -1) : -1;
      if (i >= 0) nouvelles.splice(i + 1, 0, a); else nouvelles.push(a);
    }
    sauverLignes(c.id, nouvelles);
  } finally { _majConfigEnCours = false; }
}
// Texte des lignes reprises de la bibliothèque : mis à jour quand l'ouvrage est renommé dans la bibliothèque.
// Les lignes du configurateur (libellé calculé, « – Pièce ») gardent leur texte.
function rafraichirDesignations(id) {
  if (_revueCollecte || !id || !BIB) return;
  const L = lignesDe(id);
  let change = false;
  const lotsAvant = new Set();
  const nouvelles = L.map(l => {
    if (!l.ouvrage) return l;
    const o = BIB.ouvrages.find(x => x.id === l.ouvrage && !x.supprime);
    if (!o) return l;
    // Lot : celui de la bibliothèque (une ligne créée avant un changement de lot est mise à jour),
    // sauf les lignes du bloc plâtrerie : leur lot est décidé par le configurateur (isolant avec son doublage ou cloison)
    let nl = l;
    if (!l.platNv && o.lot && o.lot !== l.lot) { lotsAvant.add(l.lot); nl = Object.assign({}, nl, { lot: o.lot }); change = true; }
    if (l.projet || l.plat || l.auto || l.libre || String(l.designation || '').includes(' – ')) return nl;
    if (l.pieceNv && (SOUS_PIECE_LOTS.has(l.lot) || l.lot === 'menuiseries-interieures' || l.menBloc)) return nl;   // lignes du configurateur (menuiseries, blocs, façades) : désignation gardée   // ligne de pièce : son descriptif (blocs portes, façades : dimensions et choix) est gardé tel quel
    if (!o.designation || o.designation === l.designation) return nl;
    change = true;
    return Object.assign({}, nl, { designation: o.designation });
  });
  if (change) sauverLignes(id, nouvelles);
  // Lot d'origine qui n'a plus aucune ligne : retiré de la liste des lots du chantier
  const c = chantiers.find(x => x.id === id);
  if (c && Array.isArray(c.lots) && lotsAvant.size) {
    const encore = new Set(nouvelles.map(x => x.lot));
    const restants = c.lots.filter(x => !(lotsAvant.has(x) && !encore.has(x)));
    if (restants.length !== c.lots.length) { c.lots = restants; lsSet('chantiers', chantiers); marquerChantier(id); }
  }
}
// Surbrillance d'une ligne du métré :
// - mauve : ligne ajoutée automatiquement à cause d'une autre (semelle liée à une fouille, ouvrage lié à une case du configurateur)
// - ambre : ligne saisie à la main
// - rien : lignes produites directement par le configurateur ou reprises telles quelles
function surbrillanceLigne(l) {
  if (l.pieceNv) return l.pieceOption ? 'ligne-option' : '';   // configurateur de pièces : norme NF C 15-100 sans couleur, option ajoutée en bleu
  const oRelie = BIB && BIB.ouvrages ? BIB.ouvrages.find(y => y.id === l.ouvrage) : null;
  const ouvrageRelie = !!(oRelie && (oRelie.lieConfig || oRelie.liePar || oRelie.cotes));
  if (l.vrd || l.lienDe) return 'ligne-lie';
  const manuelle = !(l.projet || l.auto || l.plat || l.platNv || l.qteAuto || l.lien || ouvrageRelie);   // platNv : plâtrerie produite par le configurateur
  return manuelle ? 'ligne-manuelle' : '';
}

// Lots regroupés par pièce au métré : un titre par pièce (ex. « Chambre 1 »), puis ses lignes
const SOUS_PIECE_LOTS = new Set(['electricite', 'revetements-sols']);
function nomPieceMetre(id) {
  if (id === 'maison') return 'Maison (hors pièces)';
  const c = chantiers.find(x => x.id === courantId);
  const p = c ? piecesNvDe(c).find(x => x.id === id) : null;
  return p ? (p.nom || 'Pièce') + (p.qualif ? ' ' + p.qualif : '') : 'Pièce';
}
// Sous-titres du métré (menuiseries, plâtrerie, pièces), calculés une seule fois pour l'écran, l'impression, les documents par lot et l'Excel
const SOUS_TITRES_MEN = { ouv: 'Menuiseries ouvrantes', coul: 'Menuiseries coulissantes', ferm: 'Fermeture - occultation' };
const SOUS_TITRES_PLAT = { cloi: 'Cloisonnement', doub: 'Doublage', pla: 'Plafond' };
function titresAvantLignes(lotId, ls) {
  const vus = new Set();
  let platPrec = null, piecePrec = null;
  return ls.map(l => {
    const t = [];
    if (SOUS_TITRES_MEN[l.menBloc] && !vus.has(l.menBloc)) { vus.add(l.menBloc); t.push(SOUS_TITRES_MEN[l.menBloc]); }
    if (l.platBloc && l.platBloc !== platPrec) t.push(SOUS_TITRES_PLAT[l.platBloc]);
    platPrec = l.platBloc || null;
    if (SOUS_PIECE_LOTS.has(lotId)) { const cleP = l.pieceNv || null; if (cleP && cleP !== piecePrec) t.push(nomPieceMetre(cleP)); piecePrec = cleP; }
    return t;
  });
}
function renderMetre() {
  // Dossier Kanban du chantier courant lu une fois (pour la page de garde et les généralités)
  const cc = chantiers.find(x => x.id === courantId), rc = cc ? refKanbanDe(cc) : '';
  if (rc && !(rc in _kanbanDossiers)) dossierKanban(rc).then(() => { if (typeof renderMetre === 'function') renderMetre(); }).catch(() => {});
  if (!courantId || !BIB) return;
  nettoyerSuffixeRigoles(courantId);
  rafraichirDesignations(courantId);
  majLignesDepuisConfigurateur(chantiers.find(x => x.id === courantId));
  // Semelles béton manquantes ou obsolètes : recalculées depuis les fouilles (enregistrées seulement si changé)
  { const avant = lignesDe(courantId), apres = alignerFondations(avant);
    if (JSON.stringify(apres) !== JSON.stringify(avant)) sauverLignes(courantId, apres); }
  majLignesLiees(courantId);
  majQuantitesAuto(chantiers.find(x => x.id === courantId));
  // Électricité et revêtements suivent l'ordre des pièces du configurateur (les lignes désordonnées sont remises en ordre)
  { const cOrdre = chantiers.find(x => x.id === courantId);
    const avantOrdre = lignesDe(courantId), apresOrdre = ordonnerLignesPieces(cOrdre, avantOrdre.slice());
    if (JSON.stringify(apresOrdre) !== JSON.stringify(avantOrdre)) sauverLignes(courantId, apresOrdre); }
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
    if (i > 0) h += `<tr class="lot-sep" aria-hidden="true"><td colspan="${nc}"></td></tr>`;   // espace marqué entre deux lots
    h += `<tr class="lot" data-lot="${esc(lotId)}"><td colspan="${nc}"><span class="lotnum">${String(i + 1).padStart(2, '0')}</span> ${esc(lot ? lot.nom : lotId)}
      <span class="muted">(${vide ? 'aucune ligne' : ls.length + ' ligne' + (ls.length > 1 ? 's' : '')})</span>
      ${vide ? `<button class="btn small sec" data-retirer-lot="${esc(lotId)}">Retirer</button>` : ''}
      ${aGen ? `<label class="gen-choix"><input type="checkbox" data-gen="${esc(lotId)}" ${coche ? 'checked' : ''}> Généralités dans le métré</label>` : ''}</td></tr>`;
    if (coche) h += `<tr class="gen"><td colspan="${nc}">${genHtml(lotId, i + 1)}</td></tr>`;
    const recapC = recapCharpenteHtml(lotId);
    if (recapC) h += `<tr class="gen"><td colspan="${nc}">${recapC}</td></tr>`;
    const titres = titresAvantLignes(lotId, ls);
    for (const [ii, l] of ls.entries()) {
      for (const t of titres[ii]) h += `<tr class="sous-titre-plat"><td colspan="${nc}" style="font-weight:600;background:#f3f6f9;padding-top:10px">${esc(t)}</td></tr>`;
      const pu = prixUnitaire(l);
      const mt = pu != null ? l.quantite * pu : null;
      if (mt != null) total += mt; else sansPrix++;
      // Surlignage « saisie manuelle » : une ligne d'un ouvrage relié (configurateur, ligne source ou cotes liées) n'en est pas une
      h += `<tr class="ligne ${surbrillanceLigne(l)}" data-uid="${esc(l.uid)}" data-lot="${esc(lotId)}">
        <td class="numl"><span class="poignee" data-glisser-ligne="${esc(l.uid)}" title="Glisser pour déplacer l'ouvrage">⋮⋮</span>${nums[l.uid]}</td>
        <td>${esc(l.designation)}${origineLigne(l) ? ` <button class="btn small sec" data-retour="${esc(l.lot)}" data-mur="${esc((l.origine || {}).mur || '')}" title="Revenir au configurateur à l'endroit du calcul" style="margin-left:4px;min-height:26px;padding:2px 8px">↩ Configurateur</button>` : ''}${(BIB.ouvrages.find(x => x.id === l.ouvrage) || {}).detail ? `<div class="ouv-detail" style="font-style:italic;font-size:12px;color:#6b7280;margin-top:2px">${esc(BIB.ouvrages.find(x => x.id === l.ouvrage).detail)}</div>` : ''}</td>
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
  const surb = lignesDe(courantId).map(surbrillanceLigne);
  const nbLiees = surb.filter(x => x === 'ligne-lie').length, nbManuelles = surb.filter(x => x === 'ligne-manuelle').length, nbOptions = surb.filter(x => x === 'ligne-option').length;
  const legOpt = nbOptions ? '<span class="pastille pastille-option"></span> option ajoutée en plus de la norme NF C 15-100 ' : '';
  if (nbOptions || nbLiees || nbManuelles) h = `<p class="legende-manuel">${legOpt}${nbLiees ? '<span class="pastille pastille-lie"></span> ajouté à cause d\'une autre ligne ' : ''}${nbManuelles ? '<span class="pastille pastille-manuel"></span> saisi à la main' : ''}</p>` + h;
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
  "Chambre": "Chambre", "Bureau": "Bureau", "Salon": "Séjour", "Séjour": "Séjour", "Pièce de vie": "Séjour",
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
  if (PIECES_ANCIEN_VEILLE) return 'Ancien configurateur de pièces en veille : aucune ligne générée.';
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


/* ============ Configurateur de pièces (nouveau bloc) ============ */
// Par pièce : surface au sol + revêtement, portes fin de chantier, menuiseries extérieures, appareillage de la pièce seulement.
// Stocké dans c.elec.piecesNv. Les lignes produites portent pieceNv (id de la pièce) et sont remplacées à chaque génération.
const PNV_APPAREIL = [
  { cle: 'prises', libelle: 'Prises de courant', des: 'Prise de courant 16 A' },
  { cle: 'rj45', libelle: 'Prise RJ45', des: 'Prise RJ45 (réseau)' },
  { cle: 'interrup', libelle: 'Interrupteurs simples (allumage)', des: 'Interrupteur simple allumage (point)' },
  { cle: 'vv', libelle: 'Interrupteurs va-et-vient', des: 'Interrupteur va-et-vient (point)' },
  { cle: 'points', libelle: 'Points lumineux', des: 'Point lumineux plafonnier' },
  { cle: 'rasoir', libelle: 'Prise rasoir', des: 'Prise rasoir (transformateur 20-50 VA, hors volume de sécurité)' },
  { cle: 'tv', libelle: 'Prise TV', des: 'Prise TV' },
  { cle: 'hotte', libelle: 'Prise hotte', des: 'Prise hotte 16 A (à 1,80 m)' },
  { cle: 'plaque', libelle: 'Plaque de cuisson (32 A)', des: 'Circuit spécialisé plaque de cuisson 32 A' },
  { cle: 'four', libelle: 'Four (16 A)', des: 'Circuit spécialisé four 16 A' },
  { cle: 'lvaisselle', libelle: 'Lave-vaisselle (16 A)', des: 'Circuit spécialisé lave-vaisselle 16 A' },
  { cle: 'llinge', libelle: 'Lave-linge (16 A)', des: 'Circuit spécialisé lave-linge 16 A' },
  { cle: 'sechelinge', libelle: 'Sèche-linge (16 A)', des: 'Circuit spécialisé sèche-linge 16 A' },
  { cle: 'chauffeau', libelle: 'Chauffe-eau (20 A)', des: 'Circuit spécialisé chauffe-eau 20 A' }
];
const PNV_PORTES = { '63': 'Bloc-porte fin de chantier 63×204', '73': 'Bloc-porte fin de chantier 73×204', '83': 'Bloc-porte fin de chantier 83×204', '93': 'Bloc-porte fin de chantier 93×204', '103': 'Bloc-porte fin de chantier 103×204' };
// Sens d'ouverture des portes de passage (information, ne modifie aucun ouvrage)
const PNV_SENS_PORTE = { droite: 'poussant à droite', gauche: 'poussant à gauche' };
// Choix du bloc porte (un ouvrage de la bibliothèque par combinaison, voir le lot menuiseries-interieures)
const BP_CHOIX = {
  dim: ['63×204', '73×204', '83×204', '93×204', '103×204'],
  dest: ['de communication', 'acoustique', 'de service isothermique', 'technique coupe-feu EI30', 'palière thermique', 'palière acoustique', 'palière blindage de sécurité', 'fin de chantier', 'palière coupe-feu'],
  pousse: ['poussant droit', 'poussant gauche'],
  ame: ['âme alvéolaire', 'âme pleine', 'âme tubulaire'],
  type: ['isoplane', 'postformé', 'vitré'],
  fin: ['rive droite', 'recouvrement'],
  pose: ['pose traditionnelle', 'pose fin de chantier', 'pose rénovation']
};
for (const k of Object.keys(BP_CHOIX)) BP_CHOIX[k] = BP_CHOIX[k].map(t => [t, t]);
// Nombre de portes de passage d'une pièce (somme des blocs portes) ; largeur : 83 cm
const LARGEUR_PORTE_NV = 0.83;
// Intitulé du métré : « Bloc-porte » + dimension choisie + reste de la désignation
function intituleBloc(designation, dim) { return designation.replace('Bloc-porte ', 'Bloc-porte ' + (dim || '83×204') + ' '); }
// Ouvrage de la bibliothèque déduit des choix du bloc porte (sans sélection manuelle).
// Destination « fin de chantier » (une désignation par dimension) et « palière coupe-feu » : cas particuliers, les autres choix sont sans objet.
// Retourne { o, intitule } ou { manque } si un choix est incomplet ou si l'ouvrage n'existe pas.
function ouvrageBloc(bl) {
  const dim = bl.dim || '83×204';
  let designation, intitule;
  if (bl.dest === 'fin de chantier') { designation = `Bloc-porte fin de chantier ${dim}`; intitule = designation; }
  else if (bl.dest === 'palière coupe-feu') { designation = 'Bloc-porte palière coupe-feu'; intitule = intituleBloc(designation, dim); }
  else {
    if (!['dest', 'pousse', 'ame', 'type', 'fin', 'pose'].every(c => bl[c])) return { manque: 'Bloc porte : choix à compléter' };
    designation = `Bloc-porte ${bl.dest}, ${bl.pousse}, ${bl.ame}, ${bl.type}, finition ${bl.fin}, ${bl.pose}`;
    intitule = intituleBloc(designation, dim);
  }
  const o = BIB.ouvrages.find(x => x.designation === designation && !x.supprime);
  return o ? { o, intitule } : { manque: 'Bloc porte : ouvrage absent de la bibliothèque (' + designation + ')' };
}
function nbPortesNv(p) { return (p.blocs || []).reduce((a, bl) => a + num(bl.nb), 0); }
// Spots encastrés, formule de la fiche : Surface (m²) × Lux recommandés = Lumens totaux ; Lumens totaux ÷ Lumens par spot = nombre de spots (arrondi au supérieur)
// Lux recommandés : valeurs retenues par Mathieu (entrée/couloir 150, chambre/séjour 200, cuisine 300, bureau 350, salle de bains et salle d'eau 400, WC et buanderie/cellier 150)
const SPOT_LUX = { 'Entrée / dégagement': 150, 'Chambre': 200, 'Séjour': 200, 'Cuisine': 300, 'Bureau': 350, 'Salle de bains': 400, 'Salle d\'eau': 400, 'WC': 150, 'Buanderie / cellier': 150 };
// Lumens émis par un spot : 450 lm, valeur de l'exemple de la fiche (salon 20 m² → 7 à 8 spots)
const SPOT_LUMENS = 450;
// Éclairage du plafond d'une pièce : 'spots' seulement si la pièce a une règle de spots, sinon point lumineux
function eclairagePiece(p) {
  return p.eclairage === 'spots' && SPOT_LUX[typePieceNv(p.nom) || ''] ? 'spots' : 'point';
}
function nbSpots(p) {
  const lux = SPOT_LUX[typePieceNv(p.nom) || ''];
  const surf = num(p.surf);
  return lux && surf > 0 ? Math.ceil(surf * lux / SPOT_LUMENS) : 0;
}
// Type de pièce (règles de calcul) déduit du nom saisi ou du plan : nom exact, sinon mot-clé
const MOTS_TYPE_PIECE = [
  [/toilette|\bwc\b/i, 'WC'], [/salle d.eau/i, "Salle d'eau"], [/salle de bain|\bsdb\b/i, 'Salle de bains'],
  [/chambre/i, 'Chambre'], [/bureau/i, 'Bureau'], [/salon|s[ée]jour|pi[èe]ce de vie/i, 'Séjour'],
  [/cuisine/i, 'Cuisine'], [/dressing/i, 'Dressing'], [/cellier|buanderie/i, 'Buanderie / cellier'],
  [/\bdgt|d[ée]gagement|couloir|entr[ée]e/i, 'Entrée / dégagement'], [/cave/i, 'Cave'], [/garage/i, 'Garage'],
  [/mezzanine/i, 'Mezzanine'], [/escalier/i, "Cage d'escalier"], [/terrasse/i, 'Extérieur (terrasse)']
];
function typePieceNv(nom) {
  const t = String(nom || '').trim();
  if (ELEC_PIECE_TYPES[t]) return ELEC_PIECE_TYPES[t];
  const m = MOTS_TYPE_PIECE.find(([re]) => re.test(t));
  return m ? m[1] : '';
}
function piecesNvDe(c) {
  c.elec = c.elec || { pieces: [] };
  c.elec.piecesNv = c.elec.piecesNv || [];
  return c.elec.piecesNv;
}
function ouvrageParDesig(des) { return BIB.ouvrages.find(o => o.designation === des && !o.supprime); }
// Portes et baies de la bibliothèque « Menuiseries extérieures » : elles sont déduites du linéaire de plinthes
function menusPorteBaie() {
  return BIB.ouvrages.filter(o => o.lot === 'menuiseries-exterieures' && ouvActif(o) && /^(Porte|Baie)/i.test(o.designation));
}
// Appareillage par défaut d'une pièce, d'après les repères NF C 15-100 (infographie Legrand « Les prises de courant »).
// Une valeur saisie à la main prime toujours.
// Désignation de l'ouvrage à mettre au métré : la terrasse reçoit des équipements extérieurs
function desPnv(p, a) {
  const regle = typePieceNv(p.nom) || '';
  if (regle === 'Extérieur (terrasse)') {
    if (a.cle === 'prises') return 'Prise extérieure étanche';
    if (a.cle === 'points') return 'Éclairage extérieur (applique ou borne)';
    if (a.cle === 'interrup') return 'Interrupteur à voyant témoin pour prise extérieure';
  }
  return a.des;
}
function appDefaut(p, cle) {
  if (p.app && p.app[cle] !== undefined && p.app[cle] !== '') return String(p.app[cle]);
  const regle = typePieceNv(p.nom) || '';
  const surf = num(p.surf);
  // Sans surface saisie, les prises qui dépendent de la surface restent vides (pas de valeur devinée)
  const surfVide = String(p.surf ?? '').trim() === '';
  const fixe = ['Chambre', 'Bureau', 'Salle de bains', 'Salle d\'eau', 'WC', 'Garage', 'Cave', 'Mezzanine', 'Cage d\'escalier', 'Extérieur (terrasse)'];
  if (cle === 'prises' && surfVide && !fixe.includes(regle)) return '';
  if (cle === 'points') return String(Math.max(1, Math.ceil(num(p.surf) / 20)));   // 1 point par tranche de 20 m² (arrondi au supérieur), 1 minimum
  // allumage : simple pour cuisine, dressing, salle de bains, salle d'eau, WC ; aucun pour chambre, séjour, couloir (va-et-vient)
  // va-et-vient : couloir, chambre, séjour (1 point chacun) ; cuisine (1 en plus du simple)
  if (cle === 'interrup') {
    const simple = { 'Cuisine': '1', 'Dressing': '1', 'Salle de bains': '1', 'Salle d\'eau': '1', 'WC': '1', 'Chambre': '0', 'Séjour': '0', 'Entrée / dégagement': '0', 'Cage d\'escalier': '0' };
    return regle in simple ? simple[regle] : '1';
  }
  // cage d'escalier : 1 point en va-et-vient (une commande à chaque étage)
  if (cle === 'vv') return ['Chambre', 'Séjour', 'Entrée / dégagement', 'Cuisine', 'Cage d\'escalier'].includes(regle) ? '1' : '0';
  // RJ45 : séjour 2 (près du coin TV), chambre 1, bureau 1, cuisine 1
  if (cle === 'rj45') return ({ 'Séjour': '2', 'Chambre': '1', 'Bureau': '1', 'Cuisine': '1' })[regle] || '';
  if (cle === 'tv') return regle === 'Séjour' ? '1' : '';
  if (cle === 'hotte') return regle === 'Cuisine' ? '1' : '';
  // gros appareils : une ligne spécialisée par appareil (cuisine ; buanderie / cellier)
  if (cle === 'plaque' || cle === 'four' || cle === 'lvaisselle') return regle === 'Cuisine' ? '1' : '';
  if (cle === 'llinge' || cle === 'sechelinge' || cle === 'chauffeau') return regle === 'Buanderie / cellier' ? '1' : '';
  // prises : séjour 5 (< 28 m²) ou 7 (≥ 28 m²) ; chambre 3 ; bureau 3 ; cuisine 3 (≤ 4 m²) ou 6 (> 4 m², dont 4 au-dessus du plan de travail)
  // salle de bains et salle d'eau : 1 prise hors volumes ; WC : aucune ; autres pièces de plus de 4 m² : 1
  if (cle === 'rasoir') return (regle === 'Salle de bains' || regle === 'Salle d\'eau') ? '1' : '';
  if (regle === 'Séjour') return String(surf >= 28 ? 7 : 5);
  if (regle === 'Chambre' || regle === 'Bureau') return '3';
  if (regle === 'Cuisine') return surf > 4 ? '6' : '3';
  if (regle === 'Salle de bains' || regle === 'Salle d\'eau') return '1';
  if (regle === 'WC') return '0';
  // garage 2 prises ; cave, mezzanine et terrasse 1 prise (terrasse : prise extérieure étanche) ; cage d'escalier aucune
  if (regle === 'Garage') return '2';
  if (regle === 'Cave' || regle === 'Mezzanine' || regle === 'Extérieur (terrasse)') return '1';
  if (regle === 'Cage d\'escalier') return '0';
  // entrée / dégagement (couloir) : 1 prise obligatoire, 2 si la pièce dépasse 4 m²
  if (regle === 'Entrée / dégagement') return surf > 4 ? '2' : '1';
  return surf > 4 ? '1' : '0';
}
// Façades de placard de la bibliothèque (coulissant ou battant), choisies dans une liste
function facadesPlacard() { return BIB.ouvrages.filter(o => ouvActif(o) && /^Façade de placard/i.test(o.designation)); }
// Largeur totale des façades posées au sol (ml) : elles ne reçoivent pas de plinthe
// Façades de placard : choix du configurateur (comme les menuiseries). Ouvrage de base automatique : coulissant ou battant
const FA_CHOIX = {
  vantaux: [['1', '1 vantail'], ['2', '2 vantaux'], ['3', '3 vantaux'], ['4', '4 vantaux']],   // battant ou pliant uniquement
  ouvrant: [['francaise', 'Ouvrant à la française'], ['coulissante', 'Coulissante'], ['acordeon', 'Accordéon']],
  structure: [['m10', 'Panneau mélaminé standard 10 mm'], ['m12', 'Panneau mélaminé standard 12 mm'], ['m18', 'Panneau mélaminé épais 18 mm'], ['m19', 'Panneau mélaminé épais 19 mm'], ['mdf', 'Panneau MDF à peindre'], ['persienne', 'Persienne ajourée']],
  finition: [['uni', 'Décor uni (blanc, gris, anthracite)'], ['bois', 'Décor imitation bois (chêne, aspect brut, noyer)'], ['argent', 'Miroir argenté'], ['teinte', 'Miroir teinté (bronze ou gris)'], ['laque', 'Verre laqué']],
  pose: [['entre', 'Pose entre murs'], ['fileur', 'Pose avec fileur latéral'], ['joue', 'Pose avec joue de terminaison'], ['rampant', 'Pose sous rampant']],
  amort: [['oui', 'Compris amortisseur de fin de course'], ['non', 'Non compris amortisseur de fin de course']]
};
const FA_BASE = { coulissante: 'OUV-1837', francaise: 'OUV-1838', acordeon: 'OUV-1838' };   // comptées à l'unité
function designationFacade(f) {
  const txt = (champ, v) => libelleFixe('fa-' + champ, v, (FA_CHOIX[champ].find(([x]) => x === v) || [])[1] || '');
  const battant = f.ouvrant !== 'coulissante';
  const dims = num(f.l) > 0 && num(f.h) > 0 ? `${fmt(num(f.l))}×${fmt(num(f.h))} cm` : '';
  // Même logique que le bloc porte : dimension en tête, puis tous les choix tels que saisis
  return ['Façade de placard', dims, battant && f.vantaux ? txt('vantaux', f.vantaux).toLowerCase() : '', txt('ouvrant', f.ouvrant), txt('structure', f.structure), txt('finition', f.finition), txt('pose', f.pose), txt('amort', f.amort)].filter(Boolean).join(', ');
}
function facadesLargeur(p) { return (p.facades || []).filter(f => num(f.l) > 0).reduce((a, f) => a + (num(f.nb) || 1) * num(f.l) / 100, 0); }
// Fermetures et occultations : ouvrage de la bibliothèque pour chaque choix (absent = à créer)
const FERM_OUV = { 'vr-manuel': 'OUV-0178', 'vr-motor': 'OUV-0177', 'vr-solaire': 'OUV-1745', 'vb-pvc': 'OUV-1746', 'vb-alu': 'OUV-0180', 'vb-bois': 'OUV-0179', 'brise': 'OUV-0592', 'screen': 'OUV-0182', 'banne': 'OUV-0181' };
const MOUST_OUV = { integree: 'OUV-0183', independante: 'OUV-1747' };
// Menuiseries extérieures (tableau de référence) : listes de choix, une par ligne du tableau
const ME_CHOIX = {
  type: [['fen', 'Fenêtre'], ['pf', 'Porte-fenêtre'], ['pe', "Porte d'entrée"]],
  mat: [['pvc', 'PVC'], ['alu', 'Aluminium'], ['bois', 'Bois'], ['mixte', 'Mixte bois/aluminium'], ['acier', 'Acier']],
  vantaux: [['1', '1 vantail'], ['2', '2 vantaux'], ['3', '3 vantaux'], ['4', '4 vantaux']],
  ouvrant: [['francaise', 'Ouvrant à la française'], ['anglaise', "Ouvrant à l'anglaise"], ['oscillo', 'Oscillo-battant'], ['abattant', 'Abattant'], ['coulissante', 'Coulissante'], ['galandage', 'Coulissante à galandage'], ['translation', 'Coulissante à translation'], ['fixe', 'Châssis fixe'], ['guillotine', 'Ouvrant à guillotine'], ['basculant', 'Ouvrant basculant'], ['pivotant', 'Ouvrant pivotant']],
  vitrage: [['simple', 'Simple vitrage'], ['double', 'Double vitrage standard'], ['vir', 'Double vitrage VIR'], ['triple', 'Triple vitrage']],
  esth: [['clair', 'Clair'], ['imprime', 'Imprimé (ou granité)'], ['depoli', 'Dépoli'], ['teinte', 'Teinté']],
  secu: [['non', 'Vitrage non sécurisé'], ['feuillete', 'Vitrage sécurisé (feuilleté standard) 44.2'], ['sp10', 'Vitrage de haute sécurité (anti-effraction renforcé) SP10'], ['trempe', 'Vitrage trempé thermiquement'], ['arme', 'Vitrage armé']],
  pose: [['applique', 'Pose en applique'], ['tunnel', 'Pose en tunnel'], ['renovation', 'Pose en rénovation']],
  volet: [['oui', 'Compris fermeture'], ['non', 'Non compris fermeture']],
  ferm: [['vr-manuel', 'Volet roulant manuel'], ['vr-motor', 'Volet roulant motorisé'], ['vr-solaire', 'Volet roulant solaire'], ['vb-pvc', 'Volet battant ou coulissant PVC'], ['vb-alu', 'Volet battant ou coulissant alu'], ['vb-bois', 'Volet battant ou coulissant bois'], ['brise', 'Brise-soleil orientable'], ['screen', 'Store screen extérieur'], ['banne', 'Store banne']],
  moust: [['integree', 'Moustiquaire intégrée au volet'], ['independante', 'Moustiquaire indépendante']]
};
// Ouvrages de la bibliothèque proposés pour un bloc menuiserie extérieure (fenêtres et portes)
function menusBlocOuvrages() {
  return BIB.ouvrages.filter(o => o.lot === 'menuiseries-exterieures' && ouvActif(o) && /^(Fenêtre|Porte-fenêtre|Porte|Baie)/i.test(o.designation));
}
// Menuiseries coulissantes (sous-titre « Menuiseries coulissantes » au métré) ; les autres ouvrants vont sous « Menuiseries ouvrantes »
const MEN_COUL = ['coulissante', 'galandage', 'translation'];
// Ouvrage de base choisi automatiquement selon type + matériau + nombre de vantaux (pas de combinaisons en bibliothèque)
const ME_BASE = { 'pe-pvc-1': 'OUV-1834', 'pe-alu-1': 'OUV-1832', 'pe-bois-1': 'OUV-1833', 'pe-mixte-1': 'OUV-1835', 'pe-acier-1': 'OUV-1836', 'fen-pvc-1': 'OUV-1721', 'fen-pvc-2': 'OUV-1722', 'fen-pvc-3': 'OUV-1723', 'fen-pvc-4': 'OUV-1724', 'fen-alu-1': 'OUV-1725', 'fen-alu-2': 'OUV-1726', 'fen-alu-3': 'OUV-1727', 'fen-alu-4': 'OUV-1728', 'fen-bois-1': 'OUV-1729', 'fen-bois-2': 'OUV-1730', 'fen-bois-3': 'OUV-1731', 'fen-bois-4': 'OUV-1732', 'pf-pvc-1': 'OUV-1733', 'pf-pvc-2': 'OUV-1734', 'pf-pvc-3': 'OUV-1735', 'pf-pvc-4': 'OUV-1736', 'pf-alu-1': 'OUV-1737', 'pf-alu-2': 'OUV-1738', 'pf-alu-3': 'OUV-1739', 'pf-alu-4': 'OUV-1740', 'pf-bois-1': 'OUV-1741', 'pf-bois-2': 'OUV-1742', 'pf-bois-3': 'OUV-1743', 'pf-bois-4': 'OUV-1744' };
function baseMenuiserie(m) {
  const id = ME_BASE[`${m.type}-${m.mat}-${m.vantaux}`];
  return id ? BIB.ouvrages.find(x => x.id === id && !x.supprime) || null : null;
}
// Texte des choix pour la désignation du métré (ex. « Fenêtre 2 vantaux, ouvrant à la française, 100 x 200 cm, simple vitrage… »)
const ME_TXT = {
  type: { fen: 'Fenêtre', pf: 'Porte-fenêtre', pe: "Porte d'entrée" },
  vantaux: { '1': '1 vantail', '2': '2 vantaux', '3': '3 vantaux', '4': '4 vantaux' },
  ouvrant: { francaise: 'ouvrant à la française', anglaise: "ouvrant à l'anglaise", oscillo: 'oscillo-battant', abattant: 'abattant', coulissante: 'coulissante', galandage: 'coulissante à galandage', translation: 'coulissante à translation', fixe: 'châssis fixe', guillotine: 'ouvrant à guillotine', basculant: 'ouvrant basculant', pivotant: 'ouvrant pivotant' },
  vitrage: { simple: 'simple vitrage', double: 'double vitrage standard', vir: 'double vitrage VIR', triple: 'triple vitrage' },
  esth: { clair: 'clair', imprime: 'imprimé (ou granité)', depoli: 'dépoli', teinte: 'teinté' },
  secu: { non: 'non sécurisé', feuillete: 'vitrage feuilleté 44.2', sp10: 'vitrage haute sécurité SP10', trempe: 'vitrage trempé', arme: 'vitrage armé' },
  pose: { applique: 'pose en applique', tunnel: 'pose en tunnel', renovation: 'pose en rénovation' }
};
// Désignation du métré composée à partir des choix du bloc ; volet, fermeture et moustiquaire ont leurs propres lignes
function designationMenuiserie(m) {
  const tx = (c, v) => libelleFixe('me-' + c, v, (ME_TXT[c] || {})[v] || '');
  const mat = (ME_CHOIX.mat.find(([v]) => v === m.mat) || [])[1] || '';
  const dims = num(m.l) > 0 && num(m.h) > 0 ? `${fmt(num(m.l))}×${fmt(num(m.h))} cm` : '';
  // Même logique que le bloc porte et la façade : dimensions en tête, puis tous les choix (type, matériau, vantaux…)
  // Porte d'entrée : seuls type, matériau, vantaux et dimensions comptent (les autres choix sont cachés dans le configurateur)
  if (m.type === 'pe') return [dims, [tx('type', m.type), mat, tx('vantaux', m.vantaux)].filter(Boolean).join(' ')].filter(Boolean).join(', ');
  return [dims, [tx('type', m.type), mat, tx('vantaux', m.vantaux)].filter(Boolean).join(' '), tx('ouvrant', m.ouvrant), tx('vitrage', m.vitrage), tx('esth', m.esth), tx('secu', m.secu), tx('pose', m.pose)].filter(Boolean).join(', ');
}
// Un bloc menuiserie extérieure : mêmes principes que le bloc porte (listes à crayon, dimensions, ouvrage de la bibliothèque, nombre)
function blocMenuiserie(p, m, k) {
  const id = esc(p.id);
  const porte = m.type === 'pe';   // porte d'entrée : seuls le type, le matériau, les vantaux, les dimensions et le nombre comptent
  const sel = (champ, lib, vide) => `<div style="flex:1;min-width:150px;font-size:12px"><div style="margin-bottom:2px">${lib}</div>${selCrayon('me-' + champ, 'Menuiserie : ' + lib.toLowerCase(), `<select data-nv="${id}|menu|${k}|${champ}" style="width:100%;min-width:0">${optCodes('me-' + champ, 'Menuiserie : ' + lib.toLowerCase(), ME_CHOIX[champ], m[champ] || '', vide)}</select>`)}</div>`;
  return `<div class="row" style="flex-wrap:wrap;gap:6px;margin-top:4px;align-items:center;border:1px solid #e0c9a6;border-radius:8px;padding:6px;background:#fff">
    ${sel('type', 'Type', '— choisir —')}
    ${sel('mat', 'Matériau', '— choisir —')}
    ${sel('vantaux', 'Nombre de vantaux', '— choisir —')}
    ${porte ? '' : sel('ouvrant', "Type d'ouvrant", '— choisir —')}
    <div style="flex:1;min-width:150px;font-size:12px"><div style="margin-bottom:2px">Dimensions L × H (cm)</div><span style="display:flex;gap:4px"><input data-nv="${id}|menu|${k}|l" inputmode="decimal" value="${esc(m.l || '')}" placeholder="Larg." style="width:50%;min-width:0"><input data-nv="${id}|menu|${k}|h" inputmode="decimal" value="${esc(m.h || '')}" placeholder="Haut." style="width:50%;min-width:0"></span></div>
    ${porte ? '' : sel('vitrage', 'Vitrage', '— choisir —')}
    ${porte ? '' : sel('esth', 'Esthétique', '— choisir —')}
    ${porte ? '' : sel('secu', 'Sécurité', '— choisir —')}
    ${porte ? '' : sel('pose', 'Type de pose', '— choisir —')}
    ${porte ? '' : sel('volet', 'Fermeture', '— choisir —')}
    ${!porte && m.volet === 'oui' ? sel('ferm', 'Type de fermeture', '— choisir —') : ''}
    ${porte ? '' : sel('moust', 'Moustiquaire', '— aucune —')}
    <div style="font-size:12px"><div style="margin-bottom:2px">Unité</div><input data-nv="${id}|menu|${k}|nb" inputmode="numeric" value="${esc(m.nb || '')}" style="width:70px"></div>
    <button type="button" class="btn small danger" style="align-self:flex-end;flex:0 0 auto" data-nv-act="delmenu:${id}:${k}">✕</button></div>`;
}
function blocFacade(p, f, k) {
  const id = esc(p.id);
  const sel = (champ, lib, vide) => `<div style="flex:1;min-width:150px;font-size:12px"><div style="margin-bottom:2px">${lib}</div>${selCrayon('fa-' + champ, 'Façade de placard : ' + lib.toLowerCase(), `<select data-nv="${id}|facade|${k}|${champ}" style="width:100%;min-width:0">${optCodes('fa-' + champ, 'Façade de placard : ' + lib.toLowerCase(), FA_CHOIX[champ], f[champ] || '', vide)}</select>`)}</div>`;
  return `<div class="row" style="flex-wrap:wrap;gap:6px;margin-top:4px;align-items:center;border:1px solid #e0c9a6;border-radius:8px;padding:6px;background:#fff">
    ${sel('ouvrant', "Type d'ouvrant", '— choisir —')}
    ${f.ouvrant && f.ouvrant !== 'coulissante' ? sel('vantaux', 'Nombre de vantaux', '— choisir —') : ''}
    <div style="flex:1;min-width:150px;font-size:12px"><div style="margin-bottom:2px">Dimensions L × H (cm)</div><span style="display:flex;gap:4px"><input data-nv="${id}|facade|${k}|l" inputmode="decimal" value="${esc(f.l || '')}" placeholder="Larg." style="width:50%;min-width:0"><input data-nv="${id}|facade|${k}|h" inputmode="decimal" value="${esc(f.h || '')}" placeholder="Haut." style="width:50%;min-width:0"></span></div>
    ${sel('structure', 'Structure du panneau', '— choisir —')}
    ${sel('finition', 'Esthétique & finitions', '— choisir —')}
    ${sel('pose', 'Type de pose', '— choisir —')}
    ${sel('amort', 'Amortisseur', '— choisir —')}
    <div style="font-size:12px"><div style="margin-bottom:2px">Unité</div><input data-nv="${id}|facade|${k}|nb" inputmode="numeric" value="${esc(f.nb || '')}" style="width:70px"></div>
    <button type="button" class="btn small danger" style="align-self:flex-end;flex:0 0 auto" data-nv-act="delfacade:${id}:${k}">✕</button></div>`;
}
function estPorteBaie(m) { const b = baseMenuiserie(m); return !!b && menusPorteBaie().some(o => o.id === b.id); }
// Pièces repliées dans le configurateur (on ne voit que le nom de la pièce)
// Pièces dépliées : toutes repliées par défaut ; réinitialisé à chaque arrivée dans le configurateur
const piecesDepliees = new Set();
function renderPiecesNv() {
  const host = $('cfgPiecesNv');
  if (!host) return;
  const c = chantiers.find(x => x.id === courantId);
  if (!c || !BIB) { host.innerHTML = ''; return; }
  const liste = piecesNvDe(c);
  const revets = BIB.ouvrages.filter(o => o.lot === 'revetements-sols' && ouvActif(o));
  const optRev = sel => `<option value="">— choisir —</option>` + revets.map(o => `<option value="${esc(o.id)}" ${o.id === sel ? 'selected' : ''}>${esc(o.designation)}</option>`).join('');
  const carte = (p) => { const rep = !piecesDepliees.has(p.id); return `<div class="sousbloc" data-piece="${esc(p.id)}" style="padding:10px;margin:10px 0">
    <div class="row" style="justify-content:flex-start;align-items:center;gap:6px">
      <button type="button" class="btn sec small" data-piece-act="fold:${esc(p.id)}" title="${rep ? 'Déplier la pièce' : 'Replier la pièce'}" style="flex:0 0 auto;padding:2px 10px;font-size:16px">${rep ? '▸' : '▾'}</button>
      <button type="button" class="btn sec small" data-piece-act="haut:${esc(p.id)}" title="Monter la pièce" style="flex:0 0 auto;padding:2px 10px;font-size:16px">↑</button>
      <button type="button" class="btn sec small" data-piece-act="bas:${esc(p.id)}" title="Descendre la pièce" style="flex:0 0 auto;padding:2px 10px;font-size:16px">↓</button>
      <span data-glisser-piece="${esc(p.id)}" title="Glisser pour changer l'ordre des pièces" style="cursor:grab;touch-action:none;user-select:none;font-size:20px;padding:0 6px;color:var(--mut);flex:0 0 auto">⋮⋮</span>
      <input list="dlPiecesNv" data-nv="${esc(p.id)}|nom" value="${esc(p.nom || '')}" placeholder="Nom de la pièce (ex. Chambre parentale)" style="flex:1 1 160px;min-width:0;font-weight:700">
      <input data-nv="${esc(p.id)}|qualif" inputmode="numeric" value="${esc(p.qualif || '')}" placeholder="n°" title="Numéro (Chambre 1, Chambre 2…)" style="flex:0 0 64px;width:64px">
      <button type="button" class="btn small danger" style="flex:0 0 auto" data-nv-act="del:${esc(p.id)}">Supprimer la pièce</button>
    </div>
    <div class="piece-corps" style="${rep ? 'display:none' : ''}">
    <div class="row" style="flex-wrap:wrap;gap:6px;margin-top:6px">
      <label style="font-size:12px">Surface au sol m² <input data-nv="${esc(p.id)}|surf" inputmode="decimal" value="${esc(p.surf || '')}" style="width:90px"></label>
      <label style="font-size:12px">Linéaire ml <input data-nv="${esc(p.id)}|perim" inputmode="decimal" value="${esc(p.perim || '')}" style="width:90px"></label>
      ${selCrayon('nv-revet', 'Revêtement de la pièce', `<select data-nv="${esc(p.id)}|revet" style="flex:1;min-width:0">${optDesignationsId('nv-revet', 'Revêtement de la pièce', () => revets.map(o => o.designation), p.revet, '— choisir —')}</select>`)}
    </div>
    <div style="margin-top:8px"><strong style="font-size:13px">Menuiseries extérieures</strong></div>
    ${(p.menus || []).map((m, k) => blocMenuiserie(p, m, k)).join('')}
    <button type="button" class="btn sec small" style="margin-top:6px" data-nv-act="addmenu:${esc(p.id)}">+ Menuiserie extérieure</button>
    <div style="margin-top:8px"><strong style="font-size:13px">Portes de passage fin de chantier (bloc porte)</strong></div>
    ${(p.blocs || []).map((bl, k) => `<div class="row" style="flex-wrap:wrap;gap:6px;margin-top:4px;align-items:center;border:1px solid #e0c9a6;border-radius:8px;padding:6px;background:#fff">
      ${[['dest', 'Destination'], ['dim', 'Dimensions'], ['pousse', 'Poussant'], ['ame', 'Âme'], ['type', 'Type'], ['fin', 'Finition'], ['pose', 'Pose']].map(([champ, lib]) => `<label style="font-size:12px;flex:1;min-width:150px">${lib}${selCrayon('bp-' + champ, 'Bloc porte : ' + lib.toLowerCase(), `<select data-nv="${esc(p.id)}|bloc|${k}|${champ}" style="width:100%;min-width:0">${optCodes('bp-' + champ, 'Bloc porte : ' + lib.toLowerCase(), BP_CHOIX[champ], bl[champ] || (champ === 'dim' ? '83×204' : ''), '— choisir —')}</select>`)}</label>`).join('')}
      <label style="font-size:12px">Nombre <input data-nv="${esc(p.id)}|bloc|${k}|nb" inputmode="numeric" value="${esc(bl.nb || '')}" style="width:70px"></label>
      <button type="button" class="btn small danger" data-nv-act="delbloc:${esc(p.id)}:${k}">✕</button></div>`).join('')}
    <button type="button" class="btn sec small" style="margin-top:6px" data-nv-act="addbloc:${esc(p.id)}">+ Porte de passage</button>
    <div style="margin-top:8px"><strong style="font-size:13px">Façades de placard</strong></div>
    ${(p.facades || []).map((f, k) => blocFacade(p, f, k)).join('')}
    <button type="button" class="btn sec small" style="margin-top:6px" data-nv-act="addfacade:${esc(p.id)}">+ Façade de placard</button>
    <div class="row" style="flex-wrap:wrap;gap:6px;margin-top:6px"><label style="font-size:12px">Passage libre sans porte ml (déduit des plinthes) <input data-nv="${esc(p.id)}|passage" inputmode="decimal" value="${esc(p.passage || '')}" style="width:90px"></label></div>
    <div style="margin-top:8px"><strong style="font-size:13px">Appareillage de cette pièce</strong></div>
    <div class="row" style="flex-wrap:wrap;gap:6px;margin-top:4px">
      ${SPOT_LUX[typePieceNv(p.nom) || ''] ? `<label style="font-size:12px">Éclairage du plafond <select data-nv="${esc(p.id)}|eclairage" style="min-width:200px"><option value="">Point lumineux plafonnier</option><option value="spots" ${eclairagePiece(p) === 'spots' ? 'selected' : ''}>Spots encastrés (selon la surface)</option></select></label>` : ''}
      ${eclairagePiece(p) === 'spots' ? `<label style="font-size:12px">Plafonnier en plus, commandé par va-et-vient <select class="option-piece" data-nv="${esc(p.id)}|plafVV" style="min-width:160px"><option value="">Non</option><option value="oui" ${p.plafVV === 'oui' ? 'selected' : ''}>Oui</option></select></label>` : ''}
      ${PNV_APPAREIL.map(a => a.cle === 'points' && eclairagePiece(p) === 'spots'
        ? `<span class="muted" style="font-size:12px">Spots encastrés calculés : ${nbSpots(p)}</span>`
        : `<label style="font-size:12px">${esc(a.libelle)} <input data-nv="${esc(p.id)}|app|${a.cle}" inputmode="numeric" value="${esc(appDefaut(p, a.cle))}" style="width:60px"></label>`).join('')}
    </div></div></div>`; };
  host.innerHTML = `<datalist id="dlPiecesNv">${Object.keys(ELEC_PIECE_TYPES).map(t => `<option value="${esc(t)}">`).join('')}</datalist>${tabTitre('B. Configurateur de pièces')}<div class="bloc bloc-lettre">
    <p class="muted">Pour chaque pièce : surface au sol et revêtement, portes fin de chantier, menuiseries extérieures et appareillage de la pièce uniquement.</p>
    ${liste.map(carte).join('') || '<p class="muted">Aucune pièce.</p>'}
    ${liste.length ? (() => { const eq = equipementsMaison(c); return `<div class="card" style="margin-top:10px"><strong style="font-size:13px">Équipements de la maison (calculés selon les pièces)</strong>
      <p class="muted" style="font-size:12px;margin:4px 0">Tableau : ${esc(eq.tableau)} (${eq.modules} modules pour ${eq.circuits} circuits, ${eq.ddr} différentiel(s) 30 mA). Détecteurs de fumée : ${eq.detecteurs} (1 pour 100 m², pour ${fmt(eq.surf)} m² hors terrasse).</p></div>`; })() : ''}
    <div class="row" style="gap:8px;margin-top:8px;flex-wrap:wrap">
      <button type="button" class="btn sec" data-nv-act="add">+ Ajouter une pièce</button>
      <button type="button" class="btn" data-nv-act="gen">Ajouter au métré</button>
      <button type="button" class="btn sec" data-nv-act="gen-maison">Ajouter l'installation électrique de la maison</button>
    </div>
    <p id="nvStatut" class="muted" style="font-size:13px"></p></div>`;
}
// Équipements de la maison (hors pièces) : tableau adapté aux pièces saisies, et détecteurs de fumée (1 pour 100 m²)
// Circuits : éclairage (8 points max par circuit), prises (8 max), 1 circuit par appareil spécialisé, 1 circuit VMC
function equipementsMaison(c) {
  const pcs = piecesNvDe(c).filter(p => (typePieceNv(p.nom) || '') !== 'Extérieur (terrasse)');
  let ecl = 0, pri = 0, spec = 0, surf = 0;
  for (const p of pcs) surf += num(p.surf);
  for (const p of pcs) {
    if (eclairagePiece(p) === 'spots') ecl += nbSpots(p); else ecl += num(appDefaut(p, 'points'));
    if (eclairagePiece(p) === 'spots' && p.plafVV === 'oui') ecl += 1;
    pri += ['prises', 'tv', 'hotte', 'rasoir'].reduce((a, k) => a + num(appDefaut(p, k)), 0);
    spec += ['plaque', 'four', 'lvaisselle', 'llinge', 'sechelinge', 'chauffeau'].filter(k => num(appDefaut(p, k)) > 0).length;
  }
  const circuits = (ecl ? Math.ceil(ecl / 8) : 0) + (pri ? Math.ceil(pri / 8) : 0) + spec + 1;
  const ddr = Math.max(2, Math.ceil(circuits / 8));
  const modules = Math.ceil((circuits + 2 * ddr + 2) * 1.2);
  const tableau = modules <= 12 ? 'Tableau électrique 12 modules avec protections'
    : modules <= 24 ? 'Tableau électrique 24 modules avec protections'
    : modules <= 36 ? 'Tableau électrique 36 modules avec protections'
    : modules <= 48 ? 'Tableau électrique 48 modules avec protections'
    : 'Tableau électrique 4 rangées (logement > 100 m²)';
  const detecteurs = surf > 0 ? Math.ceil(surf / 100) : 0;
  // Liste de l'installation : tout ce qui se compte (les câbles et gaines en mètres se saisissent à la main)
  const rj = pcs.reduce((a, p) => a + num(appDefaut(p, 'rj45')), 0);
  const nbEau = pcs.filter(p => /salle d.(eau|bain)/i.test((typePieceNv(p.nom) || '') + ' ' + (p.nom || ''))).length;
  const items = [
    { des: tableau, n: 1, info: `${modules} modules nécessaires, ${circuits} circuits` },
    { des: 'Disjoncteur de branchement', n: 1 },
    { des: 'Disjoncteur divisionnaire (1 par circuit)', n: circuits, info: `${circuits} circuits` },
    { des: 'Interrupteur différentiel 30 mA', n: ddr, info: `${ddr} pour ${circuits} circuits` },
    { des: 'Prise de terre (piquet et ruban)', n: 1 },
    { des: 'Liaison équipotentielle', n: 1 },
  ];
  if (nbEau) items.push({ des: "Liaison équipotentielle de salle d'eau", n: nbEau, info: 'une par pièce d\'eau' });
  if (rj > 0) items.push({ des: 'Tableau télécommunication', n: 1 });
  if (detecteurs > 0) items.push({ des: 'Détecteur autonome de fumée', n: detecteurs, info: '1 pour 100 m²' });
  return { pieces: pcs.length, circuits, ddr, modules, tableau, detecteurs, surf, items };
}
// Installation électrique de la maison (hors pièces), calculée sur toutes les pièces
function ajouterEquipementsMaison(c, L, manque) {
  const eq = equipementsMaison(c);
  let nb = 0;
  for (const it of eq.items) {
    const o = ouvrageParDesig(it.des);
    if (!o) { manque.push(it.des); continue; }
    const v = { nombre: String(it.n) };
    ajouterLotSiAbsent(c.id, o.lot);
    L.push({ uid: uid(), lot: o.lot, ouvrage: o.id, designation: `${o.designation}${it.info ? ' (' + it.info + ')' : ''} – maison`, unite: o.unite, valeurs: v, quantite: calcul(o, v), surface: null, prix: 'moyen', pieceNv: 'maison', pieceOption: false, cree: new Date().toISOString() });
    nb++;
  }
  return nb;
}
// Bouton « Ajouter l'installation électrique de la maison » : même calcul que « Ajouter au métré »
function genererEquipementsMaison(c) {
  delete c.metreGele;
  const eq = equipementsMaison(c);
  if (eq.pieces === 0) return 'Équipements : saisis d\'abord les pièces.';
  const L = lignesDe(c.id).filter(l => l.pieceNv !== 'maison');
  const manque = [];
  const nb = ajouterEquipementsMaison(c, L, manque);
  sauverLignes(c.id, L);
  renderMetre();
  if (manque.length) return 'Installation électrique : ouvrage manquant dans la bibliothèque (' + manque.join(', ') + ').';
  return nb ? 'Installation électrique de la maison ajoutée au métré.' : 'Installation électrique : aucune ligne.';
}
// Ordre des pièces : les lignes des lots revêtements et électricité suivent l'ordre des pièces du configurateur
// (les lignes sans pièce ou de la maison ne bougent pas). Renvoie la liste des lignes triée.
function ordonnerLignesPieces(c, L = lignesDe(c.id)) {
  const ordre = new Map(piecesNvDe(c).map((p, i) => [p.id, i]));
  const pos = [];
  L.forEach((l, i) => { if (SOUS_PIECE_LOTS.has(l.lot) && ordre.has(l.pieceNv)) pos.push(i); });
  const triees = pos.map((i, k) => ({ l: L[i], k })).sort((x, y) => (ordre.get(x.l.pieceNv) - ordre.get(y.l.pieceNv)) || (x.k - y.k)).map(x => x.l);
  pos.forEach((i, k) => { L[i] = triees[k]; });
  return L;
}
function genererPiecesNv(c) {
  delete c.metreGele;
  const pcs = piecesNvDe(c);
  // Les équipements de la maison (bouton séparé) sont conservés lors de la génération des pièces
  const L = lignesDe(c.id).filter(l => !l.pieceNv);   // les équipements de la maison sont recalculés à chaque génération
  const manque = [];
  let nb = 0;
  const volets = [];   // fermetures et occultations, mises en fin de liste au métré
  const menusNv = [];  // menuiseries extérieures, regroupées en ouvrantes puis coulissantes
  // Menuiseries intérieures (blocs-portes, façades de placard) : le nom de la pièce est indiqué dans le détail, pas dans le descriptif
  const ajouteDansPiece = (o, valeurs, q, designation, pieceId, nomPc) => { ajoute(o, valeurs, q, designation, pieceId); const lP = L[L.length - 1]; if (lP) lP.detailTexte = nomPc; };
  const ajoute = (o, valeurs, q, designation, pieceId, option, bloc) => {
    ajouterLotSiAbsent(c.id, o.lot);
    // Électricité et revêtements : le titre de la pièce est déjà au-dessus, on ne le répète pas dans le descriptif
    if (pieceId && SOUS_PIECE_LOTS.has(o.lot)) designation = designation.replace(/ – [^–]*$/, '');
    L.push({ uid: uid(), lot: o.lot, ouvrage: o.id, designation, unite: o.unite, valeurs, quantite: q, surface: null, prix: 'moyen', pieceNv: pieceId, pieceOption: !!option, menBloc: bloc || undefined, cree: new Date().toISOString() });
    nb++;
  };
  const menusIntNv = [];   // blocs portes et façades de placard, réunis après la boucle des pièces
  for (const p of pcs) {
    const nom = (p.nom || 'Pièce') + (p.qualif ? ' ' + p.qualif : '');   // « Chambre » + numéro
    const surf = num(p.surf);
    if (p.revet && surf > 0) {
      const o = BIB.ouvrages.find(x => x.id === p.revet);
      if (!o) manque.push('revêtement de ' + nom);
      else { const v = { nombre: '1', cote1: String(surf), cote2: '1' }; ajoute(o, v, calcul(o, v), `${o.designation} – ${nom}`, p.id); const lR = L[L.length - 1]; if (lR) { lR.modeLigne = 'texte'; lR.detailTexte = 'surface indiquée sur plan'; } }
    }
    // Plinthes : linéaire de la pièce, juste sous son revêtement de sol (aucun matériau)
    if (num(p.perim) > 0) {
      // Linéaire de plinthes = périmètre − portes de passage − façades de placard − portes et baies extérieures − passages libres sans porte
      const largeurPorte = LARGEUR_PORTE_NV;
      const baies = (p.menus || []).filter(m => estPorteBaie(m) && num(m.l) > 0).reduce((a, m) => a + (num(m.nb) || 1) * num(m.l) / 100, 0);
      const lin = Math.max(0, num(p.perim) - nbPortesNv(p) * largeurPorte - facadesLargeur(p) - baies - num(p.passage));
      const o = BIB.ouvrages.find(x => x.id === 'OUV-0881' && !x.supprime);
      if (!o) manque.push('Plinthes (OUV-0881)');
      else if (lin > 0) {
        const v = { nombre: '1', cote1: String(Math.round(lin * 100) / 100) };
        ajoute(o, v, calcul(o, v), `${o.designation} – ${nom}`, p.id);
        const lPl = L[L.length - 1];
        const perimR = Math.round(num(p.perim) * 100) / 100, linR = Math.round(lin * 100) / 100, passR = Math.round((num(p.perim) - lin) * 100) / 100;
        if (lPl) { lPl.modeLigne = 'texte'; lPl.detailTexte = `périphérie de la pièce ${fmt(perimR)} m − passages ${fmt(passR)} m = ${fmt(linR)} ml`; }
      }
    }
    for (const bl of (p.blocs || [])) {
      if (!(num(bl.nb) > 0)) continue;
      const r = ouvrageBloc(bl);
      if (r.manque) { manque.push(r.manque); continue; }
      const v = { nombre: String(num(bl.nb)) };
      menusIntNv.push({ o: r.o, v, q: calcul(r.o, v), base: r.intitule, nom, designation: `${r.intitule} – ${nom}`, pid: p.id });
    }
    for (const f of (p.facades || [])) {
      const n = num(f.nb) || 1;
      if (!(num(f.l) > 0 && num(f.h) > 0)) { if (f.ouvrant) manque.push('Façade de placard : dimensions L × H à saisir (' + nom + ')'); continue; }
      if (!f.ouvrant || !f.structure || !f.finition || !f.pose || !f.amort) { manque.push('Façade de placard : choix incomplets (' + nom + ')'); continue; }
      if (f.ouvrant !== 'coulissante' && !f.vantaux) { manque.push('Façade de placard : nombre de vantaux à choisir (' + nom + ')'); continue; }
      const o = BIB.ouvrages.find(x => x.id === FA_BASE[f.ouvrant] && !x.supprime);
      if (!o) { manque.push('façade de placard'); continue; }
      const v = { nombre: String(n) };   // à l'unité : les dimensions figurent dans la désignation
      menusIntNv.push({ o, v, q: calcul(o, v), base: designationFacade(f), nom, designation: `${designationFacade(f)} – ${nom}`, pid: p.id });
    }
    for (const m of (p.menus || [])) {
      if ((m.volet === 'oui' && m.ferm) || m.moust) volets.push({ m, nom, pid: p.id });   // traités après toutes les menuiseries
      if (!(num(m.l) > 0 && num(m.h) > 0)) { if (m.type || m.mat) manque.push('Menuiserie extérieure : dimensions L × H à saisir (' + nom + ')'); continue; }
      if (!m.type || !m.mat || !m.vantaux) { manque.push('Menuiserie extérieure : type, matériau ou vantaux non choisis (' + nom + ')'); continue; }
      const o = baseMenuiserie(m);
      if (!o) { manque.push('Menuiserie extérieure : pas encore d\'ouvrage de base pour ' + (ME_TXT.type[m.type] || '') + ' ' + (ME_CHOIX.mat.find(([v]) => v === m.mat) || [])[1] + ' ' + (ME_TXT.vantaux[m.vantaux] || '') + ' (' + nom + ')'); continue; }
      const v = { nombre: String(num(m.nb) || 1) };
      menusNv.push({ o, v, q: calcul(o, v), base: designationMenuiserie(m), nom, designation: `${designationMenuiserie(m)} – ${nom}`, pid: p.id, bloc: MEN_COUL.includes(m.ouvrant) ? 'coul' : 'ouv' });
    }
    if (eclairagePiece(p) === 'spots' && nbSpots(p) > 0) {
      const desSpot = ['Salle de bains', 'Salle d\'eau'].includes(typePieceNv(p.nom)) ? 'Spot encastré LED étanche IP65 (salle de bain)' : 'Spot encastré LED';
      const o = ouvrageParDesig(desSpot);
      if (!o) manque.push(desSpot);
      else { const v = { nombre: String(nbSpots(p)) }; ajoute(o, v, calcul(o, v), `${o.designation} – ${nom}`, p.id); }
    }
    if (eclairagePiece(p) === 'spots' && p.plafVV === 'oui') {
      const oPl = ouvrageParDesig('Point lumineux plafonnier');
      const oVV = ouvrageParDesig('Interrupteur va-et-vient (point)');
      if (!oPl) manque.push('Point lumineux plafonnier');
      else { const v = { nombre: '1' }; ajoute(oPl, v, calcul(oPl, v), `${oPl.designation} (plafonnier avec spots) – ${nom}`, p.id, true); }
      if (!oVV) manque.push('Interrupteur va-et-vient (point)');
      else { const v = { nombre: '1' }; ajoute(oVV, v, calcul(oVV, v), `${oVV.designation} (commande du plafonnier) – ${nom}`, p.id, true); }
    }
    for (const a of PNV_APPAREIL) {
      if (a.cle === 'points' && eclairagePiece(p) === 'spots') continue;
      const n = num(appDefaut(p, a.cle));
      if (!(n > 0)) continue;
      const o = ouvrageParDesig(desPnv(p, a));
      if (!o) { manque.push(desPnv(p, a)); continue; }
      const v = { nombre: String(n) };
      ajoute(o, v, calcul(o, v), `${o.designation} – ${nom}`, p.id);
    }
  }
  // Réunit les lignes identiques (même ouvrage, mêmes dimensions et options, hors pièce) : quantités additionnées, pièces citées
  const reunir = (items) => {
    const groupes = new Map();
    for (const x of items) {
      const cle = x.o.id + '|' + x.base + '|' + x.bloc;
      const g = groupes.get(cle);
      if (!g) groupes.set(cle, { ...x, nombre: num(x.v.nombre), pieces: [x.nom] });
      else { g.nombre += num(x.v.nombre); g.q += x.q; if (!g.pieces.includes(x.nom)) g.pieces.push(x.nom); }
    }
    return [...groupes.values()].map(g => ({ o: g.o, v: { ...g.v, nombre: String(g.nombre) }, q: g.q, pid: g.pid, bloc: g.bloc, designation: g.base, pieces: g.pieces.join(', ') }));
  };
  // Menuiseries : le nom de la pièce n'est plus dans le descriptif ; il est indiqué dans le détail (ex. « chambre 1, chambre 2 »)
  const ajouteMen = (x, bl) => { ajoute(x.o, x.v, x.q, x.designation, x.pid, false, bl); const lM = L[L.length - 1]; if (lM && x.pieces) lM.detailTexte = x.pieces; };
  for (const bl of ['ouv', 'coul']) for (const x of reunir(menusNv.filter(x => x.bloc === bl))) ajouteMen(x, bl);
  // Menuiseries intérieures (blocs portes, façades de placard) : identiques réunies, pièces citées dans le détail
  for (const x of reunir(menusIntNv)) ajouteMen(x);
  const fermL = [];   // fermetures et moustiquaires, réunies ensuite par dimensions
  // Fermeture - occultation : volet, store ou moustiquaire par menuiserie, sous le sous-titre du métré
  for (const { m, nom, pid } of volets) {
    const n = num(m.nb) || 1, L_ = num(m.l), H_ = num(m.h);
    if (!(L_ > 0 && H_ > 0)) { manque.push('Fermeture : dimensions L × H à saisir (' + nom + ')'); continue; }
    if (m.volet === 'oui' && m.ferm) {
    const lib = (ME_CHOIX.ferm.find(([v]) => v === m.ferm) || [])[1] || m.ferm;
    const idF = FERM_OUV[m.ferm], oF = idF ? BIB.ouvrages.find(x => x.id === idF && !x.supprime) : null;
    if (!oF) manque.push('Fermeture : ' + lib + ' (pas encore d\'ouvrage dans la bibliothèque)');
    else {
      const v = oF.unite === 'm²' ? { nombre: String(n), cote1: String(L_ / 100), cote2: String(H_ / 100) } : { nombre: String(n) };
      const dimsTxt = oF.unite === 'm²' ? ` ${fmt(L_)} × ${fmt(H_)} cm` : ` (${fmt(L_)} × ${fmt(H_)} cm)`;
      fermL.push({ o: oF, v, q: calcul(oF, v), base: `${oF.designation}${dimsTxt}`, nom, pid, bloc: 'ferm' });
      // Volet roulant motorisé : alimentation et commande électriques, ajoutées au lot électricité
      if (m.ferm === 'vr-motor') for (const idE of ['OUV-0224', 'OUV-0624']) {
        const oE = BIB.ouvrages.find(x => x.id === idE && !x.supprime);
        if (!oE) { manque.push('électricité du volet motorisé (' + idE + ')'); continue; }
        const vE = { nombre: String(n) };
        ajoute(oE, vE, calcul(oE, vE), `${oE.designation} – ${nom}`, pid);
      }
    }
    }
    if (m.moust) {
      const libM = (ME_CHOIX.moust.find(([v]) => v === m.moust) || [])[1] || m.moust;
      const integreeSansFermeture = m.moust === 'integree' && !(m.volet === 'oui' && m.ferm);
      const idM = integreeSansFermeture ? null : MOUST_OUV[m.moust], oM = idM ? BIB.ouvrages.find(x => x.id === idM && !x.supprime) : null;
      if (integreeSansFermeture) manque.push('Moustiquaire intégrée : choisis une fermeture (Compris fermeture) ou la moustiquaire indépendante (' + nom + ')');
      else if (!oM) manque.push('Moustiquaire : ' + libM + ' (pas encore d\'ouvrage dans la bibliothèque)');
      else { const v = { nombre: String(n) }; fermL.push({ o: oM, v, q: calcul(oM, v), base: `${oM.designation} (${fmt(L_)} × ${fmt(H_)} cm)`, nom, pid, bloc: 'ferm' }); }
    }
  }
  for (const x of reunir(fermL)) ajouteMen(x, 'ferm');
  if (pcs.length) nb += ajouterEquipementsMaison(c, L, manque);
  // Lignes de chaque pièce réunies dans l'ordre des pièces (électricité, revêtements, alimentation et commande des volets comprises)
  ordonnerLignesPieces(c, L);
  sauverLignes(c.id, L);
  renderMetre();
  const uniques = manque.filter((d, i, t) => t.indexOf(d) === i);
  if (uniques.some(d => d.startsWith('Bloc porte : ouvrage non choisi'))) return 'Pièces : choisis l\'ouvrage de chaque bloc porte (dernière case de la liste).';
  if (uniques.some(d => d.startsWith('Moustiquaire intégrée'))) return 'Pièces : la moustiquaire intégrée demande une fermeture choisie ; sinon choisis la moustiquaire indépendante.';
  if (uniques.some(d => d.startsWith('Façade de placard : choix incomplets'))) return 'Pièces : termine les choix de chaque façade de placard (type, structure, finition, pose, amortisseur), sinon elle n\'est pas au métré.';
  if (uniques.some(d => d.startsWith('Façade de placard : nombre de vantaux'))) return 'Pièces : choisis le nombre de vantaux des façades battantes ou pliantes.';
  if (uniques.some(d => d.startsWith('Façade de placard : dimensions'))) return 'Pièces : saisis les dimensions L × H de chaque façade de placard, sinon elle n\'est pas au métré.';
  if (uniques.some(d => d.startsWith('Menuiserie extérieure : type, matériau'))) return 'Pièces : choisis type, matériau et nombre de vantaux de chaque menuiserie extérieure, sinon elle n\'est pas au métré.';
  if (uniques.some(d => d.startsWith('Menuiserie extérieure : pas encore'))) return 'Pièces : ' + uniques.find(d => d.startsWith('Menuiserie extérieure : pas encore')).replace('Menuiserie extérieure : ', '') + ' — à ajouter à la bibliothèque.';
  if (uniques.some(d => d.startsWith('Menuiserie extérieure : dimensions'))) return 'Pièces : saisis les dimensions L × H de chaque menuiserie extérieure, sinon elle n\'est pas au métré.';
  if (uniques.length) return 'Pièces : ouvrage manquant dans la bibliothèque.';
  return nb ? 'Pièces régénérées.' : 'Pièces : aucune ligne.';
}
/* ============ Bloc plâtrerie et isolation (séparé du configurateur de pièces) ============ */
// Saisie : hauteur sous plafond, linéaire de cloisonnement et linéaire de doublage. Surface = linéaire × hauteur.
// Les lignes produites portent platNv et sont remplacées à chaque génération.
// Isolants proposés dans la plâtrerie : ouvrages « Isolation … » en m², hors toiture, rampants, combles, planchers, dalles et ITE
function isolantsPlat() {
  return BIB.ouvrages.filter(o => ouvActif(o) && o.unite === 'm²' && /^(Isolation|Isolant)/i.test(o.designation)
    && !/(toiture|rampant|combles|plancher|dalle|solive|terre-plein|enterr|extérieur|chevron|poutre)/i.test(o.designation)
    && !/\bITE\b/.test(o.designation));
}
function optIsol(val, key, titre) {
  if (!key) return `<option value="">Sans isolant</option>` + isolantsPlat().map(o => `<option value="${esc(o.id)}" ${o.id === val ? 'selected' : ''}>${esc(o.designation)}</option>`).join('');
  return optListeOuvrages(key, titre, () => isolantsPlat().map(o => o.designation), val, 'Sans isolant');
}
// Liste d'ouvrages de la bibliothèque, modifiable : la valeur de chaque option est l'identifiant de l'ouvrage
function optListeOuvrages(key, titre, baseFn, val, vide) {
  // Si des lots ont été choisis dans l'éditeur, la liste suit ces lots (retirer un lot retire ses ouvrages)
  LISTES_CONF[key] = { titre, base: () => { const r = listeReglage(key); return Array.isArray(r.lots) ? designationsTousLots(r.lots) : baseFn(); } };
  const liste = listeEffective(key);
  const ids = liste.map(d => { const o = BIB.ouvrages.find(x => !x.supprime && x.designation === d); return o ? o.id : ''; });
  let html = vide ? `<option value="">${esc(vide)}</option>` : '';
  if (val && !ids.includes(val)) { const o = BIB.ouvrages.find(x => x.id === val); if (o) html += `<option value="${esc(o.id)}" selected>${esc(o.designation)} (retiré de la liste)</option>`; }
  return html + liste.map((d, i) => ids[i] ? `<option value="${esc(ids[i])}" ${ids[i] === val ? 'selected' : ''}>${esc(d)}</option>` : '').join('');
}
// Liste de désignations (bibliothèque) : valeur = le texte de l'option
function optDesignations(key, titre, baseFn, val, vide) {
  LISTES_CONF[key] = { titre, base: baseFn };
  const liste = listeEffective(key);
  let h = vide ? `<option value="">${esc(vide)}</option>` : '';
  if (val && !liste.includes(val)) h += `<option selected>${esc(val)} (retiré de la liste)</option>`;
  return h + liste.map(d => `<option ${d === val ? 'selected' : ''}>${esc(d)}</option>`).join('');
}
// Liste à codes fixes : entries = [[code, libellé], …]
function optCodes(key, titre, entries, val, vide) {
  FIXES_DEFAUTS[key] = entries;
  const liste = valeursFixes(key, entries);
  let h = vide ? `<option value="">${esc(vide)}</option>` : '';
  if (val && !liste.some(([k]) => k === val)) h += `<option value="${esc(val)}" selected>${esc(val)} (retiré de la liste)</option>`;
  return h + liste.map(([k, t]) => `<option value="${esc(k)}" ${k === val ? 'selected' : ''}>${t}</option>`).join('');
}
// Liste de la bibliothèque dont la valeur est l'identifiant (alias de optListeOuvrages)
function optDesignationsId(key, titre, baseFn, val, vide) { return optListeOuvrages(key, titre, baseFn, val, vide); }
// Crayon seul, et crayon + liste sur la même ligne
function crayonBouton(key, titre) {
  return `<button type="button" class="btn small sec" data-action="gerer-liste" data-liste="${esc(key)}" title="Gérer cette liste" style="padding:4px 8px;flex:0 0 auto">✏️</button>`;
}
function selCrayon(key, titre, selHtml) {
  return `<span class="crayon-rangee" style="flex:1;min-width:0">${crayonBouton(key, titre)}<span style="flex:1;min-width:0;display:flex">${selHtml}</span></span>`;
}
function platNvDe(c) { const q = c.platNv = c.platNv || {}; q.hauteur = q.hauteur || ''; q.hauteurDoub = q.hauteurDoub || ''; q.cloi = q.cloi || { ml: '', m2: '', ouv: '', isol: '', joint: '' }; q.doub = q.doub || { ml: '', m2: '', ouv: '', isol: '', joint: '' };
  if (!q.doub.jointInit) { q.doub.joint = 'S * 1,9'; q.doub.jointInit = true; }
  if (!q.cloi.jointInit) { q.cloi.joint = 'S * 3,8'; q.cloi.jointInit = true; }
  q.pla = q.pla || { m2: '', ouv: '', isol: '', joint: '' };
  for (const k of ['cloi', 'doub', 'pla']) { q[k].hydro = q[k].hydro || ''; q[k].feu = q[k].feu || ''; }
  q.cloi.acou = q.cloi.acou || '';
  q.enduit = q.enduit || { ouv: '' };
  if (!q.pla.hydroInit) { q.pla.hydro = 'S'; q.pla.hydroInit = true; }
  // Formule de la bande à joint du plafond : S × 3,80 (proposée une seule fois, ensuite modifiable librement)
  if (!q.pla.jointInit) { q.pla.joint = 'S * 3,8'; q.pla.jointInit = true; }
  return q; }
// Bande à joint : une case où l'on saisit une formule ; S = surface de la ligne (m²). Résultat = quantité de l'ouvrage OUV-0579.
const OUV_BANDE_JOINT = 'OUV-0579';
function resultatFormuleJoint(texte, surface) {
  let t = String(texte || '').trim().replace(/,/g, '.').replace(/×/g, '*').replace(/÷/g, '/').replace(/\bS\b/gi, '(' + surface + ')');
  if (!t || !/^[0-9+\-*/(). ]+$/.test(t)) return null;
  try { const r = Function('"use strict"; return (' + t + ');')(); return Number.isFinite(r) ? r : null; } catch (e) { return null; }
}
function optPlat(re, val, key, titre) {
  if (key) return optListeOuvrages(key, titre, () => [...new Set(BIB.ouvrages.filter(o => ouvActif(o) && o.unite === 'm²' && re.test(o.designation)).map(o => o.designation))], val, '— choisir —');
  return `<option value="">— choisir —</option>` + BIB.ouvrages.filter(o => ouvActif(o) && o.unite === 'm²' && re.test(o.designation))
    .map(o => `<option value="${esc(o.id)}" ${o.id === val ? 'selected' : ''}>${esc(o.designation)}</option>`).join('');
}
// Cadenas des cases de formule « Bande à joint » : verrouillé par défaut (lecture seule), déverrouillable d'un clic
function verrouJoint(q, cle) { return !(q.verrou && q.verrou[cle] === false); }
function champJoint(q, cle, val) {
  const v = verrouJoint(q, cle);
  return `<span style="display:flex;flex-wrap:nowrap;gap:4px;flex:1;min-width:200px;align-items:center">
    <button type="button" data-verrou="${cle}" title="${v ? 'Déverrouiller la formule' : 'Verrouiller la formule'}" style="flex:0 0 28px;width:28px;height:28px;padding:0;background:#1f6fd1;color:#fff;border:none;border-radius:3px;cursor:pointer;line-height:1">${v ? '🔒' : '🔓'}</button>
    <input data-plat="${cle}|joint" value="${esc(val || '')}" placeholder="formule, ex. S × 1,1" ${v ? 'readonly' : ''} class="${v ? 'joint-verrouille' : ''}" style="flex:1;min-width:150px"></span>`;
}
// Plus-values plaque hydrofuge et plaque coupe-feu : une case de formule chacune, sous la bande à joint
// Surface totale (m²) des salles d'eau et salles de bain du configurateur : base de la plus-value hydrofuge du plafond
function surfacePiecesEau(c) {
  return piecesNvDe(c).reduce((a, p) => PLAT_EAU.test(p.type) ? a + num(p.surf) * (num(p.nb) || 1) : a, 0);
}
function champPlusValue(cle, sous, titre, val) {
  return `<div class="row" style="gap:6px;margin-top:4px;align-items:center"><span class="muted" style="font-size:12px;min-width:120px">${titre}</span><input data-plat="${cle}|${sous}" value="${esc(val || '')}" placeholder="formule" style="flex:1;min-width:200px"></div>`;
}
// Plaque coupe-feu : liste déroulante de surfaces en m² (3, 6, 9 ou 15)
const PLAQUES_FEU_M2 = ['3', '6', '9', '15'];
function champPlaqueFeu(cle, val, res) {
  return `<div class="row" style="gap:6px;margin-top:4px;align-items:center"><span class="muted" style="font-size:12px;min-width:120px;color:#d62828">Plus-value plaque coupe-feu</span><select data-plat="${cle}|feu" style="flex:1;min-width:200px"><option value="">— choisir —</option>${PLAQUES_FEU_M2.map(v => `<option value="${v}" ${v === String(val || '') ? 'selected' : ''}>${v} m²</option>`).join('')}</select>${resBox(res)}</div>`;
}
// Plus-value hydrofuge du doublage : on saisit le linéaire (ml), multiplié par la hauteur de doublage
function champMlHydro(q, cle, sous = 'hydro', titre = 'Plus-value plaque hydrofuge', res) {
  const ml = num(q[cle][sous]), h = num(cle === 'doub' ? q.hauteurDoub : q.hauteur);
  // Plaques de 1,20 m : nombre de plaques arrondi au-dessus, longueur couverte = plaques × 1,20 m, surface = longueur couverte × hauteur
  const PLAQUE_ML = 1.2;
  const nbPlaques = ml > 0 ? Math.ceil(ml / PLAQUE_ML) : 0;
  const longueur = nbPlaques * PLAQUE_ML;
  const detail = ml > 0 && h > 0
    ? `${fmt(ml)} ml ÷ ${fmt(PLAQUE_ML)} = ${fmt(ml / PLAQUE_ML)} → ${nbPlaques} plaques × ${fmt(PLAQUE_ML)} m = ${fmt(longueur)} m × ${fmt(h)} m = ${fmt(longueur * h)} m²`
    : 'saisir le linéaire et la hauteur ' + (cle === 'doub' ? 'de doublage' : 'sous plafond');
  return `<div class="row" style="gap:6px;margin-top:4px;align-items:center"><span class="muted" style="font-size:12px;min-width:120px;color:${sous === 'acou' ? '#1f6fd1' : '#2e9e44'}">${titre}</span><input data-plat="${cle}|${sous}" inputmode="decimal" value="${esc(q[cle][sous] || '')}" placeholder="ml" style="width:120px"><span class="muted" style="font-size:12px;flex:1">${detail}</span>${res !== undefined ? resBox(res) : ''}</div>`;
}
// Case de résultat, en lecture seule, en bout de ligne
function resBox(txt) {
  return `<span class="res-box" style="min-width:95px;text-align:right;border:1px solid #bbb;border-radius:4px;padding:3px 8px;background:#f5f5f5;font-size:13px;font-weight:600">${txt}</span>`;
}
// Résultats affichés en bout de ligne (bande à joint, plus-values hydrofuge et coupe-feu), même calcul que la génération du métré
function resultatsPlat(c, q) {
  const h = num(q.hauteur), R = {};
  const m2txt = v => (v === null || v === undefined || !(v >= 0)) ? '—' : fmt(v) + ' m²';
  // Bande à joint : l'unité vient de la bibliothèque (OUV-0579)
  const oJ = BIB.ouvrages.find(x => x.id === OUV_BANDE_JOINT && !x.supprime);
  const uniteJoint = oJ && oJ.unite ? oJ.unite : 'm²';
  const jointTxt = v => (v === null || v === undefined || !(v >= 0)) ? '—' : fmt(v) + ' ' + uniteJoint;
  for (const cle of ['cloi', 'doub']) {
    const ml = num(q[cle].ml), m2s = num(q[cle].m2), hk = cle === 'doub' ? num(q.hauteurDoub) : h;
    const viaMl = ml > 0 && hk > 0;
    const surfBrute = viaMl ? ml * hk : m2s;
    const surfCase = surfBrute > 0 ? Math.max(0, surfBrute - (cle === 'doub' ? menuiseriesToutesM2(c) : portesEtPlacardsToutesM2(c))) : null;
    const mlH = num(q[cle].hydro);
    R[cle] = {
      joint: surfCase === null ? '—' : jointTxt(resultatFormuleJoint(q[cle].joint, surfCase)),
      hydro: mlH > 0 && hk > 0 ? m2txt(Math.ceil(mlH / 1.2) * 1.2 * hk) : '—',
      feu: num(q[cle].feu) > 0 ? m2txt(num(q[cle].feu)) : '—'
    };
  }
  const m2 = num(q.pla.m2);
  R.pla = {
    joint: m2 > 0 ? jointTxt(resultatFormuleJoint(q.pla.joint, m2)) : '—',
    hydro: m2txt(resultatFormuleJoint(q.pla.hydro, surfacePiecesEau(c))),
    feu: num(q.pla.feu) > 0 ? m2txt(num(q.pla.feu)) : '—'
  };
  return R;
}
// Formule verrouillable (cadenas) pour une plus-value, avec sa case de résultat
function champFormuleVerrou(q, vkey, dataKey, titre, val, res) {
  const v = verrouJoint(q, vkey);
  return `<div class="row" style="gap:6px;margin-top:4px;align-items:center"><span class="muted" style="font-size:12px;min-width:120px;color:#2e9e44">${titre}</span>
    <span style="display:flex;flex-wrap:nowrap;gap:4px;flex:1;min-width:200px;align-items:center">
    <button type="button" data-verrou="${vkey}" title="${v ? 'Déverrouiller la formule' : 'Verrouiller la formule'}" style="flex:0 0 28px;width:28px;height:28px;padding:0;background:#1f6fd1;color:#fff;border:none;border-radius:3px;cursor:pointer;line-height:1">${v ? '🔒' : '🔓'}</button>
    <input data-plat="${dataKey}" value="${esc(val || '')}" placeholder="formule" ${v ? 'readonly' : ''} class="${v ? 'joint-verrouille' : ''}" style="flex:1;min-width:150px"></span>${resBox(res)}</div>`;
}
function renderPlatNv() {
  const host = $('cfgPlatNv');
  if (!host) return;
  const c = chantiers.find(x => x.id === courantId);
  if (!c || !BIB) { host.innerHTML = ''; return; }
  const q = platNvDe(c);
  const R = resultatsPlat(c, q);
  const ligne = (cle, titre, re, extra = '') => `<div class="row" style="flex-wrap:wrap;gap:6px;margin-top:6px;align-items:center;background:rgba(224,123,26,0.55);border-radius:6px;padding:6px 8px;">
      <strong style="font-size:15px;min-width:120px;color:#fff;font-weight:600">${titre}</strong>${extra}
      <label style="font-size:12px">Linéaire ml <input data-plat="${cle}|ml" inputmode="decimal" value="${esc(q[cle].ml || '')}" style="width:80px"></label>
      ${cle === 'pla' ? '' : `<label style="font-size:12px">ou surface m² <input data-plat="${cle}|m2" inputmode="decimal" value="${esc(q[cle].m2 || '')}" style="width:80px"></label>`}
      ${selCrayon(`plat-${cle}-ouv`, titre, `<select data-plat="${cle}|ouv" style="flex:1;min-width:0">${optPlat(re, q[cle].ouv, `plat-${cle}-ouv`, titre)}</select>`)}</div>
      <div class="row" style="gap:6px;margin-top:4px;align-items:center"><span class="muted" style="font-size:12px;min-width:120px;color:#e6b800;font-weight:600">Isolant</span>${selCrayon(`plat-${cle}-isol`, titre, `<select data-plat="${cle}|isol" style="flex:1;min-width:0">${optIsol(q[cle].isol, `plat-${cle}-isol`, titre + ' : isolant')}</select>`)}</div>
      <div class="row" style="gap:6px;margin-top:4px;align-items:center"><span class="muted" style="font-size:12px;min-width:120px">Bande à joint</span>${champJoint(q, cle, q[cle].joint)}${resBox(R[cle].joint)}</div>
      ${champMlHydro(q, cle, 'hydro', 'Plus-value plaque hydrofuge', R[cle].hydro)}
      ${cle === 'cloi' ? champMlHydro(q, cle, 'acou', 'Plus-value plaque acoustique') : ''}
      ${champPlaqueFeu(cle, q[cle].feu, R[cle].feu)}`;
  const en = enduitIntSurf(c);
  host.innerHTML = `${tabTitre('C. Plâtrerie et isolation (bloc séparé)')}<div class="bloc bloc-lettre">
    <p class="muted">Cloisonnement : hauteur sous plafond. Doublage : hauteur de doublage (peut être différente). Surface = linéaire × hauteur.</p>
    <div class="row" style="flex-wrap:wrap;gap:6px;align-items:center">
      <label style="font-size:12px">Hauteur sous plafond m <input data-plat="hauteur" inputmode="decimal" value="${esc(q.hauteur || '')}" style="width:90px"></label></div>
    ${ligne('cloi', 'Cloisonnement', /^Cloison/i)}
    <p class="muted" style="font-size:13px;margin:4px 0 0">Portes de passage et façades de placard déduites du cloisonnement (1,50 m² et plus) : ${fmt(portesEtPlacardsM2(c))} m².</p>
    ${ligne('doub', 'Doublage', /^(Doublage|Système Optima|Rail montant doublé)/i, `<label style="font-size:12px">Hauteur de doublage m <input data-plat="hauteurDoub" inputmode="decimal" value="${esc(q.hauteurDoub || '')}" style="width:90px"></label>`)}
    <p class="muted" style="font-size:13px;margin:4px 0 0">Menuiseries extérieures déduites du doublage : ${fmt(menuiseriesExtM2(c))} m² (fenêtres, portes-fenêtres, baies et portes d'entrée d'au moins 1,50 m²).</p>
    <div class="row" style="gap:6px;margin-top:6px;align-items:center"><span class="muted" style="font-size:12px;min-width:120px;font-weight:600">Enduit intérieur</span>${selCrayon('plat-enduit-ouv', 'Enduit intérieur', `<select data-plat="enduit|ouv" style="flex:1;min-width:0">${optPlat(/^Enduit intérieur traditionnel/i, q.enduit.ouv, 'plat-enduit-ouv', 'Enduit intérieur')}</select>`)}</div>
    <p class="muted" style="font-size:13px;margin:2px 0 0">Enduit intérieur : périmètre des murs périphériques ${fmt(en.linP)} m × hauteur de doublage ${fmt(en.hk)} m, moins menuiseries extérieures ${fmt(en.ded)} m² = ${fmt(en.net)} m².</p>
    <div class="row" style="flex-wrap:wrap;gap:6px;margin-top:6px;align-items:center;background:rgba(224,123,26,0.55);border-radius:6px;padding:6px 8px;">
      <strong style="font-size:15px;min-width:120px;color:#fff;font-weight:600">Plafond</strong>
      <label style="font-size:12px">Surface m² <input data-plat="pla|m2" inputmode="decimal" value="${esc(q.pla.m2 || '')}" style="width:80px"></label>
      ${selCrayon('plat-pla-ouv', 'Plafond', `<select data-plat="pla|ouv" style="flex:1;min-width:0">${optPlat(/^(Plafond|Faux plafond)/i, q.pla.ouv, 'plat-pla-ouv', 'Plafond')}</select>`)}</div>
    <div class="row" style="gap:6px;margin-top:4px;align-items:center"><span class="muted" style="font-size:12px;min-width:120px;color:#e6b800;font-weight:600">Isolant</span>${selCrayon('plat-pla-isol', 'Plafond : isolant', `<select data-plat="pla|isol" style="flex:1;min-width:0">${optIsol(q.pla.isol, 'plat-pla-isol', 'Plafond : isolant')}</select>`)}</div>
    <div class="row" style="gap:6px;margin-top:4px;align-items:center"><span class="muted" style="font-size:12px;min-width:120px">Bande à joint</span>${champJoint(q, 'pla', q.pla.joint)}${resBox(R.pla.joint)}</div>
    ${champFormuleVerrou(q, 'plaHydro', 'pla|hydro', 'Plus-value plaque hydrofuge', q.pla.hydro, R.pla.hydro)}
    <p class="muted" style="font-size:13px;margin:2px 0 0">Surface des salles d'eau et salles de bain (base de la plus-value hydrofuge du plafond) : ${fmt(surfacePiecesEau(c))} m².</p>
    ${champPlaqueFeu('pla', q.pla.feu, R.pla.feu)}
    <div class="row" style="gap:8px;margin-top:10px"><button type="button" class="btn" data-plat-act="gen">Ajouter au métré</button></div>
    <p id="platStatut" class="muted" style="font-size:13px"></p></div>`;
}
// Seuil de déduction de la plâtrerie (doublage et cloisons) : une ouverture n'est déduite que si elle fait au moins 1,50 m²
const SEUIL_PLATRERIE = 1.5;
// Surface (m²) des menuiseries extérieures saisies dans les pièces (fenêtres, portes-fenêtres, baies, portes d'entrée) qui atteignent le seuil
function menuiseriesExtM2(c) {
  return piecesNvDe(c).reduce((a, p) => a + (p.menus || []).reduce((b, m) => {
    if (!(num(m.l) > 0 && num(m.h) > 0)) return b;
    const aire = num(m.l) * num(m.h) / 10000;
    return b + (aire >= SEUIL_PLATRERIE ? aire * (num(m.nb) || 1) : 0);
  }, 0), 0);
}
// Surface (m²) de toutes les menuiseries extérieures saisies, sans seuil (pour la case de formule du doublage)
function menuiseriesToutesM2(c) {
  return piecesNvDe(c).reduce((a, p) => a + (p.menus || []).reduce((b, m) => {
    if (!(num(m.l) > 0 && num(m.h) > 0)) return b;
    return b + num(m.l) * num(m.h) / 10000 * (num(m.nb) || 1);
  }, 0), 0);
}
// Enduit intérieur : périmètre des murs périphériques × hauteur de doublage, moins toutes les menuiseries extérieures
function enduitIntSurf(c) {
  const linP = (projetDe(c).murs || []).filter(m => (m.cat || 'peri') === 'peri').reduce((a, m) => a + num(m.longueur), 0);
  const hk = num(platNvDe(c).hauteurDoub);
  const brut = linP * hk, ded = menuiseriesToutesM2(c);
  return { linP, hk, brut, ded, net: Math.max(0, brut - ded) };
}
// Habillages des menuiseries (ml) : côtés (2 × hauteur) de chaque menuiserie, plus la largeur (sous-face du linteau) sauf volet roulant
function habillageMl(c) {
  return piecesNvDe(c).reduce((a, p) => a + (p.menus || []).reduce((b, m) => {
    if (!(num(m.l) > 0 && num(m.h) > 0)) return b;
    const nb = num(m.nb) || 1;
    const cotes = 2 * num(m.h) / 100;
    const linteau = m.volet === 'roulant' ? 0 : num(m.l) / 100;
    return b + (cotes + linteau) * nb;
  }, 0), 0);
}
// Hauteur standard des portes de passage (bloc-porte fin de chantier 204 cm)
const HAUTEUR_PORTE_M = 2.04;
// Surface (m²) des portes de passage et des façades de placard saisies dans les pièces, déduites du cloisonnement
// seulement si chaque élément fait au moins 1,50 m² (égal ou supérieur)
function portesEtPlacardsM2(c) {
  return piecesNvDe(c).reduce((a, p) => {
    const aireporte = LARGEUR_PORTE_NV * HAUTEUR_PORTE_M;
    const portes = aireporteOk(aireporte) ? nbPortesNv(p) * aireporte : 0;
    const facades = (p.facades || []).reduce((b, f) => {
      if (!(num(f.l) > 0 && num(f.h) > 0)) return b;
      const aire = num(f.l) * num(f.h) / 10000;
      return b + (aire >= SEUIL_PLATRERIE ? aire * (num(f.nb) || 1) : 0);
    }, 0);
    return a + portes + facades;
  }, 0);
}
// Surface (m²) de toutes les portes de passage et façades de placard, sans seuil (pour la case de formule du cloisonnement)
function portesEtPlacardsToutesM2(c) {
  return piecesNvDe(c).reduce((a, p) => {
    const aireporte = LARGEUR_PORTE_NV * HAUTEUR_PORTE_M;
    const portes = nbPortesNv(p) * aireporte;
    const facades = (p.facades || []).reduce((b, f) => (num(f.l) > 0 && num(f.h) > 0) ? b + num(f.l) * num(f.h) / 10000 * (num(f.nb) || 1) : b, 0);
    return a + portes + facades;
  }, 0);
}
function aireporteOk(aire) { return aire >= SEUIL_PLATRERIE; }
// Bande à joint : case choisie par ligne (cloisonnement, doublage, plafond). Rien n'est ajouté si la case est vide.
// Surface : même surface que la ligne pour l'instant (formule à préciser). Retourne false si l'ouvrage choisi manque.
function ajouterBandeJoint(c, L, formule, surface, titre) {
  const oJ = BIB.ouvrages.find(x => x.id === OUV_BANDE_JOINT && !x.supprime);
  const r = resultatFormuleJoint(formule, surface);
  if (!oJ || r === null) return false;
  ajouterLotSiAbsent(c.id, oJ.lot);
  // Formule « S × coefficient » : le détail affiche la surface S et le coefficient (ex. « S 138,08 × coef. 1,1 »)
  const coef = String(formule || '').trim().replace(',', '.').match(/^S\s*[×x*]\s*(\d+(\.\d+)?)$/i);
  const vJ = coef ? { nombre: coef[1], cote1: String(surface), cote2: '1' } : { nombre: '1', cote1: String(r), cote2: '1' };
  L.push({ uid: uid(), lot: oJ.lot, ouvrage: oJ.id, designation: `${oJ.designation} – ${titre}, ${fmt(r)} ${oJ.unite || 'm²'}`, unite: oJ.unite, valeurs: vJ, quantite: calcul(oJ, vJ), surface: null, prix: 'moyen', ...(coef ? { modeLigne: 'coef' } : {}), platNv: true, cree: new Date().toISOString() });
  return true;
}
function genererPlatNv(c) {
  delete c.metreGele;
  const q = platNvDe(c);
  const h = num(q.hauteur);
  // Cloisonnement et doublage : linéaire × hauteur, ou surface m² saisie directement (si les deux sont saisis, le linéaire prime)
  const sansHauteur = !(h > 0) && ['cloi', 'doub'].some(k => num(q[k].ml) > 0 && !(num(q[k].m2) > 0));
  const L = lignesDe(c.id).filter(l => !l.platNv);   // les anciennes lignes sont toujours retirées
  const manque = []; let nb = 0;
  // Ajoute une ligne au métré pour un ouvrage donné, en m², avec la surface indiquée (cote1)
  // detailTexte : texte affiché dans la colonne Détail (ex. « longueur (2 plaques × 1,20 m) × hauteur 2,70 m »)
  const ajouteM2 = (o, designation, surface, detailTexte) => {
    ajouterLotSiAbsent(c.id, o.lot);
    const v = { nombre: '1', cote1: String(surface), cote2: '1' };
    const ligne = { uid: uid(), lot: o.lot, ouvrage: o.id, designation, unite: o.unite, valeurs: v, quantite: calcul(o, v), surface: null, prix: 'moyen', platNv: true, cree: new Date().toISOString() };
    if (detailTexte) { v.src = 'Plus-value plaque'; ligne.detailTexte = detailTexte; }
    L.push(ligne);
    nb++;
  };
  // Plus-value plaque (hydrofuge, acoustique) saisie en ml : plaques de 1,20 m arrondies au-dessus, × hauteur
  const PLAQUE_ML = 1.2;
  const plusValueMl = (ml, hh) => {
    const n = ml > 0 && hh > 0 ? Math.ceil(ml / PLAQUE_ML) : 0;
    return { n, surf: n * PLAQUE_ML * hh, hh };
  };
  const ouvPlusValue = id => BIB.ouvrages.find(x => x.id === id && !x.supprime);
  const ouvHydro = 'OUV-0948', ouvFeu = 'OUV-0949', ouvAcou = 'OUV-0950';
  const ajouteMlPlus = (idOuv, nomPV, titre, ml, hh) => {
    const pv = plusValueMl(ml, hh);
    if (!(pv.surf > 0)) return;
    const o = ouvPlusValue(idOuv);
    if (!o) { manque.push(nomPV + ' ' + titre); return; }
    ajouteM2(o, `${o.designation} – ${titre} : ${pv.n} plaques × ${fmt(PLAQUE_ML)} m × ${fmt(hh)} m = ${fmt(pv.surf)} m²`, pv.surf, `${fmt(ml)} ml ÷ ${fmt(PLAQUE_ML)} = ${fmt(ml / PLAQUE_ML)} → ${pv.n} plaques × ${fmt(PLAQUE_ML)} m = ${fmt(pv.n * PLAQUE_ML)} m × ${fmt(hh)} m = ${fmt(pv.surf)} m²`);
  };
  const ajouteFeu = (titre, valeur) => {
    const m2 = num(valeur);
    if (!(m2 > 0)) return;
    const o = ouvPlusValue(ouvFeu);
    if (!o) { manque.push('plus-value coupe-feu ' + titre); return; }
    ajouteM2(o, `${o.designation} – ${titre}, ${fmt(m2)} m²`, m2, `plaque coupe-feu ${fmt(m2)} m² (liste 3, 6, 9 ou 15)`);
  };
  for (const [cle, titre] of [['cloi', 'cloisonnement'], ['doub', 'doublage']]) {
    const d0 = L.length;
    const ml = num(q[cle].ml), m2s = num(q[cle].m2);
    const hk = cle === 'doub' ? num(q.hauteurDoub) : h;   // le doublage a sa propre hauteur
    const viaMl = ml > 0 && hk > 0;
    const surfBrute = viaMl ? ml * hk : m2s;
    if (!(surfBrute > 0)) continue;
    const o = BIB.ouvrages.find(x => x.id === q[cle].ouv && !x.supprime);
    if (!o) { manque.push(titre); continue; }
    ajouterLotSiAbsent(c.id, o.lot);
    // 1. Type d'ouvrage : déduction doublage = menuiseries extérieures de 1,50 m² et plus ; cloisonnement = portes et façades de 1,50 m² et plus
    const ded = cle === 'doub' ? menuiseriesExtM2(c) : portesEtPlacardsM2(c);
    const net = Math.max(0, surfBrute - ded);
    const libDed = cle === 'doub' ? 'menuiseries de 1,50 m² et plus' : 'portes et façades de placard de 1,50 m² et plus';
    const base = viaMl ? `${fmt(ml)} ml × ${fmt(hk)} m` : `${fmt(m2s)} m² saisis`;
    // Saisi en linéaire × hauteur : le détail affiche L (linéaire) et H (hauteur) ; les déductions passent dans « nombre » (coefficient)
    const v = viaMl ? { nombre: String(surfBrute > 0 ? net / surfBrute : 1), cote1: String(ml), cote2: String(hk) } : { nombre: '1', cote1: String(net), cote2: '1' };
    L.push({ uid: uid(), lot: o.lot, ouvrage: o.id, designation: `${o.designation} – ${base}, moins ${libDed} : ${fmt(ded)} m²`, unite: o.unite, valeurs: v, quantite: calcul(o, v), surface: null, prix: 'moyen', ...(viaMl ? { modeLigne: 'lxh' } : {}), platNv: true, cree: new Date().toISOString() });
    nb++;
    // 2. Isolant : même surface nette que la plaque, × 1,05 (chute et découpe)
    if (q[cle].isol) {
      const oI = BIB.ouvrages.find(x => x.id === q[cle].isol && !x.supprime);
      if (!oI) manque.push('isolant ' + titre);
      else {
        const surfIsol = net;   // même surface nette que la plaque placo (mêmes déductions), puis + 5 % de chute et découpe
        ajouterLotSiAbsent(c.id, o.lot);
        const vI = viaMl ? { nombre: String(surfBrute > 0 ? surfIsol * 1.05 / surfBrute : 1), cote1: String(ml), cote2: String(hk) } : { nombre: '1', cote1: String(surfIsol * 1.05), cote2: '1' };
        L.push({ uid: uid(), lot: o.lot, ouvrage: oI.id, designation: `${oI.designation} – ${titre}, ${fmt(surfIsol)} m² plus 5 % marge de découpe = ${fmt(surfIsol * 1.05)} m²`, unite: oI.unite, valeurs: vI, quantite: calcul(oI, vI), surface: null, prix: 'moyen', ...(viaMl ? { modeLigne: 'lxh' } : {}), platNv: true, cree: new Date().toISOString() });
        nb++;
      }
    }
    // 3. Bande à joint : formule sans seuil (cloisonnement = linéaire × hauteur − portes et façades ; doublage = − menuiseries)
    const surfCase = cle === 'doub' ? Math.max(0, surfBrute - menuiseriesToutesM2(c)) : Math.max(0, surfBrute - portesEtPlacardsToutesM2(c));
    if ((q[cle].joint || '').trim()) { if (ajouterBandeJoint(c, L, q[cle].joint, surfCase, titre)) nb++; else manque.push('formule bande à joint ' + titre); }
    // 4. Plus-values : hydrofuge, puis acoustique (cloisonnement), puis coupe-feu
    ajouteMlPlus(ouvHydro, 'plus-value hydrofuge', titre, num(q[cle].hydro), hk);
    if (cle === 'cloi') ajouteMlPlus(ouvAcou, 'plus-value acoustique', titre, num(q.cloi.acou), hk);
    ajouteFeu(titre, q[cle].feu);
    for (let i = d0; i < L.length; i++) L[i].platBloc = cle;
  }
  // Enduit intérieur (plâtre projeté ou chaux-sable) : périmètre des murs périphériques × hauteur de doublage, moins les menuiseries extérieures
  const oEnd = q.enduit && q.enduit.ouv ? BIB.ouvrages.find(x => x.id === q.enduit.ouv && !x.supprime) : null;
  const enSurf = enduitIntSurf(c);
  if (q.enduit && q.enduit.ouv && !oEnd) manque.push('enduit intérieur');
  if (oEnd && enSurf.net > 0) {
    ajouterLotSiAbsent(c.id, oEnd.lot);
    const vE = { nombre: '1', cote1: String(enSurf.net), cote2: '1' };
    L.push({ uid: uid(), lot: oEnd.lot, ouvrage: oEnd.id, designation: `${oEnd.designation} – périmètre ${fmt(enSurf.linP)} m × hauteur de doublage ${fmt(enSurf.hk)} m, moins menuiseries extérieures : ${fmt(enSurf.ded)} m²`, unite: oEnd.unite, valeurs: vE, quantite: calcul(oEnd, vE), surface: null, prix: 'moyen', platNv: true, cree: new Date().toISOString() });
    nb++;
  }
  // Plafond : saisi directement en m², sans hauteur
  const m2 = num(q.pla.m2);
  const d0Pla = L.length;
  if (m2 > 0) {
    const o = BIB.ouvrages.find(x => x.id === q.pla.ouv && !x.supprime);
    if (!o) manque.push('plafond');
    else {
      ajouterLotSiAbsent(c.id, o.lot);
      // 1. Type d'ouvrage (surface du plafond, sans déduction)
      const v = { nombre: '1', cote1: String(m2), cote2: '1' };
      L.push({ uid: uid(), lot: o.lot, ouvrage: o.id, designation: `${o.designation} – ${fmt(m2)} m²`, unite: o.unite, valeurs: v, quantite: calcul(o, v), surface: null, prix: 'moyen', platNv: true, cree: new Date().toISOString() });
      nb++;
      // 2. Isolant : surface du plafond × 1,05
      if (q.pla.isol) {
        const oI = BIB.ouvrages.find(x => x.id === q.pla.isol && !x.supprime);
        if (!oI) manque.push('isolant plafond');
        else {
          ajouterLotSiAbsent(c.id, o.lot);
          const vI = { nombre: '1', cote1: String(m2 * 1.05), cote2: '1' };
          L.push({ uid: uid(), lot: o.lot, ouvrage: oI.id, designation: `${oI.designation} – plafond, ${fmt(m2)} m² × 1,05 = ${fmt(m2 * 1.05)} m²`, unite: oI.unite, valeurs: vI, quantite: calcul(oI, vI), surface: null, prix: 'moyen', platNv: true, cree: new Date().toISOString() });
          nb++;
        }
      }
      // 3. Bande à joint : surface du plafond
      if ((q.pla.joint || '').trim()) { if (ajouterBandeJoint(c, L, q.pla.joint, m2, 'plafond')) nb++; else manque.push('formule bande à joint plafond'); }
      // 4. Plus-values : hydrofuge (formule, S = surface des salles d'eau et de bain), puis coupe-feu
      if ((q.pla.hydro || '').trim()) {
        const oH = ouvPlusValue(ouvHydro);
        const sEau = surfacePiecesEau(c);
        const rH = resultatFormuleJoint(q.pla.hydro, sEau);
        if (!(rH > 0)) { /* rien à ajouter : surface des salles d'eau nulle ou formule incorrecte */ if (rH === null) manque.push('formule plus-value hydrofuge plafond'); }
        else if (!oH) manque.push('plus-value hydrofuge plafond');
        else ajouteM2(oH, `${oH.designation} – plafond salles d'eau et de bain, ${fmt(rH)} m²`, rH, `formule (${q.pla.hydro}) avec S = surface des salles d'eau et de bain ${fmt(surfacePiecesEau(c))} m²`);
      }
      ajouteFeu('plafond', q.pla.feu);
    }
  }
  for (let i = d0Pla; i < L.length; i++) L[i].platBloc = 'pla';
  sauverLignes(c.id, L);
  renderMetre();
  if (sansHauteur) return 'Plâtrerie : hauteur manquante.';
  if (manque.length) return 'Plâtrerie : type manquant.';
  return nb ? 'Plâtrerie régénérée.' : 'Plâtrerie : linéaire manquant.';
}
// Bouton « Générer le métré depuis le configurateur » : relance les trois blocs ; chacun retire ses anciennes lignes
// et ne remet que ce qui est encore saisi. Les lignes saisies à la main ne sont pas touchées.
function genererMetreConfigurateur(c) {
  const msgs = [genererPiecesNv(c), genererPlatNv(c), genererPeinture(c)];
  // Le bouton remet le métré en service : les lignes de la fiche (murs, toiture, charpente, terrain…) sont alors recréées aussi
  delete c.metreGele;
  majLignesDepuisConfigurateur(c);
  renderMetre();
  // Message court : « Métré régénéré. », suivi seulement des éléments manquants
  const manquants = msgs.filter(m => m && /manquant/.test(m));
  return ['Métré régénéré.', ...manquants].join(' ');
}
if ($('btnGenererConfig')) $('btnGenererConfig').addEventListener('click', () => {
  const c = chantiers.find(x => x.id === courantId);
  if (!c) return;
  const msg = genererMetreConfigurateur(c);
  lsSet('chantiers', chantiers); marquerChantier(c.id);
  if ($('cfgStatut')) $('cfgStatut').textContent = msg;
});
// Remise à zéro : vide toutes les cases vertes (cases remplies) du configurateur.
// Chaque case vidée envoie son événement « change » : les gestionnaires enregistrent le vide dans les données.
// Les lignes du métré générées par ces cases sont ensuite retirées ; les lignes saisies à la main restent.
function remiseAZeroConfigurateur(c, demander = true) {
  if (demander && !confirm('Remise à zéro du configurateur : toutes les cases du configurateur de ce chantier seront vidées (pièces, plâtrerie, peinture, blocs). Le métré n\'est pas modifié ; utilisez « Retirer les lignes générées » pour retirer les lignes déjà produites. Le terrain et les renseignements du client sont conservés. Continuer ?')) return;
  razConfigurateur(c);
  if ($('cfgStatut')) $('cfgStatut').textContent = 'Configurateur mis à zéro. Le métré n\'a pas été modifié.';
}
// Vide les cases du configurateur du chantier, sans toucher aux lignes du métré ni aux lots
function razConfigurateur(c) {
  const terrainGarde = refKanbanDe(c) && c.projet && c.projet.terrain ? JSON.parse(JSON.stringify(c.projet.terrain)) : null;   // chantier Kanban : terrain gardé
  const f = $('vConfig');
  if (f) {
    f.querySelectorAll('input:not([type=checkbox]):not([type=button]),select,textarea').forEach(el => {
      if (el.value === '' || el.id === 'btnGenererConfig') return;
      el.value = '';
      el.dispatchEvent(new Event('change', { bubbles: true }));
    });
  }
  delete c.projet;
  if (terrainGarde) projetDe(c).terrain = terrainGarde;
  c.elec = { pieces: [], piecesNv: [] };
  c.platNv = {};
  c.peinture = {};
  lsSet('chantiers', chantiers); marquerChantier(c.id);
  renderPiecesNv(); renderPlatNv(); renderPeinture();
}
// Remise à zéro du métré du chantier ouvert : toutes ses lignes (saisies à la main comprises) et ses lots ; le configurateur n'est pas modifié
function remiseAZeroMetre() {
  const c = chantiers.find(x => x.id === courantId);
  if (!c) { if ($('cfgStatut')) $('cfgStatut').textContent = 'Ouvrez d\'abord un chantier.'; return; }
  if (!confirm('Remise à zéro du métré de ce chantier : toutes les lignes du métré seront effacées, y compris celles saisies à la main. Le configurateur n\'est pas modifié. Continuer ?')) return;
  sauverLignes(c.id, []);
  c.lots = [];
  c.metreGele = true;   // le métré reste vide tant que « Ajouter au métré » n'est pas relancé
  lsSet('chantiers', chantiers); marquerChantier(c.id);
  renderMetre();
  if ($('cfgStatut')) $('cfgStatut').textContent = 'Métré du chantier remis à zéro. Le configurateur est conservé.';
}
if ($('btnRazMetre')) $('btnRazMetre').addEventListener('click', remiseAZeroMetre);
// Vide le configurateur du chantier : blocs du configurateur (projet sauf terrain), pièces, plâtrerie, peinture et toutes les lignes du métré.
// Restent : le terrain (fiche client) et l'identité du dossier (référence Kanban, client).
function razTotale(c) {
  // Le terrain (fiche client) est gardé : on le mémorise avant de vider les cases
  const terrainGarde = refKanbanDe(c) && c.projet && c.projet.terrain ? JSON.parse(JSON.stringify(c.projet.terrain)) : null;   // chantier Kanban : terrain gardé
  const f = $('vConfig');
  if (f) {
    f.querySelectorAll('input:not([type=checkbox]):not([type=button]),select,textarea').forEach(el => {
      if (el.value === '' || el.id === 'btnGenererConfig') return;
      el.value = '';
      el.dispatchEvent(new Event('change', { bubbles: true }));
    });
  }
  delete c.projet;                 // les blocs du configurateur repartent de leurs valeurs par défaut (projetDe)
  if (terrainGarde) projetDe(c).terrain = terrainGarde;
  c.elec = { pieces: [], piecesNv: [] };
  c.platNv = {};
  c.peinture = {};
  sauverLignes(c.id, []);          // tout le métré du chantier, lignes saisies à la main comprises
  c.lots = [];                     // plus aucun titre de lot : le métré repart vide
  lsSet('chantiers', chantiers); marquerChantier(c.id);
  renderPiecesNv(); renderPlatNv(); renderPeinture();
}
if ($('btnRaz')) $('btnRaz').addEventListener('click', () => {
  const c = chantiers.find(x => x.id === courantId);
  if (c) remiseAZeroConfigurateur(c, true);
});
$('vConfig') && $('vConfig').addEventListener('click', e => {
  const v = e.target.closest('[data-verrou]');
  if (v) {
    const c = chantiers.find(x => x.id === courantId);
    if (!c) return;
    const q = platNvDe(c); q.verrou = q.verrou || {};
    q.verrou[v.dataset.verrou] = !verrouJoint(q, v.dataset.verrou);
    lsSet('chantiers', chantiers); marquerChantier(c.id);
    renderPlatNv();
    return;
  }
  const b = e.target.closest('[data-plat-act]');
  if (!b) return;
  const c = chantiers.find(x => x.id === courantId);
  if (!c) return;
  const msg = genererPlatNv(c);
  if ($('platStatut')) $('platStatut').textContent = msg;
  lsSet('chantiers', chantiers); marquerChantier(c.id);
});
$('vConfig') && $('vConfig').addEventListener('change', e => {
  const t = e.target.closest('[data-plat]');
  if (!t) return;
  const c = chantiers.find(x => x.id === courantId);
  if (!c) return;
  const q = platNvDe(c);
  const [cle, sous] = t.dataset.plat.split('|');
  if (cle === 'hauteur') q.hauteur = t.value; else if (cle === 'hauteurDoub') q.hauteurDoub = t.value; else q[cle][sous] = t.value;
  lsSet('chantiers', chantiers); marquerChantier(c.id);
});
/* ============ Bloc peinture (séparé, comme la plâtrerie) ============ */
// Murs : linéaire × hauteur, moins les menuiseries extérieures, portes et façades d'au moins 1,50 m².
// Plafond : surface saisie directement en m². Données dans c.peinture ; lignes marquées peiNv.
function peiDe(c) {
  const q = c.peinture = c.peinture || {};
  q.hauteur = q.hauteur || '';
  q.murs = q.murs || { ml: '', ouv: 'OUV-0689' };
  q.plafond = q.plafond || { m2: '', ouv: 'OUV-0690' };
  q.portesFacades = q.portesFacades || { ouv: 'OUV-0691' };
  return q;
}
// Hauteur : seulement celle saisie dans le bloc peinture (jamais celle de la plâtrerie)
function peiHauteur(c) { return num(peiDe(c).hauteur); }
// Surface brute de toutes les portes de passage et façades de placard du configurateur (sans seuil)
function portesFacadesBrutM2(c) {
  return piecesNvDe(c).reduce((a, p) => a + nbPortesNv(p) * LARGEUR_PORTE_NV * HAUTEUR_PORTE_M
    + (p.facades || []).reduce((b, f) => b + (num(f.l) > 0 && num(f.h) > 0 ? num(f.l) * num(f.h) / 10000 * (num(f.nb) || 1) : 0), 0), 0);
}
// Surface totale de toutes les menuiseries extérieures du configurateur, sans seuil
function menuiseriesTotalM2(c) {
  return piecesNvDe(c).reduce((a, p) => a + (p.menus || []).reduce((b, m) => b + (num(m.l) > 0 && num(m.h) > 0 ? num(m.l) * num(m.h) / 10000 * (num(m.nb) || 1) : 0), 0), 0);
}
// Linéaire des murs à peindre : somme des linéaires saisis dans chaque pièce du configurateur de pièces
// Plafond : somme des surfaces des pièces du configurateur (terrasse exclue), utilisée si le champ est vide
function surfacePiecesPlafond(c) { return piecesNvDe(c).filter(p => (typePieceNv(p.nom) || '') !== 'Extérieur (terrasse)').reduce((a, p) => a + num(p.surf), 0); }
// Murs à peindre : doublage (une face) et cloisons (deux faces), hauteurs du bloc peinture ou, à défaut, de la plâtrerie
// Si le linéaire est vide, la surface m² saisie dans la plâtrerie est prise telle quelle (sans hauteur nécessaire)
function peiMursDetail(c) {
  const pl = platNvDe(c);
  const h = peiHauteur(c) || num(pl.hauteur);
  const hD = h;   // même hauteur que celle du bloc peinture (ou de la plâtrerie à défaut)
  const mlD = num(pl.doub.ml), mlC = num(pl.cloi.ml);
  const m2D = num(pl.doub.m2), m2C = num(pl.cloi.m2);
  const surfD = mlD > 0 ? mlD * hD : m2D;
  const surfC = mlC > 0 ? mlC * h : m2C;
  return { h, hD, mlD, mlC, surfD, surfC };
}
// Portes de passage (surface brute, une fois) et façades de placard (surface brute, une fois ici)
function portesBrutM2(c) { return piecesNvDe(c).reduce((a, p) => a + nbPortesNv(p) * LARGEUR_PORTE_NV * HAUTEUR_PORTE_M, 0); }
function facadesBrutM2(c) { return piecesNvDe(c).reduce((a, p) => a + (p.facades || []).reduce((b, f) => b + (num(f.l) > 0 && num(f.h) > 0 ? num(f.l) * num(f.h) / 10000 * (num(f.nb) || 1) : 0), 0), 0); }
function peiLineaire(c) { return piecesNvDe(c).reduce((a, p) => a + num(p.perim), 0); }
function optPei(re, val, key, titre) {
  if (key) return optListeOuvrages(key, titre, () => [...new Set(BIB.ouvrages.filter(o => ouvActif(o) && o.unite === 'm²' && re.test(o.designation)).map(o => o.designation))], val, '');
  return BIB.ouvrages.filter(o => ouvActif(o) && o.unite === 'm²' && re.test(o.designation))
    .map(o => `<option value="${esc(o.id)}" ${o.id === val ? 'selected' : ''}>${esc(o.designation)}</option>`).join('');
}
function renderPeinture() {
  const host = $('cfgPeinture');
  if (!host) return;
  const c = chantiers.find(x => x.id === courantId);
  if (!c || !BIB) { host.innerHTML = ''; return; }
  const q = peiDe(c);
  host.innerHTML = `${tabTitre('D. Peinture (bloc séparé)')}<div class="bloc bloc-lettre">
    <p class="muted">Murs : doublage × hauteur, moins les menuiseries extérieures. Cloisons : cloisonnement × hauteur, moins les portes de passage et les façades de placard (façades × 2), le tout × 2 (deux faces). Total = murs + cloisons. Portes et placards peints : surface × 2. Plafond : surface en m².</p>
    <p class="muted" style="font-size:13px;margin:0 0 6px">Surface totale des menuiseries extérieures : ${fmt(menuiseriesTotalM2(c))} m² (déduite des murs).</p>
    <div class="row" style="flex-wrap:wrap;gap:6px;align-items:center">
      <label style="font-size:12px">Hauteur sous plafond m <input data-pei="hauteur" inputmode="decimal" value="${esc(q.hauteur || '')}" placeholder="${esc(platNvDe(c).hauteur || '')}" style="width:90px"></label>
      <span class="muted" style="font-size:12px">(vide = hauteur du bloc plâtrerie)</span></div>
    <div class="row" style="flex-wrap:wrap;gap:6px;margin-top:6px;align-items:center">
      <strong style="font-size:13px;min-width:120px">Murs</strong>
      <span style="font-size:13px">Doublage ${fmt(peiMursDetail(c).surfD)} m² + cloisons ${fmt(peiMursDetail(c).surfC)} m² × 2 (linéaires ou surfaces saisis dans la plâtrerie)</span>
      ${selCrayon('pei-murs-ouv', 'Peinture : murs', `<select data-pei="murs|ouv" style="flex:1;min-width:0">${optPei(/^Peinture (acrylique )?murs/i, q.murs.ouv, 'pei-murs-ouv', 'Peinture : murs')}</select>`)}</div>
    <div class="row" style="flex-wrap:wrap;gap:6px;margin-top:6px;align-items:center">
      <strong style="font-size:13px;min-width:120px">Portes et placards</strong>
      <span style="font-size:13px">Surface des portes de passage et façades de placard : ${fmt(portesFacadesBrutM2(c))} m² × 2 = ${fmt(portesFacadesBrutM2(c) * 2)} m² (deux faces)</span>
      ${selCrayon('pei-portesFacades-ouv', 'Peinture : portes et placards', `<select data-pei="portesFacades|ouv" style="flex:1;min-width:0">${optPei(/^Peinture/i, q.portesFacades.ouv, 'pei-portesFacades-ouv', 'Peinture : portes et placards')}</select>`)}</div>
    <div class="row" style="flex-wrap:wrap;gap:6px;margin-top:6px;align-items:center">
      <strong style="font-size:13px;min-width:120px">Plafond</strong>
      <label style="font-size:12px">Surface m² <input data-pei="plafond|m2" inputmode="decimal" value="${esc(q.plafond.m2 || '')}" placeholder="${esc(fmt(surfacePiecesPlafond(c)))}" style="width:80px"></label> <span class="muted" style="font-size:12px">vide = total des pièces : ${fmt(surfacePiecesPlafond(c))} m²</span>
      ${selCrayon('pei-plafond-ouv', 'Peinture : plafond', `<select data-pei="plafond|ouv" style="flex:1;min-width:0">${optPei(/^Peinture plafond/i, q.plafond.ouv, 'pei-plafond-ouv', 'Peinture : plafond')}</select>`)}</div>
    <div class="row" style="gap:8px;margin-top:10px"><button type="button" class="btn" data-pei-act="gen">Ajouter au métré</button></div>
    <p id="peiStatut" class="muted" style="font-size:13px"></p></div>`;
}
function genererPeinture(c) {
  delete c.metreGele;
  const q = peiDe(c);
  const h = peiHauteur(c);
  const L = lignesDe(c.id).filter(l => !l.peiNv);
  const manque = []; let nb = 0;
  const ajoute = (o, v, designation) => {
    ajouterLotSiAbsent(c.id, o.lot);
    L.push({ uid: uid(), lot: o.lot, ouvrage: o.id, designation, unite: o.unite, valeurs: v, quantite: calcul(o, v), surface: null, prix: 'moyen', peiNv: true, cree: new Date().toISOString() });
    nb++;
  };
  const mur = peiMursDetail(c);
  const sansHauteur = (mur.mlD > 0 && !(mur.hD > 0)) || (mur.mlC > 0 && !(mur.h > 0));
  if ((mur.surfD + mur.surfC) > 0 && !sansHauteur) {
    const o = BIB.ouvrages.find(x => x.id === q.murs.ouv && !x.supprime);
    if (!o) manque.push('murs');
    else {
      // Murs : doublage × hauteur, moins les menuiseries extérieures
      // Cloisons : cloisonnement × hauteur, moins les portes de passage et les façades de placard (façades × 2), puis × 2 (deux faces)
      // Total : murs + cloisons
      const menus = menuiseriesTotalM2(c);
      const murNet = Math.max(0, mur.surfD - menus);
      const portes = portesBrutM2(c), facades = facadesBrutM2(c);
      const cloisNet = Math.max(0, mur.surfC - portes - 2 * facades);
      const cloisDouble = cloisNet * 2;
      const total = murNet + cloisDouble;
      ajoute(o, { nombre: '1', cote1: String(total), cote2: '1' }, `${o.designation} – murs ${fmt(mur.surfD)} m² − menuiseries ${fmt(menus)} m² = ${fmt(murNet)} m² ; cloisons ${fmt(mur.surfC)} m² − portes ${fmt(portes)} m² − façades ${fmt(2 * facades)} m² = ${fmt(cloisNet)} m² × 2 = ${fmt(cloisDouble)} m²`);
    }
  }
  // Portes de passage et façades de placard : surface totale brute × 2 (deux faces), sans déduction
  const pf = portesFacadesBrutM2(c);
  if (pf > 0) {
    const o = BIB.ouvrages.find(x => x.id === q.portesFacades.ouv && !x.supprime);
    if (!o) manque.push('portes et placards');
    else ajoute(o, { nombre: '1', cote1: String(pf * 2), cote2: '1' }, `${o.designation} – portes et façades de placard ${fmt(pf)} m² × 2`);
  }
  const m2 = num(q.plafond.m2) || surfacePiecesPlafond(c);
  if (m2 > 0) {
    const o = BIB.ouvrages.find(x => x.id === q.plafond.ouv && !x.supprime);
    if (!o) manque.push('plafond');
    else ajoute(o, { nombre: '1', cote1: String(m2), cote2: '1' }, `${o.designation} – ${fmt(m2)} m²`);
  }
  sauverLignes(c.id, L);
  renderMetre();
  if (sansHauteur) return 'Peinture : hauteur manquante.';
  if (manque.length) return 'Peinture : type manquant.';
  return nb ? 'Peinture régénérée.' : 'Peinture : surface manquante.';
}
$('vConfig') && $('vConfig').addEventListener('click', e => {
  const b = e.target.closest('[data-pei-act]');
  if (!b) return;
  const c = chantiers.find(x => x.id === courantId);
  if (!c) return;
  const msg = genererPeinture(c);
  if ($('peiStatut')) $('peiStatut').textContent = msg;
  lsSet('chantiers', chantiers); marquerChantier(c.id);
});
$('vConfig') && $('vConfig').addEventListener('change', e => {
  const t = e.target.closest('[data-pei]');
  if (!t) return;
  const c = chantiers.find(x => x.id === courantId);
  if (!c) return;
  const q = peiDe(c);
  const [cle, sous] = t.dataset.pei.split('|');
  if (cle === 'hauteur') q.hauteur = t.value; else q[cle][sous] = t.value;
  lsSet('chantiers', chantiers); marquerChantier(c.id);
});
function majPieceNv(c, cle, val) {
  const [id, champ, k, sous] = cle.split('|');
  const p = piecesNvDe(c).find(x => x.id === id);
  if (!p) return;
  if (champ === 'menu') { p.menus = p.menus || []; if (p.menus[k]) p.menus[k][sous] = val; }
  else if (champ === 'facade') { p.facades = p.facades || []; if (p.facades[k]) p.facades[k][sous] = val; }
  else if (champ === 'bloc') { p.blocs = p.blocs || []; if (p.blocs[k]) p.blocs[k][sous] = val; }
  else if (champ === 'app') { p.app = p.app || {}; p.app[k] = val; }
  else p[champ] = val;
  lsSet('chantiers', chantiers); marquerChantier(c.id);
}
$('vConfig') && $('vConfig').addEventListener('click', e => {
  const pa = e.target.closest('[data-piece-act]');
  if (pa) {
    const c = chantiers.find(x => x.id === courantId);
    if (!c) return;
    const [act, id] = pa.dataset.pieceAct.split(':');
    if (act === 'fold') { piecesDepliees.has(id) ? piecesDepliees.delete(id) : piecesDepliees.add(id); renderPiecesNv(); return; }
    // Monter ou descendre la pièce d'une place, puis remettre les lignes dans le même ordre
    const liste = piecesNvDe(c);
    const i = liste.findIndex(p => p.id === id), j = act === 'haut' ? i - 1 : i + 1;
    if (i < 0 || j < 0 || j >= liste.length) return;
    [liste[i], liste[j]] = [liste[j], liste[i]];
    sauverLignes(c.id, ordonnerLignesPieces(c));
    lsSet('chantiers', chantiers); marquerChantier(c.id);
    renderPiecesNv(); renderPlatNv(); renderPeinture();
    return;
  }
  const b = e.target.closest('[data-nv-act]');
  if (!b) return;
  const c = chantiers.find(x => x.id === courantId);
  if (!c) return;
  const [act, id, k] = b.dataset.nvAct.split(':');
  const liste = piecesNvDe(c);
  if (act === 'add') { liste.push({ id: 'pn' + uid(), nom: '', surf: '', revet: '', menus: [], portes: '', app: {} }); piecesDepliees.add(liste[liste.length - 1].id); }   // la nouvelle pièce s'ouvre pour la saisie
  else if (act === 'del') c.elec.piecesNv = liste.filter(p => p.id !== id);
  else if (act === 'addmenu') { const p = liste.find(x => x.id === id); if (p) (p.menus = p.menus || []).push({ id: 'me' + uid(), type: '', vantaux: '', ouvrant: '', l: '', h: '', vitrage: '', esth: '', secu: '', pose: '', volet: '', ferm: '', moust: '', ouv: '', nb: '1' }); }
  else if (act === 'delmenu') { const p = liste.find(x => x.id === id); if (p) p.menus.splice(Number(k), 1); }
  else if (act === 'addbloc') { const p = liste.find(x => x.id === id); if (p) (p.blocs = p.blocs || []).push({ dim: '83×204', dest: '', pousse: '', ame: '', type: '', fin: '', pose: '', ouv: '', nb: '1' }); }
  else if (act === 'delbloc') { const p = liste.find(x => x.id === id); if (p) p.blocs.splice(Number(k), 1); }
  else if (act === 'addfacade') { const p = liste.find(x => x.id === id); if (p) (p.facades = p.facades || []).push({ vantaux: '', ouvrant: '', structure: '', finition: '', pose: '', amort: '', l: '', h: '', nb: '1' }); }
  else if (act === 'delfacade') { const p = liste.find(x => x.id === id); if (p) p.facades.splice(Number(k), 1); }
  else if (act === 'gen') { const msg = genererPiecesNv(c); if ($('nvStatut')) $('nvStatut').textContent = msg; lsSet('chantiers', chantiers); marquerChantier(c.id); return; }
  else if (act === 'gen-maison') { const msg = genererEquipementsMaison(c); if ($('nvStatut')) $('nvStatut').textContent = msg; lsSet('chantiers', chantiers); marquerChantier(c.id); return; }
  lsSet('chantiers', chantiers); marquerChantier(c.id);
  renderPiecesNv(); renderPlatNv(); renderPeinture();
});
$('vConfig') && $('vConfig').addEventListener('change', e => {
  const t = e.target.closest('[data-nv]');
  if (!t) return;
  const c = chantiers.find(x => x.id === courantId);
  if (c) majPieceNv(c, t.dataset.nv, t.value);
  if (c && /\|menu\|\d+\|volet$|\|facade\|\d+\|ouvrant$/.test(t.dataset.nv)) renderPiecesNv();   // « Compris volet roulant » fait apparaître Fermeture
});

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
    .filter(o => ouvActif(o) && o.unite === unite && re.test(o.designation) && !(exclure && exclure.test(o.designation)))
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
  if (PIECES_ANCIEN_VEILLE) return 'Ancien configurateur de pièces en veille : aucune ligne générée.';
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
    // Murs bruts : linéaire × hauteur. Ouvertures (portes, fenêtres, passages libres) de 1 m² ou plus déduites
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
      if (une >= SEUIL_DEDUCTION) ded += total;   // plâtrerie : seules les ouvertures de 1 m² ou plus (une à une)
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
  if (dedTot > 0) msg += ' Ouvertures de 1 m² ou plus déduites des murs : ' + fmt(dedTot) + ' m².';
  const uniques = manquants.filter((d, i, t) => t.indexOf(d) === i);
  if (uniques.length) msg += ' À compléter : ' + uniques.join(' ; ') + '.';
  return msg;
}
// Après suppression d'une pièce : retire du métré de CE chantier les lignes que le configurateur produisait et qui n'ont plus de source.
// Les lignes saisies à la main ne sont jamais touchées ; les autres chantiers ne sont pas concernés.
function retirerLignesSansSource(c) {
  if (!c || !BIB || PIECES_ANCIEN_VEILLE) return 0;   // en veille : rien n'est retiré (les lignes restent)
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
  renderPiecesNv(); renderPlatNv(); renderPeinture();
  const P = platDe(c), pieces = piecesDe(c);
  const opt = (liste, val) => `<option value="">— choisir —</option>` + liste.map(d => `<option ${d === val ? 'selected' : ''}>${esc(d)}</option>`).join('');
  const optPortes = () => `<option value="">— choisir —</option><option>${esc(PORTE_AUTO)}</option>` + optDesignations('pieces-portes', 'Portes : type', () => platPortes(), '', '').replace('<option value=""></option>', '');
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
        ${selCrayon('pieces-sol', 'Revêtement de sol (pièce)', `<select data-plrow="${i}:sol" style="flex:1;min-width:0">${optDesignations('pieces-sol', 'Revêtement de sol (pièce)', () => platSols(), p.sol || '', '— choisir —')}</select>`)}
      </div>
      <p class="muted" style="margin:10px 0 2px">Murs (linéaire brut, hauteur ${num(P.hauteur) ? num(P.hauteur) + ' m' : 'à saisir'})</p>
      ${subListe(p.cloisons || [], i, 'cloisons', x => `Cloison · ${esc(x.type)} · ${fmt(num(x.ml))} ml`)}
      <div class="row" style="margin-top:4px">${selCrayon('pieces-cloisons', 'Cloisons : type', `<select id="pl_${i}_cloisons_type" style="flex:1;min-width:0">${optDesignations('pieces-cloisons', 'Cloisons : type', () => platCloisons(), '', '— choisir —')}</select>`)}<input id="pl_${i}_cloisons_ml" inputmode="decimal" placeholder="ml" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:cloisons">Ajouter au métré</button></div>
      ${subListe(p.doublages || [], i, 'doublages', x => `Doublage · ${esc(x.type)} · ${fmt(num(x.ml))} ml`)}
      <div class="row" style="margin-top:4px">${selCrayon('pieces-doublages', 'Doublages : type', `<select id="pl_${i}_doublages_type" style="flex:1;min-width:0">${optDesignations('pieces-doublages', 'Doublages : type', () => platDoublages(), '', '— choisir —')}</select>`)}<input id="pl_${i}_doublages_ml" inputmode="decimal" placeholder="ml" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:doublages">Ajouter au métré</button></div>
      ${subListe(p.portes || [], i, 'portes', x => `Porte · ${esc(x.type)} · ${num(x.nb)} × ${fmt(num(x.largeur))} × ${fmt(num(x.hauteur))} m`)}
      <div class="row" style="margin-top:4px;flex-wrap:wrap">${selCrayon('pieces-portes', 'Portes : type', `<select id="pl_${i}_portes_type" style="flex:1;min-width:0">${optPortes()}</select>`)}<input id="pl_${i}_portes_nb" inputmode="numeric" placeholder="1" placeholder="Nb" style="width:60px"><input id="pl_${i}_portes_l" inputmode="decimal" placeholder="Larg. m" style="width:80px"><input id="pl_${i}_portes_h" inputmode="decimal" placeholder="Haut. m" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:portes">+ Porte</button></div>
      ${menusDe(p).length ? '<p class="muted" style="margin:10px 0 2px">Menuiseries extérieures de la pièce</p>' : ''}
      ${menusDe(p).map((x, k) => `<div class="ouv"><span>${esc(FICHE_OUV[x.type] || x.type)} · ${num(x.nb)} × ${fmt(num(x.largeur))} × ${fmt(num(x.hauteur))} m${x.materiau ? ' · ' + esc(FICHE_MAT[x.materiau]) + (finTxt(x.fin, x.ral) ? ' · ' + esc(finTxt(x.fin, x.ral)) : '') : ''}${x.appui ? ' · appui ' + esc(appuiNom(x.appui)) : ''}</span><span style="display:flex;gap:6px;flex:0 0 auto"><button type="button" class="btn small" data-valider-menu="${i}:${k}">Valider</button><button type="button" class="btn small danger" data-pldel="${i}:menus:${k}">✕</button></span></div>`).join('')}
      <div class="sousbloc" style="padding:8px;margin:8px 0"><strong style="display:block;margin-bottom:4px">Ajouter une menuiserie extérieure</strong>
        <label style="display:block;font-size:14px;margin:4px 0">Type</label>${selCrayon('pieces-menus-type', 'Menuiserie : type d\'ouvrant', `<select id="pl_${i}_menus_type" style="width:100%">${optCodes('pieces-menus-type', 'Menuiserie : type d\'ouvrant', Object.entries(FICHE_OUV), '', '')}</select>`)}
        <div class="row" style="gap:6px;flex-wrap:wrap"><div style="flex:1;min-width:90px"><label style="display:block;font-size:14px;margin:4px 0">Nombre</label><input id="pl_${i}_menus_nb" inputmode="numeric" placeholder="1"></div>
        <div style="flex:1;min-width:90px"><label style="display:block;font-size:14px;margin:4px 0">Largeur (m)</label><input id="pl_${i}_menus_l" inputmode="decimal" placeholder="ex. 1,20"></div>
        <div style="flex:1;min-width:90px"><label style="display:block;font-size:14px;margin:4px 0">Hauteur (m)</label><input id="pl_${i}_menus_h" inputmode="decimal" placeholder="ex. 1,35"></div></div>
        <label style="display:block;font-size:14px;margin:4px 0">Matériau</label>${selCrayon('pieces-menus-mat', 'Menuiserie : matériau', `<select id="pl_${i}_menus_mat" style="width:100%">${optCodes('pieces-menus-mat', 'Menuiserie : matériau', matsPour('ouvrant'), 'PVC', '')}</select>`)}
        <label style="display:block;font-size:14px;margin:4px 0">Finition</label>${selCrayon('pieces-menus-fin', 'Menuiserie : finition', `<select id="pl_${i}_menus_fin" style="width:100%">${optCodes('pieces-menus-fin', 'Menuiserie : finition', finsPour('PVC'), 'std', '')}</select>`)}
        ${selCrayon('pieces-ral', 'Menuiserie : couleur RAL', `<select id="pl_${i}_menus_ral" style="width:100%;display:none;margin-top:4px">${optCodes('pieces-ral', 'Menuiserie : couleur RAL', RAL_LISTE.map(([k, t]) => [k, `${k} · ${t}`]), '', '— choisir la couleur —')}</select>`)}
        <label style="display:block;font-size:14px;margin:4px 0">Volet</label>${selCrayon('pieces-volet', 'Menuiserie : volet', `<select id="pl_${i}_menus_volet" style="width:100%">${optCodes('pieces-volet', 'Menuiserie : volet', Object.entries(FICHE_VOLET), '', '')}</select>`)}
        <div id="pl_${i}_menus_volbox" style="display:none;border-left:3px solid #E07838;padding-left:8px;margin:4px 0">
          <label style="display:block;font-size:14px;margin:4px 0">Matériau du volet</label>${selCrayon('pieces-volet-mat', 'Volet : matériau', `<select id="pl_${i}_menus_matvolet" style="width:100%">${optCodes('pieces-volet-mat', 'Volet : matériau', matsPour('ouvrant'), 'alu', '')}</select>`)}
          <label style="display:block;font-size:14px;margin:4px 0">Finition du volet</label>${selCrayon('pieces-volet-fin', 'Volet : finition', `<select id="pl_${i}_menus_finvolet" style="width:100%">${optCodes('pieces-volet-fin', 'Volet : finition', finsPour('alu'), 'std', '')}</select>`)}
          ${selCrayon('pieces-volet-ral', 'Volet : couleur RAL', `<select id="pl_${i}_menus_ralvolet" style="width:100%;display:none;margin-top:4px">${optCodes('pieces-volet-ral', 'Volet : couleur RAL', RAL_LISTE.map(([k, t]) => [k, `${k} · ${t}`]), '', '— choisir la couleur —')}</select>`)}
        </div>
        <label style="display:block;font-size:14px;margin:4px 0">Appui de fenêtre</label>${selCrayon('pieces-appui', 'Menuiserie : appui', `<select id="pl_${i}_menus_appui" style="width:100%">${optListeOuvrages('pieces-appui', 'Menuiserie : appui', () => appuisFenetreBase(), '', '— aucun —')}</select>`)}
        <div style="margin:6px 0"><label style="font-size:14px;margin-right:12px"><input type="checkbox" id="pl_${i}_menus_elec" style="width:auto;height:auto"> Volet roulant motorisé</label>
        <label style="font-size:14px;margin-right:12px"><input type="checkbox" id="pl_${i}_menus_securit" style="width:auto;height:auto"> Verre sécurit</label>
        <label style="font-size:14px"><input type="checkbox" id="pl_${i}_menus_opaque" style="width:auto;height:auto"> Verre opaque</label></div>
        <button type="button" class="btn sec small" data-pladd="${i}:menus">+ Ajouter cette menuiserie</button></div>
      ${subListe(p.ouvertures || [], i, 'ouvertures', x => `Ouverture libre · ${num(x.nb)} × ${fmt(num(x.largeur))} × ${fmt(num(x.hauteur))} m`)}
      <div class="row" style="margin-top:4px;flex-wrap:wrap"><span class="muted" style="flex:1;min-width:180px">Ouverture libre (passage)</span><input id="pl_${i}_ouvertures_nb" inputmode="numeric" placeholder="1" placeholder="Nb" style="width:60px"><input id="pl_${i}_ouvertures_l" inputmode="decimal" placeholder="Larg. m" style="width:80px"><input id="pl_${i}_ouvertures_h" inputmode="decimal" placeholder="Haut. m" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:ouvertures">+ Ouverture</button></div>
      ${subListe(p.placards || [], i, 'placards', x => `Placard · ${esc(x.type)} · ${num(x.nb)} × ${fmt(num(x.largeur))} × ${fmt(num(x.hauteur))} m`)}
      <div class="row" style="margin-top:4px;flex-wrap:wrap">${selCrayon('pieces-placards', 'Placards : type', `<select id="pl_${i}_placards_type" style="flex:1;min-width:0">${optDesignations('pieces-placards', 'Placards : type', () => platPlacards(), '', '— choisir —')}</select>`)}<input id="pl_${i}_placards_nb" inputmode="numeric" placeholder="1" placeholder="Nb" style="width:60px"><input id="pl_${i}_placards_l" inputmode="decimal" placeholder="Larg. m" style="width:80px"><input id="pl_${i}_placards_h" inputmode="decimal" placeholder="Haut. m" style="width:80px"><button type="button" class="btn sec small" data-pladd="${i}:placards">+ Placard</button></div>
    </div>`;
  };
  const carteEquip = (p, i) => `<div class="sousbloc" style="padding:10px;margin:10px 0">
        <strong>${esc(nomPiece(p))}</strong>
      ${equipOptions(p).length ? `<p class="muted" style="margin:10px 0 2px">Équipements (nombre)</p>
      ${subListe(p.equip || [], i, 'equip', x => `${esc(x.type)} × ${num(x.nb)}`)}
      <div class="row" style="margin-top:4px;flex-wrap:wrap">${selCrayon('pieces-equip', 'Équipements : type', `<select id="pl_${i}_equip_type" style="flex:1;min-width:0">${optCodes('pieces-equip', 'Équipements : type', equipOptions(p).map(d => [d, esc(d)]), '', '— choisir —')}</select>`)}<input id="pl_${i}_equip_nb" inputmode="numeric" placeholder="1" placeholder="Nb" style="width:60px"><button type="button" class="btn sec small" data-pladd="${i}:equip">+ Équipement</button></div>` : ''}
    </div>`;
  if (PIECES_ANCIEN_VEILLE) { if ($('cfgPieces')) $('cfgPieces').innerHTML = ''; }   // ancien configurateur retiré de l'affichage ; ses données restent
  else $('cfgPieces').innerHTML = `${tabTitre('B. Liste des pièces de la maison (sans l\'équipement)')}<div class="bloc">
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
    <div style="margin-top:8px"><label for="plSol" style="display:block;font-size:15px;font-weight:600;margin:6px 0 4px;color:var(--fg)">Revêtement de sol</label>${selCrayon('pieces-sol', 'Revêtement de sol', `<select id="plSol" style="width:100%">${optDesignations('pieces-sol', 'Revêtement de sol', () => platSols(), '', '— choisir —')}</select>`)}</div>
    <div class="row" style="margin-top:10px"><button type="button" class="btn sec" id="plAjPiece">Ajouter ou mettre à jour la pièce</button></div>
    <h3 style="margin:14px 0 0;font-size:15px">Pièces et leurs murs</h3>
    ${pieces.map(carte).join('') || '<p class="muted">Aucune pièce.</p>'}
    </div>`;
  $('cfgEquip').innerHTML = `${tabTitre('13. Équipements')}<div class="bloc">
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
    actualiserMetre();
    if ($('cfgStatut')) $('cfgStatut').textContent = 'Configurateur enregistré. Les lignes calculées sont ajoutées automatiquement au métré.';
  }, 300);
}
// Retire du métré, dans tous les chantiers, les lignes générées automatiquement (les lignes saisies à la main restent)
// Retire du métré du chantier ouvert les lignes générées par le configurateur (les lignes saisies à la main restent)
function retirerLignesAuto() {
  const c = chantiers.find(x => x.id === courantId);
  if (!c) { if ($('cfgStatut')) $('cfgStatut').textContent = 'Ouvrez d\'abord un chantier.'; return; }
  const L = lignesDe(c.id), garde = L.filter(l => !(l.auto || l.plat || l.projet));
  const n = L.length - garde.length;
  if (!n) { if ($('cfgStatut')) $('cfgStatut').textContent = 'Aucune ligne générée automatiquement à retirer dans ce chantier.'; return; }
  if (!confirm(n + ' ligne(s) générée(s) seront retirées du métré de ce chantier. Vos lignes saisies à la main ne sont pas touchées. Continuer ?')) return;
  sauverLignes(c.id, garde);
  renderMetre();
  if ($('cfgStatut')) $('cfgStatut').textContent = n + ' ligne(s) générée(s) retirée(s) du métré. Vos lignes saisies à la main sont conservées.';
}
if ($('btnRetirerAuto')) $('btnRetirerAuto').addEventListener('click', retirerLignesAuto);
// Bouton « Synchroniser le métré » : recalcule le métré depuis le configurateur et la bibliothèque, puis envoie sur Drive
async function synchroniserMetre() {
  const c = chantiers.find(x => x.id === courantId);
  if (!c) return;
  majQuantitesAuto(c);
  majLignesDepuisConfigurateur(c);
  renderMetre();
  await synchroniserChantiers(true);
}
if ($('btnSyncMetre')) $('btnSyncMetre').addEventListener('click', synchroniserMetre);
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
  if (b.id === 'plGenElec' || b.id === 'plGen') { sauverPlat(c); synchroConfig(); return; }
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
    ajuste(g('mat'), matsPour(g('type').value), '');
    ajuste(g('fin'), finsPour(g('mat').value), '');
  }
  if (m[2] === 'matvolet' || m[2] === 'finvolet') {
    ajuste(g('finvolet'), finsPour(g('matvolet').value), '');
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
function optionsListe(liste, val) { return (liste.some(([k]) => k === '') ? liste : [['', '— à choisir —'], ...liste]).map(([k, t]) => `<option value="${k}" ${k === val ? 'selected' : ''}>${t}</option>`).join(''); }
function ralOptions(val) { return '<option value="">— choisir la couleur —</option>' + RAL_LISTE.map(([k, t]) => `<option value="${k}" ${k === val ? 'selected' : ''}>${k} · ${t}</option>`).join(''); }
// Texte ajouté à la désignation et à l'affichage : finition et couleur RAL
function finTxt(fin, ral) {
  if (fin === 'brut') return 'bois brut';
  if (fin === 'teinte') return 'bois teinté';
  if (fin === 'ral') return ral ? ral : 'couleur RAL à choisir';
  return '';
}
const FICHE_VOLET = { 'aucun': 'Pas de volet', 'battant': 'Volet battant', 'roulant': 'Volet roulant' };
// Géométrie de la toiture (le toit terrasse se choisit dans le type de charpente : il met la géométrie à « plat »)
const FICHE_TOIT = { 'monopente': 'Monopente', 'deux-pans': '2 pans', 'trois-pans': '3 pans', 'quatre-pans': '4 pans' };
const FICHE_APPUIS = { '2': '2 appuis', '3': '3 appuis' };
const FICHE_VERSANT = { sans: 'Sans coyau', avec: 'Avec coyau (rupture de pente en bas de versant)' };
const FICHE_EGOUT = { droit: 'Chevrons coupés droit à l\'aplomb du mur', 'queue-de-vache': 'Débord prononcé en queue de vache (charpente apparente sous la toiture)' };
// Choix de la fiche : « — à choisir — » par défaut, rien n'est proposé tant que vous n'avez pas choisi
const CHOIX_VIDE = ['', '— à choisir —'];
const FICHE_CHARP = { traditionnelle: 'Charpente traditionnelle', fermette: 'Charpente industrielle (fermettes)', terrasse: 'Toit terrasse' };
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
  'tuile-canal': 'Tuiles canal (surface courante)', 'tuile-plate-tc': 'Tuiles plates (surface courante)',
  'tuile-meca-tc': 'Tuiles mécaniques (surface courante)', 'tuile-romane-canal': 'Tuiles romanes canal (surface courante)',
  'ardoise': 'Ardoises naturelles (surface courante)', 'zinc': 'Zinc en plaques (surface courante)', 'bac-acier': 'Bacs acier (surface courante)'
};
// Anciens choix de la fiche (avant la liste élargie) : ramenés au nouveau nom
// Ce qui manque pour que la charpente et la couverture sortent au métré (affiché dans le configurateur)
function toitureManquants(p) {
  const t = p.toiture || {}, m = [];
  // Toitures suivantes : type de charpente, géométrie et surface de chacune
  const sup = [];
  (p.toituresSup || []).forEach((ts, i) => {
    const n = nomToit(ts, i + 1);
    if (!ts.charpente) sup.push(n + ' : type de charpente');
    else if (!FICHE_CHARP[charpenteDe(ts)]) sup.push(n + ' : type de charpente « ' + ts.charpente + ' » non relié au métré');
    if (ts.type !== 'plat' && !ts.type) sup.push(n + ' : géométrie');
    if (!(num(ts.surface) > 0 || num(ts.surfCouv) > 0)) sup.push(n + ' : surface au sol couverte');
  });
  return [...toitureManquants1(p), ...sup];
}
function toitureManquants1(p) {
  const t = p.toiture || {}, m = [];
  if (t.type === 'plat') {
    if (!(num(t.surface) > 0 || num(t.surfCouv) > 0)) m.push('surface au sol couverte (bloc Charpente, Surfaces et compléments)');
    return m;
  }
  const entame = t.charpente || t.type || t.couverture || num(t.surface) || num(t.surfCouv) || num(t.faite) || num(t.rive) || num(t.egout) || num(t.noue);
  if (!entame) return m;
  if (!t.charpente) m.push('type de charpente (bloc Charpente)');
  else if (!FICHE_CHARP[charpenteDe(t)]) m.push('type de charpente « ' + t.charpente + ' » non relié au métré');
  if (!t.type) m.push('géométrie (bloc Charpente)');
  if (!(num(t.surface) > 0 || num(t.surfCouv) > 0)) m.push('surface au sol couverte (bloc Charpente, Surfaces et compléments)');
  if (!t.couverture) m.push('couverture (bloc Couverture)');
  else if (!COUV_OUV[couvDe(t)]) m.push('couverture « ' + t.couverture + ' » non reliée au métré');
  return m;
}
function toitureManqueHtml(p) {
  const m = toitureManquants(p);
  return m.length ? `<div style="background:#fff4e5;border:1px solid #E07838;border-radius:8px;padding:8px 10px;font-size:14px;margin-bottom:6px"><b>Charpente et couverture absentes du métré tant que manque :</b> ${m.map(esc).join(' ; ')}.</div>` : '';
}
// Plusieurs toitures (jusqu'à 4) : la toiture 1 est p.toiture, les suivantes p.toituresSup (charpente distincte chacune)
const TOITS_MAX = 4;
function toitsDe(p) { return [p.toiture || {}, ...((p.toituresSup) || [])]; }
function nomToit(t, i) { return (t && t.nom) || ('Toiture ' + (i + 1)); }
function rampantToit(t) {
  const S = num(t.surface), pente = num(t.pente);
  return num(t.surfCouv) > 0 ? num(t.surfCouv) : (pente > 0 ? S / Math.cos(Math.atan(pente / 100)) : S);
}
function toitPente(p) { return toitsDe(p).some(t => t.type !== 'plat'); }
function toitPlat(p) { return toitsDe(p).some(t => t.type === 'plat'); }
function surfacePlanToit(p) { return planToit(p.toiture || {}); }
// Surface de toiture en plan : saisie, sinon déduite de la surface de couverture et de la pente
function planToit(t) {
  if (num(t.surface) > 0) return num(t.surface);
  if (num(t.surfCouv) > 0) return Math.round(num(t.surfCouv) * Math.cos(Math.atan(num(t.pente) / 100)) * 100) / 100;
  return 0;
}
function couvDe(toit) {
  const v = toit.couverture || '';
  const k = { tuiles: 'tuile-meca-tc', bac: 'bac-non-isole' }[v] || v;
  if (COUV_OUV[k] || !k || !BIB) return k;
  // Liste reliée à la bibliothèque : la valeur est la désignation de l'ouvrage choisi
  const o = BIB.ouvrages.find(x => x.designation === k);
  const cle = o && Object.keys(COUV_OUV).find(c => COUV_OUV[c] === o.id);
  return cle || k;
}
// Type de charpente normalisé : la liste peut donner la clé (« traditionnelle ») ou la désignation d'un ouvrage de la bibliothèque
function charpenteDe(toit) {
  const v = (toit && toit.charpente) || '';
  if (!v || FICHE_CHARP[v] || v === 'aucune') return v;
  const o = BIB && BIB.ouvrages.find(x => x.designation === v);
  if (o && o.id === 'OUV-1839') return 'fermette';
  if (o && o.id === 'OUV-1840') return 'traditionnelle';
  if (/terrasse/i.test(v)) return 'terrasse';
  if (/industri|fermette/i.test(v)) return 'fermette';
  if (/tradition/i.test(v)) return 'traditionnelle';
  return v;
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
// Couverture : ouvrage de la bibliothèque pour chaque tuile (surface courante)
const COUV_OUV = { 'tuile-canal': 'OUV-1842', 'tuile-plate-tc': 'OUV-1843', 'tuile-meca-tc': 'OUV-1844', 'tuile-romane-canal': 'OUV-1845', 'ardoise': 'OUV-1858', 'zinc': 'OUV-1859', 'bac-acier': 'OUV-1860' };
// Accessoires propres à chaque couverture (faîtage, rive, égout, ventilation) : ouvrages de la bibliothèque
const COUV_ACC = {
  ardoise: { faite: 'OUV-1861', rive: 'OUV-1862', egout: 'OUV-1863', ventil: 'OUV-1864' },
  zinc: { faite: 'OUV-1865', rive: 'OUV-1866', egout: 'OUV-1867' },
  'bac-acier': { faite: 'OUV-1868', rive: 'OUV-1869', egout: 'OUV-1870' }
};
// Désignation de la bibliothèque à partir de son numéro (les lignes du configurateur sont retrouvées par ce nom)
function desOuv(id) { const o = BIB && BIB.ouvrages.find(x => x.id === id); return o ? o.designation : undefined; }
const ALIM_VOLET = 'Alimentation volet roulant électrique';
const FICHE_LOTS_MUR = ['gros-oeuvre', 'ossature-bois', 'isolation-thermique', 'doublages-cloisons-plafonds', 'revetements-muraux', 'peinture-finitions'];
const DES_FOND_FOUILLE = 'Fouilles en tranchée pour semelles filantes';
const DES_FOND_SEMELLE = 'Semelles filantes en béton armé';
const DES_MASSIF = 'Fouille pour puits ou massif de fondation';
const DES_SEMELLE_ISO = 'Semelles isolées en béton armé';
const DES_PLATEFORME = 'Fouille en pleine masse (dallage, plateforme)';
// Terrassement saisi dans « Terrain » du configurateur : décapage et réseaux en tranchée (la clôture n'est jamais automatique)
const DES_DECAP = 'Décapage de terre végétale (épaisseur 20 cm)';
const DES_RES_EAU = 'Canalisation eau potable multicouche (tranchée, pose comprise)';
const DES_RES_EU = 'Canalisation PVC EU ou EV (tranchée, pose comprise) – diamètre à préciser';
const DES_RES_EP = 'Canalisation PVC EP vers réseau ou infiltration (tranchée, pose comprise) – diamètre à préciser';
const DES_RES_ELEC = 'Tranchée et gaine électrique (pose comprise) – électricité';
// Installation de chantier saisie dans « Chantier » du configurateur
const DES_BASE_VIE = 'Base vie (bungalow ou conteneur) : mise en place et repli';
const DES_BRANCH_EAU = "Branchement provisoire d'eau de chantier";
const DES_BRANCH_ELEC = "Branchement provisoire d'électricité de chantier";
const DES_GRUE = 'Grue de chantier (mise en place)';
const DES_BENNE = 'Benne à gravats (location et enlèvement)';
const DES_BENNE_TRI = 'Benne à déchets triés (location et enlèvement)';
const DES_DIVERS = 'Fouille pour trou divers';
const FICHE_FONDS_DEF = { largeur: '', hauteur: '' };

// Types de murs proposés : élévations de la bibliothèque, puis murs de soutènement et muret
function typesMurs() {
  const elev = [...new Set(BIB.ouvrages.filter(o => ouvActif(o) && o.qte === 'elev_net').map(o => o.designation))];
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
  if (!c.projet.plancher) c.projet.plancher = { type: '', surface: '', brut: '', ep: '', retombee: '', portee: '', entraxe: '' };
  return c.projet;
}
// Calculs : murs moins ouvertures de 1 m² ou plus, tableaux (2 côtés × hauteur × épaisseur),
// toiture développée, fondations (murs porteurs × dimensions de la semelle et de la fouille)
const APPUI_LIB = { '': 'Pas d\'appui', 'beton': 'Béton', 'beton-pierre': 'Béton ton pierre', 'alu': 'Aluminium', 'acier': 'Acier laqué 75/100e' };
// Appui de fenêtre : la menuiserie garde l'identifiant de l'ouvrage « Appui de fenêtre … » de la bibliothèque
function appuisFenetreBase() { return BIB.ouvrages.filter(o => ouvActif(o) && /^Appui de fenêtre /.test(o.designation)).map(o => o.designation); }
// Seuils de porte de la bibliothèque (ouvrages « Seuil … »), proposés dans la liste « Seuil de porte compris » des murs
// Drainage et arase des murs périphériques : une liste par élément ; rien choisi = rien au métré
const habTabBase = () => BIB.ouvrages.filter(o => ouvActif(o) && /^Habillage des tableaux/.test(o.designation)).map(o => o.designation);
const habAngBase = () => BIB.ouvrages.filter(o => ouvActif(o) && /^Chaînage d['’]angle harpe/.test(o.designation)).map(o => o.designation);
const habChaBase = () => BIB.ouvrages.filter(o => ouvActif(o) && /^Chaînage de couronnement/.test(o.designation)).map(o => o.designation);
const linStdBase = () => BIB.ouvrages.filter(o => ouvActif(o) && /^Linteaux en béton armé coulés/.test(o.designation)).map(o => o.designation);
const linGpBase = () => BIB.ouvrages.filter(o => ouvActif(o) && /^Linteaux de grandes portées/.test(o.designation)).map(o => o.designation);
const chaineHorizBase = () => BIB.ouvrages.filter(o => ouvActif(o) && /^Chaînages horizontaux/.test(o.designation)).map(o => o.designation);
const raidBase = () => BIB.ouvrages.filter(o => ouvActif(o) && /^Poteaux raidisseurs/.test(o.designation)).map(o => o.designation);
const habBandeBase = () => BIB.ouvrages.filter(o => ouvActif(o) && /^Réalisation de bandes de peinture/.test(o.designation)).map(o => o.designation);
// Deux choix optionnels (tableaux, bandes de peinture), en ml, sur une même ligne ; rien choisi = rien au métré
function habillagesMenuiseries(p) {
  const bloc = (cle, titre, base) => `<div style="flex:1;min-width:240px"><div style="font-size:13px;margin-bottom:3px">${titre}</div>${selCrayon('hab-' + cle, titre, `<select data-k="choix" data-champ="hab${cle}" style="width:100%;padding:6px">${optListeOuvrages('hab-' + cle, titre, base, (p.choix || {})['hab' + cle] || '', '— aucun —')}</select>`)}</div>`;
  return `<div style="margin-top:10px;border-top:1px dashed #ccc;padding-top:8px"><strong style="font-size:13px">Habillages des menuiseries (ml)</strong><div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:4px">${bloc('Tab', 'Habillage des tableaux', habTabBase)}${bloc('Bande', 'Bandes de peinture', habBandeBase)}</div><p class="muted" style="font-size:12px;margin:4px 0 0">Linéaire : côtés (hauteur × 2) de chaque menuiserie, plus la largeur sauf volet roulant.</p></div>
  <div style="margin-top:10px;border-top:1px dashed #ccc;padding-top:8px"><strong style="font-size:13px">Chaînage d'angle en pierre (ml, option)</strong><div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:4px"><div style="flex:2;min-width:240px">${selCrayon('hab-Ang', "Chaînage d'angle en pierre", `<select data-k="choix" data-champ="habAng" style="width:100%;padding:6px">${optListeOuvrages('hab-Ang', "Chaînage d'angle en pierre", habAngBase, (p.choix || {}).habAng || '', '— aucun —')}</select>`)}</div><div style="flex:1;min-width:140px"><div style="font-size:13px;margin-bottom:3px">Nombre de chaînes d'angle</div><input data-k="choix" data-champ="habAngNb" inputmode="numeric" value="${esc((p.choix || {}).habAngNb || '')}" style="width:100%;padding:6px"></div></div><p class="muted" style="font-size:12px;margin:4px 0 0">Calcul : nombre × hauteur moyenne des murs périphériques.</p></div>
  <div style="margin-top:10px;border-top:1px dashed #ccc;padding-top:8px"><strong style="font-size:13px">Chaînage sur le mur périphérique (ml)</strong><div style="margin-top:4px">${selCrayon('hab-Cha', 'Chaînage périphérique', `<select data-k="choix" data-champ="habCha" style="width:100%;padding:6px">${optListeOuvrages('hab-Cha', 'Chaînage périphérique', habChaBase, (p.choix || {}).habCha || '', '— aucun —')}</select>`)}</div><p class="muted" style="font-size:12px;margin:4px 0 0">Calcul : linéaire du mur périphérique.</p></div>
  <div style="margin-top:10px;border-top:1px dashed #ccc;padding-top:8px"><strong style="font-size:13px">Linteaux au-dessus des menuiseries (ml)</strong><div style="display:flex;gap:8px;flex-wrap:wrap;margin-top:4px"><div style="flex:1;min-width:240px">${selCrayon('hab-LinStd', 'Linteau standard (≤ 2,50 m)', `<select data-k="choix" data-champ="linStd" style="width:100%;padding:6px">${optListeOuvrages('hab-LinStd', 'Linteau standard (≤ 2,50 m)', linStdBase, (p.choix || {}).linStd || '', '— aucun —')}</select>`)}</div><div style="flex:1;min-width:240px">${selCrayon('hab-LinGp', 'Linteau de grande portée (> 2,50 m)', `<select data-k="choix" data-champ="linGp" style="width:100%;padding:6px">${optListeOuvrages('hab-LinGp', 'Linteau de grande portée (> 2,50 m)', linGpBase, (p.choix || {}).linGp || '', '— aucun —')}</select>`)}</div></div><p class="muted" style="font-size:12px;margin:4px 0 0">Calcul : largeur de chaque menuiserie + 0,40 m (20 cm de chaque côté), une ligne par longueur, × nombre de menuiseries de même largeur.</p></div>`;
}
const drainBase = () => BIB.ouvrages.filter(o => ouvActif(o) && /^(Système complet de drainage|Ouvrage global de drainage)/.test(o.designation)).map(o => o.designation);
const cunetteBase = () => BIB.ouvrages.filter(o => ouvActif(o) && /^Cunette périphérique/.test(o.designation)).map(o => o.designation);
const regardsBase = () => BIB.ouvrages.filter(o => ouvActif(o) && /^Regards de visite/.test(o.designation)).map(o => o.designation);
const nappeBase = () => BIB.ouvrages.filter(o => ouvActif(o) && /^(Nappe |Plaques de protection mécanique)/.test(o.designation)).map(o => o.designation);
const araseBase = () => BIB.ouvrages.filter(o => ouvActif(o) && /^Bande d'arase étanche/.test(o.designation)).map(o => o.designation);
function seuilsNvBase() { return BIB.ouvrages.filter(o => ouvActif(o) && /^(Seuil |Bavette pliée en aluminium)/.test(o.designation)).map(o => o.designation); }
function appuiNom(id) { if (!id) return ''; const o = BIB.ouvrages.find(x => x.id === id); return o ? o.designation : (APPUI_LIB[id] || id); }
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
  if (PIECES_ANCIEN_VEILLE) return [];
  const c = chantiers.find(x => x.id === courantId);
  return c ? piecesDe(c) : [];
}
function projetCalcul(p) {
  const r = { murs: [], brut: 0, deduit: 0, net: 0, tableaux: 0, ouvs: [], toiture: 0, linP: 0, linSoub: 0, linSolin: 0, deltaSoub: 0, soubS: 0, semelle: 0, fouille: 0 };
  // Épaisseur du mur fini : moyenne des murs périphériques, pondérée par leur longueur
  let sEp = 0, sLong = 0;
  for (const m of p.murs) {
    const brut = surfaceMur(m);
    r.murs.push({ m, brut, ded: 0 });
    r.brut += brut;
    if (m.cat === 'soub') {
      r.linSoub += num(m.longueur);
      // Enduit hydrofuge : solin au mètre linéaire + pose Delta-MS sur hauteur + 30 cm
      if (m.finition === HYDRO_SOUB) { r.linSolin += num(m.longueur); r.deltaSoub += num(m.longueur) * (num(m.hauteur) + DELTA_SOUB_PLUS); }
      // Membrane Delta-MS choisie comme protection : sa ligne sur hauteur + 30 cm
      if (m.finition === DELTA_SOUB) r.deltaSoub += num(m.longueur) * (num(m.hauteur) + DELTA_SOUB_PLUS);
    }
    else if (m.porteur !== false) r.linP += num(m.longueur);
    if ((m.cat || 'peri') === 'peri' && num(m.epMur) > 0 && num(m.longueur) > 0) { sEp += num(m.epMur) * num(m.longueur); sLong += num(m.longueur); }
  }
  const e = sLong > 0 ? sEp / sLong / 100 : 0;
  r.epMoy = e;
  // Finition extérieure des murs périphériques : elle donne le revêtement des tableaux des fenêtres
  const murFin = r.murs.find(x => x.m.cat === 'peri' && x.m.finition);
  r.finTab = murFin ? murFin.m.finition : '';
  // Menuiseries rattachées aux pièces : chacune compte pour son nombre (nb × pièces identiques)
  for (const x of menusCalcul(piecesCourantes())) {
    const aire = num(x.m.largeur) * num(x.m.hauteur);
    const tab = (2 * num(x.m.hauteur) + num(x.m.largeur)) * x.nb;   // tableaux au mètre linéaire : 2 côtés + linteau (m)
    if (aire >= SEUIL_DEDUCTION) r.deduit += aire * x.nb;
    r.tableaux += tab;
    r.ouvs.push({ o: { nom: nomPiece(x.piece) + ' · ' + FICHE_OUV[x.m.type] }, aire, tab, deduit: aire >= SEUIL_DEDUCTION, nb: x.nb });
  }
  // Menuiseries du nouveau configurateur de pièces : même règle que l'ancien (surface déduite des murs cochés, tableaux)
  const cNv = chantiers.find(x => x.id === courantId);
  let dedNv = 0;   // fenêtres du nouveau bloc : déduites des murs périphériques, sans case à cocher
  if (cNv) for (const pc of piecesNvDe(cNv)) for (const m of (pc.menus || [])) {
    if (!(num(m.l) > 0 && num(m.h) > 0)) continue;
    const nbM = num(m.nb) || 1;
    const aire = num(m.l) * num(m.h) / 10000;          // cm × cm → m²
    const tab = (2 * num(m.h) + num(m.l)) / 100 * nbM;   // tableaux au mètre linéaire : 2 côtés + linteau (m)
    if (aire >= SEUIL_DEDUCTION) dedNv += aire * nbM;
    r.tableaux += tab;
    r.ouvs.push({ o: { nom: (pc.nom || 'Pièce') + (pc.qualif ? ' ' + pc.qualif : '') + ' · fenêtre' }, aire, tab, deduit: aire >= SEUIL_DEDUCTION, nb: nbM });
  }
  // Fenêtres du configurateur de pièces : toujours déduites des murs périphériques (au prorata de leur surface brute)
  // Déduction automatique : murs périphériques et pignons (refends et soubassements : pas de fenêtres)
  const periNv = r.murs.filter(x => x.m.cat === 'peri' || x.m.cat === 'pignon');
  const brutPeri = periNv.reduce((a, x) => a + x.brut, 0);
  if (dedNv > 0 && brutPeri > 0) for (const x of periNv) x.menu = (x.menu || 0) + Math.min(x.brut, dedNv * x.brut / brutPeri);
  r.deduitMenuiseries = r.deduit;
  // Ouverture libre (m²) : s'ajoute à la part des menuiseries, sans règle de seuil
  for (const x of r.murs) x.ded = Math.min(x.brut, (x.menu || 0) + Math.max(0, num(x.m.ouvLibre)));
  r.deduit = r.murs.reduce((a, x) => a + x.ded, 0);
  r.net = Math.max(0, r.brut - r.deduit);
  // Surfaces nettes : soubassement à part, élévation par type de mur (sans type = choix du chantier), finitions par mur
  r.parType = {}; r.parSoub = {}; r.parFin = {}; r.parTypeFl = {};
  for (const x of r.murs) {
    const net = x.brut - x.ded;
    const k = x.m.type || '';
    if (x.m.cat === 'soub') { const cle = k + '|' + (x.m.chaine === true ? '1' : '0') + (x.m.raid === true ? '1' : '0'); r.parSoub[cle] = (r.parSoub[cle] || 0) + net; r.soubS += net; }
    else {
      r.parType[k] = (r.parType[k] || 0) + net;
      const pigM = x.m.cat === 'pignon';
      const cle = k + '|' + [x.m.chaine, x.m.raid, x.m.appui, pigM ? false : x.m.seuil].map(v => (v === true ? '1' : '0')).join('') + (pigM ? 'P' : '-');
      r.parTypeFl[cle] = (r.parTypeFl[cle] || 0) + net;
    }
    // La membrane Delta-MS a sa propre ligne (hauteur + 30 cm) : elle n'est pas comptée une deuxième fois comme finition
    if (x.m.finition && net > 0 && !(x.m.cat === 'soub' && x.m.finition === DELTA_SOUB)) r.parFin[x.m.finition] = (r.parFin[x.m.finition] || 0) + net;
  }
  const pente = num(p.toiture.pente);
  const S = num(p.toiture.surface);
  // Surface de couverture saisie (3D) : utilisée telle quelle ; sinon calcul à partir de la surface au sol et de la pente.
  // Plusieurs toitures : surfaces additionnées (toits en pente d'un côté, toits terrasses de l'autre)
  r.toitPente = toitsDe(p).filter(t => t.type !== 'plat').reduce((a, t) => a + rampantToit(t), 0);
  r.toitPlat = toitsDe(p).filter(t => t.type === 'plat').reduce((a, t) => a + rampantToit(t), 0);
  r.toiture = r.toitPente + r.toitPlat;
  const f = p.fond || FICHE_FONDS_DEF;
  // Si des rigoles sont saisies (bloc Terrassement), leur linéaire, largeur et HT servent aux semelles et fouilles
  const rig = num(f.rigLin) > 0;
  r.fondLin = rig ? num(f.rigLin) : 0;  // seul le champ « rigoles » du configurateur compte (pas les murs porteurs)
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
    surface_toiture_plan: toitsDe(p).reduce((a, t) => a + num(t.surface), 0),
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
    nb_douille: (toitPente(p) && /^tuile/.test(couvDe(p.toiture))) ? ventilationNb(p) : 0,
    nb_sortie125: (toitPente(p) && /^tuile/.test(couvDe(p.toiture))) ? 0 : ventilationNb(p),
    ml_noue: num(p.toiture.noue),
    couverture: toitPente(p) ? couvDe(p.toiture) : '',
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
    elev_net: r.net,
    finit_net: r.net,
    murs_choix: '',
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
    charpente_variante: charpenteDe(p.toiture) === 'fermette' ? (p.toiture.type || '') + '|' + penteBande(p)
      : (charpenteDe(p.toiture) === 'traditionnelle' ? 'traditionnelle' : 'aucune'),
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
  piecesDepliees.clear();   // à chaque entrée dans le configurateur, toutes les pièces sont repliées
  ficheRendre();
  ouvrirConfigurateur();
  route('config');
  synchroConfig();
}
// Depuis le configurateur : retour direct au métré du même chantier (sans passer par la liste des chantiers)
if ($('btnRetourChantier')) $('btnRetourChantier').addEventListener('click', () => {
  if (!courantId || !chantiers.find(x => x.id === courantId && !x.supprime)) { route('chantiers'); renderChantiers(); return; }
  ouvrirChantier(courantId);
});
if ($('vConfig')) {
  $('vConfig').addEventListener('change', ficheChange);
  $('vConfig').addEventListener('click', ficheClick);
}
function ficheListeMur() {
  return BIB.ouvrages.filter(o => ouvActif(o) && o.unite === 'm²' && FICHE_LOTS_MUR.includes(o.lot))
    .map(o => o.designation).filter((d, i, t) => t.indexOf(d) === i);
}
// Membrane Delta-MS : posée sur le mur de soubassement, sur sa hauteur + 30 cm
const DELTA_SOUB = 'Membrane de protection et drainage Delta-MS sur mur de soubassement';
const DELTA_SOUB_PLUS = 0.30;
// Enduit hydrofuge : seul cas qui déclenche automatiquement le solin et la pose Delta-MS
const HYDRO_SOUB = 'Enduit hydrofuge sur mur de soubassement (face extérieure)';
// Murs de la bibliothèque (lot gros œuvre) : parois en m²
function ficheListeMurGO() {
  return BIB.ouvrages.filter(o => ouvActif(o) && o.unite === 'm²' && o.lot === 'gros-oeuvre' && /mur|élévation/i.test(o.designation) && !/hydrofuge|membrane|étanchéité|enduit|drainage/i.test(o.designation))
    .map(o => o.designation).filter((d, i, t) => t.indexOf(d) === i);
}
// Ouvrages retirés de la seule liste des finitions (ils restent dans la bibliothèque)
const FINITIONS_RETIREES = new Set([
  'Contre-lattage pour bardage', 'Plafond en lambris bois', 'Enduit de finition sur plâtre (sous-couche)',
  'Enduit plâtre projeté intérieur', 'Papier peint ou toile de verre', 'Peinture murs et plafonds (2 couches)',
  'Lasure ou vernis bois extérieur (bardage, terrasse)', 'Peinture de sol (garage)', 'Enduit de rebouchage et lissage',
  'Démolition de cloison légère (plâtre ou placo)', 'Enduit chaux intérieur sur mur ancien',
  'Démolition de cloison en plaques de plâtre', "Piquetage et dépose d'enduit ancien",
  'Bande et enduit de joints sur plaques de plâtre', 'Bande et enduit de joints sur plaque de plâtre compris ponçage', 'Lambris bois mural', 'Papier peint',
  'Enduit décoratif (tadelakt, chaux, béton ciré)', 'Lambris PVC', 'Enduit de finition sur plâtre',
  'Peinture plafond deux couches', 'Peinture boiseries et menuiseries', 'Peinture sur métal (radiateurs, garde-corps)',
  'Lasure bois extérieur', 'Enduit de lissage sur plâtre'
]);
// Finitions : recherche dans toute la bibliothèque (m²)
function ficheListeFinition() {
  return BIB.ouvrages.filter(o => ouvActif(o) && o.unite === 'm²' && /enduit|bardage|crépi|peinture|lasure|revêtement|parement|plaque|placo|papier|tapisserie|lambris|vêture|finition/i.test(o.designation) && !/carrelage|faïence|doublage/i.test(o.designation) && !FINITIONS_RETIREES.has(o.designation) && !/^Enduit intérieur /.test(o.designation))
    .map(o => o.designation).filter((d, i, t) => t.indexOf(d) === i);
}
// Protections des murs enterrés (soubassement) : toute la bibliothèque (m²)
function ficheListeProtection() {
  return BIB.ouvrages.filter(o => ouvActif(o) && o.unite === 'm²' && /hydrofuge|membrane|étanchéité|drainage|enterré|protection/i.test(o.designation))
    .map(o => o.designation).filter((d, i, t) => t.indexOf(d) === i);
}
// ===== Listes déroulantes du configurateur, modifiables (crayon à gauche de chaque liste) =====
// Base = liste du code. Réglages de l'utilisateur : ouvrages retirés (retires) et ajoutés (ajoutes),
// enregistrés sur cet appareil (lsGet 'listes') puis sur Drive (fichier listes.json).
const LISTES_CONF = {
  murs: { titre: 'Matériau des murs (élévation)', base: ficheListeMur },
  tableaux: { titre: 'Tableaux de menuiseries', base: ficheListeMur },
  murGO: { titre: 'Type de mur (gros œuvre)', base: ficheListeMurGO },
  finition: { titre: 'Finition des murs', base: ficheListeFinition },
  protection: { titre: 'Protection des murs enterrés (soubassement)', base: ficheListeProtection }
};
function listesReglages() { const L = lsGet('listes', {}); return L && typeof L === 'object' ? L : {}; }
function listeReglage(cle) { const r = listesReglages()[cle] || {}; return { retires: r.retires || [], ajoutes: r.ajoutes || [], lots: Array.isArray(r.lots) ? r.lots : null, biblio: !!r.biblio, titre: r.titre || '', libelles: r.libelles || {} }; }
// Libellé d'une valeur fixe : celui qui a été modifié dans la liste, sinon le libellé d'origine
function libelleFixe(cle, v, defaut) { const o = listeReglage(cle).libelles[v]; return o || defaut; }
// Liste « bibliothèque » : une liste à valeurs fixes peut être remplacée par les ouvrages de lots choisis
function designationsTousLots(lots) { return [...new Set(BIB.ouvrages.filter(o => ouvActif(o) && lots.includes(o.lot)).map(o => o.designation))]; }
function enregistrerListeBiblio(cle) {
  const r = listeReglage(cle);
  LISTES_CONF[cle] = { titre: r.titre || cle, base: () => designationsTousLots(listeReglage(cle).lots || []), biblioFixe: true };
}
function retirerListeBiblio(cle) { if (LISTES_CONF[cle] && LISTES_CONF[cle].biblioFixe) delete LISTES_CONF[cle]; }
// Liste affichée : base du code, sans les ouvrages retirés, avec les ouvrages ajoutés
function listeEffective(cle) {
  const r = listeReglage(cle);
  const liste = LISTES_CONF[cle].base().filter(d => !r.retires.includes(d));
  r.ajoutes.forEach(d => { if (!liste.includes(d)) liste.push(d); });
  return liste;
}
// Liste déroulante précédée du crayon
function listeAvecCrayon(cle, selectHtml) {
  return `<div class="crayon-rangee"><button type="button" class="btn small sec" data-action="gerer-liste" data-liste="${cle}" title="Gérer cette liste" style="padding:4px 8px;flex:0 0 auto">✏️</button><div style="flex:1;min-width:0">${selectHtml}</div></div>`;
}
// Enregistre sur cet appareil, puis envoie sur Drive si la connexion est active
async function sauverListes(L) {
  lsSet('listes', L); lsSet('listes_modifiees', true);
  if (!syncConfigOk()) return 'Enregistré sur cet appareil. Renseignez le script dans Réglages pour l\'envoyer sur Drive.';
  try {
    const j = await post({ action: 'sauver_listes', listes: L });
    if (j.ok) { lsSet('listes_modifiees', false); return 'Enregistré et envoyé sur Drive.'; }
    return 'Drive a refusé l\'envoi : ' + (j.erreur || 'erreur inconnue') + '. Enregistré sur cet appareil.';
  } catch (e) { return 'Envoi impossible pour le moment. Enregistré sur cet appareil.'; }
}
// Reprend les listes de Drive, sauf si cet appareil a des modifications non encore envoyées
async function reprendreListes() {
  if (!syncConfigOk() || lsGet('listes_modifiees', false)) return;
  try {
    const j = await post({ action: 'lire_listes' });
    if (j.ok && j.listes) lsSet('listes', j.listes);
  } catch (e) { /* hors ligne : copie de cet appareil */ }
}
let listeGereCle = null;
let glSel = [], glAncre = null;   // sélection des lignes d'ouvrages (bleu), ancre pour Maj
let listeRetour = null;
// Ouvre l'éditeur depuis un crayon, en mémorisant l'endroit d'où l'on vient
function ouvrirDepuisCrayon(b) {
  const vc = $('vConfig'), sec = b.closest('section');
  const dansConfig = vc && vc.contains(b);
  const secs = dansConfig ? [...vc.querySelectorAll('section')] : [];
  listeRetour = { index: dansConfig && sec ? secs.indexOf(sec) : -1, y: window.scrollY };
  if (LISTES_CONF[b.dataset.liste]) { ouvrirGestionListe(b.dataset.liste); return; }
  const lab = b.closest('div') && b.closest('div').parentElement ? b.closest('div').parentElement.querySelector('label') : null;
  ouvrirGestionValeurs(b.dataset.liste, lab ? lab.textContent : 'Liste');
}
// Crayons placés hors du configurateur principal (plâtrerie, peinture)
document.addEventListener('click', e => {
  const b = e.target.closest && e.target.closest('[data-action="gerer-liste"]');
  if (!b || ($('vConfig') && $('vConfig').contains(b))) return;
  ouvrirDepuisCrayon(b);
});
// Ferme l'éditeur, redessine les blocs concernés avec les listes à jour, et revient à l'endroit d'origine
function fermerGestionListe() {
  const ov = $('gestListe'); if (ov) ov.remove();
  const ovv = $('gestValeurs'); if (ovv) ovv.remove();
  listeGereCle = null; listeValeurCle = null;
  ficheRendre();
  ouvrirConfigurateur();
  const r = listeRetour; listeRetour = null;
  if (!r) return;
  const secs = $('vConfig') ? [...$('vConfig').querySelectorAll('section')] : [];
  if (r.index >= 0 && secs[r.index]) secs[r.index].scrollIntoView({ block: 'center' });
  else window.scrollTo(0, r.y);
}
// Lots attribués à la liste : ceux choisis par l'utilisateur, sinon les lots des ouvrages du code
function listeLots(cle) {
  const r = listeReglage(cle);
  if (Array.isArray(r.lots)) return r.lots.filter(id => BIB.lots.some(l => l.id === id));   // liste vide = aucun lot (volontaire)
  const base = LISTES_CONF[cle].base();
  return [...new Set(BIB.ouvrages.filter(o => ouvActif(o) && base.includes(o.designation)).map(o => o.lot))];
}
// Ouvrages (m²) d'une liste de lots
function designationsDesLots(lots) {
  return [...new Set(BIB.ouvrages.filter(o => ouvActif(o) && o.unite === 'm²' && lots.includes(o.lot)).map(o => o.designation))];
}
function sauverReglage(cle, r) { const L = listesReglages(); L[cle] = r; return sauverListes(L); }
// Enregistre tout de suite sur cet appareil et met à jour l'écran ; l'envoi Drive se termine à côté (sans attendre)
function sauverReglageEtMessage(cle, r, msgId) {
  sauverReglage(cle, r).then(m => { const el = $(msgId); if (el) el.textContent = m; });
}
function ouvrirGestionListe(cle) {
  listeGereCle = cle;
  let ov = $('gestListe');
  if (!ov) {
    ov = document.createElement('div');
    ov.id = 'gestListe';
    ov.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:1000;display:flex;align-items:flex-start;justify-content:center;overflow:auto;padding:16px';
    // Délégation : un seul écouteur pour toute la fenêtre, même après redessin
    ov.addEventListener('change', async e => {
      const t = e.target;
      if (t.id === 'glLot') { ov.dataset.lot = t.value; rendreGestionListe(true); return; }
      if (t.id === 'glAjoutLot') {
        if (!t.value) return;
        const r = listeReglage(listeGereCle); r.lots = [...listeLots(listeGereCle), t.value];
        ov.dataset.lot = t.value;
        sauverReglageEtMessage(listeGereCle, r, 'glMsg'); rendreGestionListe(); return;
      }
      const i = t.closest('input[data-gl]'); if (!i) return;
      const r = listeReglage(listeGereCle), d = i.dataset.gl, b = LISTES_CONF[listeGereCle].base();
      r.retires = r.retires.filter(x => x !== d); r.ajoutes = r.ajoutes.filter(x => x !== d);
      if (i.checked && !b.includes(d)) r.ajoutes.push(d);
      if (!i.checked && b.includes(d)) r.retires.push(d);
      sauverReglageEtMessage(listeGereCle, r, 'glMsg');
      rendreGestionListe(true);
    });
    ov.addEventListener('input', e => { if (e.target.id === 'glFiltre') { ov.dataset.filtre = e.target.value; rendreGestionListe(true); } });
    ov.addEventListener('click', async e => {
      const t = e.target;
      if (t === ov || t.id === 'glFermer') { fermerGestionListe(); return; }
      // Ligne d'ouvrage : la case coche ou décoche ; le texte sélectionne (bleu)
      const ligneCliquee = t.closest && t.closest('label[data-gl-ligne]');
      if (ligneCliquee) {
        e.preventDefault();   // c'est ce code qui décide, pas le navigateur
        const cle = listeGereCle, base = LISTES_CONF[cle].base();
        const rangees = [...$('glListe').querySelectorAll('label[data-gl-ligne]')].map(l => l.dataset.glLigne);
        const d = ligneCliquee.dataset.glLigne;
        if (t.tagName === 'INPUT') {
          // Case : s'applique à toute la sélection si cette ligne en fait partie, sinon à cette seule ligne
          // Le navigateur a déjà basculé la case : son état actuel est le nouvel état voulu
          const coche = t.checked;
          const cibles = glSel.includes(d) ? glSel.slice() : [d];
          const r = listeReglage(cle);
          cibles.forEach(x => {
            r.retires = r.retires.filter(y => y !== x); r.ajoutes = r.ajoutes.filter(y => y !== x);
            if (coche && !base.includes(x)) r.ajoutes.push(x);
            if (!coche && base.includes(x)) r.retires.push(x);
          });
          sauverReglageEtMessage(cle, r, 'glMsg');
          rendreGestionListe(true);
          return;
        }
        // Texte : Maj = plage depuis le dernier cliqué ; Ctrl = ajouter ou retirer ; sans touche = cette ligne seule
        if (e.shiftKey && glAncre && rangees.includes(glAncre)) {
          const a = rangees.indexOf(glAncre), b = rangees.indexOf(d);
          glSel = rangees.slice(Math.min(a, b), Math.max(a, b) + 1);
        } else if (e.ctrlKey || e.metaKey) {
          glSel = glSel.includes(d) ? glSel.filter(x => x !== d) : glSel.concat([d]);
          glAncre = d;
        } else {
          glSel = [d]; glAncre = d;
        }
        rendreGestionListe(true);
        return;
      }
      const cle = listeGereCle, base = LISTES_CONF[cle].base();
      if (t.dataset.retirlot) {
        const r = listeReglage(cle); r.lots = listeLots(cle).filter(id => id !== t.dataset.retirlot);
        if (ov.dataset.lot === t.dataset.retirlot) ov.dataset.lot = r.lots[0] || '';
        sauverReglageEtMessage(cle, r, 'glMsg'); rendreGestionListe(); return;
      }
      if (t.id === 'glToutDecocher') {
        if (!confirm('Décocher tous les ouvrages de cette liste ? Vous cocherez ensuite ceux que vous voulez.')) return;
        sauverReglageEtMessage(cle, { lots: listeLots(cle), retires: base.slice(), ajoutes: [] }, 'glMsg');
        rendreGestionListe(); return;
      }
      if (t.id === 'glToutCocher') {
        const r = listeReglage(cle), surLot = designationsTousLots([ov.dataset.lot]);
        r.retires = r.retires.filter(x => !surLot.includes(x));
        surLot.forEach(d => { if (!base.includes(d) && !r.ajoutes.includes(d)) r.ajoutes.push(d); });
        sauverReglageEtMessage(cle, r, 'glMsg'); rendreGestionListe(); return;
      }
      if (t.id === 'glOrigine') {
        if (!confirm("Revenir à la liste d'origine de ce configurateur ? Vos ajouts, retraits et lots pour cette liste seront effacés.")) return;
        const r0 = listeReglage(cle);
        sauverReglageEtMessage(cle, r0.biblio ? { retires: [], ajoutes: [], lots: r0.lots, biblio: true, titre: r0.titre } : { retires: [], ajoutes: [], lots: null }, 'glMsg');
        rendreGestionListe();
      }
    });
    document.body.appendChild(ov);
  }
  ov.dataset.lot = listeLots(cle)[0] || ''; ov.dataset.filtre = ''; glSel = []; glAncre = null;
  rendreGestionListe();
}
function rendreGestionListe(seulLaListe) {
  const ov = $('gestListe'); if (!ov || !listeGereCle) return;
  const cle = listeGereCle, lots = listeLots(cle);
  if (!lots.includes(ov.dataset.lot)) ov.dataset.lot = lots[0] || '';
  const lot = ov.dataset.lot, filtre = (ov.dataset.filtre || '').toLowerCase();
  const efficace = listeEffective(cle);
  // Tous les ouvrages du lot affiché (toutes unités) : un ouvrage décoché reste listé, case vide
  const surLot = designationsTousLots(lot ? [lot] : []);
  const hors = efficace.filter(d => !designationsTousLots(lots).includes(d));
  const filtrer = arr => arr.filter(d => !filtre || d.toLowerCase().includes(filtre));
  // Case à cocher fine, à gauche : décocher ne fait que changer la case, l'ouvrage reste affiché
  const ligne = d => `<label data-gl-ligne="${esc(d)}" style="display:flex;gap:8px;align-items:flex-start;padding:5px 4px;border-bottom:1px solid #eee;font-size:14px;cursor:pointer;user-select:none;background:${glSel.includes(d) ? '#cfe6ff' : 'transparent'}"><input type="checkbox" data-gl="${esc(d)}" ${efficace.includes(d) ? 'checked' : ''} style="width:16px;height:16px;margin:2px 0 0;flex:0 0 16px;accent-color:#7a5a00;cursor:pointer"><span>${esc(d)}</span></label>`;
  const contenuListe = `<div style="display:flex;gap:6px;flex-wrap:wrap;margin:6px 0">
      <button type="button" class="btn small sec" id="glToutCocher">Tout cocher (ce lot)</button>
      <button type="button" class="btn small danger" id="glToutDecocher">Tout décocher</button>
    </div>
    <div style="font-size:12px;color:#6b5a7a;margin:6px 0">Cochée = proposé dans la liste. Décocher ne fait pas disparaître l'ouvrage de cette fenêtre.<br>La <strong>case</strong> coche ou décoche. Cliquer sur le <strong>nom</strong> sélectionne (bleu) : <strong>Ctrl</strong> + nom ajoute ou retire de la sélection, <strong>Maj</strong> + nom sélectionne tout l'intervalle. Cocher une case d'une ligne sélectionnée s'applique à toute la sélection.</div>
    ${filtrer(surLot).map(ligne).join('') || '<p class="muted" style="font-size:13px">Aucun ouvrage pour ce lot.</p>'}
    ${filtrer(hors).length ? `<p style="font-size:13px;margin:10px 0 2px"><strong>Ajoutés depuis un lot non attribué</strong></p>${filtrer(hors).map(ligne).join('')}` : ''}`;
  if (seulLaListe && $('glListe')) { $('glListe').innerHTML = contenuListe; return; }
  const dispo = BIB.lots.filter(l => !lots.includes(l.id));
  ov.innerHTML = `<div style="background:#fff;color:#222;border-radius:10px;max-width:640px;width:100%;padding:16px;margin:auto">
    <h3 style="margin:0 0 8px">Liste : ${esc(LISTES_CONF[cle].titre)}</h3>
    <div style="font-size:13px"><strong>Lots attribués à cette liste</strong></div>
    <div style="display:flex;gap:6px;flex-wrap:wrap;align-items:center;margin-top:6px">
      ${lots.map(id => `<span style="border:1px solid #c9b8dc;border-radius:14px;padding:3px 6px 3px 10px;font-size:13px">${esc(libLot(id))} <button type="button" data-retirlot="${esc(id)}" title="Retirer ce lot" style="border:0;background:none;cursor:pointer;font-size:13px">✕</button></span>`).join('')}
      <select id="glAjoutLot" style="padding:4px;font-size:13px"><option value="">+ Ajouter un lot…</option>${dispo.map(l => `<option value="${esc(l.id)}">${esc(l.nom)}</option>`).join('')}</select>
    </div>
    <label style="font-size:13px;display:block;margin-top:10px">Lot affiché (seuls ses ouvrages sont listés)
      <select id="glLot" style="width:100%;padding:6px;margin-top:4px">${lots.map(id => `<option value="${esc(id)}" ${id === lot ? 'selected' : ''}>${esc(libLot(id))}</option>`).join('')}</select></label>
    <input id="glFiltre" placeholder="Rechercher un ouvrage…" value="${esc(ov.dataset.filtre || '')}" style="width:100%;padding:6px;margin-top:8px;box-sizing:border-box">
    <div id="glListe" style="max-height:50vh;overflow:auto;margin-top:6px">${contenuListe}</div>
    <p id="glMsg" style="font-size:13px;color:#6b5a7a;margin:8px 0"></p>
    <div style="display:flex;gap:8px;justify-content:space-between;flex-wrap:wrap">
      <button type="button" class="btn sec" id="glOrigine">Revenir à la liste d'origine</button>
      <button type="button" class="btn" id="glFermer">Fermer</button>
    </div>
  </div>`;
}

// ===== Listes à choix fixes (toiture, équipements, plancher…) : valeurs modifiables =====
// Clé de la liste = data-k + '.' + data-champ (ex. « toit.type »). Réglages : retires = valeurs décochées, ajoutes = { v, t }
const FIXES_DEFAUTS = {};   // valeurs d'origine de chaque liste, enregistrées au moment du dessin
// Listes modifiées au crayon : ce que chaque choix donne au métré.
// Un ouvrage de la bibliothèque choisi dans une liste reliée à la bibliothèque va au métré avec la quantité de cette case.
const RUBRIQUE_FICHE = { toit: 'toiture', equip: 'equip', plan: 'plancher', cuis: 'cuisine', choix: 'choix' };
const LISTE_SOURCE = { 'toit.couverture': 'surface_toiture', 'toit.charpente': 'surface_toiture', 'toit.ecran': 'surface_toiture',
  'toit.isoToit': 'surface_toiture', 'toit.etancheite': 'surface_toiture', 'toit.gouttiere': 'ml_egout', 'toit.descente': 'ml_descentes',
  'toit.couvertine': 'ml_acrotere', 'cuis.plan': 'ml_plan' };
const LISTE_PARAMETRES = new Set(['toit.type', 'toit.appuis', 'toit.versant', 'toit.egoutStyle']);   // réglages sans ouvrage propre
const LISTE_NOMS = { 'toit.charpente': 'Type de charpente', 'toit.ecran': 'Écran de sous-toiture', 'toit.isoToit': 'Isolation de la toiture',
  'toit.etancheite': 'Étanchéité', 'toit.couverture': 'Couverture', 'toit.couvertine': 'Couvertine', 'toit.gouttiere': 'Gouttières',
  'toit.descente': 'Descentes', 'cuis.plan': 'Plan de travail', 'plan.dallage': 'Dallage', 'plan.type': 'Plancher' };
// null : choix reconnu par le calcul ; sinon { val, o, src } (o et src présents : l'ouvrage choisi va au métré ; sinon rien ne sort)
const n1b = x => (x === undefined || x === null || x === '' ? 1 : num(x));
function etatListe(p, cle) {
  const [k, champ] = cle.split('.');
  const val = ((p[RUBRIQUE_FICHE[k]] || {})[champ]);
  if (!val || typeof val !== 'string' || LISTE_PARAMETRES.has(cle)) return null;
  if (cle === 'toit.charpente' && (FICHE_CHARP[charpenteDe(p.toiture)] || val === 'aucune')) return null;
  if (cle === 'toit.couverture' && COUV_OUV[couvDe(p.toiture)]) return null;
  if ((FIXES_DEFAUTS[cle] || []).some(([v]) => v === val)) return null;
  const rg = listeReglage(cle);
  const a = rg.ajoutes.find(x => x.v === val);
  if (a && a.des) return null;   // valeur ajoutée et reliée à un ouvrage : déjà traitée
  const o = BIB && BIB.ouvrages.find(x => ouvActif(x) && x.designation === val);
  return { val, o: o || null, src: o ? (o.qte || LISTE_SOURCE[cle] || null) : null };
}
// Choix des listes qui n'iront pas au métré (affiché en haut du configurateur)
function listesNonRelieesHtml(p) {
  const pb = [];
  for (const cle of Object.keys(FIXES_DEFAUTS)) {
    const e = etatListe(p, cle);
    if (e && !(e.o && e.src)) pb.push(`${LISTE_NOMS[cle] || cle} : « ${e.val} »`);
  }
  return pb.length ? `<div style="background:#fff4e5;border:1px solid #E07838;border-radius:8px;padding:8px 10px;font-size:14px;margin:6px 0"><b>Choix non reliés au métré</b> (valeur ajoutée au crayon sans ouvrage, ou ouvrage sans quantité connue) : ${pb.map(esc).join(' ; ')}. Reliez la valeur à un ouvrage dans le crayon, ou choisissez une valeur de la liste.</div>` : '';
}
function cleFixe(attrs) {
  const k = /data-k="([^"]+)"/.exec(attrs), c = /data-champ="([^"]+)"/.exec(attrs);
  return k && c ? (k[1] === 'toitS' ? 'toit' : k[1]) + '.' + c[1] : null;
}
function valeursFixes(cle, defauts) {
  const r = listeReglage(cle);
  if (r.biblio) { enregistrerListeBiblio(cle); return listeEffective(cle).map(d => [d, d]); }
  retirerListeBiblio(cle);
  return [...defauts.map(([v, t]) => [v, r.libelles[v] || t]), ...r.ajoutes.map(a => [a.v, a.t])].filter(([v]) => !r.retires.includes(v));
}
let listeValeurCle = null;
function ouvrirGestionValeurs(cle, titre) {
  listeValeurCle = cle;
  let ov = $('gestValeurs');
  if (!ov) {
    ov = document.createElement('div');
    ov.id = 'gestValeurs';
    ov.style.cssText = 'position:fixed;inset:0;background:rgba(0,0,0,.45);z-index:1000;display:flex;align-items:flex-start;justify-content:center;overflow:auto;padding:16px';
    ov.dataset.titre = titre || 'Liste';
    ov.addEventListener('change', async e => {
      const lien = e.target.dataset.lien;
      if (lien) {
        // Lien d'une valeur ajoutée : ouvrage de la bibliothèque et quantité du configurateur
        const r = listeReglage(listeValeurCle), a = r.ajoutes.find(x => x.v === e.target.dataset.lv);
        if (!a) return;
        if (lien === 'des') {
          const d = e.target.value.trim();
          if (d && !BIB.ouvrages.some(o => !o.supprime && o.designation === d)) {
            $('gvMsg').textContent = "Cet ouvrage n'existe pas dans la bibliothèque : choisissez-le dans la liste proposée.";
            return;
          }
          a.des = d;
        } else a.src = e.target.value;
        sauverReglageEtMessage(listeValeurCle, r, 'gvMsg');
        return;
      }
      const lib = e.target.closest('input[data-libelle]');
      if (lib) {
        const r = listeReglage(listeValeurCle), v = lib.dataset.libelle, texte = lib.value.trim();
        const a = r.ajoutes.find(x => x.v === v);
        const d = (FIXES_DEFAUTS[listeValeurCle] || []).find(([x]) => x === v);
        if (a) { if (texte) a.t = texte; }
        else if (!texte || (d && texte === d[1])) delete r.libelles[v];
        else r.libelles[v] = texte;
        sauverReglageEtMessage(listeValeurCle, r, 'gvMsg');
        return;
      }
      const i = e.target.closest('input[data-v]'); if (!i) return;
      const r = listeReglage(listeValeurCle), v = i.dataset.v;
      r.retires = r.retires.filter(x => x !== v);
      if (!i.checked) r.retires.push(v);
      sauverReglageEtMessage(listeValeurCle, r, 'gvMsg');
      rendreGestionValeurs(true);
    });
    ov.addEventListener('click', async e => {
      const t = e.target, cle = listeValeurCle;
      if (t === ov || t.id === 'gvFermer') { fermerGestionListe(); return; }
      if (t.id === 'gvAjouter') {
        const lib = ($('gvNouveau').value || '').trim(); if (!lib) return;
        const r = listeReglage(cle); r.ajoutes.push({ v: 'v' + Date.now(), t: lib });
        sauverReglageEtMessage(cle, r, 'gvMsg'); rendreGestionValeurs(); return;
      }
      if (t.dataset.supprajout) {
        if (!confirm('Supprimer définitivement cette valeur que vous avez ajoutée ?')) return;
        const r = listeReglage(cle), v = t.dataset.supprajout;
        r.ajoutes = r.ajoutes.filter(a => a.v !== v); r.retires = r.retires.filter(x => x !== v);
        sauverReglageEtMessage(cle, r, 'gvMsg'); rendreGestionValeurs(); return;
      }
      if (t.id === 'gvToutCocher') {
        const r = listeReglage(cle); r.retires = [];
        sauverReglageEtMessage(cle, r, 'gvMsg'); rendreGestionValeurs(); return;
      }
      if (t.id === 'gvToutDecocher') {
        if (!confirm('Décocher toutes les valeurs de cette liste ? Vous cocherez ensuite celles que vous voulez.')) return;
        const r = listeReglage(cle);
        r.retires = [...(FIXES_DEFAUTS[cle] || []).map(([v]) => v), ...r.ajoutes.map(a => a.v)];
        sauverReglageEtMessage(cle, r, 'gvMsg'); rendreGestionValeurs(); return;
      }
      if (t.id === 'gvBiblio') {
        const lots = [...ov.querySelectorAll('input[data-glot]:checked')].map(i => i.dataset.glot);
        if (!lots.length) { $('gvMsg').textContent = 'Cochez au moins un lot.'; return; }
        sauverReglageEtMessage(cle, { retires: [], ajoutes: [], lots, biblio: true, titre: ov.dataset.titre || cle }, 'gvMsg');
        enregistrerListeBiblio(cle);
        ov.remove(); listeValeurCle = null;
        ouvrirGestionListe(cle);
        return;
      }
      if (t.id === 'gvFixe') {
        if (!confirm('Revenir aux valeurs fixes de cette liste ? Les lots choisis et les ouvrages cochés seront effacés.')) return;
        sauverReglageEtMessage(cle, { retires: [], ajoutes: [], lots: null, biblio: false, titre: '' }, 'gvMsg');
        retirerListeBiblio(cle);
        rendreGestionValeurs(); return;
      }
      if (t.id === 'gvOrigine') {
        if (!confirm("Revenir aux valeurs d'origine de cette liste ? Vos ajouts et retraits seront effacés.")) return;
        sauverReglageEtMessage(cle, { retires: [], ajoutes: [], lots: null }, 'gvMsg'); rendreGestionValeurs();
      }
    });
    document.body.appendChild(ov);
  }
  ov.dataset.titre = titre || ov.dataset.titre;
  rendreGestionValeurs();
}
// Choix de la source : valeurs fixes, ou ouvrages de la bibliothèque (lots cochés)
function blocSourceListe(cle, r) {
  const cadre = 'padding:8px;margin:6px 0;border:1px solid #c9b8dc;border-radius:8px';
  if (r.biblio) return `<div style="${cadre}"><strong>Cette liste utilise les ouvrages de la bibliothèque</strong><div style="font-size:13px;color:#6b5a7a;margin:4px 0">Lots : ${esc((r.lots || []).map(libLot).join(', ') || 'aucun')}. Le crayon ouvre la liste des ouvrages à cocher.</div><button type="button" class="btn small sec" id="gvFixe">Revenir aux valeurs fixes</button></div>`;
  return `<div style="${cadre}"><strong>Remplacer par les ouvrages de la bibliothèque</strong><div style="font-size:12px;color:#6b5a7a;margin:2px 0 6px">Cochez les lots : la liste proposera leurs ouvrages, que vous cocherez ensuite un par un.</div>${BIB.lots.map(l => `<label style="display:flex;gap:6px;align-items:center;font-size:14px;margin:4px 0"><input type="checkbox" data-glot="${esc(l.id)}" style="width:16px;height:16px;margin:0">${esc(l.nom)}</label>`).join('')}<button type="button" class="btn small" id="gvBiblio" style="margin-top:6px">Utiliser ces lots</button></div>`;
}
function rendreGestionValeurs(seulLaListe) {
  const ov = $('gestValeurs'); if (!ov || !listeValeurCle) return;
  const cle = listeValeurCle, defauts = FIXES_DEFAUTS[cle] || [], r = listeReglage(cle);
  const lienLigne = a => `<div style="display:flex;gap:6px;flex-wrap:wrap;margin:2px 0 6px 24px">
      <input list="dlOuvrages" data-lien="des" data-lv="${esc(a.v)}" value="${esc(a.des || '')}" placeholder="Ouvrage de la bibliothèque (lié au métré)" style="flex:2;min-width:200px;padding:4px;font-size:13px">
      <select data-lien="src" data-lv="${esc(a.v)}" style="flex:1;min-width:180px;padding:4px;font-size:13px"><option value="">Quantité : aucune (pas de ligne)</option>${Object.entries(SRC_QTE).map(([k, lib]) => `<option value="${k}" ${a.src === k ? 'selected' : ''}>${esc(lib)}</option>`).join('')}</select>
    </div>`;
  const ligne = (v, t, ajout) => {
    const a = ajout ? r.ajoutes.find(x => x.v === v) : null;
    const libelle = `<input data-libelle="${esc(v)}" value="${esc(t)}" title="Modifier le libellé" style="flex:1;min-width:0;padding:4px;font-size:14px">`;
    return `<div style="border-bottom:1px solid #eee;padding:4px 0"><div style="display:flex;gap:8px;align-items:center;font-size:14px"><input type="checkbox" data-v="${esc(v)}" ${r.retires.includes(v) ? '' : 'checked'} style="width:16px;height:16px;margin:0;flex:0 0 16px;accent-color:#7a5a00">${libelle}${ajout ? `<button type="button" data-supprajout="${esc(v)}" title="Supprimer cette valeur" style="border:0;background:none;cursor:pointer;color:#a33">✕</button>` : ''}</div>${a ? lienLigne(a) : ''}</div>`;
  };
  const contenu = blocSourceListe(cle, r) + (r.biblio ? '' : `<div style="display:flex;gap:6px;flex-wrap:wrap;margin:6px 0">
      <button type="button" class="btn small sec" id="gvToutCocher">Tout cocher</button>
      <button type="button" class="btn small danger" id="gvToutDecocher">Tout décocher</button>
    </div>
    <div style="font-size:12px;color:#6b5a7a;margin:6px 0">Cochée = proposée dans la liste. Décocher ne fait pas disparaître la valeur de cette fenêtre.</div>
    ${defauts.map(([v, t]) => ligne(v, r.libelles[v] || t, false)).join('')}
    ${r.ajoutes.map(a => ligne(a.v, a.t, true)).join('')}`);
  if (seulLaListe && $('gvListe')) { $('gvListe').innerHTML = contenu; return; }
  ov.innerHTML = `<div style="background:#fff;color:#222;border-radius:10px;max-width:560px;width:100%;padding:16px;margin:auto">
    <h3 style="margin:0 0 8px">Liste : ${esc(ov.dataset.titre || 'Liste')}</h3>
    <div style="display:flex;gap:6px;align-items:center;margin-bottom:6px">
      <input id="gvNouveau" placeholder="Nouvelle valeur à proposer…" style="flex:1;padding:6px;box-sizing:border-box">
      <button type="button" class="btn small" id="gvAjouter">Ajouter</button>
    </div>
    <datalist id="dlOuvrages">${BIB.ouvrages.filter(o => ouvActif(o)).map(o => `<option value="${esc(o.designation)}">`).join('')}</datalist>
    <div id="gvListe" style="max-height:55vh;overflow:auto">${contenu}</div>
    <p id="gvMsg" style="font-size:13px;color:#6b5a7a;margin:8px 0"></p>
    <div style="display:flex;gap:8px;justify-content:space-between;flex-wrap:wrap">
      <button type="button" class="btn sec" id="gvOrigine">Revenir aux valeurs d'origine</button>
      <button type="button" class="btn" id="gvFermer">Fermer</button>
    </div>
  </div>`;
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
function tabTitre(t) {
  // Titre en onglet : identifiant (lettre ou chiffre) et première lettre en grand, le reste en majuscules plus petites
  const lettre = /^[A-Z]\./.test(t);
  const m = /^([A-Z0-9]+)\.\s*(.*)$/.exec(t);
  const id = m ? m[1] : '', titre = m ? m[2] : t;
  const premiere = titre.charAt(0).toUpperCase(), reste = titre.slice(1).toUpperCase();
  return `<div class="tab-row ${lettre ? 'lettre' : 'numero'}"><svg class="tab-svg" aria-hidden="true"></svg><h2 class="lot-titre"><span class="tab-gros">${esc(id)}.</span> <span class="tab-gros">${esc(premiere)}</span><span class="tab-petit">${esc(reste)}</span></h2></div>`;
}
// Dessin des onglets : un seul tracé par titre (4 px, arrondis de 14 px), sans superposition de bordures
function dessinerOnglets() {
  document.querySelectorAll('.tab-row').forEach(row => {
    const h2 = row.querySelector('h2'), svg = row.querySelector('svg.tab-svg');
    if (!h2 || !svg) return;
    const w = row.clientWidth, hh = row.clientHeight;
    if (!w || !hh) return;                       // écran masqué : on dessinera à l'affichage
    const sx = h2.offsetLeft + h2.offsetWidth, r = 14;
    const d = `M 2 ${hh - 2 + r} A ${r} ${r} 0 0 1 ${2 + r} ${hh - 2} L ${sx - 2 - r} ${hh - 2} A ${r} ${r} 0 0 0 ${sx - 2} ${hh - 2 - r} L ${sx - 2} ${2 + r} A ${r} ${r} 0 0 1 ${sx - 2 + r} 2 L ${w - 2 - r} 2 A ${r} ${r} 0 0 1 ${w - 2} ${2 + r} L ${w - 2} ${hh}`;
    const vb = `0 0 ${w} ${hh}`;
    if (svg.getAttribute('viewBox') !== vb) svg.setAttribute('viewBox', vb);
    let path = svg.firstElementChild;
    if (!path) { path = document.createElementNS('http://www.w3.org/2000/svg', 'path'); svg.appendChild(path); }
    if (path.getAttribute('d') !== d) path.setAttribute('d', d);
    if (_ongletsRO && !row.dataset.observe) { row.dataset.observe = '1'; _ongletsRO.observe(row); _ongletsRO.observe(h2); }
  });
}
// Recalcul dès que la police est chargée et à chaque changement de taille d'un titre (sinon le coin peut se décaler)
const _ongletsRO = typeof ResizeObserver !== 'undefined' ? new ResizeObserver(() => requestAnimationFrame(dessinerOnglets)) : null;
if (document.fonts && document.fonts.ready) document.fonts.ready.then(() => requestAnimationFrame(dessinerOnglets));
let _ongletsT = null;
new MutationObserver(() => { cancelAnimationFrame(_ongletsT); _ongletsT = requestAnimationFrame(dessinerOnglets); }).observe(document.body, { childList: true, subtree: true });
window.addEventListener('resize', dessinerOnglets);
window.addEventListener('load', dessinerOnglets);
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
  const calMurs = projetCalcul(p);   // surfaces à déduire de chaque mur (menuiseries cochées + ouverture libre)
  const sel = (opts, val) => (opts.some(([v]) => v === '') ? opts : [['', '— à choisir —'], ...opts]).map(([v, t]) => `<option value="${esc(v)}" ${v === val ? 'selected' : ''}>${esc(t)}</option>`).join('');
  const optListe = (liste, val) => `<option value="" ${!val ? 'selected' : ''}>— choisir —</option>` + liste.map(d => `<option value="${esc(d)}" ${d === val ? 'selected' : ''}>${esc(d)}</option>`).join('');
  const carte = (titre, contenu, src) => `<section ${src ? `data-source="${src}"` : ''} class="sousbloc" style="padding:12px;margin-bottom:12px"><h3 style="margin:0 0 8px;font-size:16px">${titre}</h3>${contenu}</section>`;
  const champ = (lib, html) => `<div style="min-width:0"><label style="display:block;margin:6px 0 4px;font-size:15px;color:var(--fg);font-weight:600">${lib}</label>${html}</div>`;
  const inp = (attrs, val, w) => `<input ${attrs} value="${esc(val ?? '')}" style="width:${w || '100%'};padding:10px;border:1px solid var(--mut);border-radius:8px;background:var(--card);color:var(--fg);font-size:16px">`;
  const sel2 = (attrs, opts, val) => {
    const cle = cleFixe(attrs);
    let liste = opts;
    if (cle) {
      const vide = opts.filter(([v]) => v === ''), defauts = opts.filter(([v]) => v !== '');
      FIXES_DEFAUTS[cle] = defauts;
      liste = [...vide, ...valeursFixes(cle, defauts)];
      if (val && !liste.some(([v]) => v === val)) liste.push([val, val + ' (retiré de la liste)']);
    }
    const html = `<select ${attrs} style="width:100%;padding:6px;border:1px solid #c9b8dc;border-radius:6px">${sel(liste, val)}</select>`;
    return cle ? listeAvecCrayon(cle, html) : html;
  };

  const optListe2 = (liste, sel, vide) => `<option value="">${vide}</option>` + liste.map(t => `<option value="${esc(t)}" ${sel === t ? 'selected' : ''}>${esc(t)}</option>`).join('');
  // Appuis de fenêtre de la bibliothèque (ouvrages « Appui de fenêtre … »), proposés dans la liste « Appui de fenêtre compris »
  const appuisNv = () => BIB.ouvrages.filter(o => ouvActif(o) && /^Appui de fenêtre /.test(o.designation)).map(o => o.designation);
  // Une case à cocher « … compris » suivie de sa liste déroulante (crayon) : valeur gardée dans le mur
  const murCaseListe = (m, id, flag, lib, cle, tit) => `<div style="flex:1;min-width:260px">
    <label style="display:flex;gap:6px;align-items:center;font-size:13px"><input type="checkbox" ${id} data-champ="${flag}" ${m[flag] === true ? 'checked' : ''}> ${lib}</label>
    ${selCrayon(cle, tit, `<select ${id} data-champ="liste_${flag}" style="width:100%;padding:6px">${optListeOuvrages(cle, tit, () => (cle === 'mur-appui' ? appuisNv() : cle === 'mur-seuil' ? seuilsNvBase() : cle === 'mur-chaine' ? chaineHorizBase() : cle === 'mur-raid' ? raidBase() : []), m['liste_' + flag] || '', '— aucun —')}</select>`)}</div>`;
  const rangeMur = m => {
    const id = `data-k="mur" data-id="${m.id}"`;
    const pig = m.cat === 'pignon', soub = m.cat === 'soub', refend = m.cat === 'refend';
    const selMat = listeAvecCrayon('murGO', `<select ${id} data-champ="type" style="width:100%;padding:6px">${optListe2(listeEffective('murGO'), m.type || '', '— choisir le mur de la bibliothèque —')}</select>`);
    const selFin = refend ? '' : listeAvecCrayon(soub ? 'protection' : 'finition', `<select ${id} data-champ="finition" style="width:100%;padding:6px">${soub ? optListe2(listeEffective('protection'), m.finition || '', 'Sans protection') : optListe2(listeEffective('finition'), m.finition || '', 'Sans finition')}</select>`);
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
        ${(num(m.longueur) > 0 || num(m.hauteur) > 0 || m.type) ? `<div style="display:flex;gap:14px;flex-wrap:wrap;width:100%">
          ${pig ? murCaseListe(m, id, 'chaine', 'Arase comprise', 'mur-arase', 'Arase comprise (mur pignon)') : murCaseListe(m, id, 'chaine', 'Chaînage compris', 'mur-chaine', 'Chaînage compris (mur)')}
          ${murCaseListe(m, id, 'raid', 'Poteau raidisseur compris', 'mur-raid', 'Poteau raidisseur compris (mur)')}
          ${m.raid === true ? champ('Nombre de poteaux', inp(`${id} data-champ="nbPoteaux" inputmode="numeric"`, m.nbPoteaux, '120px')) : ''}
          ${soub ? '' : murCaseListe(m, id, 'appui', 'Appui de fenêtre compris', 'mur-appui', 'Appui de fenêtre compris (mur)')}
          ${(soub || pig) ? '' : murCaseListe(m, id, 'seuil', 'Seuil de porte compris', 'mur-seuil', 'Seuil de porte compris (mur)')}
        </div>` : ''}
      <div style="display:flex;gap:14px;flex-wrap:wrap;align-items:end;margin-top:8px;padding-top:6px;border-top:1px dashed var(--line);font-size:13px">
        ${champ('Épaisseur du mur fini (cm)', inp(`${id} data-champ="epMur" inputmode="decimal" placeholder="ex. 35"`, m.epMur, '120px'))}
        ${champ('Ouverture libre (m²)', inp(`${id} data-champ="ouvLibre" inputmode="decimal"`, m.ouvLibre, '120px'))}
        <span style="font-size:13px">Surface à déduire : <strong>${fmt(((calMurs.murs.find(x => x.m === m) || {}).ded) || 0)} m²</strong></span>
      </div></div>`;
  };
  const blocMurs = cat => p.murs.filter(m => (m.cat || 'peri') === cat).map(rangeMur).join('')
    || '<p style="color:#6b5a7a;margin:0">Aucun mur.</p>';
  const ajouterMur = (cat, texte) => `<button type="button" class="btn sec" data-action="addmur" data-cat="${cat}" style="margin-top:6px">${texte}</button>`;
  const menusResume = (() => {
    const pcs = piecesDe(c).filter(x => menusDe(x).length);
    const lignes = pcs.map(pc => `<p style="margin:8px 0 2px"><strong>${esc(nomPiece(pc))}</strong></p>` + menusDe(pc).map(m => `<div class="ouv" style="font-size:14px;min-height:0;padding:6px 0">${esc(FICHE_OUV[m.type] || m.type)} · ${num(m.nb)} × ${fmt(num(m.largeur))} × ${fmt(num(m.hauteur))} m · ${esc(FICHE_MAT[m.materiau] || 'matériau à choisir')}${finTxt(m.fin, m.ral) ? ' · ' + esc(finTxt(m.fin, m.ral)) : ''} · appui ${esc(appuiNom(m.appui) || 'à choisir')}</div>`).join('')).join('');
    const anciennes = p.ouvertures.length ? `<p style="color:#b42318;font-weight:600;margin:10px 0 2px">À rattacher à une pièce (pas encore comptées dans le métré) :</p>` + p.ouvertures.map(o => `<div class="ouv" style="font-size:14px;min-height:0;padding:6px 0">${esc(o.nom)} · ${esc(FICHE_OUV[o.type] || o.type)} · ${num(o.largeur)} × ${num(o.hauteur)} m <button type="button" class="btn small danger" data-action="delouv" data-id="${o.id}">Supprimer</button></div>`).join('') : '';
    return (lignes || '<p class="muted">Aucune menuiserie saisie. Saisissez-les dans chaque pièce, bloc B.</p>') + anciennes;
  })();
  const toit = p.toiture;
  const plat = toit.type === 'plat';
  const choix = (attrs, entries, val) => sel2(attrs, [CHOIX_VIDE, ...entries], val || '');
  const lot = (t) => `<h2 style="margin:20px 0 8px;padding:8px 12px;border-radius:10px;background:var(--acc);color:#fff;font-size:17px">${t}</h2>`;
  // Champs de structure d'une toiture (toiture 1 : data-k="toit" ; toitures suivantes : data-k="toitS" + data-id)
  const champsStructure = (t, kA) => {
    const platT = t.type === 'plat';
    const typeC = platT ? 'terrasse' : (t.charpente || '');
    return `${champ('Type de charpente', choix(`${kA} data-champ="charpente"`, Object.entries(FICHE_CHARP), typeC))}
            ${platT ? '<div></div>' : champ('Géométrie', choix(`${kA} data-champ="type"`, Object.entries(FICHE_TOIT), t.type))}
            <div style="grid-column:1/-1;margin-top:6px;font-weight:600;font-size:13px">Portée et pente</div>
            ${champ('Appuis', choix(`${kA} data-champ="appuis"`, Object.entries(FICHE_APPUIS), t.appuis))}
            ${champ('Longueur entre appuis (m)', inp(`${kA} data-champ="portee" inputmode="decimal" placeholder="ex. 8"`, t.portee || ''))}
            ${champ(platT ? 'Pente (%), minimum 3,5 %' : 'Pente (%)', inp(`${kA} data-champ="pente" inputmode="decimal"` + (platT ? ' placeholder="minimum 3,5"' : ' placeholder="ex. 30"'), t.pente))}
            <div></div>
            ${platT ? '' : `<div style="grid-column:1/-1;margin-top:6px;font-weight:600;font-size:13px">Versant et égout</div>
            ${champ('Type de versant', choix(`${kA} data-champ="versant"`, Object.entries(FICHE_VERSANT), t.versant))}
            ${t.versant === 'avec' ? champ('Longueur de la coyalure (cm), ex. 80 pour les 80 derniers centimètres du toit', inp(`${kA} data-champ="coyauLong" inputmode="decimal" placeholder="ex. 80"`, t.coyauLong || '')) : '<div></div>'}
            ${champ('Esthétique de l\'égout', choix(`${kA} data-champ="egoutStyle"`, Object.entries(FICHE_EGOUT), t.egoutStyle))}
            <div></div>`}
            <div style="grid-column:1/-1;margin-top:6px;font-weight:600;font-size:13px">Surfaces et compléments</div>
            ${champ('Surface au sol couverte (m²)', inp(`${kA} data-champ="surface" inputmode="decimal"`, t.surface))}
            ${champ('Surface de couverture (m², pente comprise, prise dans la 3D) — facultatif', inp(`${kA} data-champ="surfCouv" inputmode="decimal" placeholder="calculée si vide"`, t.surfCouv || ''))}
            ${charpenteDe(t) === 'traditionnelle' && !platT ? champ('Chevronnage', `<label style="font-size:14px"><input type="checkbox" ${kA} data-champ="chevronnage" ${t.chevronnage ? 'checked' : ''} style="width:auto;height:auto"> Chevrons sur pannes et sablières</label>`) : '<div></div>'}`;
  };
  const nbToits = toitsDe(p).length;
  const nomChamp = (t, kA) => nbToits > 1 ? champ('Nom de la toiture', inp(`${kA} data-champ="nom" placeholder="ex. Corps principal, aile, garage"`, t.nom || '')) + '<div></div>' : '';
  const contenuCharp = `<div class="toitManque">${toitureManqueHtml(p)}</div><div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
            ${nomChamp(toit, 'data-k="toit"')}
            ${champsStructure(toit, 'data-k="toit"')}
            ${champ('Écran de sous-toiture', choix('data-k="toit" data-champ="ecran"', Object.entries(FICHE_ECRAN), toit.ecran))}
            <div style="grid-column:1/-1;margin-top:6px;font-weight:600;font-size:13px">Pénétrations, chevêtres et croupes</div>
            ${champ('Pénétration de toiture en charpente industrielle (forfait : nombre de pénétrations)', inp('data-k="toit" data-champ="nbPenetInd" inputmode="numeric" placeholder="ex. 1"', toit.nbPenetInd))}
            ${champ('Pénétration de toiture en charpente traditionnelle (forfait : nombre de pénétrations)', inp('data-k="toit" data-champ="nbPenetTrad" inputmode="numeric" placeholder="ex. 1"', toit.nbPenetTrad))}
            ${champ('Chevêtre sur charpente industrielle en fermettes (nombre)', inp('data-k="toit" data-champ="nbChevInd" inputmode="decimal"', toit.nbChevInd))}
            ${champ('Grand chevêtre sur charpente industrielle, trémie d\'escalier (nombre)', inp('data-k="toit" data-champ="nbGrandChevInd" inputmode="decimal"', toit.nbGrandChevInd))}
            ${champ('Chevêtre sur charpente traditionnelle (nombre)', inp('data-k="toit" data-champ="nbChevTrad" inputmode="decimal"', toit.nbChevTrad))}
            ${champ('Croupe en charpente industrielle (m² projeté au sol)', inp('data-k="toit" data-champ="m2CroupeInd" inputmode="decimal"', toit.m2CroupeInd))}
            ${champ('Croupe en charpente traditionnelle (m² de rampant)', inp('data-k="toit" data-champ="m2CroupeTrad" inputmode="decimal"', toit.m2CroupeTrad))}
    </div>`;
  // Toitures suivantes : une carte chacune, avec sa propre charpente (portée, pente, type…)
  const cartesToitsSup = (p.toituresSup || []).map((t, i) => {
    const kA = `data-k="toitS" data-id="${t.id}"`;
    return carte(`Toiture ${i + 2}${t.nom ? ' : ' + esc(t.nom) : ''} — charpente distincte`, `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
            ${nomChamp(t, kA)}
            ${champsStructure(t, kA)}
          </div>
          <div class="row" style="margin-top:8px"><button type="button" class="btn small sec" data-action="deltoit" data-id="${t.id}">Supprimer cette toiture</button></div>`);
  }).join('');
  const boutonToit = nbToits < TOITS_MAX ? `<div class="row" style="margin:4px 0 12px"><button type="button" class="btn sec" data-action="addtoit">+ Ajouter une toiture (charpente distincte)</button>
    <span class="muted" style="font-size:12px;margin-left:8px">Jusqu'à ${TOITS_MAX} toitures, par exemple deux toits imbriqués de portées différentes.</span></div>` : '';
  const contenuIso = `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
      ${champ('Isolation de toiture', choix('data-k="toit" data-champ="isoToit"', Object.entries(FICHE_ISO_TOIT), toit.isoToit))}
    </div><p style="font-size:12px;color:#6b5a7a;margin:6px 0 0">Les autres isolations se choisissent dans le métré.</p>`;
  const contenuCouv = `<div class="toitManque">${toitureManqueHtml(p)}</div><div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
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
            ${plat ? '' : `<div style="grid-column:1/-1;margin-top:6px;font-weight:600;font-size:13px">Accessoires de couverture</div>
            ${champ('Fronton de faîtage (nombre)', inp('data-k="toit" data-champ="nbFronton" inputmode="decimal"', toit.nbFronton))}
            ${champ('Chatière de ventilation (nombre)', inp('data-k="toit" data-champ="nbChatiere" inputmode="decimal"', toit.nbChatiere))}
            ${champ('Demi-tuile ou tuile double (nombre)', inp('data-k="toit" data-champ="nbDemiTuile" inputmode="decimal"', toit.nbDemiTuile))}
            ${champ('Abergement de cheminée en zinc (nombre)', inp('data-k="toit" data-champ="nbAbergement" inputmode="decimal"', toit.nbAbergement))}
            ${champ('Selle en plomb de tête de noue (nombre)', inp('data-k="toit" data-champ="nbSelle" inputmode="decimal"', toit.nbSelle))}
            ${champ('Bande de solin en zinc (ml)', inp('data-k="toit" data-champ="mlSolin" inputmode="decimal"', toit.mlSolin))}
            ${champ('Couloir de rive contre mur en zinc (ml)', inp('data-k="toit" data-champ="mlCouloir" inputmode="decimal"', toit.mlCouloir))}`}
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
    <div style="margin-top:8px">${champ('Semelle filante insérée au métré avec ces fouilles (lot gros œuvre, m³)', selCrayon('terr-semelle', 'Semelle filante (fouilles en rigole)', `<select data-k="fond" data-champ="semOuv" style="width:100%">${optListeOuvrages('terr-semelle', 'Semelle filante (fouilles en rigole)', () => BIB.ouvrages.filter(o => ouvActif(o) && o.lot === 'gros-oeuvre' && o.unite === 'm³' && /^Semelles filantes/i.test(o.designation)).map(o => o.designation), fd.semOuv || '', '— aucune semelle —')}</select>`))}</div>
    <p style="font-size:13px;margin:12px 0 4px"><strong>Fouilles en pleine masse</strong></p>
    <p style="font-size:12px;color:#6b5a7a;margin:0 0 4px">Ajoutez une ligne par fouille. Pour un massif, choisissez l'ouvrage de maçonnerie : sans choix, aucune semelle n'est ajoutée au métré.</p>
    ${pleinesDe(fd).map(e => `<div ${(e.usage || 'massif') === 'massif' ? 'data-source="massif_m3"' : ''} style="border:1px solid #e0c9a6;border-radius:8px;padding:8px;margin-top:6px;background:#fff">
      ${champ('Usage', `<select data-k="pleine" data-id="${esc(e.id)}" data-champ="usage" style="width:100%">${[['plateforme', 'Plateforme / dallage'], ['massif', 'Massif de fondation'], ['divers', 'Trou divers (ex. cuve)']].map(([v, l]) => `<option value="${v}"${(e.usage || 'massif') === v ? ' selected' : ''}>${l}</option>`).join('')}</select>`)}
      ${champ('Ouvrage de maçonnerie (une seule ligne au métré, lot gros œuvre)', (() => { const cle = `terr-maco-${e.usage || 'massif'}`, tit = 'Maçonnerie : ' + (e.usage || 'massif'); return selCrayon(cle, tit, `<select data-k="pleine" data-id="${esc(e.id)}" data-champ="ouv" style="width:100%">${optListeOuvrages(cle, tit, () => [...new Set(BIB.ouvrages.filter(o => ouvActif(o) && (o.unite === 'm²' || o.unite === 'm³') && o.lot === 'gros-oeuvre').map(o => o.designation))], e.ouv || '', '— aucun —')}</select>`) + `<label style="display:flex;gap:6px;align-items:center;font-size:14px;margin-top:4px"><input type="checkbox" data-k="pleine" data-id="${esc(e.id)}" data-champ="coff" ${e.coff ? 'checked' : ''} style="width:16px;height:16px;margin:0"> Coffrage compris (indiqué sur la ligne du métré)</label>`; })())}
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
    const nvDallages = plancherNvOuvrages().filter(o => /^Dallage/.test(o.designation));
    const nvPlanchers = plancherNvOuvrages().filter(o => !/^Dallage/.test(o.designation));
    return `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
      ${champ('RDC : surface du dallage (m²)', inp('data-k="plan" data-champ="brut" inputmode="decimal"', pl.brut || ''))}
      ${champ('RDC : type de dallage', sel2('data-k="plan" data-champ="dallage"', [CHOIX_VIDE, ...nvDallages.map(o => [o.id, o.designation])], pl.dallage || ''))}
      ${champ('Étage (R+1) : type de plancher', sel2('data-k="plan" data-champ="type"', [CHOIX_VIDE, ...nvPlanchers.map(o => ['ouv:' + o.id, o.designation])], pl.type || ''))}
      ${champ('Étage (R+1) : surface du plancher (m²)', inp('data-k="plan" data-champ="surface" inputmode="decimal"', pl.surface))}
    </div><p style="font-size:12px;color:#6b5a7a;margin:6px 0 0">Le dallage concerne le rez-de-chaussée (RDC). Le plancher concerne l'étage (R+1) : ne le renseignez que si la maison a un étage. Les quantités sont calculées sur les surfaces saisies.</p>`;
  })();
  $('cfgFiche').innerHTML = `<div id="cfgListesManque"></div>${tabTitre('A. Terrain')}<div class="bloc bloc-lettre">
    ${carte('Terrain et accès', `<div style="display:grid;grid-template-columns:1fr 1fr;gap:6px">
      <div style="grid-column:1/-1;display:flex;gap:8px;align-items:flex-end;flex-wrap:wrap"><div style="flex:1;min-width:220px">${champ('Référence du dossier Kanban', inp('data-k="kref" placeholder="ex. 003-02-2026"', refKanbanDe(c), '100%'))}</div></div>
      <div id="cfgEtudeKanban" style="grid-column:1/-1"></div>
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
  etudeKanbanAfficher(c);
  $('cfgFicheSuite').innerHTML = `    ${tabTitre('0. Installation de chantier')}<div class="bloc">
    ${carte('Installation de chantier (forfaits à ajouter ou non)', champ('Branchement provisoire d\'eau', `<select data-k="chant" data-champ="eau" style="width:100%;padding:6px">${['', 'oui', 'non'].map(v => `<option value="${v}" ${(p.chantier.eau || '') === v ? 'selected' : ''}>${{ '': '— à choisir —', oui: 'Oui', non: 'Non' }[v]}</option>`).join('')}</select>`)
      + champ('Branchement provisoire d\'électricité', `<select data-k="chant" data-champ="elec" style="width:100%;padding:6px">${['', 'oui', 'non'].map(v => `<option value="${v}" ${(p.chantier.elec || '') === v ? 'selected' : ''}>${{ '': '— à choisir —', oui: 'Oui', non: 'Non' }[v]}</option>`).join('')}</select>`)
      + champ('Base de vie (bungalow ou conteneur)', `<select data-k="chant" data-champ="base" style="width:100%;padding:6px">${['', 'oui', 'non'].map(v => `<option value="${v}" ${(p.chantier.base || '') === v ? 'selected' : ''}>${{ '': '— à choisir —', oui: 'Oui', non: 'Non' }[v]}</option>`).join('')}</select>`)
      + champ('Grue de chantier', `<select data-k="chant" data-champ="grue" style="width:100%;padding:6px">${['', 'oui', 'non'].map(v => `<option value="${v}" ${(p.chantier.grue || '') === v ? 'selected' : ''}>${{ '': '— à choisir —', oui: 'Oui', non: 'Non' }[v]}</option>`).join('')}</select>`)
      + champ('Nombre de bennes à gravats', inp('data-k="chant" data-champ="bennes" inputmode="numeric"', p.chantier.bennes, '120px'))
      + champ('Nombre de bennes à déchets triés', inp('data-k="chant" data-champ="bennesTri" inputmode="numeric"', p.chantier.bennesTri, '120px')))}
    </div>
    ${tabTitre('1. Terrassement')}<div class="bloc">
    ${carte('Fouilles en rigoles (linéaire saisi à la main)', contenuRig, 'fond_fouille')}
    </div>
    ${tabTitre('2. Gros œuvre + matériaux de finition')}<div class="bloc">
    ${carte('Murs de soubassement (mur au-dessus des fondations)', blocMurs('soub') + ajouterMur('soub', '+ Ajouter un mur de soubassement'))}
    ${carte('Murs périphériques', blocMurs('peri') + (p.murs.some(m => (m.cat || 'peri') === 'peri') ? '' : ajouterMur('peri', '+ Ajouter le mur périphérique')) + habillagesMenuiseries(p))}
    ${carte('Murs de refend (sans finition)', blocMurs('refend') + ajouterMur('refend', '+ Ajouter un mur de refend'))}
    ${carte('Murs pignons (demi-pignons pour les toits monopente)', blocMurs('pignon') + ajouterMur('pignon', '+ Ajouter un mur pignon'))}
    ${rigoleActive ? '' : carte('Fondations', contenuFond)}
    ${carte('Planchers : RDC (dallage) et étage (R+1)', contenuPlancher)}
    ${carte('Drainage et arase (murs périphériques)', ['drain|Drain en pied de mur', 'cunette|Cunette périphérique', 'regards|Regards de bouclage', 'arase|Arase étanche de pied de mur', 'nappe|Nappe de protection (murs de soubassement)'].map(x => { const [k, lib] = x.split('|'); const fn = { drain: drainBase, cunette: cunetteBase, regards: regardsBase, arase: araseBase, nappe: nappeBase }[k]; return champ(lib, selCrayon('dr-' + k, 'Drainage : ' + lib.toLowerCase(), `<select data-k="choix" data-champ="${k}" style="width:100%;padding:6px">${optListeOuvrages('dr-' + k, 'Drainage : ' + lib.toLowerCase(), fn, p.choix[k] || '', '— aucun —')}</select>`)) + (k === 'regards' ? champ('Nombre de regards', `<input data-k="choix" data-champ="regardsNb" inputmode="numeric" value="${esc(p.choix.regardsNb || '')}" style="width:100%;padding:6px">`) : ''); }).join(''))}
    </div>
    ${tabTitre('3. Charpente')}<div class="bloc">
    ${carte(nbToits > 1 ? `Toiture 1${toit.nom ? ' : ' + esc(toit.nom) : ''} — type, surfaces et charpente` : 'Toiture : type, surfaces et charpente', contenuCharp)}
    ${cartesToitsSup}${boutonToit}
    </div>
    ${tabTitre('4. Couverture')}<div class="bloc">
    ${carte('Couverture, égouts, faîtage, gouttières, descentes', contenuCouv)}
    </div>
    ${tabTitre('5. Menuiserie extérieure')}<div class="bloc">
    ${carte('Menuiseries extérieures : résumé (lecture seule, à saisir dans chaque pièce, bloc B)', menusResume)}
    </div>
    ${tabTitre('6. Isolation')}<div class="bloc">
    ${carte('Isolation', contenuIso)}
    </div>
    ${tabTitre('7. Plâtrerie')}<div class="bloc">
    ${carte('Cloisons et doublages', '<p class="muted">Les cloisons et doublages se saisissent pièce par pièce, dans le bloc B.</p>')}
    </div>
    ${tabTitre('8. Électricité')}<div class="bloc">
    ${carte('Équipements électriques et extérieurs', contenuElec)}
    </div>
    ${tabTitre('9. Plomberie sanitaire')}<div class="bloc">
    ${carte('Équipements sanitaires, eau chaude, cuves, assainissement', contenuPlomb)}
    </div>
    ${tabTitre('10. Revêtements de sol')}<div class="bloc">
    ${carte('Revêtements de sol', '<p class="muted">Le revêtement de chaque pièce se choisit dans le bloc B, menu « Sol » de la pièce.</p>')}
    </div>
    ${tabTitre('11. Chauffage, VMC, climatisation')}<div class="bloc">
    ${carte('Chauffage, ventilation, climatisation', contenuChauf)}
    </div>
    ${tabTitre('12. Cuisine')}<div class="bloc">
    ${carte('Cuisine (linéaires et plan de travail)', champ('Meubles bas (ml)', inp('data-k="cuis" data-champ="bas" inputmode="decimal"', p.cuisine.bas, '160px'))
      + champ('Meubles hauts (ml)', inp('data-k="cuis" data-champ="haut" inputmode="decimal"', p.cuisine.haut, '160px'))
      + champ('Plan de travail', sel2('data-k="cuis" data-champ="plan"', [CHOIX_VIDE, ['stratifie', 'Stratifié'], ['quartz', 'Quartz']], p.cuisine.plan || ''))
      + champ('Longueur du plan de travail (ml)', inp('data-k="cuis" data-champ="plan_ml" inputmode="decimal"', p.cuisine.plan_ml, '160px')))}
    </div>
`;
  $('cfgResultats').innerHTML = `<div class="bloc">${carte('Résultats des calculs', '<div id="ficheResume"></div>')}</div>`;
  ficheResume();
}
function ficheResume() {
  const c = chantiers.find(x => x.id === courantId); if (!c) return;
  document.querySelectorAll('.toitManque').forEach(el => { el.innerHTML = toitureManqueHtml(projetDe(c)); });
  if ($('cfgListesManque')) $('cfgListesManque').innerHTML = listesNonRelieesHtml(projetDe(c));
  if (!$('ficheResume')) return;
  const p = projetDe(c), r = projetCalcul(p);
  const ligne = (a, b, gras) => `<tr><td style="padding:4px 0;${gras ? 'font-weight:700' : ''}">${a}</td><td style="text-align:right;padding:4px 0;${gras ? 'font-weight:700;color:#6a1b9a' : ''}">${b}</td></tr>`;
  $('ficheResume').innerHTML = `<table style="width:100%;border-collapse:collapse">
    ${ligne('Murs (longueur × hauteur)', fmt(r.brut) + ' m²')}
    ${ligne('Ouvertures égales ou supérieures à 1 m² déduites', '− ' + fmt(r.deduit) + ' m²')}
    ${ligne('Élévation nette des murs (finition)', fmt(r.net) + ' m²', true)}
    ${ligne('Tableaux de menuiseries (linéaire : 2 côtés + linteau)', fmt(r.tableaux) + ' ml', true)}
    ${ligne('Toiture (surface développée)', fmt(r.toiture) + ' m²', true)}
    ${ligne('Linéaire des murs porteurs', fmt(r.linP) + ' ml')}
    ${ligne('Fouilles en tranchée', fmt(r.fouille) + ' m³', true)}
    ${ligne('Semelles filantes béton', fmt(r.semelle) + ' m³', true)}
    ${ligne('Soubassement : surface des murs porteurs', fmt(r.soubS) + ' m²', true)}
  </table>
  ${r.ouvs.length ? `<p style="font-size:12px;color:#6b5a7a;margin:8px 0 0">${r.ouvs.map(x => `${esc(x.o.nom)} : ${fmt(x.aire)} m² · tableau ${fmt(x.tab)} ml${x.deduit ? ' · déduite des murs' : ''}`).join('<br>')}</p>` : ''}`;
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
  else if (k === 'toit') {
    p.toiture[champ] = val;
    // Toit terrasse : la géométrie devient « plat » ; une autre charpente la remet à choisir
    if (champ === 'charpente') { if (charpenteDe(p.toiture) === 'terrasse') p.toiture.type = 'plat'; else if (p.toiture.type === 'plat') p.toiture.type = ''; }
  }
  else if (k === 'toitS') {
    const ts = (p.toituresSup || []).find(x => x.id === t.dataset.id);
    if (ts) {
      ts[champ] = val;
      if (champ === 'charpente') { if (charpenteDe(ts) === 'terrasse') ts.type = 'plat'; else if (ts.type === 'plat') ts.type = ''; }
    }
  }
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
  const refaire = (k === 'mur' && ['longueur', 'hauteur', 'type', 'ouvLibre'].includes(champ)) || (k === 'equip' && champ === 'poele') || (k === 'ouv' && ['volet', 'type'].includes(champ)) || ((k === 'toit' || k === 'toitS') && ['type', 'charpente', 'versant'].includes(champ)) || (k === 'plan' && champ === 'type') || (k === 'pleine' && champ === 'usage');
  if (refaire) ficheRendre(); else ficheResume();
}
// Lecture seule du Kanban : même adresse que le Kanban utilise pour lire ses dossiers
const KANBAN_LECTURE = 'https://script.google.com/macros/s/AKfycbwLGYVnT9HvYgLJNzEP1QCa8b-BQw18eZ0vse2hXixZT4LwrFv3-bt4X4i--gX8eqDoKw/exec';
// Référence Kanban : celle saisie, sinon celle du client Kanban choisi pour ce métré
// Étude de faisabilité du dossier Kanban (zones sismique, de vent et de neige, argile, radon, risques, PLU) : affichée en lecture seule
const _kanbanDossiers = {};
function etudeKanbanHtml(card, pourImpression) {
  const f = card.faisa || {}, e = card.euro || {};
  const v = x => (x === undefined || x === null || x === '' || (Array.isArray(x) && !x.length)) ? '—' : esc(Array.isArray(x) ? x.join(', ') : String(x));
  const lignes = [
    ['Zone sismique', v(f.sismicite)],
    ['Zone de vent', v(e.vent)],
    ['Zone de neige', v(e.neige)],
    ['Altitude (m)', v(e.alt)],
    ['Catégorie', v(e.cat)],
    ['Hauteur de référence (m)', v(e.h)],
    ['Retrait-gonflement des argiles', v(f.argile)],
    ['Radon (niveau)', v(f.radon)],
    ['Risques naturels', v(f.risques)],
    ['Zones du PLU', v((f.zones || []).map(z => z.code))],
  ];
  if (pourImpression) return `<div style="display:grid;grid-template-columns:1fr 1fr;gap:4px 12px;font-size:14px">${lignes.map(([lib, val]) => `<div><b>${lib}</b> : ${val}</div>`).join('')}</div>`;
  const lien = f.georisquesUrl ? ` <a href="${esc(f.georisquesUrl)}" target="_blank" rel="noopener">Rapport Géorisques</a>` : '';
  return `<div style="border-top:1px solid var(--mut);padding-top:8px;margin-top:4px">
    <div style="font-weight:600;font-size:14px;margin-bottom:6px">Étude de faisabilité (Kanban, lecture seule)${lien}</div>
    <div style="display:grid;grid-template-columns:1fr 1fr;gap:4px 12px;font-size:14px">
      ${lignes.map(([lib, val]) => `<div><b>${lib}</b> : ${val}</div>`).join('')}
    </div></div>`;
}
// Lecture d'un dossier du Kanban (une fois, puis mémorisée ; null si le dossier n'existe pas)
const _kanbanEnCours = {};
function dossierKanban(ref) {
  if (ref in _kanbanDossiers) return Promise.resolve(_kanbanDossiers[ref]);
  if (_kanbanEnCours[ref]) return _kanbanEnCours[ref];
  _kanbanEnCours[ref] = fetch(KANBAN_LECTURE).then(r => r.json()).then(db => {
    const card = [...(db.cards || []), ...(db.archived || [])].find(x => x.ref === ref) || null;
    _kanbanDossiers[ref] = card; delete _kanbanEnCours[ref];
    return card;
  }).catch(err => { delete _kanbanEnCours[ref]; throw err; });
  return _kanbanEnCours[ref];
}
// Étude de faisabilité du chantier courant, pour la page de garde imprimée
function etudeCouranteImpression() {
  const c = chantiers.find(x => x.id === courantId); const ref = c ? refKanbanDe(c) : '';
  const card = ref && _kanbanDossiers[ref];
  if (!card) return '';
  return `<div class="bloc"><h2>Étude de faisabilité</h2>${etudeKanbanHtml(card, true)}</div>`;
}
function etudeKanbanAfficher(c) {
  const box = $('cfgEtudeKanban'); if (!box) return;
  const ref = refKanbanDe(c);
  if (!ref) { box.innerHTML = ''; return; }
  if (_kanbanDossiers[ref]) { box.innerHTML = etudeKanbanHtml(_kanbanDossiers[ref]); return; }
  box.innerHTML = '<p style="font-size:12px;color:#6b5a7a;margin:6px 0 0">Lecture de l\'étude de faisabilité…</p>';
  dossierKanban(ref).then(card => {
    if (!card) { if ($('cfgEtudeKanban')) $('cfgEtudeKanban').innerHTML = ''; return; }
    if (refKanbanDe(c) === ref && $('cfgEtudeKanban')) $('cfgEtudeKanban').innerHTML = etudeKanbanHtml(card);
    if (typeof renderMetre === 'function') renderMetre();   // généralités et page de garde se mettent à jour
  }).catch(() => { if ($('cfgEtudeKanban')) $('cfgEtudeKanban').innerHTML = '<p style="font-size:12px;color:#6b5a7a;margin:6px 0 0">Étude de faisabilité : Kanban injoignable pour le moment.</p>'; });
}
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
  if (a === 'gerer-liste') { ouvrirDepuisCrayon(b); return; }
  if (a === 'addmur') {
    const cat = b.dataset.cat || 'peri';
    const nomCat = { soub: 'Mur de soubassement', peri: 'Mur périphérique', refend: 'Mur de refend', pignon: 'Mur pignon' }[cat];
    p.murs.push({ id: 'm' + uid(), cat, nom: nomCat + ' ' + (p.murs.length + 1), longueur: '', hauteur: cat === 'soub' ? (p.soub.hauteur || '') : '', pente: '', nb: '', nbDemi: '', porteur: true, type: '', finition: '', ouvLibre: '', deduire: false });
  }
  else if (a === 'delmur') p.murs = p.murs.filter(m => m.id !== b.dataset.id);
  else if (a === 'delouv') p.ouvertures = p.ouvertures.filter(o => o.id !== b.dataset.id);
  else if (a === 'addpleine') pleinesDe(p.fond).push({ id: 'p' + uid(), usage: 'massif', nb: '', L: '', l: '', h: '' });
  else if (a === 'delpleine') p.fond.pleines = pleinesDe(p.fond).filter(e => e.id !== b.dataset.id);
  else if (a === 'addtoit') { p.toituresSup = p.toituresSup || []; if (toitsDe(p).length < TOITS_MAX) p.toituresSup.push({ id: 't' + uid(), nom: '', charpente: '', type: '', surface: '', surfCouv: '', pente: '' }); }
  else if (a === 'deltoit') { if (!confirm('Supprimer cette toiture et sa charpente ?')) return; p.toituresSup = (p.toituresSup || []).filter(x => x.id !== b.dataset.id); }
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
  const ajouter = (des, q, designation, valeursFixes, src, origine) => {
    if (!des) { if (q > 0) manquants.push('(choix non fait)'); return; }
    const o = BIB.ouvrages.find(x => !x.supprime && x.designation === des);
    if (!o) { manquants.push(des); return; }
    if (!(q > 0)) return;
    const valeurs = valeursFixes || valeursPour(o.unite, q);
    if (src && (o.unite === 'm²' || o.unite === 'm³')) valeurs.src = 'Calcul du configurateur : ' + src;
    const lot = o.lot;
    ajouterLotSiAbsent(courantId, lot);
    L.push({ uid: uid(), lot, ouvrage: o.id, designation: designation || o.designation, unite: o.unite,
             valeurs, quantite: calcul(o, valeurs), surface: null, prix: 'moyen', projet: true, origine: origine || null, cree: new Date().toISOString(),
             qteAuto: o.qte === 'fond_semelle' ? 'fond_semelle' : undefined });
    nb++;
  };
  const murDuType = (t, soub) => { const m = (p.murs || []).find(x => (x.type || '') === t && ((x.cat || 'peri') === 'soub') === !!soub); return m ? { mur: m.id } : null; };
  // Fondations : uniquement si des fouilles en rigole sont saisies dans le terrassement
  const fdim = p.fond || FICHE_FONDS_DEF;
  // Fouilles en pleine masse (plateforme, massifs, trous divers) : indépendantes des rigoles
  for (const e of pleinesDe(fdim)) {
    const L_ = num(e.L), l_ = num(e.l), h_ = num(e.h), n_ = num(e.nb);
    const dims = { cote1: String(L_), cote2: String(l_), cote3: String(h_) };
    if (e.usage === 'massif') {
      if (!(n_ > 0 && L_ > 0 && l_ > 0 && h_ > 0)) continue;
      ajouter(DES_MASSIF, n_ * L_ * l_ * h_, undefined, { nombre: String(n_), ...dims });
      // Pas de semelle automatique : l'ouvrage de maçonnerie choisi ci-dessous (si il y en a un) est seul au métré
    } else if (e.usage === 'plateforme') {
      const S_ = num(e.s), H_ = num(e.h), N_ = 1;  // plateforme : toujours 1, pas de nombre
      if (S_ > 0 && H_ > 0) ajouter(DES_PLATEFORME, N_ * S_ * H_, undefined, { nombre: String(N_), cote1: String(S_), cote2: '1', cote3: String(H_), src: TXT_SURFACE });
    } else if (e.usage === 'divers') {
      if (L_ > 0 && l_ > 0 && h_ > 0) ajouter(DES_DIVERS, L_ * l_ * h_, undefined, { nombre: '1', ...dims });
    }
    // Ouvrage de maçonnerie choisi pour cet usage : une seule ligne au lot maçonnerie
    if (e.ouv) {
      const o = BIB.ouvrages.find(x => x.id === e.ouv && !x.supprime);
      const usage = e.usage || 'massif', enM2 = o && o.unite === 'm²';
      let q = 0;
      if (usage === 'plateforme') q = enM2 ? num(e.s) : num(e.s) * num(e.h);
      else if (usage === 'massif') { const base = num(e.nb) * num(e.L) * num(e.l); q = enM2 ? base : base * num(e.h); }
      else q = enM2 ? num(e.L) * num(e.l) : num(e.L) * num(e.l) * num(e.h);
      // Massif : même détail que la fouille du terrassement (nombre, longueur, largeur, hauteur)
      const valMassif = usage === 'massif' ? { nombre: String(num(e.nb)), cote1: String(num(e.L)), cote2: String(num(e.l)), cote3: String(num(e.h)) } : null;
      if (o && (o.unite === 'm²' || o.unite === 'm³')) ajouter(o.designation, q, e.coff ? o.designation + ' (coffrage compris)' : undefined, valMassif, valMassif ? null : 'fouille ' + usage + ' (terrassement)');
      else if (o) manquants.push(o.designation + ' (unité non prise en charge)');
    }
  }
  // Semelles filantes et fouilles en tranchée : seulement si des rigoles sont saisies
  if (!(num(fdim.rigLin) > 0)) { /* pas de semelles filantes sans terrassement en rigole */ } else {
  const nAvantFouille = L.length;
  ajouter(DES_FOND_FOUILLE, r.fouille, 'Fouilles en tranchée pour semelles filantes',
    { nombre: '1', cote1: String(r.fondLin), cote2: String(r.fdimLarg), cote3: String(r.fdimProf) });
  // Semelle choisie par l'utilisateur : mémorisée sur la ligne de fouille, lue par alignerFondations()
  // Rien de choisi : pas de semelle au métré (aucune valeur par défaut)
  if (L.length > nAvantFouille) L[L.length - 1].semOuv = fdim.semOuv || '';
  // OUV-0040 reprend automatiquement les cotes de la ligne OUV-0008 (fouille) si elle existe
  // La semelle béton (gros œuvre) n'est plus créée ici : elle suit la ligne de fouille, voir alignerFondations()
  }
  // Décapage et réseaux en tranchée, selon les champs du configurateur (Terrain). Pas de clôture : elle se lie à la main.
  { const dec = num(p.terrain.decap); ajouter(DES_DECAP, dec, undefined, { nombre: '1', cote1: dec.toFixed(2), cote2: '1', src: TXT_SURFACE }); }
  ajouter(DES_RES_EAU, num(p.terrain.resEau));
  ajouter(DES_RES_EU, num(p.terrain.resEu));
  ajouter(DES_RES_EP, num(p.terrain.resEp));
  ajouter(DES_RES_ELEC, num(p.terrain.resElec));
  // Installation de chantier, selon « Chantier » du configurateur (forfaits oui/non, nombre de bennes)
  const ch = p.chantier || {};
  ajouter(DES_BRANCH_EAU, ch.eau === 'oui' ? 1 : 0);
  ajouter(DES_BRANCH_ELEC, ch.elec === 'oui' ? 1 : 0);
  ajouter(DES_BASE_VIE, ch.base === 'oui' ? 1 : 0);
  ajouter(DES_GRUE, ch.grue === 'oui' ? 1 : 0);
  ajouter(DES_BENNE, num(ch.bennes));
  ajouter(DES_BENNE_TRI, num(ch.bennesTri));
  // Soubassement : chaque mur avec son matériau ; solin en tête sur son linéaire
  // Un seul article par type de mur : les cases « compris » se règlent dans le configurateur, elles n'apparaissent plus au métré
  const soubParType = {};
  for (const [cle, surf] of Object.entries(r.parSoub || {})) {
    const t = cle.slice(0, cle.lastIndexOf('|'));
    soubParType[t] = (soubParType[t] || 0) + surf;
  }
  for (const [t, surf] of Object.entries(soubParType)) {
    if (!(surf > 0)) continue;
    if (!t) { manquants.push('Matériau du mur de soubassement'); continue; }
    ajouter(t, surf, t, null, SRC_QTE.soub_s, murDuType(t, true));
  }
  // Solin en tête de soubassement : seulement sur les murs de soubassement avec enduit hydrofuge
  ajouter('Solin en aluminium fixé en tête de mur de soubassement', r.linSolin, 'Solin aluminium fixé en tête de soubassement');
  // Membrane Delta-MS : pose sur la hauteur du soubassement + 30 cm, seulement si ce mur a cette protection
  ajouter(DELTA_SOUB, r.deltaSoub, DELTA_SOUB, null, 'murs de soubassement (hauteur + 30 cm)');
  // Plancher bas
  // Ouvrage de la bibliothèque choisi dans une liste reliée à la bibliothèque (crayon) : quantité de la case
  {
    const ctxB = ctxQuantites(c);
    for (const cle of Object.keys(FIXES_DEFAUTS)) {
      const e = etatListe(p, cle);
      if (!e || !e.o || !e.src) continue;
      const v = qteValeur({ qte: e.src, unite: e.o.unite }, ctxB);
      if (v) ajouter(e.o.designation, n1b(v.nombre) * n1b(v.cote1) * n1b(v.cote2) * n1b(v.cote3), undefined, v);
    }
  }
  // Valeurs ajoutées à une liste à choix fixe, liées à un ouvrage de la bibliothèque (crayon)
  {
    const RUBRIQUE = { toit: 'toiture', equip: 'equip', plan: 'plancher', cuis: 'cuisine', choix: 'choix' };
    const ctxQ = ctxQuantites(c), n1 = x => (x === undefined || x === null || x === '' ? 1 : num(x));
    Object.entries(listesReglages()).forEach(([cle, rg]) => {
      const [k, champ] = cle.split('.');
      if (!champ || !RUBRIQUE[k] || !Array.isArray(rg.ajoutes)) return;
      const val = (p[RUBRIQUE[k]] || {})[champ];
      const a = rg.ajoutes.find(x => x.v === val && x.des && (rg.retires || []).indexOf(x.v) < 0);
      if (!a) return;
      const o = BIB.ouvrages.find(x => !x.supprime && x.designation === a.des);
      const v = o && a.src ? qteValeur({ qte: a.src, unite: o.unite }, ctxQ) : null;
      if (!v) return;
      ajouter(a.des, n1(v.nombre) * n1(v.cote1) * n1(v.cote2) * n1(v.cote3), undefined, v);
    });
  }
  // Surface de plancher brut saisie à la main : dallage béton sur terre-plein
  if (num(p.plancher.brut) > 0) {
    // Dallage RDC : seulement le type choisi dans le configurateur (rien choisi = rien)
    const oD = p.plancher.dallage ? BIB.ouvrages.find(x => x.id === p.plancher.dallage && !x.supprime) : null;
    if (oD) ajouter(oD.designation, num(p.plancher.brut), oD.designation, { nombre: '1', cote1: String(num(p.plancher.brut)), cote2: '1', src: TXT_SURFACE }, null);
    else manquants.push('type de dallage (RDC)');
  }
  // Plancher choisi parmi les nouveaux ouvrages : quantité = surface du plancher
  if (String(p.plancher.type || '').startsWith('ouv:') && r.plS > 0) {
    const oP = BIB.ouvrages.find(x => x.id === p.plancher.type.slice(4) && !x.supprime);
    if (oP) ajouter(oP.designation, r.plS, oP.designation, { nombre: '1', cote1: String(r.plS), cote2: '1', src: TXT_SURFACE }, null);
  }
  // Élévation, finition, tableaux, toiture
  // Une ligne par type de mur ; les murs sans type prennent le « Matériau des murs » du chantier
  // Cases cochées des murs en élévation : indiquées dans la désignation, sans changer la quantité
  // Détail des élévations : la formule du métier (longueur × hauteur, moins les menuiseries), sans mention du configurateur
  const SRC_ELEV = 'Calcul du configurateur : ' + SRC_QTE.elev_net;
  const ELEV_FL = ['chaînage compris', 'poteau raidisseur compris', 'appui de fenêtre compris', 'seuil de porte compris'];
  const elevParType = {};
  for (const [cle, surf] of Object.entries(r.parTypeFl || {})) {
    const t = cle.slice(0, cle.lastIndexOf('|'));
    elevParType[t] = (elevParType[t] || 0) + surf;
  }
  for (const [t, surf] of Object.entries(elevParType)) {
    if (!(surf > 0)) continue;
    if (t === '') {
      manquants.push('Type de mur (mur sans type)'); continue;
    } else {
      ajouter(t, surf, t.replace(/\s*\([^)]*\)/g, ''), { nombre: '1', cote1: surf.toFixed(2), cote2: '1', src: SRC_ELEV, typeMur: t }, null, murDuType(t, false));
    }
  }
  // Finitions et protections choisies mur par mur (surface nette de chaque mur)
  for (const [f, surf] of Object.entries(r.parFin || {})) if (surf > 0) ajouter(f, surf, f, null, SRC_QTE.finit_net);
  // Tableaux : revêtement choisi dans le configurateur, sinon finition extérieure du mur périphérique (automatique dès qu'une fenêtre est saisie)
  // Habillages des menuiseries (ml) : même linéaire pour le tableau et la bande de peinture
  const habMl = habillageMl(c);
  // Les tableaux de menuiseries se comptent uniquement au mètre linéaire (habillage choisi dans la fiche) : plus de ligne en m²
  for (const id of [p.choix.habTab, p.choix.habBande]) {
    const o = id && BIB.ouvrages.find(x => x.id === id);
    if (!(o && habMl > 0)) continue;
    const n0 = L.length;
    ajouter(o.designation, habMl, o.designation, null, null);
    // Détail écrit : linéaire en ml et épaisseur du mur périphérique (sur l'ouvrage, au mètre linéaire)
    const lHab = L[L.length - 1];
    if (L.length > n0 && lHab.ouvrage === o.id) { lHab.modeLigne = 'texte'; lHab.detailTexte = `${fmt(habMl)} ml (2 × hauteur + largeur, par menuiserie) – épaisseur du mur périphérique ${fmt((r.epMoy || 0) * 100)} cm`; }
  }
  // Linteaux : largeur de chaque menuiserie + 0,40 m, regroupées par largeur ; une ligne par longueur
  {
    const groupes = {};
    piecesNvDe(c).forEach(pc => (pc.menus || []).forEach(m => {
      const w = num(m.l) / 100, nb = num(m.nb) || 1;
      if (!(w > 0)) return;
      const k = w.toFixed(2);
      groupes[k] = groupes[k] || { w, nb: 0 };
      groupes[k].nb += nb;
    }));
    const oStd = p.choix.linStd && BIB.ouvrages.find(x => x.id === p.choix.linStd);
    const oGp = p.choix.linGp && BIB.ouvrages.find(x => x.id === p.choix.linGp);
    Object.values(groupes).sort((a, b) => a.w - b.w).forEach(g => {
      const o = g.w > 2.5 ? oGp : oStd;
      if (!o) return;
      const long = g.w + 0.4;
      const q = long * g.nb;
      // Détail écrit : largeur d'ouverture + 2 × 0,20 m d'appui, × nombre de menuiseries (comme le calcul réellement fait)
      ajouter(o.designation, q, `${o.designation} – ${fmt(long)} m (${fmt(g.w)} m + 0,40 m) × ${g.nb} menuiserie${g.nb > 1 ? 's' : ''} de même largeur`, { nombre: String(g.nb), cote1: String(long) }, null, null);
      const lLin = L[L.length - 1];
      if (lLin && lLin.ouvrage === o.id) { lLin.modeLigne = 'texte'; lLin.detailTexte = `${fmt(g.w)} m d'ouverture + 2 × 0,20 m d'appui = ${fmt(long)} m × ${g.nb} menuiserie${g.nb > 1 ? 's' : ''} = ${fmt(q)} ml`; }
    });
  }
  // Chaînages et poteaux raidisseurs, mur par mur : chaînage = longueur du mur ; poteau = nombre saisi × hauteur du mur
  for (const m of (p.murs || [])) {
    const cat = m.cat || 'peri';
    if (cat !== 'pignon' && m.chaine === true && m.liste_chaine && num(m.longueur) > 0) {
      const o = BIB.ouvrages.find(x => x.id === m.liste_chaine);
      if (o) ajouter(o.designation, num(m.longueur), `${o.designation} – ${m.nom || 'mur'} : longueur ${fmt(num(m.longueur))} m`, null, null, { mur: m.id });
    }
    if (m.raid === true && m.liste_raid && num(m.nbPoteaux) > 0 && num(m.hauteur) > 0) {
      const o = BIB.ouvrages.find(x => x.id === m.liste_raid);
      if (o) ajouter(o.designation, num(m.nbPoteaux) * num(m.hauteur), `${o.designation} – ${m.nom || 'mur'} : ${fmt(num(m.nbPoteaux))} poteaux × hauteur ${fmt(num(m.hauteur))} m`, null, null, { mur: m.id });
    }
  }
  // Chaînage sur le mur périphérique (ml) : linéaire du mur périphérique
  {
    const oCha = p.choix.habCha && BIB.ouvrages.find(x => x.id === p.choix.habCha);
    const linPeri = (p.murs || []).filter(m => (m.cat || 'peri') === 'peri').reduce((a, m) => a + num(m.longueur), 0);
    if (oCha && linPeri > 0) ajouter(oCha.designation, linPeri, oCha.designation, null, null);
  }
  // Chaînages d'angle en pierre (ml) : nombre saisi × hauteur moyenne des murs périphériques
  {
    const oAng = p.choix.habAng && BIB.ouvrages.find(x => x.id === p.choix.habAng);
    const nAng = num(p.choix.habAngNb);
    const hauts = (p.murs || []).filter(m => (m.cat || 'peri') === 'peri' && num(m.hauteur) > 0).map(m => num(m.hauteur));
    const hMoy = hauts.length ? hauts.reduce((a, b) => a + b, 0) / hauts.length : 0;
    if (oAng && nAng > 0) {
      if (hMoy > 0) {
        // Détail écrit : nombre de chaînages × hauteur moyenne = longueur, comme le calcul réellement fait
        ajouter(oAng.designation, nAng * hMoy, oAng.designation, { nombre: String(nAng), cote1: String(hMoy) }, null, null);
        const lAng = L[L.length - 1];
        if (lAng && lAng.ouvrage === oAng.id) { lAng.modeLigne = 'texte'; lAng.detailTexte = `${fmt(nAng)} chaînage(s) d'angle × hauteur moyenne ${fmt(hMoy)} m = ${fmt(nAng * hMoy)} ml`; }
      }
      else manquants.push('hauteur des murs périphériques (chaînage d\'angle)');
    }
  }
  // Charpente et écran de sous-toiture : l'ouvrage de la bibliothèque correspond à la variante (type de toit, pente, charpente, écran)
  for (const o of BIB.ouvrages) {
    if (!ouvActif(o) || !o.si || !['charpente_variante', 'ecran'].includes(o.si.cle) || !o.qte) continue;
    const v = qteValeur(o, ctxQuantites(c));
    if (v && num(v.cote1) > 0) ajouter(o.designation, num(v.cote1), undefined, null, SRC_QTE[o.qte] || null);
  }
  // Toits terrasses : étanchéité ; toits en pente : couverture (surfaces de toutes les toitures concernées)
  if (toitPlat(p) && p.toiture.etancheite && r.toitPlat > 0) ajouter(ETANCH_DESIG[p.toiture.etancheite], r.toitPlat, 'Étanchéité de la partie courante du toit plat', null, SRC_QTE.surface_toiture);
  if (toitPente(p) && COUV_OUV[couvDe(p.toiture)]) ajouter(desOuv(COUV_OUV[couvDe(p.toiture)]), r.toitPente, undefined, null, SRC_QTE.surface_toiture);
  // Toiture incomplète : on le signale, sinon la charpente et la couverture restent absentes sans explication
  manquants.push(...toitureManquants(p));
  // Charpente : fermettes (m² projeté au sol), charpente traditionnelle et chevronnage (m² de rampant)
  // Une charpente par toiture (désignation suivie du nom de la toiture quand il y en a plusieurs)
  {
    const toitsL = toitsDe(p), plusieurs = toitsL.length > 1;
    toitsL.forEach((t, i) => {
      if (t.type === 'plat') return;
      const suf = plusieurs ? ' – ' + nomToit(t, i) : '';
      const ch = charpenteDe(t);
      if (ch === 'fermette') { const d = desOuv('OUV-1839'); ajouter(d, planToit(t), d + suf, null, SRC_QTE.surface_toiture_plan); }
      if (ch === 'traditionnelle') {
        const d = desOuv('OUV-1840'); ajouter(d, 1, d + suf, { nombre: '1' });   // forfait unique par charpente
        if (t.chevronnage) { const d2 = desOuv('OUV-1841'); ajouter(d2, rampantToit(t), d2 + suf, null, SRC_QTE.surface_toiture); }
      }
    });
  }
  // Pénétrations (m² ou ml), chevêtres (u) et croupes (m²) saisis dans la fiche Charpente
  // Pénétrations : au forfait (une par pénétration) ; la noue se compte en couverture
  ajouter(desOuv('OUV-1871'), num(p.toiture.nbPenetInd), undefined, { nombre: String(num(p.toiture.nbPenetInd)) });
  ajouter(desOuv('OUV-1872'), num(p.toiture.nbPenetTrad), undefined, { nombre: String(num(p.toiture.nbPenetTrad)) });
  ajouter(desOuv('OUV-1873'), num(p.toiture.nbChevInd));
  ajouter(desOuv('OUV-1874'), num(p.toiture.nbGrandChevInd));
  ajouter(desOuv('OUV-1877'), num(p.toiture.nbChevTrad));
  ajouter(desOuv('OUV-1875'), num(p.toiture.m2CroupeInd), undefined, null, SRC_QTE.surface_toiture_plan);
  ajouter(desOuv('OUV-1876'), num(p.toiture.m2CroupeTrad), undefined, null, SRC_QTE.surface_toiture);
  // Accessoires de tuiles : faîtage, rives, noues, tuiles à douille (longueurs et nombres saisis dans la fiche)
  if (toitPente(p) && /^tuile/.test(couvDe(p.toiture))) {
    ajouter(desOuv('OUV-1846'), num(p.toiture.faite));
    ajouter(desOuv('OUV-1847'), num(p.toiture.rive));
    ajouter(desOuv('OUV-1851'), ventilationNb(p));
  }
  // Accessoires d'ardoise, de zinc ou de bacs acier (faîtage, rives, égout, ventilation)
  if (toitPente(p) && COUV_ACC[couvDe(p.toiture)]) {
    const A = COUV_ACC[couvDe(p.toiture)];
    ajouter(desOuv(A.faite), num(p.toiture.faite));
    ajouter(desOuv(A.rive), num(p.toiture.rive));
    if (A.egout) ajouter(desOuv(A.egout), num(p.toiture.egout));
    if (A.ventil) ajouter(desOuv(A.ventil), ventilationNb(p));
  }
  // Noue en zinc : pour toutes les couvertures (saisie dans la fiche Charpente)
  if (toitPente(p) && COUV_OUV[couvDe(p.toiture)]) ajouter(desOuv('OUV-1853'), num(p.toiture.noue));
  // Accessoires saisis en nombre ou en ml (fiche Couverture)
  if (toitPente(p) && /^tuile/.test(couvDe(p.toiture))) {
    ajouter(desOuv('OUV-1849'), num(p.toiture.nbFronton));
    ajouter(desOuv('OUV-1850'), num(p.toiture.nbChatiere));
    ajouter(desOuv('OUV-1852'), num(p.toiture.nbDemiTuile));
  } else if (toitPente(p) && (num(p.toiture.nbFronton) > 0 || num(p.toiture.nbChatiere) > 0 || num(p.toiture.nbDemiTuile) > 0)) {
    manquants.push('frontons, chatières et demi-tuiles : réservés aux couvertures en tuiles');
  }
  if (toitPente(p)) {
    ajouter(desOuv('OUV-1856'), num(p.toiture.nbAbergement));
    ajouter(desOuv('OUV-1857'), num(p.toiture.nbSelle));
    ajouter(desOuv('OUV-1854'), num(p.toiture.mlSolin));
    ajouter(desOuv('OUV-1855'), num(p.toiture.mlCouloir));
  }
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
  // Appuis de fenêtre : cochés dans les murs extérieurs. Chaque fenêtre du projet reçoit l'appui choisi dans la liste du mur.
  // Une ligne par largeur, unité = nombre de fenêtres de cette largeur.
  const appuisChoisis = [...new Set((p.murs || []).filter(m => ['peri', 'pignon'].includes(m.cat || 'peri') && m.appui === true && m.liste_appui).map(m => m.liste_appui))];
  if (appuisChoisis.length > 1) manquants.push('appuis de fenêtre : un seul appui par projet, plusieurs choisis dans les murs');
  if (appuisChoisis.length === 1) {
    const oA = BIB.ouvrages.find(x => x.id === appuisChoisis[0]);
    if (!oA) manquants.push('appui de fenêtre');
    else {
      const parLargeur = {};
      for (const pc of piecesNvDe(c)) for (const m of (pc.menus || [])) {
        if (m.type !== 'fen' || !(num(m.l) > 0)) continue;
        parLargeur[num(m.l)] = (parLargeur[num(m.l)] || 0) + (num(m.nb) || 1);
      }
      for (const [Lcm, n] of Object.entries(parLargeur)) ajouter(oA.designation, n, `${oA.designation.replace(/\s*\([^)]*\)/g, '')} – largeur ${fmt(Number(Lcm) / 100)} m`, { nombre: String(n) }, null);
    }
  }
  // Drainage et arase : longueur des murs périphériques (regards : nombre saisi). Rien choisi = rien.
  const longPeriDr = (p.murs || []).filter(m => (m.cat || 'peri') === 'peri').reduce((a, m) => a + num(m.longueur), 0);
  const ajouterDrainage = (id, q) => { const o = id && BIB.ouvrages.find(x => x.id === id); if (o && q > 0) ajouter(o.designation, q, o.designation.replace(/\s*\([^)]*\)/g, ''), null, null); };
  ajouterDrainage(p.choix.drain, longPeriDr);
  ajouterDrainage(p.choix.cunette, longPeriDr);
  ajouterDrainage(p.choix.arase, longPeriDr);
  ajouterDrainage(p.choix.regards, num(p.choix.regardsNb));
  // Nappe : surface des murs de soubassement + 0,60 m de hauteur (relevé de 15 à 20 cm au-dessus du mur, 40 à 45 cm sous le drain)
  const soubLongNappe = (p.murs || []).filter(m => m.cat === 'soub').reduce((a, m) => a + num(m.longueur), 0);
  // Les plaques de protection ne prennent pas le relevé : seule la nappe le prend
  const oNappe = p.choix.nappe && BIB.ouvrages.find(x => x.id === p.choix.nappe);
  const avecReleve = oNappe && /^Nappe /.test(oNappe.designation);
  const surfNappe = r.soubS + (avecReleve ? 0.6 * soubLongNappe : 0);
  if (oNappe && surfNappe > 0) ajouter(oNappe.designation, surfNappe, oNappe.designation.replace(/\s*\([^)]*\)/g, ''), { nombre: '1', cote1: surfNappe.toFixed(2), cote2: '1', src: avecReleve ? 'Murs de soubassement + 0,60 m de relevé' : 'Murs de soubassement' }, null);
  // Seuils de porte : même procédure que les appuis. Les murs cochés « Seuil de porte compris » donnent leur seuil à toutes les portes du projet.
  // Une ligne par type de seuil, unité = nombre de portes.
  const seuilsChoisis = [...new Set((p.murs || []).filter(m => !['soub', 'pignon'].includes(m.cat || 'peri') && m.seuil === true && m.liste_seuil).map(m => m.liste_seuil))];
  if (seuilsChoisis.length > 1) manquants.push('seuils de porte : un seul seuil par projet, plusieurs choisis dans les murs');
  if (seuilsChoisis.length === 1) {
    const oS = BIB.ouvrages.find(x => x.id === seuilsChoisis[0]);
    const nPortes = piecesNvDe(c).reduce((a, pc) => a + nbPortesNv(pc), 0);
    if (!oS) manquants.push('seuil de porte');
    else if (nPortes > 0) ajouter(oS.designation, nPortes, oS.designation.replace(/\s*\([^)]*\)/g, ''), { nombre: String(nPortes) }, null);
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
    const nouv = { uid: uid(), lot: o.lot, ouvrage: o.id, designation: o.designation, unite: o.unite,
             valeurs: vals, quantite: q, surface, cree: new Date().toISOString(), qteAuto: memeValeur ? o.qte : undefined, lien: lienConfig || undefined };
    const remp = remplacementConfig(L, o, precedent);
    if (remp === false) { $('apercu').textContent = 'Non ajoutée : la ligne du configurateur est conservée.'; return; }
    if (remp) { nouv.uid = remp.uid; nouv.cree = remp.cree; delete nouv.qteAuto; nouv.repris = cleLigneConfig(remp); L[L.indexOf(remp)] = nouv; }
    else L.push(nouv);
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

// Ligne libre dans le métré : titre, unité et quantité saisis librement, sans passer par la bibliothèque
function ouvrirLigneLibre() {
  const lots = BIB.lots.map(l => `<option value="${esc(l.id)}" ${l.id === lotCourant ? 'selected' : ''}>${esc(l.nom)}</option>`).join('');
  $('sheet').innerHTML = `<h2 style="margin:0 0 4px;font-size:18px">Ligne libre</h2>
    <p class="muted">La ligne entre directement dans le métré. Elle n'est pas ajoutée à la bibliothèque.</p>
    <form id="fLigneLibre">
      <label for="ll_des">Titre</label><input id="ll_des" name="designation" required>
      <label for="ll_lot">Lot</label><select id="ll_lot" name="lot">${lots}</select>
      <label for="ll_unite">Unité (libre)</label><input id="ll_unite" name="unite" value="u">
      <label for="ll_qte">Quantité</label><input id="ll_qte" name="quantite" inputmode="decimal" required>
      <div class="row" style="margin-top:8px">
        <button type="button" class="btn sec" id="bAnnulerLL">Annuler</button>
        <button type="submit" class="btn">Ajouter au métré</button>
      </div>
    </form>`;
  const f = $('fLigneLibre');
  f.addEventListener('submit', e => {
    e.preventDefault();
    const q = Number(String(f.elements.quantite.value).trim().replace(',', '.'));
    if (!(q > 0)) { alert('La quantité doit être un nombre supérieur à 0.'); return; }
    const designation = f.elements.designation.value.trim();
    const unite = f.elements.unite.value.trim() || 'u';
    const lot = f.elements.lot.value;
    ajouterLotSiAbsent(courantId, lot);
    const L = lignesDe(courantId);
    L.push({ uid: uid(), lot, ouvrage: null, designation, unite, valeurs: { nombre: String(q) }, quantite: q, surface: null, libre: true, ligneLibre: true, cree: new Date().toISOString() });
    sauverLignes(courantId, L);
    renderMetre();
    fermer();
  });
  $('bAnnulerLL').onclick = () => fermer();
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
// Barre d'avancement de la synchronisation (visible pendant l'envoi et la réception)
// Envoi = 0 à 50 %, réception = 50 à 100 %. Actif seulement pendant « Synchroniser les chantiers ».
let syncEnCours = false;
function syncAvance(pct, libelle) {
  const b = $('syncBarre'), r = $('syncRempli');
  if (b) b.hidden = false;
  if (r) r.style.width = Math.round(pct) + '%';
  syncStatut(libelle + ' ' + Math.round(pct) + ' %');
}
function syncFinBarre() { const b = $('syncBarre'); if (b) b.hidden = true; }
function syncStatut(texte) { const e = $('syncStatut'); if (e) { e.style.whiteSpace = 'pre-line'; e.textContent = texte; } }
function syncConfigOk() { return !!(lsGet('url', '') && lsGet('jeton', '')); }

// Appelé après chaque modification d'un chantier ou de ses lignes : envoi rapide
function marquerChantier(id) {
  const x = syncLire();
  x[id] = Object.assign({}, x[id], { modifie: true });
  syncEcrire(x);
  clearTimeout(marquerChantier.t);
  marquerChantier.t = setTimeout(envoyerChantiers, 3000);
}

async function envoyerChantiers(msgs) {
  const explicite = !!syncManuelle;   // lancé par un bouton « Synchroniser » ; jamais à l'ouverture de l'application
  const affiche = !msgs; msgs = msgs || [];
  if (!syncConfigOk()) { if (affiche) syncStatut('Renseignez l\'adresse du script et le jeton dans Réglages.'); return; }
  const x = syncLire();
  for (const c of chantiers) if (!x[c.id] && !c.supprime) x[c.id] = { modifie: true };   // anciens chantiers : envoyés une fois ; supprimés : jamais envoyés
  const heure = () => new Date().toLocaleTimeString('fr-FR', { hour: '2-digit', minute: '2-digit' });
  const idsSync = Object.keys(x); let fait = 0;
  syncReq.libelle = 'Envoi des modifications';
  for (const id of idsSync) {
    fait++;
    const c = chantiers.find(y => y.id === id);
    if (!c) { if (x[id].modifie) delete x[id]; continue; }
    // Chantier supprimé : sa version « supprimée » est envoyée une seule fois, sans contrôle de conflit
    if (c.supprime) {
      if (x[id].supprimeEnvoye && !x[id].modifie) continue;
      try {
        const j = await post({ action: 'sauver_chantier', chantier: Object.assign({}, c, { lignes: [] }), base_maj: null });
        if (j.ok) x[id] = { maj: j.maj, modifie: false, supprimeEnvoye: true };
      } catch (e) { syncEcrire(x); msgs.push('Pas de réseau : envoi différé'); if (affiche) syncStatut(msgs.join('\n')); return; }
      continue;
    }
    if (!x[id].modifie) continue;
    const doc = Object.assign({}, c, { lignes: lignesDe(id) });
    try {
      const j = await post({ action: 'sauver_chantier', chantier: doc, base_maj: x[id].maj || null });
      if (j.ok) { x[id] = { maj: j.maj, modifie: false }; msgs.push(c.nom + ' : envoyé à ' + heure()); }
      else if (j.conflit) {
        // Conflit : seulement sur demande explicite, l'utilisateur choisit de garder la version du téléphone
        if (explicite && confirm('Drive a une autre version de « ' + c.nom + ' ».\n\nGarder la version de ce téléphone et l\'envoyer sur Drive à la place ?')) {
          const j2 = await post({ action: 'sauver_chantier', chantier: doc, base_maj: null });
          if (j2.ok) { x[id] = { maj: j2.maj, modifie: false }; msgs.push(c.nom + ' : envoyé à ' + heure() + ' (version du téléphone gardée)'); }
          else msgs.push(c.nom + ' : refus (' + (j2.erreur || 'réponse inattendue') + ')');
        } else if (explicite && confirm('Reprendre la version de Drive sur ce téléphone, à la place de la version du téléphone ?\n\nOK : version de Drive.\nAnnuler : ne rien changer.')) {
          // Reprise de la version Drive : elle remplace celle du téléphone (lignes comprises)
          const j3 = await post({ action: 'lire_chantier', id });
          if (j3.ok && j3.chantier) {
            const { lignes: lignesDrive, ...metaDrive } = j3.chantier;
            const i = chantiers.findIndex(y => y.id === id);
            if (i >= 0) chantiers[i] = metaDrive; else chantiers.push(metaDrive);
            lsSet('lignes.' + id, metaDrive.supprime ? [] : alignerFondations(lignesDrive || []));
            lsSet('chantiers', chantiers);
            x[id] = { maj: j3.chantier.maj, modifie: false };
            msgs.push(c.nom + ' : version de Drive reprise sur ce téléphone');
          } else msgs.push(c.nom + ' : refus (' + (j3.erreur || 'lecture impossible') + ')');
        } else { x[id].conflit = true; msgs.push(c.nom + ' : conflit (modifié ailleurs)'); }
      }
      else msgs.push(c.nom + ' : refus (' + (j.erreur || 'réponse inattendue') + ')');
    } catch (e) { syncEcrire(x); msgs.push(c.nom + ' : pas de réseau, envoi différé'); if (affiche) syncStatut(msgs.join('\n')); return; }
  }
  syncEcrire(x);
  if (affiche) syncStatut(msgs.length ? msgs.join('\n') : 'Rien à envoyer : tous les chantiers sont à jour.');
}

// Récupère les chantiers modifiés sur un autre appareil (sans écraser les modifications non envoyées)
async function recupererChantiers(msgs) {
  const affiche = !msgs; msgs = msgs || [];
  if (!syncConfigOk()) return;
  syncReq.libelle = 'Interrogation de Drive';
  const liste = await post({ action: 'lister_chantiers' });
  if (!liste.ok) { msgs.push('Refus du script : ' + (liste.erreur || 'erreur inconnue')); if (affiche) syncStatut(msgs.join(' · ')); return; }
  const x = syncLire();
  let recus = 0;
  let vus = 0;
  for (const item of liste.chantiers) {
    const id = item.id;
    vus++; syncReq.libelle = 'Réception des chantiers';
    // Chantier modifié ici et pas encore envoyé : on le garde, sauf si l'autre appareil l'a supprimé
    const j = await post({ action: 'lire_chantier', id });
    const doc = j.ok ? j.chantier : null;
    if (!doc || (x[id] && x[id].maj === doc.maj)) continue;
    if (x[id] && x[id].modifie && !doc.supprime) continue;
    const { lignes, ...meta } = doc;
    const i = chantiers.findIndex(c => c.id === id);
    if (i >= 0) chantiers[i] = meta; else chantiers.push(meta);
    lsSet('lignes.' + id, doc.supprime ? [] : alignerFondations(lignes || []));
    x[id] = { maj: doc.maj, modifie: false, supprimeEnvoye: doc.supprime ? true : undefined };
    recus++;
    if (!doc.supprime) msgs.push((meta.nom || id) + ' : reçu de Drive');
    else msgs.push((meta.nom || id) + ' : supprimé sur un autre appareil, retiré ici');
  }
  lsSet('chantiers', chantiers);
  syncEcrire(x);
  if (recus) renderChantiers();
  if (affiche) syncStatut(msgs.length ? msgs.join('\n') : 'Chantiers à jour');
}

let syncManuelle = false;   // vrai seulement pendant un clic sur « Synchroniser »
let syncReq = { fait: 0, total: 1 };   // compteur de requêtes pour la barre d'avancement
async function synchroniserChantiers(manuelle = false) {
  if (!syncConfigOk()) { if (manuelle) syncStatut('Renseignez l\'adresse du script et le jeton dans Réglages.'); return; }
  const msgs = [];
  syncManuelle = !!manuelle;
  syncEnCours = true;
  syncReq = { fait: 0, total: Object.keys(syncLire()).length + 2 };
  if (manuelle) syncAvance(0, 'Démarrage…');
  try {
    await envoyerChantiers(msgs); await recupererChantiers(msgs);
    // Un état pour chaque chantier affiché (les chantiers supprimés ne sont pas affichés)
    const affiches = chantiers.filter(c => !c.supprime);
    const etat = c => msgs.find(m => m.startsWith(c.nom + ' : ') || m.startsWith(c.nom + ' : pas de réseau')) || (c.nom + ' : à jour');
    const globaux = msgs.filter(m => !affiches.some(c => m.startsWith(c.nom + ' :')));
    if (manuelle) syncStatut([...globaux, ...affiches.map(etat)].join('\n'));
  } catch (e) { if (manuelle) syncStatut('Synchronisation impossible pour le moment (réseau).'); }
  finally {
    syncEnCours = false; syncManuelle = false;
    // Barre pleine, puis disparition : le texte des résultats n'est pas modifié
    if (manuelle) { const r = $('syncRempli'); if (r) r.style.width = '100%'; setTimeout(syncFinBarre, 1500); }
  }
}

// Bouton « Synchroniser les chantiers » sur la liste des chantiers
function preparerSynchro() {
  if (PAGE === 'tableau' || $('btnSynchro') || !$('listeChantiers')) return;   // la page du métré a sa propre barre (identifiants uniques)
  $('listeChantiers').insertAdjacentHTML('beforebegin', `<div class="row" style="margin-bottom:12px;align-items:center">
    <button class="btn sec small" id="btnSynchro" style="flex:0 0 auto">Synchroniser les chantiers</button>
    <div id="syncBarre" hidden style="width:180px;height:14px;background:var(--line);border-radius:6px;overflow:hidden;flex:0 0 auto"><div id="syncRempli" style="height:100%;width:0;background:var(--ok);transition:width .3s"></div></div>
    <span class="muted" id="syncStatut"></span></div>`);
  $('btnSynchro').onclick = () => synchroniserChantiers(true);
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
$('ongletSaisie2').onclick = () => route('metre');
$('ongletTableau2').onclick = () => route('tableau');

$('selLot').onchange = e => { lotCourant = e.target.value; colorerLot(); renderLotMenuSaisie(); renderOuvrages(); };
$('recherche').oninput = renderOuvrages;

$('listeOuvrages').addEventListener('click', e => {
  if (e.target.closest('#bLibre2')) { ouvrirModal(); ouvrirLibre(); return; }
  if (e.target.closest('#bLigneLibre')) { ouvrirModal(); ouvrirLigneLibre(); return; }
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
               quantite: l.quantite, detail: detail(l), detailHtml: detailHtml(l), desc: ((BIB.ouvrages.find(x => x.id === l.ouvrage) || {}).detail || ''), pu, montant, titres: [] };
    })
  }));
  // Sous-titres calculés comme à l'écran (même fonction)
  for (const lot of lots) {
    const ls = L.filter(l => l.lot === lot.id);
    const tt = titresAvantLignes(lot.id, ls);
    lot.lignes.forEach((ligne, k) => { ligne.titres = tt[k]; });
  }
  return { titre: c.nom, client: c.client || null, date: new Date().toLocaleDateString('fr-FR'), lots,
           avecPrix, total };
}

function htmlImpression(d, logo, pg) {
  const cl = d.client || {};
  const ligne = (label, val) => val ? `<tr><th class="k">${esc(label)}</th><td>${esc(val)}</td></tr>` : '';
  const surf = cl.surf ? `${cl.surf} m²` : '';
  let corps = '';
  const nc = d.avecPrix ? 7 : 5;
  for (const [iLot, lot] of d.lots.entries()) {
    if (iLot > 0) corps += `<tr class="lot-sep"><td colspan="${nc}"></td></tr>`;
    corps += `<tr class="lot"><td colspan="${nc}">${esc(lot.num)} · ${esc(lot.nom)}${lot.lignes.length ? '' : ' <span class="vide">(aucune ligne)</span>'}</td></tr>`;
    if (lot.gen) corps += `<tr class="gen"><td colspan="${nc}">${genHtml(lot.gen.id, lot.gen.num)}</td></tr>`;
    { const rc = recapCharpenteHtml(lot.id); if (rc) corps += `<tr class="gen"><td colspan="${nc}">${rc}</td></tr>`; }
    for (const l of lot.lignes) {
      for (const t of l.titres) corps += `<tr class="st"><td colspan="${nc}">${esc(t)}</td></tr>`;
      corps += `<tr><td class="n">${esc(l.num)}</td><td>${esc(l.designation)}${l.desc ? `<div class="desc" style="font-style:italic;font-size:11px;color:#6b7280;margin-top:3px">${esc(l.desc)}</div>` : ''}</td>
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
  table.metre tr.lot td { background: #E07838; color: #fff; font-weight: 700; font-size: 10.5pt; text-transform: uppercase; letter-spacing: .02em; padding: 2.5mm 2mm; border-top: 1.2mm solid #8a3f12; border-bottom: none; }
  table.metre tr.lot td .vide { color: #fff; opacity: .85; text-transform: none; }
  table.metre tr.lot-sep td { height: 7mm; padding: 0; border: none; background: #fff; }
  table.metre tr.lot { page-break-after: avoid; }
  table.metre tr { page-break-inside: avoid; }
  table.metre tr.gen { page-break-inside: auto; }
  table.metre tr.gen td { background: #fbfbfb; border-bottom: none; padding: 2mm 2mm 3mm; font-size: 8.5pt; }
  table.metre tr.st td { background: #f3f6f9; font-weight: 600; padding-top: 3mm; border-bottom: none; }
  .gen-titre { color: #E07838; font-weight: 700; font-size: 9pt; margin-bottom: 1.5mm; }
  .gen-sec { margin: 0 0 2mm; }
  .gen-s { color: #2b2b2b; margin-bottom: 0.5mm; }
  .gen-sec ul { margin: 0; padding-left: 5mm; color: #4a4a4a; }
  .gen-sec li { margin: 0 0 0.5mm; }
  .vide { font-weight: 400; color: #8a8a8a; }
  h2.entete-metre { font-size: 13pt; color: #2b2b2b; margin: 0 0 4mm; }
  table.metre tr.st td { background: #f3f6f9; font-weight: 600; padding-top: 3mm; border-bottom: none; }
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
  ${etudeCouranteImpression()}
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
    const gen = (cdpgf ? genHtml(lot.id, lot.ordre) : '') + recapCharpenteHtml(lot.id);
    const lignes = lot.lignes.map(l => `${l.titres.map(t => `<tr class="st"><td colspan="${cdpgf ? 8 : 5}">${esc(t)}</td></tr>`).join('')}<tr>
        <td class="n">${esc(l.num)}</td><td>${esc(l.designation)}${l.desc ? `<div class="desc" style="font-style:italic;font-size:11px;color:#6b7280;margin-top:3px">${esc(l.desc)}</div>` : ''}</td>
        <td class="num">${fmt(l.quantite)}</td><td>${esc(l.unite)}</td><td class="det">${l.detailHtml}</td>
        ${cdpgf ? '<td class="vierge"></td><td class="vierge"></td><td class="vierge petit"></td>' : ''}</tr>`).join('');
    // Totaux : Total HT, puis trois lignes de TVA (un taux par ligne, car un projet peut mélanger plusieurs taux), puis Total TTC
    // Bloc aligné sur les colonnes P.U. HT, Montant HT et TVA % : libellé à gauche, montant dans la colonne Montant HT, taux dans la colonne TVA %
    const vide5 = '<td colspan="5" class="hors"></td>';
    const lignesTva = [1, 2, 3].map(n => `<tr class="tva">${vide5}<td class="lib">TVA ${n}</td><td class="case"></td><td class="case taux">…… %</td></tr>`).join('');
    const pied = cdpgf
      ? `<tfoot><tr class="esp"><td colspan="8"></td></tr>
        <tr class="tot">${vide5}<td class="lib">Total HT du lot</td><td class="case"></td><td class="hors"></td></tr>
        <tr class="entete-tva">${vide5}<td class="hors"></td><td class="mini">Montant de la TVA</td><td class="mini">Taux</td></tr>
        ${lignesTva}
        <tr class="esp"><td colspan="8"></td></tr>
        <tr class="ttc">${vide5}<td class="lib">Total TTC du lot</td><td class="case"></td><td class="hors"></td></tr></tfoot>`
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
  table.metre tr.st td { background: #f3f6f9; font-weight: 600; padding-top: 3mm; border-bottom: none; }
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
  table.metre tfoot td { border: none; background: #fff; }
  table.metre tfoot tr.esp td { height: 5mm; padding: 0; }
  table.metre tfoot td.lib { text-align: right; font-weight: 600; padding: 2mm 3mm 2mm 2mm; vertical-align: middle; white-space: nowrap; }
  table.metre tfoot td.case { border: 1px solid #6b6b6b; height: 8mm; min-width: 22mm; vertical-align: middle; }
  table.metre tfoot td.taux { text-align: right; color: #8a8a8a; font-size: 8pt; padding-right: 2mm; }
  table.metre tfoot td.mini { font-size: 7pt; color: #6b6b6b; text-align: center; padding: 2.5mm 0 0.5mm; }
  table.metre tfoot tr.tva td.case { border-top-width: 0; }
  table.metre tfoot tr.entete-tva + tr.tva td.case { border-top-width: 1px; }
  table.metre tfoot tr.tot td.lib, table.metre tfoot tr.ttc td.lib { font-weight: 700; font-size: 10pt; }
  table.metre tfoot tr.tot td.case, table.metre tfoot tr.ttc td.case { border: 2px solid #E07838; height: 9mm; }
  table.metre tfoot tr.esp td { height: 3mm; }
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

  // ---- Page 1 : mode d'emploi (sur sa propre page, avant la page de garde) ----
  nouvellePage();
  contexteTable = false;
  y -= 26;
  ecrire("Mode d'emploi", M, y, 16, helvB, ORANGE);
  y -= 26;
  ligne("ATTENTION : lisez ceci avant de remplir le fichier. Ce fichier ne fonctionne que dans Google Chrome. Dans Adobe ou dans un autre logiciel, les montants ne se calculent pas.", M, LARG, 9, helv, NOIR);
  ligne("1. Fermez ce fichier (fermez la fenêtre du logiciel qui l'a ouvert).", M, LARG, 9, helv, NOIR);
  ligne("2. Allez dans le dossier où le fichier est enregistré (par exemple « Téléchargements »).", M, LARG, 9, helv, NOIR);
  ligne("3. Faites un clic droit sur le fichier.", M, LARG, 9, helv, NOIR);
  ligne("4. Cliquez sur « Ouvrir avec ».", M, LARG, 9, helv, NOIR);
  ligne("5. Cliquez sur « Google Chrome ». Si Chrome n'apparaît pas, cliquez sur « Rechercher une autre application » ou « Choisir une autre application », puis sélectionnez Google Chrome.", M, LARG, 9, helv, NOIR);
  ligne("6. Vérifiez que le fichier s'affiche bien dans Google Chrome.", M, LARG, 9, helv, NOIR);
  ligne("7. Remplissez seulement les cases « P.U. HT » et « TVA % » de chaque ligne. Les quantités sont déjà fixées.", M, LARG, 9, helv, NOIR);
  ligne("8. Après chaque prix saisi, vérifiez que « Montant HT » se remplit.", M, LARG, 9, helv, NOIR);
  ligne("9. En bas de chaque lot, vérifiez que les totaux HT, TVA et TTC s'affichent.", M, LARG, 9, helv, NOIR);
  ligne("10. Pour garder votre saisie : cliquez sur l'icône Télécharger (flèche en haut à droite de Chrome), puis rouvrez le fichier téléchargé dans Chrome et vérifiez que vos prix sont bien là.", M, LARG, 9, helv, NOIR);
  // Aide visuelle pour l'étape 10 : capture du bandeau Chrome (fichier aide-telechargement-chrome.png, à côté de l'application)
  try {
    const aide = await doc.embedPng(await (await fetch(new URL('aide-telechargement-chrome.png', location.href).href, { cache: 'no-cache' })).arrayBuffer());
    const sAide = aide.scaleToFit(LARG, 60);
    if (y - sAide.height - 8 < BAS) nouvellePage();
    y -= sAide.height + 6;
    page.drawImage(aide, { x: M, y, width: sAide.width, height: sAide.height });
    y -= 8;
    // Zoom sur la flèche de téléchargement (fichier aide-telechargement-chrome-zoom.png)
    const zoom = await doc.embedPng(await (await fetch(new URL('aide-telechargement-chrome-zoom.png', location.href).href, { cache: 'no-cache' })).arrayBuffer());
    const sZoom = zoom.scaleToFit(LARG * 0.5, 110);
    if (y - sZoom.height - 8 < BAS) nouvellePage();
    y -= sZoom.height + 6;
    page.drawImage(zoom, { x: M, y, width: sZoom.width, height: sZoom.height });
    y -= 8;
  } catch (e) { /* image absente : le texte de l'étape 10 suffit */ }
  ligne('Les taux de TVA du lot (TVA 1, 2 et 3) sont affichés en haut de chaque lot : ils sont repris automatiquement de la colonne « TVA % ».', M, LARG, 9, helv, NOIR);

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
        for (const sct of sectionsDuLot(lot.id)) {
          ligne(sct.titre, M, LARG, 8, helvB, NOIR);
          for (const p of sct.points) ligne('• ' + p, M + 8, LARG - 8, 7.6, helv, GRIS);
        }
        y -= 6;
      }
    }
    const recapP = recapCharpente(lot.id);
    if (recapP.length) {
      ligne('Récapitulatif pour le calcul de charpente', M, LARG, 9, helvB, ORANGE);
      for (const g of recapP) {
        ligne(g.titre, M, LARG, 8, helvB, g.site ? ORANGE : NOIR);
        for (const [a, v] of g.lignes) ligne('• ' + a + ' : ' + v, M + 8, LARG - 8, 7.6, helv, GRIS);
      }
      y -= 6;
    }
    enteteTable();
    const noms = [];
    lot.lignes.forEach((l, i) => {
      for (const t of l.titres) {
        if (y - 18 < BAS) { nouvellePage(); enteteTable(); }
        page.drawRectangle({ x: M, y: y - 16, width: LARG, height: 16, color: GRIS_CLAIR });
        ecrire(t, M + 4, y - 11, 8.5, helvB, NOIR);
        y -= 16;
      }
      const des = decoupeTexte(l.designation, helvB, 8.5, C.des - 8);
      const det = [...(l.detail ? decoupeTexte(l.detail, helv, 7.2, C.des - 8) : []), ...(l.desc ? decoupeTexte(l.desc, helv, 7.2, C.des - 8) : [])];
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
    ligne('Indiquez les prix unitaires HT et le taux de TVA de chaque ligne. Les montants et les totaux se calculent automatiquement dans Google Chrome (voir le mode d\'emploi, page de garde).', M, LARG, 7.5, helv, GRIS);
  });

  // Pied de page : numéro de page et rappel du logiciel
  const pages = doc.getPages();
  pages.forEach((p, i) => {
    p.drawText(texteFormulaire(`Page ${i + 1} / ${pages.length} · Calculs : ouvrir ce fichier avec Google Chrome`), { x: M, y: 24, size: 6.8, font: helv, color: GRIS });
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
  const lignesLot = [], lignesLigne = [], lignesTitre = [];
  for (const lot of d.lots) {
    lignesLot.push(m.length);
    m.push([lot.num + ' · ' + lot.nom, '', '', '', lot.lignes.length ? '' : '(aucune ligne)', ...(avecPrix ? [''] : []), ...(avecPrix ? [''] : [])].slice(0, nc));
    for (const l of lot.lignes) {
      for (const t of l.titres) { lignesTitre.push(m.length); m.push(['', t, '', '', '', ...(avecPrix ? ['', ''] : [])]); }
      lignesLigne.push(m.length);
      m.push([l.num, l.designation, l.quantite, l.unite, [l.desc, l.detail].filter(Boolean).join(' — '), ...(avecPrix ? [l.pu ?? '', l.montant ?? ''] : [])]);
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
  for (const r of lignesTitre) for (const c of lettres) style(ws2, c + (r + 1), { font: { bold: true }, fill: { fgColor: { rgb: 'F3F6F9' } } });
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
  reprendreListes();
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

// Envoi sur Drive. Si la bibliothèque de l'appareil a moins d'ouvrages que le Drive,
// on demande confirmation (suppressions voulues) puis on renvoie avec l'accord.
async function envoyerBibliotheque() {
  let j = await post({ action: 'sauver_bibliotheque', bibliotheque: BIB });
  if (!j.ok && j.reduction) {
    const ok = confirm('Le Drive contient ' + j.reduction + ' ouvrage(s) de plus que cette bibliothèque. Ces ouvrages seront supprimés sur le Drive. Confirmer ?');
    if (!ok) return { ok: false, erreur: 'envoi annulé, rien n\'a été modifié sur le Drive' };
    j = await post({ action: 'sauver_bibliotheque', bibliotheque: BIB, confirmer_reduction: true });
  }
  return j;
}

$('btnEnvoiBib').onclick = async () => {
  if (!lsGet('url', '') || !lsGet('jeton', '')) { alert("Enregistrez d'abord l'adresse et le jeton."); return; }
  try {
    const j = await envoyerBibliotheque();
    alert(j.ok ? 'Bibliothèque envoyée sur Drive.' : 'Refus : ' + (j.erreur || 'erreur inconnue'));
  } catch (e) { alert('Envoi impossible pour le moment (réseau).'); }
};

/* ============ Bibliothèque : modifier les ouvrages et leurs prix ============ */
// Ouvrage utilisable (listes, pickers, configurateur) : ni supprimé, ni archivé (déclaration de fonction : utilisable dès le chargement)
function ouvActif(o) { return !o.supprime && !o.archive; }
// Dallages et planchers saisis dans le configurateur (OUV-1748 à OUV-1759), non archivés
function plancherNvOuvrages() { return BIB ? BIB.ouvrages.filter(o => ouvActif(o) && /^OUV-17(4[89]|5\d)$/.test(o.id)) : []; }
const ouvragesLibres = () => BIB.ouvrages.filter(o => ouvActif(o));   // supprimés et archivés n'apparaissent plus
function champsBib(unite) { return champsLibre(unite).map(c => ({ cle: c.cle, libelle: c.libelle })); }
const aujourdhui = () => new Date().toLocaleDateString('fr-FR');

// Liste des lots de la bibliothèque : noms en majuscules, un lot sur deux en texte orange
function optionsLotsBiblio() {
  const opts = BIB.lots.map((l, i) => {
    const couleur = i % 2 === 0 ? 'color:#E07838;font-weight:700' : '';
    return `<option value="${esc(l.id)}" style="${couleur}">${esc(String(l.nom).toUpperCase())}</option>`;
  }).join('');
  return '<option value="">TOUS LES LOTS</option>' + opts;
}
// Liste déroulante maison du choix de lot (s'ouvre au toucher, couleurs visibles sur téléphone)
function renderLotMenu() {
  const id = $('biblioLot').value;
  const lot = BIB.lots.find(l => l.id === id);
  $('biblioLotTexte').textContent = lot ? String(lot.nom).toUpperCase() : 'TOUS LES LOTS';
  const bouton = $('biblioLotBouton');   // lot choisi : case bleue, texte blanc
  bouton.style.background = lot ? '#2F6FB0' : '';
  bouton.style.borderColor = lot ? '#2F6FB0' : '';
  bouton.style.color = lot ? '#fff' : '';
  bouton.style.fontWeight = lot ? '700' : '';
  const item = (valeur, texte, couleur, actif) =>
    `<button type="button" data-lot-valeur="${esc(valeur)}" style="display:block;width:100%;text-align:left;padding:12px;min-height:44px;border:0;border-bottom:1px solid var(--line);background:${actif ? 'var(--line)' : 'transparent'};color:${couleur};font-weight:${couleur === 'var(--fg)' ? '400' : '700'};font-size:16px;cursor:pointer">${esc(texte)}</button>`;
  let h = item('', 'TOUS LES LOTS', 'var(--fg)', id === '');
  BIB.lots.forEach((l, i) => {
    h += item(l.id, String(l.nom).toUpperCase(), i % 2 === 0 ? '#E07838' : 'var(--fg)', id === l.id);
  });
  $('biblioLotListe').innerHTML = h;
}
$('biblioLotBouton').onclick = () => {
  renderLotMenu();
  $('biblioLotListe').classList.toggle('hidden');
};
$('biblioLotListe').addEventListener('click', e => {
  const b = e.target.closest('[data-lot-valeur]');
  if (!b) return;
  $('biblioLot').value = b.dataset.lotValeur;
  $('biblioLotListe').classList.add('hidden');
  renderLotMenu();
  renderBiblio();
});
function ouvrirBiblio() {
  $('titre').textContent = 'Bibliothèque de métré';
  $('biblioEntete').style.top = document.querySelector('header').offsetHeight + 'px';   // le bloc du haut reste visible en faisant défiler
  $('biblioLot').innerHTML = optionsLotsBiblio();
  renderLotMenu();
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
  // Ouvrages archivés (non supprimés, masqués des listes) : restaurables
  const archives = BIB.ouvrages.filter(o => o.archive && !o.supprime && (!lot || o.lot === lot));
  if (archives.length) {
    $('biblioListe').innerHTML += `<details style="padding:0 12px 12px"><summary class="muted">Archivés (${archives.length})</summary>` +
      archives.map(o => `<div class="ouv" style="padding:8px 0"><span>${esc(o.designation)}</span>
        <button class="btn small sec" data-desarchiver="${esc(o.id)}">Désarchiver</button></div>`).join('') + `</details>`;
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
      <textarea id="b_rappel" name="rappel" rows="3" placeholder="ex. Longueur du mur × hauteur sous plafond, déduire les ouvertures ≥ 1 m²" style="width:100%;padding:10px;border:1px solid var(--line);border-radius:8px;background:var(--card);color:var(--fg);font:inherit">${esc(v.rappel || '')}</textarea>
      <label for="b_detail">Détail (texte affiché sous le titre de l'ouvrage dans le métré)</label><textarea id="b_detail" name="detail" rows="6" style="width:100%;padding:10px;border:1px solid var(--line);border-radius:8px;background:var(--card);color:var(--fg);font:inherit">${esc(v.detail || '')}</textarea>
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
  const detail = f.elements.detail ? f.elements.detail.value.trim() : '';
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
    if (detail) o.detail = detail; else delete o.detail;
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
    if (detail) o.detail = detail;
    if (lie) o.liePar = lie;
    if (lieConf) o.lieConfig = lieConf;
    if (Object.keys(COTES_EDIT).length) o.cotes = JSON.parse(JSON.stringify(COTES_EDIT));
    if (prix) o.prix_indicatif = prix;
    BIB.ouvrages.push(o);
  }
  sauverBibliotheque();
}

// Enregistre tout de suite sur l'appareil, puis envoie sur Drive en arrière-plan
async function sauverBibliotheque() {
  lsSet('bib', BIB);
  lsSet('bib_modifiee', true);
  const statut = $('biblioStatut');
  const sansDrive = !lsGet('url', '') || !lsGet('jeton', '');
  fermer();
  statut.textContent = sansDrive ? 'Enregistré sur cet appareil. Renseignez le script dans Réglages pour l\'envoyer sur Drive.' : 'Enregistré sur cet appareil. Envoi sur Drive en cours…';
  statut.classList.remove('hidden');
  renderBiblio();
  if (sansDrive) return;
  try {
    const j = await envoyerBibliotheque();
    if (j.ok) { lsSet('bib_modifiee', false); statut.textContent = 'Enregistré et envoyé sur Drive.'; }
    else statut.textContent = 'Drive a refusé l\'envoi : ' + (j.erreur || 'erreur inconnue') + '. Enregistré sur cet appareil.';
  } catch (e) {
    statut.textContent = 'Pas de réseau : enregistré sur cet appareil, il sera envoyé plus tard.';
  }
}

$('btnBiblio').onclick = ouvrirBiblio;
$('biblioLot').onchange = renderBiblio;
$('biblioRecherche').oninput = renderBiblio;
$('btnBiblioNouveau').onclick = () => { ouvrirModal(); formulaireOuvrage(null, $('biblioLot').value); };
// Renommer le lot choisi : seul le nom change, l'identifiant du lot reste le même (les ouvrages restent reliés)
$('btnRenommerLot').onclick = async () => {
  const id = $('biblioLot').value;
  if (!id) { alert('Choisissez d\'abord un lot dans la liste.'); return; }
  const lot = BIB.lots.find(l => l.id === id);
  if (!lot) return;
  const saisi = prompt('Nouveau nom du lot :', lot.nom);
  if (saisi === null) return;
  const nom = saisi.trim();
  if (!nom || nom === lot.nom) return;
  lot.nom = nom;
  await sauverBibliotheque();   // enregistre sur cet appareil et envoie sur Drive
  const choisi = $('biblioLot').value;   // met à jour la liste des lots, sans effacer le message
  $('biblioLot').innerHTML = optionsLotsBiblio();
  $('biblioLot').value = choisi;
  renderLotMenu();
  remplirLots();
  renderBiblio();
};
$('biblioListe').addEventListener('click', e => {
  const d = e.target.closest('[data-desarchiver]');
  if (d) {
    const o = BIB.ouvrages.find(x => x.id === d.dataset.desarchiver);
    if (o) { delete o.archive; o.version = (o.version || 1) + 1; sauverBibliotheque(); renderBiblio(); }
    return;
  }
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

/* ============ Mise à jour de la fiche métré ============ */
// Appelée dès que le configurateur ou la bibliothèque change, et quand on revient sur la fiche métré
function actualiserMetre() {
  if (PAGE !== 'tableau' || !courantId || !BIB || _revueCollecte) return;
  renderMetre();
}
document.addEventListener('visibilitychange', () => { if (!document.hidden) actualiserMetre(); });
window.addEventListener('focus', actualiserMetre);

/* ============ Synchro entre les deux fenêtres ============ */
window.addEventListener('storage', e => {
  if (!e.key || !e.key.startsWith(LS)) return;
  chantiers = lsGet('chantiers', []);
  // Seule la fenêtre « tableau » suit le chantier choisi dans l'autre fenêtre.
  // La fenêtre principale garde le sien : son configurateur ne doit jamais écrire dans un autre chantier.
  if (PAGE === 'tableau') courantId = lsGet('courant', courantId);
  if (PAGE === 'tableau' && e.key === LS + 'courant' && courantId) { ouvrirChantier(courantId); return; }
  if (PAGE === 'tableau') renderMetre();
  compterLignes();
});

// Hauteur de l'en-tête (il peut passer sur deux lignes) : la barre du configurateur se fige juste en dessous
function majHauteurEntete() {
  const h = document.querySelector('header');
  if (h) document.documentElement.style.setProperty('--hdr-h', h.offsetHeight + 'px');
}
window.addEventListener('resize', majHauteurEntete);
if (window.ResizeObserver && document.querySelector('header')) new ResizeObserver(majHauteurEntete).observe(document.querySelector('header'));
majHauteurEntete();
/* ============ Démarrage ============ */
// Remise à zéro unique du chantier « test Claude » : toutes ses lignes sont effacées, le chantier est gardé
function remiseAZeroTestClaude() {
  if (lsGet('remise_test_claude_v166', false)) return;
  const c = chantiers.find(x => !x.supprime && String(x.nom || '').trim().toLowerCase() === 'test claude');
  if (!c) return;
  sauverLignes(c.id, []);
  lsSet('remise_test_claude_v166', true);
}
(async function init() {
  await chargerBibliotheque();
  if (!BIB) { document.body.insertAdjacentHTML('beforeend', '<p class="muted" style="padding:16px">Bibliothèque introuvable.</p>'); return; }
  lotCourant = BIB.lots[0].id;
  remplirLots();
  remiseAZeroTestClaude();
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
  reprendreListes();
  preparerSynchro();
  preparerTaillePG();
  synchroniserChantiers(false);   // à l'ouverture : silencieux, aucune boîte de conflit
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

/* Mode clair / sombre (bureau) : choix mémorisé sur cet appareil ; sans choix, on suit le réglage de l'ordinateur */
(function () {
  const CLE = 'metre2m.theme';
  function appliquer(theme) {
    document.documentElement.dataset.theme = theme;
    const b = document.getElementById('btnTheme');
    if (b) b.textContent = theme === 'dark' ? '☀ Mode clair' : '☾ Mode sombre';
  }
  let theme = null;
  try { theme = localStorage.getItem(CLE); } catch (e) { /* mode privé : pas de mémoire */ }
  if (theme !== 'dark' && theme !== 'light') theme = matchMedia('(prefers-color-scheme: dark)').matches ? 'dark' : 'light';
  appliquer(theme);
  document.addEventListener('click', e => {
    if (!e.target.closest('#btnTheme')) return;
    const suivant = document.documentElement.dataset.theme === 'dark' ? 'light' : 'dark';
    try { localStorage.setItem(CLE, suivant); } catch (err) { /* pas de mémoire : le choix vaut pour cette fenêtre */ }
    appliquer(suivant);
  });
})();

/* ============ Import d'un plan PDF (étape 1 : lecture et vérification, sans écriture dans le configurateur) ============ */
let PLAN = null;   // { pieces: [{nom, surface}], menus: [{type, largeur, hauteur, piece}], total: '' }
let PLAN_VALIDE = null;   // copie du plan validé, en attente du choix : remise à zéro totale ou complément
const RE_SURF_PL = /^\d+[.,]\d{2}\s?m²$/;
const RE_MEN_PL = /(fen[eê]tre(?: coulissante| fixe)?|porte(?: fen[eê]tre| d.entr[ée]e)?|baie(?: coulissante)?)?\s*(\d{2,3})\s?[x×]\s?(\d{2,3})/gi;

function chargerPdfJs() {
  return new Promise((ok, ko) => {
    if (window.pdfjsLib) return ok(window.pdfjsLib);
    const s = document.querySelector('script[src*="pdf.min.js"]');
    if (!s) return ko(new Error('bibliothèque PDF absente'));
    s.addEventListener('load', () => ok(window.pdfjsLib));
    s.addEventListener('error', () => ko(new Error('bibliothèque PDF non chargée (réseau ?)')));
    if (window.pdfjsLib) ok(window.pdfjsLib);
  });
}

async function lirePlanPdf(fichier) {
  const lib = await chargerPdfJs();
  lib.GlobalWorkerOptions.workerSrc = 'https://cdnjs.cloudflare.com/ajax/libs/pdf.js/3.11.174/pdf.worker.min.js';
  const pdf = await lib.getDocument({ data: await fichier.arrayBuffer() }).promise;
  const page = await pdf.getPage(1);
  const contenu = await page.getTextContent();
  const fr = contenu.items.filter(it => it.str && it.str.trim()).map(it => ({ x: it.transform[4], y: it.transform[5], s: it.str.trim() }));
  const surfaces = fr.filter(f => RE_SURF_PL.test(f.s) && !/zone/i.test(f.s));
  const labels = fr.filter(f => !RE_SURF_PL.test(f.s) && !/\d+\s?[x×]\s?\d+/i.test(f.s) && /[a-zA-Zé]/.test(f.s) && f.s.length > 2 && !/cm|m²|habitable|zone/i.test(f.s));
  const dist = (a, b) => Math.abs(a.x - b.x) + Math.abs(a.y - b.y);
  const pieces = surfaces.map(sf => {
    const c = labels.reduce((m, l) => (!m || dist(l, sf) < dist(m, sf) ? l : m), null);
    const loin = c && dist(c, sf) > 60;
    return { nom: loin ? 'TOTAL OU ZONE (à vérifier)' : (c ? c.s : '?'), surface: sf.s };
  });
  const menus = [];
  for (const f of fr) {
    for (const m of f.s.matchAll(RE_MEN_PL)) {
      const proche = surfaces.reduce((b, sf) => (!b || dist(sf, f) < dist(b, f) ? sf : b), null);
      const idx = proche ? surfaces.indexOf(proche) : -1;
      menus.push({ type: (m[1] || 'non précisé').trim(), largeur: m[2], hauteur: m[3], piece: idx >= 0 && pieces[idx] ? pieces[idx].nom : '?' });
    }
  }
  return { pieces, menus, total: '' };
}

function afficherPlan() {
  if (!PLAN) return;
  const ligne = (contenu) => `<div style="display:flex;gap:6px;align-items:center;margin-bottom:6px;flex-wrap:wrap">${contenu}</div>`;
  const champ = (cls, i, champ, val, w) => `<input data-pl="${cls}" data-i="${i}" data-c="${champ}" value="${esc(val)}" style="width:${w};min-height:38px">`;
  let h = '<strong>Pièces et surfaces</strong><div style="margin:8px 0">';
  h += ligne('<span class="muted" style="width:40%;font-size:12px">Nom de la pièce</span><span class="muted" style="width:18%;font-size:12px">Surface (m²)</span><span class="muted" style="width:18%;font-size:12px">Linéaire (ml)</span>');
  PLAN.pieces.forEach((p, i) => { h += ligne(champ('piece', i, 'nom', p.nom, '40%') + champ('piece', i, 'surface', p.surface, '18%') + champ('piece', i, 'lin', p.lin || '', '18%') + `<button type="button" class="btn small sec" data-pl-suppr="piece" data-i="${i}">Suppr.</button>`); });
  h += '<button type="button" class="btn small sec" data-pl-ajout="piece">+ Ajouter une pièce</button></div>';
  h += '<strong>Menuiseries</strong><div style="margin:8px 0">';
  PLAN.menus.forEach((m, i) => { h += ligne(champ('menu', i, 'type', m.type, '30%') + champ('menu', i, 'largeur', m.largeur, '12%') + ' x ' + champ('menu', i, 'hauteur', m.hauteur, '12%') + champ('menu', i, 'piece', m.piece, '30%') + `<button type="button" class="btn small sec" data-pl-suppr="menu" data-i="${i}">Suppr.</button>`); });
  h += '<button type="button" class="btn small sec" data-pl-ajout="menu">+ Ajouter une menuiserie</button></div>';
  h += `<label>Surface habitable indiquée sur le plan (m²)</label>` + champ('total', 0, 'valeur', PLAN.total, '40%');
  $('plTableau').innerHTML = h;
}

$('btnImportPlan').onclick = () => { route('import'); PLAN = null; PLAN_VALIDE = null; $('plChoix').classList.add('hidden'); $('plTableau').innerHTML = ''; $('plStatut').textContent = 'Choisissez un fichier PDF.'; };
$('btnPlAnnuler').onclick = () => { PLAN = null; PLAN_VALIDE = null; route('config'); };
$('plFichier').onchange = async e => {
  const f = e.target.files && e.target.files[0];
  if (!f) return;
  $('plStatut').textContent = 'Lecture du plan en cours…';
  try {
    PLAN = await lirePlanPdf(f);
    const tot = PLAN.pieces.find(p => /TOTAL/.test(p.nom));
    PLAN.total = tot ? tot.surface : '';
    PLAN.pieces = PLAN.pieces.filter(p => !/TOTAL/.test(p.nom));
    $('plStatut').textContent = `${PLAN.pieces.length} pièce(s) et ${PLAN.menus.length} menuiserie(s) trouvées. Vérifiez et corrigez avant de valider.`;
    afficherPlan();
  } catch (err) {
    $('plStatut').textContent = 'Lecture impossible : ' + (err.message || err);
  }
};
$('plTableau').addEventListener('input', e => {
  const c = e.target.dataset.c; if (!c || !PLAN) return;
  const i = Number(e.target.dataset.i);
  if (e.target.dataset.pl === 'piece') PLAN.pieces[i][c] = e.target.value;
  else if (e.target.dataset.pl === 'menu') PLAN.menus[i][c] = e.target.value;
  else if (e.target.dataset.pl === 'total') PLAN.total = e.target.value;
});
$('plTableau').addEventListener('click', e => {
  if (!PLAN) return;
  const ajout = e.target.closest('[data-pl-ajout]');
  if (ajout) {
    if (ajout.dataset.plAjout === 'piece') PLAN.pieces.push({ nom: '', surface: '', lin: '' });
    else PLAN.menus.push({ type: '', largeur: '', hauteur: '', piece: '' });
    afficherPlan(); return;
  }
  const suppr = e.target.closest('[data-pl-suppr]');
  if (suppr && confirm('Supprimer cette ligne du tableau ?')) {
    const i = Number(suppr.dataset.i);
    if (suppr.dataset.plSuppr === 'piece') PLAN.pieces.splice(i, 1); else PLAN.menus.splice(i, 1);
    afficherPlan();
  }
});
$('btnPlValider').onclick = () => {
  if (!PLAN) { alert('Importez d\'abord un plan.'); return; }
  const vides = PLAN.pieces.filter(p => !p.nom.trim() || !p.surface.trim()).length;
  if (vides && !confirm(vides + ' pièce(s) sans nom ou sans surface. Valider quand même ?')) return;
  lsSet('plan_valide', { date: new Date().toISOString(), ...PLAN });
  PLAN_VALIDE = JSON.parse(JSON.stringify(PLAN));
  PLAN = null;
  $('plTableau').innerHTML = '';
  $('plChoix').classList.remove('hidden');
  $('plStatut').textContent = `Plan validé : ${PLAN_VALIDE.pieces.length} pièce(s), ${PLAN_VALIDE.menus.length} menuiserie(s). Choisissez comment l'envoyer dans le configurateur. Rien n'est encore écrit.`;
};

/* ---- Envoi du plan validé dans le configurateur : deux choix ---- */
// Calcule ce qui serait écrit, sans rien modifier : retourne la nouvelle liste de pièces et le rapport
// Règle : une case déjà remplie n'est jamais écrasée ; une pièce ou une menuiserie déjà présente n'est pas dupliquée
function planEtat(liste, plan) {
  const L = JSON.parse(JSON.stringify(liste));
  const rap = { ajoutees: [], completees: [], menusAjoutes: [], conservees: [], aVerifier: [] };
  for (const pc of plan.pieces) {
    const nom = (pc.nom || '').trim(), surf = (pc.surface || '').trim(), lin = (pc.lin || '').trim();
    if (!nom) { rap.aVerifier.push('Pièce sans nom, rien n\'est écrit pour elle'); continue; }
    const libelle = nom;
    let p = L.find(x => ((x.nom || '') + (x.qualif ? ' ' + x.qualif : '')).trim().toLowerCase() === nom.toLowerCase());
    if (!typePieceNv(nom)) rap.aVerifier.push(`« ${nom} » : type de pièce non reconnu, les règles de calcul (appareillage, spots) ne s'appliqueront pas`);
    if (!p) {
      p = { id: 'pn' + uid(), nom, qualif: '', surf: '', perim: '', revet: '', menus: [], portes: '', app: {} };
      L.push(p);
      if (surf) p.surf = surf;
      if (lin) p.perim = lin;
      rap.ajoutees.push(libelle + (surf ? ' : ' + surf + ' m²' : '') + (lin ? ' · ' + lin + ' ml' : ''));
    } else if (!p.surf && surf) {
      p.surf = surf;
      rap.completees.push(libelle + ' : surface ' + surf + ' m²');
    } else if (p.surf && surf && num(p.surf) !== num(surf)) {
      rap.conservees.push(libelle + ' : surface déjà à ' + p.surf + ' m² (plan : ' + surf + ' m²), non modifiée');
    }
    if (lin && !p.perim) {
      p.perim = lin;
      rap.completees.push(libelle + ' : linéaire ' + lin + ' ml');
    } else if (lin && p.perim && num(p.perim) !== num(lin)) {
      rap.conservees.push(libelle + ' : linéaire déjà à ' + p.perim + ' ml (plan : ' + lin + ' ml), non modifié');
    }
    p.menus = p.menus || [];
    for (const m of plan.menus.filter(x => x.piece === nom)) {
      const lib = `${m.type} ${m.largeur} × ${m.hauteur} cm`;
      if (p.menus.some(x => num(x.l) === num(m.largeur) && num(x.h) === num(m.hauteur))) {
        rap.conservees.push(`${libelle} : ${lib} déjà présente, non ajoutée`);
        continue;
      }
      p.menus.push({ l: m.largeur, h: m.hauteur, nb: '1', ouv: '' });
      rap.menusAjoutes.push(`${libelle} : ${lib}`);
      if (!/^fen[eê]tre/i.test(m.type)) rap.aVerifier.push(`${libelle} : ${lib} ajoutée comme fenêtre, à changer dans le configurateur si c'est une porte ou une baie`);
    }
  }
  if (plan.total) rap.aVerifier.push(`Surface habitable du plan (${plan.total} m²) : aucune case du configurateur ne la reçoit, elle n'est pas reportée`);
  return { liste: L, rap };
}
function recapPlan(titre, rap) {
  const bloc = (t, l) => l.length ? '\n' + t + '\n' + l.map(x => '  - ' + x).join('\n') + '\n' : '';
  const corps = bloc('Pièces ajoutées :', rap.ajoutees) + bloc('Surfaces complétées (cases vides seulement) :', rap.completees)
    + bloc('Menuiseries ajoutées :', rap.menusAjoutes) + bloc('Déjà renseigné, non modifié :', rap.conservees) + bloc('À vérifier (non écrit) :', rap.aVerifier);
  return titre + '\n' + (corps || '\nRien à écrire.');
}
function envoyerPlan(mode) {
  const c = chantiers.find(x => x.id === courantId);
  if (!c || !PLAN_VALIDE) { alert('Aucun plan validé ou chantier introuvable.'); return; }
  const base = mode === 'raz' ? [] : piecesNvDe(c);
  const { liste, rap } = planEtat(base, PLAN_VALIDE);
  const titre = mode === 'raz'
    ? 'REMISE À ZÉRO TOTALE : tout le configurateur et tout le métré de ce chantier seront effacés (lignes saisies à la main comprises), puis remplis avec le plan. Le terrain et les renseignements du client sont conservés.'
    : 'COMPLÉTER LE CONFIGURATEUR : aucune case déjà remplie ni aucune ligne existante n\'est modifiée.';
  if (!confirm(recapPlan(titre, rap) + '\n\nÉcrire dans le configurateur ?')) return;
  if (mode === 'raz') razTotale(c);
  c.elec = c.elec || { pieces: [] };
  c.elec.piecesNv = liste;
  lsSet('chantiers', chantiers); marquerChantier(c.id);
  renderPiecesNv(); renderPlatNv(); renderPeinture();
  PLAN_VALIDE = null;
  $('plChoix').classList.add('hidden');
  $('plStatut').textContent = 'Plan écrit dans le configurateur. Cliquez sur « Générer le métré depuis le configurateur » pour créer les lignes.';
  route('config');
}
$('btnPlRaz').onclick = () => envoyerPlan('raz');
$('btnPlCompleter').onclick = () => envoyerPlan('completer');
$('btnPlChoixAnnuler').onclick = () => { PLAN_VALIDE = null; $('plChoix').classList.add('hidden'); route('config'); };
