#!/usr/bin/env bash
# bootstrap-project/run.sh
# Creates a new claude-to-code project from Spec Factory output.
#
# Usage: run.sh <project-name>
# Prompts interactively for target folder, source folder, and privacy.

set -euo pipefail

# --- Args ---------------------------------------------------------------------

if [[ $# -lt 1 ]]; then
  echo "error: project name required" >&2
  echo "usage: run.sh <project-name>" >&2
  exit 1
fi

PROJECT_NAME="$1"

# Validate project name: lowercase letters, digits, hyphens only.
if [[ ! "$PROJECT_NAME" =~ ^[a-z0-9][a-z0-9-]*[a-z0-9]$ ]]; then
  echo "error: invalid project name '$PROJECT_NAME'" >&2
  echo "       use lowercase letters, digits, and hyphens only." >&2
  echo "       must start and end with a letter or digit." >&2
  exit 1
fi

# --- Paths --------------------------------------------------------------------

SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CONFIG_FILE="$SKILL_DIR/.config"

# --- Preflight ----------------------------------------------------------------

for cmd in gh git; do
  if ! command -v "$cmd" >/dev/null 2>&1; then
    echo "error: '$cmd' not found on PATH." >&2
    if [[ "$cmd" == "gh" ]]; then
      echo "       install from https://cli.github.com/ then run 'gh auth login'." >&2
    fi
    exit 1
  fi
done

if ! gh auth status >/dev/null 2>&1; then
  echo "error: gh is not authenticated." >&2
  echo "       run: gh auth login" >&2
  exit 1
fi

# --- Config: first run or existing? -------------------------------------------

# Config file format (one key=value per line):
#   github_user=neeeeeeessa
#   template_repo=neeeeeeessa/claude-to-code
#   target_folders=C:\Users\simoe\Projects|D:\work|~/Dev/github
#   default_source=~/Downloads
#
# `target_folders` is a pipe-separated list of candidate folders to offer.

if [[ ! -f "$CONFIG_FILE" ]]; then
  echo ""
  echo "first run on this machine — let's set up the config."
  echo ""

  read -rp "your github username: " github_user
  if [[ -z "$github_user" ]]; then
    echo "error: github username cannot be empty" >&2
    exit 1
  fi

  read -rp "template repo [${github_user}/claude-to-code]: " template_repo
  template_repo="${template_repo:-${github_user}/claude-to-code}"

  echo ""
  echo "where do projects live on this machine?"
  echo "enter one or more paths, one per line. blank line when done."
  echo "(these will be offered as choices when you bootstrap a project.)"
  echo ""
  target_folders=""
  while true; do
    read -rp "  path: " folder
    if [[ -z "$folder" ]]; then break; fi
    # Normalize: expand ~ to $HOME
    folder="${folder/#\~/$HOME}"
    if [[ -z "$target_folders" ]]; then
      target_folders="$folder"
    else
      target_folders="$target_folders|$folder"
    fi
  done

  if [[ -z "$target_folders" ]]; then
    echo "error: at least one target folder is required" >&2
    exit 1
  fi

  read -rp "default source folder for spec files [~/Downloads]: " default_source
  default_source="${default_source:-~/Downloads}"
  default_source="${default_source/#\~/$HOME}"

  cat > "$CONFIG_FILE" <<EOF
github_user=$github_user
template_repo=$template_repo
target_folders=$target_folders
default_source=$default_source
EOF

  echo ""
  echo "config saved to $CONFIG_FILE"
  echo "edit this file anytime to change defaults."
  echo ""
fi

# Load config
# shellcheck disable=SC1090
. "$CONFIG_FILE"

# --- Interactive: target folder -----------------------------------------------

echo "project: $PROJECT_NAME"
echo ""
echo "where should the project be created?"

# Parse target_folders (pipe-separated)
IFS='|' read -r -a FOLDER_CHOICES <<< "$target_folders"

i=1
for f in "${FOLDER_CHOICES[@]}"; do
  echo "  $i) $f"
  i=$((i + 1))
done
echo "  $i) other (specify path)"
OTHER_OPTION=$i

while true; do
  read -rp "choice [1]: " choice
  choice="${choice:-1}"
  if [[ "$choice" =~ ^[0-9]+$ ]] && [[ "$choice" -ge 1 ]] && [[ "$choice" -le "$OTHER_OPTION" ]]; then
    break
  fi
  echo "please enter a number between 1 and $OTHER_OPTION"
done

if [[ "$choice" -eq "$OTHER_OPTION" ]]; then
  read -rp "path: " TARGET_PARENT
  TARGET_PARENT="${TARGET_PARENT/#\~/$HOME}"
else
  TARGET_PARENT="${FOLDER_CHOICES[$((choice - 1))]}"
fi

if [[ ! -d "$TARGET_PARENT" ]]; then
  echo "error: parent folder does not exist: $TARGET_PARENT" >&2
  exit 1
fi

TARGET_DIR="$TARGET_PARENT/$PROJECT_NAME"

if [[ -e "$TARGET_DIR" ]]; then
  echo "error: $TARGET_DIR already exists." >&2
  echo "       pick a different project name or delete the existing folder." >&2
  exit 1
fi

# --- Interactive: source folder -----------------------------------------------

echo ""
read -rp "where are the 5 spec files? [$default_source]: " SOURCE_DIR
SOURCE_DIR="${SOURCE_DIR:-$default_source}"
SOURCE_DIR="${SOURCE_DIR/#\~/$HOME}"

if [[ ! -d "$SOURCE_DIR" ]]; then
  echo "error: source folder does not exist: $SOURCE_DIR" >&2
  exit 1
fi

# --- Interactive: privacy -----------------------------------------------------

echo ""
read -rp "repo visibility [private]: (private/public) " visibility
visibility="${visibility:-private}"
if [[ "$visibility" != "private" && "$visibility" != "public" ]]; then
  echo "error: visibility must be 'private' or 'public'" >&2
  exit 1
fi

# --- Locate the 5 spec files with fuzzy matching ------------------------------

echo ""
echo "looking for spec files in $SOURCE_DIR..."

declare -A FOUND_FILES

find_file() {
  local expected="$1"
  local basename_noext="${expected%.md}"

  # Priority order:
  # 1. Exact match: constitution.md
  # 2. Exact match in subdirectory (e.g. SOURCE_DIR/spec-output/constitution.md)
  # 3. Pattern match: constitution*.md, constitution (1).md, constitution-2.md
  # 4. Most-recently-modified match

  local candidates=()

  # Exact match at root
  if [[ -f "$SOURCE_DIR/$expected" ]]; then
    candidates+=("$SOURCE_DIR/$expected")
  fi

  # Pattern matches at root (handles "(1)", "-2", " 2", "_2", etc.)
  while IFS= read -r -d '' candidate; do
    # Skip if already in candidates
    local already=0
    for c in "${candidates[@]}"; do
      if [[ "$c" == "$candidate" ]]; then already=1; break; fi
    done
    if [[ $already -eq 0 ]]; then
      candidates+=("$candidate")
    fi
  done < <(find "$SOURCE_DIR" -maxdepth 2 -type f -iname "${basename_noext}*.md" -print0 2>/dev/null)

  if [[ ${#candidates[@]} -eq 0 ]]; then
    return 1
  fi

  # If only one candidate, use it.
  if [[ ${#candidates[@]} -eq 1 ]]; then
    echo "${candidates[0]}"
    return 0
  fi

  # Multiple candidates: pick most recently modified.
  # This handles the Claude.ai "(1)" case — the newer one is usually what you want.
  local newest=""
  local newest_time=0
  for c in "${candidates[@]}"; do
    local mtime
    mtime=$(stat -c '%Y' "$c" 2>/dev/null || stat -f '%m' "$c" 2>/dev/null || echo 0)
    if [[ "$mtime" -gt "$newest_time" ]]; then
      newest_time=$mtime
      newest="$c"
    fi
  done
  echo "$newest"
}

REQUIRED_FILES=("constitution.md" "spec.md" "plan.md" "tasks.md" "handoff-summary.md")
MISSING=()

for f in "${REQUIRED_FILES[@]}"; do
  resolved=$(find_file "$f" || true)
  if [[ -z "$resolved" ]]; then
    MISSING+=("$f")
  else
    FOUND_FILES[$f]="$resolved"
    # Pretty-print the mapping: show the filename found vs expected
    found_basename="$(basename "$resolved")"
    if [[ "$found_basename" != "$f" ]]; then
      echo "  ✓ $f → $(basename "$resolved")"
    else
      echo "  ✓ $f"
    fi
  fi
done

if [[ ${#MISSING[@]} -gt 0 ]]; then
  echo ""
  echo "error: could not find these files in $SOURCE_DIR:" >&2
  for m in "${MISSING[@]}"; do
    echo "  - $m" >&2
  done
  echo "" >&2
  echo "download all five artifacts from the Spec Factory and try again." >&2
  exit 1
fi

# Confirm mappings if any were fuzzy-matched
FUZZY_COUNT=0
for f in "${REQUIRED_FILES[@]}"; do
  if [[ "$(basename "${FOUND_FILES[$f]}")" != "$f" ]]; then
    FUZZY_COUNT=$((FUZZY_COUNT + 1))
  fi
done

if [[ $FUZZY_COUNT -gt 0 ]]; then
  echo ""
  read -rp "some files were fuzzy-matched. proceed? [Y/n]: " confirm
  confirm="${confirm:-Y}"
  if [[ "$confirm" != "Y" && "$confirm" != "y" ]]; then
    echo "aborted."
    exit 1
  fi
fi

# --- Confirm the plan ---------------------------------------------------------

echo ""
echo "ready to bootstrap:"
echo "  project name: $PROJECT_NAME"
echo "  github repo:  $github_user/$PROJECT_NAME ($visibility)"
echo "  from template: $template_repo"
echo "  local path:   $TARGET_DIR"
echo "  source files: $SOURCE_DIR"
echo ""
read -rp "proceed? [Y/n]: " confirm
confirm="${confirm:-Y}"
if [[ "$confirm" != "Y" && "$confirm" != "y" ]]; then
  echo "aborted."
  exit 1
fi

# --- Do the work --------------------------------------------------------------

echo ""
echo "▶ creating repo $github_user/$PROJECT_NAME from template $template_repo"
cd "$TARGET_PARENT"
gh repo create "$github_user/$PROJECT_NAME" \
  --template "$template_repo" \
  --clone \
  --"$visibility"

cd "$TARGET_DIR"

echo "▶ activating pre-commit hook"
git config core.hooksPath .githooks

# The template repo contains a tools/ folder with skills, installer, and the
# Spec Factory prompt. New projects don't need any of that — remove it so
# the project starts clean.
if [[ -d tools ]]; then
  echo "▶ removing tools/ (not needed in new projects)"
  rm -rf tools
fi

echo "▶ placing spec files"
# constitution goes to .specify/memory/
cp "${FOUND_FILES[constitution.md]}" .specify/memory/constitution.md
# rest go to specs/
for f in spec.md plan.md tasks.md handoff-summary.md; do
  cp "${FOUND_FILES[$f]}" "specs/$f"
done

# Remove the placeholder README in specs/ if it exists
if [[ -f specs/README.md ]]; then
  rm specs/README.md
fi

echo "▶ creating branch ralph/initial-build"
git checkout -b ralph/initial-build

echo "▶ committing specs"
git add .
git commit -m "specs: initial import from Spec Factory" >/dev/null

# --- Run A3 validator if installed --------------------------------------------

VALIDATOR_SCRIPT="$HOME/.claude/skills/validate-specs/validate.sh"
if [[ -f "$VALIDATOR_SCRIPT" ]]; then
  echo "▶ validating specs (A3)"
  if bash "$VALIDATOR_SCRIPT"; then
    VALIDATION_STATUS="passed"
  else
    rc=$?
    if [[ $rc -eq 1 ]]; then
      VALIDATION_STATUS="failed — fix issues before running /ralph-go"
    elif [[ $rc -eq 2 ]]; then
      VALIDATION_STATUS="warnings only (can proceed)"
    else
      VALIDATION_STATUS="validator error"
    fi
  fi
else
  VALIDATION_STATUS="skipped (A3 skill not installed)"
fi

# --- Report -------------------------------------------------------------------

echo ""
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo "✓ project bootstrapped: $PROJECT_NAME"
echo "━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━"
echo ""
echo "  local path:     $TARGET_DIR"
echo "  github:         https://github.com/$github_user/$PROJECT_NAME"
echo "  branch:         ralph/initial-build"
echo "  validation:     $VALIDATION_STATUS"
echo ""
echo "next:"
echo "  cd '$TARGET_DIR'"
echo "  claude                        # open Claude Code"
echo "  > /ralph-go cautious          # or work interactively"
echo ""
