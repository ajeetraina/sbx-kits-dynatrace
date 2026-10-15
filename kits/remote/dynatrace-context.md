## Dynatrace observability tooling (SaaS, Remote MCP)

The official Dynatrace **Remote MCP server** is registered with the agent as
`dynatrace`, pointed at the SaaS environment in `DT_ENVIRONMENT`
(`https://<env>.apps.dynatrace.com`). It is hosted by Dynatrace — nothing is
installed in the sandbox. Through it you can list problems, security
vulnerabilities and exceptions, find entities, run and explain DQL against
Grail, and talk to Davis CoPilot.

No token lives in the sandbox. The platform token is bound on the host as the
`dynatrace` credential (`sbx secret set dynatrace`) and carried in-container
only as a proxy-managed sentinel in `DT_PLATFORM_TOKEN`; the sbx proxy
overwrites the `Authorization` header with the real token on outbound requests
to `*.apps.dynatrace.com`. If MCP calls fail with auth errors, check that
`DT_ENVIRONMENT` is your real `*.apps.dynatrace.com` URL and that the secret is
bound (`sbx secret ls`).

For quick scripting the `requests`-based runbooks in `~/runbooks/` run DQL
directly against the Grail query API — `python3 ~/runbooks/run_dql.py 'fetch
dt.davis.problems | limit 10'` or `python3 ~/runbooks/dynatrace_report.py`.
