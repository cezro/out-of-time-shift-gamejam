const { spawn, execFile } = require('child_process');
const path = require('path');

const GODOT_EXE = 'D:\\SteamLibrary\\steamapps\\common\\Godot Engine\\godot.windows.opt.tools.64.exe';
const PROJECT_DIR = 'c:\\Users\\Zero\\Documents\\GitHub Repositories\\out-of-time-shift-gamejam\\new-game-project';
const MCP_SERVER_SCRIPT = path.join(__dirname, 'build', 'index.js');

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

class McpStressClient {
  constructor() {
    this.process = null;
    this.buffer = '';
    this.pending = new Map();
    this.msgId = 100;
  }

  async start() {
    this.process = spawn('node', [MCP_SERVER_SCRIPT], {
      cwd: __dirname,
      env: { ...process.env, GODOT_PATH: GODOT_EXE }
    });

    this.process.stdout.on('data', (chunk) => {
      this.buffer += chunk.toString();
      const lines = this.buffer.split('\n');
      this.buffer = lines.pop();
      for (const line of lines) {
        if (!line.trim()) continue;
        try {
          const msg = JSON.parse(line);
          if (msg.id !== undefined && this.pending.has(msg.id)) {
            const { resolve } = this.pending.get(msg.id);
            this.pending.delete(msg.id);
            resolve(msg);
          }
        } catch (e) {
          // ignore non-json or partial lines
        }
      }
    });

    this.process.stderr.on('data', (chunk) => {
      // server debug logs
    });

    // Initialize
    const initRes = await this.send('initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'adversarial_stress_client', version: '2.0' }
    });
    return initRes;
  }

  send(method, params, timeoutMs = 8000) {
    const id = ++this.msgId;
    return new Promise((resolve, reject) => {
      const timer = setTimeout(() => {
        if (this.pending.has(id)) {
          this.pending.delete(id);
          reject(new Error(`Timeout (${timeoutMs}ms) waiting for response id ${id} (method: ${method})`));
        }
      }, timeoutMs);

      this.pending.set(id, {
        resolve: (val) => {
          clearTimeout(timer);
          resolve(val);
        },
        reject: (err) => {
          clearTimeout(timer);
          reject(err);
        }
      });

      const req = { jsonrpc: '2.0', id, method, params };
      this.process.stdin.write(JSON.stringify(req) + '\n');
    });
  }

  callTool(name, args, timeoutMs = 8000) {
    return this.send('tools/call', { name, arguments: args }, timeoutMs);
  }

  sendRaw(rawString) {
    this.process.stdin.write(rawString + '\n');
  }

  async stop() {
    if (this.process) {
      try {
        await this.callTool('stop_project', {});
      } catch (e) {}
      this.process.kill();
      this.process = null;
    }
  }
}

