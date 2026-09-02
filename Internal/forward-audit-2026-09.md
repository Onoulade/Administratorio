# Forward Audit — September 2026

This audit looks beyond reported defects toward structural risk, performance,
balance clarity, documentation drift, localization coverage, and deeper engine
validation. It is a prioritized working document, not a promise to ship every
candidate mechanic.

## Baseline

- Approximately 74,000 lines across runtime, prototypes, tests, and support code.
- 78 test/support files at the start of the audit.
- Real Factorio 2.0.77 startup succeeds in base-only, Space Age, Quality, and
  Working Hours configurations covered by the matrix.
- The Factorio-backed progression report now has zero hard structural failures.
- English has 2,113 shipped locale keys after removal of one obsolete debug row;
  French and Russian cover the same key set.
- The new control-stage smoke scenario exercises production event registration in
  the real engine. Previous files named `*_runtime` execute against Lua mocks.

## Repaired During This Audit

1. **Public Train Stop reload regression.** Build events skipped transit paperwork,
   but registry rebuilds called the lower-level setup function directly and added a
   permit chest. The exemption now lives at the shared setup boundary and has both
   mocked and real-engine coverage.
2. **Uncraftable handcraft routes.** The recent handcraft-preservation pass left
   canonical no-fluid recipes in Factorio's machine-only `advanced-crafting`
   category. They now use the character's actual `crafting` category. This removes
   the `engine-unit` hard failure from the live progression graph.
3. **Cross-force labor research leak.** Biter-station trip capacity and worker tier
   were serialized as one global maximum. They are now derived from the station's
   force at dispatch time; derived research state is no longer stored.
4. **Cross-force evolution notices.** The once-per-second warning pass evaluated
   only `game.forces.player`; it now evaluates every force and lets the existing
   eligibility guard discard irrelevant forces.
5. **Redundant hot-path cleanup.** Biter-station link sanitation ran inside the
   10-tick station update and again every 60 ticks. The duplicate pass and its dead
   profiler row were removed.
6. **Localization gaps.** Field Office hover text, complaint recovery, and the
   Administrative Certification retheme were missing from French and Russian.
   Locale parity and placeholder parity are now enforced automatically.
7. **Documentation drift.** Corrected Space Age/Quality compatibility, complaint
   counts, Field Office speed, Biter Employment Office inventory/capacity, labor
   efficiency tiers, Biterport tier count, managed-building membership, and the
   English Bureaucratic Transcendence description.

## Priority 1 — Confidence Before More Content

### Add save-based runtime and migration fixtures

The new engine scenario proves startup and event routing, but it does not yet prove
long-lived serialized state. Add small committed saves or deterministic scenario
builders for:

- Admin Station registration → waiting → resolution → payout → return;
- protest timeout, building shutdown, promise, and desk reassignment;
- Biter Employment Office dispatch, recipe completion, return, and station removal;
- Biterport provider/requester transfer and ghost construction;
- pneumatic intake/outtake transfer with circuit disable and network split/merge;
- Space Age fax, relocation, territorial arbitration, and trajectory compliance;
- loading at least one pre-current-version save through every supported migration.

Each scenario should write a compact machine-readable result and fail on a Lua
exception. Avoid asserting animation timing unless it affects state.

### Add deterministic performance scenarios

The runtime debug panel is useful for player reports, but there is no reproducible
budget. Create benchmark saves at small/medium/stress sizes and record:

- 50 / 250 / 1,000 waiting or protesting citizens;
- 25 / 100 / 500 Biterports plus representative chests and ghosts;
- 50 / 250 / 1,000 station-managed machines;
- large pneumatic networks undergoing steady transfer and topology changes;
- active asteroid staffing on several platforms.

Track average and high-percentile script update time rather than enforcing a brittle
wall-clock threshold on every developer machine. Use trend thresholds in CI once a
stable runner exists.

## Priority 2 — Architecture

### Split the largest behavioral modules by state ownership

The main maintenance risks are `scripts/biters_protests.lua` (~4,659 lines),
`scripts/biterport.lua` (~3,282), `control.lua` (~2,375), and
`scripts/biter_station.lua` (~2,146). Split by durable state and lifecycle, not by
arbitrary line count:

- protest target selection, routing/obstacle recovery, state transitions, and
  rendering/alerts;
- Biterport network topology, reservations, worker execution, construction, and
  presentation;
- control-stage storage/migration, entity lifecycle, player/UI events, and tick
  scheduling;
- station registry, dispatch planning, worker execution, and managed-machine runs.

Give each extracted module a narrow dependency table, following
`control_resolution_processing.new(deps)`. This makes engine objects replaceable in
tests without globally replacing `game`, `storage`, and `defines`.

### Version storage schemas explicitly

Runtime state is initialized defensively in many modules, but schema evolution is
distributed across configuration handlers and normalization functions. Add one
integer schema version per subsystem and idempotent migration steps. Derived values
such as research effects should be recomputed from forces, not serialized.

### Decide the multi-force support contract

Some systems iterate all forces, while ceasefires, protest searches, hired agents,
and several fallbacks explicitly target the force named `player`. Either:

