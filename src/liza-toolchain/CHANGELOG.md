## Unreleased

### Minor

- npm lock:
  - body-parser: 2.3.0 → 2.4.0
  - qs: 6.16.0 → 6.16.1

## 1.3.0

- Creating the container no longer re-owns files of another uid in the volume,
  such as your old uid after a rebuild under a new one. It warns with the
  command to take them, and takes nothing while they're there, root's files
  included.
- `semble`: filelock==4.2.0 → filelock==4.2.1
  - filelock: 4.2.0 → 4.2.1
- Each start warns of a tool missing from the volume, and the next create
  installs it again.

## 1.2.0

- `ast-grep`: 0.45.3 → 0.50.0
- `yq`: v4.53.6 → v4.54.1
- `rtk`: v0.50.0 → v1.0.1
- `uv`: 0.12.19 → 0.13.1
- `scip-search`: v0.2.1 (b8c1487bb4cb) → v0.3.0 (16384a7564ec)
- `stacklit`: c8a87a75116e → 3c0e04153fe1
- `node`: v24.21.0 → v24.22.0
- `go`: 1.27.1 → 1.27.2
- `semble`: filelock==4.0.4, hf-xet==1.6.0, huggingface-hub==1.33.0, markupsafe==3.0.3, numpy==2.5.3, orjson==3.12.0, semble==0.6.1, tokenizers==0.23.2, wcwidth==0.9.1 → filelock==4.2.0, hf-xet==1.7.0, huggingface-hub==2.2.0, markupsafe==3.0.4, numpy==2.5.4, orjson==3.13.0, semble==0.6.2, tokenizers==0.23.3, wcwidth==0.9.2
  - certifi: removed
  - filelock: 4.0.4 → 4.2.0
  - hf-xet: 1.6.0 → 1.7.0
  - httpcore: removed
  - httpcore2: added 2.13.1
  - httpx: removed
  - httpx2: added 2.13.1
  - httpx2-jsfetch: added 1.0
  - huggingface-hub: 1.33.0 → 2.2.0
  - markupsafe: 3.0.3 → 3.0.4
  - numpy: 2.5.3 → 2.5.4
  - orjson: 3.12.0 → 3.13.0
  - semble: 0.6.1 → 0.6.2
  - tokenizers: 0.23.2 → 0.23.3
  - truststore: added 0.10.5
  - wcwidth: 0.9.1 → 0.9.2
- The README says what each tool does.
- `context7`: 4.1.1 → 4.4.4
  - @modelcontextprotocol/core: 2.0.0 → 2.3.1
  - @modelcontextprotocol/node: 2.0.0 → 2.1.1
  - @modelcontextprotocol/server: 2.0.0 → 2.3.1 (GHSA-jm63-cq47-j5jp, GHSA-46jr-4wx8-v453, GHSA-rvq5-wwqv-78pq)
  - @opentelemetry/api-logs: 0.221.0 → 0.222.0
  - @opentelemetry/core: 2.10.0, 2.11.0 → 2.11.0
  - @opentelemetry/exporter-prometheus: 0.221.0 → 0.222.0
  - @opentelemetry/instrumentation: 0.221.0 → 0.222.0
  - @opentelemetry/instrumentation-runtime-node: 0.34.0 → 0.35.0
  - @opentelemetry/resources: 2.10.0, 2.11.0 → 2.11.0
  - @opentelemetry/sdk-metrics: 2.10.0, 2.11.0 → 2.11.0
  - cjs-module-lexer: 2.2.1 → 2.3.0
  - es-module-lexer: 3.0.2 → 3.0.4
  - hono: 4.13.9 → 4.13.13 (GHSA-5r4p-p66f-jhc7)
  - import-in-the-middle: 3.5.1 → 3.5.2
  - zod: 4.6.5 → 4.6.7
- `ast-grep`: 0.50.0 → 0.51.0
- `semble`: model2vec==0.9.0, semble==0.6.2 → model2vec==0.10.0, semble==0.7.0
  - model2vec: 0.9.0 → 0.10.0
  - semble: 0.6.2 → 0.7.0

## 1.1.1

- Release downloads checked against a pinned sha256 retry after any error, a reset
  connection included, where the image's curl is 7.71 or later.

## 1.1.0

- `uv`: 0.12.18 → 0.12.19
- `semble`: filelock==4.0.3, vicinity==0.4.5 → filelock==4.0.4, vicinity==0.4.6
  - filelock: 4.0.3 → 4.0.4
  - vicinity: 0.4.5 → 0.4.6

## 1.0.0

- First release.
