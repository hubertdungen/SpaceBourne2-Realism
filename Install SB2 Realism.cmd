@echo off
rem Opens the SpaceBourne 2 Realism installer window.
start "" powershell.exe -NoProfile -ExecutionPolicy Bypass -STA -WindowStyle Hidden -File "%~dp0SB2RealismInstaller.ps1"
