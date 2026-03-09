#!/bin/bash
# Setup symlinks from this repo to ~/.claude/skills/ and ~/.claude/scripts/
# Run: bash setup.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
SCRIPTS_DIR="$HOME/.claude/scripts"

mkdir -p "$SKILLS_DIR"
mkdir -p "$SCRIPTS_DIR"

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

for skill_dir in "$REPO_DIR"/skills/*/; do
  skill_name="$(basename "$skill_dir")"
  target="$SKILLS_DIR/$skill_name"

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
