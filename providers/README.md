# Dynatrace target for the kit

The kit gives your agent hands-on access to Dynatrace - problems, security
vulnerabilities, entities, logs, and DQL queries against Grail - through
Dynatrace's hosted **Remote MCP server**, plus a few `requests`-based runbooks
for scripting.

## Target

| Target | MCP server | Dynatrace | Credential | How it reaches Dynatrace |
|---|---|---|---|---|
| [remote](./remote.md) (default) | **Hosted** by Dynatrace (no install) | SaaS (`*.apps.dynatrace.com`) | platform token via `sbx secret set-custom` | proxy injects `Authorization: Bearer` on the wire |

## Why the hosted Remote MCP server

Dynatrace's guidance for local-dev clients (VS Code, Claude Code, Cursor, ...) is
to use the hosted **Remote MCP server**: nothing is installed in the sandbox, it
is always up to date, and it needs no infrastructure. It is Dynatrace's
production-supported server and targets Dynatrace **SaaS** (the Gen3
`*.apps.dynatrace.com` platform with Grail/DQL).

## Notes

1. **The kit never holds a token.** `sbx run` has no `-e` flag by design. You
   store the token once with `sbx secret set-custom` (Dynatrace isn't a built-in
   sbx service, so this is the "custom" variant), keyed on the Dynatrace host and
   an env var. The sbx proxy then swaps the placeholder for the real token on
   outbound requests, so it never enters the sandbox, shell history, or `ps`.
   Secrets are global by default (scope one with `--sandbox`).

   ```bash
   sbx secret set-custom --host '*.apps.dynatrace.com' --env DT_PLATFORM_TOKEN --value "$DT_TOKEN"
   sbx secret ls   # confirm the secret is stored
   ```

2. **The environment URL is the one value the kit cannot know for you.** SaaS
   URLs (`https://<env>.apps.dynatrace.com`) are per-user, so `DT_ENVIRONMENT`
   ships a placeholder. Set yours by running from a local clone and editing the
   spec (`sbx run --kit ./kits/remote`) or `export DT_ENVIRONMENT=...` inside the
   sandbox.

3. **Network egress must be allowed.** The kit declares its hosts in the spec,
   but if you self-manage sbx policy without centralized AI governance, allow
   the kit's egress once so sandbox requests aren't denied:

   ```bash
   sbx policy allow network "*.apps.dynatrace.com,pypi.org,files.pythonhosted.org"
   ```

   Under org-managed governance a local allow cannot widen egress - an admin
   adds the rule. `sbx policy log <sandbox>` names any host that was blocked.

## Tokens & scopes

- A **platform token** (`dt0s16....`) is created
  under *Account Management -> Identity & access management -> Platform tokens*.
  The hosted Remote MCP gateway itself requires two scopes -
  `mcp-gateway:servers:invoke` and `mcp-gateway:servers:read` - **without them the
  MCP tool calls return 403** even though the DQL runbooks (which hit Grail
  directly) still work. Add a read-only observability set for the tools to reach
  data: `app-engine:apps:run`, `storage:buckets:read`, `storage:logs:read`,
  `storage:metrics:read`, `storage:events:read`, `storage:entities:read`,
  `storage:spans:read`, `storage:bizevents:read`, `storage:system:read`,
  `storage:security.events:read`. Add `davis-copilot:*:execute` for Davis CoPilot
  and the various `:write`/`send` scopes only if you want the agent to create
  notebooks, send events, etc.

See [remote.md](./remote.md) for the exact `spec.yaml`, run command, and setup
steps.
