#!/usr/bin/env python3
"""Builds the guide pages of the website from guides/*.html into docs/.

Each source file starts with a JSON header in an HTML comment:
  <!-- {"slug": "...", "lang": "en", "title": "...", "description": "...", "h1": "...",
        "updated": "2026-11-08", "read": "5 min", "pair": "<slug of the other-language version>",
        "order": <position in lists>} -->
followed by the article body. The script adds the page frame, JSON-LD (Article, BreadcrumbList,
FAQPage from <section class="faq-block">, HowTo from <ol class="howto">), related guides,
the guides index pages, sitemap.xml and the guide list in llms.txt.

Run: python3 Tools/build-guides.py
"""
import html
import json
import re
from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
SRC = ROOT / "guides"
DOCS = ROOT / "docs"
SITE = "https://claudimoret.github.io/youtube-music-mac/"
DOWNLOAD = "https://github.com/claudimoret/youtube-music-mac/releases/latest/download/Tubemac.zip"

T = {
    "en": {
        "home": "Tubemac", "guides": "Guides", "guides_url": "guides/", "other_lang": ("Deutsch", "de/", "de"),
        "support": "♥ Support", "support_url": "#support", "updated": "Updated", "read": "read",
        "related": "More guides", "cta_title": "Want YouTube Music to feel like a real Mac app?",
        "cta_text": "Tubemac is a free, 1 MB YouTube Music app for Mac – edge-to-edge design, media keys, Control Center and background playback. Apple Silicon &amp; Intel, macOS 14+.",
        "cta_btn": "Download Tubemac – free", "cta_more": "Take the tour",
        "hub_title": "YouTube Music on Mac – Guides &amp; How-tos",
        "hub_desc": "Practical guides for using YouTube Music on a Mac: apps, media keys, background playback, Dock, Apple Silicon, shortcuts and sign-in.",
        "hub_lead": "Everything you need to get YouTube Music working nicely on your Mac – written for everyday Mac users, kept up to date.",
        "footer": "Unofficial. YouTube Music is a trademark of Google LLC. Tubemac is not affiliated with Google. Other app names belong to their respective projects.",
    },
    "de": {
        "home": "Tubemac", "guides": "Ratgeber", "guides_url": "de/ratgeber/", "other_lang": ("English", "", "en"),
        "support": "♥ Unterstützen", "support_url": "de/#spenden", "updated": "Aktualisiert", "read": "Lesezeit",
        "related": "Weitere Ratgeber", "cta_title": "YouTube Music als echte Mac-App?",
        "cta_text": "Tubemac ist eine kostenlose YouTube Music App für den Mac (1 MB) – randloses Design, Mediatasten, Kontrollzentrum und Wiedergabe im Hintergrund. Apple Silicon &amp; Intel, ab macOS 14.",
        "cta_btn": "Tubemac kostenlos laden", "cta_more": "Tour ansehen",
        "hub_title": "YouTube Music auf dem Mac – Ratgeber &amp; Anleitungen",
        "hub_desc": "Anleitungen rund um YouTube Music auf dem Mac: Apps im Vergleich, Tastenkürzel, Apps trotz Warnung öffnen und mehr.",
        "hub_lead": "Alles, damit YouTube Music auf deinem Mac rund läuft – verständlich erklärt für ganz normale Mac-Nutzer.",
        "footer": "Inoffiziell. YouTube Music ist eine Marke der Google LLC. Tubemac steht in keiner Verbindung zu Google. Andere App-Namen gehören den jeweiligen Projekten.",
    },
}

