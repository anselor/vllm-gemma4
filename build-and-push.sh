#!/usr/bin/env bash
# Build the patched vLLM image(s) and push them to a container registry.
#
# The patched parser (PR #42006) is committed alongside this script as
# gemma4_tool_parser.py, so this directory is a self-contained build context --
# the build host needs nothing but this directory + docker.
#
# This builds one image per entry in BASES (different base nightlies) and tags
# each with a date-based, human-readable version plus the base-digest short for
# provenance. The entry in LATEST_DATE additionally moves the `pr<PR>-latest`
# and `latest` tags.
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

# Base nightlies to build. Each entry: "YYYYMMDD=sha256:<digest>".
# Override the whole list via the BASES env var (space/newline separated, same
# "date=digest" format), e.g. BASES="20260610=sha256:abc..." ./build-and-push.sh
if [[ -n "${BASES:-}" ]]; then
  read -r -a BASES <<<"${BASES}"
else
  BASES=(
    # nightly-9c7f7741 — conservative: TP2/MTP/vision fixes #43909 #43982 #43798 #44232
    "20260607=sha256:f1900e879be14dff1c0b6a43a28cb63d5cb384f206eeab47f735ff440e11694c"
    # nightly-2c9c07c8 — also includes #42175 (Gemma4 FA4 all-layers + mm_prefix)
    "20260610=sha256:03768d9400bf490934e5dce2e9d8ddd9e004a5054939e14641188d8a9b69db8e"
  )
fi

# Which base DATE moves the floating `pr<PR>-latest` / `latest` tags.
LATEST_DATE="${LATEST_DATE:-20260610}"

# Provenance of the baked-in parser (for the image label only). Keep PR_SHA in
# sync with gemma4_tool_parser.py -- re-extract both together (see README).
PR_REF="${PR_REF:-42006}"
PR_SHA="${PR_SHA:-fe026ca4547295936c8bac39b4e0ed8885d07ea7}"

# Source repo URL, recorded as an image label so the registry can link the
# package to it. Optional. e.g. https://github.com/<owner>/gemma4-vllm
SOURCE_URL="${SOURCE_URL:-}"

# Set PUSH=0 to build and tag locally without pushing (e.g. to verify a build).
PUSH="${PUSH:-1}"
# -----------------------------------------------------------------------------

if [[ ! -f ./gemma4_tool_parser.py ]]; then
  echo "ERROR: gemma4_tool_parser.py missing from build context." >&2
  echo "Regenerate from the PR with:" >&2
  echo "  git -C /path/to/vllm fetch origin pull/${PR_REF}/head:pr-${PR_REF}" >&2
  echo "  git -C /path/to/vllm show pr-${PR_REF}:vllm/tool_parsers/gemma4_tool_parser.py > ./gemma4_tool_parser.py" >&2
  exit 1
fi

for entry in "${BASES[@]}"; do
  BASE_DATE="${entry%%=*}"
  BASE_DIGEST="${entry#*=}"
  if [[ "${BASE_DATE}" == "${entry}" || -z "${BASE_DIGEST}" ]]; then
    echo "ERROR: malformed BASES entry '${entry}' (expected YYYYMMDD=sha256:...)" >&2
    exit 1
  fi
  DIGEST_SHORT="${BASE_DIGEST#sha256:}"; DIGEST_SHORT="${DIGEST_SHORT:0:12}"

  # Immutable: date-based version + base-digest short (provenance).
  TAGS=("pr${PR_REF}-${BASE_DATE}" "pr${PR_REF}-${DIGEST_SHORT}")
  # The designated base also moves the floating tags.
  if [[ "${BASE_DATE}" == "${LATEST_DATE}" ]]; then
    TAGS+=("pr${PR_REF}-latest" "latest")
  fi

  tag_args=()
  for t in "${TAGS[@]}"; do tag_args+=(-t "${REGISTRY}:${t}"); done

  echo
  echo "[build] base=${BASE_DIGEST} (date=${BASE_DATE})"
  echo "[build] parser=PR#${PR_REF}@${PR_SHA:0:12}"
  echo "[build] tags: ${TAGS[*]}"
  DOCKER_BUILDKIT=1 docker build \
    --build-arg "BASE_DIGEST=${BASE_DIGEST}" \
    --build-arg "BASE_DATE=${BASE_DATE}" \
    --build-arg "PR_REF=${PR_REF}" \
    --build-arg "PR_SHA=${PR_SHA}" \
    --build-arg "SOURCE_URL=${SOURCE_URL}" \
    "${tag_args[@]}" .

  if [[ "${PUSH}" == "1" ]]; then
    for t in "${TAGS[@]}"; do
      echo "[push] ${REGISTRY}:${t}"
      docker push "${REGISTRY}:${t}"
    done
  else
    echo "[skip-push] PUSH=0 -- built and tagged locally only"
  fi
done

echo
if [[ "${PUSH}" == "1" ]]; then
  echo "Done. Latest (date=${LATEST_DATE}) is at:"
  echo "  ${REGISTRY}:pr${PR_REF}-latest"
else
  echo "Done (no push). Inspect with: docker images ${REGISTRY}"
fi
