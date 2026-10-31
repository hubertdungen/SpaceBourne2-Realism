# Changelog

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
