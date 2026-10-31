# Génère les textures A2M (enduits, tuiles) : PNG 512×512, répétables
import os, numpy as np
from PIL import Image, ImageDraw, ImageFilter
RACINE = os.path.dirname(os.path.abspath(__file__))  # textures rangées à côté de ce script
N = 512
rng = np.random.default_rng(7)

def bruit(echelle, amp):
    """Bruit répétable : grille aléatoire agrandie par interpolation circulaire."""
    g = rng.random((echelle, echelle))
    img = Image.fromarray((g * 255).astype(np.uint8)).resize((N, N), Image.BICUBIC)
    return (np.asarray(img).astype(float) / 255 - 0.5) * amp

def rgb(c): return np.array(c, dtype=float)

def sauve(arr, dossier, nom):
    os.makedirs(os.path.join(RACINE, dossier), exist_ok=True)
    Image.fromarray(np.clip(arr, 0, 255).astype(np.uint8)).save(os.path.join(RACINE, dossier, nom + '.png'))

# ---- Enduits : couleur de fond + grain selon la finition
def enduit(couleur, finition):
    base = np.ones((N, N, 3)) * rgb(couleur)
    if finition == 'taloche':        # fin, presque lisse, léger grain
        m = bruit(64, 10) + bruit(128, 6)
    elif finition == 'gratte_fin':   # stries fines et serrées
        m = bruit(256, 14) + bruit(96, 8)
    elif finition == 'gratte_moyen': # grain plus gros, plus marqué
        m = bruit(48, 26) + bruit(160, 10)
    elif finition == 'projete':      # points en relief
        m = bruit(120, 30); m = m + (rng.random((N, N)) > 0.985) * 40
    else:                            # chaux : marbrures douces
        m = bruit(20, 22) + bruit(60, 10)
    return base + m[..., None]

ENDUITS = [
    ('taloche_blanc', (240, 238, 232), 'taloche'),
    ('taloche_beige', (222, 205, 180), 'taloche'),
    ('gratte_fin_sable', (214, 190, 150), 'gratte_fin'),
    ('gratte_fin_gris', (176, 174, 170), 'gratte_fin'),
    ('gratte_moyen_ocre', (200, 160, 100), 'gratte_moyen'),
    ('gratte_moyen_blanc_casse', (232, 226, 214), 'gratte_moyen'),
    ('projete_blanc', (242, 240, 236), 'projete'),
    ('projete_gris_clair', (200, 198, 192), 'projete'),
    ('chaux_creme', (236, 228, 208), 'chaux'),
    ('chaux_ocre_clair', (214, 186, 140), 'chaux'),
    ('chaux_gris_pierre', (170, 166, 158), 'chaux'),
    ('taloche_gris_anthracite', (92, 92, 94), 'taloche'),
]
for nom, c, f in ENDUITS:
    sauve(enduit(c, f), 'enduits', nom)

# ---- Tuiles : grille de tuiles répétée, nuances par tuile
def tuile_canal(couleur, nuance, nom):
    im = Image.new('RGB', (N, N), (60, 30, 20))
    d = ImageDraw.Draw(im)
    rang = 64
    for y in range(0, N + rang, rang):
        for x in range(-32, N + 64, 64):
            t = 1 + rng.uniform(-nuance, nuance)
            c = tuple(int(min(255, v * t)) for v in couleur)
            # demi-cylindre convexe (tuile de dessus) : ellipse ombrée
            d.ellipse([x, y, x + 64, y + rang * 2], fill=c)
            d.ellipse([x + 12, y + 8, x + 52, y + rang * 2 - 8], outline=tuple(int(v * 0.6) for v in c), width=3)
    im = im.filter(ImageFilter.GaussianBlur(0.6))
    arr = np.asarray(im).astype(float) + bruit(160, 14)[..., None]
    sauve(arr, 'tuiles', nom)

