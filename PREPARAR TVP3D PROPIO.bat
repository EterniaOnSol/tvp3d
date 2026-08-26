@echo off
title TVP3D - Preparar perfil propio
cd /d "%~dp0"
set "TVP3D_PROPIO_ERROR=0"

echo ==========================================
echo   TVP3D - Preparar perfil propio
echo ==========================================
echo.

call "%~dp0herramientas\resolver_godot.bat"
if not defined TVP3D_GODOT_EXE (
  set "TVP3D_PROPIO_ERROR=1"
) else (
  echo OK: Godot encontrado.
)

if not exist "%~dp0cliente3d\project.godot" (
  echo ERROR: falta cliente3d\project.godot.
  set "TVP3D_PROPIO_ERROR=1"
) else (
  echo OK: proyecto Godot encontrado.
)
if not exist "%~dp0cliente3d\servidor_propio\servidor.tscn" (
  echo ERROR: falta la escena del servidor propio.
  set "TVP3D_PROPIO_ERROR=1"
) else (
  echo OK: escena del servidor propio encontrada.
)
if not exist "%~dp0cliente3d\propio\cliente_3d.tscn" (
  echo ERROR: falta la escena del cliente propio.
  set "TVP3D_PROPIO_ERROR=1"
) else (
  echo OK: escena del cliente propio encontrada.
)
if not exist "%~dp0cliente3d\servidor_propio\prueba_dos_clientes.tscn" (
  echo ERROR: falta la prueba de dos clientes.
  set "TVP3D_PROPIO_ERROR=1"
) else (
  echo OK: prueba de dos clientes encontrada.
)

echo.
if "%TVP3D_PROPIO_ERROR%"=="1" (
  echo El perfil propio necesita correcciones antes de arrancar.
  pause
  exit /b 1
)

echo Perfil propio listo.
echo Ejecuta ARRANCAR SERVIDOR PROPIO.bat y despues JUGAR PROPIO.bat.
pause
exit /b 0
