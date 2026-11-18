#!/usr/bin/env python3
"""Lists, and optionally cleans up, the signing certificates in the Apple developer account.

Each iPhone build on GitHub runs on a fresh Mac, so Xcode's automatic signing makes a new
"Apple Development" certificate (named "Created via API") every time. Apple caps how many an
account can have, and builds fail once the cap is reached. `cleanup` revokes only those
CI-made development certificates; distribution certificates and ones made on your own Mac
are never touched. Nothing here affects apps already in the App Store or TestFlight.

Usage: asc-certs.py list|cleanup   (needs KEY_ID, ISSUER_ID and the .p8 key path in KEY_P8)
"""
import json, os, sys, time, urllib.request
import jwt  # PyJWT

API = "https://api.appstoreconnect.apple.com/v1/certificates"


def token():
    key = open(os.environ["KEY_P8"]).read()
    now = int(time.time())
    return jwt.encode({"iss": os.environ["ISSUER_ID"], "iat": now, "exp": now + 600, "aud": "appstoreconnect-v1"},
                      key, algorithm="ES256", headers={"kid": os.environ["KEY_ID"], "typ": "JWT"})


def call(method, url):
    req = urllib.request.Request(url, method=method, headers={"Authorization": "Bearer " + token()})
    with urllib.request.urlopen(req) as r:
        body = r.read()
        return json.loads(body) if body else None


def certs():
    out = call("GET", API + "?limit=200&fields[certificates]=name,displayName,certificateType,expirationDate,platform")
    return out["data"]


def ci_made(c):
    a = c["attributes"]
    return a.get("certificateType") in ("DEVELOPMENT", "IOS_DEVELOPMENT") and "Created via API" in (a.get("name") or "")


mode = sys.argv[1] if len(sys.argv) > 1 else "list"
cs = certs()
for c in cs:
    a = c["attributes"]
    print(f'{a.get("certificateType"):<22} {a.get("name")!s:<45} {a.get("displayName")!s:<30} expires {str(a.get("expirationDate"))[:10]}{"  <- made by a GitHub build" if ci_made(c) else ""}')
if mode == "cleanup":
    for c in [c for c in cs if ci_made(c)]:
        call("DELETE", f'{API}/{c["id"]}')
        print("Revoked", c["attributes"].get("name"), c["id"])
