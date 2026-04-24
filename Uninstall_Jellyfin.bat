@echo off
chcp 65001 >nul 2>&1

net session >nul 2>&1
if %errorLevel% neq 0 (
    echo Trazim administratorske dozvole...
    powershell -Command "Start-Process powershell -ArgumentList '-NoProfile -ExecutionPolicy Bypass -File \"%~dp0uninstall_jellyfin.ps1\"' -Verb RunAs"
    exit /b
)

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0uninstall_jellyfin.ps1"

if %errorLevel% neq 0 (
    echo.
    echo  Skripta je zatvorena s greskom (kod: %errorLevel%).
    pause
)