async function getGodotPids() {
  return new Promise((resolve) => {
    execFile('tasklist', ['/FI', 'IMAGENAME eq godot.windows.opt.tools.64.exe', '/FO', 'CSV'], (err, stdout) => {
      if (err || !stdout) return resolve(new Set());
      const lines = stdout.trim().split('\n').filter(l => l.includes('godot.windows.opt.tools.64.exe'));
      const pids = new Set();
      for (const line of lines) {
        const parts = line.split(',');
        if (parts.length >= 2) {
          const pid = parseInt(parts[1].replace(/"/g, ''), 10);
          if (!isNaN(pid)) pids.add(pid);
        }
      }
      resolve(pids);
    });
  });
}

async function runAdversarialStressSuite() {
  console.log('================================================================');
  console.log('       GODOT MCP & ENGINE ADVERSARIAL STRESS TEST SUITE         ');
  console.log('================================================================');

  let passedTests = 0;
  let totalTests = 0;

  function assertTest(name, condition, details = '') {
    totalTests++;
    if (condition) {
      passedTests++;
      console.log(`  [PASS] Test ${totalTests}: ${name}`);
    } else {
      console.error(`  [FAIL] Test ${totalTests}: ${name} -- Details: ${details}`);
    }
  }

  // ---------------------------------------------------------------------------
  // SECTION 1: 20-Cycle Process-Level Rapid Scene Reload Loop
  // ---------------------------------------------------------------------------
  console.log('\n--- Section 1: Process-Level Rapid Scene Reload (20 Iterations) ---');
  let procCyclesPassed = 0;
  for (let i = 1; i <= 20; i++) {
    const res = await new Promise((resolve) => {
      execFile(GODOT_EXE, ['-d', '--headless', '--path', PROJECT_DIR, 'scenes/main.tscn', '--quit-after', '20'], (err, stdout, stderr) => {
        const hasErr = err !== null && (err.code !== 0);
        const hasStderr = stderr && stderr.trim().length > 0;
        const hasWarning = /warning/i.test(stdout + stderr);
        const hasUidErr = /invalid UID/i.test(stdout + stderr);
        resolve(!hasErr && !hasStderr && !hasWarning && !hasUidErr);
      });
    });
    if (res) procCyclesPassed++;
    process.stdout.write(res ? '.' : 'X');
  }
  console.log('');
  assertTest('20 Process-Level Reloads Zero Stderr & Zero Warnings', procCyclesPassed === 20, `Passed: ${procCyclesPassed}/20`);

  // Start MCP client
  const client = new McpStressClient();
  const initRes = await client.start();
  assertTest('MCP Server Initialization', initRes?.result?.serverInfo?.name === 'godot-mcp');

  // ---------------------------------------------------------------------------
  // SECTION 2: Concurrency & High Frequency Requests
  // ---------------------------------------------------------------------------
  console.log('\n--- Section 2: Concurrency & High-Frequency Request Stress ---');
  const CONCURRENT_COUNT = 15;
  const promises = [];
  for (let i = 0; i < CONCURRENT_COUNT; i++) {
    promises.push(client.callTool('get_project_info', { projectPath: PROJECT_DIR }));
  }
  const concurrentResults = await Promise.all(promises);
  const allResolved = concurrentResults.every(r => r && r.result && !r.error && !r.result.isError);
  assertTest(`Handle ${CONCURRENT_COUNT} Concurrent get_project_info Requests`, allResolved);

  // Interleaved mixed concurrent calls
  const mixedPromises = [
    client.callTool('get_godot_version', {}),
    client.callTool('get_project_info', { projectPath: PROJECT_DIR }),
    client.callTool('list_projects', { directory: path.dirname(PROJECT_DIR), recursive: false }),
    client.callTool('get_godot_version', {}),
    client.callTool('get_project_info', { projectPath: PROJECT_DIR }),
  ];
  const mixedResults = await Promise.all(mixedPromises);
  const mixedAllOk = mixedResults.every(r => r && r.result && !r.error && !r.result.isError);
  assertTest('Handle Interleaved Mixed Concurrent Requests', mixedAllOk);

  // ---------------------------------------------------------------------------
  // SECTION 3: Rapid Run / Stop Cycling & Process Leak Check
  // ---------------------------------------------------------------------------
  console.log('\n--- Section 3: Rapid Run/Stop Cycling & Zombie Process Check ---');
  const baselinePids = await getGodotPids();
  console.log(`  (Baseline Godot PIDs before cycling: ${Array.from(baselinePids).join(', ') || 'none'})`);

  let runStopSuccesses = 0;
  for (let i = 1; i <= 8; i++) {
    const runRes = await client.callTool('run_project', { projectPath: PROJECT_DIR, scene: 'res://scenes/main.tscn' });
    await sleep(80); // Briefest tick
    const stopRes = await client.callTool('stop_project', {});
    const ok = runRes?.result?.content?.[0]?.text?.includes('started') && stopRes?.result?.content?.[0]?.text?.includes('stopped');
    if (ok) runStopSuccesses++;
  }
  assertTest('8 Consecutive Rapid Run-Stop Cycles', runStopSuccesses === 8, `Passed: ${runStopSuccesses}/8`);

  // Double run_project without stop in between (test process cleanup override)
  await client.callTool('run_project', { projectPath: PROJECT_DIR, scene: 'res://scenes/main.tscn' });
  await sleep(100);
  const doubleRunRes = await client.callTool('run_project', { projectPath: PROJECT_DIR, scene: 'res://scenes/main.tscn' });
  assertTest('Consecutive run_project Without Prior Stop Gracefully Kills & Restarts', doubleRunRes?.result?.content?.[0]?.text?.includes('started'));
  await client.callTool('stop_project', {});
  await sleep(800); // Allow Windows kernel to complete process termination

  // Process leak verification: ensure no new PIDs beyond baseline
  const currentPids = await getGodotPids();
  const leakedPids = Array.from(currentPids).filter(p => !baselinePids.has(p));
  assertTest('Zero Dangling Godot Processes Leaked After Run/Stop Cycling', leakedPids.length === 0, `Leaked PIDs: ${leakedPids.join(', ')}`);

  // ---------------------------------------------------------------------------
  // SECTION 4: Debug Output Streaming Under Load
  // ---------------------------------------------------------------------------
  console.log('\n--- Section 4: Live Debug Output Streaming Under Heavy Load ---');
  await client.callTool('run_project', { projectPath: PROJECT_DIR, scene: 'res://scenes/main.tscn' });
  await sleep(800); // Allow engine to boot and run simulation

  let debugPolls = 0;
  let debugErrorsObserved = 0;
  for (let i = 0; i < 15; i++) {
    const dbgRes = await client.callTool('get_debug_output', {});
    const text = dbgRes?.result?.content?.[0]?.text || '';
    if (text) {
      debugPolls++;
      try {
        const parsed = JSON.parse(text);
        if (parsed.errors && parsed.errors.length > 0) {
          debugErrorsObserved += parsed.errors.length;
        }
      } catch (e) {}
    }
    await sleep(50);
  }
  assertTest('15 High-Frequency get_debug_output Polls During Live Simulation', debugPolls === 15);
  assertTest('Zero Active Errors Logged in Godot MCP Debug Stream', debugErrorsObserved === 0, `Errors observed: ${debugErrorsObserved}`);

  const finalStop = await client.callTool('stop_project', {});
  let finalErrorsCount = 0;
  try {
    const parsedStop = JSON.parse(finalStop?.result?.content?.[0]?.text || '{}');
    finalErrorsCount = parsedStop.finalErrors?.length || 0;
  } catch (e) {}
  assertTest('Zero Final Errors Upon Project Stop in Godot MCP', finalErrorsCount === 0, `Final errors: ${finalErrorsCount}`);

  // ---------------------------------------------------------------------------
  // SECTION 5: Adversarial Inputs, Security & Error Handling
  // ---------------------------------------------------------------------------
  console.log('\n--- Section 5: Adversarial Input Fuzzing & Error Handling ---');

  // 1. Unknown tool
  const unknownToolRes = await client.callTool('non_existent_exploit_tool', {});
  assertTest('Unknown Tool Rejection (MethodNotFound)', unknownToolRes?.error?.code === -32601 || unknownToolRes?.error !== undefined);

  // 2. Directory traversal in projectPath
  const traversalRes = await client.callTool('run_project', { projectPath: PROJECT_DIR + '\\..\\..\\malicious' });
  assertTest('Path Traversal Prevention in projectPath', traversalRes?.result?.isError === true || traversalRes?.error !== undefined);

  // 3. Non-existent project path
  const nonExistentProjRes = await client.callTool('run_project', { projectPath: 'C:\\NonExistentPath_Godot_Test' });
  assertTest('Non-Existent Project Path Graceful Error', nonExistentProjRes?.result?.isError === true);

  // 4. Missing required projectPath argument
  const missingArgsRes = await client.callTool('run_project', {});
  assertTest('Missing Required Argument Graceful Error', missingArgsRes?.result?.isError === true);

  // 5. get_debug_output when idle
  const idleDebugRes = await client.callTool('get_debug_output', {});
  assertTest('get_debug_output on Idle Server Returns Informative Error', idleDebugRes?.result?.isError === true && idleDebugRes?.result?.content?.[0]?.text?.includes('No active Godot process'));

  // 6. stop_project when idle
  const idleStopRes = await client.callTool('stop_project', {});
  assertTest('stop_project on Idle Server Returns Informative Error', idleStopRes?.result?.isError === true && idleStopRes?.result?.content?.[0]?.text?.includes('No active Godot process'));

  // 7. Malformed JSON injection on stdin (server resilience test)
  client.sendRaw('{"jsonrpc": "2.0", "invalid_syntax...');
  await sleep(100);
  const healthCheckRes = await client.callTool('get_godot_version', {});
  assertTest('Server Remains Healthy and Alive After Malformed JSON Injection', healthCheckRes?.result?.content?.[0]?.text?.includes('4.7'));

  // Cleanup
  await client.stop();

  console.log('\n================================================================');
  console.log(`ADVERSARIAL STRESS SUMMARY: ${passedTests} / ${totalTests} PASSED (Failed: ${totalTests - passedTests})`);
  console.log('================================================================\n');

  if (passedTests === totalTests) {
    console.log('>>> OVERALL ADVERSARIAL VERDICT: APPROVE <<<');
    process.exit(0);
  } else {
    console.error('>>> OVERALL ADVERSARIAL VERDICT: REJECT <<<');
    process.exit(1);
  }
}

runAdversarialStressSuite().catch((err) => {
  console.error('Fatal test error:', err);
  process.exit(1);
});
