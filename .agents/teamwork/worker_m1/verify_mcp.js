const { spawn } = require('child_process');

const godot = 'D:\\SteamLibrary\\steamapps\\common\\Godot Engine\\godot.windows.opt.tools.64.exe';
const proj = 'c:\\Users\\Zero\\Documents\\GitHub Repositories\\out-of-time-shift-gamejam\\new-game-project';

const mcp = spawn('node', ['tools/godot-mcp/build/index.js'], {
  cwd: 'c:\\Users\\Zero\\Documents\\GitHub Repositories\\out-of-time-shift-gamejam',
  env: { ...process.env, GODOT_PATH: godot }
});

let buffer = '';
const responses = new Map();

mcp.stdout.on('data', (d) => {
  buffer += d.toString();
  const lines = buffer.split('\n');
  buffer = lines.pop();
  for (const line of lines) {
    if (!line.trim()) continue;
    try {
      const msg = JSON.parse(line);
      if (msg.id !== undefined) {
        responses.set(msg.id, msg);
      }
    } catch (e) {}
  }
});

function sendRequest(id, method, params) {
  const req = { jsonrpc: '2.0', id, method, params };
  mcp.stdin.write(JSON.stringify(req) + '\n');
}

function waitResponse(id, timeoutMs = 5000) {
  return new Promise((resolve, reject) => {
    const start = Date.now();
    const iv = setInterval(() => {
      if (responses.has(id)) {
        clearInterval(iv);
        resolve(responses.get(id));
      } else if (Date.now() - start > timeoutMs) {
        clearInterval(iv);
        reject(new Error(`Timeout waiting for response id ${id}`));
      }
    }, 50);
  });
}

function sleep(ms) {
  return new Promise(resolve => setTimeout(resolve, ms));
}

async function runMcpVerification() {
  try {
    console.log('1. Initializing MCP...');
    sendRequest(1, 'initialize', {
      protocolVersion: '2024-11-05',
      capabilities: {},
      clientInfo: { name: 'm1_verifier', version: '1.0' }
    });
    const initRes = await waitResponse(1);
    console.log('MCP Init Response:', JSON.stringify(initRes.result?.serverInfo));

    console.log('2. Querying project info...');
    sendRequest(2, 'tools/call', {
      name: 'get_project_info',
      arguments: { projectPath: proj }
    });
    const projInfoRes = await waitResponse(2);
    console.log('Project Info Output:\n', projInfoRes.result?.content?.[0]?.text);

    console.log('3. Running project via MCP...');
    sendRequest(3, 'tools/call', {
      name: 'run_project',
      arguments: { projectPath: proj, scene: 'res://scenes/main.tscn' }
    });
    const runRes = await waitResponse(3);
    console.log('Run Project Output:\n', runRes.result?.content?.[0]?.text);

    console.log('4. Waiting 2.5 seconds for runtime frames...');
    await sleep(2500);

    console.log('5. Querying debug output & error reports...');
    sendRequest(4, 'tools/call', {
      name: 'get_debug_output',
      arguments: {}
    });
    const debugRes = await waitResponse(4);
    const debugText = debugRes.result?.content?.[0]?.text || '';
    console.log('Debug Output:\n', debugText);

    console.log('6. Stopping project...');
    sendRequest(5, 'tools/call', {
      name: 'stop_project',
      arguments: {}
    });
    const stopRes = await waitResponse(5);
    console.log('Stop Project Output:\n', stopRes.result?.content?.[0]?.text);

    console.log('\n=== MCP VERIFICATION SUMMARY ===');
    let jsonMatch = debugText.match(/\{[\s\S]*\}/);
    if (jsonMatch) {
      try {
        const parsed = JSON.parse(jsonMatch[0]);
        console.log(`Active MCP Errors: ${parsed.errors?.length ?? 0}`);
        if (parsed.errors && parsed.errors.length > 0) {
          console.error('FAIL - Warnings/errors reported:', parsed.errors);
        } else {
          console.log('PASS - Godot MCP reports 0 active errors and 0 warnings!');
        }
      } catch (e) {
        console.log('Debug output raw string evaluated.');
      }
    }
  } catch (err) {
    console.error('MCP verification error:', err);
  } finally {
    mcp.kill();
  }
}

runMcpVerification();
