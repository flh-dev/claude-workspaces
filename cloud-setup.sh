#!/usr/bin/env bash
# Installs this marketplace's bundles into a Claude Code cloud environment.
# Cloud sessions don't load plugins from user or repo settings, only what the
# environment's setup script installs. Use as the environment setup script:
#
#   curl -fsSL https://raw.githubusercontent.com/flh-dev/claude-workspaces/main/cloud-setup.sh \
#     | bash -s -- design web cloudflare@claude-plugins-official
#
# Arguments: bundle names from this marketplace, or full plugin@marketplace ids.
# core@workspaces is always installed. The environment caches the result, so
# new pins arrive when the environment cache is rebuilt.
set -euo pipefail

add_marketplace() { claude plugin marketplace add "$1" || true; }
add_marketplace anthropics/claude-plugins-official
add_marketplace anthropics/skills
add_marketplace flh-dev/claude-workspaces

for plugin in core "$@"; do
  [[ $plugin == *@* ]] || plugin="$plugin@workspaces"
  claude plugin install "$plugin"
done
