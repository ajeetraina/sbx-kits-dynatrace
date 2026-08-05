# Dynatrace targets for the kit

The kit gives your agent hands-on access to Dynatrace — problems, security
vulnerabilities, entities, logs, and DQL queries against Grail — through the
official [Dynatrace MCP server](https://github.com/dynatrace-oss/dynatrace-mcp),
plus a few `requests`-based runbooks for scripting. What changes per target is
*which Dynatrace* it points at and *how the MCP server is hosted*.

## Target matrix

| Target | MCP server | Dynatrace | Credential | How it reaches Dynatrace |
|---|---|---|---|---|
| [remote](./remote.md) (default) | **Hosted** by Dynatrace (no install) | SaaS (`*.apps.dynatrace.com`) | platform token via `sbx secret set -g dynatrace` | proxy injects `Authorization: Bearer` on the wire |
| [local](./local.md) | Self-hosted in the sandbox (`@dynatrace-oss/dynatrace-mcp-server`) | SaaS (`*.apps.dynatrace.com`) | platform token via `sbx secret set -g dynatrace` | proxy injects `Authorization: Bearer` on the wire |
| [managed](./managed.md) | Self-hosted (`@dynatrace-oss/dynatrace-managed-mcp-server`) | Dynatrace **Managed** (your cluster) | API token via `sbx secret set -g dynatrace` | proxy injects `Authorization: Api-Token` on the wire |

## Why `remote` is the default

Dynatrace's guidance for local-dev clients (VS Code, Claude Code, Cursor, …) is
to use the hosted **Remote MCP server**: nothing is installed in the sandbox, it
is always up to date, and it needs no infrastructure. The self-hosted local
server still works and ships as the `local` kit, but it is in maintenance mode
upstream. Both target Dynatrace **SaaS** (the Gen3 `*.apps.dynatrace.com`
platform with Grail/DQL). Dynatrace **Managed** (self-hosted clusters) has a
different API and its own MCP server — that is the `managed` kit.

## Notes that apply to every target

1. **The kit never holds a token.** `sbx run` has no `-e` flag by design. You
   store the token once with sbx's secret manager and the sbx proxy attaches it
   to outbound requests on the wire, so it never enters the sandbox, shell
   history, or `ps`. The stored secret is named `dynatrace` (matching
   `credentials.sources.dynatrace` in the spec).

   ```bash
   echo "$DT_TOKEN" | sbx secret set -g dynatrace    # -g = all sandboxes
   sbx secret ls                                      # confirm a `dynatrace` entry
   ```

2. **The environment URL is the one value the kit cannot know for you.** SaaS
   URLs (`https://<env>.apps.dynatrace.com`) and Managed cluster hosts are
   per-user, so `DT_ENVIRONMENT` / the Managed config ship placeholders. Set
   yours by running from a local clone and editing the spec
   (`sbx run --kit ./kits/<target>`) or, for SaaS, `export DT_ENVIRONMENT=...`
   inside the sandbox.

## Tokens & scopes

- **SaaS (`remote`, `local`)** use a **platform token** (`dt0s16.…`), created
  under *Account Management → Identity & access management → Platform tokens*.
  A read-only observability set: `app-engine:apps:run`, `storage:buckets:read`,
  `storage:logs:read`, `storage:metrics:read`, `storage:events:read`,
  `storage:entities:read`, `storage:spans:read`, `storage:bizevents:read`,
  `storage:system:read`, `storage:security.events:read`. Add
  `davis-copilot:*:execute` for Davis CoPilot and the various `:write`/`send`
  scopes only if you want the agent to create notebooks, send events, etc.
- **Managed** uses a classic **API token** with scopes like `problems.read`,
  `entities.read`, `securityProblems.read`, `events.read`, `logs.read`,
  `metrics.read`, `DataExport`. Managed scopes differ from SaaS platform tokens.

See each target's page for the exact `spec.yaml`, run command, and setup steps.
