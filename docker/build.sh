#!/usr/bin/env bash
# Build the HippoCamp runtime image, optionally baking one profile's data in.
#
#   docker/build.sh                               -> hippocamp/runtime:latest
#   docker/build.sh --bake <profile> <scope>      -> hippocamp/<profile>_<scope>:latest
#   docker/build.sh --bake-all                    -> all six baked images
#   docker/build.sh --save <profile> <scope> OUT  -> docker save of a baked image
#
# Dataset root: $HIPPOCAMP_DATASET_ROOT (default /mnt/data/dhvlam/datasets/HippoCamp)
set -euo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
DATASET_ROOT="${HIPPOCAMP_DATASET_ROOT:-/mnt/data/dhvlam/datasets/HippoCamp}"

build_runtime() {
    docker build -t hippocamp/runtime:latest "$HERE"
}

bake() {
    local profile scope cap data meta xlsx
    profile="$(echo "$1" | tr '[:upper:]' '[:lower:]')"
    scope="$(echo "$2" | tr '[:upper:]' '[:lower:]')"
    case "$profile" in adam) cap=Adam ;; bei) cap=Bei ;; victoria) cap=Victoria ;;
        *) echo "unknown profile: $profile" >&2; exit 1 ;; esac
    case "$scope" in
        subset) data="$DATASET_ROOT/$cap/Subset/${cap}_Subset"; meta="$DATASET_ROOT/$cap/Subset"; xlsx="${cap}_Subset.xlsx" ;;
        fullset) data="$DATASET_ROOT/$cap/Fullset/$cap"; meta="$DATASET_ROOT/$cap/Fullset"; xlsx="${cap}_files.xlsx" ;;
        *) echo "unknown scope: $scope" >&2; exit 1 ;;
    esac
    docker build -f "$HERE/bake.Dockerfile" \
        --build-context "data=$data" \
        --build-context "gold=$DATASET_ROOT/HippoCamp_Gold/$cap" \
        --build-context "meta=$meta" \
        --build-arg "XLSX_NAME=$xlsx" \
        -t "hippocamp/${profile}_${scope}:latest" "$HERE"
}

case "${1:-}" in
    "") build_runtime ;;
    --bake) [ $# -eq 3 ] || { echo "usage: $0 --bake <profile> <scope>" >&2; exit 1; }
        build_runtime; bake "$2" "$3" ;;
    --bake-all) build_runtime
        for p in adam bei victoria; do for s in subset fullset; do bake "$p" "$s"; done; done ;;
    --save) [ $# -eq 4 ] || { echo "usage: $0 --save <profile> <scope> <out.tar>" >&2; exit 1; }
        docker save -o "$4" "hippocamp/$(echo "$2" | tr '[:upper:]' '[:lower:]')_$(echo "$3" | tr '[:upper:]' '[:lower:]'):latest" ;;
    *) sed -n '2,9p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
