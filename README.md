# Jellyfin — Automatska instalacija za Windows

Skripta koja na Windows računalu automatski instalira i postavi [Jellyfin](https://jellyfin.org/) media server — bez tehničkog znanja, bez ručne konfiguracije.

Nakon što skripta završi, možeš gledati filmove i serije s računala na **televizoru i mobitelu** — sve na istoj kućnoj mreži.

---

## Što skripta radi

- Preuzima i instalira najnoviji Jellyfin za Windows
- Otvara browser radi postavljanja korisnika i medijskih biblioteka
- Dodaje pravilo u Windows vatrozid (da TV može pristupiti serveru)
- Postavlja **statičku IP adresu** na ovom računalu (da se adresa ne mijenja pri svakom pokretanju)
- Dodaje **ikonu u sistemsku traku** za lako pokretanje i gašenje Jellyfina

---

## Preduvjeti

- Windows 10 ili Windows 11
- Administratorske ovlasti (skripta će ih sama zatražiti)
- Aktivna internetska veza (za preuzimanje Jellyfina, ~160 MB)

---

## Kako pokrenuti

1. Preuzmi sve datoteke iz ovog repozitorija (zeleni gumb **Code → Download ZIP**)
2. Raspakiraj ZIP na bilo koje mjesto (npr. `C:\Jellyfin-Setup`)
3. Dvaput klikni na **`Run_Jellyfin_Setup.bat`**
4. Klikni **Da** kada Windows pita za administratorske ovlasti
5. Slijedi upute na ekranu

Skripta će te pitati gdje se nalaze tvoji mediji (mapa s filmovima, serijama i sl.), a zatim sve ostalo napraviti automatski.

---

## Što se dogodi pri prvom pokretanju

Skripta otvara browser na Jellyfinovom čarobnjaku gdje:

1. Odabereš jezik
2. Postaviš korisničko ime i lozinku
3. Dodaš mape s medijima (skripta ispiše točne putanje)
4. Klikneš Završi

Nakon toga Jellyfin je spreman za korištenje.

---

## Gledanje na TV-u

1. Na TV-u instaliraj aplikaciju **Jellyfin** (dostupna za Android TV, Samsung, LG, Apple TV i dr.)
2. Kada aplikacija pita za adresu servera, upiši IP adresu koju skripta ispiše na kraju (oblika `http://192.168.x.x:8096`)
3. Prijavi se s korisničkim imenom i lozinkom koje si postavio u čarobnjaku

---

## Ikona u sistemskoj traci

Nakon instalacije u donjem desnom kutu zaslona pojavljuje se Jellyfin ikona.  
**Desni klik** na ikonu nudi:

- Pokreni Jellyfin
- Ugasi Jellyfin
- Otvori u browseru

Ikona se automatski pokreće pri svakom pokretanju Windowsa.

---

## Deinstalacija

Dvaput klikni na **`Uninstall_Jellyfin.bat`** i potvrdi.

Skripta uklanja:
- Jellyfin server i sve njegove podatke
- Ikonu iz sistemske trake
- Pravilo vatrozida
- Statičku IP adresu (vraća DHCP)

> **Napomena:** Tvoji mediji (filmovi, serije) **neće biti obrisani** — samo Jellyfin konfiguracija.

---

## Napomene

- Jellyfin je **besplatan i open-source** — nema pretplate ni ograničenja
- Port forwarding na ruteru **nije potreban** za gledanje na TV-u unutar kućne mreže
- Ako želiš pristup izvana (od kuće, mobilnim internetom), potrebno je preusmjeriti TCP port `8096` na ruteru prema IP adresi ovog računala
- Starija računala mogu imati sporije učitavanje naslovnica i metapodataka pri prvom skeniranju — to je normalno
