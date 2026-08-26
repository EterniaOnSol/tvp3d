@echo off
title TVP3D - Servidor Godot propio
cd /d "%~dp0"

call "%~dp0herramientas\resolver_godot.bat"
set "GODOT=%TVP3D_GODOT_CONSOLE_EXE%"
if not defined GODOT exit /b 1

echo ==========================================
echo   TVP3D - Servidor Godot propio
echo ==========================================
echo   Escuchando en 127.0.0.1:7277
echo.

"%GODOT%" --headless --path "%~dp0cliente3d" servidor_propio/servidor.tscn

pause
