"""App Store Connect befüllen – aus metadata/*.json und den Store-Bildern.

  store.py status                 aktuellen Stand zeigen
  store.py texts                  Name, Untertitel, Beschreibung, Keywords, URLs, Was ist neu (DE + EN)
  store.py screenshots [ordner]   6,9"-Screenshots (Standard: out-ocean/de/iphone-6.9) für de-DE hochladen
  store.py price [4.99]           Preis (Basisland Deutschland)
  store.py build [nummer]         neuesten (oder angegebenen) Build an Version 1.0 hängen
  store.py review                 Review-Kontakt + Notizen
  store.py all                    texts + screenshots + price + build + review
  store.py submit                 zur Prüfung einreichen (fragt nach)
"""
import sys, json, pathlib, hashlib, requests
sys.path.insert(0, str(pathlib.Path(__file__).parent))
from asc import get, post, patch, delete, CFG

HERE = pathlib.Path(__file__).resolve().parent.parent
APP = CFG.get("app_id")
LOCALES = ["de-DE", "en-US"]

def app_id():
    global APP
    if not APP:
        APP = next(a["id"] for a in get("/apps?limit=50")["data"] if a["attributes"]["bundleId"] == CFG["bundle_id"])
    return APP

def version():
    vs = get(f"/apps/{app_id()}/appStoreVersions?filter[platform]=IOS&limit=5")["data"]
    editable = [v for v in vs if v["attributes"]["appStoreState"] in ("PREPARE_FOR_SUBMISSION", "DEVELOPER_REJECTED", "REJECTED", "METADATA_REJECTED", "WAITING_FOR_REVIEW")]
    return (editable or vs)[0]

def meta(locale):
    return json.loads((HERE / "metadata" / f"{locale}.json").read_text())

