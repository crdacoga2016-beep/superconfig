#!/usr/bin/env python3
"""Fusiona solo las claves estéticas de Caelestia sin tocar secretos.

El parche del repo únicamente contiene apariencia, barra, fondo, GIF de sesión,
explorador y toggles. La configuración existente del portátil se conserva,
incluido el bloque `ai` con sus API keys.
"""

from __future__ import annotations

import argparse
import json
import os
import sys
import tempfile
from pathlib import Path
from typing import NoReturn


def fail(message: str) -> NoReturn:
    print(f"error: {message}", file=sys.stderr)
    raise SystemExit(1)


def load_json(path: Path) -> dict:
    if not path.exists():
        return {}
    try:
        data = json.loads(path.read_text(encoding="utf-8"))
    except json.JSONDecodeError as exc:
        fail(f"{path} no contiene JSON válido: {exc}")
    if not isinstance(data, dict):
        fail(f"{path} debe contener un objeto JSON")
    return data


def deep_merge(base: dict, patch: dict) -> dict:
    for key, value in patch.items():
        if isinstance(value, dict) and isinstance(base.get(key), dict):
            deep_merge(base[key], value)
        else:
            base[key] = value
    return base


def expand(value, home: str, wallpaper_dir: str):
    if isinstance(value, str):
        return value.replace("${HOME}", home).replace("${WALLPAPER_DIR}", wallpaper_dir)
    if isinstance(value, list):
        return [expand(item, home, wallpaper_dir) for item in value]
    if isinstance(value, dict):
        return {key: expand(item, home, wallpaper_dir) for key, item in value.items()}
    return value


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--existing", required=True, help="shell.json actual")
    parser.add_argument("--patch", required=True, help="parche estético del repo")
    parser.add_argument("--output", required=True, help="shell.json de salida")
    parser.add_argument("--home", required=True, help="HOME del usuario")
    parser.add_argument("--wallpaper-dir", required=True, help="carpeta de vídeos/fondos")
    args = parser.parse_args()

    existing_path = Path(args.existing).expanduser()
    patch_path = Path(args.patch).expanduser()
    output_path = Path(args.output).expanduser()
    home = str(Path(args.home).expanduser().resolve())
    wallpaper_dir = str(Path(args.wallpaper_dir).expanduser().resolve())

    existing = load_json(existing_path)
    patch = expand(load_json(patch_path), home, wallpaper_dir)

    original_ai = existing.get("ai")
    merged = deep_merge(existing, patch)

    if merged.get("ai") != original_ai:
        fail("el bloque ai cambió durante la fusión; se aborta para no perder API keys")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp_name = tempfile.mkstemp(
        prefix=f".{output_path.name}.", dir=str(output_path.parent), text=True
    )
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            json.dump(merged, handle, indent=4, ensure_ascii=False)
            handle.write("\n")
        os.chmod(tmp_name, 0o600)
        os.replace(tmp_name, output_path)
    except BaseException:
        try:
            os.unlink(tmp_name)
        except OSError:
            pass
        raise

    if original_ai is None:
        print("shell.json: no había bloque ai; no se creó ninguno")
    else:
        print("shell.json: bloque ai preservado intacto")
    print(f"shell.json: claves estéticas aplicadas en {output_path}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
