#Requires -RunAsAdministrator

# Hvata sve neocekivane greske i drzi prozor otvoren s porukom
trap {
    Write-Host ""
    Write-Host "  ============================================" -ForegroundColor Red
    Write-Host "  GRESKA - prozor ostaje otvoren" -ForegroundColor Red
    Write-Host "  ============================================" -ForegroundColor Red
    Write-Host "  Poruka: $($_.Exception.Message)" -ForegroundColor Yellow
    Write-Host "  Redak : $($_.InvocationInfo.ScriptLineNumber)" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "  Pritisni bilo koju tipku za zatvaranje." -ForegroundColor Gray
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
    exit 1
}

$JellyfinPort    = 8096
$JellyfinBaseUrl = "http://localhost:$JellyfinPort"
$ServiceName     = "JellyfinServer"

$script:Korak        = 0
$script:UkupnoKoraka = 7    # ukupan broj glavnih koraka

# ---------------------------------------------------------------------------
# Pomocne funkcije
# ---------------------------------------------------------------------------
function Write-Banner {
    Clear-Host
    Write-Host ""
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host "       Jellyfin Media Server - Postavljanje        " -ForegroundColor Cyan
    Write-Host "  ================================================" -ForegroundColor Cyan
    Write-Host ""
}

# Ispisuje header koraka s napretkom i procjenom trajanja
function Write-KorakHeader {
    param([string]$Naziv, [string]$Procjena = "")

    $script:Korak++
    $k   = $script:Korak
    $uk  = $script:UkupnoKoraka
    $pct = [int](($k - 1) / $uk * 100)
    $pun = [int]($pct / 10)
    $bar = ("#" * $pun) + ("-" * (10 - $pun))
    $procStr = if ($Procjena) { "  (~$Procjena)" } else { "" }

    Write-Host ""
    Write-Host "  +-- Korak $k od $uk  [$bar] $pct%$procStr" -ForegroundColor DarkCyan
    Write-Host "  |   $Naziv" -ForegroundColor White
    Write-Host ""
}

function Write-Korak  { param([string]$t) Write-Host "     [..] $t" -ForegroundColor Yellow    }
function Write-Ok     { param([string]$t) Write-Host "     [OK] $t" -ForegroundColor Green      }
function Write-Upoz   { param([string]$t) Write-Host "     [!!] $t" -ForegroundColor DarkYellow }
function Write-Greska { param([string]$t) Write-Host "     [XX] $t" -ForegroundColor Red        }
function Write-Info   { param([string]$t) Write-Host "          $t" -ForegroundColor Gray       }


# ---------------------------------------------------------------------------
# Dobrodoslica
# ---------------------------------------------------------------------------
Write-Banner
Write-Host "  Ova skripta ce automatski:" -ForegroundColor White
Write-Host "    1. Preuzeti i instalirati Jellyfin"                 -ForegroundColor Gray
Write-Host "    2. Otvoriti browser za postavljanje korisnika"      -ForegroundColor Gray
Write-Host "    3. Postaviti staticku IP adresu"                    -ForegroundColor Gray
Write-Host "    4. Dodati ikonu u traku za lako gasenje"            -ForegroundColor Gray
Write-Host ""
Write-Host "  Pritisni Enter za nastavak ili zatvori prozor za odustajanje." -ForegroundColor White
Read-Host | Out-Null


# ---------------------------------------------------------------------------
# KORAK 2 - Preuzimanje Jellyfin instalacijskog paketa
# ---------------------------------------------------------------------------
Write-Banner
Write-KorakHeader "Preuzimanje i instalacija Jellyfina" "3-6 min (ovisno o internetu)"
Write-Korak "Provjera je li Jellyfin vec instaliran..."

$JellyfinExePaths = @(
    "$env:ProgramFiles\Jellyfin\Server\jellyfin.exe",
    "${env:ProgramFiles(x86)}\Jellyfin\Server\jellyfin.exe"
)
$VecInstaliran = $JellyfinExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1

