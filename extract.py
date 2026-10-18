"""Rozcina Games/_Library/CorvusPetUniverse.txt na modularne pliki w tools/corvus_ui/src/.
Uruchom raz zeby rozdzielic; potem edytujesz src/ i build.py skleja z powrotem.
"""
import os
import sys
import re

ROOT = os.path.dirname(os.path.dirname(os.path.dirname(os.path.abspath(__file__))))
MASTER = os.path.join(ROOT, "Games", "_Library", "CorvusPetUniverse.txt")
SRC = os.path.join(os.path.dirname(os.path.abspath(__file__)), "src")

lines = open(MASTER, encoding="utf-8").read().replace("\r\n", "\n").split("\n")

# markery
boot_begin = next(i for i, l in enumerate(lines) if l.startswith("-- Whole hub in xpcall"))
lib_begin = next(i for i, l in enumerate(lines) if l.strip() == "local Library = (function()")
# pierwszy end)() po lib_begin na glebokosci 0 - to koniec library IIFE
# szukamy "    end)()" na linii poprzedzajacej "    local function loadAddon(name)"
load_addon_line = next(i for i, l in enumerate(lines) if l.strip() == "local function loadAddon(name)")
lib_end = load_addon_line - 1
assert lines[lib_end].strip() == "end)()", f"spodziewany end)() na linii {lib_end}, dostano: {lines[lib_end]!r}"

head_text = "\n".join(lines[boot_begin:lib_begin])
library_text = "\n".join(lines[lib_begin:lib_end + 1])
boot_text = "\n".join(lines[lib_end + 1:])

os.makedirs(SRC, exist_ok=True)
open(os.path.join(SRC, "01_head.lua"), "w", encoding="utf-8", newline="\n").write(head_text + "\n")
open(os.path.join(SRC, "02_library.lua"), "w", encoding="utf-8", newline="\n").write(library_text + "\n")
open(os.path.join(SRC, "03_boot.lua"), "w", encoding="utf-8", newline="\n").write(boot_text.rstrip("\n") + "\n")
print(f"head: {len(head_text.splitlines())} lines")
print(f"library: {len(library_text.splitlines())} lines")
print(f"boot: {len(boot_text.splitlines())} lines")
print(f"wrote {SRC}")
