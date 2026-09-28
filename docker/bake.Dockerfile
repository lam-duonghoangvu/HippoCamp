# Self-contained per-profile image: the runtime image plus one profile's data.
# Built by `docker/build.sh --bake <profile> <scope>` with named build contexts
# `data`, `gold` and `meta` (the directory holding the metadata spreadsheet).
ARG RUNTIME_IMAGE=hippocamp/runtime:latest
FROM ${RUNTIME_IMAGE}
ARG XLSX_NAME
USER root
COPY --from=data --chown=root:root --chmod=a+rX . /hippocamp/data/
COPY --from=gold --chown=hippocamp_api:hippocamp_api . /hippocamp/.private/gold/
COPY --from=meta --chown=hippocamp_api:hippocamp_api ${XLSX_NAME} /hippocamp/.private/metadata/files.xlsx
USER hippocamp_user
