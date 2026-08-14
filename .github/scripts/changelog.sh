#!/bin/bash
set -e

# ── Configuration ─────────────────────────────────────
SINCE_TAG="${1:-v0.0.0}"
DEFAULT_TMP="${RUNNER_TEMP:-/tmp}"
OUTPUT_FILE="${2:-${DEFAULT_TMP}/changelog.txt}"

# ── Scan commits since given tag ──────────────────────
if [ "$SINCE_TAG" = "v0.0.0" ] || [ -z "$SINCE_TAG" ]; then
  COMMITS=$(git log HEAD --pretty=format:"%s|%h")
else
  COMMITS=$(git log "${SINCE_TAG}..HEAD" --pretty=format:"%s|%h")
fi

echo "Generating changelog since $SINCE_TAG"

commit_link() {
  local hash="$1"

  if [ -n "${GITHUB_SERVER_URL:-}" ] && [ -n "${GITHUB_REPOSITORY:-}" ]; then
    echo "[${hash}](${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${hash})"
  else
    echo "$hash"
  fi
}

format_entry() {
  local scope="$1"
  local desc="$2"
  local link="$3"

  if [ -n "$scope" ]; then
    echo "* ${scope}: ${desc} (${link})"
  else
    echo "* ${desc} (${link})"
  fi
}

# ── Categorize commits ────────────────────────────────
BREAKINGS=""
REVERTS=""
FEATURES=""
FIXES=""
PERFS=""
REFACTORS=""
DOCS=""

while IFS='|' read -r msg hash; do
  [ -z "$msg" ] && continue

  LINK=$(commit_link "$hash")

  # 1. Revert PRs (GitHub default or conventional revert)
  if echo "$msg" | grep -qE "^Revert \""; then
    DESC=$(echo "$msg" | sed -E 's/^Revert "(.*)"$/\1/')
    ENTRY="* Revert \"${DESC}\" (${LINK})"
    REVERTS="${REVERTS}${ENTRY}\n"
    continue
  elif echo "$msg" | grep -qE "^revert(\(.+\))?:"; then
    SCOPE=$(echo "$msg" | sed -nE 's/^revert\(([^)]+)\):.*/\1/p')
    DESC=$(echo "$msg" | sed -E 's/^revert(\([^)]+\))?: *//')
    ENTRY=$(format_entry "$SCOPE" "$DESC" "$LINK")
    REVERTS="${REVERTS}${ENTRY}\n"
    continue
  fi

  # 2. Breaking Changes
  if echo "$msg" | grep -qE "^[a-zA-Z0-9_-]+(\(.+\))?!:"; then
    SCOPE=$(echo "$msg" | sed -nE 's/^[a-zA-Z0-9_-]+\(([^)]+)\)!:.*/\1/p')
    DESC=$(echo "$msg" | sed -E 's/^[a-zA-Z0-9_-]+(\([^)]+\))?!: *//')
    ENTRY=$(format_entry "$SCOPE" "$DESC" "$LINK")
    BREAKINGS="${BREAKINGS}${ENTRY}\n"
    continue
  fi

  # 3. Features
  if echo "$msg" | grep -qE "^feat(\(.+\))?:"; then
    SCOPE=$(echo "$msg" | sed -nE 's/^feat\(([^)]+)\):.*/\1/p')
    DESC=$(echo "$msg" | sed -E 's/^feat(\([^)]+\))?: *//')
    ENTRY=$(format_entry "$SCOPE" "$DESC" "$LINK")
    FEATURES="${FEATURES}${ENTRY}\n"
    continue
  fi

  # 4. Bug Fixes
  if echo "$msg" | grep -qE "^fix(\(.+\))?:"; then
    SCOPE=$(echo "$msg" | sed -nE 's/^fix\(([^)]+)\):.*/\1/p')
    DESC=$(echo "$msg" | sed -E 's/^fix(\([^)]+\))?: *//')
    ENTRY=$(format_entry "$SCOPE" "$DESC" "$LINK")
    FIXES="${FIXES}${ENTRY}\n"
    continue
  fi

  # 5. Performance Improvements
  if echo "$msg" | grep -qE "^perf(\(.+\))?:"; then
    SCOPE=$(echo "$msg" | sed -nE 's/^perf\(([^)]+)\):.*/\1/p')
    DESC=$(echo "$msg" | sed -E 's/^perf(\([^)]+\))?: *//')
    ENTRY=$(format_entry "$SCOPE" "$DESC" "$LINK")
    PERFS="${PERFS}${ENTRY}\n"
    continue
  fi

  # 6. Refactoring
  if echo "$msg" | grep -qE "^refactor(\(.+\))?:"; then
    SCOPE=$(echo "$msg" | sed -nE 's/^refactor\(([^)]+)\):.*/\1/p')
    DESC=$(echo "$msg" | sed -E 's/^refactor(\([^)]+\))?: *//')
    ENTRY=$(format_entry "$SCOPE" "$DESC" "$LINK")
    REFACTORS="${REFACTORS}${ENTRY}\n"
    continue
  fi

  # 7. Documentation
  if echo "$msg" | grep -qE "^docs(\(.+\))?:"; then
    SCOPE=$(echo "$msg" | sed -nE 's/^docs\(([^)]+)\):.*/\1/p')
    DESC=$(echo "$msg" | sed -E 's/^docs(\([^)]+\))?: *//')
    ENTRY=$(format_entry "$SCOPE" "$DESC" "$LINK")
    DOCS="${DOCS}${ENTRY}\n"
    continue
  fi

done <<< "$COMMITS"

# ── Build changelog ───────────────────────────────────
CHANGELOG=""

if [ -n "$BREAKINGS" ]; then
  CHANGELOG="${CHANGELOG}Breaking Changes\n${BREAKINGS}\n\n"
fi

if [ -n "$FEATURES" ]; then
  CHANGELOG="${CHANGELOG}Features\n${FEATURES}\n\n"
fi

if [ -n "$FIXES" ]; then
  CHANGELOG="${CHANGELOG}Bug Fixes\n${FIXES}\n\n"
fi

if [ -n "$REVERTS" ]; then
  CHANGELOG="${CHANGELOG}Reverts\n${REVERTS}\n\n"
fi

if [ -n "$PERFS" ]; then
  CHANGELOG="${CHANGELOG}Performance Improvements\n${PERFS}\n\n"
fi

if [ -n "$REFACTORS" ]; then
  CHANGELOG="${CHANGELOG}Refactoring\n${REFACTORS}\n\n"
fi

if [ -n "$DOCS" ]; then
  CHANGELOG="${CHANGELOG}Documentation\n${DOCS}\n\n"
fi

if [ -z "$CHANGELOG" ]; then
  CHANGELOG="No notable changes."
fi

echo "Changelog generated:"
printf "%b\n" "$CHANGELOG"

# ── Write changelog to file ───────────────────────────
mkdir -p "$(dirname "$OUTPUT_FILE")"
printf "%b\n" "$CHANGELOG" > "$OUTPUT_FILE"

# ── Export outputs for GitHub Actions ─────────────────
if [ -n "$GITHUB_OUTPUT" ]; then
  echo "changelog_file=$OUTPUT_FILE" >> "$GITHUB_OUTPUT"
fi