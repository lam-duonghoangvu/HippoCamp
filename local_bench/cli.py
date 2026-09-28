#!/usr/bin/env python3
"""Dispatch one HippoCamp container-style command and print its JSON result.

Usage: cli.py <command> [args...]
  cli.py list_files ["<pattern>"]
  cli.py return_txt "<file_path>"
  cli.py return_metadata "<file_path>"
  cli.py return_ori "<file_path>" ["<output_path>"]
  cli.py return_img "<file_path>" ["<output_path>"] [--page N]
  cli.py set_flags <0|1> <0|1>
  cli.py hhelp
"""
import sys
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import api  # noqa: E402

if __name__ == "__main__":
    sys.exit(api.main())
