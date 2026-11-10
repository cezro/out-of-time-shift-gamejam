from pathlib import Path
import re

p = Path(r"c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project\scripts\modular_rig\modular_asset_system.gd")
lines = p.read_text(encoding="utf-8").splitlines()
for i, line in enumerate(lines, 1):
    m = re.match(r"^\s+var\s+(\w+)\s*=\s*", line)
    if m and ":=" not in line and ":" not in line.split("=")[0]:
        print(f"Line {i}: {line.strip()}")
