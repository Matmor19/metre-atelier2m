# Pictogrammes redessinés (mur, modifier un mur, contrôler un objet, palette, styles) : même tuile, même trait que les autres
import os
ici = os.path.dirname(os.path.abspath(__file__))
TUILE = '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 24 24" width="24" height="24">\n<rect x="0.75" y="0.75" width="22.5" height="22.5" rx="3.5" fill="#F9DCC0" stroke="#9C8F84" stroke-width="0.6"/>\n'
D = '#3C3C3C'; O = '#E07838'
def st(w=0.7): return f'stroke="{D}" stroke-width="{w}" stroke-linejoin="round" stroke-linecap="round"'
L_MUR = 'M3.5 5 H20.5 V10.5 H9 V19 H3.5 Z'
HACHURE = '<clipPath id="m"><path d="%s"/></clipPath><g clip-path="url(#m)"><path d="M-2 14 L12 0 M0 20 L20 0 M4 24 L24 4 M8 26 L28 6" stroke="#9C8F84" stroke-width="0.5"/></g>' % L_MUR
def mur_base(): return f'<path d="{L_MUR}" fill="#FFFFFF" {st()}/>' + HACHURE + f'<path d="{L_MUR}" fill="none" {st()}/>'
def badge_plus(cx, cy): return f'<circle cx="{cx}" cy="{cy}" r="4.6" fill="{O}" stroke="#fff" stroke-width="0.8"/><path d="M{cx-2.2} {cy} H{cx+2.2} M{cx} {cy-2.2} V{cy+2.2}" stroke="#fff" stroke-width="1.4" stroke-linecap="round"/>'
def poignee(x, y): return f'<rect x="{x-1.5}" y="{y-1.5}" width="3" height="3" fill="{O}" stroke="#fff" stroke-width="0.6"/>'
CRAYON = f'<path d="M12.6 21.6 L13.4 18.4 L19.8 12 L22.2 14.4 L15.8 20.8 Z" fill="{O}" {st(0.6)}/><path d="M12.6 21.6 L13.4 18.4 L15.8 20.8 Z" fill="#fff" {st(0.5)}/>'
CUBE = lambda dx=0, dy=0: (f'<path d="M12 3.5 L19.5 7.8 L12 12.1 L4.5 7.8 Z" fill="#FFFFFF" {st()}/><path d="M4.5 7.8 L12 12.1 V20.5 L4.5 16.2 Z" fill="#FFFFFF" {st()}/><path d="M12 12.1 L19.5 7.8 V16.2 L12 20.5 Z" fill="#E9E4DE" {st()}/>')
icones = {}
icones['mur'] = mur_base() + badge_plus(17.6, 17.4)
icones['modifier_mur'] = mur_base() + poignee(3.5, 5) + poignee(20.5, 5) + poignee(3.5, 19) + CRAYON
icones['modifier_toiture'] = (f'<path d="M3 12 L12 4 L21 12 Z" fill="{O}" opacity=".55"/><path d="M3 12 L12 4 L21 12" fill="none" {st(0.9)}/><rect x="6" y="12" width="12" height="7.5" fill="#FFFFFF" {st()}/>'
                              + poignee(3, 12) + poignee(12, 4) + poignee(21, 12) + CRAYON)
icones['modifier_ouverture'] = (f'<rect x="3.5" y="4" width="17" height="16" fill="#FFFFFF" {st()}/><rect x="8" y="8" width="8" height="8" fill="#BFD9EA" {st(0.8)}/>'
                                + poignee(8, 8) + poignee(16, 8) + poignee(8, 16) + poignee(16, 16) + CRAYON)
