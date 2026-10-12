@echo off
rem Zapusk igry "Na vershine". Ishchet Godot 4, ustanovlennyj cherez winget.
setlocal
set "GODOT="
for /d %%D in ("%LOCALAPPDATA%\Microsoft\WinGet\Packages\GodotEngine.GodotEngine_*") do (
  for %%F in ("%%D\Godot_v*_win64.exe") do set "GODOT=%%F"
)
if not defined GODOT (
  where godot >nul 2>nul && set "GODOT=godot"
)
if not defined GODOT (
  echo Godot ne najden. Ustanovite: winget install GodotEngine.GodotEngine
  pause
  exit /b 1
)
start "" "%GODOT%" --path "%~dp0."
