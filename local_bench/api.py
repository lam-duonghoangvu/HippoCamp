"""
Local, Docker-free HippoCamp terminal API.

The command implementations live in docker/hippocamp/api/hippocamp_api.py and
are shared with the rebuilt Docker image, so local_bench returns the same JSON
as the container. This module only maps local_bench's env vars onto it:

    HIPPOCAMP_LOCAL_DATA       -> raw benchmark files for one profile/scope
    HIPPOCAMP_LOCAL_GOLD       -> parsed-text JSON release for the same profile
    HIPPOCAMP_LOCAL_META_XLSX  -> metadata spreadsheet for the same profile/scope
    HIPPOCAMP_LOCAL_OUTPUT     -> where return_img/return_ori write (/hippocamp/output in the container)
    HIPPOCAMP_LOCAL_STATE      -> feature-flag state directory
"""

from __future__ import annotations

import os
import sys
import tempfile
from pathlib import Path

_HERE = Path(__file__).resolve().parent
_tmp = Path(tempfile.gettempdir())
_uid = os.getuid()

_ENV_MAP = {
    "HIPPOCAMP_DATA_ROOT": os.environ.get("HIPPOCAMP_LOCAL_DATA", ""),
    "HIPPOCAMP_GOLD_ROOT": os.environ.get("HIPPOCAMP_LOCAL_GOLD", ""),
    "HIPPOCAMP_METADATA_XLSX": os.environ.get("HIPPOCAMP_LOCAL_META_XLSX", ""),
    "HIPPOCAMP_OUTPUT_ROOT": os.environ.get("HIPPOCAMP_LOCAL_OUTPUT", str(_tmp / f"hippocamp_local_output_{_uid}")),
    "HIPPOCAMP_STATE_DIR": os.environ.get("HIPPOCAMP_LOCAL_STATE", str(_tmp / f"hippocamp_local_state_{_uid}")),
}
for _key, _value in _ENV_MAP.items():
    if _value:
        os.environ.setdefault(_key, _value)

sys.path.insert(0, str(_HERE.parent / "docker" / "hippocamp" / "api"))
from hippocamp_api import (  # noqa: E402,F401
    dispatch,
    get_flags,
    hhelp,
    list_files,
    main,
    render,
    return_img,
    return_metadata,
    return_ori,
    return_txt,
    set_flags,
)
