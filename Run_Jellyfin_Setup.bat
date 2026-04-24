@echo off
chcp 65001 >nul 2>&1

:: Provjeri admin prava
net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Trazim administratorske dozvole...
    powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0setup_jellyfin.ps1\"' -Verb RunAs"
    exit /b
)

:: Vec admin - pokreni skriptu direktno
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup_jellyfin.ps1"

:: Ako je skripta zatvorena s greskom, pokazi poruku i cekaj
if %errorLevel% neq 0 (
    echo.
    echo  Skripta je zatvorena s greskom (kod: %errorLevel%).
    echo  Pogledaj poruke iznad za detalje.
    pause
)
