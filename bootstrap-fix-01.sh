#!/usr/bin/env bash
# bootstrap-fix-01 — MultiPV configure bug + pydantic warning filter.
# Run from the repo root: bash bootstrap-fix-01.sh
set -euo pipefail

[ -f backend/app/engine.py ] || { echo "ERROR: run from repo root"; exit 1; }

echo "→ bootstrap-fix-01: MultiPV bug + pydantic warning filter"

# 1. Strip MultiPV from _configure() in engine.py
python << 'PYEOF'
import re, pathlib
p = pathlib.Path("backend/app/engine.py")
src = p.read_text()
before = src
src = re.sub(r'^\s*"MultiPV":\s*params\.multi_pv,\s*\n', '', src, flags=re.M)
if src == before:
    print("• engine.py: no MultiPV line found (already patched?)")
else:
    assert not re.search(r'"MultiPV":\s*params\.multi_pv', src), "still present"
    p.write_text(src)
    print("✓ engine.py: removed MultiPV from _configure (both branches)")
PYEOF

# 2. Filter pydantic UserWarnings in main.py
python << 'PYEOF'
import pathlib
p = pathlib.Path("backend/app/main.py")
src = p.read_text()
if "warnings.filterwarnings" in src:
    print("• main.py: filter already present")
else:
    if "import warnings\n" not in src:
        src = src.replace("import logging\n", "import logging\nimport warnings\n", 1)
    anchor = 'logger = logging.getLogger("chess_coach")\n'
    src = src.replace(
        anchor,
        anchor + 'warnings.filterwarnings("ignore", category=UserWarning, module="pydantic")\n',
        1,
    )
    p.write_text(src)
    print("✓ main.py: filtered pydantic warnings")
PYEOF

# 3. Verify syntax
python -c "import ast; ast.parse(open('backend/app/engine.py').read()); print('engine.py parses OK')"
python -c "import ast; ast.parse(open('backend/app/main.py').read()); print('main.py parses OK')"

echo ""
echo "✓ fix applied"
echo ""
echo "Restart uvicorn:"
echo "  cd backend && uvicorn app.main:app --host 127.0.0.1 --port 8000"
