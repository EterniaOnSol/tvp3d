@echo off
title TVP3D - Prueba con Radmin VPN
cd /d "%~dp0"

echo ==========================================
echo   TVP3D - Prueba remota con Radmin VPN
echo ==========================================
echo.

set "TVP3D_RADMIN_IP="
rem ipconfig funciona tambien cuando este .bat se ejecuta sin privilegios elevados.
for /f "tokens=2 delims=:" %%I in ('ipconfig ^| findstr /R "26\."') do for /f "tokens=*" %%J in ("%%I") do if not defined TVP3D_RADMIN_IP set "TVP3D_RADMIN_IP=%%J"

if not defined TVP3D_RADMIN_IP (
  echo ERROR: Radmin VPN no esta activo o no tiene una IP 26.x.x.x.
  echo Abre Radmin VPN, pulsa Power On y vuelve a ejecutar este archivo.
  pause
  exit /b 1
)

echo IP virtual de este PC: %TVP3D_RADMIN_IP%
echo.
echo Arrancando servidor y base de datos...
docker compose -f "%~dp0servidor\docker-compose.yaml" up -d
if errorlevel 1 (
  echo ERROR: no se pudo arrancar Docker/servidor.
  pause
  exit /b 1
)

echo Arrancando pagina web para la red Radmin...
set "TVP3D_SITE_URL=http://%TVP3D_RADMIN_IP%:8072/"
docker compose -f "%~dp0web\docker-compose.yml" up --build -d
if errorlevel 1 (
  echo ERROR: no se pudo arrancar la web.
  pause
  exit /b 1
)

echo.
echo ==========================================
echo   LISTO PARA LA PRUEBA
echo ==========================================
echo Juego : %TVP3D_RADMIN_IP%:7171
echo Web   : http://%TVP3D_RADMIN_IP%:8072
echo.
echo Tu amigo debe estar dentro de la misma red de Radmin VPN.
echo En su cliente debe editar JUGAR REMOTO.bat con esta IP:
echo   %TVP3D_RADMIN_IP%
echo.
start "" "http://%TVP3D_RADMIN_IP%:8072"
pause
