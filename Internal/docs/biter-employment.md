# Biter Employment

## Biter Worker Hiring

When you resolve a biter's complaint with a **Job Offer** in the Biter Administration Desk inventory, the biter leaves as a **Biter Worker** item instead of paying taxpayer money.

### Worker Yield by Biter Type

| Biter Type | Workers Hired | Size Category |
| --- | --- | --- |
| Small biter / spitter | 1 | Small |
| Medium biter / spitter | 2 | Medium |
| Big biter / spitter | 3 | Large |
| Behemoth biter / spitter | 5 | Behemoth |

Larger biters produce more workers per hire. The worker item represents a pack of hired laborers.

## Biter Employment Office (Biter Station)

The `biter-station` (Biter Employment Office) dispatches workers to nearby managed machines, one authorized craft per visit. Without a worker on site, these managed buildings simply don't produce.

### Managed Buildings

The biter station manages these building types:

- `union-headquarters`
- `propaganda-distillery`
- `corporate-breakroom`
- `centrifuge`
- `oil-refinery`
- `printer-t2`

### How It Works

1. Place a `biter-station` building.
2. It reserves slots in the station inventory — base 10 slots (1 for taxpayer-money, 9 for biter-worker items).
3. Workers are dispatched from the station inventory to nearby managed buildings within a 30-tile radius.
4. Each worker visits a building, performs one craft (default), and returns.
5. Salary of 1 taxpayer-money per dispatch is deducted from the station.

### Capacity Upgrades

| Technology | Slot Count |
| --- | --- |
| Base | 10 |
| `biter-station-capacity-1` | 20 |
| `biter-station-capacity-2` | 30 |
| `biter-station-capacity-3` | 40 |
| `biter-station-capacity-4` | 50 |

### Worker Tier and Speed

The biter station has a crafts-per-visit upgrade that affects both worker entity appearance and salary:

- **Tier 1** (1-2 crafts): small-biter entity, salary 1
- **Tier 2** (3-4 crafts): biter-worker-t2 entity, salary 2
- **Tier 3** (5+ crafts): biter-worker-t3 entity, salary 3

### Night Shift

During night (30% of the day cycle, centered on midnight), the biter station requires liquid coffee to dispatch workers. Each night dispatch costs 5 liquid-coffee. A hidden coffee input entity handles this automatically when working hours is enabled.

### Status Messages

Hover over the biter station to see:

- **Calling worker en route...** — a worker is being dispatched
- **No biter workers in station** — station inventory is empty of worker items
- **No taxpayer funding** — station can't pay salary; needs taxpayer-money in inventory
- **No night-shift coffee** — it's night and no coffee is available
- **Waiting for worker** — idle, no pending jobs
- **X building(s) in zone** — how many managed buildings are in range

### Runtime Behavior

The station runs on a hidden "worker force" (`administratorio-biters`) with ceasefires against player, enemy, and neutral forces. Workers are small-biter entities with custom pathfinding, dispatched via go-to commands with distraction = none. They check for jobs, phase-travel to the target building, perform the craft, then return.

## Biterport

A roboport, but staffed by walking biters instead of flying robots. Progress.

### What It Does

The `biterport` provides logistic and construction support through a walking-worker network. It replaces robotic logistics with biter workers who walk between chests and construction sites.

### Core Systems

#### Worker Slots

Each biterport has a slot capacity that scales with research:

| Technology | Worker Slots |
| --- | --- |
| Base | 5 |
| `biterport-capacity-1` | 8 |
| `biterport-capacity-2` | 10 |
| `biterport-capacity-3` | 12 |
| `biterport-capacity-4` | 15 |

#### Transport Capacity

How many items a single worker can carry:

| Technology | Items per Worker |
| --- | --- |
| Base | 1 |
| `biterport-transport-capacity-1` | 2 |
| `biterport-transport-capacity-2` | 5 |
| `biterport-transport-capacity-3` | 10 |
| `biterport-transport-capacity-4` | 25 |

#### Worker Speed

Different biter entities for different speeds:

| Technology | Worker Entity |
| --- | --- |
| Base | `biterport-worker` |
| `biterport-worker-speed-1` | `biterport-worker-fast` |
| `biterport-worker-speed-2` | `biterport-worker-express` |

#### Logistics Network

Biterports connect via a network of hidden roboports. Workers phase-travel between ports. The network is detected by BFS through the hidden roboport entities.

#### Logistics Radius

Workers scan for requested items within 25 tiles and connection distance of 50 tiles.

#### Construction Radius

Workers can build within 55 tiles of their port.

#### Chest Types

The biterport connects to:

- Active/Passive Provider Chests
- Storage Chests
- Buffer Chests
- Requester Chests
- Logistic Chests (Active/Passive/Storage/Buffer/Requester)

#### Night Shift

Like the biter station, biterports require liquid coffee during night hours. Each night dispatch costs 5 liquid-coffee.

### How to Use

1. Build a `biterport`.
2. Connect chests (logistic or regular) to the biterport area.
3. Set up requester or provider patterns in chests.
4. Workers automatically handle item transport and construction.
5. Multiple biterports form networks that share workers.

### Important Differences from Vanilla Roboport

- Workers are walking entities, not flying robots.
- No construction robots — workers place ghost entities themselves.
- Chest-based logistics, not logistic network system.
- Workers can be overwhelmed if too many requests are active.
- True construction/logistic robotics (vanilla robots) are late-game, gated by utility science.

### Status Display

Hover over the biterport for network summary: X port(s), Y worker(s). Status messages include:

- **Calling worker en route...**
- **No logistics workers in port**
- **No taxpayer funding**
- **No night-shift coffee**
- **Waiting for job**
- **Reserved for logistics worker**

## Field Office

Early-game bureaucratic outpost that summons biters from nearby nests as one-per-craft-cycle workers.

### How It Works

1. Build a `field-office`.
2. It scans for nearby biter nests within 100 tiles.
3. When a recipe is queued, it summons a biter worker from the nearest spawner.
4. The biter walks to the office, stands on it, and the office produces at 1.0x speed with 0 pollution.
5. Each biter works for 5 crafts, then walks back to the spawner and is replaced.
6. At night, biters are released (unless overtime-exemption is installed).

### Behavior

- Only operates while a biter is physically present.
- Completely inactive otherwise.
- Does not call biters at night unless overtime-exemption.
- Status messages: "No biter nest in range", "Calling biter worker...", "Biter worker on site", "Working" overlay on the biter.
- Workers despawn 5 minutes after release.

### Use Case

Field Office bridges the gap between having no biter workers and having a fully staffed biter station. It lets you start producing at key buildings without hiring workers through complaint resolution first.
