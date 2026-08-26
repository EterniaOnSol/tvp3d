@echo off
title TVP3D - Cliente 3D propio
cd /d "%~dp0"

set "GODOT=C:\Users\dell\3DTIBIA\herramientas\godot\Godot_v4.7.2-stable_win64.exe"
if not exist "%GODOT%" set "GODOT=godot"

echo ==========================================
echo   TVP3D - Cliente 3D propio
echo ==========================================
echo   Arranca primero ARRANCAR SERVIDOR PROPIO.bat
echo.

"%GODOT%" --path "%~dp0cliente3d" propio/cliente_3d.tscn

pause
