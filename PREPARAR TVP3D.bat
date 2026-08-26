@echo off
title TVP3D - Preparar entorno
cd /d "%~dp0"
set "TVP3D_SETUP_ERROR=0"

echo ==========================================
echo   TVP3D - Preparar entorno
echo ==========================================
echo.

where docker >nul 2>&1
if errorlevel 1 (
  echo ERROR: Docker no esta instalado o no esta en el PATH.
  set "TVP3D_SETUP_ERROR=1"
) else (
  docker info >nul 2>&1
  if errorlevel 1 (
    echo ERROR: Docker Desktop no esta iniciado.
    set "TVP3D_SETUP_ERROR=1"
  ) else (
    echo OK: Docker Desktop disponible.
  )
)

call "%~dp0herramientas\resolver_godot.bat"
if not defined TVP3D_GODOT_EXE (
  set "TVP3D_SETUP_ERROR=1"
) else (
  echo OK: Godot encontrado.
)

if not exist "%~dp0servidor\config.lua" (
  echo ERROR: falta servidor\config.lua.
  set "TVP3D_SETUP_ERROR=1"
) else (
  echo OK: configuracion TVP3D encontrada.
)

if not exist "%~dp0servidor\key.pem" (
  echo ERROR: falta servidor\key.pem.
  set "TVP3D_SETUP_ERROR=1"
) else (
  echo OK: clave RSA de desarrollo encontrada.
)

echo.
if "%TVP3D_SETUP_ERROR%"=="1" (
  echo El entorno necesita correcciones antes de arrancar.
  pause
  exit /b 1
)

echo Entorno listo. Puedes ejecutar ARRANCAR SERVIDOR.bat y despues JUGAR.bat.
pause
exit /b 0
