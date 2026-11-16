@echo off
rem Double-click launcher: runs ScreenshotOrganizer.ps1 from this same folder.
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "%~dp0ScreenshotOrganizer.ps1" %*
