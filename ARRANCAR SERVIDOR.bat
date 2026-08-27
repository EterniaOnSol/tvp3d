@echo off
title TVP3D - Servidor
cd /d "%~dp0servidor"

echo ==========================================
echo   TVP3D - Servidor TVP 7.72
echo ==========================================
echo.
echo  Arranca el servidor y la base de datos en Docker.
echo  La primera vez tarda (compila C++); despues son segundos.
echo.
echo  Servidor de login : 7171
echo  Servidor de juego : 7172
echo  Base de datos     : 3371
echo  phpMyAdmin        : apagado por defecto (solo perfil admin)
echo.
echo  Cuenta 123456 / clave 123456 / personaje GOD
echo.

if not exist "%~dp0servidor\config.lua" (
  echo ERROR: falta servidor\config.lua. Ejecuta PREPARAR TVP3D.bat.
  pause
  exit /b 1
)
if not exist "%~dp0servidor\key.pem" (
  echo ERROR: falta servidor\key.pem. Ejecuta PREPARAR TVP3D.bat.
  pause
  exit /b 1
)

docker compose up --build -d

echo.
echo ---- ultimas lineas del servidor ----
docker compose logs --tail 25 server

echo.
echo  Listo. Para ver el servidor en vivo: VER SERVIDOR.bat
echo  Para apagarlo:                       PARAR SERVIDOR.bat
echo.
pause
