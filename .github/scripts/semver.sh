#!/bin/bash
set -e

# ── Configuration ─────────────────────────────────────
BRANCH="${1:-dev}"
TAG_PREFIX="v"
DEV_SUFFIX="dev"

# ── Get last production tag (clean, no dev suffix) ────
LAST_PROD_TAG=$(git tag --list "${TAG_PREFIX}*" \
  | grep -E "^${TAG_PREFIX}[0-9]+\.[0-9]+\.[0-9]+$" \
  | sort -V \
  | tail -n1 || true)

if [ -z "$LAST_PROD_TAG" ]; then
  LAST_PROD_TAG="${TAG_PREFIX}0.0.0"
fi

echo "Last prod tag: $LAST_PROD_TAG"

# ── Parse major.minor.patch ───────────────────────────
VERSION="${LAST_PROD_TAG#${TAG_PREFIX}}"
MAJOR=$(echo "$VERSION" | cut -d. -f1)
MINOR=$(echo "$VERSION" | cut -d. -f2)
PATCH=$(echo "$VERSION" | cut -d. -f3)

# ── Scan commit messages since last prod tag ──────────
if [ "$LAST_PROD_TAG" = "${TAG_PREFIX}0.0.0" ]; then
  COMMIT_MSGS=$(git log HEAD --pretty=format:"%s")
else
  COMMIT_MSGS=$(git log "${LAST_PROD_TAG}..HEAD" --pretty=format:"%s")
fi

echo "Commits since $LAST_PROD_TAG:"
echo "$COMMIT_MSGS"

# ── Determine bump type ───────────────────────────────
BUMP="patch"  # default

if echo "$COMMIT_MSGS" | grep -qE "^[a-zA-Z0-9_-]+(\(.+\))?!:"; then
  BUMP="major"
elif echo "$COMMIT_MSGS" | grep -qE "^feat(\(.+\))?:"; then
  BUMP="minor"
elif echo "$COMMIT_MSGS" | grep -qE "^(fix|perf|refactor|docs)(\(.+\))?:"; then
  BUMP="patch"
fi

echo "Bump type: $BUMP"

# ── Calculate next version ────────────────────────────
if [ "$BUMP" = "major" ]; then
  MAJOR=$((MAJOR + 1)); MINOR=0; PATCH=0
elif [ "$BUMP" = "minor" ]; then
  MINOR=$((MINOR + 1)); PATCH=0
else
  PATCH=$((PATCH + 1))
fi

NEXT_VERSION="${MAJOR}.${MINOR}.${PATCH}"

# ── Determine output tag and previous dev/prod tag for changelog ─────────
if [ "$BRANCH" = "main" ]; then
  NEW_TAG="${TAG_PREFIX}${NEXT_VERSION}"
  PREV_DEV_TAG="$LAST_PROD_TAG"
else
  # Find the last dev increment for this version
  LAST_DEV=$(git tag --list "${TAG_PREFIX}${NEXT_VERSION}-${DEV_SUFFIX}.*" \
    | sort -V \
    | tail -n1 || true)

  if [ -z "$LAST_DEV" ]; then
    DEV_NUM=1
    PREV_DEV_TAG="$LAST_PROD_TAG"
  else
    DEV_NUM=$(echo "$LAST_DEV" | grep -oE "[0-9]+$")
    DEV_NUM=$((DEV_NUM + 1))
    PREV_DEV_TAG="$LAST_DEV"
  fi

  NEW_TAG="${TAG_PREFIX}${NEXT_VERSION}-${DEV_SUFFIX}.${DEV_NUM}"
fi

echo "New tag: $NEW_TAG"
echo "Prev dev tag: $PREV_DEV_TAG"

# ── Export outputs for GitHub Actions ─────────────────
if [ -n "$GITHUB_OUTPUT" ]; then
  echo "new_tag=$NEW_TAG" >> "$GITHUB_OUTPUT"
  echo "prev_dev_tag=$PREV_DEV_TAG" >> "$GITHUB_OUTPUT"
  echo "bump_type=$BUMP" >> "$GITHUB_OUTPUT"
  echo "next_version=$NEXT_VERSION" >> "$GITHUB_OUTPUT"
fi