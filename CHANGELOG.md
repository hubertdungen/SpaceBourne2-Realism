# Changelog

## 0.2.6 — 2026-11-08

- **The installer updates itself.** When you open it and a newer installer is out, it downloads it, keeps the old copy in `%LOCALAPPDATA%\SB2Realism\backups`, and reopens as the new version. The log says which version you came from. **Check for updates** does the same. If the download fails or the folder cannot be written, nothing changes and the log gives the download link. Unticking "Check for updates when this opens" turns this off too.
- If you have 0.2.5 or older, download 0.2.6 once by hand. From then on it updates itself.
- Squad Tactics is out (Nexus 18) and is listed as a normal mod.
- When GitHub answers with a passing error (504), the installer tries once more before giving up.

## 0.2.5 — 2026-11-07

- **Clear HUD: hide the clutter when you install it.** The window that asks for the reticle and HUD colours now also asks whether to hide the damage numbers, the enemy health bar and the markers on foot. Hiding the markers on foot also hides mission markers, because the game has one switch for all of them. The answer is pre-set to hide; you can change it later in `ClearHUD\scripts\config.lua`.

## 0.2.4 — 2026-11-06

- **Updates take the new default settings and keep only the ones you changed.** Before, an update kept your whole `config.lua`, so the old defaults stayed in it and replaced the new tuning. For example, Ammo Discipline kept giving half a pouch per pickup instead of 15%, and Silent Ops kept the old sight ranges. Now each setting you changed (a colour, a key, an option you switched) is copied into the new file, and every other setting takes the new default. The log lists the settings it kept.
- **Old installs are cleaned up too.** If your `config.lua` came through several updates, the installer compares it with the defaults of every earlier release, so old defaults are not mistaken for your own settings.
- `config.default.lua` now says which version's defaults it holds. Don't edit it: edit `config.lua`.

## 0.2.3 — 2026-11-01

- **Pick Clear HUD's colours when you install it.** Ticking Clear HUD and pressing **Apply ticks** asks for the reticle colour and the HUD colour. Closing that window keeps the defaults: a green reticle and the game's HUD colour. You can change them later in `ClearHUD\scripts\config.lua`.
- Clear HUD is out (Nexus 16).

## 0.2.2 — 2026-11-01

- **Update all keeps SB2 HOTAS switched off if you had it off.** Before, updating the bridge also switched the in-game part on.
- Clear HUD and Bigger Armies are listed as coming soon.

## 0.2.1 — 2026-11-01

- **Colours at a glance:**
  - Yellow rows have an update waiting, and the **Update all** button turns yellow too and shows how many.
  - Green rows are installed and up to date.
  - White rows are not installed.

## 0.2.0 — 2026-10-31

- **Play button.** Starts SpaceBourne 2, through Steam for Steam copies. When SB2 HOTAS is on, it starts the HOTAS bridge first.
- **SB2 HOTAS from the installer.** Ticking it downloads the bridge app and installs the in-game part. **Open SB2 HOTAS** starts the bridge, and **Update all** keeps it current. A copy of the bridge you already run yourself is detected and left alone.

## 0.1.0 — 2026-10-31

First release.

- **Mod checklist.** Lists every mod in the SpaceBourne 2 realism set with a short description; you tick the ones you want.
- **Ticked mods are installed and switched on.** That includes the master switch in `config.lua` and any remembered in-game toggle. Unticked mods are switched off, and their files are deleted only if you say so.
- **Updates.** The list shows the installed and latest version of each mod. **Update all** downloads and installs every newer release and keeps your `config.lua`.
- **Safety.** It backs up a mod before replacing or removing it, never touches saves, and refuses to run while the game is open.
- **UE4SS.** When it's missing, UE4SS 3.0.1 installs with one click.
- **Live mod list.** The list is read from `mods.json` in this repository, so new mods appear without a new installer.
- **Planned mods** (Tactical First Person, Ammo Discipline, Get Out of the Way, Ground Waypoints) show as "coming soon" and become installable as soon as they are released.
- **No GitHub API limit.** Versions are read from GitHub's release links, so checking for updates keeps working however often you open it.
