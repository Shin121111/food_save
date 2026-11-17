@echo off
rem Double-click this file. It stops the store.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\server.ps1" stop
pause
