# Jellyfin ikona u sistemskoj traci
# Pokrece se automatski pri prijavi u Windows (putem zakazanog zadatka)

param()
$ErrorActionPreference = 'SilentlyContinue'

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing

$ImeServisa   = "JellyfinServer"
$JellyfinPort = 8096
$JellyfinExe  = "$env:ProgramFiles\Jellyfin\Server\jellyfin.exe"

# ---------------------------------------------------------------------------
# Pomocne funkcije
# ---------------------------------------------------------------------------
function Get-JellyfinRadi {
    $svc = Get-Service -Name $ImeServisa -ErrorAction SilentlyContinue
    if ($svc) { return ($svc.Status -eq 'Running') }
    return ($null -ne (Get-Process -Name "jellyfin" -ErrorAction SilentlyContinue))
}

function Invoke-PokretanjeJellyfin {
    $svc = Get-Service -Name $ImeServisa -ErrorAction SilentlyContinue
    if ($svc)                    { Start-Service -Name $ImeServisa }
    elseif (Test-Path $JellyfinExe) { Start-Process $JellyfinExe -WindowStyle Hidden }
}

function Invoke-GasenjeJellyfin {
    $svc = Get-Service -Name $ImeServisa -ErrorAction SilentlyContinue
    if ($svc) { Stop-Service -Name $ImeServisa -Force }
    else      { Get-Process -Name "jellyfin" -ErrorAction SilentlyContinue | Stop-Process -Force }
}

# ---------------------------------------------------------------------------
# Ikona (Jellyfin .ico ako postoji, inace iscrtana plava tocka)
# ---------------------------------------------------------------------------
try {
    $icoPath = "$env:ProgramFiles\Jellyfin\Server\jellyfin.ico"
    if (Test-Path $icoPath) {
        $trayIkona = New-Object System.Drawing.Icon($icoPath)
    } else {
        $bmp = New-Object System.Drawing.Bitmap(16, 16)
        $g   = [System.Drawing.Graphics]::FromImage($bmp)
        $g.SmoothingMode = [System.Drawing.Drawing2D.SmoothingMode]::AntiAlias
        $g.Clear([System.Drawing.Color]::Transparent)
        $kist = New-Object System.Drawing.SolidBrush([System.Drawing.Color]::FromArgb(0, 164, 220))
        $g.FillEllipse($kist, 0, 0, 15, 15)
        $g.Dispose()
        $trayIkona = [System.Drawing.Icon]::FromHandle($bmp.GetHicon())
    }
} catch {
    $trayIkona = [System.Drawing.SystemIcons]::Information
}

# ---------------------------------------------------------------------------
# Ikona i izbornik
# ---------------------------------------------------------------------------
$tray         = New-Object System.Windows.Forms.NotifyIcon
$tray.Icon    = $trayIkona
$tray.Visible = $true

$izbornik = New-Object System.Windows.Forms.ContextMenuStrip

# Status (onemogucena stavka - samo za prikaz)
$stavkaStatus = New-Object System.Windows.Forms.ToolStripMenuItem
$stavkaStatus.Enabled = $false
$izbornik.Items.Add($stavkaStatus) | Out-Null
$izbornik.Items.Add([System.Windows.Forms.ToolStripSeparator]::new()) | Out-Null

$stavkaPokreni  = New-Object System.Windows.Forms.ToolStripMenuItem("Pokreni Jellyfin")
$stavkaUgasi    = New-Object System.Windows.Forms.ToolStripMenuItem("Ugasi Jellyfin")
$stavkaOtvori   = New-Object System.Windows.Forms.ToolStripMenuItem("Otvori u browseru")
$stavkaZatvori  = New-Object System.Windows.Forms.ToolStripMenuItem("Zatvori ovu ikonu")

$izbornik.Items.Add($stavkaPokreni)  | Out-Null
$izbornik.Items.Add($stavkaUgasi)    | Out-Null
$izbornik.Items.Add([System.Windows.Forms.ToolStripSeparator]::new()) | Out-Null
$izbornik.Items.Add($stavkaOtvori)   | Out-Null
$izbornik.Items.Add([System.Windows.Forms.ToolStripSeparator]::new()) | Out-Null
$izbornik.Items.Add($stavkaZatvori)  | Out-Null

$tray.ContextMenuStrip = $izbornik

# ---------------------------------------------------------------------------
# Osvjezavanje statusa (poziva se iz tajmera i iz handlera)
# ---------------------------------------------------------------------------
function Update-Status {
    if (Get-JellyfinRadi) {
        $tray.Text             = "Jellyfin radi"
        $stavkaStatus.Text     = "[ON]  Jellyfin radi"
        $stavkaPokreni.Enabled  = $false
        $stavkaUgasi.Enabled    = $true
        $stavkaOtvori.Enabled   = $true
    } else {
        $tray.Text             = "Jellyfin je ugasen"
        $stavkaStatus.Text     = "[OFF] Jellyfin je ugasen"
        $stavkaPokreni.Enabled  = $true
        $stavkaUgasi.Enabled    = $false
        $stavkaOtvori.Enabled   = $false
    }
}

# ---------------------------------------------------------------------------
# Handleri klikova
# ---------------------------------------------------------------------------
$stavkaPokreni.add_Click({
    Invoke-PokretanjeJellyfin
    Start-Sleep -Seconds 3
    Update-Status
    $tray.ShowBalloonTip(5000, "Jellyfin", "Jellyfin je pokrenut!`nMozes ga otvoriti na TV-u.", [System.Windows.Forms.ToolTipIcon]::Info)
})

$stavkaUgasi.add_Click({
    Invoke-GasenjeJellyfin
    Start-Sleep -Seconds 2
    Update-Status
    $tray.ShowBalloonTip(4000, "Jellyfin", "Jellyfin je ugasen.", [System.Windows.Forms.ToolTipIcon]::Info)
})

$stavkaOtvori.add_Click({
    Start-Process "http://localhost:$JellyfinPort"
})

$stavkaZatvori.add_Click({
    $tajmer.Stop()
    $tray.Visible = $false
    [System.Windows.Forms.Application]::Exit()
})

# ---------------------------------------------------------------------------
# Tajmer - osvjezava status svakih 6 sekundi
# ---------------------------------------------------------------------------
$tajmer = New-Object System.Windows.Forms.Timer
$tajmer.Interval = 6000
$tajmer.add_Tick({ Update-Status })
$tajmer.Start()

# ---------------------------------------------------------------------------
# Pocetno stanje i obavijest pri pokretanju
# ---------------------------------------------------------------------------
Update-Status

if (Get-JellyfinRadi) {
    $tray.ShowBalloonTip(
        6000,
        "Jellyfin radi",
        "Jellyfin radi, klikni ""Ugasi"" da ga ugasis.`n(Desni klik na ovu ikonu)",
        [System.Windows.Forms.ToolTipIcon]::Info
    )
}

[System.Windows.Forms.Application]::Run()