- support multiple player forces and replace those assumptions with owning-force
  state plus relationship rules; or
- document that Administratorio supports cooperative play on the standard player
  force only, then add an early diagnostic for unsupported PvP scenarios.

Partial support is the most failure-prone state because it appears to work until
research, protests, or worker ownership diverges.

## Priority 3 — Performance Candidates

Measure these in the benchmark scenarios before changing cadence:

- `trajectory_compliance.on_tick` is registered every tick even when no assignments,
  deviations, assaults, arrays, or catapults exist. Maintain an active-work counter
  or dynamically register only while work exists if the empty cost is measurable.
- Biter-station updates inspect every managed building every 10 ticks, including
  waiver checks and registry sanitation. Shard stable registries or maintain dirty
  sets for module/recipe changes.
- Biterport dispatch rebuilds networks and scans job sources every 30 ticks. Cache
  topology by build/remove events and keep round-robin cursors for world scans.
- Selected-biter and Field Office hover refreshes share protest cadence. Refresh
  only open panels and avoid rebuilding invariant caption structures.
- Keep rebuild-time whole-surface scans in configuration/migration paths; do not
  move them into normal ticks.

## Priority 4 — Balance Questions Worth Instrumenting

These are hypotheses, not automatic nerfs:

- Complaint payout per filed ticket grows from 5 (small) to 7.5 (medium), about
  16.7 (big), and 25 (behemoth). This makes evolution a strong income multiplier in
  addition to adding deeper paperwork. Measure money earned per minute and desk
  occupancy by evolution band.
- Labor Efficiency jumps from 1 to 3 to 5 machine visits for the same salary. That
  cuts dispatch cost per authorization by 67% and then 80% versus base. Verify that
  this does not erase the intended taxpayer-money pressure too early.
- Field Offices provide salary-free, night-capable work at 0.5× speed for two
  crafts per borrowed citizen. Measure when players stop using them; if they remain
  dominant after formal employment, strengthen their geographic or throughput role
  distinction rather than applying a flat cost.
- Validate yellow-paper spoil times with real belt and train travel, not isolated
  recipe arithmetic.
- Review the staffed overtime alternate: it creates the same exemption item through
  a much more expensive recipe. It needs a clear logistical advantage or it is a
  decorative trap.
- `unified-operations-charter` has narrow demand for a capstone form. Prefer a few
  meaningful late recipes over blanket ingredient injection.

## Priority 5 — Progression Diagnostics To Resolve

The planet-escape analyzer also reports imports outside its policy for Gleba
(`coal`, `crude-oil`, `politician-fluid`, `processing-unit`, `redundant-rubble`,
and `rocket-fuel`) and for Vulcanus (`processing-unit` and `rocket-fuel`) under
the default rocket targets. The normal suite currently generates that report
without `--enforce-import-policy`. Decide whether those starts promise local
escape or only deadlock-free imported escape, then either repair the local
graphs or encode the intended imports and enforce the policy in the main suite.

The real-data report still lists direct unlocks that are not immediately usable.
They are informational because runtime sources, specialist staffing, and deliberate
later bureaucracy can make them valid. Review and classify each into an explicit
allowlist with a reason, or fix its prerequisite/unlock placement:

- Biolab and Captive Biter Spawner;
- Construction Robot;
- Heat Exchanger and Steam Turbine at Heating Tower;
- Mech Armor and Power Armor MK2;
- Nuclear Reactor and Centrifuge;
- Synthetic Personnel Bureau and Unstaffed Operations Waiver;
- senior/executive Trajectory Compliance Arrays;
- turbo belts, underground belts, and splitters.

Do not simply suppress the report. An allowlist entry should name the intended
runtime source or later gate so changed dependencies can still invalidate it.

## Mechanics That Fit, After Stability Work

1. **Player-facing compliance dashboard.** Promote a safe subset of the existing
   debug counts into an ordinary UI: unresolved complaint families, desk occupancy,
   protests, station coverage, salary burn, and paperwork consumption rate.
2. **Administrative audit trail.** A compact history of shutdown reasons and the
   last few consumed/failed permits would turn opaque stalls into solvable factory
   problems without removing the bureaucracy fantasy.
3. **Circuit observability.** Add consistent status/shortage signals for employment
   stations, Biterports, Field Offices, and interplanetary endpoints. Prefer signals
   over more bespoke GUIs so players can build their own control systems.
4. **Planetary public finance.** The existing design plan is thematically strong,
   but it adds several new intermediary nouns. Implement only if playtest telemetry
   shows taxpayer money becomes irrelevant off-world; start with one allocation and
   one redemption loop before adding customs appraisal and cargo manifests.
5. **Administrative incidents.** Rare, forecastable events such as inspection weeks
   or temporary filing-rule changes could vary mature factories. They should be
   opt-in or clearly telegraphed and must never invalidate a factory permanently.

## Documentation Strategy

The hand-written reference currently duplicates constants and technology facts and
has already drifted. Long term, generate tables for complaint counts/payouts,
building membership, capacities, and upgrade values from shared dependency-free Lua
modules. Keep prose hand-written; generate only factual tables. Add a release check
that rejects obsolete internal identifiers such as removed technology tiers.