# ---------- Texte ----------
def texts():
    info = get(f"/apps/{app_id()}/appInfos")["data"][0]
    locs = {l["attributes"]["locale"]: l for l in get(f"/appInfos/{info['id']}/appInfoLocalizations")["data"]}
    ver = version()
    vlocs = {l["attributes"]["locale"]: l for l in get(f"/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")["data"]}
    for loc in LOCALES:
        m = meta(loc)
        info_attrs = {"name": m["name"], "subtitle": m["subtitle"], "privacyPolicyUrl": m["privacyPolicyUrl"]}
        if loc in locs:
            patch(f"/appInfoLocalizations/{locs[loc]['id']}", {"data": {"type": "appInfoLocalizations", "id": locs[loc]["id"], "attributes": info_attrs}})
        else:
            post("/appInfoLocalizations", {"data": {"type": "appInfoLocalizations", "attributes": {"locale": loc, **info_attrs},
                 "relationships": {"appInfo": {"data": {"type": "appInfos", "id": info["id"]}}}}})
        ver_attrs = {k: m[k] for k in ["description", "keywords", "promotionalText", "supportUrl", "marketingUrl"]}
        if ver["attributes"]["versionString"] != "1.0":   # "Was ist neu" gibt es erst ab dem ersten Update
            ver_attrs["whatsNew"] = m["whatsNew"]
        if loc in vlocs:
            patch(f"/appStoreVersionLocalizations/{vlocs[loc]['id']}", {"data": {"type": "appStoreVersionLocalizations", "id": vlocs[loc]["id"], "attributes": ver_attrs}})
        else:
            post("/appStoreVersionLocalizations", {"data": {"type": "appStoreVersionLocalizations", "attributes": {"locale": loc, **ver_attrs},
                 "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver["id"]}}}}})
        print(f"✓ Texte {loc}: {m['name']} — {m['subtitle']}")
    patch(f"/apps/{app_id()}", {"data": {"type": "apps", "id": app_id(), "attributes": {"primaryLocale": "de-DE"}}})
    print("✓ Primärsprache: de-DE")

# ---------- Screenshots ----------
def screenshots(folder=None, locale="de-DE", display_type="APP_IPHONE_67"):
    folder = pathlib.Path(folder or HERE / "out-ocean/de/iphone-6.9")
    files = sorted(folder.glob("*.png"))
    assert files, f"keine PNGs in {folder}"
    ver = version()
    vloc = next(l for l in get(f"/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")["data"] if l["attributes"]["locale"] == locale)
    sets = get(f"/appStoreVersionLocalizations/{vloc['id']}/appScreenshotSets")["data"]
    sset = next((s for s in sets if s["attributes"]["screenshotDisplayType"] == display_type), None)
    if not sset:
        sset = post("/appScreenshotSets", {"data": {"type": "appScreenshotSets", "attributes": {"screenshotDisplayType": display_type},
                    "relationships": {"appStoreVersionLocalization": {"data": {"type": "appStoreVersionLocalizations", "id": vloc["id"]}}}}})["data"]
    for old in get(f"/appScreenshotSets/{sset['id']}/appScreenshots")["data"]:
        delete(f"/appScreenshots/{old['id']}")
    for f in files:
        data = f.read_bytes()
        shot = post("/appScreenshots", {"data": {"type": "appScreenshots", "attributes": {"fileName": f.name, "fileSize": len(data)},
                    "relationships": {"appScreenshotSet": {"data": {"type": "appScreenshotSets", "id": sset["id"]}}}}})["data"]
        for op in shot["attributes"]["uploadOperations"]:
            chunk = data[op["offset"]: op["offset"] + op["length"]]
            r = requests.request(op["method"], op["url"], data=chunk, headers={h["name"]: h["value"] for h in op["requestHeaders"]})
            r.raise_for_status()
        patch(f"/appScreenshots/{shot['id']}", {"data": {"type": "appScreenshots", "id": shot["id"],
              "attributes": {"uploaded": True, "sourceFileChecksum": hashlib.md5(data).hexdigest()}}})
        print(f"✓ Screenshot {f.name} ({len(data)//1024} KB)")
    print(f"✓ {len(files)} Screenshots in {locale} / {display_type}")

# ---------- Preis ----------
def price(amount="4.99", territory="DEU"):
    pts = get(f"/apps/{app_id()}/appPricePoints?filter[territory]={territory}&limit=200")["data"]
    pt = next(p for p in pts if p["attributes"]["customerPrice"] == amount)
    post("/appPriceSchedules", {"data": {"type": "appPriceSchedules",
        "relationships": {"app": {"data": {"type": "apps", "id": app_id()}},
                          "baseTerritory": {"data": {"type": "territories", "id": territory}},
                          "manualPrices": {"data": [{"type": "appPrices", "id": "${price1}"}]}}},
        "included": [{"type": "appPrices", "id": "${price1}", "attributes": {"startDate": None},
                      "relationships": {"appPricePoint": {"data": {"type": "appPricePoints", "id": pt["id"]}}}}]})
    print(f"✓ Preis {amount} € (Basis {territory}, andere Länder automatisch)")

# ---------- Build ----------
def build(number=None):
    builds = get(f"/builds?filter[app]={app_id()}&filter[processingState]=VALID&sort=-uploadedDate&limit=10")["data"]
    b = next((x for x in builds if number is None or x["attributes"]["version"] == str(number)), None)
    assert b, "kein passender Build (VALID) gefunden"
    ver = version()
    patch(f"/appStoreVersions/{ver['id']}", {"data": {"type": "appStoreVersions", "id": ver["id"],
          "relationships": {"build": {"data": {"type": "builds", "id": b["id"]}}}}})
    print(f"✓ Build {b['attributes']['version']} an Version {ver['attributes']['versionString']} gehängt")

# ---------- Review ----------
def review():
    ver = version(); m = meta("de-DE")
    attrs = {"contactFirstName": "Ralf", "contactLastName": "Lohrmann", "contactEmail": "geldtracker.contact@gmail.com",
             "contactPhone": "+49 71135152473", "demoAccountRequired": False, "notes": m["reviewNotes"]}
    try:
        rd = get(f"/appStoreVersions/{ver['id']}/appStoreReviewDetail")["data"]
        patch(f"/appStoreReviewDetails/{rd['id']}", {"data": {"type": "appStoreReviewDetails", "id": rd["id"], "attributes": attrs}})
    except SystemExit:
        post("/appStoreReviewDetails", {"data": {"type": "appStoreReviewDetails", "attributes": attrs,
             "relationships": {"appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver["id"]}}}}})
    print("✓ Review-Kontakt und Notizen gesetzt")

# ---------- Status / Submit ----------
def status():
    a = get(f"/apps/{app_id()}")["data"]["attributes"]; ver = version()
    print(f"App: {a['name']} ({a['bundleId']}), Primärsprache {a['primaryLocale']}")
    print(f"Version {ver['attributes']['versionString']}: {ver['attributes']['appStoreState']}")
    b = get(f"/appStoreVersions/{ver['id']}/build")["data"]
    print("Build:", b["attributes"]["version"] if b else "— keiner —")
    for l in get(f"/appStoreVersions/{ver['id']}/appStoreVersionLocalizations")["data"]:
        n = sum(len(get(f"/appScreenshotSets/{s['id']}/appScreenshots")["data"]) for s in get(f"/appStoreVersionLocalizations/{l['id']}/appScreenshotSets")["data"])
        print(f"  {l['attributes']['locale']}: {n} Screenshots, Keywords: {l['attributes'].get('keywords')}")
    try:
        sched = get(f"/apps/{app_id()}/appPriceSchedule")["data"]
        p = get(f"/appPriceSchedules/{sched['id']}/manualPrices?include=appPricePoint&limit=5")
        print("Preis:", [f"{x['attributes']['customerPrice']} (du bekommst {x['attributes']['proceeds']})" for x in p.get("included", []) if x["type"] == "appPricePoints"])
    except SystemExit: print("Preis: — keiner —")

def submit():
    ver = version()
    if input(f"Version {ver['attributes']['versionString']} wirklich zur Prüfung einreichen? [j/N] ").lower() != "j": return
    sub = post("/reviewSubmissions", {"data": {"type": "reviewSubmissions", "attributes": {"platform": "IOS"},
          "relationships": {"app": {"data": {"type": "apps", "id": app_id()}}}}})["data"]
    post("/reviewSubmissionItems", {"data": {"type": "reviewSubmissionItems",
          "relationships": {"reviewSubmission": {"data": {"type": "reviewSubmissions", "id": sub["id"]}},
                            "appStoreVersion": {"data": {"type": "appStoreVersions", "id": ver["id"]}}}}})
    patch(f"/reviewSubmissions/{sub['id']}", {"data": {"type": "reviewSubmissions", "id": sub["id"], "attributes": {"submitted": True}}})
    print("✓ Eingereicht – Status: Warten auf Prüfung")

if __name__ == "__main__":
    cmd, args = (sys.argv[1] if len(sys.argv) > 1 else "status"), sys.argv[2:]
    if cmd == "all":
        texts(); screenshots(*args); price(); build(); review(); status()
    else:
        globals()[cmd](*args)
