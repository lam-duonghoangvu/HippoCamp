#!/bin/bash
# Reset feature flags on container start, then run the requested command
# (or an interactive login shell) with the HippoCamp functions loaded.
sudo -n -u hippocamp_api /hippocamp/api/set_flags 1 1 >/dev/null 2>&1 || true
cd /hippocamp/data || exit 1
if [ $# -eq 0 ]; then
    exec /bin/bash -l
fi
exec /bin/bash -lc 'source /home/hippocamp_user/.bashrc; "$@"' bash "$@"
