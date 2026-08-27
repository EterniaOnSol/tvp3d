@echo off
title TVP3D - Parar la pagina web
cd /d "%~dp0web"

echo ==========================================
echo   TVP3D - apagando la pagina web
echo ==========================================
echo.
echo  Esto apaga SOLO la web. El servidor del juego y la
echo  base de datos siguen prendidos.
echo.

docker compose down

echo.
echo  Web apagada.
echo.
pause
