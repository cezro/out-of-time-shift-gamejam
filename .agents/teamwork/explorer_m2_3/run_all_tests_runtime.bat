@echo off
set "GODOT=D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
set "PROJ=c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project"
set "OUTDIR=c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\explorer_m2_3"

for %%F in ("%PROJ%\tests\*.gd") do (
    echo Running %%~nxF...
    "%GODOT%" -d --headless --path "%PROJ%" -s "res://tests/%%~nxF" 2> "%OUTDIR%\runtime_%%~nF.txt"
)
echo Done.
