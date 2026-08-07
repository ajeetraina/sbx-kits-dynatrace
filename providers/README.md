# Dynatrace targets for the kit

The kit gives your agent hands-on access to Dynatrace - problems, security
vulnerabilities, entities, logs, and DQL queries against Grail - through a
Dynatrace MCP server, plus a few `requests`-based runbooks for scripting. The
default target uses Dynatrace's hosted **Remote MCP server**; what changes per
target is *which Dynatrace* it points at and *how the MCP server is hosted*.

## Target matrix

| Target | MCP server | Dynatrace | Credential | How it reaches Dynatrace |
|---|---|---|---|---|
| [remote](./remote.md) (default) | **Hosted** by Dynatrace (no install) | SaaS (`*.apps.dynatrace.com`) | platform token via `sbx secret set-custom` | proxy injects `Authorization: Bearer` on the wire |
| [managed](./managed.md) | Self-hosted (`@dynatrace-oss/dynatrace-managed-mcp-server`) | Dynatrace **Managed** (your cluster) | API token via `sbx secret set-custom` | proxy injects `Authorization: Api-Token` on the wire |

## Why `remote` is the default

Dynatrace's guidance for local-dev clients (VS Code, Claude Code, Cursor, ...) is
to use the hosted **Remote MCP server**: nothing is installed in the sandbox, it
is always up to date, and it needs no infrastructure. It is Dynatrace's
production-supported server and the successor to the deprecated self-hosted
server (`@dynatrace-oss/dynatrace-mcp-server`, final release `2.1.2`; a `local`
kit for it was retired). It targets Dynatrace **SaaS** (the Gen3
`*.apps.dynatrace.com` platform with Grail/DQL). Dynatrace **Managed**
(self-hosted clusters) has a different API and its own MCP server - that is the
`managed` kit.

## Notes that apply to every target

1. **The kit never holds a token.** `sbx run` has no `-e` flag by design. You
   store the token once with `sbx secret set-custom` (Dynatrace isn't a built-in
   sbx service, so this is the "custom" variant), keyed on the Dynatrace host and
   an env var. The sbx proxy then swaps the placeholder for the real token on
   outbound requests, so it never enters the sandbox, shell history, or `ps`.
   Secrets are global by default (scope one with `--sandbox`).

   ```bash
   # SaaS (remote)
   sbx secret set-custom --host '*.apps.dynatrace.com' --env DT_PLATFORM_TOKEN --value "$DT_TOKEN"
   # Managed (host must match kits/managed/spec.yaml)
   sbx secret set-custom --host 'managed.example.com' --env DT_API_TOKEN --value "$DT_TOKEN"

   sbx secret ls   # confirm the secret is stored
   ```

2. **The environment URL is the one value the kit cannot know for you.** SaaS
   URLs (`https://<env>.apps.dynatrace.com`) and Managed cluster hosts are
   per-user, so `DT_ENVIRONMENT` / the Managed config ship placeholders. Set
   yours by running from a local clone and editing the spec
   (`sbx run --kit ./kits/<target>`) or, for SaaS, `export DT_ENVIRONMENT=...`
   inside the sandbox.

3. **Network egress must be allowed.** The kit declares its hosts in the spec,
   but if you self-manage sbx policy without centralized AI governance, allow
   the kit's egress once so sandbox requests aren't denied:

   ```bash
   # SaaS (remote)
   sbx policy allow network "*.apps.dynatrace.com,pypi.org,files.pythonhosted.org"
   # Managed (swap in your cluster host; npm is needed for the self-hosted MCP)
   sbx policy allow network "managed.example.com,registry.npmjs.org,pypi.org,files.pythonhosted.org"
   ```

   Under org-managed governance a local allow cannot widen egress - an admin
   adds the rule. `sbx policy log <sandbox>` names any host that was blocked.

## Tokens & scopes

- **SaaS (`remote`)** uses a **platform token** (`dt0s16....`), created
  under *Account Management -> Identity & access management -> Platform tokens*.
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
