@echo off
set "GODOT_PATH=D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
if not exist "%GODOT_PATH%" (
    set "GODOT_PATH=godot"
)
echo Launching OUT OF TIME (Godot 4.7)...
"%GODOT_PATH%" --path "%~dp0new-game-project"
