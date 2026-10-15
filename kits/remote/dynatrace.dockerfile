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

# The overlay: lands on any shell base.
FROM scratch
COPY --from=build /out /

# Static runtime env. A mixin's ENV merges into the composed image, so these
# reach the agent process and the runbooks (an /etc/profile.d drop would reach
# only login shells). NO_PROXY keeps loopback traffic off the sandbox proxy.
# DT_ENVIRONMENT is not set here: it resolves at create from the `environment`
# kit arg (see the descriptor) so one published kit serves every environment.
ENV NO_PROXY="localhost,127.0.0.1,host.docker.internal" \
    no_proxy="localhost,127.0.0.1,host.docker.internal"
