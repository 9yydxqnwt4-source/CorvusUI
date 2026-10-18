"""Build modularny -> single-file Games/_Library/CorvusPetUniverse.txt.

Uruchom po edycji tools/corvus_ui/src/*.lua zeby zbudowac master library ktora
build.py kazdego huba wycina w sekcje `local Library = (function()` ... `end)()`.
"""
import glob
import os
import sys

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "src")
OUT = os.path.join(ROOT, "Games", "_Library", "CorvusPetUniverse.txt")

parts = sorted(glob.glob(os.path.join(SRC, "*.lua")))
if not parts:
    sys.exit("no src/*.lua files found; run extract.py first")

body = []
for p in parts:
    text = open(p, encoding="utf-8").read().rstrip("\n")
    body.append(text)

out = "\n".join(body) + "\n"
# zabezpieczenie: webhook plaintext zabroniony
assert "FeedbackWebhook" not in out or "function(hex)" in out, "FeedbackWebhook musi byc XOR-ed przez secret.py"
open(OUT, "w", encoding="utf-8", newline="\n").write(out)
print(f"wrote {OUT} ({out.count(chr(10))} lines, from {len(parts)} source files)")
