import { spawn } from 'child_process';

const serverScript = "c:/Users/Zero/Documents/GitHub Repositories/out-of-time-shift-gamejam/tools/godot-mcp/build/index.js";
const projectPath = "c:/Users/Zero/Documents/GitHub Repositories/out-of-time-shift-gamejam/new-game-project";
const godotPath = "D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe";

const proc = spawn('node', [serverScript], {
    env: { ...process.env, GODOT_PATH: godotPath, DEBUG: "true" },
    stdio: ['pipe', 'pipe', 'inherit']
});

let buffer = '';

function send(msg) {
    proc.stdin.write(JSON.stringify(msg) + '\n');
}

proc.stdout.on('data', (data) => {
    buffer += data.toString();
    const lines = buffer.split('\n');
    buffer = lines.pop();
    for (const line of lines) {
        if (!line.trim()) continue;
        try {
            const parsed = JSON.parse(line);
            console.log("RESPONSE (id=" + parsed.id + "):", JSON.stringify(parsed, null, 2));
            if (parsed.id === 1) {
                // Run project
                console.log("Calling run_project...");
                send({
                    jsonrpc: "2.0",
                    id: 2,
                    method: "tools/call",
                    params: {
                        name: "run_project",
                        arguments: { projectPath }
                    }
                });
            } else if (parsed.id === 2) {
                // Wait 2 seconds, then get debug output
                console.log("Waiting 2.5 seconds for debug output...");
                setTimeout(() => {
                    send({
                        jsonrpc: "2.0",
                        id: 3,
                        method: "tools/call",
                        params: {
                            name: "get_debug_output",
                            arguments: {}
                        }
                    });
                }, 2500);
            } else if (parsed.id === 3) {
                // Stop project
                console.log("Calling stop_project...");
                send({
                    jsonrpc: "2.0",
                    id: 4,
                    method: "tools/call",
                    params: {
                        name: "stop_project",
                        arguments: {}
                    }
                });
            } else if (parsed.id === 4) {
                console.log("Finished successfully!");
                proc.kill();
                process.exit(0);
            }
        } catch (e) {
            console.log("RAW:", line);
        }
    }
});

send({
    jsonrpc: "2.0",
    id: 1,
    method: "initialize",
    params: {
        protocolVersion: "2024-11-05",
        capabilities: {},
        clientInfo: { name: "explorer-runner", version: "1.0.0" }
    }
});
