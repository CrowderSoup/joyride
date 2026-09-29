#!/usr/bin/env python3
"""Sample real Salt Lake Valley elevations onto the game's grids.

Usage: tools/fetch_elevation.py   (writes data/elevation_near.f32 and data/elevation_far.f32)

The game's city is SLC squeezed horizontally: a 150 m game block is a 201 m (660 ft) real
block, and Temple Square is the origin of both. So game (x, z) maps to real meters east/south
of Temple Square times REAL_PER_GAME, which puts every numbered street over its real address.
Heights stay real meters, relative to Temple Square (the game scales them, if at all).

Source: AWS Terrain Tiles (Terrarium PNG encoding, mostly USGS 3DEP/NED in the US).
Tiles are cached in tools/.cache. Needs only numpy.

Output: little-endian float32s. Header x0, z0, step, nx, nz, then nx*nz heights, row by
row (z outer, x inner). Must match Ground's expectations (it reads the header).
"""
import math
import os
import struct
import sys
import urllib.request
import zlib

import numpy as np

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
CACHE = os.path.join(ROOT, "tools", ".cache")
URL = "https://s3.amazonaws.com/elevation-tiles-prod/terrarium/{z}/{x}/{y}.png"

TEMPLE_SQUARE = (40.7705, -111.8925)  # lat, lon of the middle of the block
# The tiles carry lake-bed bathymetry; clamp to (roughly) the Great Salt Lake's surface.
LAKE_SURFACE = 1280.0
REAL_PER_GAME = 201.0 / 150.0

# (name, x0, z0, step, nx, nz, zoom, smoothing passes). Near covers the city, airport and I-15 with a rim;
# far is the old Terrain grid (+-28 km at 300 m). Near's edges sit on far's grid lines.
GRIDS = [
    ("near", -2200.0, -2200.0, 20.0, 241, 316, 13, 4),
    ("far", -28000.0, -28000.0, 300.0, 187, 187, 10, 0),
]


def blur(h: np.ndarray) -> np.ndarray:
    """3x3 box blur. The raw DEM has embankments, cuts and noise that make lumpy roads at
    street scale; a few passes leave the real hills and drop the rest."""
    p = np.pad(h, 1, mode="edge")
    return sum(p[1 + dy:1 + dy + h.shape[0], 1 + dx:1 + dx + h.shape[1]]
               for dy in (-1, 0, 1) for dx in (-1, 0, 1)) / 9.0


def decode_png_rgb(data: bytes) -> np.ndarray:
    """Minimal PNG decoder: 8-bit RGB or RGBA, non-interlaced. Returns HxWx3 uint8."""
    assert data[:8] == b"\x89PNG\r\n\x1a\n"
    pos = 8
    idat = b""
    while pos < len(data):
        length = struct.unpack(">I", data[pos:pos + 4])[0]
        kind = data[pos + 4:pos + 8]
        body = data[pos + 8:pos + 8 + length]
        if kind == b"IHDR":
            w, h, depth, color, _, _, interlace = struct.unpack(">IIBBBBB", body)
            assert depth == 8 and color in (2, 6) and interlace == 0, (depth, color, interlace)
            bpp = 3 if color == 2 else 4
        elif kind == b"IDAT":
            idat += body
        pos += 12 + length
    raw = np.frombuffer(zlib.decompress(idat), dtype=np.uint8).reshape(h, 1 + w * bpp)
    out = np.zeros((h, w * bpp), dtype=np.int32)
    prev = np.zeros(w * bpp, dtype=np.int32)
    for y in range(h):
        f = raw[y, 0]
        line = raw[y, 1:].astype(np.int32)
        if f == 0:
            cur = line
        elif f == 1:
            cur = line.copy()
            for i in range(bpp, len(cur)):
                cur[i] = (cur[i] + cur[i - bpp]) & 255
        elif f == 2:
            cur = (line + prev) & 255
        elif f == 3:
            cur = line.copy()
            for i in range(len(cur)):
                left = cur[i - bpp] if i >= bpp else 0
                cur[i] = (cur[i] + ((left + prev[i]) >> 1)) & 255
        elif f == 4:
            cur = line.copy()
            for i in range(len(cur)):
                a = cur[i - bpp] if i >= bpp else 0
                b = prev[i]
                c = prev[i - bpp] if i >= bpp else 0
                p = a + b - c
                pa, pb, pc = abs(p - a), abs(p - b), abs(p - c)
                pred = a if pa <= pb and pa <= pc else (b if pb <= pc else c)
                cur[i] = (cur[i] + pred) & 255
        else:
            raise ValueError(f"bad filter {f}")
        out[y] = cur
        prev = cur
    return out.reshape(h, w, bpp)[:, :, :3].astype(np.uint8)