icones['modifier'] = (CUBE() + poignee(4.5, 7.8) + poignee(19.5, 7.8) + poignee(12, 20.5) + CRAYON)
icones['cloison'] = (f'<path d="M3 20 L21 20" {st(0.8)}/><rect x="9" y="4" width="2.6" height="14" fill="#FFFFFF" {st()}/><rect x="11.6" y="4" width="1.6" height="14" fill="{O}" opacity=".55" {st(0.7)}/><rect x="13.2" y="4" width="2.6" height="14" fill="#FFFFFF" {st()}/>'
                     + '<path d="M5 9 L8 9 M5 13 L8 13" ' + st(0.8) + '/><path d="M17.5 9 L20 9 M17.5 13 L20 13" ' + st(0.8) + '/>')
icones['fusionner_cloisons'] = (f'<path d="M3 20 L21 20" {st(0.8)}/><rect x="4" y="9" width="16" height="3" fill="#FFFFFF" {st()}/><rect x="10.5" y="9" width="3" height="10" fill="#FFFFFF" {st()}/><rect x="10.8" y="9.4" width="2.4" height="2.2" fill="{O}" opacity=".7"/>')
icones['verif_objet'] = CUBE() + f'<circle cx="17.4" cy="17.4" r="5" fill="{O}" stroke="#fff" stroke-width="0.8"/><path d="M14.8 17.5 L16.7 19.4 L20 15.6" fill="none" stroke="#fff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
icones['palette'] = f'<rect x="3.5" y="4" width="17" height="16" rx="1.5" fill="#FFFFFF" {st()}/><rect x="3.5" y="4" width="5.2" height="16" rx="1.2" fill="{O}" {st()}/><rect x="10.5" y="6.4" width="3.6" height="3.6" fill="#F9DCC0" {st(0.6)}/><rect x="15.4" y="6.4" width="3.6" height="3.6" fill="#F9DCC0" {st(0.6)}/><rect x="10.5" y="11.6" width="3.6" height="3.6" fill="#F9DCC0" {st(0.6)}/><rect x="15.4" y="11.6" width="3.6" height="3.6" fill="#F9DCC0" {st(0.6)}/><path d="M10.5 17.6 H19" stroke="{D}" stroke-width="0.6" stroke-linecap="round"/>'
icones['styles'] = (f'<path d="M12 3.5 L19.5 7.8 L12 12.1 L4.5 7.8 Z" fill="#FFFFFF" {st()}/><path d="M4.5 7.8 L12 12.1 V20.5 L4.5 16.2 Z" fill="#F4B988" {st()}/><path d="M12 12.1 L19.5 7.8 V16.2 L12 20.5 Z" fill="#8F8F8F" {st()}/>'
                    f'<path d="M16.8 10 L18.6 9 M16.8 12.4 L18.6 11.4 M16.8 14.8 L18.6 13.8" stroke="#fff" stroke-width="0.5"/><circle cx="19.3" cy="4.8" r="1.3" fill="{O}"/>')
def carte(x, y, c1, c2): return f'<rect x="{x}" y="{y}" width="8.2" height="8.2" rx="1" fill="#fff" {st(0.6)}/><rect x="{x+1.4}" y="{y+1.4}" width="2.4" height="5.4" fill="{c1}"/><rect x="{x+4.4}" y="{y+1.4}" width="2.4" height="5.4" fill="{c2}"/>'
icones['compositions'] = carte(3, 3, '#C9C9C9', '#FAE08C') + carte(12.8, 3, '#FAE08C', '#E9A06A') + carte(3, 12.8, '#E9A06A', '#C9C9C9') + carte(12.8, 12.8, '#C9C9C9', '#FAE08C') + f'<circle cx="19.6" cy="19.6" r="3.2" fill="{O}" stroke="#fff" stroke-width="0.7"/><path d="M18.2 19.6 H21 M19.6 18.2 V21" stroke="#fff" stroke-width="1.1" stroke-linecap="round"/>'
icones['niveaux'] = (f'<rect x="9" y="3.5" width="4" height="17" fill="#FFFFFF" {st()}/>' + f'<path d="M3.5 7 H20.5" stroke="#3E8EDE" stroke-width="0.9" stroke-dasharray="2 1"/>' + f'<path d="M3.5 12 H20.5" stroke="{O}" stroke-width="1.5"/>' + f'<path d="M3.5 17 H20.5" stroke="#2E9E6B" stroke-width="0.9" stroke-dasharray="2 1"/>' + f'<path d="M4 12 L6.6 10.4 V13.6 Z" fill="{O}"/><path d="M4 7 L6.4 5.6 V8.4 Z" fill="#3E8EDE"/><path d="M4 17 L6.4 15.6 V18.4 Z" fill="#2E9E6B"/>' + f'<path d="M18.5 7.5 V11.5 M17.2 9 L18.5 7.5 L19.8 9" fill="none" {st(0.8)}/>')
icones['ferraillage'] = (f'<rect x="3.5" y="5" width="17" height="14" fill="#FFFFFF" {st()}/><rect x="6" y="7.5" width="12" height="9" fill="none" stroke="{O}" stroke-width="1.1"/>'
    + ''.join(f'<circle cx="{x}" cy="{y}" r="1.1" fill="{O}" stroke="{D}" stroke-width="0.4"/>' for x, y in ((6,16.5),(12,16.5),(18,16.5),(6,7.5),(18,7.5))))