def tuile_romane(couleur, nuance, nom):
    im = Image.new('RGB', (N, N), (70, 35, 25))
    d = ImageDraw.Draw(im)
    for y in range(0, N + 48, 48):
        for x in range(-40, N + 80, 80):
            t = 1 + rng.uniform(-nuance, nuance)
            c = tuple(int(min(255, v * t)) for v in couleur)
            d.rounded_rectangle([x, y, x + 76, y + 46], radius=22, fill=c, outline=tuple(int(v * 0.55) for v in c), width=2)
    im = im.filter(ImageFilter.GaussianBlur(0.5))
    arr = np.asarray(im).astype(float) + bruit(160, 12)[..., None]
    sauve(arr, 'tuiles', nom)

def tuile_mecanique(couleur, nuance, nom):
    im = Image.new('RGB', (N, N), (60, 28, 18))
    d = ImageDraw.Draw(im)
    for y in range(0, N + 40, 40):
        for x in range(-30, N + 60, 60):
            t = 1 + rng.uniform(-nuance, nuance)
            c = tuple(int(min(255, v * t)) for v in couleur)
            d.rounded_rectangle([x, y, x + 56, y + 36], radius=8, fill=c, outline=tuple(int(v * 0.6) for v in c), width=2)
    im = im.filter(ImageFilter.GaussianBlur(0.5))
    arr = np.asarray(im).astype(float) + bruit(160, 12)[..., None]
    sauve(arr, 'tuiles', nom)

