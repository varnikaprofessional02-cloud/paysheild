@echo off
rem Double-click to start PayShield locally. Extra args are passed through, e.g. start-payshield.bat -Reset
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0start-payshield.ps1" %*
pause
