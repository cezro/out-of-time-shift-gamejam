@echo off
set "GODOT_PATH=D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
set "PROJ=%~dp0new-game-project"

echo [1/5] Running Core Kinematics ^& Combat Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_core.gd 2>&1
if errorlevel 1 exit /b 1

echo [2/5] Running Chronos Shift ^& Timeline Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_chrono_and_timeline.gd 2>&1
if errorlevel 1 exit /b 1

echo [3/5] Running Modular Piece-by-Piece Rig Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_modular_rig.gd 2>&1
if errorlevel 1 exit /b 1

echo [4/5] Running End-to-End Game Scene Integration Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_game_integration.gd 2>&1
if errorlevel 1 exit /b 1

echo [5/5] Running Disprover Adversarial Red-Team Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_adversarial_disprover.gd 2>&1
if errorlevel 1 exit /b 1

echo ALL 5 TEST SUITES PASSED!
