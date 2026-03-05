#!/bin/bash
# Setup symlinks from this repo to ~/.claude/skills/ and ~/.claude/scripts/
# Run: bash setup.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"
SCRIPTS_DIR="$HOME/.claude/scripts"

mkdir -p "$SKILLS_DIR"
mkdir -p "$SCRIPTS_DIR"

for skill_dir in "$REPO_DIR"/skills/*/; do
  skill_name="$(basename "$skill_dir")"
  target="$SKILLS_DIR/$skill_name"

  if [ -L "$target" ]; then
    echo "skip: $skill_name (symlink already exists)"
  elif [ -e "$target" ]; then
    echo "warn: $skill_name (non-symlink file exists, skipping)"
  else
    ln -s "$skill_dir" "$target"
    echo "link: $skill_name -> $skill_dir"
  fi

  # スキルディレクトリ内のシェルスクリプトを~/.claude/scripts/にシンボリックリンク
  for script in "$skill_dir"*.sh; do
    [ -f "$script" ] || continue
    script_name="$(basename "$script")"
    script_target="$SCRIPTS_DIR/$script_name"

    if [ -L "$script_target" ]; then
      echo "skip: scripts/$script_name (symlink already exists)"
    elif [ -e "$script_target" ]; then
      echo "warn: scripts/$script_name (non-symlink file exists, skipping)"
    else
      ln -s "$script" "$script_target"
      echo "link: scripts/$script_name -> $script"
    fi
  done
done

echo "done."
