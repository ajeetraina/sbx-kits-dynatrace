#!/usr/bin/env bash
set -euo pipefail

namespace="${DOCKERHUB_NAMESPACE:-${DOCKER_NAMESPACE:-ajeetraina777}}"
tag="${TAG:-latest}"
repo_root="$(cd "$(dirname "$0")/.." && pwd)"
image="docker.io/$namespace/sbx-dynatrace-kits"

# publish SPEC_DIR IMAGE_TAG README_FILE [FILES_DIR]
# Stages a kit (spec.yaml + README + LICENSE), validates it, and pushes one tag.
# If FILES_DIR is given, its whole tree is staged as the kit's files/ dir - the
# sbx-kits-contrib convention where everything under files/home is mirrored into
# /home/agent/ in the sandbox. That's how the runbooks ship without being
# hard-coded into spec.yaml: drop a *.py in files/home/runbooks/, no spec edit.
#
# The canonical files/ tree lives at the repo root, so `sbx run --kit ./` picks
# it up directly for local testing. Every tag ships the same runbooks since they
# read their target from the env the kit sets up.
publish() {
  local spec_dir="$1" image_tag="$2" readme="$3" files_dir="${4:-}"
  local stage
  stage="$(mktemp -d /tmp/dynatrace-kits-push.XXXXXX)"
  mkdir -p "$stage/dynatrace"
  cp "$spec_dir/spec.yaml" "$stage/dynatrace/spec.yaml"
  cp "$readme" "$stage/dynatrace/README.md"
  cp "$repo_root/LICENSE" "$stage/dynatrace/LICENSE"
  if [ -n "$files_dir" ] && [ -d "$files_dir" ]; then
    cp -R "$files_dir" "$stage/dynatrace/files"
  fi
  sbx kit validate "$stage/dynatrace"
  sbx kit push "$stage/dynatrace" "$image:$image_tag"
  rm -rf "$stage"
  echo "Pushed $image:$image_tag"
}

# Default kit (remote) at the repo root -> :$tag (default :latest), with the
# canonical files/ tree (runbooks).
publish "$repo_root" "$tag" "$repo_root/README.md" "$repo_root/files"

# Per-target kits under kits/ -> :<target> (e.g. :remote).
# Each tag uses its provider doc as the image README. Those docs use repo-relative
# links; fine on GitHub, cosmetic-only on the Hub page.
for dir in "$repo_root"/kits/*/; do
  target="$(basename "$dir")"
  readme="$repo_root/providers/$target.md"
  [ -f "$readme" ] || readme="$repo_root/README.md"
  publish "$dir" "$target" "$readme" "$repo_root/files"
done
