#!/usr/bin/env python3
"""Genera el .desktop de Thunar apuntando al wrapper Fluent/Win11."""

from __future__ import annotations

import argparse
import sys
from pathlib import Path


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--source", required=True)
    parser.add_argument("--output", required=True)
    parser.add_argument("--wrapper", required=True)
    parser.add_argument("--icon", default="")
    args = parser.parse_args()

    source = Path(args.source)
    output = Path(args.output)

    if not source.is_file():
        print(f"error: no existe {source}", file=sys.stderr)
        return 1

    lines = []
    for line in source.read_text(encoding="utf-8").splitlines():
        if line.startswith("Exec=thunar"):
            line = line.replace("Exec=thunar", f"Exec={args.wrapper}", 1)
        elif line == "Icon=org.xfce.thunar" and args.icon:
            line = f"Icon={args.icon}"
        lines.append(line)

    output.parent.mkdir(parents=True, exist_ok=True)
    output.write_text("\n".join(lines) + "\n", encoding="utf-8")
    print(f"thunar.desktop generado en {output}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
