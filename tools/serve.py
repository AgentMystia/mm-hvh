#!/usr/bin/env python3
"""Static file server with COOP/COEP so Godot Web can use SharedArrayBuffer if enabled."""
from __future__ import annotations

import argparse
import http.server
import os
import socketserver


class Handler(http.server.SimpleHTTPRequestHandler):
	extensions_map = {
		**http.server.SimpleHTTPRequestHandler.extensions_map,
		".wasm": "application/wasm",
		".pck": "application/octet-stream",
		".js": "application/javascript",
	}

	def end_headers(self) -> None:
		self.send_header("Cross-Origin-Opener-Policy", "same-origin")
		self.send_header("Cross-Origin-Embedder-Policy", "require-corp")
		self.send_header("Cross-Origin-Resource-Policy", "same-origin")
		self.send_header("Cache-Control", "no-cache")
		super().end_headers()


def main() -> None:
	p = argparse.ArgumentParser()
	p.add_argument("--port", type=int, default=43187)
	p.add_argument("--dir", default="export/web")
	args = p.parse_args()
	os.chdir(args.dir)
	socketserver.TCPServer.allow_reuse_address = True
	with socketserver.TCPServer(("0.0.0.0", args.port), Handler) as httpd:
		print("serving", os.getcwd(), "on", args.port, flush=True)
		httpd.serve_forever()


if __name__ == "__main__":
	main()
