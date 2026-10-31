# SpaceBourne 2 Realism - installer and updater for the realism mod set.
# Double-click "Install SB2 Realism.cmd". Never touches saves or the game executable.
# Headless use (tests, scripts):
#   -NoGui -List                       show installed / latest versions
#   -NoGui -Apply "htr,silentops"      the full ticked set: install + activate these, deactivate the rest
#   -NoGui -UpdateAll                  update every installed mod that has a newer release
#   -NoGui -InstallUE4SS               install UE4SS 3.0.1 (bundled in HTR's full release)
#   -GamePath "D:\...\SpaceBourne 2"   skip auto-detection; -Delete also removes unticked folders
param(
    [string]$GamePath,
    [switch]$NoGui,
    [switch]$List,
    [string]$Apply,
    [switch]$UpdateAll,
    [switch]$InstallUE4SS,
    [switch]$Delete,
    [string]$Manifest
)
$ErrorActionPreference = 'Stop'
$AppVersion = '0.1.0'
$AppRepo = 'hubertdungen/SpaceBourne2-Realism'
$ManifestUrl = "https://raw.githubusercontent.com/$AppRepo/main/mods.json"
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
$Utf8 = New-Object Text.UTF8Encoding($false)
$DataDir = Join-Path $env:LOCALAPPDATA 'SB2Realism'
$script:Gui = $null          # log textbox when the window is open
$script:Latest = @{}         # mod id -> @{ Version; Url } from GitHub

# ---------- helpers ----------
function Log([string]$msg) {
    if ($script:Gui) {
        $script:Gui.AppendText($msg + [Environment]::NewLine)
        [System.Windows.Forms.Application]::DoEvents()
    } else { Write-Host $msg }
}