MODAL = {
    "en": '''<div class="modal" id="thanks" role="dialog" aria-modal="true" aria-labelledby="thanks-title">
  <div class="box">
    <button class="close" type="button" aria-label="Close" data-close>✕</button>
    <img src="{a}icon.png" alt="" width="72" height="72">
    <h3 id="thanks-title">Thanks for downloading Tubemac! 🎧</h3>
    <p>Your download has started.</p>
    <div class="next"><ol>
      <li>Open <strong>Tubemac.zip</strong> and drag <strong>Tubemac</strong> into <strong>Applications</strong>.</li>
      <li>First launch: <strong>System Settings → Privacy &amp; Security → Open Anyway</strong>.</li>
    </ol></div>
    <p class="tip">Tubemac is free. If you like it, a small tip keeps it going ♥</p>
    <div class="amounts">
      <a class="amount" href="https://www.paypal.com/paypalme/morrret/1EUR" target="_blank" rel="noopener">1 €</a>
      <a class="amount" href="https://www.paypal.com/paypalme/morrret/2EUR" target="_blank" rel="noopener">2 €</a>
      <a class="amount" href="https://www.paypal.com/paypalme/morrret/5EUR" target="_blank" rel="noopener">5 €</a>
    </div>
    <button class="later" type="button" data-close>Maybe later</button>
  </div>
</div>''',
    "de": '''<div class="modal" id="thanks" role="dialog" aria-modal="true" aria-labelledby="thanks-title">
  <div class="box">
    <button class="close" type="button" aria-label="Schließen" data-close>✕</button>
    <img src="{a}icon.png" alt="" width="72" height="72">
    <h3 id="thanks-title">Danke fürs Herunterladen! 🎧</h3>
    <p>Dein Download hat begonnen.</p>
    <div class="next"><ol>
      <li><strong>Tubemac.zip</strong> öffnen und <strong>Tubemac</strong> in <strong>Programme</strong> ziehen.</li>
      <li>Beim ersten Start: <strong>Systemeinstellungen → Datenschutz &amp; Sicherheit → „Dennoch öffnen“</strong>.</li>
    </ol></div>
    <p class="tip">Tubemac ist kostenlos. Gefällt sie dir, hilft eine kleine Spende ♥</p>
    <div class="amounts">
      <a class="amount" href="https://www.paypal.com/paypalme/morrret/1EUR" target="_blank" rel="noopener">1 €</a>
      <a class="amount" href="https://www.paypal.com/paypalme/morrret/2EUR" target="_blank" rel="noopener">2 €</a>
      <a class="amount" href="https://www.paypal.com/paypalme/morrret/5EUR" target="_blank" rel="noopener">5 €</a>
    </div>
    <button class="later" type="button" data-close>Vielleicht später</button>
  </div>
</div>''',
}


def text(fragment):
    return re.sub(r"\s+", " ", html.unescape(re.sub(r"<[^>]+>", "", fragment))).strip()


def load():
    guides = []
    for f in sorted(SRC.glob("*.html")):
        raw = f.read_text()
        m = re.match(r"\s*<!--(.*?)-->\s*", raw, re.S)
        meta = json.loads(m.group(1))
        meta["body"] = raw[m.end():].strip()
        meta["path"] = (meta["slug"] + "/") if meta["lang"] == "en" else f"de/{meta['slug']}/"
        meta["url"] = SITE + meta["path"]
        guides.append(meta)
    return sorted(guides, key=lambda g: (g.get("order", 99), g["slug"]))


def jsonld(g, t):
    graph = [
        {
            "@type": "Article",
            "headline": g["h1"],
            "description": g["description"],
            "inLanguage": g["lang"],
            "datePublished": g.get("published", g["updated"]),
            "dateModified": g["updated"],
            "author": {"@type": "Person", "name": "claudimoret", "url": "https://github.com/claudimoret"},
            "publisher": {"@type": "Organization", "name": "Tubemac",
                          "logo": {"@type": "ImageObject", "url": SITE + "assets/icon.png"}},
            "image": SITE + "assets/screenshot-artist.png",
            "mainEntityOfPage": g["url"],
            "about": {"@id": SITE + "#app"},
        },
        {
            "@type": "BreadcrumbList",
            "itemListElement": [
                {"@type": "ListItem", "position": 1, "name": "Tubemac",
                 "item": SITE + ("de/" if g["lang"] == "de" else "")},
                {"@type": "ListItem", "position": 2, "name": text(t["guides"]), "item": SITE + t["guides_url"]},
                {"@type": "ListItem", "position": 3, "name": g["h1"], "item": g["url"]},
            ],
        },
    ]
    faq = re.search(r'<section class="faq-block">(.*?)</section>', g["body"], re.S)
    if faq:
        pairs = re.findall(r"<h3>(.*?)</h3>\s*<p>(.*?)</p>", faq.group(1), re.S)
        graph.append({"@type": "FAQPage", "mainEntity": [
            {"@type": "Question", "name": text(q), "acceptedAnswer": {"@type": "Answer", "text": text(a)}}
            for q, a in pairs]})
    howto = re.search(r'<ol class="howto"[^>]*data-name="([^"]+)"[^>]*>(.*?)</ol>', g["body"], re.S)
    if howto:
        steps = re.findall(r"<li>(.*?)</li>", howto.group(2), re.S)
        graph.append({"@type": "HowTo", "name": html.unescape(howto.group(1)), "step": [
            {"@type": "HowToStep", "position": i + 1, "text": text(s)} for i, s in enumerate(steps)]})
    return json.dumps({"@context": "https://schema.org", "@graph": graph}, ensure_ascii=False, indent=2)


