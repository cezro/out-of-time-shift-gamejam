# Dispatch for Explorer Survey 3 (Scene Hierarchy, Resources & Dependency Audit)

- Working Directory: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\explorer_survey_3
- Project Directory: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project
- Original Request: c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\ORIGINAL_REQUEST.md
- Godot Executable: D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe
- Focus: Audit all scenes (.tscn), resources (.tres), shaders (.gdshader), tilemaps, collision shapes, and assets in `new-game-project`. Detect any missing resources, broken ext_resource/sub_resource links, UID discrepancies, or editor load warnings.


## 2026-11-10T13:11:14Z
From: 86a09c29-dff7-47f8-88f0-15d3fb6a2bab
Priority: MESSAGE_PRIORITY_HIGH

You are a read-only Explorer agent (`teamwork_explorer`) performing Phase 0 Survey for the Godot project.
Your assigned working directory is:
`c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\explorer_survey_3`

MANDATORY FIRST STEP:
Read `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\ORIGINAL_REQUEST.md` completely.
Also read `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\explorer_survey_3\DISPATCH.md`.

Context & Parameters:
- Project Directory: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project`
- Godot Engine Executable: `D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`

Objective:
1. Audit all scenes (`.tscn`), resources (`.tres`), shaders (`.gdshader`), materials, tilemaps, fonts, and textures in `new-game-project`.
2. Check for missing dependencies (`ExtResource` pointing to non-existent files or invalid UIDs), corrupted resource files, or circular dependencies.
3. Test loading individual scenes using Godot CLI headless mode (e.g. `& "D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe" --headless --path "c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project" scene_file.tscn --quit-after 60` or similar headless checks) to identify any resource-loading warnings, missing shader uniforms, invalid node configurations, or missing collision shapes.
4. List all discovered issues, with file paths, scene names, and exact warning/error messages.

Do NOT modify or create any source code files (you are read-only).
Maintain `progress.md` with timestamps in your working directory.
When finished, write a comprehensive report to `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\explorer_survey_3\analysis.md` and write a standard Handoff report to `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\explorer_survey_3\handoff.md`.
Finally, send a completion message back to the orchestrator with a summary and the path to your handoff file.