# --- pictogrammes en perspective (objets reconnaissables au premier coup d'oeil) ---
import math
def iso(x, y, z, cx=12, cy=15, k=2.6): return (cx + (x - y) * 0.866 * k, cy + (x + y) * 0.5 * k - z * k)
def poly(pts, fill, w=0.7): return '<path d="M' + ' L'.join('%.2f %.2f' % p for p in pts) + f' Z" fill="{fill}" {st(w)}/>'
def boite(x0, y0, z0, x1, y1, z1, haut='#FFFFFF', gauche='#EDE7E0', droite='#C9C2BA', cx=12, cy=15, k=2.6):
    P = lambda x, y, z: iso(x, y, z, cx, cy, k)
    return (poly([P(x0, y1, z1), P(x1, y1, z1), P(x1, y1, z0), P(x0, y1, z0)], gauche)
            + poly([P(x1, y0, z1), P(x1, y1, z1), P(x1, y1, z0), P(x1, y0, z0)], droite)
            + poly([P(x0, y0, z1), P(x1, y0, z1), P(x1, y1, z1), P(x0, y1, z1)], haut))
def ligne(a, b, c=O, w=0.9): return f'<path d="M{a[0]:.2f} {a[1]:.2f} L{b[0]:.2f} {b[1]:.2f}" stroke="{c}" stroke-width="{w}" stroke-linecap="round" fill="none"/>'
# escalier : 4 marches vues en perspective
icones['escalier'] = ''.join(boite(k, 0, 0, k + 1, 3, 4 - k, cx=9, cy=9, k=2.4) for k in range(4))
# fondation : semelle filante + mur au-dessus
icones['fondation'] = boite(0, 0, 0, 5, 2.2, 0.9, haut='#D9D4CE', cx=6, cy=12.5, k=2.2) + boite(0.7, 0.6, 0.9, 4.3, 1.6, 3.4, cx=6, cy=12.5, k=2.2) + f'<path d="M3 21 H21" stroke="{D}" stroke-width="0.6" stroke-dasharray="1.6 1.2"/>'
# ferraillage : cage d'armature (4 barres longues + cadres)
def cage():
    P = lambda x, y, z: iso(x, y, z, 7, 14.5, 2.3)
    o = ''
    for (x, y) in ((0, 0), (0, 1.6), (4, 0), (4, 1.6)): pass
    haut = [(0, 0), (1.6, 0), (1.6, 1.6), (0, 1.6)]
    for (x, y) in haut[:1] + haut[3:] + haut[1:3]:
        o += ligne(P(x, y, 0), P(x, y, 4), D, 0.9)
    for z in (0.2, 1.4, 2.6, 3.8):
        o += poly([P(0, 0, z), P(1.6, 0, z), P(1.6, 1.6, z), P(0, 1.6, z)], 'none', 0.6).replace('stroke="%s"' % D, 'stroke="%s"' % O)
    return o
