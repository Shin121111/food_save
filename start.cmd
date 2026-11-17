@echo off
rem Double-click this file. It starts the store in the background and opens the browser.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\server.ps1" start
pause
