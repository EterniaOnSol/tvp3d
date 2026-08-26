@echo off
title TVP3D - Probar servidor Godot propio
cd /d "%~dp0"

set "GODOT=C:\Users\dell\3DTIBIA\herramientas\godot\Godot_v4.7.2-stable_win64_console.exe"
if not exist "%GODOT%" set "GODOT=godot"

echo ==========================================
echo   TVP3D - Prueba cliente-servidor Godot
echo ==========================================
echo   El servidor propio debe estar corriendo.
echo.

"%GODOT%" --headless --path "%~dp0cliente3d" pruebas/prueba_servidor_propio.tscn

pause
