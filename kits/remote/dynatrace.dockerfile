# syntax=docker/dockerfile:1

# Dynatrace (SaaS, Remote MCP) — MIXIN overlay.
#
# This kit installs no MCP server: the Dynatrace Remote MCP server is hosted by
# Dynatrace and reached over the network (see network-policy / credential in the
# descriptor). The only content the overlay carries is the `requests`-based DQL
# runbooks, staged under /home/agent/runbooks. `requests` itself is NOT baked in
# — it is installed at create time by the lifecycle install hook, because a
# --user install lands in ~/.local tied to one Python minor version and a mixin
# cannot know the composed base's Python, so it has to run against that base's
# own interpreter.
#
# There is no ENTRYPOINT: a mixin rides on the base workload's launch command.
# Run the agent as usual and talk to the `dynatrace` MCP server, or run the
# runbooks from a shell.

FROM busybox:1 AS build
# Stage the shared DQL runbooks under the agent's home. The chown starts AT
# /home/agent so the overlay ships /home owned by root (0:0) and /home/agent
# owned by the agent (1000:1000) — the two ownership invariants kit-tck
# enforces for an overlay. Numeric ids because `scratch` carries no
# /etc/passwd to resolve a name against.
RUN mkdir -p /out/home/agent/runbooks
COPY files/home/runbooks/ /out/home/agent/runbooks/
RUN rm -rf /out/home/agent/runbooks/__pycache__ \
 && chown -R 1000:1000 /out/home/agent

# The overlay: lands on any shell base. It carries files only — no ENV.
FROM scratch
COPY --from=build /out /

# MIGRATION NOTE: the v2 kit set NO_PROXY / no_proxy in environment.variables.
# They are intentionally NOT set here. A mixin's ENV merges into the composed
# image, and a merged key other than PATH is first-writer-owned: the sbx
# runtime already sets NO_PROXY (to its own loopback + sandbox CIDR), so a
# mixin that sets a different value makes the composition refuse to assemble
# ("env conflict on NO_PROXY"). The runtime's value is the correct one, so the
# mixin leaves it alone.
#
# DT_ENVIRONMENT is likewise not set here: it resolves at create from the
# `environment` kit arg (see the descriptor) so one published kit serves every
# environment.