icones['ferraillage'] = f'<g transform="translate(5.5,2)">' + cage().replace('stroke="#3C3C3C"', 'stroke="#3C3C3C"') + '</g>' + f'<path d="M3 20 H21" stroke="{D}" stroke-width="0.6"/>'
# toiture : maison à deux pentes en perspective
def toit():
    P = lambda x, y, z: iso(x, y, z, 12, 15, 2.3)
    o = boite(0, 0, 0, 3.6, 3.6, 2.6, cx=12, cy=17, k=2.3)
    pg = [P(0, 3.6, 2.6), P(3.6, 3.6, 2.6)]
    return o
icones['toiture'] = (poly([(5, 20), (5, 12), (14, 12), (14, 20)], '#EDE7E0') + poly([(14, 12), (20, 9.5), (20, 17.5), (14, 20)], '#C9C2BA')
    + poly([(3, 12.4), (9.5, 4.5), (15.5, 4.5), (21.5, 9.6), (14, 12.4)], '#E9A06A') + poly([(3, 12.4), (14, 12.4), (21.5, 9.6)], 'none', 0.7)
    + poly([(14, 12.4), (21.5, 9.6), (21.5, 11.2), (14, 14)], '#D88A55'))
# garde-corps : trois poteaux, lisse haute et barreaux
def gc():
    P = lambda x, y, z: iso(x, y, z, 5, 11, 2.6)
    o = ''
    for x in (0, 2, 4):
        o += ligne(P(x, 0, 0), P(x, 0, 3), D, 1.2)
    for x in (0.67, 1.33, 2.67, 3.33):
        o += ligne(P(x, 0, 0.4), P(x, 0, 2.8), D, 0.5)
    o += ligne(P(0, 0, 3), P(4, 0, 3), O, 1.6) + ligne(P(0, 0, 0.3), P(4, 0, 0.3), D, 0.7)
    return o
icones['gardecorps'] = '<g transform="translate(0,2)">' + gc() + '</g>'
# détail / présentation : cube plein à gauche, cube transparent avec barres à droite
icones['mode_vue'] = (boite(0, 0, 0, 2.2, 2.2, 2.2, cx=6.5, cy=14, k=2.3)
    + poly([iso(0, 0, 2.2, 17, 14, 2.3), iso(2.2, 0, 2.2, 17, 14, 2.3), iso(2.2, 2.2, 2.2, 17, 14, 2.3), iso(0, 2.2, 2.2, 17, 14, 2.3)], 'none', 0.7)
    + poly([iso(0, 2.2, 2.2, 17, 14, 2.3), iso(2.2, 2.2, 2.2, 17, 14, 2.3), iso(2.2, 2.2, 0, 17, 14, 2.3), iso(0, 2.2, 0, 17, 14, 2.3)], 'none', 0.7)
    + poly([iso(2.2, 0, 2.2, 17, 14, 2.3), iso(2.2, 2.2, 2.2, 17, 14, 2.3), iso(2.2, 2.2, 0, 17, 14, 2.3), iso(2.2, 0, 0, 17, 14, 2.3)], 'none', 0.7)
    + ligne(iso(0.6, 1.1, 0.5, 17, 14, 2.3), iso(1.6, 1.1, 0.5, 17, 14, 2.3), O, 1.1) + ligne(iso(0.6, 1.1, 1.6, 17, 14, 2.3), iso(1.6, 1.1, 1.6, 17, 14, 2.3), O, 1.1))
import cairosvg
for n, corps in icones.items():
    open(os.path.join(ici, 'icones', n + '.svg'), 'w', encoding='utf-8').write(TUILE + corps + '</svg>')
    svg = os.path.join(ici, 'icones', n + '.svg')
    for t in (16, 24, 32):
        cairosvg.svg2png(url=svg, write_to=os.path.join(ici, 'icones', '%s_%d.png' % (n, t)), output_width=t, output_height=t)
    cairosvg.svg2pdf(url=svg, write_to=os.path.join(ici, 'icones', n + '.pdf'))
print('ok', list(icones))
