@echo off
title TVP3D - Probar conexion
cd /d "%~dp0"

echo ==========================================
echo   TVP3D - prueba de conexion
echo ==========================================
echo.
echo  Se conecta al servidor y prueba tres cosas:
echo    1. pedir la lista de personajes
echo    2. entrar al mundo
echo    3. caminar para los cuatro lados
echo.
echo  El servidor tiene que estar andando
echo  ("ARRANCAR SERVIDOR.bat").
echo.

call "%~dp0herramientas\resolver_godot.bat"
if not defined TVP3D_GODOT_CONSOLE_EXE (
  pause
  exit /b 1
)

"%TVP3D_GODOT_CONSOLE_EXE%" --headless --path "%~dp0cliente3d" pruebas/prueba_login.tscn

echo.
pause
