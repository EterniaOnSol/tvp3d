@echo off
title TVP3D - Pagina web
cd /d "%~dp0web"

echo ==========================================
echo   TVP3D - Pagina web (MyAAC)
echo ==========================================
echo.
echo  Aca la gente se hace la cuenta y los personajes.
echo.
echo  Direccion : http://localhost:8072
echo.
echo  La PRIMERA vez tarda bastante: arma la imagen de PHP
echo  y baja las librerias de MyAAC. Despues son segundos.
echo.

if not exist "%~dp0web\myaac\index.php" (
  echo ERROR: falta la carpeta web\myaac.
  pause
  exit /b 1
)

echo  Revisando que el servidor este prendido...
docker network inspect servidor_tvp_network >nul 2>&1
if errorlevel 1 (
  echo.
  echo  ERROR: no encuentro la red del servidor.
  echo  La web se conecta a la base de datos DEL SERVIDOR,
  echo  asi que primero hay que ejecutar ARRANCAR SERVIDOR.bat
  echo  y despues este.
  echo.
  pause
  exit /b 1
)

docker compose up --build -d
if errorlevel 1 (
  echo.
  echo  Algo fallo al levantar la web. Mira el error de arriba.
  pause
  exit /b 1
)

echo.
echo ---- ultimas lineas de la web ----
docker compose logs --tail 30 web

echo.
echo  Si arriba dice "Bajando las librerias", todavia esta trabajando.
echo  Miralo en vivo con VER WEB.bat y espera a que diga "Web lista".
echo.
echo  Abriendo el navegador...
start "" http://localhost:8072
echo.
echo  Para verla en vivo : VER WEB.bat
echo  Para apagarla      : PARAR WEB.bat
echo.
pause