def frame(g_lang, depth, title, description, canonical, body, head_extra="", ld="", og_type="article"):
    t = T[g_lang]
    up = "../" * depth
    other_label, other_path, other_code = t["other_lang"]
    return f'''<!doctype html>
<html lang="{g_lang}">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>{title}</title>
<meta name="description" content="{description}">
<link rel="canonical" href="{canonical}">
{head_extra}<meta name="theme-color" content="#08060a">
<link rel="icon" type="image/png" href="{up}assets/favicon.png">
<link rel="apple-touch-icon" href="{up}assets/apple-touch-icon.png">
<link rel="stylesheet" href="{up}assets/site.css">
<meta property="og:type" content="{og_type}">
<meta property="og:site_name" content="Tubemac">
<meta property="og:title" content="{title}">
<meta property="og:description" content="{description}">
<meta property="og:url" content="{canonical}">
<meta property="og:image" content="{SITE}assets/og-image.png">
<meta name="twitter:card" content="summary_large_image">
{('<script type="application/ld+json">' + chr(10) + ld + chr(10) + '</script>') if ld else ''}
</head>
<body>

<div style="position:relative">
  <div class="glow" aria-hidden="true"></div>
  <header class="top wrap">
    <a class="brand" href="{up}{'de/' if g_lang == 'de' else ''}"><img src="{up}assets/favicon.png" alt="" width="36" height="36">Tubemac</a>
    <nav class="links">
      <a href="{up}{t['guides_url']}">{t['guides']}</a>
      <a href="{up}{other_path}" hreflang="{other_code}" lang="{other_code}">{other_label}</a>
      <a class="heart" href="{up}{t['support_url']}">{t['support']}</a>
    </nav>
  </header>
{body}
</div>

<footer>
  <div class="wrap row">
    <span><a href="{up}{'de/' if g_lang == 'de' else ''}">Tubemac</a> · <a href="{up}{t['guides_url']}">{t['guides']}</a> · <a href="https://github.com/claudimoret/youtube-music-mac">GitHub</a> · <a href="{up}{t['support_url']}">{t['support']}</a></span>
    <span>{t['footer']}</span>
  </div>
</footer>

{MODAL[g_lang].replace('{a}', up + 'assets/')}
<script src="{up}assets/site.js" defer></script>
</body>
</html>
'''


def build_guide(g, guides):
    t = T[g["lang"]]
    depth = g["path"].count("/")
    up = "../" * depth
    related = [o for o in guides if o["lang"] == g["lang"] and o["slug"] != g["slug"]]
    rel_html = "".join(f'<li><a href="{up}{o["path"]}">{o["h1"]}</a></li>' for o in related)
    head_extra = ""
    pair = next((o for o in guides if g.get("pair") and o["slug"] == g["pair"] and o["lang"] != g["lang"]), None)
    if pair:
        head_extra = (f'<link rel="alternate" hreflang="{g["lang"]}" href="{g["url"]}">\n'
                      f'<link rel="alternate" hreflang="{pair["lang"]}" href="{pair["url"]}">\n')
    body = f'''  <article class="doc">
    <p class="crumbs"><a href="{up}{'de/' if g['lang'] == 'de' else ''}">Tubemac</a> › <a href="{up}{t['guides_url']}">{t['guides']}</a></p>
    <h1>{g['h1']}</h1>
    <p class="updated">{t['updated']} {g['updated_label']} · {g['read']} {t['read'] if g['lang'] == 'en' else ''}</p>
{g['body']}
    <div class="cta-box">
      <img src="{up}assets/icon.png" alt="" width="64" height="64">
      <div>
        <h2>{t['cta_title']}</h2>
        <p>{t['cta_text']}</p>
        <p class="cta-row"><a class="btn btn-primary" data-download href="{DOWNLOAD}">{t['cta_btn']}</a> <a class="btn btn-ghost" href="{up}{'de/' if g['lang'] == 'de' else ''}#tour">{t['cta_more']}</a></p>
      </div>
    </div>
    <h2>{t['related']}</h2>
    <ul class="related">{rel_html}</ul>
  </article>'''
    out = DOCS / g["path"] / "index.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(frame(g["lang"], depth, g["title"], g["description"], g["url"], body, head_extra, jsonld(g, t)))


