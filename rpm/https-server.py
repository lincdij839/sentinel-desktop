#!/usr/bin/env python3
"""Serve a directory over HTTPS for the Sentinel DNF repository."""
import argparse
import ssl
from functools import partial
from http.server import SimpleHTTPRequestHandler, ThreadingHTTPServer


def main() -> None:
    parser = argparse.ArgumentParser()
    parser.add_argument("--dir", required=True)
    parser.add_argument("--port", type=int, default=8743)
    parser.add_argument("--bind", default="0.0.0.0")
    parser.add_argument("--cert", required=True)
    parser.add_argument("--key", required=True)
    args = parser.parse_args()
    handler = partial(SimpleHTTPRequestHandler, directory=args.dir)
    httpd = ThreadingHTTPServer((args.bind, args.port), handler)
    ctx = ssl.SSLContext(ssl.PROTOCOL_TLS_SERVER)
    ctx.load_cert_chain(args.cert, args.key)
    httpd.socket = ctx.wrap_socket(httpd.socket, server_side=True)
    httpd.serve_forever()


if __name__ == "__main__":
    main()
