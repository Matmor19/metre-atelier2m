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
icones['verif_objet'] = CUBE() + f'<circle cx="17.4" cy="17.4" r="5" fill="{O}" stroke="#fff" stroke-width="0.8"/><path d="M14.8 17.5 L16.7 19.4 L20 15.6" fill="none" stroke="#fff" stroke-width="1.5" stroke-linecap="round" stroke-linejoin="round"/>'
icones['palette'] = f'<rect x="3.5" y="4" width="17" height="16" rx="1.5" fill="#FFFFFF" {st()}/><rect x="3.5" y="4" width="5.2" height="16" rx="1.2" fill="{O}" {st()}/><rect x="10.5" y="6.4" width="3.6" height="3.6" fill="#F9DCC0" {st(0.6)}/><rect x="15.4" y="6.4" width="3.6" height="3.6" fill="#F9DCC0" {st(0.6)}/><rect x="10.5" y="11.6" width="3.6" height="3.6" fill="#F9DCC0" {st(0.6)}/><rect x="15.4" y="11.6" width="3.6" height="3.6" fill="#F9DCC0" {st(0.6)}/><path d="M10.5 17.6 H19" stroke="{D}" stroke-width="0.6" stroke-linecap="round"/>'
icones['styles'] = (f'<path d="M12 3.5 L19.5 7.8 L12 12.1 L4.5 7.8 Z" fill="#FFFFFF" {st()}/><path d="M4.5 7.8 L12 12.1 V20.5 L4.5 16.2 Z" fill="#F4B988" {st()}/><path d="M12 12.1 L19.5 7.8 V16.2 L12 20.5 Z" fill="#8F8F8F" {st()}/>'
                    f'<path d="M16.8 10 L18.6 9 M16.8 12.4 L18.6 11.4 M16.8 14.8 L18.6 13.8" stroke="#fff" stroke-width="0.5"/><circle cx="19.3" cy="4.8" r="1.3" fill="{O}"/>')
def carte(x, y, c1, c2): return f'<rect x="{x}" y="{y}" width="8.2" height="8.2" rx="1" fill="#fff" {st(0.6)}/><rect x="{x+1.4}" y="{y+1.4}" width="2.4" height="5.4" fill="{c1}"/><rect x="{x+4.4}" y="{y+1.4}" width="2.4" height="5.4" fill="{c2}"/>'
icones['compositions'] = carte(3, 3, '#C9C9C9', '#FAE08C') + carte(12.8, 3, '#FAE08C', '#E9A06A') + carte(3, 12.8, '#E9A06A', '#C9C9C9') + carte(12.8, 12.8, '#C9C9C9', '#FAE08C') + f'<circle cx="19.6" cy="19.6" r="3.2" fill="{O}" stroke="#fff" stroke-width="0.7"/><path d="M18.2 19.6 H21 M19.6 18.2 V21" stroke="#fff" stroke-width="1.1" stroke-linecap="round"/>'
import cairosvg
for n, corps in icones.items():
    open(os.path.join(ici, 'icones', n + '.svg'), 'w', encoding='utf-8').write(TUILE + corps + '</svg>')
    svg = os.path.join(ici, 'icones', n + '.svg')
    for t in (16, 24, 32):
        cairosvg.svg2png(url=svg, write_to=os.path.join(ici, 'icones', '%s_%d.png' % (n, t)), output_width=t, output_height=t)
    cairosvg.svg2pdf(url=svg, write_to=os.path.join(ici, 'icones', n + '.pdf'))
print('ok', list(icones))
