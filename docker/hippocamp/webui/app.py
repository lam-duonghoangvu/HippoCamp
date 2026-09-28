#!/usr/bin/env python3
"""
Minimal HippoCamp WebUI: the HTTP routes documented in docs/docker_api.md,
served from the same hippocamp_api module as the terminal commands (so feature
flags and path checks apply identically). The original UI and its
Flask-SocketIO live updates are not public; this page polls /api/history.
"""

import os
import sys
import threading
import time
from pathlib import Path

from flask import Flask, abort, jsonify, request, send_file

sys.path.insert(0, "/hippocamp/api")
import hippocamp_api as api  # noqa: E402

PREVIEW_CHARS = 2000
app = Flask(__name__)
app.config["JSON_SORT_KEYS"] = False  # keep `success` first, as in the terminal output
_history = []
_history_lock = threading.Lock()


def _record(command, source, result=None):
    with _history_lock:
        _history.append({"time": time.strftime("%Y-%m-%d %H:%M:%S"), "command": command,
                         "source": source, "result": result})
        del _history[:-500]


def _preview_txt(result):
    data = (result or {}).get("data")
    if not result.get("success") or not isinstance(data, dict):
        return result
    segments = []
    for seg in data.get("segments") or []:
        seg = dict(seg)
        content = seg.get("content")
        if isinstance(content, str) and len(content) > PREVIEW_CHARS:
            seg["content"] = content[:PREVIEW_CHARS] + "..."
        segments.append(seg)
    return {**result, "data": {**data, "segments": segments}}


@app.get("/")
def index():
    return """<!doctype html><html><head><meta charset="utf-8"><title>HippoCamp</title>
<style>body{font:14px system-ui;margin:16px}pre{white-space:pre-wrap;background:#f4f4f4;padding:8px}</style>
</head><body><h1>HippoCamp</h1><h2>Command history</h2><div id="h"></div><h2>Files</h2><pre id="f"></pre>
<script>
async function tick(){
  const h=await (await fetch('/api/history')).json();
  document.getElementById('h').innerHTML=h.data.slice().reverse().map(e=>
    '<pre>'+e.time+' ['+e.source+'] '+String(e.command).replace(/</g,'&lt;')+'</pre>').join('');
}
fetch('/api/files/list').then(r=>r.json()).then(j=>document.getElementById('f').textContent=(j.data||[]).join('\\n'));
tick();setInterval(tick,2000);
</script></body></html>"""


@app.get("/api/files")
def files_tree():
    sub = request.args.get("path", "")
    base = api._resolve(sub) if sub else api.DATA_ROOT
    if base is None or not base.is_dir():
        return jsonify(api._err(f"invalid path: {sub}"))
    entries = [{"name": p.name, "path": api._rel(p), "type": "dir" if p.is_dir() else "file"}
               for p in sorted(base.iterdir())]
    return jsonify(api._ok(data=entries))


@app.get("/api/files/list")
def files_list():
    return jsonify(api.list_files(request.args.get("pattern", "")))


@app.get("/api/return_txt/<path:file_path>")
def return_txt(file_path):
    _record(f'return_txt "{file_path}"', "webui")
    return jsonify(_preview_txt(api.return_txt(file_path)))


@app.get("/api/return_txt_full/<path:file_path>")
def return_txt_full(file_path):
    _record(f'return_txt "{file_path}"', "webui")
    return jsonify(api.return_txt(file_path))


@app.get("/api/return_img/<path:file_path>")
def return_img(file_path):
    page = request.args.get("page", type=int)
    _record(f'return_img "{file_path}"' + (f" --page {page}" if page else ""), "webui")
    return jsonify(api.return_img(file_path, "", page))


@app.get("/api/return_ori/<path:file_path>")
def return_ori(file_path):
    resolved = api._resolve(file_path)
    if resolved is None or not resolved.is_file():
        return jsonify(api._err(f"file not found: {file_path}"))
    return jsonify(api._ok(file_path=f"{api.CONTAINER_DATA}/{api._rel(resolved)}",
                           size=resolved.stat().st_size,
                           url=f"/api/serve_file/{api._rel(resolved)}"))


@app.get("/api/return_ori_full/<path:file_path>")
def return_ori_full(file_path):
    return jsonify(api.return_ori(file_path))


@app.get("/api/return_metadata/<path:file_path>")
def return_metadata(file_path):
    return jsonify(api.return_metadata(file_path))


@app.get("/api/serve_image/<path:image_path>")
def serve_image(image_path):
    dest = api._resolve_output(image_path, "")
    if dest is None or not dest.is_file():
        abort(404)
    return send_file(dest)


@app.get("/api/serve_file/<path:file_path>")
def serve_file(file_path):
    resolved = api._resolve(file_path)
    if resolved is None or not resolved.is_file():
        abort(404)
    return send_file(resolved)


@app.get("/api/history")
def history():
    with _history_lock:
        return jsonify(api._ok(data=list(_history)))


@app.post("/api/terminal_notify")
@app.post("/api/log_command")
@app.post("/api/bash_notify")
def log_command():
    payload = request.get_json(silent=True) or {}
    source = payload.get("source") or request.path.rsplit("/", 1)[-1]
    _record(payload.get("command", ""), source, payload.get("result"))
    return jsonify(api._ok(data="logged"))


@app.get("/api/feature_flags")
def feature_flags():
    return jsonify(api._ok(data=api.get_flags()))


@app.post("/api/feature_flags")
def feature_flags_post():
    return jsonify(api._err("feature flags are read-only over HTTP; use set_flags")), 403


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=int(os.environ.get("HIPPOCAMP_PORT", "8080")), threaded=True)
