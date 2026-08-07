# Local MCP (Dynatrace SaaS, self-hosted server) — DEPRECATED

Installs the Dynatrace MCP server (`@dynatrace-oss/dynatrace-mcp-server`) inside
the sandbox and wires it to your SaaS environment. Same SaaS target and same
credential model as [remote](./remote.md) - the only difference is that the MCP
server runs *in the sandbox* instead of being hosted by Dynatrace.

> ⚠️ **Deprecated.** The upstream self-hosted server
> ([github.com/dynatrace-oss/dynatrace-mcp](https://github.com/dynatrace-oss/dynatrace-mcp))
> is deprecated: `2.1.2` was the **final release** and no further updates will be
> made. Dynatrace directs users to the hosted, **production-supported**
> [Remote MCP server](https://www.dynatrace.com/hub/detail/dynatrace-mcp-server)
> (the [remote](./remote.md) kit, the default here). Use `remote` unless you
> specifically need a self-hosted stdio server pinned to `2.1.2`; this kit is
> kept only for that case. See Dynatrace's
> [migration guide](https://github.com/dynatrace-oss/dynatrace-mcp/blob/main/docs/remote-mcp-migration.md).

| | |
|---|---|
| MCP server | `mcp-server-dynatrace` in the sandbox (pinned `2.1.2`) |
| Dynatrace | SaaS (`*.apps.dynatrace.com`) |
| Environment URL | you set it (`DT_ENVIRONMENT`) |
| Credential | platform token via `sbx secret set-custom` |

## 1. Create a platform token

Same as remote - a `dt0s16....` platform token with the read-only observability
scopes (see [providers/README.md](./README.md#tokens--scopes)).

## 2. Store the token

The `--env DT_PLATFORM_TOKEN` is important here: the self-hosted MCP server reads
its token from that env var, and `set-custom` sets it to the proxy-swapped
placeholder.

```bash
sbx secret set-custom --host '*.apps.dynatrace.com' --env DT_PLATFORM_TOKEN --value "$DT_TOKEN"
```

## 3. Set your environment URL

Edit `kits/local/spec.yaml` (`DT_ENVIRONMENT` and the `mcp.json` initFile) and
run from the clone, or `export DT_ENVIRONMENT=https://<env>.apps.dynatrace.com`
inside the sandbox. Use the Gen3 **apps** URL, not `*.live.dynatrace.com`.

## Run

```bash
sbx secret set-custom --host '*.apps.dynatrace.com' --env DT_PLATFORM_TOKEN --value "$DT_TOKEN"
sbx run --kit docker.io/ajeetraina777/sbx-dynatrace-kits:local claude
# or from an edited clone:
sbx run --kit ./kits/local claude
```

## What the kit contains

- Installs the pinned `@dynatrace-oss/dynatrace-mcp-server@2.1.2` (bin
  `mcp-server-dynatrace`) and registers it with the Claude agent at startup.
- `DT_MCP_TOKEN_STORAGE=file` so it runs headless (no OS keychain / browser
  login), and `DT_MCP_DISABLE_TELEMETRY=true` to keep egress tight.
- Same proxy-injected `Authorization: Bearer` wiring as remote - the token is a
  placeholder in the sandbox and swapped on the wire for `*.apps.dynatrace.com`.

## Verify (inside the sandbox)

The binary is installed and the server is registered:

```console
!command -v mcp-server-dynatrace
!claude mcp list
```

End-to-end, through the Grail DQL API:

```console
!python3 ~/runbooks/run_dql.py
!python3 ~/runbooks/dynatrace_report.py
```
