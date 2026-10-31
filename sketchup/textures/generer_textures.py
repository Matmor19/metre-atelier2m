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
