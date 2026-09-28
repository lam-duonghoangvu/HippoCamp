#!/usr/bin/env bash
# Start a sandboxed HippoCamp container for one profile/scope.
#
#   docker/run.sh <adam|bei|victoria> <subset|fullset> [options]
#
# Options:
#   --dataset-root DIR   HippoCamp dataset root (default: $HIPPOCAMP_DATASET_ROOT
#                        or /mnt/data/dhvlam/datasets/HippoCamp)
#   --baked              use the self-contained hippocamp/<profile>_<scope> image
#                        (docker/build.sh --bake) instead of bind-mounting data
#   --image IMAGE        runtime image (default: hippocamp/runtime:latest)
#   --name NAME          container name (default: hippocamp-<profile>-<scope>)
#   --port PORT          host port for the WebUI (default: documented port)
#   --host ADDR          host address to publish on (default: 127.0.0.1; the
#                        API has no auth, so 0.0.0.0 must be explicit)
#   --no-network         run with --network none (disables the WebUI port)
#   --no-readonly        do not mount the root filesystem read-only
#   --replace            remove an existing container with the same name first
set -euo pipefail

usage() { sed -n '2,18p' "$0" | sed 's/^# \{0,1\}//'; exit 1; }
[ $# -ge 2 ] || usage

PROFILE="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
SCOPE="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
shift 2

DATASET_ROOT="${HIPPOCAMP_DATASET_ROOT:-/mnt/data/dhvlam/datasets/HippoCamp}"
IMAGE="hippocamp/runtime:latest"
BAKED=0 NETWORK=1 READONLY=1 REPLACE=0 NAME="" PORT="" HOST=127.0.0.1
while [ $# -gt 0 ]; do
    case "$1" in
        --dataset-root) DATASET_ROOT="$2"; shift 2 ;;
        --baked) BAKED=1; shift ;;
        --image) IMAGE="$2"; shift 2 ;;
        --name) NAME="$2"; shift 2 ;;
        --port) PORT="$2"; shift 2 ;;
        --host) HOST="$2"; shift 2 ;;
        --no-network) NETWORK=0; shift ;;
        --no-readonly) READONLY=0; shift ;;
        --replace) REPLACE=1; shift ;;
        *) usage ;;
    esac
done

case "$PROFILE" in
    adam) CAP=Adam ;; bei) CAP=Bei ;; victoria) CAP=Victoria ;;
    *) echo "unknown profile: $PROFILE" >&2; exit 1 ;;
esac
# Host ports documented for the released images.
case "$PROFILE-$SCOPE" in
    bei-subset) DEFAULT_PORT=18081 ;; adam-subset) DEFAULT_PORT=18082 ;;
    victoria-subset) DEFAULT_PORT=18083 ;; bei-fullset) DEFAULT_PORT=18084 ;;
    adam-fullset) DEFAULT_PORT=18085 ;; victoria-fullset) DEFAULT_PORT=18086 ;;
    *) echo "unknown scope: $SCOPE (use subset or fullset)" >&2; exit 1 ;;
esac
if [ "$SCOPE" = subset ]; then
    DATA="$DATASET_ROOT/$CAP/Subset/${CAP}_Subset"
    XLSX="$DATASET_ROOT/$CAP/Subset/${CAP}_Subset.xlsx"
else
    DATA="$DATASET_ROOT/$CAP/Fullset/$CAP"
    XLSX="$DATASET_ROOT/$CAP/Fullset/${CAP}_files.xlsx"
fi
GOLD="$DATASET_ROOT/HippoCamp_Gold/$CAP"
NAME="${NAME:-hippocamp-$PROFILE-$SCOPE}"
PORT="${PORT:-$DEFAULT_PORT}"

if docker container inspect "$NAME" >/dev/null 2>&1; then
    if [ "$REPLACE" = 1 ]; then
        docker rm -f "$NAME" >/dev/null
    else
        echo "container $NAME already exists (use --replace, or: docker start $NAME)" >&2
        exit 1
    fi
fi

args=(
    run -d -it --name "$NAME" --hostname hippocamp
    -e "HIPPOCAMP_DATASET=${PROFILE}_${SCOPE}"
    --cap-drop ALL --cap-add SETUID --cap-add SETGID --cap-add AUDIT_WRITE
    --pids-limit 512 --memory 8g
    --tmpfs /tmp:rw,mode=1777,size=4g
    --tmpfs /run:rw,mode=755,size=16m
    --tmpfs /hippocamp/output:rw,mode=1777,size=2g
    --tmpfs /hippocamp/.private/state:rw,uid=1001,gid=1001,mode=0700,size=1m
)
[ "$READONLY" = 1 ] && args+=(--read-only)
if [ "$NETWORK" = 1 ]; then
    args+=(-p "$HOST:$PORT:8080")
else
    args+=(--network none)
fi
if [ "$BAKED" = 1 ]; then
    IMAGE="hippocamp/${PROFILE}_${SCOPE}:latest"
else
    for p in "$DATA" "$GOLD" "$XLSX"; do
        [ -e "$p" ] || { echo "missing: $p" >&2; exit 1; }
    done
    args+=(
        -v "$DATA:/hippocamp/data:ro"
        -v "$GOLD:/hippocamp/.private/gold:ro"
        -v "$XLSX:/hippocamp/.private/metadata/files.xlsx:ro"
    )
fi
args+=("$IMAGE")

docker "${args[@]}" >/dev/null
echo "started $NAME ($IMAGE) on $HOST:$PORT"
echo "  shell:  docker exec -it $NAME bash -l"
echo "  agent:  --container $NAME"
