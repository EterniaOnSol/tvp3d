@echo off
title TVP3D - Consola de la pagina web
cd /d "%~dp0web"

echo ==========================================
echo   TVP3D - lo que dice la web, en vivo
echo ==========================================
echo.
echo  Aca aparecen las visitas y los errores de PHP.
echo  Ctrl+C para salir.
echo.

docker compose logs -f web
