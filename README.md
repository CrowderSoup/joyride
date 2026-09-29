# Joyride (working title)

You're a driver. You drive shit. Cars, trucks, motorcycles, planes — around a city
that's a lot like Salt Lake City. No missions, no cops, no timer. Cozy game for bros.

Built with Godot 4.7 (GDScript), 3D, Forward+ (Vulkan) renderer. Linux-only for now.
Needs a Vulkan driver; on Apple Silicon Asahi that's `sudo pacman -S vulkan-asahi`.

## Run it

```sh
godot --path .          # play
godot -e --path .       # open in the editor
```

## Controls

You start on foot in the Joyride hangar at the airport, with the plane, the Frontier,
the sedan and the motorcycle parked in their bays. Walk up to one and press F to get in.
To switch, stop, get out, and walk to another one. Vehicles stay wherever you leave them
(yellow squares on the map).

| Action | Keyboard | Gamepad |
|---|---|---|
| Walk (relative to the camera) | WASD (or arrows) | Left stick |
| Gas / brake+reverse | W / S | RT / LT |
| Steer | A / D | Left stick |
| Look around (swings back behind a vehicle) | Mouse | Right stick |
| Orbit the camera (on foot) | Q / E | Right stick |
| Run (on foot) | Shift | X |
| Jump / handbrake (drift) | Space | A |
| Get in / get out (must be nearly stopped) | F | Y |
| Unstick vehicle in place; on foot: back to the hangar | R | Back |
| Map (click to set waypoint, right-click to clear) | M | Start |
| Toggle help | H | |
| Toggle ambient occlusion (pretty, but ~6 ms/frame on an M1) | F3 | |
| Free the mouse; press again to quit | Esc | |

**Plane:** on the ground it drives like a car: W for gas, S to brake (hold S at a stop to
back up slowly), A/D to steer. Taxi out, line up on runway 35, hold W until the HUD says
"Hold S to lift off" (~63 mph), then hold S. In the air: W/S pitch (S pulls up), A/D roll,
Q/E rudder, Shift/Ctrl throttle. Banking turns you; let go and the wings level.

## The ground

The land is real: Salt Lake Valley elevations from the USGS (via AWS Terrain Tiles),
sampled by `tools/fetch_elevation.py` into `data/elevation_*.f32`. The city is squeezed
horizontally (a 150 m game block is a 201 m real one) with Temple Square as the origin of
both, so every numbered street sits over its real address: State Street climbs to the
Capitol, the Avenues and the east bench rise, and the west side drops toward the airport.
Heights are real meters. The fine city grid is smoothed a little so roads aren't lumpy;
the coarse one carries the real Wasatch, Oquirrhs and Great Salt Lake out to ~28 km.

`Ground` answers "how high is the ground here" for everything else. The airport, the
Capitol, the other landmarks and ponds get leveled pads (`Ground.flatten`) before
anything is built. To refetch: `python3 tools/fetch_elevation.py` (needs numpy; caches
tiles in `tools/.cache`).

## How the city works

The city is generated at startup by `CityGen` — SLC-flavored, not a map of it. It's
deterministic (same seed every run), and compressed so everything is a short drive:

- **Grid:** 150 m blocks (real SLC is ~200 m) numbered from Temple Square, which sits at
  the origin (+X east, +Z south). Main, State, West Temple, North/South Temple, then
  "400 South", "700 East" and so on, 600 West to 900 East and 400 North to 1300 South.
  Arterials are 24 m wide, others 20 m or 15 m. No alleys or driveways.
- **Zones:** skyscrapers downtown (podium + 1–3 setback tiers, glass or stone, crowns),
  mid-rise brick and stone with storefront awnings around that, warehouses along I-15,
  houses (hip/gable roofs, yards, street trees) everywhere else, and a few pocket parks.
  A handful of hand-placed signature towers give the skyline its shape.
- **Landmarks** (`Landmarks`): Temple Square with the temple and tabernacle, the Capitol at
  the head of State Street, the arena, and the City & County Building on Washington
  Square. Pioneer Park and Liberty Park (with its pond) are parks from the generator.
