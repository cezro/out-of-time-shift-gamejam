const { execFile } = require('child_process');
const fs = require('fs');
const path = require('path');

const godot = 'D:\\SteamLibrary\\steamapps\\common\\Godot Engine\\godot.windows.opt.tools.64.exe';
const proj = 'c:\\Users\\Zero\\Documents\\GitHub Repositories\\out-of-time-shift-gamejam\\new-game-project';

function execAsync(args) {
  return new Promise((resolve) => {
    execFile(godot, args, (err, stdout, stderr) => {
      resolve({ err, stdout, stderr });
    });
  });
}

async function runVerification() {
  console.log('=== STEP 1: --check-only on all scripts ===');
  const scripts = [
    'res://scripts/chrono_shift/chrono_shift_model.gd',
    'res://scripts/timeline/timeline_system.gd',
    'res://scripts/game/game_controller.gd',
    'res://scripts/game/audio_manager.gd',
    'res://scripts/core/combat_math.gd',
    'res://scripts/core/enemy_ai.gd',
    'res://scripts/core/player_kinematics.gd',
    'res://scripts/core/ragdoll_physics.gd',
    'res://scripts/core/time_control.gd',
    'res://scripts/modular_rig/modular_asset_system.gd',
    'res://scripts/tools/asset_mcp_bridge.gd',
    'res://tests/test_core.gd',
    'res://tests/test_chrono_and_timeline.gd',
    'res://tests/test_modular_rig.gd',
    'res://tests/test_game_integration.gd',
    'res://tests/test_adversarial_disprover.gd'
  ];

  let checkOnlyErrors = 0;
  for (const s of scripts) {
    const res = await execAsync(['--headless', '--path', proj, '--check-only', '-s', s]);
    if (res.err) {
      console.error(`PARSE ERROR in ${s}:`, res.stderr);
      checkOnlyErrors++;
    }
  }
  console.log(`--check-only result: ${scripts.length - checkOnlyErrors}/${scripts.length} passed (errors: ${checkOnlyErrors})`);

  console.log('\n=== STEP 2: Debug Mode (-d --headless) Stderr Warning Scan ===');
  let totalWarnings = 0;
  for (const s of scripts) {
    const res = await execAsync(['-d', '--headless', '--path', proj, '--check-only', '-s', s]);
    const stderrTrimmed = res.stderr.trim();
    if (stderrTrimmed.length > 0) {
      console.log(`WARNINGS in ${s}:\n${stderrTrimmed}`);
      totalWarnings++;
    }
  }
  console.log(`Debug check result: ${totalWarnings} scripts logged warnings (0 expected)`);

  console.log('\n=== STEP 3: Automated Test Suites (All 5) ===');
  const testSuites = [
    'res://tests/test_core.gd',
    'res://tests/test_chrono_and_timeline.gd',
    'res://tests/test_modular_rig.gd',
    'res://tests/test_game_integration.gd',
    'res://tests/test_adversarial_disprover.gd'
  ];

  let totalTestsPassed = 0;
  let testSuiteFailures = 0;
  for (const t of testSuites) {
    const res = await execAsync(['--headless', '--path', proj, '-s', t]);
    const stdout = res.stdout;
    const stderr = res.stderr.trim();
    console.log(`\n--- Test Suite: ${t} ---`);
    console.log(stdout.trim());
    if (stderr) {
      console.log(`[STDERR]:\n${stderr}`);
    }
    if (res.err) {
      console.error(`FAILED: ${t} (exit code ${res.err.code})`);
      testSuiteFailures++;
    }
  }

  console.log('\n=== STEP 4: Headless Execution of scenes/main.tscn (60 frames) ===');
  const sceneRes = await execAsync(['-d', '--headless', '--path', proj, 'scenes/main.tscn', '--quit-after', '60']);
  console.log('STDOUT:\n', sceneRes.stdout.trim());
  console.log('STDERR length:', sceneRes.stderr.trim().length);
  if (sceneRes.stderr.trim().length > 0) {
    console.log('STDERR:\n', sceneRes.stderr.trim());
  } else {
    console.log('Zero errors and zero warnings logged for scenes/main.tscn!');
  }

  console.log('\n=== ALL CLI VERIFICATION STEPS COMPLETE ===');
}

runVerification();
