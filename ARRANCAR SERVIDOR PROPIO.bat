@echo off
title TVP3D - Servidor Godot propio
cd /d "%~dp0"

set "GODOT=C:\Users\dell\3DTIBIA\herramientas\godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" set "GODOT=godot"

echo ==========================================
echo   TVP3D - Servidor Godot propio
echo ==========================================
echo   Escuchando en 127.0.0.1:7277
echo.

"%GODOT%" --headless --path "%~dp0cliente3d" servidor_propio/servidor.tscn

pause
