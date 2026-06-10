# syntax=docker/dockerfile:1
#
# vLLM nightly with the Gemma4 tool-call parser fix from vllm-project/vllm#42006.
#
# The PR is a pure-Python change (no kernels, no recompile) to a single file,
# vllm/tool_parsers/gemma4_tool_parser.py, so the build replaces that one file
# in the base image.

# Base nightly digest. Override with:
#   --build-arg BASE_DIGEST=sha256:<new digest>
# Default is the 2026-06-10 nightly (nightly-2c9c07c8), which is the one tagged
# `latest` by build-and-push.sh. The 2026-06-07 nightly (nightly-9c7f7741,
# sha256:f1900e87…) is the conservative alternative also built by that script.
ARG BASE_DIGEST=sha256:03768d9400bf490934e5dce2e9d8ddd9e004a5054939e14641188d8a9b69db8e
FROM vllm/vllm-openai@${BASE_DIGEST}

# Provenance of the baked-in parser, recorded as image labels.
# SOURCE_URL: set to the source repo so the registry can link the package to it.
# BASE_DIGEST is re-declared here: an ARG before FROM is only in scope for the
# FROM line, so it must be redeclared to be usable in the LABEL below.
ARG BASE_DIGEST
ARG BASE_DATE=""
ARG PR_REF=42006
ARG PR_SHA=fe026ca4547295936c8bac39b4e0ed8885d07ea7
ARG SOURCE_URL=""
LABEL org.opencontainers.image.description="vLLM nightly with the Gemma4 MTP streaming tool-call parser fix (vllm-project/vllm#${PR_REF})" \
      org.opencontainers.image.base.digest="${BASE_DIGEST}" \
      org.opencontainers.image.version="${BASE_DATE}" \
      org.opencontainers.image.source="${SOURCE_URL}" \
      patch.pr="vllm-project/vllm#${PR_REF}@${PR_SHA}" \
      patch.scope="vllm/tool_parsers/gemma4_tool_parser.py"

# Stage the patched parser, then replace the file *wherever vLLM actually
# imports it from*. Resolving the path at build time (instead of hardcoding
# dist-packages) means it still lands on the real file if a future base image
# installs vLLM elsewhere, and the build fails here if the module can't be
# imported at all.
COPY gemma4_tool_parser.py /tmp/gemma4_tool_parser.py
RUN python3 <<'PY'
import os, shutil
import vllm.tool_parsers.gemma4_tool_parser as m
dst = m.__file__
shutil.copyfile("/tmp/gemma4_tool_parser.py", dst)
os.remove("/tmp/gemma4_tool_parser.py")
print(f"[patch] wrote parser to: {dst}")
PY

# Independent re-import in a fresh process to confirm the patched file loads.
RUN python3 -c "import vllm.tool_parsers.gemma4_tool_parser as m; print('[verify] live parser:', m.__file__)"
