#!/usr/bin/env python3
"""Minimal HTTP-CONNECT proxy that forwards all tunnels through an upstream
SOCKS5 proxy. Pure stdlib (works on Python 3.14 where pproxy/uvloop break).

Usage: http_to_socks_bridge.py <listen_port> <socks_host> <socks_port>

litellm's async httpx client honors HTTP(S)_PROXY for HTTP-CONNECT proxies but
not SOCKS, so this bridges: httpx --HTTP CONNECT--> here --SOCKS5--> ssh -D tunnel.
"""
import asyncio
import socket
import struct
import sys


async def socks5_connect(socks_host, socks_port, dst_host, dst_port):
    reader, writer = await asyncio.open_connection(socks_host, socks_port)
    # greeting: VER=5, 1 method, NO AUTH(0)
    writer.write(b"\x05\x01\x00")
    await writer.drain()
    if await reader.readexactly(2) != b"\x05\x00":
        raise OSError("SOCKS5 no-auth rejected")
    # CONNECT request with domain name (ATYP=3) so DNS resolves at the VPS
    host_b = dst_host.encode()
    req = b"\x05\x01\x00\x03" + struct.pack("!B", len(host_b)) + host_b + struct.pack("!H", dst_port)
    writer.write(req)
    await writer.drain()
    resp = await reader.readexactly(4)
    if resp[1] != 0x00:
        raise OSError(f"SOCKS5 connect failed, code={resp[1]}")
    atyp = resp[3]
    if atyp == 1:
        await reader.readexactly(4)
    elif atyp == 3:
        ln = (await reader.readexactly(1))[0]
        await reader.readexactly(ln)
    elif atyp == 4:
        await reader.readexactly(16)
    await reader.readexactly(2)  # bound port
    return reader, writer


async def pipe(src, dst):
    try:
        while True:
            data = await src.read(65536)
            if not data:
                break
            dst.write(data)
            await dst.drain()
    except Exception:
        pass
    finally:
        try:
            dst.close()
        except Exception:
            pass


async def handle(client_reader, client_writer, socks_host, socks_port):
    try:
        line = await client_reader.readline()
        if not line:
            client_writer.close(); return
        parts = line.decode(errors="replace").split()
        if len(parts) < 2 or parts[0].upper() != "CONNECT":
            client_writer.write(b"HTTP/1.1 405 Method Not Allowed\r\n\r\n")
            await client_writer.drain(); client_writer.close(); return
        host, _, port = parts[1].partition(":")
        port = int(port or 443)
        # drain remaining request headers
        while True:
            h = await client_reader.readline()
            if h in (b"\r\n", b"\n", b""):
                break
        try:
            up_r, up_w = await socks5_connect(socks_host, socks_port, host, port)
        except Exception as e:
            client_writer.write(f"HTTP/1.1 502 Bad Gateway\r\n\r\n{e}".encode())
            await client_writer.drain(); client_writer.close(); return
        client_writer.write(b"HTTP/1.1 200 Connection Established\r\n\r\n")
        await client_writer.drain()
        await asyncio.gather(pipe(client_reader, up_w), pipe(up_r, client_writer))
    except Exception:
        try:
            client_writer.close()
        except Exception:
            pass


async def main():
    port = int(sys.argv[1]); socks_host = sys.argv[2]; socks_port = int(sys.argv[3])
    server = await asyncio.start_server(
        lambda r, w: handle(r, w, socks_host, socks_port), "127.0.0.1", port
    )
    print(f"HTTP->SOCKS bridge listening on 127.0.0.1:{port} -> {socks_host}:{socks_port}", flush=True)
    async with server:
        await server.serve_forever()


if __name__ == "__main__":
    try:
        asyncio.run(main())
    except KeyboardInterrupt:
        pass
