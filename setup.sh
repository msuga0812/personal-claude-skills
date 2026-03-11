#!/bin/bash
# Setup symlinks from this repo to ~/.claude/skills/ and ~/.claude/scripts/
# Run: bash setup.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
SCRIPTS_DIR="$HOME/.claude/scripts"

FORCE_ALL=0
SELECTED_SKILLS=()
SKILL_NAMES=()

usage() {
  cat <<'EOF'
Usage: bash setup.sh [options]

Options:
  -a, --all   Install all skills
  -y, --yes   Install all skills (for non-interactive mode)
  -h, --help  Show this help
EOF
}

is_interactive() {
  [ -t 0 ] && [ -t 1 ]
}

add_selected_skill() {
  local name="$1"
  local existing
  for existing in "${SELECTED_SKILLS[@]:-}"; do
    [ "$existing" = "$name" ] && return 0
  done
  SELECTED_SKILLS+=("$name")
}

select_all_skills() {
  SELECTED_SKILLS=("${SKILL_NAMES[@]}")
}

collect_skills() {
  local skill_dir
  for skill_dir in "$REPO_DIR"/skills/*/; do
    [ -d "$skill_dir" ] || continue
    SKILL_NAMES+=("$(basename "$skill_dir")")
  done

  if [ "${#SKILL_NAMES[@]}" -eq 0 ]; then
    echo "error: no skills found in $REPO_DIR/skills"
    exit 1
  fi
}

select_with_gum() {
  local options selection line
  options=("[ALL] すべて選択" "${SKILL_NAMES[@]}")

  echo "Select skills to install (multi-select):"
  selection="$(printf '%s\n' "${options[@]}" | gum choose --no-limit || true)"

  [ -n "$selection" ] || return 0

  while IFS= read -r line; do
    [ -n "$line" ] || continue
    if [ "$line" = "[ALL] すべて選択" ]; then
      select_all_skills
      return 0
    fi
    add_selected_skill "$line"
  done <<EOF
$selection
EOF
}

select_with_number_prompt() {
  local i input normalized token idx skill_name

  echo "Select skills to install by number (comma-separated)."
  echo "Type 'all' to install all skills, or press Enter to skip."
  for i in "${!SKILL_NAMES[@]}"; do
    printf "  %d) %s\n" "$((i + 1))" "${SKILL_NAMES[$i]}"
  done

  read -r -p "Selection: " input || true
  normalized="${input//[[:space:]]/}"

  [ -n "$normalized" ] || return 0
  if [ "$normalized" = "all" ] || [ "$normalized" = "ALL" ]; then
    select_all_skills
    return 0
  fi

  IFS=',' read -r -a tokens <<<"$normalized"
  for token in "${tokens[@]}"; do
    if ! [[ "$token" =~ ^[0-9]+$ ]]; then
      echo "warn: invalid selection '$token' (skipped)"
      continue
    fi

    idx=$((token - 1))
    if [ "$idx" -lt 0 ] || [ "$idx" -ge "${#SKILL_NAMES[@]}" ]; then
      echo "warn: selection out of range '$token' (skipped)"
      continue
    fi

    skill_name="${SKILL_NAMES[$idx]}"
    add_selected_skill "$skill_name"
  done
}

ensure_symlink() {
  local name="$1" src="$2" dst="$3"
  if [ -L "$dst" ]; then
    echo "skip: $name (symlink already exists)"
  elif [ -e "$dst" ]; then
    echo "warn: $name (non-symlink file exists, skipping)"
  else
    ln -s "$src" "$dst"
    echo "link: $name -> $src"
  fi
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    -a|--all)
      FORCE_ALL=1
      ;;
    -y|--yes)
      FORCE_ALL=1
      ;;
    -h|--help)
      usage
      exit 0
      ;;
    *)
      echo "error: unknown option: $1"
      usage
      exit 1
      ;;
  esac
  shift
done

collect_skills

if [ "$FORCE_ALL" -eq 1 ]; then
  select_all_skills
elif is_interactive; then
  if command -v gum >/dev/null 2>&1; then
    select_with_gum
  else
    echo "info: gum not found. Falling back to numbered prompt."
    select_with_number_prompt
  fi
else
  echo "info: non-interactive mode without --all/-y. Nothing installed."
  echo "hint: run with --all or -y to install all skills."
  exit 0
fi

if [ "${#SELECTED_SKILLS[@]}" -eq 0 ]; then
  echo "info: no skills selected. nothing to do."
  exit 0
fi

mkdir -p "$SKILLS_DIR"
mkdir -p "$SCRIPTS_DIR"

echo "selected: ${SELECTED_SKILLS[*]}"

for skill_name in "${SELECTED_SKILLS[@]}"; do
  skill_dir="$REPO_DIR/skills/$skill_name/"
  target="$SKILLS_DIR/$skill_name"

  if [ ! -d "$skill_dir" ]; then
    echo "warn: skill directory not found: $skill_dir (skipped)"
    continue
  fi

  # スキル固有のsetup.shがあれば実行し、scripts/シンボリックリンクはスキップ
  if [ -x "$skill_dir/setup.sh" ]; then
    echo "setup: $skill_name (custom setup)"
    "$skill_dir/setup.sh"
    ensure_symlink "$skill_name" "$skill_dir" "$target"
    continue
  fi

  ensure_symlink "$skill_name" "$skill_dir" "$target"

  # スキルディレクトリ内のシェルスクリプトを~/.claude/scripts/にシンボリックリンク
  for script in "$skill_dir"*.sh; do
    [ -f "$script" ] || continue
    script_name="$(basename "$script")"
    script_target="$SCRIPTS_DIR/$script_name"

    ensure_symlink "scripts/$script_name" "$script" "$script_target"
  done
done

echo "done."
