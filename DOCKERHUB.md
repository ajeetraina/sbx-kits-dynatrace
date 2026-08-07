# Dynatrace kit for Docker Sandboxes

A standalone [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) kit
(`kind: mixin`) that gives any sandbox agent access to
[Dynatrace](https://www.dynatrace.com/) - problems, security vulnerabilities,
entities, logs, and DQL queries against Grail - through a Dynatrace MCP server,
plus `requests`-based runbooks. This image ships in two target flavors, one per
tag.

Source and full docs: https://github.com/ajeetraina/sbx-kits-dynatrace

## Image tags

| Tag | MCP server | Dynatrace | Credential |
|-----|------------|-----------|------------|
| `latest`, `remote` | Hosted by Dynatrace (Remote MCP) | SaaS (`*.apps.dynatrace.com`) | platform token via `sbx secret set-custom` |
| `managed` | Self-hosted (Managed build) | Dynatrace Managed cluster | API token via `sbx secret set-custom` |

`remote` is the default because it needs no install and is Dynatrace's
recommended path for local-dev clients: the MCP server is hosted, and the
sandbox reaches it over `*.apps.dynatrace.com` with the token injected on the
wire. `managed` targets a self-hosted Dynatrace Managed cluster instead.

## Quick start

Remote default. Store a platform token once (keyed on the apps host), set your
environment URL (see the repo's providers/remote.md), then launch:

    sbx secret set-custom --host '*.apps.dynatrace.com' --env DT_PLATFORM_TOKEN --value "$DT_TOKEN"
    sbx run --kit docker.io/ajeetraina777/sbx-dynatrace-kits:latest claude

Dynatrace Managed (edit kits/managed/spec.yaml with your cluster host first):

    sbx secret set-custom --host 'managed.example.com' --env DT_API_TOKEN --value "$DT_TOKEN"
    sbx run --kit ./kits/managed claude

No tag holds a token. The sbx proxy injects it from the stored secret, so the
token never enters the sandbox. `sbx run` has no `-e` flag by design.

## How it works

Each kit wires up the Dynatrace MCP server for its target, sets `DT_ENVIRONMENT`,
writes a portable MCP definition to `~/.dynatrace/mcp.json`, and (best-effort)
registers the server with the Claude agent. Dynatrace traffic is routed through
the sbx proxy, which attaches the stored token (`Authorization: Bearer` for SaaS
platform tokens, `Api-Token` for Managed) on the wire. It also ships runbooks
(`~/runbooks/run_dql.py`, `dynatrace_report.py`, `managed_report.py`) that query
Dynatrace directly.

Per-target setup, validation, and the raw `spec.yaml` for each kit live on
GitHub: https://github.com/ajeetraina/sbx-kits-dynatrace/tree/main/providers
