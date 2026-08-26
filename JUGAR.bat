@echo off
title TVP3D
cd /d "%~dp0"

echo ==========================================
echo   TVP3D
echo ==========================================
echo.
echo  OJO: el servidor tiene que estar andando.
echo  Si no lo esta, abri primero "ARRANCAR SERVIDOR.bat".
echo.
echo  Flechas o WASD para caminar
echo  Arrastra el mouse para girar la camara
echo  Rueda del mouse para acercar y alejar
echo  ESC para salir
echo.

call "%~dp0herramientas\resolver_godot.bat"
if not defined TVP3D_GODOT_EXE (
  pause
  exit /b 1
)

"%TVP3D_GODOT_EXE%" --path "%~dp0cliente3d" main.tscn

echo.
pause
