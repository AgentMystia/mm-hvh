#!/usr/bin/env python3
"""Post-process Godot Web HTML so it runs on ordinary HTTPS (GitHub Pages / Vercel)."""
from __future__ import annotations

from pathlib import Path

HTML = Path("/workspace/export/web/index.html")


def main() -> None:
    text = HTML.read_text(encoding="utf-8")
    text = text.replace(
        '"ensureCrossOriginIsolationHeaders":true',
        '"ensureCrossOriginIsolationHeaders":false',
    )
    if "hvh-web-menu-hint" not in text:
        extra = """
		<style id="hvh-web-menu-hint">
#hvh-menu-btn { pointer-events: auto !important; }
		</style>
"""
        text = text.replace("</head>", extra + "\t</head>", 1)
    HTML.write_text(text, encoding="utf-8")
    print("patched", HTML)


if __name__ == "__main__":
    main()
