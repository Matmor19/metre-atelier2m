# Notice d'utilisation : générée à partir des outils réellement déclarés (build_rbz.py), de la palette, de notice_details.json
# et de nouveautes.json. Appelée par build_rbz.py : elle est donc toujours à jour de la version construite.
import re, json, os, html
ici = os.path.dirname(os.path.abspath(__file__))
def lire(f): return open(os.path.join(ici, f), encoding='utf-8').read()
def propre(t): return t.replace("\\'", "'")

def generer():
    b = lire('build_rbz.py')
    outils = {a: (propre(t), propre(bl)) for a, t, bl in re.findall(r"^\s*\['(\w+)',\s+'((?:[^'\\]|\\.)*)',\s+'((?:[^'\\]|\\.)*)'", b, re.M)}
    pal = lire('palette.rb')
    groupes = re.findall(r"\['([^']+)',\s+%w\[([^\]]+)\]\]", pal)
    det = json.load(open(os.path.join(ici, 'notice_details.json'), encoding='utf-8'))
    nouv = json.load(open(os.path.join(ici, 'nouveautes.json'), encoding='utf-8'))
    version = re.search(r"EXT\.version = '([^']+)'", lire('a2m_metre_chargeur.rb')).group(1)
    vus = set(); md = [f"# Métré Atelier 2M — notice d'utilisation (version {version})\n",
        "Notice générée automatiquement à chaque version : chaque bouton de la palette y figure, avec son rôle et, quand il est détaillé, la marche à suivre.\n"]
    h = [f"<h1>Métré Atelier 2M — notice d'utilisation</h1><p class='v'>Version {version}</p>"]
    for titre, ids in groupes:
        md.append(f"\n## {titre}\n"); h.append(f"<h2>{html.escape(titre)}</h2>")
        for i in ids.split():
            if i not in outils: continue
            vus.add(i); t, bl = outils[i]
            md.append(f"### {t}\n{bl}\n")
            h.append(f"<section><h3>{html.escape(t)}</h3><p>{html.escape(bl)}</p>")
            if i in det:
                md.extend(f"- {l}" for l in det[i]); md.append('')
                h.append('<ul>' + ''.join(f"<li>{html.escape(l)}</li>" for l in det[i]) + '</ul>')
            h.append('</section>')
    reste = [i for i in outils if i not in vus]
    if reste:
        md.append("\n## Autres commandes (menu Extensions)\n"); h.append('<h2>Autres commandes (menu Extensions)</h2>')
        for i in reste:
            t, bl = outils[i]; md.append(f"### {t}\n{bl}\n"); h.append(f"<section><h3>{html.escape(t)}</h3><p>{html.escape(bl)}</p></section>")
    md.append("\n## Dernières nouveautés\n"); h.append('<h2>Dernières nouveautés</h2><ul>')
    for n in nouv[:20]:
        md.append(f"- {n}"); h.append(f"<li>{html.escape(n)}</li>")
    h.append('</ul>')
    open(os.path.join(ici, 'NOTICE.md'), 'w', encoding='utf-8').write('\n'.join(md) + '\n')
    css = ("<style>:root{--bg:#faf6f1;--tx:#3c3c3c;--ac:#c9672f;--card:#fff;--bd:#e6dccf}@media(prefers-color-scheme:dark){:root{--bg:#1d1b19;--tx:#e8e2da;--ac:#e8925c;--card:#2a2724;--bd:#3d3833}}"
           "body{margin:0;background:var(--bg);color:var(--tx);font:15px/1.55 'Segoe UI',Arial,sans-serif}main{max-width:820px;margin:0 auto;padding:24px 16px}"
           "h1{font-size:26px;margin:0}.v{color:var(--ac);margin:4px 0 24px}h2{color:var(--ac);border-bottom:1px solid var(--bd);padding-bottom:6px;margin-top:36px}"
           "section{background:var(--card);border:1px solid var(--bd);border-radius:10px;padding:12px 16px;margin:12px 0}h3{margin:0 0 4px;font-size:16px}section p{margin:0 0 6px}ul{margin:6px 0 0;padding-left:20px}li{margin:3px 0}</style>")
    open(os.path.join(ici, 'notice.html'), 'w', encoding='utf-8').write(
        "<!doctype html><html lang='fr'><head><meta charset='utf-8'><meta name='viewport' content='width=device-width,initial-scale=1'><title>Notice Atelier 2M</title>" + css + "</head><body><main>" + ''.join(h) + "</main></body></html>")
    sans = [i for i in outils if i not in det]
    print('notice : %d outils, %d avec marche à suivre ; à détailler : %s' % (len(outils), len(det), ', '.join(sans[:12]) + ('…' if len(sans) > 12 else '')))

if __name__ == '__main__':
    generer()