- **Airport** (`Airport`): just west of I-15 at the end of North Temple, about 1 km from
  Temple Square.

`CityGen.generate()` returns plain map data (roads, buildings, areas, trees, props,
places); `Airport` adds itself to it, then `CityBuilder` drapes the lots, parks,
sidewalks, roads and lane markings over the ground and stands the buildings on it;
`Scenery` scatters trees and streetlights; `Terrain` builds the land itself. `World` runs
all of that in the right order.

## Layout

```
scripts/main.gd                 parked vehicles, getting in/out, waypoint, HUD updates
scripts/controls.gd             the input map
scripts/player/walker.gd        you, on foot
scripts/world/world.gd          builds the static world, in order
scripts/world/lighting.gd       sky, sun, fog, post
scripts/world/ground.gd         real elevation data: height lookups, leveled pads
scripts/world/city_gen.gd       generates the SLC-like city: grid, zones, buildings, parks
scripts/world/landmarks.gd      Temple Square, the Capitol, the arena, City & County Building
scripts/world/airport.gd        airfield west of I-15: runway, taxiway, hangar, tower
scripts/chase_camera.gd         follow/orbit cam, pulls in at walls, FOV widens with speed
scripts/hud.gd                  speed / street name / help text, owns the maps
scripts/ui/map_geometry.gd      map data -> one shared 2D mesh + street labels
scripts/ui/map_view.gd          heading-up minimap and full-screen waypoint map
scripts/world/city_builder.gd   map data -> lots, roads, markings draped on the ground; buildings + collision
scripts/world/scenery.gd        chunked MultiMesh trees and streetlights
scripts/world/terrain.gd        the land: city ground, valley, mountains, lake
shaders/building.gdshader       procedural facades (windows, curtain wall, brick, warehouse), storefronts, fake AO
scripts/world/street_index.gd   "what street am I on" spatial lookup
scripts/world/mesh_tiles.gd     splits big static meshes into cullable 500 m tiles
scripts/vehicles/vehicle.gd     base class: what main, the camera and the HUD can ask any vehicle
scripts/vehicles/ground_vehicle.gd  arcade car model on hills, spinning/steering wheels, body pitch/roll
scripts/vehicles/model_builder.gd   extrude/loft/lathe/tube toolkit for procedural low-poly vehicles
scripts/vehicles/frontier.gd    2008 Nissan Frontier NISMO crew cab
scripts/vehicles/sedan.gd       generic modern midsize sedan
scripts/vehicles/motorcycle.gd  middleweight naked bike; fork and bars steer on a raked head
scripts/vehicles/airplane.gd    arcade flight model
scripts/vehicles/plane_model.gd Cessna 172-style high-wing plane
scripts/audio/engine_sound.gd   synthesized engines and tire squeal (no audio files)
scripts/audio/sfx.gd            synthesized one-shots: doors, footsteps
tools/fetch_elevation.py        real DEM -> data/elevation_*.f32
```

## Known simplifications

- The city is SLC-like, not SLC: compressed grid, made-up buildings, one-runway airport.
- The land follows real elevation, but roads just lie on it: I-15 is at ground level, no
  bridges or overpasses. Only the city area is smooth enough to drive nicely.
- Sound is synthesized: engines, tire squeal, doors, footsteps. No music or radio.
- Vehicles are procedural low-poly with no interiors; the windows are opaque.
- No traffic, pedestrians, or day/night yet.
- Exports need `data/*.f32` added to the export's non-resource include filter.
- Performance budget (M1 Pro, Retina): the scene is GPU-bound at ~80 fps uncapped with
  defaults. SSAO (F3) costs ~6 ms even at its cheapest; SSIL cost more and is off. Depth
  mostly comes from the baked-looking AO in the building shader, aerial-perspective haze,
  and a warm-sun/cool-ambient split. Buildings and the road surface are split into 500 m
  tiles (`MeshTiles`) so off-screen and out-of-shadow-range parts get culled.

## Ideas for later

- Name it
- A radio
- Bigger map: Sugar House, the U, the Avenues, Great Salt Lake
- Helicopter, boat, lawnmower
- Ambient traffic, time of day, snow
