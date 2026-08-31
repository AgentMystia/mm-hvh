#!/usr/bin/env python3
"""Fail CI if the Web export is missing, undersized, or has COOP/COEP isolation on."""
from __future__ import annotations

from pathlib import Path

ROOT = Path(__file__).resolve().parent.parent
WEB = ROOT / "export" / "web"
HTML = WEB / "index.html"
PCK = WEB / "index.pck"
WASM = WEB / "index.wasm"


def main() -> None:
    html = HTML.read_text(encoding="utf-8")
    if 'ensureCrossOriginIsolationHeaders":false' not in html:
        raise SystemExit("index.html must disable COOP/COEP isolation for GitHub Pages")
    if not PCK.is_file() or PCK.stat().st_size < 1_000_000:
        raise SystemExit("index.pck missing or too small")
    if not WASM.is_file() or WASM.stat().st_size < 1_000_000:
        raise SystemExit("index.wasm missing or too small")
    pck = PCK.stat().st_size
    wasm = WASM.stat().st_size
    if f'"index.pck":{pck}' not in html:
        raise SystemExit(f"index.html fileSizes pck mismatch (file is {pck})")
    print(f"web export ok pck={pck} wasm={wasm}")


if __name__ == "__main__":
    main()
