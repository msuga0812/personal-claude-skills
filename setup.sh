#!/bin/bash
# Setup symlinks from this repo to ~/.claude/skills/
# Run: bash setup.sh

set -euo pipefail

REPO_DIR="$(cd "$(dirname "$0")" && pwd)"
SKILLS_DIR="$HOME/.claude/skills"

mkdir -p "$SKILLS_DIR"

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
done

echo "done."
