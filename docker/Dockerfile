# HippoCamp runtime image, rebuilt from the public contract (docs/docker_api.md).
# Data is not baked in: docker/run.sh bind-mounts one profile read-only
# (or see bake.Dockerfile for self-contained per-profile images).
FROM ubuntu:24.04

ENV DEBIAN_FRONTEND=noninteractive LANG=C.UTF-8 LC_ALL=C.UTF-8

RUN apt-get update && apt-get install -y --no-install-recommends \
        bash sudo ca-certificates curl jq less file procps \
        coreutils findutils grep sed gawk \
        python3 python3-pip python3-flask \
        libreoffice-writer-nogui libreoffice-calc-nogui libreoffice-impress-nogui \
        fonts-dejavu-core fonts-liberation fonts-noto-cjk \
    && rm -rf /var/lib/apt/lists/*

# Same versions as the project .venv, so local_bench and the image render identically.
RUN pip3 install --no-cache-dir --break-system-packages openpyxl==3.1.5 pillow==12.3.0 pypdfium2==5.13.0

# hippocamp_user: the agent's shell. hippocamp_api: the only account that can
# read gold text, metadata and feature-flag state.
RUN (userdel -r ubuntu 2>/dev/null || true) \
    && useradd -u 1000 -m -s /bin/bash hippocamp_user \
    && useradd -u 1001 -M -d /nonexistent -s /usr/sbin/nologin hippocamp_api

COPY hippocamp/api/ /hippocamp/api/
COPY hippocamp/webui/ /hippocamp/webui/
COPY sudoers /etc/sudoers.d/hippocamp

RUN mkdir -p /hippocamp/data /hippocamp/tools /hippocamp/output \
        /hippocamp/.private/gold /hippocamp/.private/metadata /hippocamp/.private/state \
    && ln -s /hippocamp/.private/gold /hippocamp/gold \
    && ln -s /hippocamp/.private/metadata /hippocamp/metadata \
    && chown -R hippocamp_api:hippocamp_api /hippocamp/.private \
    && chmod 0700 /hippocamp/.private \
    && chmod 1777 /hippocamp/output \
    && chown -R root:root /hippocamp/api /hippocamp/webui \
    && chmod 0755 /hippocamp/api/* \
    && chmod 0644 /hippocamp/api/hippocamp_api.py /hippocamp/api/bashrc_additions /hippocamp/webui/app.py \
    && chmod 0440 /etc/sudoers.d/hippocamp \
    && visudo -cf /etc/sudoers.d/hippocamp \
    && printf 'source /hippocamp/api/bashrc_additions\n' > /home/hippocamp_user/.bashrc \
    && printf '[ -f ~/.bashrc ] && . ~/.bashrc\n' > /home/hippocamp_user/.profile \
    && chown root:root /home/hippocamp_user /home/hippocamp_user/.bashrc /home/hippocamp_user/.profile \
    && chmod 0755 /home/hippocamp_user

USER hippocamp_user
WORKDIR /hippocamp/data
EXPOSE 8080 5000
ENTRYPOINT ["/hippocamp/api/entrypoint.sh"]
