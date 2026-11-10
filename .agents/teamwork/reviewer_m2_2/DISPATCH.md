## 2026-11-10T14:24:18Z
You are Reviewer M2.2 (`teamwork_reviewer`) reviewing Milestone M2 for the Godot project.
Your assigned working directory is:
`c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\reviewer_m2_2`

MANDATORY FIRST STEP:
Read `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\ORIGINAL_REQUEST.md` completely.
Also read `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\PROJECT.md`.
Read the Victory Auditor's report:
`c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\victory_auditor_1\handoff.md`
Read Worker M2's handoff:
`c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\.agents\teamwork\worker_m2\handoff.md`

Context & Parameters:
- Project Directory: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project`
- Godot Engine Executable: `D:\SteamLibrary\steamapps\common\Godot Engine\godot.windows.opt.tools.64.exe`
- Godot MCP Tooling: `c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\tools\godot-mcp`

Objective:
1. Independently test scene execution of `scenes/stickman/stickmanprocedural.tscn` and `scenes/main.tscn` headlessly for 60+ frames, capturing stdout and stderr. Verify 0 bytes stderr (0 warnings, 0 errors).
2. Run all 5 canonical test suites (`run_tests.bat`) and verify 100% test pass rate with 0 bytes stderr.
3. Test Godot MCP server over stdio JSON-RPC (`get_project_info`, `run_project`, `get_debug_output`, `stop_project`). Verify `errors: []` and clean execution.
4. In your `handoff.md`, explicitly declare your verdict as either APPROVE or REQUEST_CHANGES.
Send a completion message back to the orchestrator with your verdict and handoff path.
