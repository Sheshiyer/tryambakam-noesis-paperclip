#!/usr/bin/env bash
set -euo pipefail

copy_scripts_from_repo() {
  if [[ "$#" -lt 3 ]]; then
    echo "Usage: copy_scripts_from_repo <source_repo> <target_dir> <script_name...>" >&2
    return 2
  fi

  local source_repo="$1"
  local target_dir="$2"
  shift 2

  local source_scripts_dir="$source_repo/scripts"
  if [[ ! -d "$source_scripts_dir" ]]; then
    echo "Missing source scripts directory: $source_scripts_dir" >&2
    return 1
  fi

  mkdir -p "$target_dir"
  local script_name
  for script_name in "$@"; do
    local source_path="$source_scripts_dir/$script_name"
    if [[ ! -f "$source_path" ]]; then
      echo "Missing source script: $source_path" >&2
      return 1
    fi
    cp "$source_path" "$target_dir/$script_name"
  done
}

write_runtime_root_guard_stub() {
  local target_path="$1"
  cat > "$target_path" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
case "${1:-check}" in
  assert|check) exit 0 ;;
  *) exit 0 ;;
esac
EOF
  chmod +x "$target_path"
}

make_scripts_executable() {
  if [[ "$#" -lt 2 ]]; then
    echo "Usage: make_scripts_executable <scripts_dir> <script_name...>" >&2
    return 2
  fi

  local scripts_dir="$1"
  shift

  local script_name
  for script_name in "$@"; do
    local target_path="$scripts_dir/$script_name"
    if [[ ! -f "$target_path" ]]; then
      echo "Missing target script: $target_path" >&2
      return 1
    fi
    chmod +x "$target_path"
  done
}
