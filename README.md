# EntityLib

Client-side entity tracking and perception library for Roblox.

EntityLib provides a unified, cached representation of players and NPCs on the client, with fast spatial queries and perception helpers (distance, FOV, line of sight).

Pure Lua. Client-only. Zero idle cost.

---

## What it does

- Tracks player characters and NPC models as entities
- Caches Humanoid and HumanoidRootPart references
- Provides fast spatial queries (nearby, closest, enemies)
- Supports perception logic (FOV, line of sight, visibility)
- Integrates cleanly with TeamManager (if present)
- Emits lifecycle events when entities are added or removed

---

## What it does NOT do

- It does not replicate data
- It does not control entities
- It does not run per-frame logic by default
- It does not enforce server authority

EntityLib is a client-side perception and query layer.

---

## Setup

Load EntityLib using HttpGet:

```lua
local EntityLib = loadstring(game:HttpGet(
    "https://raw.githubusercontent.com/rconsoIe/EntityLib/refs/heads/main/loader.lua"
))()

-- Optional version selection:

-- EntityLib.version = "v1.1.0"

EntityLib = EntityLib.init()
```

If no version is specified, the latest version is loaded by default. `(Note: most functions require version 1.1.0)`

---

## Core concepts

### Entity

An entity is a cached table representing a character or NPC:

- Player characters
- NPCs (Models with a Humanoid)

Each entity contains:
- id
- model
- player (nil for NPCs)
- humanoid
- hrp (HumanoidRootPart)
- isNPC

Entities are created once and cleaned up automatically.

---

## Basic API

### EntityLib.getAll

Returns all tracked entities.

```lua
EntityLib.getAll()
```

---

### EntityLib.fromModel

Returns the entity associated with a model.

```lua
EntityLib.fromModel(model)
```

---

### EntityLib.fromPlayer

Returns the entity associated with a player’s character.

```lua
EntityLib.fromPlayer(player)
```

---

### EntityLib.getById

Returns an entity by its unique id.

```lua
EntityLib.getById(id)
```

---

### EntityLib.isAlive

Checks whether an entity is alive.

```lua
EntityLib.isAlive(entity)
```

Returns true or false.

---

### EntityLib.getPosition

Returns the world position of an entity.

```lua
EntityLib.getPosition(entity)
```

---

## Spatial queries

All spatial queries are:
- distance-based
- computed on demand
- free of per-frame cost

---

### EntityLib.getNearby

Returns all entities within a radius.

```lua
EntityLib.getNearby(radius, angle)
```

- radius: distance in studs
- angle (optional): FOV cone in degrees

---

### EntityLib.getEnemiesNearby

Returns nearby enemy entities.

```lua
EntityLib.getEnemiesNearby(radius, angle)
```

Enemies are determined via TeamManager when available.
NPCs are always treated as enemies.

---

### EntityLib.getClosest

Returns the closest entity within range.

```lua
EntityLib.getClosest(radius, angle)
```

Returns a single entity or nil.

---

### EntityLib.getNearestEnemy

Returns the nearest enemy entity.

```lua
EntityLib.getNearestEnemy(radius, angle)
```

---

### EntityLib.getEntitiesInBox

Returns entities inside a box volume.

```lua
EntityLib.getEntitiesInBox(cframe, size)
```

Useful for hitboxes, zones, and triggers.

---

## Perception helpers (v1.1)

EntityLib includes perception utilities built on real geometry.

---

### EntityLib.hasLineOfSight

Checks if the entity is unobstructed from the camera or player.

```lua
EntityLib.hasLineOfSight(entity)
```

Uses Raycast with proper filtering.

---

### EntityLib.isVisible

Checks if an entity is visible to the player.

```lua
EntityLib.isVisible(entity, angle)
```

Visibility = FOV check + line of sight.

---

### EntityLib.getVisible

Returns all visible entities within range.

```lua
EntityLib.getVisible(radius, angle)
```

---

### EntityLib.getNearestVisibleEnemy

Returns the nearest visible enemy.

```lua
EntityLib.getNearestVisibleEnemy(radius, angle)
```

Combines:
- distance
- FOV
- line of sight
- enemy check

---

## Lifecycle events

### EntityLib.onAdded

Called when an entity is created.

```lua
EntityLib.onAdded(callback)
```

Callback signature:

```lua
callback(entity)
```

---

### EntityLib.onRemoved

Called when an entity is removed.

```lua
EntityLib.onRemoved(callback)
```

Callback signature:

```lua
callback(entity)
```

---

## NPC support

EntityLib automatically tracks NPCs:

- Any Model added to Workspace
- Must contain a Humanoid
- Must contain a HumanoidRootPart

NPC entities:
- have entity.player == nil
- have entity.isNPC == true
- are treated as enemies by default

---

## Team integration

If TeamManager is present:
- Player entities respect team relationships
- Enemy checks use TeamManager.isEnemy

If TeamManager is not present:
- Player enemies are ignored
- NPCs are still considered enemies

EntityLib works with or without TeamManager.

---

## Performance notes

- No Heartbeat usage by default
- No Workspace scanning loops
- No repeated FindFirstChild calls
- Squared-distance math (no sqrt)
- All queries are O(n) on demand

Designed for combat systems, targeting, ESP, and AI perception.

---

## Recommended usage

Use EntityLib for:
- hitbox targeting
- nearest enemy selection
- visibility checks
- ESP / overlays
- AI awareness
- client-side combat logic

Avoid using EntityLib for:
- server validation
- security checks
- authoritative decisions

---

## Example (combat targeting)

```lua
local target = EntityLib.getNearestVisibleEnemy(40, 90)
if target then
    print("target entity:", target.id)
end
```

---

## Design goals

- Minimal API
- Predictable behavior
- Zero idle cost
- Clean integration with other client libraries

EntityLib is designed to work alongside:
- Packets
- Scheduler
- Signals
- TeamManager

---

## Notes

- Listener execution order is not guaranteed
- Visibility uses camera direction when available
- All helpers are synchronous
- Keep callbacks lightweight
