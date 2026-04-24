#Requires -RunAsAdministrator

function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor Red
    Write-Host "         Jellyfin - Potpuna deinstalacija          " -ForegroundColor Red
    Write-Host "  ================================================" -ForegroundColor Red
    Write-Host ""
}

function Write-Korak  { param([string]$t) Write-Host "  [..] $t" -ForegroundColor Yellow    }
function Write-Ok     { param([string]$t) Write-Host "  [OK] $t" -ForegroundColor Green      }
function Write-Upoz   { param([string]$t) Write-Host "  [!!] $t" -ForegroundColor DarkYellow }
function Write-Info   { param([string]$t) Write-Host "       $t" -ForegroundColor Gray       }

Write-Banner
Write-Host "  Ovo ce potpuno ukloniti:" -ForegroundColor White
Write-Host "    * Jellyfin server i sve njegove podatke"    -ForegroundColor Gray
Write-Host "    * Ikonu u sistemskoj traci i zakazani zadatak" -ForegroundColor Gray
Write-Host "    * Pravilo vatrozida"                        -ForegroundColor Gray
Write-Host "    * Staticku IP adresu (vraca se na DHCP)"    -ForegroundColor Gray
Write-Host ""
$potvrda = Read-Host "  Jesi li siguran? [D/N]"
if ($potvrda.Trim().ToUpper() -ne "D") {
    Write-Host "  Odustajanje. Nista nije uklonjeno." -ForegroundColor Cyan
    Start-Sleep -Seconds 2
    exit 0
}
Write-Host ""

# ---------------------------------------------------------------------------
# 1. Ugasi i ukloni ikonu iz sistemske trake
# ---------------------------------------------------------------------------
Write-Korak "Gasim ikonu u sistemskoj traci..."
try {
    $proc = Get-CimInstance Win32_Process -Filter "Name='powershell.exe'" -ErrorAction SilentlyContinue |
        Where-Object { $_.CommandLine -like "*tray_jellyfin*" }
    if ($proc) {
        $proc | ForEach-Object { Stop-Process -Id $_.ProcessId -Force -ErrorAction SilentlyContinue }
        Write-Ok "Ikona ugasena."
    } else {
        Write-Info "Ikona vec nije bila pokrenuta."
    }
} catch { Write-Upoz "Nije uspjelo gasenje ikone: $_" }

# ---------------------------------------------------------------------------
# 2. Ukloni zakazani zadatak
# ---------------------------------------------------------------------------
Write-Korak "Uklanjam zakazani zadatak (JellyfinTray)..."
try {
    Unregister-ScheduledTask -TaskName "JellyfinTray" -Confirm:$false -ErrorAction Stop
    Write-Ok "Zakazani zadatak uklonjen."
} catch {
    if ($_.Exception.Message -match "cannot find") { Write-Info "Zakazani zadatak nije ni postojao." }
    else { Write-Upoz "Nije uspjelo: $_" }
}

# ---------------------------------------------------------------------------
# 3. Ukloni datoteke ikone
# ---------------------------------------------------------------------------
Write-Korak "Brisem datoteke ikone..."
try {
    $trayMapa = "$env:ProgramData\JellyfinTray"
    if (Test-Path $trayMapa) {
        Remove-Item $trayMapa -Recurse -Force
        Write-Ok "Mapa $trayMapa obrisana."
    } else {
        Write-Info "Mapa nije postojala."
    }
} catch { Write-Upoz "Nije uspjelo: $_" }

# ---------------------------------------------------------------------------
# 4. Zaustavi Jellyfin servis
# ---------------------------------------------------------------------------
Write-Korak "Zaustavljam Jellyfin servis..."
try {
    $svc = Get-Service -Name "JellyfinServer" -ErrorAction SilentlyContinue
    if ($svc) {
        Stop-Service -Name "JellyfinServer" -Force -ErrorAction SilentlyContinue
        Write-Ok "Servis zaustavljen."
    } else {
        # Pokusaj zaustaviti kao proces
        Get-Process -Name "jellyfin" -ErrorAction SilentlyContinue | Stop-Process -Force
        Write-Info "Servis nije pronaden, zaustavio sam proces."
    }
} catch { Write-Upoz "Nije uspjelo zaustavljanje: $_" }

Start-Sleep -Seconds 2

# ---------------------------------------------------------------------------
# 5. Pokreni Jellyfin deinstalacijski program
# ---------------------------------------------------------------------------
Write-Korak "Pokrecem Jellyfin deinstalacijski program..."

$deinstaleri = @(
    "$env:ProgramFiles\Jellyfin\Server\uninstall.exe",
    "${env:ProgramFiles(x86)}\Jellyfin\Server\uninstall.exe"
)

