# local_bench

A Docker-free stand-in for one HippoCamp container, so the released
`agent/vllm.py` / `agent/vllm_batch.py` terminal-agent wrappers can run
against the raw dataset files on disk instead of a `hippocamp/*` Docker
image. Useful when you don't have (or don't want) Docker access, but you do
have the raw profile files and the `HippoCamp_Gold` parsed-text release
locally — e.g. `/mnt/data/dhvlam/datasets/HippoCamp`.

**This does not modify `agent/`.** It implements the same
`list_files` / `return_txt` / `return_metadata` / `return_img` / `return_ori`
/ `set_flags` contract documented in [`../docs/docker_api.md`](../docs/docker_api.md),
and intercepts the `docker exec` / `docker port` calls that
`agent/vllm.py::run_docker_command` makes, redirecting them here instead of
to a real container. From the agent script's point of view, nothing changed.

## How it works

- `api.py` — maps `HIPPOCAMP_LOCAL_DATA` (raw files), `HIPPOCAMP_LOCAL_GOLD`
  (parsed text), `HIPPOCAMP_LOCAL_META_XLSX` (metadata spreadsheet) and the
  optional `HIPPOCAMP_LOCAL_OUTPUT` / `HIPPOCAMP_LOCAL_STATE` onto
  [`../docker/hippocamp/api/hippocamp_api.py`](../docker/hippocamp/api/hippocamp_api.py),
  the same command implementations the rebuilt Docker image runs. Command
  output is byte-identical to the container's, except text/office page renders
  when the host lacks the image's fonts.
- `cli.py` — `python3 cli.py <command> [args...]`, prints the JSON contract.
- `bin/{list_files,return_txt,return_metadata,return_img,return_ori,set_flags,hhelp}` —
  one-line shims calling `cli.py` with the project's venv Python.
- `bin/docker` — a fake `docker` executable. When `run_docker_command` in
  `agent/vllm.py` shells out to `docker exec <container> /bin/bash -lc "<script>"`,
  this rewrites `/hippocamp/api/X` → `bin/X` and drops the
  `sudo -u hippocamp_api` prefix, then actually runs the (now-local) script
  with `cwd` set to `HIPPOCAMP_LOCAL_DATA`, so plain shell commands (`ls`,
  `find`, `cat`, `grep`, ...) behave the same way they would inside the
  container's `/hippocamp/data`. `docker port` (WebUI autodetect) always
  reports unavailable, since there's no WebUI in local mode.

## Usage

Put `local_bench/bin` first on `PATH` and set the three data env vars, then
run the agent scripts exactly as documented in `agent/README.md` /
`docs/reproduction.md` — `--container` is still required by argparse but its
value is ignored by the local `docker` shim:

```bash
export HIPPOCAMP_LOCAL_DATA="/mnt/data/dhvlam/datasets/HippoCamp/Adam/Subset/Adam_Subset"
export HIPPOCAMP_LOCAL_GOLD="/mnt/data/dhvlam/datasets/HippoCamp/HippoCamp_Gold/Adam"
export HIPPOCAMP_LOCAL_META_XLSX="/mnt/data/dhvlam/datasets/HippoCamp/Adam/Subset/Adam_Subset.xlsx"
export PATH="$(pwd)/local_bench/bin:$PATH"

python3 agent/vllm_batch.py \
  --container local-adam-subset \
  --questions-file /mnt/data/dhvlam/datasets/HippoCamp/Adam/Subset/Adam_Subset.json \
  --model Qwen2.5-3B-Instruct \
  --api-url http://127.0.0.1:8000/v1 \
  --prompt-config config3 \
  --result-dir result/vllm_local_adam_subset \
  --log-dir log/vllm_local_adam_subset
```

To point at a different profile/scope (Bei, Victoria, fullset), change the
three `HIPPOCAMP_LOCAL_*` env vars to the matching `Fullset`/`Subset`
directories and re-run — nothing else needs to change.

`--prompt-config`: pick `config3` (return_txt on, return_img off) for a
text-only model. `config0` (all tools on) sends `image_url` content blocks
for image files, which a non-multimodal model's OpenAI-compatible endpoint
will typically reject.

## Known limitation vs. the real container

This intentionally does not reproduce the container's sandboxing (`cd`
restricted to the data root, gold text readable only through the API,
read-only filesystem) — it's a convenience for running the released agent code
locally, not a security boundary: the model's shell can read the gold files
directly. Don't point `HIPPOCAMP_LOCAL_DATA` at anything you don't want a
model-driven shell loop to be able to read. For sandboxed runs use the rebuilt
image in [`../docker/`](../docker/README.md).
