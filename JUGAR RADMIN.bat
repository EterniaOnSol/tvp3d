@echo off
title TVP3D - Cliente del host Radmin VPN
cd /d "%~dp0"

set "TVP3D_HOST="
for /f "tokens=2 delims=:" %%I in ('ipconfig ^| findstr /R "26\."') do for /f "tokens=*" %%J in ("%%I") do if not defined TVP3D_HOST set "TVP3D_HOST=%%J"

if not defined TVP3D_HOST (
  echo ERROR: Radmin VPN no esta activo o no tiene una IP 26.x.x.x.
  pause
  exit /b 1
)

call "%~dp0herramientas\resolver_godot.bat"
if not defined TVP3D_GODOT_EXE (
  echo ERROR: no se encontro Godot.
  pause
  exit /b 1
)

echo Conectando a TVP3D por Radmin VPN: %TVP3D_HOST%
"%TVP3D_GODOT_EXE%" --path "%~dp0cliente3d" --host "%TVP3D_HOST%" main.tscn
