
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
  `;
  const s = document.createElement('style');
  s.textContent = css;
  document.head.appendChild(s);
})();

const UNITES = ['m²', 'm³', 'ml', 'u', 'forfait'];
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
function sauverLignes(id, L) { return lsSet('lignes.' + id, L); }
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
}

// Si le script est joignable, la bibliothèque maîtresse (Drive) remplace la copie locale.
async function synchroBibliotheque() {
  if (!lsGet('url', '') || !lsGet('jeton', '')) return;
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
  const vues = { chantiers: 'vChantiers', metre: 'vMetre', tableau: 'vTableau', reglages: 'vReglages' };
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
  $('listeChantiers').innerHTML = chantiers.length
    ? chantiers.map(c => `<div class="card"><div class="row" style="justify-content:space-between;align-items:center">
        <div><strong>${esc(c.nom)}</strong><div class="muted">${lignesDe(c.id).length} ligne(s)</div></div>
        <button class="btn small" data-ouvrir="${esc(c.id)}">Ouvrir</button></div></div>`).join('')
    : '<p class="muted">Aucun chantier pour l\'instant. Créez-en un ci-dessus.</p>';
}

function remplirLots() {
  $('selLot').innerHTML = BIB.lots.map(l => `<option value="${esc(l.id)}">${esc(l.nom)}</option>`).join('');
  if (!lotCourant) lotCourant = BIB.lots[0].id;
  $('selLot').value = lotCourant;
}

function renderOuvrages() {
  const q = $('recherche').value.trim().toLowerCase();
  const liste = BIB.ouvrages.filter(o => o.lot === lotCourant && (!q || o.designation.toLowerCase().includes(q)));
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
document.addEventListener('click', e => {
  if (e.target.closest('#btnAjouterLot')) {
    const lot = $('lotNouveau').value;
    if (lot) insererLot(lot, $('lotPlace').value || null);
    return;
  }
  const r = e.target.closest('[data-retirer-lot]');
  if (r) { if (confirm('Retirer ce lot vide du métré ?')) retirerLot(r.dataset.retirerLot); }
});

function renderMetre() {
  if (!courantId) return;
  const L = lignesDe(courantId);
  const lots = lotsDuChantier(courantId);
  const nums = numeroLignes(courantId);
  compterLignes();
  dessinerPanneauLot();
  let h = `<table class="metre">
    <colgroup><col style="width:9%"><col style="width:37%"><col style="width:9%"><col style="width:13%"><col style="width:26%"><col style="width:6%"></colgroup>
    <thead><tr><th>N°</th><th>Désignation</th><th>Unité</th><th class="num">Quantité</th><th>Détail</th><th></th></tr></thead><tbody>`;
  lots.forEach((lotId, i) => {
    const lot = BIB.lots.find(x => x.id === lotId);
    const ls = L.filter(l => l.lot === lotId);
    const vide = ls.length === 0;
    h += `<tr class="lot"><td colspan="6"><span class="lotnum">${String(i + 1).padStart(2, '0')}</span> ${esc(lot ? lot.nom : lotId)}
      <span class="muted">(${vide ? 'aucune ligne' : ls.length + ' ligne' + (ls.length > 1 ? 's' : '')})</span>
      ${vide ? `<button class="btn small sec" data-retirer-lot="${esc(lotId)}">Retirer</button>` : ''}</td></tr>`;
    for (const l of ls) {
      h += `<tr>
        <td class="numl">${nums[l.uid]}</td>
        <td>${esc(l.designation)}</td>
        <td>${esc(l.unite)}</td>
        <td class="num">${fmt(l.quantite)}</td>
        <td class="detail">${esc(detail(l))}</td>
        <td class="act"><button class="btn small danger" data-sup="${esc(l.uid)}" title="Supprimer">✕</button></td>
      </tr>`;
    }
  });
  if (!lots.length) h += '<tr><td colspan="6" class="muted">Aucune ligne. Retournez à la saisie pour ajouter des ouvrages.</td></tr>';
  h += '</tbody></table>';
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
    // Même ouvrage, critères conservés : l'utilisateur peut modifier et valider une nouvelle ligne.
    ouvrirOuvrage(o, vals, `Ligne ajoutée : ${fmt(q)} ${o.unite}. Modifiez les critères pour une autre ligne.`);
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
  $('titre').textContent = c ? c.nom : 'Métré';
  remplirLots();
  route(PAGE === 'tableau' ? 'tableau' : 'metre');
  renderOuvrages();
  renderMetre();
}

/* ============ Événements ============ */
$('btnChantiers').onclick = () => { route('chantiers'); renderChantiers(); };
$('btnReglages').onclick = () => {
  $('urlScript').value = lsGet('url', '');
  $('jeton').value = lsGet('jeton', '');
  $('titre').textContent = 'Réglages';
  route('reglages');
};

$('btnNouveau').onclick = () => {
  const nom = $('nomChantier').value.trim();
  if (!nom) { alert('Donnez un nom au chantier.'); return; }
  const c = { id: 'c' + uid(), nom };
  chantiers.push(c);
  lsSet('chantiers', chantiers);
  $('nomChantier').value = '';
  ouvrirChantier(c.id);
};

$('listeChantiers').addEventListener('click', e => {
  const b = e.target.closest('[data-ouvrir]');
  if (b) ouvrirChantier(b.dataset.ouvrir);
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

$('modal').addEventListener('click', e => {
  if (e.target.id === 'modal' || e.target.id === 'bAnnuler' || e.target.id === 'bAnnulerL') { fermer(); return; }
  if (e.target.id === 'bLibre') { e.preventDefault(); ouvrirLibre(); }
});

$('btnCsv').onclick = () => {
  const nums = numeroLignes(courantId);
  const L = lignesDe(courantId);
  const rows = [['N°', 'Lot', 'Désignation', 'Unité', 'Quantité', 'Détail']];
  lotsDuChantier(courantId).forEach(lotId => {
    const lot = BIB.lots.find(x => x.id === lotId);
    for (const l of L.filter(x => x.lot === lotId))
      rows.push([nums[l.uid], lot ? lot.nom : lotId, l.designation, l.unite, fmt(l.quantite).replace(/\s/g, ''), detail(l)]);
  });
  const csv = '﻿' + rows.map(r => r.map(c => `"${String(c).replace(/"/g, '""')}"`).join(';')).join('\r\n');
  const a = document.createElement('a');
  a.href = URL.createObjectURL(new Blob([csv], { type: 'text/csv;charset=utf-8' }));
  a.download = 'metre-' + (courantId || 'chantier') + '.csv';
  a.click();
};

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
  if (courantId && chantiers.find(c => c.id === courantId)) ouvrirChantier(courantId);
  else route(PAGE === 'tableau' ? 'tableau' : 'chantiers');
  synchroBibliotheque();
  envoyerPropositions();
  if ('serviceWorker' in navigator) navigator.serviceWorker.register('sw.js').catch(() => {});
})();