function Find-Game {
    $roots = @()
    $steam = (Get-ItemProperty 'HKCU:\Software\Valve\Steam' -ErrorAction SilentlyContinue).SteamPath
    if ($steam) {
        $roots += ($steam -replace '/', '\') + '\steamapps'
        $vdf = Join-Path $steam 'steamapps\libraryfolders.vdf'
        if (Test-Path $vdf) {
            Select-String -Path $vdf -Pattern '"path"\s+"([^"]+)"' | ForEach-Object {
                $roots += (($_.Matches[0].Groups[1].Value -replace '\\\\', '\').TrimEnd('\') + '\steamapps')
            }
        }
    }
    foreach ($r in $roots) {
        $g = "$r\common\SpaceBourne 2"
        if (Test-GameDir $g) { return $g }
    }
    return $null
}

function Test-GameDir([string]$g) {
    if (-not $g) { return $false }
    return [bool](Test-Path -LiteralPath (Join-Path $g 'SB2\Binaries\Win64\SB2-Win64-Shipping.exe') -ErrorAction SilentlyContinue)
}

function Win64 { Join-Path $script:Game 'SB2\Binaries\Win64' }
function ModsDir { Join-Path (Win64) 'Mods' }
function ModsTxt { Join-Path (ModsDir) 'mods.txt' }
function ModDir($m) { Join-Path (ModsDir) $m.folder }

function Read-Text([string]$p) { [IO.File]::ReadAllText($p, $Utf8) }
function Write-Text([string]$p, [string]$t) { [IO.File]::WriteAllText($p, $t, $Utf8) }

function Get-Mods {
    $json = $null
    if ($Manifest) { $json = Read-Text $Manifest }
    else {
        try { $json = (Invoke-WebRequest $ManifestUrl -UseBasicParsing -TimeoutSec 6).Content } catch { }
        if (-not $json) { $json = Read-Text (Join-Path $PSScriptRoot 'mods.json') }
    }
    return @(($json | ConvertFrom-Json).mods)
}

function Compare-Ver([string]$a, [string]$b) {
    $a = $a.TrimStart('v'); $b = $b.TrimStart('v')
    try { return ([version]$a).CompareTo([version]$b) } catch { return [string]::Compare($a, $b) }
}

function Test-GameRunning { [bool](Get-Process 'SB2-Win64-Shipping' -ErrorAction SilentlyContinue) }

# ---------- mods.txt ----------
function Get-ModsTxtLines {
    $p = ModsTxt
    $l = New-Object 'Collections.Generic.List[string]'
    if (Test-Path $p) { $l.AddRange([string[]][IO.File]::ReadAllLines($p, $Utf8)) }
    return , $l   # the comma keeps PowerShell from unrolling the list
}

function Get-ModsTxtState([string]$folder) {
    $lines = Get-ModsTxtLines
    foreach ($l in $lines) {
        if ($l -match "^\s*$([regex]::Escape($folder))\s*:\s*(\d)") { return $Matches[1] }
    }
    return $null
}

function Set-ModsTxt([string]$folder, [bool]$on) {
    New-Item -ItemType Directory -Force (ModsDir) | Out-Null
    $lines = Get-ModsTxtLines
    $v = if ($on) { 1 } else { 0 }
    $at = -1
    for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match "^\s*$([regex]::Escape($folder))\s*:") { $at = $i; break } }
    if ($at -ge 0) { $lines[$at] = "$folder : $v" }
    else {
        $kb = -1
        for ($i = 0; $i -lt $lines.Count; $i++) { if ($lines[$i] -match '^\s*Keybinds\s*:') { $kb = $i; break } }
        if ($kb -ge 0) { $lines.Insert($kb, "$folder : $v") } else { $lines.Add("$folder : $v") }
    }
    [IO.File]::WriteAllLines((ModsTxt), $lines.ToArray(), $Utf8)
}

# ---------- status ----------
function Get-Installed($m) {
    $d = ModDir $m
    if (-not (Test-Path $d)) { return $null }
    $ver = '?'
    $main = Join-Path $d 'scripts\main.lua'
    if (Test-Path $main) {
        $mm = [regex]::Match((Read-Text $main), 'VERSION\s*=\s*"([^"]+)"')
        if ($mm.Success) { $ver = $mm.Groups[1].Value }
    }
    $state = Get-ModsTxtState $m.folder
    $active = ($state -eq '1') -or (($state -ne '0') -and (Test-Path (Join-Path $d 'enabled.txt')))
    return @{ Version = $ver; Active = $active }
}

function Get-LatestRelease($m) {
    $r = Invoke-RestMethod "https://api.github.com/repos/$($m.repo)/releases/latest" -TimeoutSec 15
    $url = $null
    if ($m.asset) {
        $a = @($r.assets | Where-Object { $_.name -match $m.asset }) | Select-Object -First 1
        if ($a) { $url = $a.browser_download_url }
    }
    return @{ Version = $r.tag_name.TrimStart('v'); Url = $url; Page = $r.html_url }
}

function Update-Latest($mods) {
    foreach ($m in $mods) {
        try { $script:Latest[$m.id] = Get-LatestRelease $m }
        catch { Log "  Could not check $($m.name): $($_.Exception.Message)" }
    }
}

function Get-StatusText($m) {
    $inst = Get-Installed $m
    $lat = $script:Latest[$m.id]
    if (-not $inst) { return 'not installed' }
    $s = if ($inst.Active) { 'active' } else { 'installed, off' }
    if ($lat -and $inst.Version -ne '?') {
        $c = Compare-Ver $inst.Version $lat.Version
        if ($c -lt 0) { $s += " - update $($inst.Version) -> $($lat.Version)" }
        elseif ($c -gt 0) { $s += ' - newer than release' }
        else { $s += ' - up to date' }
    }
    return $s
}

# ---------- actions ----------
function Backup-ModDir($m) {
    $d = ModDir $m
    if (-not (Test-Path $d)) { return }
    $inst = Get-Installed $m
    $dst = Join-Path $DataDir ("backups\{0}-{1}-{2}" -f $m.folder, $inst.Version, (Get-Date -Format 'yyyyMMdd-HHmmss'))
    New-Item -ItemType Directory -Force $dst | Out-Null
    Copy-Item (Join-Path $d '*') $dst -Recurse -Force
    Log "  Backup: $dst"
}

function Install-ModFiles($m) {
    if ($m.external) { throw "$($m.name) is installed by its own app." }
    $lat = $script:Latest[$m.id]
    if (-not $lat) { $lat = Get-LatestRelease $m; $script:Latest[$m.id] = $lat }
    if (-not $lat.Url) { throw "No download found for $($m.name)." }
    $tmp = Join-Path $env:TEMP ('SB2Realism_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $tmp | Out-Null
    try {
        Log "  Downloading $($m.name) $($lat.Version)..."
        $zip = Join-Path $tmp 'mod.zip'
        Invoke-WebRequest $lat.Url -OutFile $zip -UseBasicParsing
        Expand-Archive $zip (Join-Path $tmp 'x') -Force
        $src = Get-ChildItem (Join-Path $tmp 'x') -Recurse -Directory |
            Where-Object { $_.Name -eq $m.folder -and (Test-Path (Join-Path $_.FullName 'scripts\main.lua')) } |
            Select-Object -First 1
        if (-not $src) { throw "The download has no $($m.folder) folder." }
        $dest = ModDir $m
        Backup-ModDir $m
        $cfg = Join-Path $dest 'scripts\config.lua'
        $keep = $null
        if (Test-Path $cfg) { $keep = Read-Text $cfg }
        # enabled.txt is skipped: mods.txt is the one on/off switch.
        Get-ChildItem $src.FullName -Recurse -File | Where-Object { $_.Name -ne 'enabled.txt' } | ForEach-Object {
            $rel = $_.FullName.Substring($src.FullName.Length).TrimStart('\')
            $to = Join-Path $dest $rel
            New-Item -ItemType Directory -Force (Split-Path $to) | Out-Null
            Copy-Item $_.FullName $to -Force
        }
        if ($keep) {
            Copy-Item $cfg (Join-Path $dest 'scripts\config.default.lua') -Force
            Write-Text $cfg $keep
            Log "  Kept your config.lua (new defaults: scripts\config.default.lua)."
        }
        Log "  Installed $($m.name) $($lat.Version)."
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

function Enable-Mod($m) {
    $d = ModDir $m
    Set-ModsTxt $m.folder $true
    # mods.txt is the one switch: enabled.txt would keep a mod loading after it is set to 0.
    Remove-Item (Join-Path $d 'enabled.txt') -ErrorAction SilentlyContinue
    $cfg = Join-Path $d 'scripts\config.lua'
    if ((Test-Path $cfg) -and $m.switches) {
        $t = Read-Text $cfg; $orig = $t
        foreach ($k in $m.switches) {
            $re = New-Object regex ("(?m)^(\s*$([regex]::Escape($k))\s*=\s*)false\b")
            $t = $re.Replace($t, '${1}true', 1)
        }
        if ($t -ne $orig) { Write-Text $cfg $t; Log "  Switched on in config.lua: $($m.switches -join ', ')." }
    }
    foreach ($s in @($m.state)) {
        if (-not $s) { continue }
        $f = Join-Path $d $s.file
        if (-not (Test-Path $f)) { continue }
        $t = Read-Text $f
        $re = New-Object regex ("(?m)^$([regex]::Escape($s.key))=.*$")
        $n = $re.Replace($t, "$($s.key)=$($s.value)", 1)
        if ($n -ne $t) { Write-Text $f $n; Log "  Saved toggle reset to on ($($s.file))." }
    }
    Log "  $($m.name) is active."
}

function Disable-Mod($m, [bool]$remove) {
    if (Test-Path (ModDir $m)) {
        Set-ModsTxt $m.folder $false
        Remove-Item (Join-Path (ModDir $m) 'enabled.txt') -ErrorAction SilentlyContinue
    }
    if ($remove) {
        Backup-ModDir $m
        Remove-Item (ModDir $m) -Recurse -Force
        Log "  Removed $($m.name) (backup kept)."
    } else { Log "  $($m.name) switched off (files kept)." }
}

function Test-UE4SS { Test-Path (Join-Path (Win64) 'UE4SS.dll') }

function Install-UE4SSFiles {
    $w = Win64
    if (Test-UE4SS) { Log 'UE4SS is already installed.'; return }
    if (Test-Path (Join-Path $w 'dwmapi.dll')) { throw 'The game folder already has a dwmapi.dll from another mod loader. Remove it first.' }
    # UE4SS 3.0.1 ships inside Hardcore Tactical Realism's full release (MIT licence notice included there).
    $r = Invoke-RestMethod 'https://api.github.com/repos/hubertdungen/SpaceBourne2-HardcoreTacticalRealism/releases/latest' -TimeoutSec 15
    $a = @($r.assets | Where-Object { $_.name -match '^HardcoreTacticalRealism-[\d.]+\.zip$' }) | Select-Object -First 1
    if (-not $a) { throw 'UE4SS download not found.' }
    $tmp = Join-Path $env:TEMP ('SB2Realism_' + [guid]::NewGuid().ToString('N'))
    New-Item -ItemType Directory -Force $tmp | Out-Null
    try {
        Log 'Downloading UE4SS 3.0.1...'
        Invoke-WebRequest $a.browser_download_url -OutFile (Join-Path $tmp 'u.zip') -UseBasicParsing
        Expand-Archive (Join-Path $tmp 'u.zip') (Join-Path $tmp 'x') -Force
        $u = Join-Path $tmp 'x\ue4ss'
        Copy-Item (Join-Path $u 'dwmapi.dll'), (Join-Path $u 'UE4SS.dll') $w -Force
        $ini = (Read-Text (Join-Path $u 'UE4SS-settings.ini')) -replace '(?m)^GuiConsoleEnabled\s*=.*$', 'GuiConsoleEnabled = 0'
        Write-Text (Join-Path $w 'UE4SS-settings.ini') $ini
        New-Item -ItemType Directory -Force (ModsDir) | Out-Null
        if (-not (Test-Path (ModsTxt))) { Write-Text (ModsTxt) '' }
        Write-Text (Join-Path $w 'SB2Realism-installed-UE4SS.txt') 'UE4SS was installed by the SpaceBourne 2 Realism installer.'
        Log 'UE4SS 3.0.1 installed.'
    } finally { Remove-Item $tmp -Recurse -Force -ErrorAction SilentlyContinue }
}

# Ticked = the full wanted set. Returns nothing; logs each step.
function Invoke-Apply($mods, [string[]]$ticked, [scriptblock]$askRemove) {
    if (Test-GameRunning) { throw 'Close SpaceBourne 2 first.' }
    if (-not (Test-UE4SS)) { Install-UE4SSFiles }
    foreach ($m in $mods) {
        $inst = Get-Installed $m
        if ($ticked -contains $m.id) {
            Log "$($m.name):"
            if ($m.external) {
                if ($inst) { Set-ModsTxt $m.folder $true; Log '  active (updates come from its own app).' }
                else { Log "  Install it with its own app: https://www.nexusmods.com/spacebourne2/mods/$($m.nexus)" }
                continue
            }
            try {
                if (-not $inst) { Install-ModFiles $m }
                Enable-Mod $m
            } catch { Log "  FAILED: $($_.Exception.Message)" }
        } elseif ($inst -and $inst.Active) {
            Log "$($m.name):"
            $remove = $false
            if ($askRemove -and -not $m.external) { $remove = & $askRemove $m }
            if ($remove -eq $null) { Log '  skipped.'; continue }
            Disable-Mod $m ([bool]$remove)
        }
    }
    Log 'Done.'
}

function Invoke-UpdateAll($mods) {
    if (Test-GameRunning) { throw 'Close SpaceBourne 2 first.' }
    Update-Latest $mods
    $any = $false
    foreach ($m in $mods) {
        $inst = Get-Installed $m
        $lat = $script:Latest[$m.id]
        if (-not $inst -or -not $lat -or $inst.Version -eq '?') { continue }
        if ((Compare-Ver $inst.Version $lat.Version) -ge 0) { continue }
        $any = $true
        Log "$($m.name): $($inst.Version) -> $($lat.Version)"
        if ($m.external) { Log '  Update it from its own app or its page.'; continue }
        try {
            Install-ModFiles $m
            if ($inst.Active) { Enable-Mod $m }
        } catch { Log "  FAILED: $($_.Exception.Message)" }
    }
    if (-not $any) { Log 'Everything is up to date.' }
    Log 'Done.'
}

function Test-InstallerUpdate {
    try {
        $r = Invoke-RestMethod "https://api.github.com/repos/$AppRepo/releases/latest" -TimeoutSec 8
        if ((Compare-Ver $AppVersion $r.tag_name) -lt 0) { Log "A newer installer is available: $($r.tag_name) - $($r.html_url)" }
    } catch { }
}

# ---------- headless ----------
$script:Game = $GamePath
if (-not $script:Game) { $script:Game = Find-Game }

if ($NoGui) {
    if (-not (Test-GameDir $script:Game)) { throw 'SpaceBourne 2 not found. Use -GamePath.' }
    Log "Game: $($script:Game)"
    $mods = Get-Mods
    if ($InstallUE4SS) { Install-UE4SSFiles }
    if ($Apply) {
        $ids = @($Apply -split '[,; ]+' | Where-Object { $_ })
        Invoke-Apply $mods $ids ([scriptblock]::Create("return `$$([bool]$Delete)"))
    }
    if ($UpdateAll) { Invoke-UpdateAll $mods }
    if ($List -or (-not $Apply -and -not $UpdateAll -and -not $InstallUE4SS)) {
        Update-Latest $mods
        Log ("UE4SS: " + $(if (Test-UE4SS) { 'installed' } else { 'missing' }))
        foreach ($m in $mods) {
            $inst = Get-Installed $m
            $lat = $script:Latest[$m.id]
            Log ("{0,-34} {1,-8} {2,-8} {3}" -f $m.name, $(if ($inst) { $inst.Version } else { '-' }), $(if ($lat) { $lat.Version } else { '?' }), (Get-StatusText $m))
        }
    }
    return
}

# ---------- window ----------
Add-Type -AssemblyName System.Windows.Forms, System.Drawing
[System.Windows.Forms.Application]::EnableVisualStyles()

$settingsFile = Join-Path $DataDir 'settings.json'
$settings = @{ checkOnStart = $true }
try { if (Test-Path $settingsFile) { $settings.checkOnStart = [bool]((Read-Text $settingsFile | ConvertFrom-Json).checkOnStart) } } catch { }

$form = New-Object System.Windows.Forms.Form
$form.Text = "SpaceBourne 2 Realism - installer $AppVersion"
$form.Size = New-Object System.Drawing.Size(980, 640)
$form.MinimumSize = New-Object System.Drawing.Size(760, 480)
$form.StartPosition = 'CenterScreen'
$form.Font = New-Object System.Drawing.Font('Segoe UI', 9)

$lv = New-Object System.Windows.Forms.ListView
$lv.Dock = 'Fill'; $lv.View = 'Details'; $lv.CheckBoxes = $true; $lv.FullRowSelect = $true; $lv.GridLines = $true
foreach ($c in @(@('Mod', 240), @('Installed', 75), @('Latest', 75), @('Status', 230), @('About', 420))) { [void]$lv.Columns.Add($c[0], $c[1]) }

$log = New-Object System.Windows.Forms.TextBox
$log.Dock = 'Bottom'; $log.Multiline = $true; $log.ScrollBars = 'Vertical'; $log.ReadOnly = $true; $log.Height = 150
$script:Gui = $log

$buttons = New-Object System.Windows.Forms.FlowLayoutPanel
$buttons.Dock = 'Bottom'; $buttons.Height = 40; $buttons.Padding = New-Object System.Windows.Forms.Padding(4)
function New-Button([string]$text, [int]$w) {
    $b = New-Object System.Windows.Forms.Button
    $b.Text = $text; $b.Width = $w; $b.Height = 28
    [void]$buttons.Controls.Add($b); return $b
}
$bApply = New-Button 'Apply ticks' 110
$bUpdate = New-Button 'Update all' 100
$bCheck = New-Button 'Check for updates' 140
$bPage = New-Button 'Open mod page' 120
$cbStart = New-Object System.Windows.Forms.CheckBox
$cbStart.Text = 'Check for updates when this opens'; $cbStart.AutoSize = $true; $cbStart.Checked = $settings.checkOnStart
$cbStart.Margin = New-Object System.Windows.Forms.Padding(14, 8, 3, 3)
[void]$buttons.Controls.Add($cbStart)

$top = New-Object System.Windows.Forms.FlowLayoutPanel
$top.Dock = 'Top'; $top.Height = 96; $top.Padding = New-Object System.Windows.Forms.Padding(4)
$lblGame = New-Object System.Windows.Forms.Label
$lblGame.Text = 'Game folder:'; $lblGame.AutoSize = $true; $lblGame.Margin = New-Object System.Windows.Forms.Padding(3, 8, 3, 3)
$txtGame = New-Object System.Windows.Forms.TextBox
$txtGame.Width = 560; $txtGame.ReadOnly = $true
$bBrowse = New-Object System.Windows.Forms.Button
$bBrowse.Text = 'Browse...'; $bBrowse.Width = 90; $bBrowse.Height = 26
$lblUe = New-Object System.Windows.Forms.Label
$lblUe.AutoSize = $true; $lblUe.Margin = New-Object System.Windows.Forms.Padding(3, 8, 3, 3)
$bUe = New-Object System.Windows.Forms.Button
$bUe.Text = 'Install UE4SS'; $bUe.Width = 110; $bUe.Height = 26
$hint = New-Object System.Windows.Forms.Label
$hint.AutoSize = $true; $hint.Margin = New-Object System.Windows.Forms.Padding(3, 6, 3, 3)
$hint.Text = 'Tick the mods you want and press Apply ticks. Every ticked mod is installed and switched on; unticked mods are switched off.'
$top.Controls.AddRange(@($lblGame, $txtGame, $bBrowse, $lblUe, $bUe, $hint))
$top.SetFlowBreak($bBrowse, $true); $top.SetFlowBreak($bUe, $true)

# Fill first, then the bottom bars, then the top bar (WinForms docks the last-added control first).
$form.Controls.Add($lv); $form.Controls.Add($log); $form.Controls.Add($buttons); $form.Controls.Add($top)

$script:Mods = @()

function Set-Busy([bool]$busy) {
    foreach ($c in @($bApply, $bUpdate, $bCheck, $bBrowse, $bUe)) { $c.Enabled = -not $busy }
    $form.UseWaitCursor = $busy
    [System.Windows.Forms.Application]::DoEvents()
}

function Update-View {
    $ok = Test-GameDir $script:Game
    $txtGame.Text = if ($ok) { $script:Game } else { '(not found - press Browse)' }
    if ($ok -and (Test-UE4SS)) { $lblUe.Text = 'UE4SS: installed'; $bUe.Visible = $false }
    elseif ($ok) { $lblUe.Text = 'UE4SS: missing (needed by every mod)'; $bUe.Visible = $true }
    else { $lblUe.Text = ''; $bUe.Visible = $false }
    $top.SetFlowBreak($lblUe, -not $bUe.Visible)
    $lv.BeginUpdate(); $lv.Items.Clear()
    foreach ($m in $script:Mods) {
        $inst = if ($ok) { Get-Installed $m } else { $null }
        $lat = $script:Latest[$m.id]
        $it = New-Object System.Windows.Forms.ListViewItem($m.name)
        [void]$it.SubItems.Add($(if ($inst) { $inst.Version } else { '-' }))
        [void]$it.SubItems.Add($(if ($lat) { $lat.Version } else { '' }))
        [void]$it.SubItems.Add($(if ($ok) { Get-StatusText $m } else { '' }))
        [void]$it.SubItems.Add($m.desc)
        $it.Checked = [bool]($inst -and $inst.Active)
        $it.Tag = $m
        [void]$lv.Items.Add($it)
    }
    $lv.EndUpdate()
    foreach ($c in @($bApply, $bUpdate, $bCheck)) { $c.Enabled = $ok }
}

function Invoke-Safe([scriptblock]$work) {
    Set-Busy $true
    try { & $work } catch { Log "ERROR: $($_.Exception.Message)" }
    finally { Set-Busy $false; Update-View }
}

$bBrowse.Add_Click({
    $dlg = New-Object System.Windows.Forms.FolderBrowserDialog
    $dlg.Description = 'Select the "SpaceBourne 2" folder (it contains SB2\Binaries\Win64\SB2-Win64-Shipping.exe)'
    if ($dlg.ShowDialog($form) -eq 'OK') {
        if (Test-GameDir $dlg.SelectedPath) { $script:Game = $dlg.SelectedPath; Update-View }
        else { [void][System.Windows.Forms.MessageBox]::Show($form, 'That folder is not a SpaceBourne 2 install.', 'SB2 Realism') }
    }
})
$bUe.Add_Click({ Invoke-Safe { Install-UE4SSFiles } })
$bCheck.Add_Click({ Invoke-Safe { Log 'Checking GitHub for new versions...'; Update-Latest $script:Mods; Test-InstallerUpdate; Log 'Done.' } })
$bUpdate.Add_Click({ Invoke-Safe { Invoke-UpdateAll $script:Mods } })
$bApply.Add_Click({
    $ticked = @($lv.Items | Where-Object { $_.Checked } | ForEach-Object { $_.Tag.id })
    $ask = {
        param($m)
        $r = [System.Windows.Forms.MessageBox]::Show($form, "Switch off $($m.name)?`n`nYes = switch off and delete its files (a backup is kept)`nNo = switch off, keep the files`nCancel = leave it on", 'SB2 Realism', 'YesNoCancel', 'Question')
        if ($r -eq 'Yes') { return $true } elseif ($r -eq 'No') { return $false } else { return $null }
    }
    Invoke-Safe { Invoke-Apply $script:Mods $ticked $ask }
})
$bPage.Add_Click({
    $sel = $lv.SelectedItems
    if ($sel.Count -eq 0) { Log 'Select a mod first.'; return }
    Start-Process "https://www.nexusmods.com/spacebourne2/mods/$($sel[0].Tag.nexus)"
})
$lv.Add_DoubleClick({ $bPage.PerformClick() })
$cbStart.Add_CheckedChanged({
    try {
        New-Item -ItemType Directory -Force $DataDir | Out-Null
        Write-Text $settingsFile (@{ checkOnStart = $cbStart.Checked } | ConvertTo-Json)
    } catch { }
})
$form.Add_Shown({
    Invoke-Safe {
        $script:Mods = Get-Mods
        if (-not (Test-GameDir $script:Game)) { Log 'SpaceBourne 2 was not found automatically. Press Browse and pick its folder.' }
        else { Log "Game: $($script:Game)" }
        if ($cbStart.Checked) { Log 'Checking GitHub for new versions...'; Update-Latest $script:Mods; Test-InstallerUpdate }
        if (Test-GameRunning) { Log 'SpaceBourne 2 is running: close it before applying changes.' }
    }
})

[void]$form.ShowDialog()
