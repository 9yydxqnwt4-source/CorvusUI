# CorvusUI

Hybrydowa biblioteka Lua UI dla hubow Corvus w Roblox — baza na Obsidian (Linoria-style API, czyste, MIT), vibe wizualny z OasisUI (soft rounded 10 px, pastelowy sidebar, pill controls), brand Corvus (Metal silver accent `232,237,246`, dark raven `7,7,9`, logo kruka w tytule).

## Struktura

```
tools/corvus_ui/
  src/
    01_head.lua       -- xpcall boot wrapper, czeka na Knit + SPdataLoaded
    02_library.lua    -- Library IIFE (~32k linii): Window, Tabs, Groupbox,
                       -- Toggle, Dropdown, Slider, Input, Button, Label,
                       -- KeyPicker, ColorPicker, Searchbar, Starfield intro,
                       -- CommandPalette, NotificationCenter, Settings,
                       -- Theme/SaveManager hooks, +wszystkie dodatki CORVUS-*
                       -- (DIAG, LOAD, MIRROR, CONFIGLOAD, PURCHASEGUARD, ANTIAFK)
    03_boot.lua       -- loadAddon (Obsidian addons/ThemeManager+SaveManager),
                       -- hub bootstrap, Discord zasyflowane, Codes.json, feedback webhook
  extract.py          -- jednorazowo: rozcina istniejacy monolith w src/
  build.py            -- skleja src/*.lua -> Games/_Library/CorvusPetUniverse.txt
  README.md
```

Build huba (BSE/TAPSIM/DF) wycina z `Games/_Library/CorvusPetUniverse.txt` sekcje
`local Library = (function() ... end)()` (plik `02_library.lua`) i wkleja ja miedzy
`head.lua` a `pNN_*.lua`. Czyli ta biblioteka jest tylko base — kazda gra ma wlasna
nakladke konfiguracji + planer + feature'y w `Games/<Gra>/src/`.

## Visual DNA

- Linoria/Obsidian: Window z sidebar + tab buttons, groupbox, pop-out, dropdown + chip, slider, toggle (checkbox / pill), color + key picker, dialog, loading screen, resize + snap + drag.
- OasisUI: miekki `CornerRadius = 10`, tab buttons z lewym indicator-stroke'em (3 px / 22 px), pill-shaped nagrany tab, pastelowy sidebar aktywny.
- Corvus brand: AccentColor `Color3.fromRGB(232, 237, 246)` (Metal silver), BackgroundColor `(7, 7, 9)`, MainColor `(20, 21, 24)`, OutlineColor `(62, 64, 70)`, FontColor `(242, 243, 246)`, Font `Enum.Font.BuilderSans`. Logo "corvus" ikona Lucide, bootstrap z `Corvus/assets/`.

## Jak pracujesz

1. edytuj `tools/corvus_ui/src/02_library.lua` lub inny plik,
2. `python tools/corvus_ui/build.py` sklei master do `Games/_Library/CorvusPetUniverse.txt`,
3. `python Games/<Gra>/src/build.py` zbuduje huba,
4. `python tools/hubtest.py <alias>` + `python tools/hub_check.py <hub> tools/luau`,
5. `python tools/gate_upload.py all` pcha na dev gate worker.

## Pochodzenie

- Obsidian UI (MIT, Copyright 2025 deividcomsono) — baza, nie `require` tylko fork.
- OasisUI (MIT, Copyright 2025 iryko-dev) — inspiracja wizualna, nie kod.

Addony Obsidian (`ThemeManager`, `SaveManager`) sciagane w runtime z
`https://raw.githubusercontent.com/deividcomsono/Obsidian/main/addons/`.

## API (bez zmian vs Obsidian/Linoria)

- `Library:CreateWindow({...})` zwraca `Window`
- `Window:AddTab("Name", "icon")` / `Window:AddInfoTab({Name=, Icon=, Description=})`
- `Tab:AddLeftGroupbox(Name, Icon)` / `Tab:AddRightGroupbox(...)`
- Groupbox: `AddToggle`, `AddSlider`, `AddDropdown`, `AddInput`, `AddButton`, `AddLabel`, `AddKeyPicker`
- `Library.Toggles[id]`, `Library.Options[id]`
- `Library:SetTheme({...})` / `Library.Scheme`

Zgodne z `Games/*/src/p08_ui.lua` wszystkich hubow bez thin adaptera.
