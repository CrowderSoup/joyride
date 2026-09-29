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
| Walk / gas / brake+reverse | W / S (or arrows) | Left stick / RT / LT |
| Turn / steer | A / D | Left stick |
| Run (on foot) | Shift | X |
| Jump / handbrake (drift) | Space | A |
| Get in / get out (must be nearly stopped) | F | Y |
| Unstick vehicle in place; on foot: back to the hangar | R | Back |
| Map (click to set waypoint, right-click to clear) | M | Start |
| Toggle help | H | |
| Toggle ambient occlusion (pretty, but ~6 ms/frame on an M1) | F3 | |
| Quit | Esc | |

**Plane:** on the ground it drives like a car: W for gas, S to brake (hold S at a stop to
back up slowly), A/D to steer. Taxi out, line up on runway 35, hold W until the HUD says
"Hold S to lift off" (~63 mph), then hold S. In the air: W/S pitch (S pulls up), A/D roll,
Q/E rudder, Shift/Ctrl throttle. Banking turns you; let go and the wings level.

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
places); `Airport` adds itself to it, then `CityBuilder` builds the ground, lots, parks,
sidewalks, roads, lane markings and buildings; `Scenery` scatters trees and
streetlights; `Terrain` raises the Wasatch, the Capitol foothills and the Oquirrhs (all
pulled in closer than real life to frame the smaller city).

## Layout

```
scripts/main.gd                 input map, environment, parked vehicles, getting in/out, HUD updates
scripts/player/walker.gd        you, on foot
scripts/world/city_gen.gd       generates the SLC-like city: grid, zones, buildings, parks
scripts/world/landmarks.gd      Temple Square, the Capitol, the arena, City & County Building
scripts/world/airport.gd        airfield west of I-15: runway, taxiway, hangar, tower
scripts/chase_camera.gd         follow cam, FOV widens with speed
scripts/hud.gd                  speed / street name / help text, owns the maps
scripts/ui/map_geometry.gd      map data -> one shared 2D mesh + street labels
scripts/ui/map_view.gd          heading-up minimap and full-screen waypoint map
scripts/world/city_builder.gd   map data -> ground, roads, markings, buildings + collision
scripts/world/scenery.gd        chunked MultiMesh trees and streetlights
scripts/world/terrain.gd        low-poly noise mountains around the valley
shaders/building.gdshader       procedural facades (windows, curtain wall, brick, warehouse), storefronts, fake AO
scripts/world/street_index.gd   "what street am I on" spatial lookup
scripts/world/mesh_tiles.gd     splits big static meshes into cullable 500 m tiles
scripts/vehicles/ground_vehicle.gd  arcade car model, spinning/steering wheels, body pitch/roll
scripts/vehicles/model_builder.gd   profile-extrusion toolkit for procedural low-poly vehicles
scripts/vehicles/frontier.gd    2008 Nissan Frontier NISMO crew cab
scripts/vehicles/airplane.gd    arcade flight model
```

## Known simplifications

- The city is SLC-like, not SLC: compressed grid, made-up buildings, one-runway airport.
- The camera doesn't avoid walls yet, so it can clip through them when you walk along one.
- Everything is flat. No elevation, I-15 is at street level, no bridges.
- The Frontier is procedural low-poly; the sedan and motorcycle are still placeholder boxes.
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
- Bigger map: Sugar House, the U, the Avenues, Great Salt Lake
- Helicopter, boat, lawnmower
- Ambient traffic, time of day, snow
