# Joyride (working title)

You're a driver. You drive shit. Cars, trucks, motorcycles, planes — around a real
map of downtown Salt Lake City. No missions, no cops, no timer. Cozy game for bros.

Built with Godot 4.7 (GDScript), 3D, Forward+ (Vulkan) renderer. Linux-only for now.
Needs a Vulkan driver; on Apple Silicon Asahi that's `sudo pacman -S vulkan-asahi`.

## Run it

```sh
godot --path .          # play
godot -e --path .       # open in the editor
```

## Controls

| Action | Keyboard | Gamepad |
|---|---|---|
| Gas / brake+reverse | W / S (or arrows) | RT / LT |
| Steer | A / D | Left stick |
| Handbrake (drift) | Space | A |
| Switch vehicle (Frontier → Sedan → Motorcycle → Plane) | Tab | Y |
| Back to spawn (Main & South Temple) | R | Back |
| Map (click to set waypoint, right-click to clear) | M | Start |
| Toggle help | H | |
| Toggle ambient occlusion (pretty, but ~6 ms/frame on an M1) | F3 | |
| Quit | Esc | |

**Plane:** Shift/Ctrl throttle, W/S pitch (S pulls up), A/D roll, Q/E rudder.
To take off: hold Shift until ~65 mph, then hold S. Banking turns you; let go and the wings level.

## How the map works

`data/slc_map.json` is generated from OpenStreetMap:

1. Two Overpass API dumps of the bbox `40.745,-111.915,40.785,-111.865` (roughly North
   Temple to 900 S, 600 W to 700 E): `data/raw/slc_raw.json` (roads + buildings) and
   `data/raw/slc_extra.json` (parks, parking lots, street trees). Both are gitignored.
2. `tools/osm_to_map.py` projects lat/lon to local meters (+X east, +Z south) and trims
   it down to what the game needs. The origin comes from the first file only.
3. At startup `CityBuilder` builds the ground, lots, parks, sidewalks, roads, lane
   markings and buildings; `Scenery` scatters trees and streetlights; `Terrain` raises
   the Wasatch, the Capitol foothills and the Oquirrhs.

### Refreshing / expanding map data

```sh
curl -A "joyride-dev" -X POST https://overpass-api.de/api/interpreter --data-urlencode \
  'data=[out:json][timeout:90];(way["highway"~"^(motorway|trunk|primary|secondary|tertiary|residential|unclassified|motorway_link|trunk_link|primary_link|secondary_link|tertiary_link|service)$"](40.745,-111.915,40.785,-111.865);way["building"](40.745,-111.915,40.785,-111.865););out geom;' \
  -o data/raw/slc_raw.json
curl -A "joyride-dev" -X POST https://overpass-api.de/api/interpreter --data-urlencode \
  'data=[out:json][timeout:120];(way["leisure"~"^(park|garden|pitch|playground)$"](40.745,-111.915,40.785,-111.865);way["landuse"~"^(grass|recreation_ground|cemetery|village_green)$"](40.745,-111.915,40.785,-111.865);way["amenity"="parking"](40.745,-111.915,40.785,-111.865);node["natural"="tree"](40.745,-111.915,40.785,-111.865););out geom;' \
  -o data/raw/slc_extra.json
python3 tools/osm_to_map.py data/slc_map.json data/raw/slc_raw.json data/raw/slc_extra.json
```

Map data © OpenStreetMap contributors, ODbL. The in-game credit must stay.

## Layout

```
scripts/main.gd                 input map, environment, spawning/switching vehicles, HUD updates
scripts/chase_camera.gd         follow cam, FOV widens with speed
scripts/hud.gd                  speed / street name / help text, owns the maps
scripts/ui/map_geometry.gd      map JSON -> one shared 2D mesh + street labels
scripts/ui/map_view.gd          heading-up minimap and full-screen waypoint map
scripts/world/city_builder.gd   map JSON -> ground, roads, markings, buildings + collision
scripts/world/scenery.gd        chunked MultiMesh trees (real OSM trees) and streetlights
scripts/world/terrain.gd        low-poly noise mountains around the valley
shaders/building.gdshader       procedural windows, storefronts, cornice, fake AO
scripts/world/street_index.gd   "what street am I on" spatial lookup
scripts/world/mesh_tiles.gd     splits big static meshes into cullable 500 m tiles
scripts/vehicles/ground_vehicle.gd  arcade car model, spinning/steering wheels, body pitch/roll
scripts/vehicles/model_builder.gd   profile-extrusion toolkit for procedural low-poly vehicles
scripts/vehicles/frontier.gd    2008 Nissan Frontier NISMO crew cab
scripts/vehicles/airplane.gd    arcade flight model
```

## Known simplifications

- Everything is flat. No elevation, I-15 is at street level, no bridges.
- The Frontier is procedural low-poly; the sedan and motorcycle are still placeholder boxes.
- Buildings without height data get a made-up 5–14m height.
- No traffic, pedestrians, sound, or day/night yet.
- Performance budget (M1 Pro, Retina): the scene is GPU-bound at ~80 fps uncapped with
  defaults. SSAO (F3) costs ~6 ms even at its cheapest; SSIL cost more and is off. Depth
  mostly comes from the baked-looking AO in the building shader, aerial-perspective haze,
  and a warm-sun/cool-ambient split. Buildings and the road surface are split into 500 m
  tiles (`MeshTiles`) so off-screen and out-of-shadow-range parts get culled.

## Ideas for later

- Name it
- Real vehicle models, engine sounds, a radio
- Terrain/elevation (the Avenues and Capitol Hill are steep — perfect for sending it)
- Bigger map: Sugar House, the U, Great Salt Lake, the airport for the plane
- Helicopter, boat, lawnmower
- Ambient traffic, time of day, snow
