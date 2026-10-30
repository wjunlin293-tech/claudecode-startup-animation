@echo off
chcp 65001 >nul
title Claude Whiteboard installer
rem Double-click to install / update (needs internet once). Same as the one-line installer in README.md.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0setup.ps1"
echo.
pause
