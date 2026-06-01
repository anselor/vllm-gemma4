# syntax=docker/dockerfile:1
#
# vLLM nightly with the Gemma4 tool-call parser fix from vllm-project/vllm#42006.
#
# The PR is a pure-Python change (no kernels, no recompile) to a single file,
# vllm/tool_parsers/gemma4_tool_parser.py, so the build replaces that one file
# in the base image.

# Base nightly digest. Override with:
#   --build-arg BASE_DIGEST=sha256:<new digest>
ARG BASE_DIGEST=sha256:4cebac8c03f2cd9f5fabe72ac7c2a0b3aaa8450ef8f0e47429425fd1bfb83d42
FROM vllm/vllm-openai@${BASE_DIGEST}

# Provenance of the baked-in parser, recorded as image labels.
# SOURCE_URL: set to the source repo so the registry can link the package to it.
ARG PR_REF=42006
ARG PR_SHA=795272896d4b444600c759f207ebae36c2e9d80c
ARG SOURCE_URL=""
LABEL org.opencontainers.image.description="vLLM nightly with the Gemma4 MTP streaming tool-call parser fix (vllm-project/vllm#${PR_REF})" \
      org.opencontainers.image.base.digest="${BASE_DIGEST}" \
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
