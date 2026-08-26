@echo off
title TVP3D - Cliente 3D propio
cd /d "%~dp0"

call "%~dp0herramientas\resolver_godot.bat"
set "GODOT=%TVP3D_GODOT_EXE%"
if not defined GODOT exit /b 1

echo ==========================================
echo   TVP3D - Cliente 3D propio
echo ==========================================
echo   Arranca primero ARRANCAR SERVIDOR PROPIO.bat
echo.

"%GODOT%" --path "%~dp0cliente3d" propio/cliente_3d.tscn

pause
