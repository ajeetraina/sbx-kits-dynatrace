# sbx kits for Dynatrace

A standalone [Docker Sandboxes](https://docs.docker.com/ai/sandboxes/) kit
(`kind: mixin`) that gives any sandbox agent hands-on access to
[Dynatrace](https://www.dynatrace.com/) - problems, security vulnerabilities,
entities, logs, and DQL queries against Grail - through Dynatrace's hosted
**Remote MCP server**, plus a few `requests`-based runbooks for scripting.

The **hosted Remote MCP server** for Dynatrace SaaS is the zero-install path this
kit wires up. See [providers/](./providers/) for copy-paste config.

## Quickstart

```bash
# 1. Sign in to Docker Hub
sbx login

# 2. Store your platform token on the host (once) — it never enters the sandbox
sbx secret set-custom --host '*.apps.dynatrace.com' --env DT_PLATFORM_TOKEN --value 'dt0s16....'

# 3. Launch the kit — run from a repo clone, NOT your home directory
git clone https://github.com/ajeetraina/sbx-kits-dynatrace.git
cd sbx-kits-dynatrace
sbx run --kit ./kits/remote claude

# 4. Inside the sandbox: point at your environment and prove it end-to-end
export DT_ENVIRONMENT=https://<your-env>.apps.dynatrace.com
python3 ~/runbooks/run_dql.py          # expect records or "(no records)", not a 401
python3 ~/runbooks/dynatrace_report.py # problems, vulnerabilities, hosts

# 5. Or just ask the agent: "list the open problems in Dynatrace"
```

`env | grep DT_PLATFORM_TOKEN` inside the sandbox shows an `sbx-cs-…` placeholder,
never your real `dt0s16.` token. Full walkthrough is below.

## What the kit does

Layered onto an agent, the mixin does four observable things:

1. Wires up the Dynatrace **hosted Remote MCP** server (no install) for your SaaS
   environment.
2. Installs the `requests` library and ships runbooks under `~/runbooks/` that
   query Dynatrace directly (DQL against Grail).
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

A **platform token** (`dt0s16....`) under *Account Management -> Identity &
access management -> Platform tokens*. It needs the gateway scopes
`mcp-gateway:servers:invoke` and `mcp-gateway:servers:read` plus read-only
`storage:*:read` scopes.

See [providers/README.md](./providers/README.md#tokens--scopes) for the
recommended read-only scope set.

### 2. Store the token with sbx (never on the command line)

The token is never baked into the kit; you store it once on the host with
`sbx secret set-custom` (custom because Dynatrace is not a built-in sbx service),
keyed on the Dynatrace host and an env var. The sbx proxy then swaps the
placeholder for the real token on outbound requests, so it never enters the
sandbox. Secrets are global by default:

```console
# Platform token, keyed on the apps host
sbx secret set-custom --host '*.apps.dynatrace.com' --env DT_PLATFORM_TOKEN --value "$DT_TOKEN"

sbx secret ls   # confirm the secret is stored
```

**Self-managed sbx? Allow Dynatrace egress once.** If you are *not* under
centralized AI governance, permit the kit's hosts so sandbox requests are not
denied by the network policy (with org-managed governance an admin allows these
for you - a local allow cannot widen egress):

```console
sbx policy init balanced   # one-time, only if you have never initialized a policy
sbx policy allow network "*.apps.dynatrace.com,pypi.org,files.pythonhosted.org"
```

`sbx policy log <sandbox>` shows any host that was blocked, so you can allow
exactly that one.

### 3. Launch the sandbox with the kit

`DT_ENVIRONMENT` (your `https://<env>.apps.dynatrace.com` URL) is the one value
the kit can't know for you: edit it in a local clone or `export` it in-sandbox
(see [providers/remote.md](./providers/remote.md)).

```console
# Dynatrace SaaS via the hosted Remote MCP - :latest == :remote
sbx run --kit docker.io/ajeetraina777/sbx-dynatrace-kits:latest claude
```

Or straight from this repo over git:

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
the sandbox - a separate axis from the kit. The kit decides which Dynatrace the
tooling points at; the agent decides which assistant you interact with.
`sbx run --help` lists them:

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

Expect a `dynatrace` entry.

**4b. The mixin's env is present** (a fingerprint that the kit wired things up):

```console
!env | grep -E 'DT_ENVIRONMENT|DT_PLATFORM_TOKEN'
```

`DT_PLATFORM_TOKEN` holds a placeholder (set by `sbx secret set-custom --env
DT_PLATFORM_TOKEN`); the real token lives only on the host and is injected on
the wire.

**4c. The portable MCP definition the kit wrote exists:**

```console
!cat /home/agent/.dynatrace/mcp.json
```

**4d. End-to-end functional proof** - reach Dynatrace and run a live DQL query
through the Grail query API. This exercises `requests`, the env vars, the
proxy-injected token, and the connection to Dynatrace, so if you only run one
check, run this one:

```console
!python3 ~/runbooks/run_dql.py
```

Expect recent problems printed as records.

### 5. Use the MCP server from the agent

On the Claude agent the server is registered automatically. Then just ask, e.g.
*"list the open problems in Dynatrace"*, *"any critical vulnerabilities?"*, or
*"run the DQL `fetch logs | limit 5` and summarize"* - it drives the Dynatrace
MCP tools (`list_problems`, `list_vulnerabilities`, `execute_dql`,
`find_entity_by_name`, Davis CoPilot, ...). For other agents, import
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

## Setup reference

[providers/remote.md](./providers/remote.md) has the exact `spec.yaml`, run
command, token scopes, and setup notes. Overview:
[providers/README.md](./providers/README.md).

## Troubleshooting

**`mount policy denied: /Users/<you>`** when running `sbx run --kit docker.io/..`:
the sbx runtime refuses to mount your home directory into the sandbox. Run
`sbx run` from any directory other than your home directory.

**Network policy denied a Dynatrace request** (egress blocked / connection
refused reaching `*.apps.dynatrace.com`): if you self-manage sbx policy and have
no centralized governance, allow the kit's hosts once (global scope):

```console
sbx policy allow network "*.apps.dynatrace.com,pypi.org,files.pythonhosted.org"
```

Under org-managed governance a local allow cannot widen egress - an admin must
add the allow. `sbx policy log <sandbox>` names the exact blocked host.

**`run_dql.py` fails with `DT_ENVIRONMENT is not set`:** set it to your Gen3
apps URL - `export DT_ENVIRONMENT=https://<env>.apps.dynatrace.com` (not the
classic `*.live.dynatrace.com`), or edit the spec in a clone.

**`401`/`403` from Dynatrace:** confirm the secret is stored (`sbx secret ls`)
and keyed on `*.apps.dynatrace.com`, and that the token carries the required
scopes - `mcp-gateway:servers:invoke` and `mcp-gateway:servers:read` for the MCP
gateway, plus `storage:*:read` for DQL. A token missing the gateway scopes fails
MCP calls with 403 while the DQL runbooks still work. See
[providers/README.md](./providers/README.md#tokens--scopes).

**MCP `list` doesn't show `dynatrace`:** the startup
registration is skipped while `DT_ENVIRONMENT` is still the placeholder. Set it,
then re-run the `claude mcp add --transport http ...` command from
[providers/remote.md](./providers/remote.md#3-set-your-environment-url).

