@echo off
setlocal
title TVP3D - Instalar un plugin en la web
cd /d "%~dp0web"

echo ==========================================
echo   TVP3D - Instalar plugin / tema en la web
echo ==========================================
echo.
echo  Dejas el .zip del plugin en la carpeta:
echo     web\plugins-zip
echo  y despues elegis cual instalar.
echo.

if not exist "%~dp0web\plugins-zip\*.zip" (
  echo  No hay ningun .zip en web\plugins-zip.
  echo  Copia ahi el archivo del plugin y volve a ejecutar esto.
  echo.
  pause
  exit /b 1
)

echo  Plugins disponibles:
echo.
for %%f in ("%~dp0web\plugins-zip\*.zip") do echo    %%~nxf
echo.

set /p ZIP=Escribi el nombre exacto del .zip y apreta Enter:

if not exist "%~dp0web\plugins-zip\%ZIP%" (
  echo.
  echo  No encuentro "%ZIP%" en web\plugins-zip.
  pause
  exit /b 1
)

docker exec tvp3d_web php aac plugin:install "/plugins-zip/%ZIP%"
docker exec tvp3d_web php aac cache:clear

echo.
echo  Listo. Si era un TEMA, todavia hay que elegirlo:
echo  entra a http://localhost:8072/admin (cuenta 100777 / clave tvp3d2026),
echo  Settings, y ahi cambias "Template".
echo.
pause
