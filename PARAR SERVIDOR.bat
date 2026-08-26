@echo off
title TVP3D - Parar servidor
cd /d "%~dp0servidor"

echo Apagando el servidor TVP3D...
echo.
echo (La base de datos NO se borra: los personajes quedan guardados.)
echo.

docker compose down

echo.
pause