if ($VecInstaliran) {
    Write-Ok "Jellyfin je vec instaliran. Preskacem preuzimanje."
} else {
    Write-Korak "Trazim najnoviju verziju Jellyfina..."
    $InstalacijskiPaket = "$env:TEMP\jellyfin_installer.exe"

    # Provjeri je li korisnik rucno stavio installer u istu mapu (ako automatsko ne uspije)
    $lokalniInstaller = Get-ChildItem -Path $PSScriptRoot -Filter "jellyfin*windows*.exe" -ErrorAction SilentlyContinue |
        Select-Object -First 1

    $downloadUrl = $null

    # Pokusaj dohvatiti tocnu verziju s repo.jellyfin.org
    try {
        $ProgressPreference = 'SilentlyContinue'
        $stranica = Invoke-WebRequest -Uri "https://repo.jellyfin.org/?path=/server/windows/latest-stable/amd64" -UseBasicParsing
        $exeLink  = ($stranica.Links | Where-Object { $_.href -match "windows-x64\.exe" } | Select-Object -First 1).href
        if (-not $exeLink) { throw "Link za .exe nije pronaden na stranici." }
        $downloadUrl = "https://repo.jellyfin.org$exeLink"
        $verzija = [regex]::Match($exeLink, 'jellyfin_(.+?)_windows').Groups[1].Value
        Write-Ok "Najnovija verzija: $verzija"
        $ProgressPreference = 'Continue'
    } catch {
        Write-Upoz "Automatska provjera verzije nije uspjela ($_)."
        Write-Info "Koristim zadnji poznati URL (10.11.8)."
        $downloadUrl = "https://repo.jellyfin.org/files/server/windows/latest-stable/amd64/jellyfin_10.11.8_windows-x64.exe"
        $ProgressPreference = 'Continue'
    }

    Write-Korak "Preuzimam installer (~160 MB, pratite traku napretka)..."

    $preuzimanjUspjelo = $false

    # Pokusaj 1: BITS Transfer - Windows built-in, najpouzdaniji, pokazuje nativni napredak
    try {
        Import-Module BitsTransfer -ErrorAction Stop
        Start-BitsTransfer `
            -Source      $downloadUrl `
            -Destination $InstalacijskiPaket `
            -DisplayName "Preuzimanje Jellyfina" `
            -Description "Pricekaj, preuzimam ~160 MB..." `
            -ErrorAction Stop
        $preuzimanjUspjelo = $true
    } catch {
        Write-Upoz "BITS preuzimanje nije uspjelo: $_"
    }

    # Pokusaj 2: Invoke-WebRequest (bez trake napretka, ali pouzdan)
    if (-not $preuzimanjUspjelo) {
        try {
            Write-Korak "Pokusavam alternativnu metodu (bez trake napretka, pricekaj)..."
            $ProgressPreference = 'SilentlyContinue'
            Invoke-WebRequest -Uri $downloadUrl -OutFile $InstalacijskiPaket -UseBasicParsing -ErrorAction Stop
            $ProgressPreference = 'Continue'
            $preuzimanjUspjelo = $true
        } catch {
            Write-Upoz "Invoke-WebRequest nije uspjelo: $_"
        }
    }

    # Pokusaj 3: Korisnikov rucno preuzeti installer u istoj mapi
    if (-not $preuzimanjUspjelo -and $lokalniInstaller) {
        Write-Ok "Pronasao sam lokalni installer: $($lokalniInstaller.Name)"
        $InstalacijskiPaket = $lokalniInstaller.FullName
        $preuzimanjUspjelo = $true
    }

    if (-not $preuzimanjUspjelo) {
        Write-Greska "Nije moguce preuzeti Jellyfin automatski."
        Write-Host ""
        Write-Host "  Rjesenje:" -ForegroundColor White
        Write-Host "    1. Otvori https://jellyfin.org/downloads/server u browseru" -ForegroundColor Cyan
        Write-Host "    2. Preuzmi Windows installer (.exe)" -ForegroundColor Cyan
        Write-Host "    3. Stavi preuzetu datoteku u istu mapu kao ovu skriptu:" -ForegroundColor Cyan
        Write-Host "       $PSScriptRoot" -ForegroundColor Yellow
        Write-Host "    4. Pokreni skriptu ponovo - automatski ce pronaci lokalni installer" -ForegroundColor Cyan
        Write-Host ""
        pause; exit 1
    }

    Write-Ok "Preuzimanje zavrseno."

    # -----------------------------------------------------------------------
    # KORAK 3 - Instalacija (dio istog koraka 2 u brojacu)
    # -----------------------------------------------------------------------
    Write-Korak "Instaliram Jellyfin (tiha instalacija, pricekaj ~1-2 minute)..."
    Write-Host ""
    Write-Host "  *** VAZNO *** Ako se pojavi dijalosk prozor s gumbima" -ForegroundColor Yellow
    Write-Host "  Abort / Retry / Ignore  -> klikni  IGNORE  i nastavi." -ForegroundColor Yellow
    Write-Host "  (Installer pokusava pokrenuti servis, ali mi to radimo" -ForegroundColor Gray
    Write-Host "   u sljedecem koraku - nije problem.)" -ForegroundColor Gray
    Write-Host ""
    $proc = Start-Process -FilePath $InstalacijskiPaket -ArgumentList "/S" -Wait -PassThru
    # Installer vraca kod 2 kad korisnik klikne Ignore na dijalogu servisa - to je ok
    if ($proc.ExitCode -notin @(0, 2)) {
        Write-Greska "Instalacija zavrsila s greskom (kod $($proc.ExitCode))."
        Write-Info "Pokusaj pokrenuti installer rucno: $InstalacijskiPaket"
        pause; exit 1
    }
    Write-Ok "Jellyfin je uspjesno instaliran."
}

# ---------------------------------------------------------------------------
# KORAK 4 - Pokretanje servisa
# ---------------------------------------------------------------------------
Write-KorakHeader "Pokretanje Jellyfin servisa" "~30 sekundi"
Write-Korak "Pokretanje Jellyfin servisa..."

$svc = Get-Service -Name $ServiceName -ErrorAction SilentlyContinue
if ($svc) {
    if ($svc.Status -ne 'Running') {
        # Kratka pauza da se instalacija u potpunosti smiri prije pokretanja
        Start-Sleep -Seconds 5
        Start-Service -Name $ServiceName -ErrorAction SilentlyContinue
        Start-Sleep -Seconds 3
    }
    Write-Ok "Servis radi."
} else {
    $exe = $JellyfinExePaths | Where-Object { Test-Path $_ } | Select-Object -First 1
    if ($exe) {
        Start-Process -FilePath $exe -WindowStyle Hidden
        Write-Ok "Jellyfin pokrenut (standalone nacin)."
    } else {
        Write-Greska "Ne mogu pronaci Jellyfin izvrsnu datoteku nakon instalacije."
        pause; exit 1
    }
}

# ---------------------------------------------------------------------------
# KORAK 5 - Cekanje da server bude spreman
# ---------------------------------------------------------------------------
Write-KorakHeader "Cekanje da Jellyfin bude spreman" "do 90 sekundi"

$maksSekundi = 90
$pocetak     = Get-Date
$spreman     = $false

Write-Host "     Cekam odgovor servera..." -ForegroundColor Gray

while (((Get-Date) - $pocetak).TotalSeconds -lt $maksSekundi) {
    try {
        $null = Invoke-RestMethod -Uri "$JellyfinBaseUrl/health" -Method Get -UseBasicParsing -TimeoutSec 3 -ErrorAction Stop
        $spreman = $true; break
    } catch {
        $proslo = [int]((Get-Date) - $pocetak).TotalSeconds
        Write-Progress -Activity "Cekam da Jellyfin bude spreman" `
            -Status "Proslo: $proslo s  |  Maksimum: $maksSekundi s" `
            -PercentComplete ([int]($proslo / $maksSekundi * 100))
        Start-Sleep -Seconds 3
    }
}
Write-Progress -Activity "Cekam da Jellyfin bude spreman" -Completed

if (-not $spreman) {
    Write-Upoz "Server se nije pokrenuo u roku od 90 sekundi."
    Write-Info "Otvori http://localhost:$JellyfinPort u browseru i zavrsi postavljanje rucno."
    Write-Info "(Dovrsi carobnjak, kreiraj korisnika i dodaj mape s medijima.)"
    pause; exit 1
}
Write-Ok "Jellyfin radi i odgovara."

# ---------------------------------------------------------------------------
# KORAK 6 - Postavljanje korisnika i biblioteka kroz Jellyfinov carobnjak
# ---------------------------------------------------------------------------
Write-KorakHeader "Postavljanje korisnika i biblioteka" "~3-5 min (tvoj unos)"

# Postavi zadane postavke putem API-ja (ne zahtijeva prijavu)
try {
    $cfgBody = '{"UICulture":"hr","MetadataCountryCode":"HR","PreferredMetadataLanguage":"hr"}'
    Invoke-RestMethod -Uri "$JellyfinBaseUrl/Startup/Configuration" -Method Post `
        -Body $cfgBody -ContentType "application/json" -UseBasicParsing | Out-Null
} catch { <# nije kriticno #> }

try {
    $raBody = '{"EnableRemoteAccess":true,"EnableAutomaticPortMapping":false}'
    Invoke-RestMethod -Uri "$JellyfinBaseUrl/Startup/RemoteAccess" -Method Post `
        -Body $raBody -ContentType "application/json" -UseBasicParsing | Out-Null
} catch { <# nije kriticno #> }

Write-Host ""
Write-Host "  Browser ce se otvoriti. Popuni korake u carobnjaku:" -ForegroundColor White
Write-Host ""
Write-Host "  Korak 1 - Jezik:    odaberi jezik" -ForegroundColor Cyan
Write-Host "  Korak 2 - Korisnik: unesi ime i lozinku po svom izboru" -ForegroundColor Cyan
Write-Host "  Korak 3 - Mediji:   dodaj mape s filmovima/serijama (klikni 'Dodaj medijsku biblioteku')" -ForegroundColor Cyan
Write-Host "  Korak 4 - Metapodaci: ostavi zadano, klikni Dalje" -ForegroundColor Cyan
Write-Host "  Korak 5 - Zavrsi:   klikni 'Zavrsi'" -ForegroundColor Cyan
Write-Host ""
Write-Host "  Kada zavrsis u browseru, vrati se ovdje i pritisni Enter." -ForegroundColor Green
Write-Host ""
Start-Process "http://localhost:$JellyfinPort"
Read-Host "  Pritisni Enter nakon sto si zavrsio postavljanje u browseru" | Out-Null
Write-Host ""

# ---------------------------------------------------------------------------
# KORAK 7 - Windows vatrozid (da TV moze pristupiti)
# ---------------------------------------------------------------------------
Write-KorakHeader "Pravilo vatrozida" "~5 sekundi"
Write-Korak "Dodajem pravilo u Windows vatrozid (da TV moze pristupiti)..."

try {
    $postojece = Get-NetFirewallRule -DisplayName "Jellyfin Media Server" -ErrorAction SilentlyContinue
    if ($postojece) {
        Write-Ok "Pravilo vatrozida vec postoji - nema promjena."
    } else {
        New-NetFirewallRule `
            -DisplayName "Jellyfin Media Server" `
            -Description  "Dopusta dolazne veze na Jellyfin (port $JellyfinPort)" `
            -Direction    Inbound `
            -Protocol     TCP `
            -LocalPort    $JellyfinPort `
            -Action       Allow `
            -Profile      Private `
            | Out-Null
        Write-Ok "Pravilo vatrozida dodano (privatna mreza, TCP port $JellyfinPort)."
    }
} catch {
    Write-Upoz "Nisam uspio dodati pravilo vatrozida: $_"
    Write-Info "Idi u: Windows Defender vatrozid -> Napredno -> Ulazna pravila -> Novo pravilo"
    Write-Info "Dopusti TCP port $JellyfinPort na privatnim mrezama."
}

# ---------------------------------------------------------------------------
# KORAK 8 - Ikona u sistemskoj traci (za lako pokretanje/gasenje)
# ---------------------------------------------------------------------------
Write-KorakHeader "Ikona u sistemskoj traci" "~5 sekundi"
Write-Korak "Instaliram ikonu u sistemsku traku..."

$TrayMapa   = "$env:ProgramData\JellyfinTray"
$TraySkript = "$TrayMapa\tray_jellyfin.ps1"

try {
    if (-not (Test-Path $TrayMapa)) { New-Item -ItemType Directory -Path $TrayMapa | Out-Null }

    $IzvorTray = Join-Path $PSScriptRoot "tray_jellyfin.ps1"
    if (-not (Test-Path $IzvorTray)) { throw "tray_jellyfin.ps1 nije pronaden uz setup skriptu." }
    Copy-Item $IzvorTray $TraySkript -Force

    $akcija    = New-ScheduledTaskAction `
        -Execute  "powershell.exe" `
        -Argument "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$TraySkript`""
    $okidac    = New-ScheduledTaskTrigger -AtLogOn
    $postavke  = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -ExecutionTimeLimit 0
    $principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -RunLevel Highest -LogonType Interactive

    Register-ScheduledTask `
        -TaskName  "JellyfinTray" `
        -TaskPath  "\" `
        -Action    $akcija `
        -Trigger   $okidac `
        -Settings  $postavke `
        -Principal $principal `
        -Force | Out-Null

    Write-Ok "Ikona registrirana - pojavit ce se automatski pri svakom pokretanju Windowsa."

    Start-Process "powershell.exe" `
        -ArgumentList "-NoProfile -WindowStyle Hidden -ExecutionPolicy Bypass -File `"$TraySkript`"" `
        -Verb RunAs
    Write-Ok "Ikona pokrenuta - pogledaj donji desni kut zaslona."
} catch {
    Write-Upoz "Nisam uspio instalirati ikonu: $_"
    Write-Info "Pokreni rucno: tray_jellyfin.ps1 kao Administrator."
}

# ---------------------------------------------------------------------------
# KORAK 9 - Staticka IP adresa (na ovom racunalu)
# ---------------------------------------------------------------------------
Write-KorakHeader "Staticka IP adresa" "~10 sekundi"
Write-Korak "Postavljam staticku IP adresu..."

try {
    # Pronadi aktivni mrezni adapter s privatnom IP adresom
    $ipInfo = Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -match "^(192\.168\.|10\.|172\.(1[6-9]|2[0-9]|3[01])\.)" } |
        Sort-Object -Property PrefixLength -Descending |
        Select-Object -First 1

    if (-not $ipInfo) { throw "Nije pronadena aktivna mrezna veza s privatnom IP adresom." }

    $indeksAdaptera = $ipInfo.InterfaceIndex
    $trenutnaIP     = $ipInfo.IPAddress
    $prefiks        = $ipInfo.PrefixLength

    $mreza      = Get-NetIPConfiguration -InterfaceIndex $indeksAdaptera -ErrorAction Stop
    $gateway    = $mreza.IPv4DefaultGateway.NextHop
    $dnsServeri = ($mreza.DnsServer | Where-Object { $_.AddressFamily -eq 2 }).ServerAddresses

    # Provjeri je li vec staticna
    $dhcpStanje = (Get-NetIPInterface -InterfaceIndex $indeksAdaptera -AddressFamily IPv4 -ErrorAction Stop).Dhcp

    if ($dhcpStanje -eq 'Disabled') {
        Write-Ok "IP adresa je vec staticna: $trenutnaIP"
    } else {
        # Zamrzni trenutne DHCP vrijednosti kao staticne
        Set-NetIPInterface -InterfaceIndex $indeksAdaptera -AddressFamily IPv4 -Dhcp Disabled -ErrorAction Stop
        Remove-NetIPAddress -InterfaceIndex $indeksAdaptera -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue
        Remove-NetRoute     -InterfaceIndex $indeksAdaptera -AddressFamily IPv4 -Confirm:$false -ErrorAction SilentlyContinue

        $params = @{
            InterfaceIndex = $indeksAdaptera
            AddressFamily  = "IPv4"
            IPAddress      = $trenutnaIP
            PrefixLength   = $prefiks
        }
        if ($gateway) { $params.DefaultGateway = $gateway }
        New-NetIPAddress @params | Out-Null

        if ($dnsServeri) {
            Set-DnsClientServerAddress -InterfaceIndex $indeksAdaptera -ServerAddresses $dnsServeri
        } elseif ($gateway) {
            # Ako DHCP nije dostavio DNS, koristi gateway + Google DNS kao rezervu
            Set-DnsClientServerAddress -InterfaceIndex $indeksAdaptera -ServerAddresses @($gateway, "8.8.8.8")
        }

        Write-Ok "Staticka IP adresa postavljena: $trenutnaIP"
        Write-Info "Ova adresa nece se vise mijenjati pri ponovnom pokretanju."
    }

    $LocalIP    = $trenutnaIP
    $MACAdresa  = (Get-NetAdapter -ErrorAction SilentlyContinue |
        Where-Object { $_.InterfaceIndex -eq $indeksAdaptera } |
        Select-Object -First 1).MacAddress
} catch {
    Write-Upoz "Postavljanje staticke IP adrese nije uspjelo: $_"
    $LocalIP   = (Get-NetIPAddress -AddressFamily IPv4 -ErrorAction SilentlyContinue |
        Where-Object { $_.IPAddress -match "^(192\.168\.|10\.|172\.)" } |
        Select-Object -First 1).IPAddress
    $MACAdresa = $null
}

# ---------------------------------------------------------------------------
# KORAK 10 - Otvori browser
# ---------------------------------------------------------------------------
Write-Korak "Otvaram Jellyfin u browseru..."
Start-Sleep -Seconds 1
Start-Process "http://localhost:$JellyfinPort"

# ---------------------------------------------------------------------------
# Sazetak
# ---------------------------------------------------------------------------
Write-Host ""
Write-Host "  ================================================" -ForegroundColor Green
Write-Host "         POSTAVLJANJE ZAVRSENO - SVE GOTOVO!       " -ForegroundColor Green
Write-Host "  ================================================" -ForegroundColor Green
Write-Host ""
Write-Host "  Podaci za prijavu" -ForegroundColor White
Write-Host "    Korisnik i lozinka: ono sto si unio u carobnjaku." -ForegroundColor Cyan
Write-Host ""
Write-Host "  Otvori Jellyfin na OVOM racunalu" -ForegroundColor White
Write-Host "    http://localhost:$JellyfinPort" -ForegroundColor Cyan
Write-Host ""
if ($LocalIP) {
    Write-Host "  Otvori Jellyfin na TV-u / mobitelu (isti WiFi)" -ForegroundColor White
    Write-Host "    http://$($LocalIP):$JellyfinPort" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "  --> Instaliraj Jellyfin aplikaciju na TV-u i upisi gornju adresu" -ForegroundColor Yellow
    Write-Host "      kada te pita za adresu servera." -ForegroundColor Yellow
}
Write-Host ""
Write-Host "  Sljedeci put kada zelis gledati" -ForegroundColor White
Write-Host "    Jellyfin se automatski pokrece s Windowsima." -ForegroundColor Gray
Write-Host "    Samo ukljuci racunalo i otvori Jellyfin na TV-u - to je sve!" -ForegroundColor Gray
Write-Host "    Ako si ga ugasio, desni klik na ikonu u sistemskoj traci" -ForegroundColor Gray
Write-Host "    (donji desni kut zaslona) -> 'Pokreni Jellyfin'." -ForegroundColor Gray
Write-Host ""
Write-Host "  Port forwarding na ruteru" -ForegroundColor White
Write-Host "    NIJE potrebno za TV na istom kucnom WiFi-u." -ForegroundColor Gray
Write-Host "    Samo ako zelis pristup izvana (mobilni internet, od prijatelja):" -ForegroundColor Gray
if ($LocalIP) {
Write-Host "    Preusmjeri TCP port $JellyfinPort -> $LocalIP na ruteru." -ForegroundColor Gray
}
Write-Host ""

Write-Host "  Pritisni bilo koju tipku za zatvaranje ovog prozora." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
