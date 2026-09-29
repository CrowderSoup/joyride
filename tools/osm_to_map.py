#!/usr/bin/env python3
"""Convert a raw Overpass JSON dump into the compact map file the game loads.

Usage: tools/osm_to_map.py data/slc_map.json data/raw/slc_raw.json [data/raw/slc_extra.json ...]

Projects lat/lon into local meters around the bbox center:
  +X = east, +Z = south (Godot's -Z is "forward"/north).
"""
import json
import math
import sys

# Road width (meters) by OSM highway class. Generous on purpose - SLC streets are wide.
ROAD_WIDTHS = {
    "motorway": 16, "trunk": 14, "primary": 14, "secondary": 12, "tertiary": 10,
    "residential": 8, "unclassified": 7, "service": 5,
    "motorway_link": 7, "trunk_link": 7, "primary_link": 7,
    "secondary_link": 7, "tertiary_link": 7,
}
LEVEL_HEIGHT = 3.5
GREEN_TAGS = {
    "leisure": {"park", "garden", "pitch", "playground"},
    "landuse": {"grass", "recreation_ground", "cemetery", "village_green"},
}


def main(dst, *srcs):
    elements = []
    for src in srcs:
        with open(src) as f:
            elements += json.load(f)["elements"]
        if src == srcs[0]:
            # Origin comes from the first (roads/buildings) dump only, so adding
            # extra layers never shifts the world.
            lats = [p["lat"] for e in elements for p in e.get("geometry", [])]
            lons = [p["lon"] for e in elements for p in e.get("geometry", [])]
    lat0 = (min(lats) + max(lats)) / 2
    lon0 = (min(lons) + max(lons)) / 2
    mx = 111320.0 * math.cos(math.radians(lat0))
    mz = 110540.0

    def project(p):
        return [round((p["lon"] - lon0) * mx, 2), round(-(p["lat"] - lat0) * mz, 2)]

    roads, buildings, areas, trees = [], [], [], []
    for e in elements:
        tags = e.get("tags", {})
        if e["type"] == "node":
            if tags.get("natural") == "tree":
                trees.append(project(e))
            continue
        geom = e.get("geometry")
        if not geom or len(geom) < 2:
            continue
        pts = [project(p) for p in geom]
        if "highway" in tags:
            kind = tags["highway"]
            roads.append({
                "kind": kind,
                "name": tags.get("name", ""),
                "width": ROAD_WIDTHS.get(kind, 6),
                "pts": pts,
            })
        elif "building" in tags and len(pts) >= 4:
            footprint = pts[:-1]
            h = building_height(tags, e["id"], polygon_area(footprint))
            buildings.append({"h": round(h, 1), "pts": footprint})
        elif pts[0] == pts[-1] and len(pts) >= 4:
            if tags.get("amenity") == "parking":
                areas.append({"kind": "parking", "pts": pts[:-1]})
            elif any(tags.get(k) in v for k, v in GREEN_TAGS.items()):
                areas.append({"kind": "green", "pts": pts[:-1]})

    out = {"origin": [lat0, lon0], "roads": roads, "buildings": buildings, "areas": areas, "trees": trees}
    with open(dst, "w") as f:
        json.dump(out, f, separators=(",", ":"))
    print(f"{len(roads)} roads, {len(buildings)} buildings, {len(areas)} areas, {len(trees)} trees -> {dst}")


def polygon_area(pts):
    return abs(sum(a[0] * b[1] - b[0] * a[1] for a, b in zip(pts, pts[1:] + pts[:1]))) / 2


def building_height(tags, osm_id, area):
    try:
        return float(tags["height"].split()[0])
    except (KeyError, ValueError):
        pass
    try:
        return float(tags["building:levels"]) * LEVEL_HEIGHT
    except (KeyError, ValueError):
        pass
    # Deterministic "random" height so the skyline doesn't look like a waffle.
    # Small footprints are houses/garages; keep them low so they get pitched roofs.
    if area < 250:
        return 3.0 + (osm_id % 4) * 1.0
    return 5.0 + (osm_id % 7) * 1.5


if __name__ == "__main__":
    main(*sys.argv[1:])
