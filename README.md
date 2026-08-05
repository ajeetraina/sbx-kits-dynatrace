# sbx kits for Dynatrace

A standalone [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) kit
(`kind: mixin`) that gives any sandbox agent hands-on access to
[Dynatrace](https://www.dynatrace.com/) - problems, security vulnerabilities,
entities, logs, and DQL queries against Grail - through the official
[Dynatrace MCP server](https://github.com/dynatrace-oss/dynatrace-mcp), plus a
few `requests`-based runbooks for scripting.

The **hosted Remote MCP server** for Dynatrace SaaS is the zero-install default.
The target is swappable to a self-hosted MCP server or to Dynatrace Managed. See
[providers/](./providers/) for copy-paste config.

## What the kit does

Layered onto an agent, the mixin does four observable things:

1. Wires up the Dynatrace MCP server for the chosen target - the **hosted Remote
   MCP** (default, no install), a **self-hosted** stdio server
   (`@dynatrace-oss/dynatrace-mcp-server`), or the **Managed** server
   (`@dynatrace-oss/dynatrace-managed-mcp-server`).
2. Installs the `requests` library and ships runbooks under `~/runbooks/` that
   query Dynatrace directly (DQL against Grail for SaaS; Environment API v2 for
   Managed).
3. Sets `DT_ENVIRONMENT` and routes Dynatrace traffic through the sbx proxy so
   the token is attached on the wire, and writes a portable MCP definition to
   `~/.dynatrace/mcp.json`.
4. Registers the MCP server with the Claude agent (best-effort) and injects a
   memory note so the agent knows the tooling is there.

**No token lives in the sandbox.** `sbx run` has no `-e` flag: you store the
token once with sbx's secret manager and the proxy injects it into outbound
requests to Dynatrace, so it never enters the microVM, shell history, or `ps`.

## Prerequisites

### 0. Log in to Docker Hub

```console
sbx login
```

### 1. Create a Dynatrace token

- **SaaS** (`remote` / `local` targets): a **platform token** (`dt0s16.…`) under
  *Account Management → Identity & access management → Platform tokens*.
- **Managed** target: a classic **API token** in *Settings → Integration →
  Dynatrace API*.

See [providers/README.md](./providers/README.md#tokens--scopes) for the
recommended read-only scope set.

### 2. Store the token with sbx (never on the command line)

The token is never baked into the kit; the sbx proxy injects it at runtime. The
stored secret is named `dynatrace` (matching `credentials.sources.dynatrace`):

```console
echo "$DT_TOKEN" | sbx secret set -g dynatrace   # -g = all sandboxes
sbx secret ls                                     # confirm a `dynatrace` entry
```

### 3. Launch the sandbox with the kit

Each target is published as its own image tag - pick the one matching your setup.
`DT_ENVIRONMENT` (your `https://<env>.apps.dynatrace.com` URL) is the one value
the kit can't know for you: edit it in a local clone or `export` it in-sandbox
(see each provider page).

```console
# Dynatrace SaaS via the hosted Remote MCP (default, recommended) - :latest == :remote
sbx run --kit docker.io/ajeetraina777/sbx-dynatrace-kits:latest claude

# Dynatrace SaaS via a self-hosted MCP server in the sandbox
sbx run --kit docker.io/ajeetraina777/sbx-dynatrace-kits:local claude

# Dynatrace Managed (self-hosted cluster) - edit kits/managed/spec.yaml first
sbx run --kit ./kits/managed claude
```

Or straight from this repo over git (uses the default remote target):

```console
sbx run --kit "git+https://github.com/ajeetraina/sbx-kits-dynatrace.git" claude
```

Or from a local clone (the default kit lives at the repo root):

```console
git clone https://github.com/ajeetraina/sbx-kits-dynatrace.git
sbx run --kit ./sbx-kits-dynatrace/ claude
```

#### Choosing the agent

The trailing argument (`claude` above) is the **coding agent** that runs inside
the sandbox - a separate axis from the target tag. The tag (`:remote`, `:local`,
`:managed`) decides which Dynatrace the tooling points at; the agent decides
which assistant you interact with. `sbx run --help` lists them:

```
claude, claude-bedrock, codex, copilot, cursor, docker-agent, droid, gemini, kiro, opencode, shell
```

So you can swap `claude` for any of these, e.g. Codex against Dynatrace SaaS:

```console
sbx run --kit docker.io/ajeetraina777/sbx-dynatrace-kits:latest codex
```

Arguments meant for the agent itself go after a `--` separator, e.g.
`sbx run --kit ...:latest codex -- --help`.

### 4. Confirm the kit installed correctly

Inside the agent session, use `!` shell escapes to prove the mixin is really
inside.

**4a. The MCP server is registered with the agent:**

```console
!claude mcp list
```

Expect a `dynatrace` entry. For the `local`/`managed` targets the binary is also
on PATH: `!command -v mcp-server-dynatrace`.

**4b. The mixin's env is present** (a fingerprint that the kit wired things up):

```console
!env | grep -E 'DT_ENVIRONMENT|DT_PLATFORM_TOKEN'
```

`DT_PLATFORM_TOKEN` reads `proxy-managed` - that's the sentinel; the real token
lives only on the host and is injected on the wire.

**4c. The portable MCP definition the kit wrote exists:**

```console
!cat /home/agent/.dynatrace/mcp.json
```

**4d. End-to-end functional proof** - reach Dynatrace and run a live DQL query
through the Grail query API. This exercises `requests`, the env vars, the
proxy-injected token, and the connection to Dynatrace, so if you only run one
check, run this one (SaaS targets):

```console
!python3 ~/runbooks/run_dql.py
```

Expect recent problems printed as records. For Managed, run
`!python3 ~/runbooks/managed_report.py`.

### 5. Use the MCP server from the agent

On the Claude agent the server is registered automatically. Then just ask, e.g.
*"list the open problems in Dynatrace"*, *"any critical vulnerabilities?"*, or
*"run the DQL `fetch logs | limit 5` and summarize"* - it drives the Dynatrace
MCP tools (`list_problems`, `list_vulnerabilities`, `execute_dql`,
`find_entity_by_name`, Davis CoPilot, …). For other agents, import
`~/.dynatrace/mcp.json`.

### 6. Try a runbook

The kit ships runnable demos under `~/runbooks/`. They are plain files under
[`files/home/runbooks/`](./files/home/runbooks/) (the
[sbx-kits-contrib][contrib] `files/home/` convention - everything under it is
mirrored into `/home/agent/`), **not** hard-coded into `spec.yaml`:

```console
!python3 ~/runbooks/run_dql.py 'fetch dt.davis.problems | limit 10'
!python3 ~/runbooks/dynatrace_report.py
```

To add a runbook, drop a `*.py` in `files/home/runbooks/` - it ships
automatically, no `spec.yaml` change.

[contrib]: https://github.com/docker/sbx-kits-contrib

## Switching the Dynatrace target

| Target | MCP server | Dynatrace | Credential | Doc |
|---|---|---|---|---|
| remote (default) | Hosted by Dynatrace | SaaS `*.apps.dynatrace.com` | platform token | [providers/remote.md](./providers/remote.md) |
| local | Self-hosted in sandbox | SaaS `*.apps.dynatrace.com` | platform token | [providers/local.md](./providers/local.md) |
| managed | Self-hosted (Managed build) | Dynatrace Managed cluster | API token | [providers/managed.md](./providers/managed.md) |

Each page has the exact `spec.yaml`, run command, and setup notes. Overview:
[providers/README.md](./providers/README.md).

## Troubleshooting

**`mount policy denied: /Users/<you>`** when running `sbx run --kit docker.io/..`:
the sbx runtime refuses to mount your home directory into the sandbox. Run
`sbx run` from any directory other than your home directory.

**`run_dql.py` fails with `DT_ENVIRONMENT is not set`:** set it to your Gen3
apps URL - `export DT_ENVIRONMENT=https://<env>.apps.dynatrace.com` (not the
classic `*.live.dynatrace.com`), or edit the spec in a clone.

**`401`/`403` from Dynatrace:** confirm the token is stored (`sbx secret ls`
shows a `dynatrace` entry) and that it carries the required scopes
(`storage:*:read` for SaaS DQL; `problems.read`/`DataExport` for Managed). See
[providers/README.md](./providers/README.md#tokens--scopes).

**MCP `list` doesn't show `dynatrace` on the remote target:** the startup
registration is skipped while `DT_ENVIRONMENT` is still the placeholder. Set it,
then re-run the `claude mcp add --transport http …` command from
[providers/remote.md](./providers/remote.md#3-set-your-environment-url).

## License

[Apache 2.0](./LICENSE).