$nasaoDeinstalera = $false
foreach ($d in $deinstaleri) {
    if (Test-Path $d) {
        $proc = Start-Process -FilePath $d -ArgumentList "/S" -Wait -PassThru
        Write-Ok "Deinstalacija zavrsena (kod: $($proc.ExitCode))."
        $nasaoDeinstalera = $true
        break
    }
}

if (-not $nasaoDeinstalera) {
    # Pokusaj putem registra
    $regPutanje = @(
        "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
        "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    $uninstStr = $null
    foreach ($put in $regPutanje) {
        $entry = Get-ItemProperty $put -ErrorAction SilentlyContinue |
            Where-Object { $_.DisplayName -like "*Jellyfin*" } |
            Select-Object -First 1
        if ($entry) { $uninstStr = $entry.UninstallString; break }
    }

    if ($uninstStr) {
        $uninstStr = $uninstStr -replace '"',''
        $exe  = ($uninstStr -split " ")[0]
        $args = ($uninstStr -split " ",2)[1] + " /S"
        Start-Process -FilePath $exe -ArgumentList $args -Wait
        Write-Ok "Deinstalacija putem registra zavrsena."
        $nasaoDeinstalera = $true
    }
}

if (-not $nasaoDeinstalera) {
    Write-Upoz "Deinstalacijski program nije pronaden. Mozda Jellyfin nikad nije ni bio instaliran."
}

# ---------------------------------------------------------------------------
# 6. Obrisi zaostale Jellyfin mape (config, baza, metapodaci)
# ---------------------------------------------------------------------------
Write-Korak "Brisem zaostale podatke Jellyfina..."

$mazeZaBrisanje = @(
    "$env:ProgramData\Jellyfin",
    "$env:ProgramFiles\Jellyfin",
    "${env:ProgramFiles(x86)}\Jellyfin"
)

foreach ($m in $mazeZaBrisanje) {
    if (Test-Path $m) {
        try {
            Remove-Item $m -Recurse -Force
            Write-Ok "Obrisano: $m"
        } catch {
            Write-Upoz "Nisam uspio obrisati '$m': $_"
            Write-Info "Obrisi rucno (mozda treba restart racunala)."
        }
    }
}

# ---------------------------------------------------------------------------
# 7. Ukloni pravilo vatrozida
# ---------------------------------------------------------------------------
Write-Korak "Uklanjam pravilo vatrozida..."
try {
    Remove-NetFirewallRule -DisplayName "Jellyfin Media Server" -ErrorAction Stop
    Write-Ok "Pravilo vatrozida uklonjeno."
} catch {
    if ($_.Exception.Message -match "No MSFT_NetFirewallRule") { Write-Info "Pravilo nije ni postojalo." }
    else { Write-Upoz "Nije uspjelo: $_" }
}

# ---------------------------------------------------------------------------
# 8. Vrati IP adresu na DHCP
# ---------------------------------------------------------------------------
Write-Korak "Vracam IP adresu na DHCP..."
try {
    $ipInfo = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -match "^(192\.168\.|10\.|172\.)" } |
        Select-Object -First 1

    if (-not $ipInfo) { throw "Nije pronaden aktivni mrezni adapter." }

    $idx = $ipInfo.InterfaceIndex
    $dhcpStanje = (Get-NetIPInterface -InterfaceIndex $idx -AddressFamily IPv4).Dhcp

    if ($dhcpStanje -eq 'Enabled') {
        Write-Info "IP adresa je vec na DHCP-u - nema promjena."
    } else {
        # Ukloni staticku IP adresu i rutu
        Remove-NetIPAddress -InterfaceIndex $idx -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute     -InterfaceIndex $idx -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        # Vrati DHCP
        Set-NetIPInterface -InterfaceIndex $idx -AddressFamily IPv4 -Dhcp Enabled -ErrorAction Stop
        Set-DnsClientServerAddress -InterfaceIndex $idx -ResetServerAddresses
        # Obnovi DHCP zakup
        Write-Info "Obnavljam DHCP zakup (kratki prekid mreze je normalan)..."
        & ipconfig /renew | Out-Null
        Write-Ok "IP adresa vracena na DHCP."
    }
} catch {
    Write-Upoz "Vracanje na DHCP nije uspjelo: $_"
    Write-Info "Rucno: Postavke -> Mreza -> Adapter -> IPv4 -> Automatski dobavi IP adresu."
}

# ---------------------------------------------------------------------------
# Sazetak
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  ================================================" -ForegroundColor Green
Write-Host "          DEINSTALACIJA ZAVRSENA                   " -ForegroundColor Green
Write-Host "  ================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Uklonjeno je sve sto je setup skripta instalirala." -ForegroundColor White
Write-Host "  Ako ostane kakva zaostala mapa, mozes je rucno obrisati." -ForegroundColor Gray
Write-Host ""
Write-Host "  Pritisni bilo koju tipku za zatvaranje." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
