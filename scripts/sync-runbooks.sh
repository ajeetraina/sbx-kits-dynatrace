#!/usr/bin/env bash
# Sync the shared runbook files into each per-target kit directory.
#
# sbx packages a kit from a single directory: `spec.yaml` plus a sibling
# `files/` tree. It refuses symlinks that escape the kit directory, so each
# kits/<target>/ must carry its OWN real copy of the runbooks for
# `sbx run --kit ./kits/<target>` to ship them.
#
# The source of truth is the repo-root files/ tree. Run this after editing any
# runbook so the per-target copies stay in sync. CI can run it with --check to
# fail if a copy has drifted.
set -euo pipefail

repo_root="$(cd "$(dirname "$0")/.." && pwd)"
src="$repo_root/files"
targets=(remote managed)

check_only=false
[ "${1:-}" = "--check" ] && check_only=true

status=0
for t in "${targets[@]}"; do
  dst="$repo_root/kits/$t/files"
  if $check_only; then
    if ! diff -r --exclude=__pycache__ --exclude='*.pyc' "$src" "$dst" >/dev/null 2>&1; then
      echo "DRIFT: kits/$t/files differs from files/ (run scripts/sync-runbooks.sh)" >&2
      status=1
    fi
  else
    rm -rf "$dst"
    mkdir -p "$dst"
    # copy everything except Python bytecode caches
    (cd "$src" && find . -type d -name __pycache__ -prune -o -type f ! -name '*.pyc' -print) \
      | while read -r f; do
          mkdir -p "$dst/$(dirname "$f")"
          cp "$src/$f" "$dst/$f"
        done
    echo "synced files/ -> kits/$t/files"
  fi
done
exit $status
