# Dynatrace Managed (self-hosted cluster)

Installs the Dynatrace Managed MCP server
(`@dynatrace-oss/dynatrace-managed-mcp-server`) and wires it to a self-hosted
Dynatrace **Managed** cluster. Managed has a different API from SaaS and uses a
classic API token (`Authorization: Api-Token …`), which the sbx proxy injects on
the wire.

Because only you know your cluster hostname, this target is meant to be run from
a **local clone you edit** — the sandbox egress allow-list must name your
cluster, and a baked image can't.

| | |
|---|---|
| MCP server | `mcp-server-dynatrace` in the sandbox (managed build, pinned `1.0.1`) |
| Dynatrace | Managed (your cluster host) |
| Cluster URL / env id | you set them (`DT_ENVIRONMENT_CONFIGS`) |
| Credential | API token via `sbx secret set-custom` |

## 1. Create an API token

In your Managed environment: *Settings → Integration → Dynatrace API →
Generate token*, with the read scopes you need — `problems.read`,
`entities.read`, `securityProblems.read`, `events.read`, `logs.read`,
`metrics.read`, `DataExport`.

## 2. Store the token

Key it on your cluster host (the same host you set in the spec below), so the
proxy injects it on requests to that cluster:

```bash
sbx secret set-custom --host 'managed.example.com' --env DT_API_TOKEN --value "$DT_TOKEN"
```

## 3. Point the kit at your cluster

Edit `kits/managed/spec.yaml` and replace `managed.example.com` with your
cluster host in all three places (use the **same** host in the `set-custom`
command above):

- `network.allowedDomains` (so the sandbox may reach it)
- `network.serviceDomains` (so the proxy attaches the token to it)
- `DT_ENVIRONMENT_CONFIGS` — set `apiEndpointUrl`, `dynatraceUrl`,
  `environmentId`, and `alias`; leave `apiToken` as `"inject-me"` (the
  placeholder the proxy replaces). Update the same JSON in the `mcp.json` initFile.

The Managed API base is typically `https://<cluster-host>/e/` with the
environment id appended.

## Run

```bash
sbx secret set-custom --host 'managed.example.com' --env DT_API_TOKEN --value "$DT_TOKEN"
sbx run --kit ./kits/managed claude      # edit the spec first
```

## Verify (inside the sandbox)

```console
!command -v mcp-server-dynatrace
!claude mcp list
!python3 ~/runbooks/managed_report.py
```

Expect the cluster's open problems. If it can't connect, confirm your cluster
host is in `allowedDomains`, the token is stored and keyed on that same host
(`sbx secret ls`), and `DT_ENVIRONMENT_CONFIGS` has your real
`apiEndpointUrl` / `environmentId`.
