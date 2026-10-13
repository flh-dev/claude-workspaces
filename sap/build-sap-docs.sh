#!/usr/bin/env bash
# Builds the local mcp-sap-docs image used by the sap workspace (.mcp.json).
#
#   build-sap-docs.sh [<commit sha>]   default: the sha pinned in ../pins-extra.tsv
#
# Upstream's Dockerfile clones every doc source at its branch head, so a build breaks
# whenever SAP renames a file the server still expects. We check the doc sources out
# at the commits the server repo pins (its submodule gitlinks) before building; the
# Dockerfile's own clone step then fails on the existing directories and keeps ours.
set -euo pipefail

SRC="$HOME/.local/share/mcp-sap-docs"
PINS="$HOME/.claude/workspaces/pins-extra.tsv"
SHA="${1:-$(awk -F'\t' '/^sap-docs/ { print $4 }' "$PINS")}"
TAG="mcp-sap-docs:${SHA:0:7}"

[ -d "$SRC/.git" ] || git clone -q https://github.com/marianfoo/mcp-sap-docs.git "$SRC"
git -C "$SRC" fetch -q origin
git -C "$SRC" checkout -q "$SHA"

# Only sources the repo records as gitlinks have a pin; the rest stay at branch head.
mapfile -t paths < <(comm -12 \
  <(jq -r '.submodulePaths[]' "$SRC/config/variants/sap-docs.json" | sort) \
  <(git -C "$SRC" ls-files --stage -- sources | awk '$1 == "160000" { print $4 }' | sort))
echo "Checking out ${#paths[@]} doc sources at their pinned commits (others follow upstream head)..."
GIT_LFS_SKIP_SMUDGE=1 git -C "$SRC" submodule update --init --depth 1 --jobs 8 -- "${paths[@]}"

docker build --build-arg MCP_VARIANT=sap-docs -t "$TAG" "$SRC"
echo "Built $TAG. The sap workspace .mcp.json must reference this tag."
