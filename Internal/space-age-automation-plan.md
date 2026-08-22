# Space Age Automation Plan

This file records the design for the automation and interplanetary logistics pass, under the shared rules in [space-age-compatibility-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-compatibility-plan.md).

It covers six connected systems that share one thesis: **the bureaucracy learns to run without biters.**

The original thesis ran "...and the biters file about it", carried by the automation grievance thread in section 7. That thread was cut during implementation: no new complaint families.

**Status: implemented.** All six systems are built. This file is retained as the design record; the notes below record the implementation decisions that survived review.

## Architecture

These systems share this document and nothing else. Being planned together is
not a reason to share code, constants, tick handlers, storage keys, or test
files, and anything that ends up shared must be justified by a real dependency
between the systems themselves.

Each one owns its own runtime module, its own constants block, its own tick
cadence chosen for its own behaviour, and its own tests. Where a module does
depend on another, it is because it genuinely handles that other system's
items -- the relocation cannon's cargo list reads the courier and briefing
rosters because it ships them -- never because the two appear in the same
section here.

## Scope

| System | Planet gate | Replaces or extends |
|---|---|---|
| Interplanetary Tube Network | pre-Aquilo, upgrades to Administratorium | **replaces the fax network entirely** |
| AI Servers and the slop economy | Aquilo | new |
| Unstaffed Operations Waiver | tricolor paperwork | extends the biter station gate |
| Synthetic Personnel Bureau | Administratorium | extends profession formation |
| Egg couriers | Nauvis training, offworld use | replaces all offworld biter-egg shipping |
| Involuntary Relocation Cannon | Aquilo | new |

## Development Posture

No Space Age save exists yet. This pass assumes **no backwards compatibility burden**: prototypes may be deleted outright, no migrations are required, and stale tests may be removed rather than adapted.

---

## Verification Notes

The early proposal gave the Unstaffed Operations Waiver a spoil timer inside a
machine module inventory. The implemented waiver is deliberately permanent:
it has no expiry, reactivation recipe, or hidden `unit_number` timer. That
removes an unverified engine dependency and makes its price and occupied
productivity slot the complete tradeoff.

Quality has no custom automation behaviour in this pass. Temporary briefings
and couriers retain their ordinary item behaviour; no balance rule here relies
on Quality changing a lifetime.

---

## 1. Interplanetary Tube Network

### 1.1 The fax network is deleted, not migrated

The existing fax implementation is removed outright. It is replaced by an interplanetary extension of the pneumatic tube identity the mod already owns.

Deletion scope:

- `scripts/fax.lua` (2,186 lines) and `scripts/fax_shared.lua` (415 lines)
- `tests/test_fax_runtime.lua`
- entities `fax-emitter`, `interplanetary-fax-exchange`, `fax-network-combinator`
- technologies `aquilo-fax-network`, `color-faxing`, `fax-queue-capacity-1/2/3`
- the per-document `faxed-document-reconstruction-*` recipe family
- signals `signal-fax-queue-size`, `signal-fax-free-slots`, `signal-fax-reserved-slots`
- associated locale, GUI strings, and tips entries

Reusable logic worth reading before rewriting rather than copying wholesale: per-planet endpoint uniqueness, circuit request collection, and quality-preserving transfer.

### 1.2 The trunk is a separate, narrow, slow pool

The local pneumatic network stays exactly as it is: instant, per-surface, capacity 10 → 25 → 50 → 100 → 200 via `pneumatic-capacity-1..4`, `TUBE_MAX_NETWORK_RADIUS = 120`.

The interplanetary trunk is a **distinct pool** and must never merge with it. Merging would produce free 200-capacity teleportation and delete rocket logistics.

### 1.3 Arrivals use explicit hand-off

Arrivals land in the Terminus building's own inventory. Moving them into the local pneumatic pool, onto a belt, or into a chest is the player's explicit step.

This is chosen over auto-feed because it gives:

- a visible buffer the player can reason about
- a circuit-readable contents list
- a natural place for the request UI
- genuine separation between the local and interplanetary pools

### 1.4 Two ladders, read together

