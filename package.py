#!/usr/bin/env python3
"""Pack Auth (TOTP authenticator) into an unsigned BB10 archive (.bar) for the root installer.
Usage: python3 native-auth/package.py  -> native-auth/build/org.bq.auth.bar
Layout: native/auth (window), native/icon.png, native/assets/** (QML). No network, no permissions."""
import base64, hashlib, os, zipfile
HERE = os.path.dirname(os.path.abspath(__file__))
PKG, NAME, VER = "org.bq.auth", "Authenticator", "0.1.1.1"

def b64(b): return base64.urlsafe_b64encode(b).decode().rstrip("=")
def ident(letter, text): return "bqnt" + letter + b64(hashlib.sha256(text.encode()).digest())[:22]
def rd(p): return open(p, "rb").read()

assets = {"native/auth": rd(os.path.join(HERE, "build/qnx/auth")),
          "native/icon.png": rd(os.path.join(HERE, "assets", "appicon.png"))}
EXEC = {"native/auth"}
for root, _, files in os.walk(os.path.join(HERE, "assets")):
    for f in files:
        if f.startswith(".") or f == "appicon.png": continue
        p = os.path.join(root, f)
        assets["native/assets/" + os.path.relpath(p, os.path.join(HERE, "assets"))] = rd(p)

m = f"""Archive-Manifest-Version: 1.5
Archive-Created-By: bq native packager 1.0

Package-Type: application
Package-Author: bq
Package-Author-Id: {ident('A', 'bq')}
Package-Name: {PKG}
Package-Id: {ident('B', PKG)}
Package-Version: {VER}
Package-Version-Id: {ident('C', PKG + VER)}
Package-Architecture: armle-v7

Application-Name: {NAME}
Application-Id: {ident('D', PKG)}
Application-Description: On-device TOTP authenticator (offline, no permissions)
Application-Version: {VER}
Application-Version-Id: {ident('E', PKG + VER)}
Application-Requires-System: BlackBerry 10/10.3.0.0
Application-Development-Mode: false

Entry-Point-Name: {NAME}
Entry-Point-Key: e1
Entry-Point: app/native/auth
Entry-Point-Type: Qnx/Elf
Entry-Point-Icon: {{144x144}}native/icon.png
Entry-Point-Orientation: auto
Entry-Point-System-Actions: run_native

"""
for k, v in assets.items():
    m += f"Archive-Asset-Name: {k}\nArchive-Asset-SHA-512-Digest: {b64(hashlib.sha512(v).digest())}\n"
    if k in EXEC: m += "Archive-Asset-Type: Qnx/Elf\n"
    m += "\n"
out = os.path.join(HERE, "build", PKG + ".bar")
os.makedirs(os.path.join(HERE, "build"), exist_ok=True)
with zipfile.ZipFile(out, "w", zipfile.ZIP_DEFLATED) as z:
    z.writestr("META-INF/MANIFEST.MF", m)
    for k, v in assets.items():
        zi = zipfile.ZipInfo(k)
        zi.external_attr = (0o755 if k in EXEC else 0o644) << 16
        zi.compress_type = zipfile.ZIP_DEFLATED
        z.writestr(zi, v)
print(out, os.path.getsize(out), "bytes;", len(assets), "assets")