def ardoise(couleurs, nom):
    im = Image.new('RGB', (N, N), (40, 40, 44))
    d = ImageDraw.Draw(im)
    for y in range(0, N + 40, 40):
        decal = 0 if (y // 40) % 2 == 0 else 30
        for x in range(-60 + decal, N + 60, 60):
            c = couleurs[rng.integers(len(couleurs))]
            c = tuple(int(min(255, max(0, v + rng.uniform(-10, 10)))) for v in c)
            d.polygon([(x, y), (x + 56, y), (x + 56, y + 32), (x + 28, y + 38), (x, y + 32)], fill=c, outline=(30, 30, 34))
    im = im.filter(ImageFilter.GaussianBlur(0.4))
    arr = np.asarray(im).astype(float) + bruit(200, 10)[..., None]
    sauve(arr, 'tuiles', nom)

tuile_canal((176, 82, 48), 0.07, 'canal_rouge')
tuile_canal((138, 66, 44), 0.09, 'canal_rouge_vieilli')
tuile_canal((160, 84, 56), 0.16, 'canal_rouge_nuance')
tuile_romane((168, 90, 60), 0.10, 'romane_terre_cuite')
tuile_mecanique((170, 74, 46), 0.08, 'mecanique_rouge')
tuile_mecanique((70, 66, 64), 0.08, 'mecanique_noire')
ardoise([(78, 82, 90), (96, 100, 108), (62, 66, 74), (110, 112, 116)], 'ardoise_panachee')
ardoise([(60, 64, 72)], 'ardoise_naturelle')
print('ok')

# ---- RAL pour menuiseries : teinte unie, léger grain de poudrage (teintes approximatives à l'écran)
RAL = [
    ('ral_9010_blanc_pur', (241, 236, 225)),
    ('ral_9016_blanc_signalisation', (246, 246, 246)),
    ('ral_1013_blanc_perle', (234, 230, 202)),
    ('ral_1015_ivoire_clair', (230, 210, 181)),
    ('ral_1001_beige', (205, 179, 139)),
    ('ral_7035_gris_clair', (197, 199, 196)),
    ('ral_7001_gris_argent', (138, 149, 151)),
    ('ral_7015_gris_ardoise', (81, 86, 92)),
    ('ral_7016_gris_anthracite', (56, 62, 66)),
    ('ral_7022_gris_ombre', (75, 77, 70)),
    ('ral_9007_gris_aluminium', (143, 143, 138)),
    ('ral_8017_brun_chocolat', (69, 50, 46)),
    ('ral_8014_brun_sepia', (59, 47, 47)),
    ('ral_6005_vert_mousse', (47, 69, 56)),
    ('ral_6009_vert_sapin', (39, 53, 42)),
    ('ral_5010_bleu_gentiane', (14, 65, 110)),
    ('ral_3005_rouge_vin', (89, 25, 31)),
    ('ral_3004_rouge_pourpre', (107, 30, 43)),
    ('ral_9005_noir_fonce', (12, 12, 12)),
]
for nom, c in RAL:
    base = np.ones((N, N, 3)) * rgb(c)
    sauve(base + bruit(256, 5)[..., None], 'ral', nom)

# ---- Vitrages : teinte de verre + reflet diagonal, motif propre à chaque type
def vitrage(couleur, reflet, motif, nom):
    x = np.arange(N)[None, :] * np.ones((N, 1))
    y = np.arange(N)[:, None] * np.ones((1, N))
    diag = ((x + y) % 256) / 256.0          # bande de reflet répétable
    arr = np.ones((N, N, 3)) * rgb(couleur)
    arr += (reflet * np.exp(-((diag - 0.5) ** 2) / 0.006))[..., None] * 255
    if motif == 'sable':
        arr += bruit(256, 40)[..., None]     # verre dépoli : grain fort, léger voile
    if motif == 'feuillete':
        arr -= ((y % 128) < 3)[..., None] * 25   # lignes de l'intercalaire
    if motif == 'mat':
        arr += bruit(64, 18)[..., None]
    sauve(arr, 'vitrages', nom)

vitrage((214, 232, 236), 0.10, 'clair', 'clair')
vitrage((122, 138, 143), 0.14, 'clair', 'teinte_gris')
vitrage((132, 104, 74), 0.12, 'clair', 'bronze')
vitrage((120, 150, 178), 0.45, 'clair', 'reflechissant_bleu')
vitrage((200, 214, 218), 0.20, 'sable', 'sable')
vitrage((205, 225, 228), 0.12, 'feuillete', 'feuillete')
print('ok RAL + vitrages')

# ---- Zinguerie : métal avec grain et reflets propres à chaque matière
def metal(couleur, grain, nom, motif=None):
    arr = np.ones((N, N, 3)) * rgb(couleur)
    arr += bruit(256, grain)[..., None]
    if motif == 'stries':                      # zinc laminé : stries horizontales fines
        arr += (bruit(512, 1) * 0 + rng.uniform(-6, 6, (N, 1)))[..., None] * np.ones((1, N, 1))
    if motif == 'galva':                       # acier galvanisé : cristaux (spangles)
        pts = rng.random((N, N)) > 0.93
        arr += (pts * 40)[..., None] * np.array([1, 1, 1])
    if motif == 'patine':                      # zinc prépatiné : taches bleutées
        arr += bruit(40, 30)[..., None] * np.array([-0.2, 0.1, 0.6])
    sauve(arr, 'zinguerie', nom)

metal((150, 158, 162), 10, 'zinc_naturel', 'stries')
metal((86, 94, 100), 14, 'zinc_prepatine', 'patine')
metal((138, 140, 138), 8, 'aluminium_laque_gris', 'stries')
metal((165, 170, 172), 12, 'acier_galvanise', 'galva')
metal((242, 242, 238), 4, 'pvc_blanc')
metal((118, 120, 116), 4, 'pvc_gris')
metal((176, 96, 58), 22, 'cuivre', None)

# ---- Appuis et seuils : pierre et béton
def pierre_calcaire(nom):
    arr = np.ones((N, N, 3)) * rgb((224, 210, 180))
    arr += bruit(96, 16)[..., None]
    for y in range(0, N, 42):                  # lits de pose horizontaux
        arr[y:y + 2] *= 0.82
    arr += (rng.random((N, N)) > 0.97)[..., None] * (-30)   # pores
    sauve(arr, 'appuis_seuils', nom)

def granit(nom):
    arr = np.ones((N, N, 3)) * rgb((128, 128, 126))
    arr += bruit(128, 18)[..., None]
    sel = rng.random((N, N))
    arr[sel > 0.90] = rgb((215, 215, 212))     # grains clairs
    arr[sel < 0.06] = rgb((40, 40, 40))        # grains sombres
    sauve(arr, 'appuis_seuils', nom)

def beton(nom):
    arr = np.ones((N, N, 3)) * rgb((190, 188, 182))
    arr += bruit(256, 10)[..., None]
    arr += (rng.random((N, N)) > 0.99)[..., None] * (-35)
    sauve(arr, 'appuis_seuils', nom)

pierre_calcaire('pierre_calcaire')
granit('granit_gris')
beton('beton_lisse')
ar = np.ones((N, N, 3)) * rgb((214, 198, 168))
ar += bruit(64, 12)[..., None]
sauve(ar, 'appuis_seuils', 'pierre_reconstituee')

# ---- Ajouts : parements (pierre, brique) et bardages bois
def parement_pierre(nom):
    im = Image.new('RGB', (N, N), (150, 140, 124))
    d = ImageDraw.Draw(im)
    y = 0
    while y < N:
        h = int(rng.integers(40, 80))
        x = -int(rng.integers(0, 80))
        while x < N:
            w = int(rng.integers(70, 150))
            t = rng.uniform(0.8, 1.15)
            c = tuple(int(min(255, v * t)) for v in (196, 184, 160))
            d.rectangle([x, y, x + w - 4, y + h - 4], fill=c)
            x += w
        y += h
    arr = np.asarray(im.filter(ImageFilter.GaussianBlur(0.5))).astype(float) + bruit(160, 14)[..., None]
    sauve(arr, 'parements', nom)

def brique(nom):
    im = Image.new('RGB', (N, N), (200, 196, 186))  # joint
    d = ImageDraw.Draw(im)
    for r, y in enumerate(range(0, N, 32)):
        dec = 0 if r % 2 == 0 else 50
        for x in range(-100 + dec, N + 100, 100):
            t = rng.uniform(0.85, 1.1)
            c = tuple(int(min(255, v * t)) for v in (168, 84, 60))
            d.rectangle([x + 2, y + 2, x + 96, y + 28], fill=c)
    arr = np.asarray(im.filter(ImageFilter.GaussianBlur(0.4))).astype(float) + bruit(160, 12)[..., None]
    sauve(arr, 'parements', nom)

def lames(couleur, nuance, nom, horizontal=False):
    im = Image.new('RGB', (N, N), couleur)
    d = ImageDraw.Draw(im)
    pas = 64
    for i in range(0, N, pas):
        t = 1 + rng.uniform(-nuance, nuance)
        c = tuple(int(min(255, v * t)) for v in couleur)
        if horizontal:
            d.rectangle([0, i, N, i + pas - 2], fill=c)
            d.line([0, i + pas - 1, N, i + pas - 1], fill=tuple(int(v * 0.5) for v in c), width=2)
        else:
            d.rectangle([i, 0, i + pas - 2, N], fill=c)
            d.line([i + pas - 1, 0, i + pas - 1, N], fill=tuple(int(v * 0.5) for v in c), width=2)
    arr = np.asarray(im).astype(float) + bruit(256, 14)[..., None]
    sauve(arr, 'bardages', nom)

parement_pierre('parement_pierre_irreguliere')
brique('brique_apparente')
lames((168, 120, 74), 0.08, 'bardage_meleze_vertical')
lames((150, 110, 70), 0.10, 'bardage_douglas_vertical')
lames((120, 80, 50), 0.12, 'lames_terrasse_horizontal', horizontal=True)
print('ok zinguerie, appuis, parements, bardages')
