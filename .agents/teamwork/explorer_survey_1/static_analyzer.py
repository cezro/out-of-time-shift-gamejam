import os
import re
from pathlib import Path

PROJECT_DIR = Path(r"c:\Users\Zero\Documents\GitHub Repositories\out-of-time-shift-gamejam\new-game-project")

DEPRECATIONS = [
    (r'\binstance\(\)', 'Use instantiate() instead of instance() in Godot 4+'),
    (r'\byield\(', 'Use await instead of yield() in Godot 4+'),
    (r'\brand_range\(', 'Use randf_range() or randi_range() instead of rand_range()'),
    (r'\bexport\(', 'Use @export annotation instead of export keyword'),
    (r'\bonready\s+var', 'Use @onready annotation instead of onready keyword'),
    (r'\btool\b', 'Use @tool annotation instead of tool keyword'),
    (r'\.connect\(\s*["\']', 'Old string-based connect() syntax; prefer signal.connect(callable)'),
    (r'\.disconnect\(\s*["\']', 'Old string-based disconnect() syntax; prefer signal.disconnect(callable)'),
    (r'\.emit_signal\(\s*["\']', 'Old string-based emit_signal() syntax; prefer signal.emit(...)'),
    (r'\bFile\.new\(', 'Use FileAccess.open() instead of File.new() in Godot 4+'),
    (r'\bDirectory\.new\(', 'Use DirAccess.open() instead of Directory.new() in Godot 4+'),
    (r'\bVisualServer\b', 'Use RenderingServer instead of VisualServer in Godot 4+'),
    (r'\bPhysics2DServer\b', 'Use PhysicsServer2D instead of Physics2DServer in Godot 4+'),
    (r'\bSpatial\b', 'Use Node3D instead of Spatial in Godot 4+'),
]

DISCARDABLE_CALLS = [
    ('Dictionary.erase', r'(\w+)\.erase\('),
    ('Signal.connect', r'(\w+)\.connect\('),
    ('Signal.disconnect', r'(\w+)\.disconnect\('),
    ('ResourceSaver.save', r'ResourceSaver\.save\('),
    ('CharacterBody2D.move_and_slide', r'\bmove_and_slide\('),
]

def strip_strings_and_comments(text):
    # Replace multiline strings """ ... """ and ''' ... '''
    def replace_triple(match):
        return ' ' * len(match.group(0))
    text = re.sub(r'"""[\s\S]*?"""', replace_triple, text)
    text = re.sub(r"'''[\s\S]*?'''", replace_triple, text)

    # Process line by line
    result_lines = []
    for line in text.splitlines():
        # Remove comment
        # Find # not in string
        line_clean = []
        in_str = None
        for char in line:
            if in_str:
                if char == in_str:
                    in_str = None
                line_clean.append(' ')
            else:
                if char in ('"', "'"):
                    in_str = char
                    line_clean.append(' ')
                elif char == '#':
                    break
                else:
                    line_clean.append(char)
        result_lines.append("".join(line_clean))
    return result_lines

