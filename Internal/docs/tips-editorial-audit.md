# Tips & Tricks editorial audit — 2026-09-30

The tips now teach player actions and custom rules. They do not reproduce recipe
catalogs, research tables, vanilla tutorials, or planet packing lists.

Decisions confirmed with the user:

- Remove entries with no custom behavior; keep recipes and stats in Factoriopedia.
- Split complex systems into short setup, routing, and control tasks.
- Preserve distances and thresholds that affect layouts and decisions.
- Explain the 256-tile service search and 96-tile waiting movement; omit the
  random second/third-nearest roaming algorithm.
- Include custom Quality behavior and optional Hard Mode; omit mod compatibility.

## Coverage and source checks

| Topic | Rules retained or corrected | Implementation checked |
| --- | --- | --- |
| Complaints | Shared desk inventory, all complaints required, reserved slots, complaint signals | `scripts/biters.lua`, `scripts/zones.lua` |
| Visitor routing | 256-tile local search, full/idle destinations retain local search, 96-tile waiting movement | `scripts/biters.lua`, `scripts/passenger_trains.lua` |
| Evolution approvals | Research caps growth and locks larger sizes; no banked growth; Gleba excluded | `scripts/evolution_gating.lua`, `prototypes/shared/evolution_milestones.lua` |
| Frustration | Desk-bound travel pauses deadline; promises preserve cases; optional attack escalation | `scripts/biters_protests.lua`, `scripts/constants.lua` |
| Nest placement | Actual build/prebuild calls use the general 32-tile exclusion, including Capture Bureau | `control.lua` |
| Field Offices | 200-tile normal reach, shared 10-worker nest leases, 2 crafts, physical travel | `scripts/field_office.lua`, `prototypes/shared/gameplay_facts.lua` |
| Hiring | Base size yields versus Nauvis biter-only Space Age enrollment odds | `scripts/biters.lua`, `scripts/constants.lua` |
| Worker visits | Specific five-machine list, nearest-station ownership, 30-tile range, reuse and salary | `scripts/biter_station.lua`, `prototypes/shared/biter_station_buildings.lua` |
| Biterports | Square coverage, fixed 50-per-axis links, separate speed/capacity research, cargo preservation | `scripts/biterport.lua`, `scripts/biterport_storage_wait.lua` |
| Stranded workers | Compatible home, inventory space, blocked-route retries, frustration | `scripts/orphaned_worker.lua` |
| Mounts and agents | Funding expiry, patrol radius, notice capacity, remote and resupply actions | `scripts/rideable_biter.lua`, `scripts/hired_biter.lua` |
| Night work | Permanent module for Office Desk/Union HQ, 5 coffee per dispatch, clock signals | `scripts/working_hours.lua`, `scripts/administrative_clock.lua`, `prototypes/shared/gameplay_facts.lua` |
| Local tubes | Inserter-fed intake, slot-filtered outtake, mixed pool, 120-tile reach, filtered pump boundaries | `scripts/pneumatic.lua`, `prototypes/entity/pneumatic.lua` |
| Tube circuits | Pool signals on both colors, intake enable condition, duplicate signal sources | `scripts/pneumatic.lua` |
| Rail geometry | Rail 2.75, wagon center 4, stop 24, boarder center 0.85 tiles; 24 seats/queue | `scripts/passenger_trains.lua` |
| Rail operation | Prequeue signal, no boarding hard-close signal, unboarding hold, 3-leg limit | `scripts/passenger_trains.lua`, `scripts/biters.lua` |
| Rail outputs | Platform = wagon; stop = train; combining their outputs duplicates counts | `scripts/passenger_trains.lua` |
| Transit permits | Stock count sets train limit; manual/circuit limits overridden; public stop exemption | `scripts/trains.lua` |
| Signed paths | 2×2 alignment, next-segment routing, protected occupied lanes, rotation reservations | `scripts/personnel_routing.lua`, `scripts/personnel_route_graph.lua`, `scripts/personnel_traffic.lua` |
| Path controls | Immediate incoming-segment counts; manual/circuit filters; left/straight/right priority without fallback | `scripts/personnel_signals.lua`, `prototypes/shared/personnel_routing.lua` |
| Path spoilage | Half-speed expiry even in queues; expired manager changes subsequent filter match | `scripts/personnel_routing.lua` |
| Specialists/managers | Craft-time staffing, timed reusable briefings, chassis approval/mining behavior | `prototypes/recipe/space_age.lua`, `prototypes/shared/specialist_approvals.lua` |
| Unstaffed waiver | Permanent module, immediate removal behavior, no recipe/protest bypass | `scripts/biter_station.lua` |
| Quality | Field reach/Biterport coverage scale; links and station reach fixed; transport preserves quality | `scripts/quality.lua`, `scripts/field_office.lua`, `scripts/biterport.lua`, `prototypes/final_fixes/quality_integration.lua` |
| Asteroids | Deflection jurisdiction, protected staffed rocks, reserved miner slots, returning employees | `scripts/trajectory_compliance.lua` |
| Arbitration | Footprint overlaps territory; processing combines; interrupted progress regrows | `scripts/territorial_arbitration.lua` |
| Capture/eggs | Surface-specific lure modes, 48-tile capture range, idle drain versus per-capture cost, sampling cooldown | `scripts/biters.lua`, `scripts/pentapods.lua` |
| Tourism/funding | Expiring outbound package; orbital fulfillment; Nauvis checkout and revenue | `scripts/biters.lua`, `prototypes/recipe/space_age.lua` |
| Archive reassignment | Three independent 25% results, same rank, no new colors, no original input | `scripts/archive_recombination_rules.lua` |
| AI | Optical-only tokens, actual heat output, 950°C stop, byproduct handling | `scripts/ai_server.lua`, `scripts/heat_exhaust.lua`, `prototypes/shared/slop_rules.lua` |
| Interplanetary forms | Green continuous requests, red pool readout, quality match, output extraction, shared capacity includes unclaimed stock | `scripts/interplanetary_tube.lua` |
| Personnel relocation | Receiver-directed green request, red inventory readout, repeated batches and order cost | `scripts/relocation_cannon.lua` |
| Egg couriers | 30-minute expiry, input-slot aging, appropriate off-world staff | `prototypes/item/space_age.lua`, `prototypes/recipe/space_age.lua` |

