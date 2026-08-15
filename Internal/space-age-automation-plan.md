# Space Age Automation Plan

This file records the design for the automation and interplanetary logistics pass, under the shared rules in [space-age-compatibility-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-compatibility-plan.md).

It covers six connected systems that share one thesis: **the bureaucracy learns to run without biters, and the biters file about it.**

Nothing here is implemented yet. This is a design record, not a status report.

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

## Verification Gates

Two engine behaviours are unmeasured and are load-bearing. Neither can be settled by reading the codebase. Both should be tested in a real save before the dependent systems are built.

### Gate 1 — does spoilage tick inside a machine's module inventory?

The Unstaffed Operations Waiver is a module that spoils while installed. The existing spoilage precedent in this mod (briefed MMMMs, `prototypes/shared/manager_briefings.lua`) is an ordinary inventory, not a module slot.

- **If yes**: the waiver works as designed below.
- **If no**: the waiver needs a scripted expiry timer keyed on `unit_number`, which is a materially different build.

### Gate 2 — does Quality natively extend spoil time?

`spoil_ticks` is a prototype-level field and Quality is per-stack, so there is **no reasonable mod path** to per-quality spoil duration. This is native-or-nothing.

Supporting evidence that it is native: [README.md](~/Library/Application Support/factorio/mods/administratorio/README.md) already asserts it for briefings, and `scripts/quality.lua` contains no spoilage code at all — only `native_speed_multiplier` and `infrastructure_multiplier`.

- **If yes**: quality extends lifetime for all trained MMMMs (briefings and couriers alike), and the waiver runs 1h normal / 2.5h legendary.
- **If no**: every spoiling item gets one flat duration. The design survives — the Nauvis→Aquilo courier run is ~7.5 minutes of flight against a 30-minute budget — but the quality rule is dropped from the README and from principle expectations.

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

### 1.6 Required follow-up

`add_tech_prerequisite("promethium-science-pack", "aquilo-fax-network")` at `prototypes/technology/space_age.lua:970` must be re-pointed at the Aquilo colored tube tier. Without this the endgame gate silently loosens when the base tier moves earlier.

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

Precedents for hidden children in this codebase: `scripts/fax.lua:63` (combinator), the Biterport's hidden roboport (`scripts/constants.lua:225`), and `scripts/pneumatic.lua:308` (network pipe).

Known implementation cost: the hidden reactor's `heat_connections` must align with the visible footprint so heat pipes attach where players expect them.

### 2.3 Under-cooling is a hard stop

An AI Server that cannot dump its heat stops. Not a throttle. Signalled through `custom_status` with a red diode, matching the existing patterns in `scripts/working_hours.lua` and the biter station runtime.

### 2.4 The fan is a heat sink

The `lufter` becomes a **Heat Exhaust** using `type = "heat-interface"` with `mode = "at-most"`, which caps a heat network's temperature — a genuine vanilla heat void, no scripting.

This exists for players who want the compute without the power generation. Its presence must never be more efficient than actually using the heat.

### 2.5 The chain

```
electricity + training corpus  →  Inference Token  (+ heat)
Inference Token + substrate    →  Administrative Slop
Administrative Slop + blank    →  paperwork  (+ Fabricated Citations)
```

Training corpus should consume existing items — `dubious-data`, `data`, `useless-documentation` — so the Nauvis and Gleba nonsense economies feed Aquilo rather than being bypassed by it.

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

*Blocked on Verification Gate 1.*

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

### 3.3 Cost, spoilage, and reactivation

- Craft: all three base-planet specific ingredients plus tricolor paperwork
- Spoils to an **Expired Waiver** at 1h normal, 2.5h legendary
- Reactivated at Union HQ in the existing `union-negotiation` category, consuming `union-approval` fluid — cheaper than a fresh craft, so reactivation is the correct play

No new crafting category is needed: Union HQ already carries `{"union-negotiation", "bureaucracy-policy"}`.

### 3.4 The union notices

A building running on a waiver periodically files an automation grievance. See section 7.

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

## 7. The Automation Grievance Thread

A new complaint family, `ticket-automation` → `filing-a` → `case-a` → `brief-a` → `resolved-automation`, reusing the complete existing pipeline: Administration Desk queue, Resolution Office chain, frustration, protest retargeting, Taxpayer Money payout.

Four feeders:

- AI Servers running
- Unstaffed Operations Waivers installed
- Synthetic personnel manufactured
- Fabricated Citations left unhandled

The result: **the more of the biter economy is automated away, the more biter grievances are generated — and grievances can only be processed by the biter economy.** The endgame does not escape the mod's thesis; it is consumed by it.

This is data, not new systems. It is what makes six proposals one expansion rather than six bolt-ons.

---

## Stale Doctrine To Update

Deleting the fax network invalidates written doctrine outside this file. These need correcting or they will contradict this plan in future sessions:

- [space-age-aquilo-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-aquilo-plan.md) — **updated alongside this file**
- [space-age-compatibility-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-compatibility-plan.md) — principle 9 ("Faxing is reconstruction, not teleportation"), principle 14, the "Planned Aquilo Principles" section, and the Aquilo line in "Current Status" all still describe the fax network as Aquilo's capstone. **Not yet updated.**
- [README.md](~/Library/Application Support/factorio/mods/administratorio/README.md) — the Quality section promises "receivers also gain one queue slot per Quality level" and describes fax emitters and exchanges. **Not yet updated.**

## Open Questions

1. Does the AI Server export off Aquilo, or is it Aquilo-craftable only? Every other planet reward in this mod exports, but power draw would need to be brutal enough that Nauvis does not simply farm it.
2. Are Inference Tokens spendable anywhere beyond slop? The Administratorium slop tier is the primary sink; the cannon's transfer form and waiver reactivation are candidate secondary sinks. Tube postage was rejected because the base tube tier is pre-Aquilo and cannot cost a post-Aquilo currency.
3. Should synthesized specialists be identical to hired ones, or a distinct item that cannot be briefed as an MMMM?
4. Does the Terminus need one-per-planet uniqueness, as the fax receiver had?
5. What is the Heat Exhaust's dump rate relative to a server's output, and how many exhausts does one server need?