def build_hub(lang, guides):
    t = T[lang]
    path = t["guides_url"]
    depth = path.count("/")
    up = "../" * depth
    items = "".join(
        f'<a class="guide-card" href="{up}{g["path"]}"><h2>{g["h1"]}</h2><p>{g["description"]}</p></a>'
        for g in guides if g["lang"] == lang)
    body = f'''  <article class="doc" style="max-width:960px">
    <p class="crumbs"><a href="{up}{'de/' if lang == 'de' else ''}">Tubemac</a> › {t['guides']}</p>
    <h1>{t['hub_title']}</h1>
    <p class="lead">{t['hub_lead']}</p>
    <div class="guide-grid">{items}</div>
  </article>'''
    ld = json.dumps({"@context": "https://schema.org", "@type": "CollectionPage", "name": text(t["hub_title"]),
                     "url": SITE + path, "inLanguage": lang,
                     "hasPart": [{"@type": "Article", "headline": g["h1"], "url": g["url"]}
                                 for g in guides if g["lang"] == lang]}, ensure_ascii=False, indent=2)
    out = DOCS / path / "index.html"
    out.parent.mkdir(parents=True, exist_ok=True)
    out.write_text(frame(lang, depth, text(t["hub_title"]) + " | Tubemac", t["hub_desc"], SITE + path, body,
                         ld=ld, og_type="website"))


def build_sitemap(guides, today):
    urls = [("", "de/"), ("de/", ""), (T["en"]["guides_url"], None), (T["de"]["guides_url"], None)]
    rows = []
    for path, alt in urls:
        alt_links = ""
        if alt is not None:
            en, de = ("", "de/")
            alt_links = (f'\n    <xhtml:link rel="alternate" hreflang="en" href="{SITE}{en}"/>'
                         f'\n    <xhtml:link rel="alternate" hreflang="de" href="{SITE}{de}"/>')
        rows.append(f"  <url>\n    <loc>{SITE}{path}</loc>\n    <lastmod>{today}</lastmod>{alt_links}\n  </url>")
    for g in guides:
        rows.append(f"  <url>\n    <loc>{g['url']}</loc>\n    <lastmod>{g['updated']}</lastmod>\n  </url>")
    (DOCS / "sitemap.xml").write_text(
        '<?xml version="1.0" encoding="UTF-8"?>\n'
        '<urlset xmlns="http://www.sitemaps.org/schemas/sitemap/0.9" xmlns:xhtml="http://www.w3.org/1999/xhtml">\n'
        + "\n".join(rows) + "\n</urlset>\n")


def update_llms(guides):
    p = DOCS / "llms.txt"
    s = p.read_text()
    marker = "## Guides"
    s = s.split(marker)[0].rstrip() + "\n\n" + marker + "\n" + "".join(
        f"- [{text(g['h1'])}]({g['url']}): {g['description']}\n" for g in guides)
    p.write_text(s)


MONTHS = {"en": ["January", "February", "March", "April", "May", "June", "July", "August", "September",
                 "October", "November", "December"],
          "de": ["Januar", "Februar", "März", "April", "Mai", "Juni", "Juli", "August", "September",
                 "Oktober", "November", "Dezember"]}

if __name__ == "__main__":
    guides = load()
    for g in guides:
        y, m, d = g["updated"].split("-")
        month = MONTHS[g["lang"]][int(m) - 1]
        g["updated_label"] = f"{int(d)} {month} {y}" if g["lang"] == "en" else f"{int(d)}. {month} {y}"
    for g in guides:
        build_guide(g, guides)
    for lang in ("en", "de"):
        build_hub(lang, guides)
    build_sitemap(guides, max(g["updated"] for g in guides))
    update_llms(guides)
    print(f"Built {len(guides)} guides + 2 index pages")
