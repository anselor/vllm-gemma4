#!/usr/bin/env bash
# Build the patched vLLM image and push it to a container registry.
#
# The patched parser (PR #42006) is committed alongside this script as
# gemma4_tool_parser.py, so this directory is a self-contained build context --
# the build host needs nothing but this directory + docker.
#
# Prereqs:
#   docker login <registry-host>   # e.g. ghcr.io
#
# Usage:
#   REGISTRY=ghcr.io/<owner>/gemma4-vllm ./build-and-push.sh
set -euo pipefail
cd "$(dirname "$0")"

# --- config (override via environment) ---------------------------------------
# Full image path WITHOUT the tag, e.g. ghcr.io/<owner>/gemma4-vllm
REGISTRY="${REGISTRY:?set REGISTRY to your image path without a tag, e.g. ghcr.io/<owner>/gemma4-vllm}"

# Base nightly digest to patch (kept in sync with the Dockerfile default).
BASE_DIGEST="${BASE_DIGEST:-sha256:4cebac8c03f2cd9f5fabe72ac7c2a0b3aaa8450ef8f0e47429425fd1bfb83d42}"

# Provenance of the baked-in parser (for the image label only).
PR_REF="${PR_REF:-42006}"
PR_SHA="${PR_SHA:-795272896d4b444600c759f207ebae36c2e9d80c}"

# Source repo URL, recorded as an image label so the registry can link the
# package to it. Optional. e.g. https://github.com/<owner>/gemma4-vllm
SOURCE_URL="${SOURCE_URL:-}"

# Tags: an immutable one recording which nightly was patched, plus a moving tag.
DIGEST_SHORT="${BASE_DIGEST#sha256:}"; DIGEST_SHORT="${DIGEST_SHORT:0:12}"
TAGS=("pr${PR_REF}-${DIGEST_SHORT}" "pr${PR_REF}-latest")
# -----------------------------------------------------------------------------

if [[ ! -f ./gemma4_tool_parser.py ]]; then
  echo "ERROR: gemma4_tool_parser.py missing from build context." >&2
  echo "Regenerate from the PR with:" >&2
  echo "  git -C /path/to/vllm fetch origin pull/${PR_REF}/head:pr-${PR_REF}" >&2
  echo "  git -C /path/to/vllm show pr-${PR_REF}:vllm/tool_parsers/gemma4_tool_parser.py > ./gemma4_tool_parser.py" >&2
  exit 1
fi

tag_args=()
for t in "${TAGS[@]}"; do tag_args+=(-t "${REGISTRY}:${t}"); done

echo "[build] base=${BASE_DIGEST}"
echo "[build] parser=PR#${PR_REF}@${PR_SHA:0:12}"
echo "[build] ${tag_args[*]}"
DOCKER_BUILDKIT=1 docker build \
  --build-arg "BASE_DIGEST=${BASE_DIGEST}" \
  --build-arg "PR_REF=${PR_REF}" \
  --build-arg "PR_SHA=${PR_SHA}" \
  --build-arg "SOURCE_URL=${SOURCE_URL}" \
  "${tag_args[@]}" .

for t in "${TAGS[@]}"; do
  echo "[push] ${REGISTRY}:${t}"
  docker push "${REGISTRY}:${t}"
done

echo
echo "Done. Run with:"
echo "  ${REGISTRY}:${TAGS[0]}"
