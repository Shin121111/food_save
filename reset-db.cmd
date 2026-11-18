@echo off
rem Double-click this file. It runs scripts\reset-db.ps1 in PowerShell.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\reset-db.ps1"
pause
