# gemma4-vllm

The `vllm/vllm-openai` nightly image with the Gemma4 tool-call parser fix from
**[vllm-project/vllm#42006](https://github.com/vllm-project/vllm/pull/42006)**
baked in.

That PR fixes Gemma4 streaming multi-tool-call parsing under MTP (multi-token
speculative decoding) — buffered/segmented delta replay that previously
produced corrupted or merged tool calls. It changes a single package file,
`vllm/tool_parsers/gemma4_tool_parser.py`, which is committed here (pinned at
PR head `795272896`) and replaces the copy in the base image at build time.

## Build & push

```bash
docker login <registry>                          # e.g. ghcr.io
REGISTRY=<registry>/<owner>/gemma4-vllm ./build-and-push.sh
```

Override `BASE_DIGEST`, `PR_REF`, `PR_SHA`, or `SOURCE_URL` via environment.
Two tags are produced: `pr42006-<short-base-digest>` (immutable, records which
nightly was patched) and `pr42006-latest`.

The build resolves where vLLM imports the parser from, replaces it there, and
re-imports to verify — so the build fails loudly if a future base image moves
the install path or the patched file no longer imports cleanly.

## Run

See [`docker-compose.example.yml`](docker-compose.example.yml) for a serving
example (set `image:` to where you pushed it). The image is a drop-in for the
stock `vllm/vllm-openai` — same entrypoint and flags.

## Refresh the parser from the PR

```bash
git -C /path/to/vllm fetch origin pull/42006/head:pr-42006
git -C /path/to/vllm show pr-42006:vllm/tool_parsers/gemma4_tool_parser.py \
  > ./gemma4_tool_parser.py
```

Bump `PR_SHA` in `build-and-push.sh` if you re-extract from an updated PR.