| Tier | Capacity | Transit (per item) |
|---|---|---|
| base | 2–3 | 30 s |
| 2 | 5 | 15 s |
| 3 | 10 | 5 s |
| 4 | 15 | 2 s |
| 5 | 20 | 1 s |

Transit is **per item**, not per batch: each item carries its own timer and many may be in flight simultaneously.

The base tier deliberately opens at capacity 2–3 rather than 1. A single in-flight document empire-wide reads as a broken machine rather than as scarcity.

### 1.5 Technology placement

- **Base tier** prerequisites: `{pneumatic-capacity-2, cyan-yellow-bureaucracy}`, with a bicolor form as a research ingredient so the unlock is felt rather than merely listed.
- **Payload**: regular forms only at base tier. The existing `prototypes/shared/pneumatic_items.lua` list is already exactly this — ~80 black-ink paperwork, tickets, filings, cases, briefs, `paper`, `ink`, `taxpayer-money`, and **no colored forms or Space Age charters**. No new taxonomy work is required.
- **Colored tier**: unlocked on Aquilo, adds the chromatic set.
- **Upgrade tiers**: scale through to Administratorium.

### 1.6 Endgame prerequisite

`promethium-science-pack` now requires `interplanetary-tube-chromatic`, the
Aquilo colored tube tier. This preserves the endgame logistics gate after the
base trunk moved before Aquilo.

The Terminus building's staffing requirement must not be `cryoprint-technician` at base tier — that is an Aquilo-only profession, and a pre-Aquilo technology unlocking an unbuildable building is a bad first impression.

---

## 2. AI Servers and the Slop Economy

### 2.1 Recovered assets

Both art sets exist in git history and should be restored rather than recreated.

| Asset | Size | Recover with |
|---|---|---|
| `graphics/entities/endless-meeting/architectural-office.png` | 520×500 | `git show 108eabe:<path>` |
| `graphics/entities/endless-meeting/singularity-lab-shadow.png` | 548×482 | same |
| `graphics/icons/endless-meeting.png` | 64×64 | same |
| `graphics/entities/union-hq/lufter.png` | 473×459 | same |
| `graphics/icons/lufter-icon.png` | 64×64 | same |

The first set is a glowing compute core ringed by six industrial cooling turbines — deleted in `bf03de2` when the Meeting Room was removed. The second is a standalone radiator fan, deleted in `940cbce`.

The Meeting Room's six bespoke working sounds (`meeting-calm`, `meeting-debate`, `meeting-argument-1/2/3`, `meeting-argument-inside`) should be checked for in `sound/` and reused. A building that plays escalating argument loops while consuming power and producing text nobody reads is already thematically an AI server.

### 2.2 Heat is a hard requirement, and needs a composite entity

The AI Server must feed the **vanilla heat network** — real heat pipes, real heat exchangers, capable of unfreezing an Aquilo base and of driving steam power.

The engine constraint: **a single entity cannot both craft a recipe and emit heat.** `assembling-machine` has no heat output; `reactor` has no crafting.

Chosen architecture:

- visible **AI Server** is an `assembling-machine` with an electric energy source and large `energy_usage`
- a **hidden `reactor` child** at the same position carries the heat connections
- the runtime drives the child's `temperature` from the parent's crafting state

Precedents for hidden children in this codebase: the Biterport's hidden
roboport (`scripts/constants.lua:225`) and `scripts/pneumatic.lua:308`
(network pipe).

Known implementation cost: the hidden reactor's `heat_connections` must align with the visible footprint so heat pipes attach where players expect them.

### 2.3 Under-cooling is a hard stop

An AI Server that cannot dump its heat stops. Not a throttle. Signalled through `custom_status` with a red diode, matching the existing patterns in `scripts/working_hours.lua` and the biter station runtime.

### 2.4 The fan is a heat sink

The `lufter` becomes a **Heat Exhaust** using `type = "heat-interface"`. Its
hidden GUI cannot be edited, so runtime setup applies `mode = "at-most"` on
placement and rebuild; this caps a heat network's temperature and makes it a
genuine heat void rather than an accidental source.