## Removed or consolidated material

Removed dedicated catalogs for the economy chain, administrative science,
Propaganda Distillery recipes, colored inks/forms, bicolor research branches,
planet packing lists, Notary/Conciliation/Digital Services/Laser Printer recipes
and machine stats, orbital permits and office recipes, research prerequisites,
array tier/cadence tables, miner damage/capacity tables, trunk upgrade tables,
and Administratorium recipe shopping lists.

Unique behavior from those entries remains in the relevant task tips: staffing
and approvals, funding, manager reuse, asteroid jurisdiction and recovery,
colored trunk eligibility, tourism, and public train controls. Ordinary spoilage
and native research/crafting interfaces are left to the game and Factoriopedia.

Do not restore a Petition Counter guide based on residual locale/constants: it
has no active prototype/runtime implementation in this checkout. Do not use the
unused 24-tile Capture Bureau exclusion constant as proof of actual placement;
the current caller applies 32 tiles. No gameplay was changed in this audit.

## Validation

- Tips checks cover all eight Space Age / Working Hours / Quality combinations,
  early unlocks, category ownership, complete EN/FR/RU coverage, matching rich
  references, layout-critical measurements, and a 110-word editorial ceiling.
- Factorio startup matrix passes: base, Space Age, Space Age without Working Hours.
- Fresh Space Age data validates every active tip's rich-text reference and
  research target.
- Existing passenger (13), pneumatic (8), and Field Office (23) runtime tests pass.
- Full-repository locale parity has exactly the same 258 missing GUI keys in
  each of French and Russian at HEAD and in this worktree; none are tip keys.
- French tube and Biterport entries visually checked in Factorio 2.0.77: concise layout and rich links render correctly.
