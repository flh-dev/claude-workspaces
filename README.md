# claude-workspaces

Claude Code plugin marketplace with workspace bundles: one plugin per kind of work, enabled per
project. This repository is public so cloud environments can install from it.

## What belongs here

- Bundle definitions (`<bundle>/.claude-plugin/plugin.json`): a name, a description and the
  plugins the bundle depends on.
- Third-party plugins pinned by commit in `.claude-plugin/marketplace.json`, reviewed with
  `check-pins.sh`.
- `cloud-setup.sh`, which cloud environments run as their setup script.

Nothing private: no own skills, no client or company content, no credentials. Own skills live in
the claude.ai account (personal) or the KFP organisation (shared), which syncs them to local,
Cowork and cloud sessions. Plugins wanted in every session are enabled on the claude.ai account,
not bundled here.

## Bundles

| Bundle | For |
|---|---|
| `design` | Critique, polish, motion and UI review of an existing interface |
| `design-explore` | Art direction and styles for a new visual direction |
| `web` | Browser testing, TypeScript code intelligence, accessibility, performance, SEO |
| `go`, `python` | Language servers |
| `notes` | Obsidian vault |
| `m365` | Microsoft 365 and SharePoint |
| `sap`, `sap-btp` | SAP development |

## Use

Locally, add this directory as a marketplace and enable bundles per project:

```sh
claude plugin marketplace add ~/.claude/workspaces
claude plugin install web@workspaces --scope local
```

Edits load in place at the next session. A bundle whose dependencies change needs a version bump
and `claude plugin update <bundle>@workspaces --scope local` in each project that uses it.

In a cloud environment, use this as the setup script:

```sh
curl -fsSL https://raw.githubusercontent.com/flh-dev/claude-workspaces/main/cloud-setup.sh \
  | bash -s -- design web
```
