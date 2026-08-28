@echo off
title TVP3D - Preparar cliente para un amigo
cd /d "%~dp0"

echo ==========================================
echo   TVP3D - Preparar cliente Radmin VPN
echo ==========================================
echo.
echo Se generara un ZIP con el cliente, los mapas y Godot.
echo Puede tardar un poco porque incluye los datos del mundo.
echo.

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0herramientas\preparar_cliente_radmin.ps1"
if errorlevel 1 (
  echo.
  echo ERROR: no se pudo preparar el cliente.
  pause
  exit /b 1
)

echo.
echo El ZIP quedo dentro de la carpeta dist.
pause
