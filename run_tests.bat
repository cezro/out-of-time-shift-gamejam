@echo off
set "GODOT_PATH=D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe"
set "PROJ=%~dp0new-game-project"

echo [1/15] Running Core Kinematics ^& Combat Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_core.gd 2>&1
if errorlevel 1 exit /b 1

echo [2/15] Running Chronos Shift ^& Timeline Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_chrono_and_timeline.gd 2>&1
if errorlevel 1 exit /b 1

echo [3/15] Running Modular Piece-by-Piece Rig Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_modular_rig.gd 2>&1
if errorlevel 1 exit /b 1

echo [4/15] Running End-to-End Game Scene Integration Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_game_integration.gd 2>&1
if errorlevel 1 exit /b 1

echo [5/15] Running Disprover Adversarial Red-Team Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_adversarial_disprover.gd 2>&1
if errorlevel 1 exit /b 1

echo [6/15] Running Procedural Stickman Stress Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_stickman_procedural_stress.gd 2>&1
if errorlevel 1 exit /b 1

echo [7/15] Running M2 Motion Dynamics Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_m2_motion_dynamics.gd 2>&1
if errorlevel 1 exit /b 1

echo [8/15] Running Challenger M1 Adversarial Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_challenger_m1_adversarial.gd 2>&1
if errorlevel 1 exit /b 1

echo [9/15] Running Challenger M1.2 Adversarial Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_challenger_m1_2_adversarial.gd 2>&1
if errorlevel 1 exit /b 1

echo [10/15] Running Challenger M2.1 Adversarial Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_challenger_m2_1_adversarial.gd 2>&1
if errorlevel 1 exit /b 1

echo [11/15] Running Challenger M2.2 Adversarial Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_challenger_m2_2_adversarial.gd 2>&1
if errorlevel 1 exit /b 1

echo [12/15] Running Challenger M2 Composite Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_challenger_m2_adversarial_suite.gd 2>&1
if errorlevel 1 exit /b 1

echo [13/15] Running Challenger M3.2 Global Coverage Suite...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_challenger_m3_2_adversarial.gd 2>&1
if errorlevel 1 exit /b 1

echo [14/15] Running Milestone 3 Adversarial Empirical Stress...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/test_adversarial_m3_stress.gd 2>&1
if errorlevel 1 exit /b 1

echo [15/15] Running In-Engine Rapid Scene Reload Stress Harness...
"%GODOT_PATH%" --headless --path "%PROJ%" --script res://tests/stress_scene_in_engine.gd 2>&1
if errorlevel 1 exit /b 1

echo.
echo =======================================================
echo ALL 15 GODOT TEST SUITES PASSED WITH 0 DEFECTS!
echo =======================================================
