const { execFile } = require('child_process');
const fs = require('fs');
const path = require('path');

const godotPath = 'D:\\SteamLibrary\\steamapps\\common\\Godot Engine\\godot.windows.opt.tools.64.exe';
const projectPath = 'c:\\Users\\Zero\\Documents\\GitHub Repositories\\out-of-time-shift-gamejam\\new-game-project';

function runGodot(args) {
  return new Promise((resolve) => {
    execFile(godotPath, args, { windowsHide: true }, (error, stdout, stderr) => {
      resolve({
        code: error ? (error.code ?? 1) : 0,
        stdout: stdout || '',
        stderr: stderr || '',
        error
      });
    });
  });
}

function findGdScripts(dir, baseDir) {
  let results = [];
  const entries = fs.readdirSync(dir, { withFileTypes: true });
  for (const entry of entries) {
    const fullPath = path.join(dir, entry.name);
    if (entry.isDirectory()) {
      if (entry.name !== '.godot') {
        results = results.concat(findGdScripts(fullPath, baseDir));
      }
    } else if (entry.isFile() && entry.name.endsWith('.gd')) {
      const rel = path.relative(baseDir, fullPath).replace(/\\/g, '/');
      results.push('res://' + rel);
    }
  }
  return results;
}

async function main() {
  console.log('================================================================');
  console.log('AUDITOR INDEPENDENT FORENSIC VERIFICATION RUNNER');
  console.log('Godot Executable:', godotPath);
  console.log('Project Directory:', projectPath);
  console.log('================================================================\n');

  const scripts = findGdScripts(projectPath, projectPath);
  console.log(`Discovered ${scripts.length} GDScript files:`);
  for (const s of scripts) {
    console.log(`  - ${s}`);
  }

  // Phase 1: Check-only syntax validation
  console.log('\n--- Phase 1: Script Syntax & Parse Check (--check-only) ---');
  let parseErrors = 0;
  for (const s of scripts) {
    const res = await runGodot(['--headless', '--path', projectPath, '--check-only', '-s', s]);
    if (res.code !== 0 || res.stderr.trim().length > 0) {
      console.log(`[FAIL] ${s} (exit code ${res.code})`);
      if (res.stderr.trim()) console.log(`  STDERR: ${res.stderr.trim()}`);
      parseErrors++;
    } else {
      console.log(`[PASS] ${s}`);
    }
  }
  console.log(`Phase 1 Summary: ${scripts.length - parseErrors}/${scripts.length} passed (errors: ${parseErrors})`);

  // Phase 2: Debug Mode Warning Scan (-d --headless)
  console.log('\n--- Phase 2: Debug Mode Warning Scan (-d --headless --check-only) ---');
  let warningCount = 0;
  for (const s of scripts) {
    const res = await runGodot(['-d', '--headless', '--path', projectPath, '--check-only', '-s', s]);
    const stderrTrimmed = res.stderr.trim();
    if (stderrTrimmed.length > 0) {
      console.log(`[WARNING/ERROR DETECTED] ${s}:`);
      console.log(stderrTrimmed);
      warningCount++;
    } else {
      console.log(`[CLEAN: 0 WARNINGS] ${s}`);
    }
  }
  console.log(`Phase 2 Summary: ${warningCount} scripts emitted warnings/errors (expected: 0)`);

  // Phase 3: Automated Test Suites
  console.log('\n--- Phase 3: Automated Test Suite Execution ---');
  const testSuites = [
    'res://tests/test_core.gd',
    'res://tests/test_chrono_and_timeline.gd',
    'res://tests/test_modular_rig.gd',
    'res://tests/test_game_integration.gd',
    'res://tests/test_adversarial_disprover.gd'
  ];

  let totalTestSuitesFailed = 0;
  for (const t of testSuites) {
    console.log(`\nExecuting test suite: ${t}...`);
    const res = await runGodot(['--headless', '--path', projectPath, '-s', t]);
    console.log(res.stdout.trim());
    if (res.stderr.trim()) {
      console.log(`[STDERR]:\n${res.stderr.trim()}`);
    }
    if (res.code !== 0) {
      console.log(`[SUITE FAILED] Exit code: ${res.code}`);
      totalTestSuitesFailed++;
    } else {
      console.log(`[SUITE PASSED] Exit code: ${res.code}`);
    }
  }
  console.log(`\nPhase 3 Summary: ${testSuites.length - totalTestSuitesFailed}/${testSuites.length} suites passed`);

  // Phase 4: Headless Scene Execution of scenes/main.tscn (60 frames)
  console.log('\n--- Phase 4: Headless Scene Execution (scenes/main.tscn for 60 frames) ---');
  const sceneRes = await runGodot(['-d', '--headless', '--path', projectPath, 'scenes/main.tscn', '--quit-after', '60']);
  console.log('STDOUT:\n' + sceneRes.stdout.trim());
  console.log('STDERR length:', sceneRes.stderr.trim().length);
  if (sceneRes.stderr.trim().length > 0) {
    console.log('STDERR:\n' + sceneRes.stderr.trim());
  } else {
    console.log('Clean execution: ZERO errors and ZERO warnings logged.');
  }
  console.log('Exit code:', sceneRes.code);

  console.log('\n================================================================');
  console.log('AUDITOR FORENSIC VERIFICATION COMPLETE');
  console.log('================================================================');
}

main().catch(err => {
  console.error('Fatal execution error:', err);
  process.exit(1);
});