_tiles = {}


def tile_heights(z: int, tx: int, ty: int) -> np.ndarray:
    key = (z, tx, ty)
    if key not in _tiles:
        path = os.path.join(CACHE, f"{z}_{tx}_{ty}.png")
        if not os.path.exists(path):
            os.makedirs(CACHE, exist_ok=True)
            print(f"  fetching {z}/{tx}/{ty}", file=sys.stderr)
            with urllib.request.urlopen(URL.format(z=z, x=tx, y=ty)) as r, open(path, "wb") as f:
                f.write(r.read())
        with open(path, "rb") as f:
            rgb = decode_png_rgb(f.read()).astype(np.float64)
        _tiles[key] = rgb[:, :, 0] * 256.0 + rgb[:, :, 1] + rgb[:, :, 2] / 256.0 - 32768.0
    return _tiles[key]


def global_pixel(lat, lon, z):
    n = 256 * 2 ** z
    x = (lon + 180.0) / 360.0 * n
    s = math.sin(math.radians(lat))
    y = (0.5 - math.log((1 + s) / (1 - s)) / (4 * math.pi)) * n
    return x, y


def elevation(lat, lon, z):
    """Bilinear sample across tile boundaries."""
    px, py = global_pixel(lat, lon, z)
    px -= 0.5
    py -= 0.5
    x0, y0 = math.floor(px), math.floor(py)
    fx, fy = px - x0, py - y0

    def at(gx, gy):
        return tile_heights(z, gx // 256, gy // 256)[gy % 256, gx % 256]

    top = at(x0, y0) * (1 - fx) + at(x0 + 1, y0) * fx
    bot = at(x0, y0 + 1) * (1 - fx) + at(x0 + 1, y0 + 1) * fx
    return top * (1 - fy) + bot * fy


def game_to_latlon(x, z):
    east = x * REAL_PER_GAME
    south = z * REAL_PER_GAME
    lat = TEMPLE_SQUARE[0] - south / 111320.0
    lon = TEMPLE_SQUARE[1] + east / (111320.0 * math.cos(math.radians(TEMPLE_SQUARE[0])))
    return lat, lon


def main():
    base = elevation(*TEMPLE_SQUARE, 13)
    print(f"Temple Square: {base:.1f} m", file=sys.stderr)
    for name, x0, z0, step, nx, nz, zoom, passes in GRIDS:
        print(f"{name}: {nx}x{nz} at {step} m, zoom {zoom}", file=sys.stderr)
        heights = np.zeros((nz, nx), dtype=np.float32)
        for iz in range(nz):
            for ix in range(nx):
                h = max(elevation(*game_to_latlon(x0 + ix * step, z0 + iz * step), zoom), LAKE_SURFACE)
                heights[iz, ix] = h - base
        for _ in range(passes):
            heights = blur(heights)
        print(f"  range {heights.min():.1f} .. {heights.max():.1f} m", file=sys.stderr)
        path = os.path.join(ROOT, "data", f"elevation_{name}.f32")
        os.makedirs(os.path.dirname(path), exist_ok=True)
        with open(path, "wb") as f:
            f.write(np.array([x0, z0, step, nx, nz], dtype="<f4").tobytes())
            f.write(heights.astype("<f4").tobytes())


if __name__ == "__main__":
    main()
