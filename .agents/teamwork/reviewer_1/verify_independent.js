const { execFile } = require('child_process');
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

async function runReviewerVerification() {
  console.log('====================================================');
  console.log('REVIEWER 1 INDEPENDENT VERIFICATION SUITE');
  console.log('====================================================\n');

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
    'res://scripts/stickman/stickmanprocedural.gd',
    'res://scripts/tools/asset_mcp_bridge.gd',
    'res://tests/test_core.gd',
    'res://tests/test_chrono_and_timeline.gd',
    'res://tests/test_modular_rig.gd',
    'res://tests/test_game_integration.gd',
    'res://tests/test_adversarial_disprover.gd'
  ];

  console.log(`[1] Verifying static compilation (--check-only) on ${scripts.length} scripts...`);
  let checkOnlyPassed = 0;
  let checkOnlyFailed = 0;
  for (const s of scripts) {
    const res = await execAsync(['--headless', '--path', proj, '--check-only', '-s', s]);
    if (res.err) {
      console.error(`  FAIL: ${s}\n  Error: ${res.stderr || res.stdout}`);
      checkOnlyFailed++;
    } else {
      checkOnlyPassed++;
    }
  }
  console.log(`  -> Summary: ${checkOnlyPassed}/${scripts.length} passed, ${checkOnlyFailed} failed.`);

  console.log(`\n[2] Verifying debug mode compiler warnings (-d --headless --check-only)...`);
  let warningCount = 0;
  for (const s of scripts) {
    const res = await execAsync(['-d', '--headless', '--path', proj, '--check-only', '-s', s]);
    const stderrTrimmed = res.stderr.trim();
    if (stderrTrimmed.length > 0) {
      console.log(`  WARNING DETECTED in ${s}:\n${stderrTrimmed}`);
      warningCount++;
    }
  }
  console.log(`  -> Summary: ${warningCount} scripts with compiler warnings (Target: 0).`);

  console.log(`\n[3] Executing 5 automated test suites...`);
  const testSuites = [
    'res://tests/test_core.gd',
    'res://tests/test_chrono_and_timeline.gd',
    'res://tests/test_modular_rig.gd',
    'res://tests/test_game_integration.gd',
    'res://tests/test_adversarial_disprover.gd'
  ];

  let suitesPassed = 0;
  let suitesFailed = 0;
  let totalAssertionsPassed = 0;
  let totalAssertionsFailed = 0;

  for (const t of testSuites) {
    const res = await execAsync(['--headless', '--path', proj, '-s', t]);
    const stdout = res.stdout;
    const stderr = res.stderr.trim();

    // Parse summary lines: e.g. "=== Test Summary: 42 passed, 0 failed ==="
    // or "[DISPROVER RESULTS]: 17 / 17 passed"
    const passFailMatch = stdout.match(/=== Test Summary:\s*(\d+)\s+passed,\s*(\d+)\s+failed ===/i);
    const disproverMatch = stdout.match(/\[DISPROVER RESULTS\]:\s*(\d+)\s*\/\s*(\d+)\s*passed/i);

    let passedInSuite = 0;
    let failedInSuite = 0;

    if (passFailMatch) {
      passedInSuite = parseInt(passFailMatch[1], 10);
      failedInSuite = parseInt(passFailMatch[2], 10);
    } else if (disproverMatch) {
      passedInSuite = parseInt(disproverMatch[1], 10);
      const totalInDisprover = parseInt(disproverMatch[2], 10);
      failedInSuite = totalInDisprover - passedInSuite;
    }

    totalAssertionsPassed += passedInSuite;
    totalAssertionsFailed += failedInSuite;

    const suiteStatus = (res.err == null && failedInSuite === 0) ? 'PASS' : 'FAIL';
    if (suiteStatus === 'PASS') {
      suitesPassed++;
    } else {
      suitesFailed++;
    }

    console.log(`  Suite [${suiteStatus}]: ${t} -> ${passedInSuite} passed, ${failedInSuite} failed (Exit code: ${res.err ? res.err.code : 0})`);
    if (stderr.length > 0) {
      console.log(`    stderr: ${stderr}`);
    }
  }
  console.log(`  -> Suites: ${suitesPassed}/${testSuites.length} passed.`);
  console.log(`  -> Assertions: ${totalAssertionsPassed} passed, ${totalAssertionsFailed} failed.`);

  console.log(`\n[4] Executing scenes/main.tscn in headless debug mode (-d --headless --quit-after 60)...`);
  const sceneRes = await execAsync(['-d', '--headless', '--path', proj, 'scenes/main.tscn', '--quit-after', '60']);
  const sceneStderr = sceneRes.stderr.trim();
  const sceneExitCode = sceneRes.err ? sceneRes.err.code : 0;
  console.log(`  Exit code: ${sceneExitCode}`);
  console.log(`  Stderr length: ${sceneStderr.length}`);
  if (sceneStderr.length > 0) {
    console.log(`  Scene Stderr:\n${sceneStderr}`);
  } else {
    console.log(`  Clean execution! 0 errors and 0 warnings emitted.`);
  }

  console.log('\n====================================================');
  console.log('FINAL REVIEW SUMMARY:');
  console.log(`  Scripts compiled: ${checkOnlyPassed}/${scripts.length}`);
  console.log(`  Compiler warnings: ${warningCount}`);
  console.log(`  Test suites: ${suitesPassed}/${testSuites.length}`);
  console.log(`  Total assertions: ${totalAssertionsPassed} passed, ${totalAssertionsFailed} failed`);
  console.log(`  Scene execution: ${sceneExitCode === 0 && sceneStderr.length === 0 ? 'CLEAN' : 'DIRTY'}`);
  console.log('====================================================');
}

runReviewerVerification().catch(console.error);