This exists for players who want the compute without the power generation. Its presence must never be more efficient than actually using the heat.

### 2.5 The chain

```
electricity                    →  Inference Token  (+ heat)
Inference Token + substrate    →  Administrative Slop
Administrative Slop + blank    →  paperwork  (+ Fabricated Citations)
```

Electricity is deliberately the whole inference cost. Existing materials enter
at the Slop Refinery, where tokens combine with paper to form Administrative
Slop and then paperwork.

### 2.6 Slop tiering, derived from the taxonomy

`prototypes/shared/paperwork_taxonomy.lua` already carries `rank`, `family`, and `colors` per document. The generator reads it directly rather than maintaining a parallel list — the precedent is `generate_all_reassignments` in `scripts/archive_recombination_rules.lua:95`.

| Tier | Gate | Produces |
|---|---|---|
| base | Aquilo AI technology | rank 0–1, no colors |
| advanced | Administratorium | rank 2–3, no colors, huge token cost |
| never | — | anything with `colors`, and all 16 entries in `M.restricted_documents` |

**Colored paperwork is never producible from slop, at any tier.** This preserves the ink economy, the chromatic printer chain, and the planetary import loop that the whole Space Age pass rests on.

### 2.7 Hallucinations must be handled

Slop refining emits **Fabricated Citations** as an item byproduct — a reference that looks real and is not.

Handling has three outs, and all three should exist so the player has a choice:

- **vent** — wasteful, free, always available
- **fact-check** — consumes citations plus real paperwork, recovers `dubious-data` or `useless-documentation`
- **ignore** — the byproduct backs up and the server stalls

Volume scales with the **rank being slopped**. Rank 0–1 emits a trickle; the Administratorium rank 2–3 tier emits a flood. This is simultaneously the balance governor for the late tier and thematically exact: the harder the document, the more the machine invents.

---

## 3. Unstaffed Operations Waiver

### 3.1 Scope is exactly five buildings

`M.BITER_STATION_MANAGED_BUILDINGS` at `scripts/constants.lua:211`:

| Building | Module slots | Source |
|---|---|---|
| `propaganda-distillery` | 4 | `prototypes/entity/admin-buildings.lua:996` |
| `corporate-breakroom` | 3 | `prototypes/entity/admin-buildings.lua:782` |
| `centrifuge` | 4 | vanilla |
| `oil-refinery` | 3 | vanilla |
| `printer-t2` | 4 | inherited from `assembling-machine-3` deepcopy |

**All five already have module slots. No entity changes are required.** None restrict `allowed_module_categories`.

`capture-bureau`, `territorial-arbitration-post`, and `field-office` were checked and appear nowhere in `scripts/biter_station.lua`. They do not require worker-station visits to operate and are out of scope. Their zeroed `module_slots` are deliberate and should stay.

### 3.2 Implementation touch points

1. `prototypes/categories.lua` — a second `module-category` beside `night-work`
2. `prototypes/item/modules.lua` — module with `effect = {}`, mirroring `overtime-exemption`
3. `prototypes/recipe/modules.lua` — the recipe
4. `scripts/biter_station.lua` — a guard mirroring `has_overtime_exemption` at `scripts/working_hours.lua:73`, short-circuiting the deactivation at `:1467` and the visit requirement at `:986`

The waiver **occupies a productivity slot**. That implicit trade is a real cost the player feels, at no design expense.

### 3.3 Cost and permanence

- Craft: all three base-planet specific ingredients plus tricolor paperwork
- Permanent module: no spoilage and no reactivation path
- The occupied productivity slot and expensive multiversal craft are the
  continuing cost of automation

No new crafting category is needed: Union HQ already carries `{"union-negotiation", "bureaucracy-policy"}`.

---

## 4. Synthetic Personnel Bureau

*Administratorium tier.*

The building manufactures **professions**, not buildings. Four small recipes rather than thirteen duplicated building recipes.

| Profession | Currently required by |
|---|---|
| `licensed-notary` | `foundry` |
| `conciliation-officer` | `biochamber` |
| `relay-clerk` | `electromagnetic-plant` |
| `cryoprint-technician` | `cryogenic-plant` |

