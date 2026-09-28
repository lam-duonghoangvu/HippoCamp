# Rebuilt HippoCamp Docker images

The released `hippocamp/*` images (six `.tar` archives on Google Drive) are no
longer downloadable. This directory rebuilds an equivalent, sandboxed runtime
from the public contract — [`../docs/docker_api.md`](../docs/docker_api.md) and
the return examples in [`../agent/prompt_modules/config.py`](../agent/prompt_modules/config.py) —
and the Hugging Face dataset. The agent wrappers in `agent/` run against it
unmodified.

## Quick start

```bash
docker/build.sh                      # -> hippocamp/runtime:latest (~2 GB, no data)
docker/run.sh adam subset            # -> container hippocamp-adam-subset on :18082

python3 agent/vllm_batch.py --container hippocamp-adam-subset \
  --questions-file /mnt/data/dhvlam/datasets/HippoCamp/Adam/Subset/Adam_Subset.json \
  --model Qwen/Qwen2.5-VL-7B-Instruct --api-url http://127.0.0.1:8000/v1 \
  --prompt-config config0 --ensure-webui \
  --result-dir result/vllm_adam_subset --log-dir log/vllm_adam_subset
```

`run.sh <adam|bei|victoria> <subset|fullset>` bind-mounts that profile's raw
files, `HippoCamp_Gold/<Profile>` and metadata spreadsheet read-only from
`$HIPPOCAMP_DATASET_ROOT` (default `/mnt/data/dhvlam/datasets/HippoCamp`).
Container names and host ports follow the released convention:

| Container | Port |
| --- | --- |
| `hippocamp-bei-subset` | 18081 |
| `hippocamp-adam-subset` | 18082 |
| `hippocamp-victoria-subset` | 18083 |
| `hippocamp-bei-fullset` | 18084 |
| `hippocamp-adam-fullset` | 18085 |
| `hippocamp-victoria-fullset` | 18086 |

Ports are published on `127.0.0.1` only; pass `--host 0.0.0.0` to expose a
container to the network (the API has no authentication).

Options: `--replace`, `--no-network`, `--no-readonly`, `--port`, `--host`,
`--name`, `--dataset-root`, `--baked`.

Self-contained images (data copied in, for moving to another machine):

```bash
docker/build.sh --bake adam subset                 # -> hippocamp/adam_subset:latest
docker/run.sh adam subset --baked
docker/build.sh --save adam subset hippocamp_adam_subset.tar
```

Baking copies the data into the image (Bei fullset is ~67 GB).

## Sandbox

| Control | How |
| --- | --- |
| Agent runs as `hippocamp_user` | image default user |
| Gold text, metadata and feature flags readable only by `hippocamp_api` | mounted under `/hippocamp/.private` (0700, owned by `hippocamp_api`); `/hippocamp/gold` and `/hippocamp/metadata` are symlinks into it |
| API commands are the only way in | sudoers lets `hippocamp_user` run exactly the `/hippocamp/api/*` commands as `hippocamp_api`, nothing else |
| API rejects path escapes | file paths must resolve under `/hippocamp/data`; output paths under `/hippocamp/output` (symlinks planted there are rejected) |
| Data and system files immutable | data mounted `:ro`, root filesystem `--read-only`, writable tmpfs only for `/tmp`, `/run`, `/hippocamp/output` |
| Resource and privilege limits | `--cap-drop ALL` (+ `SETUID`/`SETGID`/`AUDIT_WRITE` for sudo), `--pids-limit 512`, `--memory 8g` |
| `cd` stays in `/hippocamp/data`, `ls` hides `gold` | shell functions in `hippocamp/api/bashrc_additions` (a convenience, as in the original; the permissions above are the boundary) |
| WebUI/API reachable from this host only | port published on `127.0.0.1` (`--host` to override) |
| Optional: no network | `--no-network` (also disables the WebUI port) |

`--security-opt no-new-privileges` is not used: it would break `sudo`, which
the agent wrappers hard-code (`sudo -u hippocamp_api /hippocamp/api/...`).

## Fidelity to the released images

| Aspect | Status |
| --- | --- |
| Layout under `/hippocamp/`, users, entrypoint, working directory, ports | Same as documented |
| How the agent calls commands (`docker exec … sudo -u hippocamp_api /hippocamp/api/<cmd>`, `.bashrc` functions, `txt`/`img`/`ori`/`ls_files`) | Same; verified through `agent/vllm.py::run_docker_command` |
| `return_txt` content | Same data (served from `HippoCamp_Gold`) |
| `list_files` / `return_metadata` / `return_ori` data | Same data |
| Response keys and key order | Follow the documented examples (`success` first, `error` last; `image_path`, `image_paths`, `image_b64`, `image_b64_list`, `page_count`; absolute `file_path` in `return_ori`) |
| Exact JSON text (indentation, escaping) and error-message wording | Best guess (`indent=2`, UTF-8 unescaped); the originals are not documented |
| `return_img` for PDFs and images | PDFs render 2400 px wide with pypdfium2; images are returned as-is. Not pixel-identical to the original renderer (unknown) |
| `return_img` for docx/pptx/xlsx | LibreOffice 24.2 → PDF → PNG; layout and fonts may differ from the original |
| `return_img` for txt/md/eml/csv/json/ics/ipynb | Drawn on a 2400×3200 page (the size of the documented sample) with Noto Sans CJK |
| `return_img` for audio/video | Returns an error; original behaviour unknown |
| `return_img` without `--page` | Renders page 1 only and reports the total `page_count` |
| Shell tools available to the agent | Ubuntu 24.04 + python3 (openpyxl, pillow, pypdfium2), jq, curl, coreutils; the original package list is unknown |
| WebUI | Documented HTTP routes plus a simple polling page; the original UI and its Socket.IO live updates are not reproduced; ordinary shell commands are not mirrored via `/api/bash_notify` |
| `list_files` pattern | glob against the full path or basename; a pattern without wildcards is a prefix match (per the documented `?pattern=<glob-or-prefix>`) |
| Feature flags | `set_flags` persists per container, is enforced by `return_txt`/`return_img`, and is reset on container start |
| Original image digests, base OS, `/hippocamp/tools` internals | Not reproducible |

Scores will not be bit-for-bit identical to published numbers in any case: the
agent model and the LLM judge in `evaluate.py` are sampled.

Known dataset quirk: `Adam.json` cites
`caud/Agency Agreements/AFSALABANCORPINC_08_01_1996-EX-1.1-AGENCY AGREEMENT.pdf`,
but the file on disk ends in `.PDF`. The dataset is mounted unchanged.

## Files

- `Dockerfile` — runtime image; `bake.Dockerfile` — adds one profile's data
- `build.sh`, `run.sh` — build and start containers
- `hippocamp/api/hippocamp_api.py` — all command implementations (shared with `local_bench/`)
- `hippocamp/api/{list_files,return_txt,…}` — command wrappers run via sudo
- `hippocamp/api/entrypoint.sh`, `bashrc_additions` — container start and agent shell
- `hippocamp/api/webui*`, `hippocamp/webui/app.py` — WebUI
- `sudoers` — the only sudo rule
