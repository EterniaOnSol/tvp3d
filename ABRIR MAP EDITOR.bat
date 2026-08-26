@echo off
title TVP3D - Map Editor
cd /d "%~dp0"

call "%~dp0herramientas\resolver_godot.bat"
if not defined TVP3D_GODOT_EXE (
  pause
  exit /b 1
)

"%TVP3D_GODOT_EXE%" --path "%~dp0cliente3d" editor/editor3d.tscn
