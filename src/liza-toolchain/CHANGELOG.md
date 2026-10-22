## 1.3.0

- `rtk`: v1.0.0 → v1.0.1
- `semble`: filelock==4.1.1 → filelock==4.2.0
  - filelock: 4.1.1 → 4.2.0

## 1.2.0

- `ast-grep`: 0.45.3 → 0.50.0
- `yq`: v4.53.6 → v4.54.1
- `rtk`: v0.50.0 → v1.0.0
- `uv`: 0.12.19 → 0.13.1
- `scip-search`: v0.2.1 (b8c1487bb4cb) → v0.3.0 (16384a7564ec)
- `stacklit`: c8a87a75116e → 3c0e04153fe1
- `node`: v24.21.0 → v24.22.0
- `go`: 1.27.1 → 1.27.2
- `semble`: filelock==4.0.4, hf-xet==1.6.0, huggingface-hub==1.33.0, markupsafe==3.0.3, numpy==2.5.3, orjson==3.12.0, semble==0.6.1, tokenizers==0.23.2, wcwidth==0.9.1 → filelock==4.1.1, hf-xet==1.7.0, huggingface-hub==2.2.0, markupsafe==3.0.4, numpy==2.5.4, orjson==3.13.0, semble==0.6.2, tokenizers==0.23.3, wcwidth==0.9.2
  - certifi: removed
  - filelock: 4.0.4 → 4.1.1
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
