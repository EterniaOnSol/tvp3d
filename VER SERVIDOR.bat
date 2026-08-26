@echo off
title TVP3D - Consola del servidor
cd /d "%~dp0servidor"

echo ==========================================
echo   TVP3D - lo que dice el servidor, en vivo
echo ==========================================
echo.
echo  Aca aparecen los logins, los errores y todo lo que
echo  imprime el servidor. Ctrl+C para salir.
echo.

docker compose logs -f server
