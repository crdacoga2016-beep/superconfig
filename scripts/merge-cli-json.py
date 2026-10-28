#!/usr/bin/env python3
"""Ajusta el postHook de Caelestia conservando el resto de cli.json."""

from __future__ import annotations

import json
import os
import sys
import tempfile
from pathlib import Path


def main() -> int:
    if len(sys.argv) != 3:
        print(f"uso: {sys.argv[0]} <cli.json> <postHook>", file=sys.stderr)
        return 2

    target = Path(sys.argv[1]).expanduser()
    hook = sys.argv[2]

    data = {}
    if target.exists():
        try:
            data = json.loads(target.read_text(encoding="utf-8"))
        except json.JSONDecodeError as exc:
            print(f"error: {target} no contiene JSON válido: {exc}", file=sys.stderr)
            return 1
        if not isinstance(data, dict):
            print(f"error: {target} debe contener un objeto JSON", file=sys.stderr)
            return 1

    theme = data.get("theme")
    if not isinstance(theme, dict):
        theme = {}
    theme["postHook"] = hook
    data["theme"] = theme

    target.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(prefix=f".{target.name}.", dir=str(target.parent), text=True)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(data, handle, indent=4, ensure_ascii=False)
            handle.write("\n")
        os.chmod(tmp_name, 0o644)
        os.replace(tmp_name, target)
    except BaseException:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise

    print(f"cli.json: postHook -> {hook}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
