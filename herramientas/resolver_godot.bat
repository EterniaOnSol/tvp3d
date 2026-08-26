@echo off
rem Resuelve Godot sin depender de una ruta personal.
rem Variables opcionales: TVP3D_GODOT y TVP3D_GODOT_CONSOLE.

set "TVP3D_GODOT_EXE="
set "TVP3D_GODOT_CONSOLE_EXE="

if defined TVP3D_GODOT if exist "%TVP3D_GODOT%" set "TVP3D_GODOT_EXE=%TVP3D_GODOT%"

if not defined TVP3D_GODOT_EXE if exist "%~dp0godot\Godot_v4.7.2-stable_win64.exe" set "TVP3D_GODOT_EXE=%~dp0godot\Godot_v4.7.2-stable_win64.exe"
if not defined TVP3D_GODOT_EXE if exist "%~dp0..\Godot\Godot_v4.7.2-stable_win64.exe" set "TVP3D_GODOT_EXE=%~dp0..\Godot\Godot_v4.7.2-stable_win64.exe"
if not defined TVP3D_GODOT_EXE if exist "%~dp0..\..\3DTIBIA\herramientas\godot\Godot_v4.7.2-stable_win64.exe" set "TVP3D_GODOT_EXE=%~dp0..\..\3DTIBIA\herramientas\godot\Godot_v4.7.2-stable_win64.exe"
if not defined TVP3D_GODOT_EXE if exist "%ProgramFiles%\Godot\Godot_v4.7.2-stable_win64.exe" set "TVP3D_GODOT_EXE=%ProgramFiles%\Godot\Godot_v4.7.2-stable_win64.exe"

if not defined TVP3D_GODOT_EXE for /f "delims=" %%G in ('where godot 2^>nul') do if not defined TVP3D_GODOT_EXE set "TVP3D_GODOT_EXE=%%G"
if not defined TVP3D_GODOT_EXE for /f "delims=" %%G in ('where godot4 2^>nul') do if not defined TVP3D_GODOT_EXE set "TVP3D_GODOT_EXE=%%G"

if defined TVP3D_GODOT_CONSOLE if exist "%TVP3D_GODOT_CONSOLE%" set "TVP3D_GODOT_CONSOLE_EXE=%TVP3D_GODOT_CONSOLE%"
if not defined TVP3D_GODOT_CONSOLE_EXE if defined TVP3D_GODOT_EXE for %%G in ("%TVP3D_GODOT_EXE%") do if exist "%%~dpGGodot_v4.7.2-stable_win64_console.exe" set "TVP3D_GODOT_CONSOLE_EXE=%%~dpGGodot_v4.7.2-stable_win64_console.exe"
if not defined TVP3D_GODOT_CONSOLE_EXE set "TVP3D_GODOT_CONSOLE_EXE=%TVP3D_GODOT_EXE%"

if not defined TVP3D_GODOT_EXE (
  echo ERROR: Godot 4.7 no fue encontrado.
  echo Instala Godot o define TVP3D_GODOT con la ruta al ejecutable.
)
