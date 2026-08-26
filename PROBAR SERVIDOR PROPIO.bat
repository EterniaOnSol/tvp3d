@echo off
title TVP3D - Probar servidor Godot propio
cd /d "%~dp0"

call "%~dp0herramientas\resolver_godot.bat"
set "GODOT=%TVP3D_GODOT_CONSOLE_EXE%"
if not defined GODOT exit /b 1

echo ==========================================
echo   TVP3D - Prueba cliente-servidor Godot
echo ==========================================
echo   El servidor propio debe estar corriendo.
echo.

"%GODOT%" --headless --path "%~dp0cliente3d" pruebas/prueba_servidor_propio.tscn

pause
