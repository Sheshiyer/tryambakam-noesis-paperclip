#!/usr/bin/env bash
set -euo pipefail

yaml_path_get() {
  local file="$1"
  local path="$2"
  python3 - "$file" "$path" <<'PY'
import sys

file_path = sys.argv[1]
path = tuple(part for part in sys.argv[2].split(".") if part)

def strip_inline_comment(s: str) -> str:
    in_single = False
    in_double = False
    for i, ch in enumerate(s):
        if ch == "'" and not in_double:
            in_single = not in_single
        elif ch == '"' and not in_single:
            in_double = not in_double
        elif ch == "#" and not in_single and not in_double:
            if i == 0 or s[i - 1].isspace():
                return s[:i].rstrip()
    return s.rstrip()

def parse_scalar_yaml(lines):
    values = {}
    stack = []  # (indent, path_parts)

    for raw in lines:
        if not raw.strip():
            continue
        if raw.lstrip().startswith("#"):
            continue

        indent = len(raw) - len(raw.lstrip(" "))
        line = raw.strip()
        if line.startswith("- "):
            continue
        if ":" not in line:
            continue

        key, rest = line.split(":", 1)
        key = key.strip()
        rest = strip_inline_comment(rest.strip())

        while stack and indent <= stack[-1][0]:
            stack.pop()

        parent = stack[-1][1] if stack else []
        current_path = parent + [key]

        if rest == "":
            stack.append((indent, current_path))
            continue

        if len(rest) >= 2 and rest[0] == rest[-1] and rest[0] in ("'", '"'):
            rest = rest[1:-1]

        values[tuple(current_path)] = rest

    return values

try:
    with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
        parsed = parse_scalar_yaml(f.readlines())
except FileNotFoundError:
    print("")
    raise SystemExit(0)

print(parsed.get(path, ""))
PY
}

yaml_is_false() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  value="${value,,}"
  [[ "$value" == "false" || "$value" == "no" || "$value" == "0" ]]
}

yaml_is_true() {
  local value="${1:-}"
  value="${value#"${value%%[![:space:]]*}"}"
  value="${value%"${value##*[![:space:]]}"}"
  value="${value,,}"
  [[ "$value" == "true" || "$value" == "yes" || "$value" == "1" ]]
}