Source of truth is the `specialist_by_recipe` table at `prototypes/recipe/space_age.lua:1938`. The synthesis recipes derive from it so future professions are covered automatically.

Why this shape rather than duplicating building recipes:

- touches zero existing recipes, so no divergence risk
- does not double Factoriopedia entries or confuse planner mods
- covers professions added later without further work
- solves the actual pain: `worker-biter-formation` is Nauvis-bound, so today every specialist means a Nauvis round trip

Inputs are biter eggs plus tokens and slop. **Electricity is the intended constraint**, not ingredient rarity, keeping the Bureau tethered to the AI server's power bill.

---

## 5. Egg Couriers

### 5.1 Rule: biter eggs never leave Nauvis

Spoiled eggs hatch hostile biters (`spoil_to_trigger_result`, one biter per 25 eggs). Off Nauvis there is no Administration Desk, no complaint pipeline, and no way to handle them.

Every vanilla recipe consuming eggs is therefore rerouted. Vanilla egg costs are **preserved exactly** — only what crosses space changes.

| Recipe | Vanilla | New |
|---|---|---|
| `biolab` | 10 eggs | Nauvis-only craft |
| `nutrients-from-biter-egg` | 1 egg | Nauvis-only craft |
| `overgrowth-yumako-soil` | 10 eggs | Geotechnical courier, crafted on Gleba, courier **returned** |
| `overgrowth-jellynut-soil` | 10 eggs | Geotechnical courier, crafted on Gleba, courier **returned** |
| `captive-biter-spawner` | 10 eggs | Missionary courier, **consumed** |
| `promethium-science-pack` | 10 eggs | Cobaye courier, **consumed**, recipe batched ×10 |

### 5.2 The courier family

Three items, built as a `prototypes/shared/manager_couriers.lua` module mirroring `manager_briefings.lua` — same generation loop, shared egg overlay icon so players read them as one family.

| Courier | Trained from | Destination | Fate | Nauvis→dest |
|---|---|---|---|---|
| Missionary Manager | 10 eggs + MMMM | Aquilo | consumed | 45,000 km, ~7.5 min |
| Voluntary Research Subject (Cobaye) | 10 eggs + MMMM | orbit at Nauvis | consumed | trivial |
| Geotechnical Assessment Manager | 10 eggs + MMMM | Gleba | returns MMMM | 15,000 km, ~2.5 min |

Shared properties:

- trained **only on Nauvis**
- `spoil_ticks = 30 * 60 * 60`, `spoil_result = REGULAR_MANAGER` — an expired courier costs the eggs and the trip, never the manager
- quality extends lifetime, pending Gate 2

These are a distinct second class from the briefed MMMMs, not roster bloat: different source (eggs vs meetings), different duration (30 min vs 3 min), different purpose (crossing space vs local staffing).

### 5.3 The Administratorium loop is the vanilla loop

Vanilla's 30-minute egg timer already forces promethium science to be crafted near Nauvis: a platform flies out, collects chunks, returns, takes on fresh eggs, and crafts. The Cobaye preserves that constraint exactly.

The recipe is batched ×10:

```
250 promethium-asteroid-chunk + 10 quantum-processor + 1 Cobaye  →  100 Administratorium Science
energy_required: 5 → 50
```

**Cobaye weight: 200 kg.** This is not a tuned number — it is the existing trainee tier at `prototypes/final_fixes/rocket_weights.lua:150` (`clerical-trainee`, `union-delegate`, `chemical-operator`, `nuclear-technician`, `rideable-biter`), and it lands on exact vanilla rocket parity:

| Delivery | kg per science pack |
|---|---|
| vanilla, 10 eggs at 2 kg → 10 packs | 2.0 |
| Cobaye at 200 kg → 100 packs | 2.0 |

One rocket carries 5 Cobayes = 500 science packs = one full 500-count technology, exactly as vanilla.

### 5.4 Batching hazard: the input-slot trap

A batched craft needs 250 chunks and 10 quantum processors staged. **A Cobaye inserted before the chunks arrive burns its 30-minute clock inside the input slot and expires there.**

