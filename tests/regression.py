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
                   {"id": "peri1", "nom": "Mur périphérique ", "longueur": "50", "hauteur": "2", "porteur": True,
                    "type": "Élévation murs en aggloméré de ciment 20 cm (surface nette)", "finition": "", "deduire": True}],
               "toiture": {"type": "", "surface": "", "pente": "", "couverture": ""},
               "choix": {"murs": "", "tableaux": "", "finition": ""},
               "fond": {"largeur": "", "hauteur": "", "pleines": [], "rigLin": "10", "rigHt": "0.5", "rigLarg": "0.3"},
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
  return R;
}"""

ATTENDU = {
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
if erreurs:
    echecs += len(erreurs); print('ERREURS JS :', erreurs)
print('\nRésultat :', 'TOUT EST OK' if echecs == 0 else f'{echecs} échec(s) — ne pas publier')
sys.exit(1 if echecs else 0)
