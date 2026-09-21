"""Kleiner App-Store-Connect-Client (JWT-Auth). Konfiguration in keys/config.json."""
import json, time, pathlib, sys
import jwt, requests

HERE = pathlib.Path(__file__).resolve().parent
CFG = json.loads((HERE.parent / "keys" / "config.json").read_text())
BASE = "https://api.appstoreconnect.apple.com/v1"

def token():
    key = (HERE.parent / "keys" / f"AuthKey_{CFG['key_id']}.p8").read_text()
    now = int(time.time())
    return jwt.encode({"iss": CFG["issuer_id"], "iat": now, "exp": now + 19 * 60, "aud": "appstoreconnect-v1"},
                      key, algorithm="ES256", headers={"kid": CFG["key_id"]})

def req(method, path, **kw):
    url = path if path.startswith("http") else BASE + path
    r = requests.request(method, url, headers={"Authorization": f"Bearer {token()}", **kw.pop("headers", {})}, **kw)
    if r.status_code >= 400:
        raise SystemExit(f"{method} {path} → {r.status_code}\n{r.text[:1500]}")
    return r.json() if r.text else {}

get = lambda p, **kw: req("GET", p, **kw)
post = lambda p, data: req("POST", p, json=data)
patch = lambda p, data: req("PATCH", p, json=data)
delete = lambda p: req("DELETE", p)

if __name__ == "__main__":
    apps = get("/apps?limit=50")["data"]
    for a in apps:
        print(a["id"], a["attributes"]["bundleId"], "→", a["attributes"]["name"])