def analyze_script(filepath):
    rel_path = filepath.relative_to(PROJECT_DIR).as_posix()
    raw_content = filepath.read_text(encoding='utf-8', errors='replace')
    raw_lines = raw_content.splitlines()
    clean_lines = strip_strings_and_comments(raw_content)

    issues = {
        'deprecations': [],
        'untyped_vars': [],
        'untyped_params': [],
        'missing_return_types': [],
        'unused_parameters': [],
        'shadowed_variables': [],
        'return_value_discarded': [],
        'integer_divisions': [],
        'class_members': set(),
    }

    # 1. Find class members
    for i, line in enumerate(clean_lines):
        stripped = line.strip()
        indent = len(line) - len(line.lstrip())
        if indent == 0:
            m = re.match(r'^(?:@\w+\s+)*var\s+(\w+)', stripped)
            if m:
                issues['class_members'].add(m.group(1))

    # 2. Check line by line
    paren_depth = 0
    in_func = False
    current_func = None
    func_params = []
    func_lines = []
    func_start_line = 0

    for idx, (raw_line, clean_line) in enumerate(zip(raw_lines, clean_lines)):
        line_num = idx + 1
        stripped = clean_line.strip()
        indent = len(clean_line) - len(clean_line.lstrip())

        # Check deprecations in raw line (before string stripping, though usually code)
        for pat, desc in DEPRECATIONS:
            if re.search(pat, raw_line):
                issues['deprecations'].append((line_num, raw_line.strip(), desc))

        if not stripped:
            continue

        # Count parentheses
        open_parens = clean_line.count('(') + clean_line.count('[') + clean_line.count('{')
        close_parens = clean_line.count(')') + clean_line.count(']') + clean_line.count('}')
        prev_depth = paren_depth
        paren_depth += (open_parens - close_parens)

        # Detect function header
        func_match = re.match(r'^(static\s+)?func\s+(\w+)\s*\((.*?)\)(?:\s*->\s*([\w\.\[\]]+))?\s*:', stripped)
        if func_match:
            # Check old func unused params
            if current_func:
                _check_unused(current_func, func_params, func_lines, issues)

            is_static = bool(func_match.group(1))
            func_name = func_match.group(2)
            params_str = func_match.group(3)
            ret_type = func_match.group(4)

            current_func = func_name
            func_start_line = line_num
            func_lines = []
            func_params = []

            if ret_type is None and not func_name.startswith('_init'):
                issues['missing_return_types'].append((line_num, func_name, "Missing explicit '-> Type' return hint"))

            if params_str.strip():
                for p in params_str.split(','):
                    p = p.strip()
                    if not p:
                        continue
                    pm = re.match(r'(\w+)(?:\s*:\s*([\w\.\[\]]+))?(?:\s*=\s*(.*))?', p)
                    if pm:
                        p_name = pm.group(1)
                        p_type = pm.group(2)
                        p_default = pm.group(3)
                        func_params.append((p_name, line_num))

                        if p_type is None and p_default is None:
                            issues['untyped_params'].append((line_num, f"{func_name}({p_name})", f"Untyped parameter '{p_name}'"))

                        if p_name in issues['class_members'] and not is_static:
                            issues['shadowed_variables'].append((line_num, f"{func_name}({p_name})", f"Parameter '{p_name}' shadows class member"))
            continue

        if current_func and indent > 0:
            func_lines.append(stripped)

        # Only check statements at root of a line (not inside multiline parentheses)
        if prev_depth == 0:
            # Check untyped local variables
            # var x = ... (without := and without : Type)
            var_m = re.match(r'^var\s+(\w+)\s*=\s*', stripped)
            if var_m:
                vname = var_m.group(1)
                # Ensure it's not var x := ...
                if not stripped.startswith(f'var {vname} :='):
                    issues['untyped_vars'].append((line_num, raw_line.strip(), f"Untyped variable '{vname}' ('var {vname} = ...')"))

            # Check shadowed local variables
            var_any = re.match(r'^var\s+(\w+)', stripped)
            if var_any and indent > 0:
                vname = var_any.group(1)
                if vname in issues['class_members']:
                    issues['shadowed_variables'].append((line_num, raw_line.strip(), f"Local variable '{vname}' shadows class member"))

            # Check discarded return values
            for fname, pat in DISCARDABLE_CALLS:
                if re.search(pat, stripped):
                    # Check if line does not assign or return
                    if not any(stripped.startswith(pfx) for pfx in ['var ', 'return ', 'if ', 'while ', 'elif ', 'match ']) and '=' not in stripped.split('(')[0]:
                        issues['return_value_discarded'].append((line_num, raw_line.strip(), f"Discarded return value from {fname}()"))

            # Check integer division: \b\d+\s*/\s*\d+\b (excluding floats \d+\.\d+)
            # clean_line has no strings or comments
            int_div = re.search(r'(?<![\d\.])(\d+)\s*/\s*(\d+)(?![\d\.])', clean_line)
            if int_div:
                n1, n2 = int_div.group(1), int_div.group(2)
                issues['integer_divisions'].append((line_num, raw_line.strip(), f"Integer division {n1} / {n2}"))

    if current_func:
        _check_unused(current_func, func_params, func_lines, issues)

    return issues

def _check_unused(func_name, params, lines, issues):
    body = " ".join(lines)
    for p_name, line_num in params:
        if p_name.startswith('_'):
            continue
        if not re.search(r'\b' + re.escape(p_name) + r'\b', body):
            issues['unused_parameters'].append((line_num, f"{func_name}({p_name})", f"Parameter '{p_name}' unused in body"))

if __name__ == '__main__':
    all_files = sorted(list(PROJECT_DIR.glob('**/*.gd')))
    total = 0
    report = []
    for f in all_files:
        rel = f.relative_to(PROJECT_DIR).as_posix()
        res = analyze_script(f)
        subtotal = sum(len(v) for k, v in res.items() if isinstance(v, list))
        total += subtotal
        if subtotal > 0:
            report.append(f"\n### `{rel}` ({subtotal} issues/warnings)")
            for k in ['deprecations', 'unused_parameters', 'shadowed_variables', 'return_value_discarded', 'untyped_vars', 'untyped_params', 'missing_return_types', 'integer_divisions']:
                items = res[k]
                if items:
                    report.append(f"- **{k.upper()}** ({len(items)}):")
                    for it in items:
                        report.append(f"  - Line {it[0]}: `{it[1]}` — {it[2]}")

    print("\n".join(report))
    print(f"\n==========================================")
    print(f"TOTAL VERIFIED FINDINGS: {total}")
