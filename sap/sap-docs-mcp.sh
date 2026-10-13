#!/usr/bin/env bash
# Launches the SAP docs MCP server (stdio) in a throwaway container for one Claude session.
# The container must never outlive the session, hence three layers:
#   1. the server exits when stdin closes (upstream keeps running otherwise);
#      its console logging goes to stderr, stdout carries only MCP messages
#   2. this launcher removes its container on exit
#   3. each start sweeps containers whose launcher died without cleaning up (e.g. SIGKILL)
set -uo pipefail

IMAGE="mcp-sap-docs:ab9c2a7"   # keep in sync with pins-extra.tsv; rebuild via build-sap-docs.sh
LABEL="claude.mcp=sap-docs"
NAME="sap-docs-mcp-$$"

for id in $(docker ps -aq --filter "label=$LABEL"); do
  launcher_pid=$(docker inspect -f '{{index .Config.Labels "claude.launcher-pid"}}' "$id" 2>/dev/null)
  kill -0 "$launcher_pid" 2>/dev/null || docker rm -f "$id" >/dev/null 2>&1
done

trap 'docker rm -f "$NAME" >/dev/null 2>&1' EXIT INT TERM HUP

# MCP_PRELOAD_EMBEDDINGS=false: load the semantic model on first search, not at session start
docker run -i --rm --init --no-healthcheck \
  --name "$NAME" --label "$LABEL" --label "claude.launcher-pid=$$" \
  -e MCP_PRELOAD_EMBEDDINGS=false \
  "$IMAGE" \
  node --import "data:text/javascript,console.log=console.info=console.error;process.stdin.on('end',()=>process.exit(0))" dist/src/server.js
