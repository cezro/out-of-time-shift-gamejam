import os
import re

tscn_path = r"c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project\scenes\stickman\stickmanprocedural.tscn"
assets_dir = r"c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project\assets\stickman"

pngs = sorted([f for f in os.listdir(assets_dir) if f.endswith('.png')])
imports = sorted([f for f in os.listdir(assets_dir) if f.endswith('.png.import')])

print(f"PNG count: {len(pngs)}")
print(f"Import count: {len(imports)}")

missing_imports = [p for p in pngs if p + ".import" not in imports]
print(f"Missing imports: {missing_imports}")

with open(tscn_path, "r", encoding="utf-8") as f:
    tscn_content = f.read()

# Pattern for ext_resource
pattern = r'\[ext_resource type="Texture2D" uid="([^"]+)" path="res://assets/stickman/([^"]+)"'
ext_resources = re.findall(pattern, tscn_content)
print(f"TSCN ExtResource textures found: {len(ext_resources)}")

all_matched = True
for uid, filename in ext_resources:
    imp_file = os.path.join(assets_dir, filename + ".import")
    if not os.path.exists(imp_file):
        print(f"FAIL: {imp_file} does not exist!")
        all_matched = False
        continue
    with open(imp_file, "r", encoding="utf-8") as imp_f:
        imp_text = imp_f.read()
    if f'uid="{uid}"' not in imp_text:
        print(f"FAIL: UID mismatch for {filename}: tscn={uid}")
        all_matched = False
    if f'source_file="res://assets/stickman/{filename}"' not in imp_text:
        print(f"FAIL: source_file mismatch for {filename}")
        all_matched = False
    else:
        print(f"OK: {filename} -> {uid}")

print(f"ALL MATCHED: {all_matched}")
