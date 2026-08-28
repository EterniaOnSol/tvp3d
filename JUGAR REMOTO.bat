@echo off
title TVP3D - Cliente remoto
cd /d "%~dp0"

echo ==========================================
echo   TVP3D - Cliente remoto
echo ==========================================
echo.
echo Este archivo sirve para conectarse al servidor del host.
echo Para Radmin VPN usa la IP 26.x.x.x del host.
echo.

set "TVP3D_HOST=CAMBIAR_POR_IP_RADMIN"

call "%~dp0herramientas\resolver_godot.bat"
if not defined TVP3D_GODOT_EXE (
  echo ERROR: no se encontro Godot.
  pause
  exit /b 1
)

"%TVP3D_GODOT_EXE%" --path "%~dp0cliente3d" main.tscn
