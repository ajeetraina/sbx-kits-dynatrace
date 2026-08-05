# Remote MCP (Dynatrace SaaS, default, recommended)

Points the agent at the **hosted** Dynatrace Remote MCP server for your SaaS
environment. Nothing is installed in the sandbox: the MCP server is a URL under
`https://<env>.apps.dynatrace.com/platform-reserved/mcp-gateway/...`, and the
platform token is injected by the sbx proxy as a `Bearer` header on the wire, so
it never enters the sandbox.

| | |
|---|---|
| MCP server | Hosted by Dynatrace (Streamable HTTP) |
| Dynatrace | SaaS (`*.apps.dynatrace.com`) |
| Environment URL | you set it (`DT_ENVIRONMENT`) |
| Credential | platform token via `sbx secret set -g dynatrace` |

## 1. Create a platform token

In Dynatrace: *Account Management → Identity & access management → Platform
tokens → Generate new token*. Give it the read-only observability scopes (see
[providers/README.md](./README.md#tokens--scopes)). Copy the `dt0s16.…` value.

## 2. Store the token as a secret (never on the command line)

```bash
echo "$DT_TOKEN" | sbx secret set -g dynatrace     # -g = all sandboxes
# or run `sbx secret set -g dynatrace` for an interactive prompt
sbx secret ls                                       # confirm a `dynatrace` entry
```

## 3. Set your environment URL

The kit can't know your environment id, so it ships a placeholder
`DT_ENVIRONMENT`. Set yours one of two ways:

- Run from a local clone and edit `kits/remote/spec.yaml` (`DT_ENVIRONMENT` and
  the `mcp.json` initFile URL), then `sbx run --kit ./kits/remote claude`.
- Or, inside the sandbox, `export DT_ENVIRONMENT=https://<env>.apps.dynatrace.com`
  and re-register the MCP server:
  `claude mcp add --transport http dynatrace "$DT_ENVIRONMENT/platform-reserved/mcp-gateway/v0.1/servers/dynatrace-mcp/mcp" --header "Authorization: Bearer proxy-managed"`.

Use the Gen3 **apps** URL (`https://abc12345.apps.dynatrace.com`), not the
classic `*.live.dynatrace.com`.

## Run

```bash
echo "$DT_TOKEN" | sbx secret set -g dynatrace
sbx run --kit docker.io/ajeetraina777/sbx-dynatrace-kits:latest claude
# or from an edited clone:
sbx run --kit ./kits/remote claude
```

## What the kit contains

- `network.allowedDomains` includes `*.apps.dynatrace.com`.
- `network.serviceDomains` maps `*.apps.dynatrace.com` to the `dynatrace`
  service, and `serviceAuth` sets `Authorization: Bearer %s`, so the proxy
  attaches the token to every SaaS request (MCP + DQL API).
- `credentials.sources.dynatrace` reads the token from the stored secret, and
  `environment.proxyManaged` keeps `DT_PLATFORM_TOKEN` a placeholder that the
  proxy replaces on the wire.
- A startup step registers the Remote MCP URL with the Claude agent (once
  `DT_ENVIRONMENT` is real), and `~/.dynatrace/mcp.json` holds a portable copy.

## Verify (inside the sandbox)

The MCP server is registered:

```console
!claude mcp list
```

End-to-end, through the Grail DQL API (the single most useful check):

```console
!python3 ~/runbooks/run_dql.py
!python3 ~/runbooks/dynatrace_report.py
```

Then just ask the agent, e.g. *"list the open problems in Dynatrace"* or *"run
the DQL `fetch logs | limit 5` and summarize"* — it drives the Dynatrace MCP
tools.