Correct play: stage chunks and processors first, deliver couriers last. This is a silent and expensive failure and warrants a tips-and-tricks entry.

Also worth checking at implementation: that the cryogenic plant stages 250 chunks comfortably rather than trickling.

### 5.5 Gleba return leg

Each soil craft hands back a 1-tonne MMMM on Gleba. Over time Gleba becomes a manager depot unless they are shipped back. This is a feature: it gives the cannon bidirectional traffic rather than a one-way pipe.

---

## 6. Involuntary Relocation Cannon

- **Planets only.** Space platforms are out of scope; the Cobaye reaches orbit by rocket at parity cost.
- A **regular building**, not a turret or projectile. No catapult prototype is involved.
- **Per-shot item count** payloads.
- Consumes a dedicated form, **one per item transferred**.
- Restricted to **biter-family cargo only** — this keeps rockets relevant for everything else and gives the cannon a clear identity.
- Available **before** the captive-biter-spawner is buildable, so the 30-minute Missionary window is survivable by design.

Its permanent job is the courier traffic: 1-tonne Missionary and Geotechnical managers outbound, spent MMMMs inbound. Framed as bureaucracy rather than artillery — biters and managers reassigned across the solar system because HR filed a transfer order.

---

## 7. The Automation Grievance Thread — **CUT**

Rejected during implementation: no new complaint families. `ticket-automation`,
`filing-a`, `case-a`, `brief-a`, and `resolved-automation` do not exist, and the
four feeders that would have filled them were removed with the family.

The consequence is recorded honestly: without this thread the six systems are
six independent additions rather than one expansion bound to the mod's thesis.
Nothing else in the pass depends on it.

If the binding is ever wanted back without new items, the four feeders could
instead raise an existing complaint — `ticket-unemployment` is the thematically
exact one — but that changes the balance of a complaint family that already
exists, and was not adopted.

---

## Stale Doctrine To Update

Deleting the fax network invalidates written doctrine outside this file. These need correcting or they will contradict this plan in future sessions:

- [space-age-aquilo-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-aquilo-plan.md) — **updated alongside this file**
- [space-age-compatibility-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-compatibility-plan.md) — **updated.** Principle 9 is now "The trunk is narrow and slow, not teleportation"; the planet matrix, Planned Aquilo Principles, specialist list, and Current Status all describe the tube trunk.
- [README.md](~/Library/Application Support/factorio/mods/administratorio/README.md) — **updated.** The fax queue-slot promise is gone; Quality now explicitly never widens the trunk, changes transit time, or grows a Terminus buffer.

## Open Questions — resolved during implementation

1. **Does the AI Server export off Aquilo?** Aquilo-craftable only (`surface_limited(..., "aquilo")`), matching the Laser Printer. Its 4 MW draw plus a mandatory heat network is already brutal, but keeping the build Aquilo-local avoids relying on the power bill alone to stop Nauvis farming it.
2. **Are Inference Tokens spendable beyond slop?** Yes, one secondary sink: the Synthetic Personnel Bureau consumes 4 per profession. The Administratorium slop tier remains the primary sink. The waiver is an expensive permanent module, and tube postage stayed rejected because the base trunk tier is pre-Aquilo.
3. **Are synthesised specialists identical to hired ones?** Identical — the synthesis recipes produce the same items the Nauvis formations do. A distinct item would have doubled every downstream check for no gameplay gain, and the Bureau's whole point is removing the Nauvis round trip rather than creating a parallel roster.
4. **Does the Terminus need one-per-planet uniqueness?** Yes, enforced in `scripts/interplanetary_tube.lua`. One endpoint per world is what keeps the trunk a trunk rather than a mesh, and it gives the arrivals buffer one obvious home. Placement on a second is refused and the building returned.
5. **What is the Heat Exhaust's dump rate?** 5 MW against a server producing 1/75 degree per tick into a 5 MJ/degree buffer: exactly 4 MW of heat at 60 ticks per second. One exhaust covers one server with modest headroom, so larger farms need proportional cooling rather than one fan deleting a planet's heat economy.
