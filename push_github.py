"""Push tools/corvus_ui/ source files na 9yydxqnwt4-source/CorvusUI GitHub.

Nie dotyka hub .txt ani loader. Tylko modular source + README.
Token w ~/.corvus_github_token (musi byc 9yydxqnwt4-source, inaczej odmawia).
"""
import base64
import hashlib
import json
import os
import sys
import urllib.error
import urllib.request

OWNER_REPO = "9yydxqnwt4-source/CorvusUI"
BRANCH = "main"
HERE = os.path.dirname(os.path.abspath(__file__))
FILES = [
    "README.md",
    "extract.py",
    "build.py",
    "push_github.py",
    "src/01_head.lua",
    "src/02_library.lua",
    "src/03_boot.lua",
]


def token():
    p = os.path.join(os.path.expanduser("~"), ".corvus_github_token")
    return open(p, encoding="utf-8").read().strip()


def req(method, path, body=None):
    url = "https://api.github.com" + path
    data = body.encode("utf-8") if isinstance(body, str) else body
    r = urllib.request.Request(url, method=method, data=data, headers={
        "Authorization": "Bearer " + token(),
        "User-Agent": "corvus-ui-push",
        "Accept": "application/vnd.github+json",
    })
    try:
        with urllib.request.urlopen(r, timeout=60) as resp:
            return resp.status, json.loads(resp.read().decode("utf-8"))
    except urllib.error.HTTPError as e:
        return e.code, json.loads(e.read().decode("utf-8", "replace"))


def me_login():
    code, j = req("GET", "/user")
    if code != 200:
        sys.exit("auth fail: " + str(j))
    return j["login"]


def get_file_sha(path):
    code, j = req("GET", f"/repos/{OWNER_REPO}/contents/{path}?ref={BRANCH}")
    if code == 200:
        return j["sha"]
    return None


def put_file(path, local_path):
    data = open(local_path, "rb").read()
    body = {
        "message": "chore(ui): sync " + path,
        "content": base64.b64encode(data).decode("ascii"),
        "branch": BRANCH,
    }
    existing = get_file_sha(path)
    if existing:
        body["sha"] = existing
    code, j = req("PUT", f"/repos/{OWNER_REPO}/contents/{path}", json.dumps(body))
    if code not in (200, 201):
        print(f"FAIL  {path}: {code} {j.get('message', '')}")
        return None
    sha12 = hashlib.sha256(data).hexdigest()[:12]
    commit = j["commit"]["sha"][:7]
    size = len(data)
    print(f"OK    {path:28} {size:>10,} B  sha256:{sha12}  commit:{commit}")
    return commit


def main():
    who = me_login()
    expected = OWNER_REPO.split("/")[0]
    if who != expected:
        sys.exit(f"token belongs to {who}, expected {expected}")
    print(f"authenticated as {who}, pushing to {OWNER_REPO}@{BRANCH}")
    last = None
    for rel in FILES:
        local = os.path.join(HERE, rel.replace("/", os.sep))
        if not os.path.exists(local):
            print(f"SKIP  {rel}: missing local")
            continue
        c = put_file(rel, local)
        if c:
            last = c
    if last:
        print(f"\nlatest commit: https://github.com/{OWNER_REPO}/commit/{last}")


if __name__ == "__main__":
    main()
