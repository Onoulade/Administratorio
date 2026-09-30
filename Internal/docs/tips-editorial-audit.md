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

## Focused scenes

Three working layouts illustrate the text below them:

- Two ordinary chests and inserters feed opposite tube intakes. A central
  outtake unloads onto a visible belt. The only overlay reads actual tube stock.
- A regular small biter enters the native complaint redirect handler, walks to
  the boarding platform, and boards a stationary passenger wagon. A circuit
  briefly holds unboarding before the real unboarding code resets the loop.
- Deployment feeds three personnel types through a multisign to three reception
  offices. Three ordinary constant combinators provide independent exit filters.
  The signed-path overview and multisign tip share this layout.

Production control scripts handle transport, pathfinding, reservations and
boarding. Scene maintenance only replenishes inputs, clears delivered cargo,
introduces visitors, and toggles the unboarding circuit. There are no staged
movements, fake transfers, extra captions, or illustration-only floating icons.
Generated terrain and normal platform placement-grid coordinates let the native
unit pathfinder reach the boarding center. Camera framing keeps tube power out
of view and all three path exits visible.

An isolated Factorio 2.0.77 save ran the exact scene initialization and maintenance
for 3,601 updates: 20 items from each tube source reached the belt, 20 visitors
boarded, and each filtered path delivered 13 of its matching personnel type.
The live stock readout observed real nonempty network contents. The focused Lua
checks and base/Space Age/Working Hours startup matrix pass. All three layouts
were inspected in the actual Tips window; a QA-only observer confirmed repeated
passenger loops there as well.

## Progression timing

Only the welcome guide is visible at the start. Every other guide uses native
recipe-availability or research conditions, with no read-before-unlock dependency.
Placement instructions now appear before construction, rather than waiting for
a build event that may already have happened in an existing game.

- Field Office placement: its recipe unlock at Steam Power.
- Complaint service, routing, frustration, Hard Mode and evolution approvals:
  the Admin Station recipe unlock at Field Office Deployment.
- Working Hours: the first available night-sensitive desk or dispatch building.
  Administrative Clock: its own recipe unlock.
- Worker dispatch, managed machines and stranded workers: Biter Employment Office
  or Biterport Logistics, as applicable.
- Circuit-only guides: both their system and Circuit Network must be available.
  Basic setup guides remain available before circuit research.
- Planetary funding: the first planet discovery, in time to prepare an outpost.
  Space Platform alone is too early.
- Signed-path spoilage: signed paths plus manager briefings or egg couriers.
  Egg couriers and relocation belong to the workforce category so unrelated
  interplanetary tube research cannot hide them.

All other guides were checked against the finalized recipe unlocks, including
recipe renames, hidden effects and independent research branches. The engine
audit covers every active tip and verifies that its category is already visible.
Across the supported startup profiles it checks 31 base-game tips in 815
progression states, 57 Space Age tips in 1,670 states, and 54 Space Age tips without
Working Hours in 1,662 states. States include new games, branch prerequisites,
completed research, and branches combined with circuits or manager briefings.

Validation: `lua tests/test_tips_and_tricks.lua` and
`python3 tests/test_factorio_tip_unlocks.py --factorio-bin <Factorio executable>`.
