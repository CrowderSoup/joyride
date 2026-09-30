# Roadmap

Where Joyride is and where it's headed. Update this as things land.

## What we're making

A cozy driving game in a city that feels like Salt Lake City, closer in spirit to
*The Simpsons: Hit & Run* than GTA: goofy locals with silly errands, stuff to smash for
coins, things tucked into every corner, and vehicles to unlock. No cops, no wanted
levels, no hurting anybody. Crashes are slapstick.

Ground rules that have served us well so far:

- Everything is built in code (models, city, sounds), no asset pipeline.
- The city is SLC-*like*: real street grid and real elevation, made-up buildings.
- Local flavor is where the jokes come from.

## Done

**Prototype**
- [x] Procedural SLC-like city: numbered grid from Temple Square, downtown towers,
      neighborhoods, warehouses along I-15, parks
- [x] Landmarks: Temple Square, the Capitol, the arena, City & County Building
- [x] Airport with runway, taxiway and the Joyride hangar
- [x] Four vehicles: Frontier NISMO, sedan, motorcycle, Cessna-style plane
- [x] On foot: walk up to anything and get in; vehicles stay where you leave them
- [x] HUD with street names, heading-up minimap, full map with waypoints
- [x] Arcade speed / altitude gauges, throttle bar, compass with waypoint bearings,
      flight horizon, and minimap with speed-based zoom and vehicle icons

**Foundations**
- [x] Real SLC elevation: State St climbs to the Capitol, the Avenues and east bench
      rise, the real Wasatch, Oquirrhs and Great Salt Lake around the valley
- [x] Driving on hills: gravity on slopes, coasting downhill, models sit flush
- [x] Walking relative to the camera; mouse / right-stick look
- [x] Camera pulls in at walls instead of clipping through
- [x] First / third person vehicle views (V / right-stick click), with driver-eye mounts
- [x] Terrain height, drawing and collision agree; entry checks height; parked vehicles
      only block prop respawns within their footprint
- [x] `Vehicle` base class; `main.gd` split into Controls / Lighting / World
- [x] Synthesized sound: engines per vehicle, tire squeal, doors, footsteps

**Smash & cash**
- [x] ~2,400 smashable props: hydrants (they gush), mailboxes, newspaper boxes,
      benches, trash cans, garbage bins, road-work cones
- [x] Coins spray out and fly to you; counter on the HUD; saved between sessions
- [x] Smashed stuff respawns once you're gone

## Next up

In order. Each one should be playable on its own.

1. **Hangar store.** Start with one vehicle (the sedan?). The others sit in their
   hangar bays with price tags; walk up and buy with coins. `Game` tracks what you
   own and saves it.
2. **First errand.** One quirky local with a couple of lines of dialogue and one silly
   job, paying coins. Build the errand framework (giver, objective, reward) around that
   one real case rather than up front.
3. **Kick things on foot.** Walk or run into props to smash them, like Hit & Run.

## Later

**Things to do**
- More errand types: deliver it before it melts, follow that car, race, collect N,
  catch the runaway (tumbleweed, seagull, escaped Jell-O)
- A cast of locals with running gags: fry sauce, inversion season, the lake smell,
  "oh my heck," parking downtown
- Collectibles hidden around town (rooftops the plane can reach, back lots, the
  Capitol steps) and gag cameras to ram
- Outfits and paint jobs to buy
- More vehicles: helicopter, boat, lawnmower

**The world**
- Extend the grid north into the Avenues and east to the U. The hills are there
  already, just no streets yet
- I-15 on bridges and overpasses instead of at ground level
- Ambient traffic and pedestrians (to dodge, not hit)
- Time of day; snow
- A radio

**Polish**
- Improve the synthesized sounds: listened to, playable, but underwhelming
- Name the game

## Known issues

- The plane stays level when it's on a slope away from the runway, and only its
  fuselage smashes things (the wings pass over).
- Godot prints "4 ObjectDB instances leaked" at exit. It's the engine's audio
  generators (reproduces in an empty project), harmless.
- An export would need `data/*.f32` in its non-resource include filter.
