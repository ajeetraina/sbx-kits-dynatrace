#!/usr/bin/env python3
"""Print open problems from a self-hosted Dynatrace Managed cluster.

Ships with the sbx-kits-dynatrace kit (managed target). Reads the cluster
connection from DT_ENVIRONMENT_CONFIGS (the same JSON the Managed MCP server
uses) and calls the Managed Environment API v2. The apiToken in that config is a
proxy-managed sentinel; the sbx proxy swaps in the real API token
(`Authorization: Api-Token …`) on the wire.

Usage (inside the sandbox):
    python3 ~/runbooks/managed_report.py
"""
import json
import os
import sys

import requests


def _load_config():
    raw = os.environ.get("DT_ENVIRONMENT_CONFIGS", "").strip()
    if not raw:
        raise RuntimeError("DT_ENVIRONMENT_CONFIGS is not set (managed kit only).")
    configs = json.loads(raw)
    if not configs:
        raise RuntimeError("DT_ENVIRONMENT_CONFIGS is empty.")
    return configs[0]


def _api_base(cfg):
    endpoint = cfg.get("apiEndpointUrl", "").rstrip("/")
    env_id = cfg.get("environmentId", "")
    if not endpoint or not env_id or "example.com" in endpoint or "YOUR-ENV" in env_id:
        raise RuntimeError(
            "Edit DT_ENVIRONMENT_CONFIGS in kits/managed/spec.yaml with your "
            "cluster host and environment id before running this."
        )
    return f"{endpoint}/{env_id}"


def main():
    cfg = _load_config()
    base = _api_base(cfg)
    token = cfg.get("apiToken", "proxy-managed")  # sentinel; proxy rewrites it
    headers = {"Authorization": f"Api-Token {token}", "Accept": "application/json"}

    print(f"Dynatrace Managed: {base}  (alias: {cfg.get('alias', '-')})\n")

    resp = requests.get(
        f"{base}/api/v2/problems",
        headers=headers,
        params={"pageSize": 10, "problemSelector": 'status("open")'},
        timeout=30,
    )
    if resp.status_code >= 400:
        hint = ""
        if resp.status_code in (401, 403):
            hint = " — is a token stored (`sbx secret ls` -> `dynatrace`) with problems.read / DataExport scope?"
        raise RuntimeError(f"{resp.url} -> {resp.status_code}: {resp.text[:400]}{hint}")

    problems = resp.json().get("problems", [])
    print("== Open problems ==")
    if not problems:
        print("  (none)")
        return
    for p in problems:
        title = p.get("title", "(untitled)")
        severity = p.get("severityLevel", "?")
        pid = p.get("displayId", p.get("problemId", ""))
        print(f"  - [{severity}] {title}  ({pid})")


if __name__ == "__main__":
    try:
        main()
    except Exception as exc:  # noqa: BLE001 - friendly hint, not a traceback
        print(f"Could not reach Dynatrace Managed: {exc}", file=sys.stderr)
        sys.exit(1)
