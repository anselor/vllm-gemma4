# gemma4-vllm

The `vllm/vllm-openai` nightly image with the Gemma4 tool-call parser fix from
**[vllm-project/vllm#42006](https://github.com/vllm-project/vllm/pull/42006)**
baked in.

That PR fixes Gemma4 streaming multi-tool-call parsing under MTP (multi-token
speculative decoding) — buffered/segmented delta replay that previously
produced corrupted or merged tool calls. It changes a single package file,
`vllm/tool_parsers/gemma4_tool_parser.py`, which is committed here (pinned at
PR head `fe026ca4`) and replaces the copy in the base image at build time.

## Build & push

```bash
docker login <registry>                          # e.g. ghcr.io
REGISTRY=<registry>/<owner>/gemma4-vllm ./build-and-push.sh
```

By default this builds one image per base nightly listed in `BASES`:

| Base nightly | Notable contents | Tags |
|---|---|---|
| `nightly-9c7f7741` (2026-06-07) | TP2/MTP/vision fixes #43909 #43982 #43798 #44232 | `pr42006-20260607`, `pr42006-<digest12>` |
| `nightly-2c9c07c8` (2026-06-10) | + #42175 (Gemma4 FA4 all-layers + mm_prefix) | `pr42006-20260610`, `pr42006-<digest12>`, `pr42006-latest`, `latest` |

Each build gets an immutable date-based version tag plus the base-digest short
(provenance). The `LATEST_DATE` base also moves `pr42006-latest` / `latest`.
Override `BASES`, `LATEST_DATE`, `PR_REF`, `PR_SHA`, or `SOURCE_URL` via
environment (e.g. `BASES="20260610=sha256:0376..." ./build-and-push.sh` to build
just one).

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

Bump `PR_SHA` in `build-and-push.sh` (and the `Dockerfile` default) if you
re-extract from an updated PR — the committed file and `PR_SHA` must stay in
sync. The current pin is PR head `fe026ca4` (2026-06-02); #42006 is still open,
so re-check the head before each rebuild. The build's import-verify catches a
*broken* parser but not a silent revert to an older head.
