import { fileURLToPath } from 'url';
import { dirname, join } from 'path';

const mcpModulePath = "c:/Users/Zero/Documents/GitHub Repositories/out-of-time-shift-gamejam/tools/godot-mcp/build/index.js";
const projectPath = "c:/Users/Zero/Documents/GitHub Repositories/out-of-time-shift-gamejam/new-game-project";
const godotPath = "D:/SteamLibrary/steamapps/common/Godot Engine/godot.windows.opt.tools.64.exe";

process.env.GODOT_PATH = godotPath;

async function test() {
    // Dynamic import
    const mcp = await import("file://" + mcpModulePath);
    console.log("Godot MCP Module loaded successfully");
}

test().catch(err => {
    console.error("Error:", err);
});
