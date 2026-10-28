#!/usr/bin/env python3
"""Télécharge des photos libres de droits depuis Wikimedia Commons, avec leurs crédits.

Usage : python3 -I commons_fetch.py <dossier_sortie> [catégorie] [nombre]
Ne garde que les images paysage >= 1920 px sous licence CC0, domaine public, CC BY ou CC BY-SA,
et écrit CREDITS.txt (auteur, licence, source) comme l'exigent les licences CC BY.
"""
import html, json, os, re, sys, time, urllib.parse, urllib.request

API = "https://commons.wikimedia.org/w/api.php"
UA = "MiTvStickToolkit/1.0 (usage personnel; fonds d'ecran)"
OK_LICENSE = re.compile(r"^(CC0|Public domain|PD|CC BY(-SA)? [0-9.]+)", re.I)


def get(params):
    url = API + "?" + urllib.parse.urlencode(params)
    req = urllib.request.Request(url, headers={"User-Agent": UA})
    with urllib.request.urlopen(req, timeout=30) as r:
        return json.load(r)


def clean(s):
    return html.unescape(re.sub(r"<[^>]+>", "", s or "")).strip()


def main():
    out = sys.argv[1]
    category = sys.argv[2] if len(sys.argv) > 2 else "Quality images of association football"
    wanted = int(sys.argv[3]) if len(sys.argv) > 3 else 20
    os.makedirs(out, exist_ok=True)
    params = {
        "action": "query", "format": "json", "generator": "categorymembers",
        "gcmtitle": "Category:" + category, "gcmtype": "file", "gcmlimit": "100",
        "prop": "imageinfo", "iiprop": "url|size|mime|extmetadata", "iiurlwidth": "1920",
        "iiextmetadatafilter": "LicenseShortName|Artist|Credit",
    }
    credits, n = [], 0
    while n < wanted:
        data = get(params)
        for page in (data.get("query", {}).get("pages", {}) or {}).values():
            if n >= wanted:
                break
            info = (page.get("imageinfo") or [{}])[0]
            meta = info.get("extmetadata", {})
            lic = clean(meta.get("LicenseShortName", {}).get("value"))
            if info.get("mime") != "image/jpeg" or not OK_LICENSE.match(lic):
                continue
            w, h = info.get("width", 0), info.get("height", 0)
            if w < 1920 or w < h * 1.3:
                continue
            n += 1
            name = "foot-%02d.jpg" % n
            req = urllib.request.Request(info["thumburl"], headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r, open(os.path.join(out, name), "wb") as f:
                f.write(r.read())
            author = clean(meta.get("Artist", {}).get("value")) or "inconnu"
            credits.append("%s — %s — %s — %s" % (name, author, lic, info.get("descriptionurl")))
            print("  ✔", name, "|", lic, "|", author)
            time.sleep(1)
        if "continue" not in data:
            break
        params.update(data["continue"])
    with open(os.path.join(out, "CREDITS.txt"), "w", encoding="utf-8") as f:
        f.write("Photos Wikimedia Commons (fichier — auteur — licence — source)\n")
        f.write("\n".join(credits) + "\n")
    print("%d image(s) dans %s" % (n, out))
    return 0 if n else 1


if __name__ == "__main__":
    sys.exit(main())
