![SpaceBourne 2 Realism](docs/banner.png)

# SpaceBourne 2 Realism: installer and updater

One window to install, switch on and update the whole SpaceBourne 2 realism mod set. Tick the mods you want, press **Apply ticks**, and play.

- **Pick your mods.** Every mod in the set is listed with a short description. Install all of them or just one.
- **Ticked means on.** Every ticked mod is installed *and* switched on, even one that ships switched off on its own.
- **See what's out of date.** It shows the version you have and the newest release on GitHub. **Update all** downloads and installs every newer version for you.
- **Your settings stay.** Updates keep your `config.lua`. The new defaults go next to it as `config.default.lua`.
- **Safe.** It never touches your saves or the game's executable. Before it replaces or removes a mod, it keeps a backup in `%LOCALAPPDATA%\SB2Realism\backups`.
- **UE4SS included.** If UE4SS is missing, one click installs UE4SS 3.0.1, the version every mod in the set is built for.

## How to use

1. Download the zip from [Releases](https://github.com/hubertdungen/SpaceBourne2-Realism/releases) or Nexus, and extract it anywhere.
2. Close SpaceBourne 2.
3. Double-click **`Install SB2 Realism.cmd`**.
4. The installer finds the game through Steam. For GOG or another location, press **Browse** and pick the `SpaceBourne 2` folder.
5. Tick the mods you want and press **Apply ticks**.

What the buttons do:

| Button | What it does |
|---|---|
| **Apply ticks** | Installs and switches on every ticked mod. Switches off every unticked mod; you choose whether its files are deleted (a backup is kept). |
| **Update all** | Installs the newest release of every installed mod that has one. |
| **Check for updates** | Asks GitHub for the newest versions. It also runs when the window opens, unless you untick that option. |
| **Open mod page** | Opens the selected mod's Nexus page. Double-clicking a row does the same. |

When Windows asks, allow the script to run. It is plain PowerShell, so you can read every line in `SB2RealismInstaller.ps1`.

## The realism set

| Mod | What it does | Links |
|---|---|---|
| Hardcore Tactical Realism (HTR) | Combat and AI overhaul: caliber vs armor, hit zones, wounds, faction doctrines | [GitHub](https://github.com/hubertdungen/SpaceBourne2-HardcoreTacticalRealism) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/4) · [Steam](https://steamcommunity.com/app/1646850/discussions/0/573805072991123580/) |
| Split Controls | Separate look inversion for ships and on foot | [GitHub](https://github.com/hubertdungen/SpaceBourne2-SplitControls) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/5) |
| Silent Ops | Realistic stealth, suppressors, silent takedowns | [GitHub](https://github.com/hubertdungen/SpaceBourne2-SilentOps) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/6) |
| Gear Without Levels | Any weapon or suit at any level, with small penalties | [GitHub](https://github.com/hubertdungen/SpaceBourne2-GearWithoutLevels) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/7) |
| SB2 HOTAS | Joystick, HOTAS, pedals, head tracking, triple screen | [GitHub](https://github.com/hubertdungen/SpaceBourne2-HOTAS) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/8) |
| Faction Power | Dungeons, sales and missions earn your faction power | [GitHub](https://github.com/hubertdungen/SpaceBourne2-FactionPower) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/9) |
| Tactical Engineering | Deployable turrets that take time to set up | [GitHub](https://github.com/hubertdungen/SpaceBourne2-TacticalEngineering) · [Nexus](https://www.nexusmods.com/spacebourne2/mods/10) |

SB2 HOTAS has its own bridge app, and that app installs and updates it. The installer shows its state and links to it.

**Coming soon:** Tactical First Person, Ammo Discipline, Get Out of the Way and Ground Waypoints. They are already in the installer's list, greyed out as "coming soon". Each one becomes installable on its own as soon as it is released, without a new installer.

## Details

- **On/off switch.** A mod is switched on through its line in `SB2\Binaries\Win64\Mods\mods.txt` (`Name : 1`). Managed mods don't use `enabled.txt`, so switching a mod off really switches it off.
- **Ticking a mod switches on its main features.**
  - It sets the master switch in `config.lua`, e.g. `Enabled` (and `StartOn` for Tactical Engineering).
  - If the mod remembers an in-game toggle, it resets that toggle to on.
  - Optional extras inside a mod keep your choice, e.g. HTR's gear bonus.
- **Command line** (for scripts):
  ```
  powershell -ExecutionPolicy Bypass -File SB2RealismInstaller.ps1 -NoGui -List
  powershell -ExecutionPolicy Bypass -File SB2RealismInstaller.ps1 -NoGui -Apply "htr,silentops,gear" [-Delete]
  powershell -ExecutionPolicy Bypass -File SB2RealismInstaller.ps1 -NoGui -UpdateAll
  ```
  Mod ids are in `mods.json`. `-GamePath "D:\Games\SpaceBourne 2"` skips the automatic search.

## Credits

- Made by hubertdungen.
- Thanks to TheCalcMan for testing the set and for his ideas.
- UE4SS by the [RE-UE4SS](https://github.com/UE4SS-RE/RE-UE4SS) team (MIT). The installer downloads it from HTR's full release, which includes the licence notice.

MIT licence.
