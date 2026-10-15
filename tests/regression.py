"""
Tests de non-régression — métré Atelier 2M.
Vérifie ce qui a été validé sur le chantier « Test configurateur ».
Lancer depuis la racine du dépôt :   python3 tests/regression.py
(serveur local lancé automatiquement sur le port 8812 si besoin)
"""
import json, os, subprocess, sys, time, urllib.request
from playwright.sync_api import sync_playwright

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
PORT = 8812
URL = f'http://localhost:{PORT}/index.html'

def serveur_ok():
    try:
        urllib.request.urlopen(URL, timeout=2); return True
    except Exception:
        return False

if not serveur_ok():
    subprocess.Popen([sys.executable, '-m', 'http.server', str(PORT)], cwd=ROOT,
                     stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    time.sleep(1.5)

# Chantier de test : mêmes données que « Test configurateur » validé
CHANTIER = {
    "id": "reg-test", "nom": "Régression", "client": None,
    "projet": {"epaisseur": "", "ouvertures": [],
               "murs": [
                   {"id": "soub1", "cat": "soub", "nom": "Mur de soubassement ", "longueur": "20", "hauteur": "0.5", "porteur": True,
                    "type": "Élévation murs en aggloméré de ciment 20 cm (surface nette)", "finition": "", "deduire": False},
                   {"id": "peri1", "cat": "peri", "nom": "Mur périphérique ", "longueur": "50", "hauteur": "2", "porteur": True,
                    "type": "Élévation murs en aggloméré de ciment 20 cm (surface nette)", "finition": "Enduit extérieur monocouche sur façade", "deduire": True, "epMur": "33"}],
               "toiture": {"type": "", "surface": "", "pente": "", "couverture": ""},
               "choix": {"murs": "", "tableaux": "", "finition": ""},
               "fond": {"largeur": "", "hauteur": "", "pleines": [], "rigLin": "10", "rigHt": "0.5", "rigLarg": "0.3", "semOuv": "OUV-0040"},
               "equip": {}, "cuisine": {"bas": "", "haut": "", "plan": "", "plan_ml": ""},
               "chantier": {"eau": "oui", "elec": "oui", "base": "oui", "grue": "oui", "bennes": "1", "bennesTri": "1"},
               "soub": {"hauteur": ""},
               "terrain": {"surface": "2300", "perimetre": "189", "decap": "", "resEau": ""},
               "plancher": {"type": "", "surface": "", "ep": "", "retombee": "", "portee": "", "entraxe": ""}},
    "elec": {"pieces": []}, "plat": {"hauteur": ""}, "lignes": []
}

JS_TESTS = r"""(c) => {
  const R = {};
  const vide = () => { lsSet('lignes.' + c.id, []); };
  const ouv = (L, id) => L.filter(x => x.ouvrage === id);
  // Installation : 6 lignes attendues avec les bonnes quantités
  if (!chantiers.find(x => x.id === c.id)) chantiers.push(c);
  projetDe(c); courantId = c.id; vide();
  ficheVersMetre();
  let L = lsGet('lignes.' + c.id, []);
  const inst = L.filter(x => x.lot === 'installation-chantier');
  R.installation = inst.map(x => x.ouvrage + '=' + x.quantite).sort().join(' ');
  // Fondations : fouille 10 ml -> semelle OUV-0040 même quantité, liée
  const fou = ouv(L, 'OUV-0008');
  const sem = ouv(L, 'OUV-0040');
  R.fouille = fou.length ? fou[0].quantite : null;
  R.semelle = sem.length === 1 ? sem[0].quantite : 'n=' + sem.length;
  R.semelleLiee = sem.length === 1 && sem[0].vrd === (fou[0] && fou[0].uid);
  // Suppression de la fouille -> semelle retirée
  const sansFouille = L.filter(x => x.ouvrage !== 'OUV-0008');
  R.semelleApresSuppression = alignerFondations(sansFouille).filter(x => x.ouvrage === 'OUV-0040').length;
  // Clôture : jamais créée automatiquement (décision validée) — aucune ligne OUV-0004 après synchro
  majQuantitesAuto(c); majLignesDepuisConfigurateur(c);   // même séquence que « Synchroniser le métré »
  L = lsGet('lignes.' + c.id, []);
  R.clotureAuto = L.filter(x => x.ouvrage === 'OUV-0004').length;
  // Surbrillance : règle validée
  const ob = (id, extra) => Object.assign({ ouvrage: id }, extra || {});
  const oTemp = BIB.ouvrages.find(o => o.id === 'OUV-0040');
  R.surb = {
    configDirecte: surbrillanceLigne(ob('OUV-0007', { qteAuto: 'x' })),
    semelleLiee: surbrillanceLigne(ob('OUV-0040', { vrd: 'u1' })),
    manuelle: surbrillanceLigne(ob('OUV-0004')),
    configClotureNonMauve: surbrillanceLigne(ob('OUV-0004', { qteAuto: 'cloture_ml' })),
  };
  // Murs : le détail de l'élévation (surface nette) ne cite pas le soubassement (il a son propre article)
  const lElev = L.find(x => x.ouvrage === 'OUV-0048' && /^(Calcul du configurateur : )?murs, surface nette/.test((x.valeurs || {}).src || ''));
  const lSoub = L.find(x => x.ouvrage === 'OUV-0048' && /murs de soubassement/.test((x.valeurs || {}).src || ''));
  const txtElev = lElev ? (() => { const d = document.createElement('div'); d.innerHTML = detailHtml(lElev); return d.textContent; })() : '';
  R.detailElev = { soubCite: /soubassement/i.test(txtElev), periCite: /Mur périphérique/.test(txtElev), quantite: lElev ? lElev.quantite : null, regleDeduction: /égales ou supérieures à 1 m² déduites/.test(txtElev) };
  R.soubQuantite = lSoub ? lSoub.quantite : null;
  // Ordre des lots : installation de chantier en premier
  R.premierLot = lotsDuChantier(c.id)[0] ? (lotsDuChantier(c.id)[0].id || lotsDuChantier(c.id)[0]) : null;
  // Bloc A en veille : ne génère rien. Nouveau configurateur de pièces : une pièce complète, régénérée deux fois
  const retourElec = genererElec();
  R.veilleAucuneAuto = lsGet('lignes.' + c.id, []).filter(x => x.auto).length;
  R.veilleMessage = /veille/.test(retourElec);
  const cN = chantiers.find(x => x.id === c.id);
  piecesNvDe(cN).push({ id: 'pn-test', nom: 'Chambre test', surf: '15', revet: 'OUV-0274', portes: '',
    blocs: [{ dest: '', pousse: '', ame: '', type: '', fin: '', pose: '', ouv: 'OUV-0965', nb: '1' }],
    perim: '15.5', passage: '1', facades: [{ ouv: 'OUV-0755', l: '200', h: '240', nb: '1' }], menus: [{ l: '100', h: '100', nb: '1', ouv: 'OUV-0162' }, { l: '180', h: '210', nb: '1', ouv: 'OUV-0172' }], app: { prises: '3', rj45: '1', interrup: '1', points: '1' } });
  piecesNvDe(cN).push({ id: 'pn-bureau', nom: 'Bureau', surf: '', revet: '', portes: '', menus: [], app: {} });
  piecesNvDe(cN).push({ id: 'pn-cuisine', nom: 'Cuisine', surf: '9', revet: '', portes: '', menus: [], app: {} });
  piecesNvDe(cN).push({ id: 'pn-terrasse', nom: 'Terrasse extérieure', surf: '10', revet: '', portes: '', menus: [], app: {} });
  piecesNvDe(cN).push({ id: 'pn-cellier', nom: 'Cellier', surf: '5', revet: '', portes: '', menus: [], app: {} });
  genererPiecesNv(cN); genererEquipementsMaison(cN);
  const n1 = lsGet('lignes.' + c.id, []).filter(x => x.pieceNv);
  genererPiecesNv(cN);
  const n2 = lsGet('lignes.' + c.id, []).filter(x => x.pieceNv);
  // Spots : cuisine de 9 m² en spots = 9 × 300 lux / 450 lm → 6 spots OUV-0211, sans point lumineux ; retour au point ensuite
  const pcuis = piecesNvDe(cN).find(x => x.id === 'pn-cuisine');
  pcuis.eclairage = 'spots'; genererPiecesNv(cN);
  const spotsL = lsGet('lignes.' + c.id, []).filter(x => x.pieceNv === 'pn-cuisine');
  R.spotsCuisine = spotsL.filter(x => x.ouvrage === 'OUV-0211').map(x => x.quantite).join(',');
  R.pointsCuisineSpots = spotsL.filter(x => x.ouvrage === 'OUV-0614').length;
  pcuis.plafVV = 'oui'; genererPiecesNv(cN);
  const plafL = lsGet('lignes.' + c.id, []).filter(x => x.pieceNv === 'pn-cuisine');
  R.plafPlafonnier = plafL.filter(x => x.ouvrage === 'OUV-0614').length;
  R.plafVVsupp = plafL.filter(x => /commande du plafonnier/.test(x.designation)).length;
  R.plafCouleur = plafL.filter(x => x.pieceOption && surbrillanceLigne(x) === 'ligne-option').length;
  pcuis.plafVV = ''; pcuis.eclairage = ''; genererPiecesNv(cN);
  R.pointsCuisineRetour = lsGet('lignes.' + c.id, []).filter(x => x.pieceNv === 'pn-cuisine' && x.ouvrage === 'OUV-0614').length;
  R.pieceNv = { maison: lsGet('lignes.' + c.id, []).filter(x => x.pieceNv === 'maison').map(x => x.ouvrage + '=' + x.quantite).join(' '), plafCouleur: R.plafCouleur, plafPlafonnier: R.plafPlafonnier, plafVVsupp: R.plafVVsupp, spotsCuisine: R.spotsCuisine, pointsCuisineSpots: R.pointsCuisineSpots, pointsCuisineRetour: R.pointsCuisineRetour, n: n1.length, nApresRegeneration: n2.length, surbrillance: [...new Set(n1.map(surbrillanceLigne))].join(','),
    prises: (n1.find(x => x.ouvrage === 'OUV-0611') || {}).quantite || 0,
    rjBureau: (n1.filter(x => x.ouvrage === 'OUV-0216' && /Bureau/.test(x.designation)).length),
    plinthes: (n1.find(x => x.ouvrage === 'OUV-0881') || {}).quantite || 0,
    plinthesSousRevet: (n1.findIndex(x => x.ouvrage === 'OUV-0881') === n1.findIndex(x => x.ouvrage === 'OUV-0274') + 1),
    terrasse: n1.filter(x => x.pieceNv === 'pn-terrasse' && ['OUV-0615', 'OUV-0223', 'OUV-0893'].includes(x.ouvrage)).length,
    facade: Math.round(((n1.find(x => x.ouvrage === 'OUV-0755') || {}).quantite || 0) * 100) / 100,
    circuitsCuisine: n1.filter(x => ['OUV-0882', 'OUV-0883', 'OUV-0884'].includes(x.ouvrage)).length,
    circuitsCellier: n1.filter(x => ['OUV-0885', 'OUV-0886', 'OUV-0887'].includes(x.ouvrage)).length,
    hotte: n1.filter(x => x.ouvrage === 'OUV-0888').length };
  platNvDe(cN).hauteur = '2.5'; platNvDe(cN).hauteurDoub = '2.5'; platNvDe(cN).cloi = { ml: '10', ouv: 'OUV-0751' }; platNvDe(cN).doub = { ml: '10', ouv: 'OUV-0933' }; platNvDe(cN).pla = { m2: '12', ouv: 'OUV-0149' }; genererPlatNv(cN);
  // Case de formule du doublage : (linéaire × hauteur de doublage − toutes les menuiseries, sans seuil) × 1,9
  const jD = lsGet('lignes.' + c.id, []).find(x => x.platNv && x.ouvrage === 'OUV-0579' && /doublage/.test(x.designation));
  R.doubJoint = jD && Math.abs(jD.quantite - (10 * 2.5 - menuiseriesToutesM2(cN)) * 1.9) < 0.01 ? 1 : 0;
  R.platDoub = { quantite: Math.round(((lsGet('lignes.' + c.id, []).find(x => x.ouvrage === 'OUV-0933') || {}).quantite || 0) * 100) / 100 };
  peiDe(cN).hauteur = '2.5'; peiDe(cN).murs = { ml: '10', ouv: 'OUV-0689' }; peiDe(cN).plafond = { m2: '12', ouv: 'OUV-0690' }; genererPeinture(cN);
  R.peiPF = { quantite: Math.round(((lsGet('lignes.' + c.id, []).find(x => x.ouvrage === 'OUV-0691') || {}).quantite || 0) * 100) / 100 };
  R.pei = { murs: Math.round(((lsGet('lignes.' + c.id, []).find(x => x.ouvrage === 'OUV-0689') || {}).quantite || 0) * 100) / 100, plafond: Math.round(((lsGet('lignes.' + c.id, []).find(x => x.ouvrage === 'OUV-0690') || {}).quantite || 0) * 100) / 100 };
  R.platCloi = { quantite: Math.round(((lsGet('lignes.' + c.id, []).find(x => x.ouvrage === 'OUV-0751') || {}).quantite || 0) * 100) / 100 };
  R.platPla = { quantite: Math.round(((lsGet('lignes.' + c.id, []).find(x => x.ouvrage === 'OUV-0149') || {}).quantite || 0) * 100) / 100 };
  R.plat = { quantite: Math.round(((lsGet('lignes.' + c.id, []).find(x => x.platNv) || {}).quantite || 0) * 100) / 100 };
  // Cloisonnement saisi en m² (sans linéaire) : même déduction que par le linéaire, 10 m² - portes et placards
  const pq = platNvDe(cN); const mlSauve = pq.cloi.ml;
  pq.cloi.ml = ''; pq.cloi.m2 = '10'; genererMetreConfigurateur(cN);
  const lM2 = lsGet('lignes.' + c.id, []).find(x => x.platNv && /cloison/i.test(x.designation));
  R.platM2Ok = lM2 && Math.abs(lM2.quantite - (10 - portesEtPlacardsM2(cN))) < 0.01 ? 1 : 0;
  pq.cloi.ml = mlSauve; pq.cloi.m2 = ''; genererMetreConfigurateur(cN);
  // Bande à joint (case formule) : vide, aucune ligne ; avec « S * 1,1 », une ligne OUV-0579 = surface de la cloison × 1,1
  pq.cloi.joint = ''; genererMetreConfigurateur(cN);
  const nbJointSansChoix = lsGet('lignes.' + c.id, []).filter(x => x.platNv && /joint/i.test(x.designation) && /cloisonnement/.test(x.designation)).length;
  pq.cloi.joint = 'S * 1.1'; genererMetreConfigurateur(cN);
  const jCl = lsGet('lignes.' + c.id, []).find(x => x.platNv && x.ouvrage === 'OUV-0579' && /cloisonnement/.test(x.designation));
  R.cloiJoint = jCl && Math.abs(jCl.quantite - (10 * 2.5 - portesEtPlacardsToutesM2(cN)) * 1.1) < 0.01 ? 1 : 0;
  const LJ = lsGet('lignes.' + c.id, []);
  const jC = LJ.find(x => x.platNv && x.ouvrage === 'OUV-0579' && /cloisonnement/.test(x.designation));
  const cJ = LJ.find(x => x.platNv && x.ouvrage === 'OUV-0751');
  R.platJoint = jC && nbJointSansChoix === 0 ? 1 : 0;
  pq.cloi.joint = ''; genererMetreConfigurateur(cN);
  // Isolant choisi sur la cloison : une ligne isolant de même surface que la cloison, puis retirée si on revient à « Sans isolant »
  pq.cloi.isol = 'OUV-0902'; genererMetreConfigurateur(cN);
  const lC = lsGet('lignes.' + c.id, []).find(x => x.platNv && x.ouvrage === 'OUV-0751');
  const lI = lsGet('lignes.' + c.id, []).find(x => x.platNv && x.ouvrage === 'OUV-0902');
  // Isolant du cloisonnement : (linéaire × hauteur − portes et façades, sans seuil) × 1,05
  R.platIsol = lI && Math.abs(lI.quantite - (10 * 2.5 - portesEtPlacardsToutesM2(cN)) * 1.05) < 0.01 ? 1 : 0;
  pq.cloi.isol = ''; genererMetreConfigurateur(cN);
  R.platIsolRetire = lsGet('lignes.' + c.id, []).filter(x => x.platNv && x.ouvrage === 'OUV-0902').length;
  // Retrait : sans hauteur, plus aucune ligne plâtrerie ni peinture murs ne doit rester
  platNvDe(cN).hauteur = ''; platNvDe(cN).hauteurDoub = ''; peiDe(cN).hauteur = ''; genererMetreConfigurateur(cN);
  R.platJointPla = (function () { const cc = {}; const qq = platNvDe(cc); return qq.pla.joint === 'S * 3,8' && qq.pla.jointInit === true ? 1 : 0; })();
  // Plus-value hydrofuge du cloisonnement : 11 ml → 10 plaques × 1,20 m × hauteur 2,50 m = 30 m² (OUV-0948)
  const hSauve = platNvDe(cN).hauteur; platNvDe(cN).hauteur = '2.5';
  platNvDe(cN).cloi.hydro = '11'; genererMetreConfigurateur(cN);
  const pvH = lsGet('lignes.' + c.id, []).find(x => x.platNv && x.ouvrage === 'OUV-0948' && /cloisonnement/.test(x.designation));
  R.pvHydroCloi = pvH && Math.abs(pvH.quantite - 30) < 0.01 ? 1 : 0;
  platNvDe(cN).cloi.hydro = ''; platNvDe(cN).hauteur = hSauve; genererMetreConfigurateur(cN);
  R.verrouDefaut = (function () { const qq = platNvDe({}); return verrouJoint(qq, 'cloi') && verrouJoint(qq, 'doub') && verrouJoint(qq, 'pla') ? 1 : 0; })();
  R.platStale = lsGet('lignes.' + c.id, []).filter(x => x.platNv && x.ouvrage !== 'OUV-0149' && !(/joint/i.test(x.designation) && /plafond/.test(x.designation))).length;
  R.peiStale = lsGet('lignes.' + c.id, []).filter(x => x.ouvrage === 'OUV-0689').length;
  platNvDe(cN).hauteur = '2.5'; platNvDe(cN).hauteurDoub = '2.5'; peiDe(cN).hauteur = '2.5'; genererMetreConfigurateur(cN);
  // La fenêtre du nouveau bloc (100 × 100 cm = 1 m²) est déduite du mur périphérique : 100 - 1 = 99
  ficheVersMetre();
  const elev = lsGet('lignes.' + c.id, []).find(x => x.ouvrage === 'OUV-0048' && /murs, surface nette/.test((x.valeurs || {}).src || ''));
  R.elevApresFenetre = elev ? Math.round(elev.quantite * 100) / 100 : null;
  const tabl = lsGet('lignes.' + c.id, []).find(x => x.designation === 'Tableaux de menuiseries (2 côtés)');
  R.tableauxAuto = tabl ? Math.round(tabl.quantite * 100) / 100 : null;
  R.tableauxDesig = tabl ? tabl.ouvrage : null;
  // Tableaux après synchronisation : placés juste sous l'enduit de leur mur, même si d'autres lignes suivent
  let Lt = lsGet('lignes.' + c.id, []).filter(x => x.designation !== 'Tableaux de menuiseries (2 côtés)');
  Lt.push({ uid: 'dummy-fin', lot: 'gros-oeuvre', ouvrage: 'OUV-0770', designation: 'Ligne factice', unite: 'm²', valeurs: {}, quantite: 1, prix: 'moyen' });
  lsSet('lignes.' + c.id, Lt);
  majQuantitesAuto(c); majLignesDepuisConfigurateur(c);
  const Lg = lsGet('lignes.' + c.id, []).filter(x => x.lot === 'gros-oeuvre');
  const iEnd = Lg.findIndex(x => x.ouvrage === 'OUV-0071' && /surface nette/.test((x.valeurs || {}).src || ''));
  const iTab = Lg.findIndex(x => x.designation === 'Tableaux de menuiseries (2 côtés)');
  R.tableauSousEnduit = iTab >= 0 && iTab === iEnd + 1;
  // Remise à zéro : les cases remplies sont vidées (pièce de test, plâtrerie, peinture) et les lignes générées retirées
  renderPiecesNv(); renderPlatNv(); renderPeinture();
  const avantRazPlat = lsGet('lignes.' + c.id, []).filter(x => x.platNv).length;
  remiseAZeroConfigurateur(cN, false);
  R.raz = { plat: (platNvDe(cN).hauteur === '' && platNvDe(cN).cloi.ml === '') ? 1 : 0,
    pieces: piecesNvDe(cN).length === 0 ? 1 : 0,
    pei: peiDe(cN).hauteur === '' ? 1 : 0,
    metreIntact: lsGet('lignes.' + c.id, []).filter(x => x.platNv).length === avantRazPlat ? 1 : 0 };
  return R;
}"""

ATTENDU = {
    'platM2Ok': 1,
    'platIsol': 1,
    'platJoint': 1,
    'platJointPla': 1,
    'verrouDefaut': 1,
    'doubJoint': 1,
    'cloiJoint': 1,
    'pvHydroCloi': 1,
    'platIsolRetire': 0,
    'installation': 'OUV-0484=1 OUV-0485=1 OUV-0486=1 OUV-0487=1 OUV-0488=1 OUV-0492=1',
    'fouille': 1.5,
    'semelle': 1.5,
    'semelleLiee': True,
    'semelleApresSuppression': 0,
    'clotureAuto': 0,
    'surb': {'configDirecte': '', 'semelleLiee': 'ligne-lie', 'manuelle': 'ligne-manuelle', 'configClotureNonMauve': ''},
    'premierLot': 'installation-chantier',
    'detailElev': {'soubCite': False, 'periCite': True, 'quantite': 100, 'regleDeduction': True},
    'soubQuantite': 10,
    'veilleAucuneAuto': 0,
    'elevApresFenetre': 95.22,
    'tableauxAuto': 2.05,
    'tableauSousEnduit': True,
    'tableauxDesig': 'OUV-0071',
    'veilleMessage': True,
    'plat': {'quantite': 18.51},
    'platPla': {'quantite': 12},
    'platDoub': {'quantite': 21.22},
    'platCloi': {'quantite': 18.51},
    'platStale': 0,
    'peiStale': 0,
    'raz': {'plat': 1, 'pieces': 1, 'pei': 1, 'metreIntact': 1},
    'pei': {'murs': 20.98, 'plafond': 12},
    'peiPF': {'quantite': 12.99},
    'pieceNv': {'maison': 'OUV-0609=1 OUV-0618=1', 'plafCouleur': 2, 'plafPlafonnier': 1, 'plafVVsupp': 1, 'spotsCuisine': '6', 'pointsCuisineSpots': 0, 'pointsCuisineRetour': 1, 'rjBureau': 1, 'n': 35, 'nApresRegeneration': 35, 'facade': 4.8, 'terrasse': 3, 'plinthes': 9.87, 'plinthesSousRevet': True, 'surbrillance': '', 'prises': 3, 'circuitsCuisine': 3, 'circuitsCellier': 3, 'hotte': 1},
}

echecs = 0
with sync_playwright() as pw:
    b = pw.chromium.launch(executable_path='/opt/pw-browsers/chromium', args=['--no-sandbox'])
    pg = b.new_page(service_workers='block')
    erreurs = []
    pg.on('pageerror', lambda e: erreurs.append(str(e)))
    pg.goto(URL); pg.wait_for_timeout(2500)
    obtenu = pg.evaluate(JS_TESTS, CHANTIER)
    b.close()

for cle, att in ATTENDU.items():
    got = obtenu.get(cle)
    if isinstance(att, dict):
        for k, v in att.items():
            if obtenu[cle].get(k) != v:
                echecs += 1; print(f'ÉCHEC {cle}.{k} : attendu {v!r}, obtenu {obtenu[cle].get(k)!r}')
            else:
                print(f'ok    {cle}.{k}')
    elif got != att:
        echecs += 1; print(f'ÉCHEC {cle} : attendu {att!r}, obtenu {got!r}')
    else:
        print(f'ok    {cle}')
# Portes de passage : tailles 63/73/83/93/103 présentes et ouvrages disponibles dans la bibliothèque
_bib = json.load(open(os.path.join(ROOT, 'bibliotheque.json'), encoding='utf-8'))
_app = open(os.path.join(ROOT, 'app.js'), encoding='utf-8').read()
for _t in ('63', '73', '83', '93', '103'):
    _des = f'Bloc-porte fin de chantier {_t}×204'
    _ok = any(o['designation'] == _des and not o.get('supprime') for o in _bib['ouvrages']) and f"'{_t}': '{_des}'" in _app
    if _ok: print(f'ok    porte.{_t}')
    else: echecs += 1; print(f'ÉCHEC porte.{_t} : ouvrage ou correspondance absent')
# Cloisons : une seule référence par type voulu ; cloisons sans isolant séparé ; doublons retirés (marqués « supprimé », rien d'effacé)
_gardees = ['OUV-0751', 'OUV-0752', 'OUV-0753', 'OUV-0148', 'OUV-0899', 'OUV-0900', 'OUV-0901', 'OUV-0051', 'OUV-0056']
_retirees = ['OUV-0075', 'OUV-0145', 'OUV-0146', 'OUV-0147', 'OUV-0569', 'OUV-0570', 'OUV-0571', 'OUV-0576', 'OUV-0577', 'OUV-0754', 'OUV-0756', 'OUV-0757', 'OUV-0758', 'OUV-0759']
_par = {o['id']: o for o in _bib['ouvrages']}
for _id in _gardees:
    if _id in _par and not _par[_id].get('supprime'): print(f'ok    cloison.{_id}')
    else: echecs += 1; print(f'ÉCHEC cloison.{_id} : doit rester active')
for _id in _retirees:
    if _id not in _par: print(f'ok    cloison.retiree.{_id}')
    else: echecs += 1; print(f'ÉCHEC cloison.retiree.{_id} : doit être retirée de la bibliothèque')
# Isolant laine de verre non revêtu 45 mm : proposé dans la liste d'isolant de la plâtrerie
_iso = _par.get('OUV-0902', {})
if _iso.get('designation') == 'Isolant laine de verre non revêtu 45 mm' and not _iso.get('supprime') and "/^(Isolation|Isolant)/i" in _app:
    print('ok    isolant.OUV-0902')
else: echecs += 1; print('ÉCHEC isolant.OUV-0902 : absent ou non proposé')
for _id, _des in (('OUV-0903', 'Isolant laine de verre non revêtu 60 mm'), ('OUV-0904', 'Isolant laine de verre non revêtu 85 mm'), ('OUV-0905', 'Isolant laine de verre GR32 120 mm (R 3,75)'), ('OUV-0906', 'Isolant laine de verre GR32 140 mm (R 4,35)'), ('OUV-0907', 'Isolant laine de verre Isoconfort 280 mm (R 7)'), ('OUV-0908', 'Isolant laine de verre IBR 320 mm (R 8)'), ('OUV-0909', 'Isolant laine de verre IBR 400 mm (R 10)'), ('OUV-0910', 'Isolant laine de verre soufflée 330 mm (R 7)'), ('OUV-0911', 'Isolant laine de verre soufflée 380 mm (R 8)'), ('OUV-0912', 'Isolant laine de verre soufflée 465 mm (R 10)'), ('OUV-0913', 'Isolant ouate de cellulose soufflée 300 mm (R 7)'), ('OUV-0914', 'Isolant ouate de cellulose soufflée 350 mm (R 8)'), ('OUV-0915', 'Isolant ouate de cellulose soufflée 435 mm (R 10)'), ('OUV-0916', 'Isolant panneau laine de bois 40 mm (R 1,11)'), ('OUV-0917', 'Isolant panneau laine de bois 60 mm (R 1,66)'), ('OUV-0918', 'Isolant panneau laine de bois 80 mm (R 2,22)'), ('OUV-0919', 'Isolant panneau laine de bois 100 mm (R 2,78)'), ('OUV-0920', 'Isolant panneau laine de bois 120 mm (R 3,33)'), ('OUV-0921', 'Isolant panneau laine de bois 145 mm (R 4,03)'), ('OUV-0922', 'Isolant panneau laine de bois 160 mm (R 4,44)'), ('OUV-0923', 'Isolant panneau laine de bois 180 mm (R 5)'), ('OUV-0924', 'Isolant panneau laine de bois 200 mm (R 5,56)'), ('OUV-0925', 'Isolant panneau laine de bois 220 mm (R 6,11)'), ('OUV-0926', 'Isolant panneau laine de bois 240 mm (R 6,66)'), ('OUV-0927', 'ITE panneau fibre de bois rigide 40 mm (R 0,95)'), ('OUV-0928', 'ITE panneau fibre de bois rigide 60 mm (R 1,4)'), ('OUV-0929', 'ITE panneau fibre de bois rigide 80 mm (R 1,9)'), ('OUV-0930', 'ITE panneau fibre de bois rigide 100 mm (R 2,35)'), ('OUV-0931', 'Fibre de bois à enduire 20 mm pour tableau de menuiserie')):
    _o = _par.get(_id, {})
    if _o.get('designation') == _des and not _o.get('supprime'): print(f'ok    isolant.{_id}')
    else: echecs += 1; print(f'ÉCHEC isolant.{_id} : absent')
# Isolants retirés de la bibliothèque (demande de Mathieu) : plus aucun ouvrage à ces identifiants
_retires_iso = ['OUV-0125', 'OUV-0126', 'OUV-0127', 'OUV-0128', 'OUV-0139', 'OUV-0155', 'OUV-0401', 'OUV-0402', 'OUV-0403', 'OUV-0559', 'OUV-0560']
if not any(i in _par for i in _retires_iso): print('ok    isolants.retires')
else: echecs += 1; print('ÉCHEC isolants.retires : encore présents')
# Spots encastrés : ouvrage LED standard et version étanche IP65 pour salle de bain
for _id, _des in (('OUV-0211', 'Spot encastré LED'), ('OUV-0898', 'Spot encastré LED étanche IP65 (salle de bain)')):
    _ok = any(o['id'] == _id and o['designation'] == _des and not o.get('supprime') for o in _bib['ouvrages'])
    if _ok: print(f'ok    spot.{_id}')
    else: echecs += 1; print(f'ÉCHEC spot.{_id} : ouvrage absent')
if erreurs:
    echecs += len(erreurs); print('ERREURS JS :', erreurs)
print('\nRésultat :', 'TOUT EST OK' if echecs == 0 else f'{echecs} échec(s) — ne pas publier')
sys.exit(1 if echecs else 0)
