# Space Age Compatibility Plan

This is the current canonical Space Age design plan for Administratorio.

It replaces older brainstorm versions and normalizes the current direction around:

- CMY bureaucracy: `cyan-ink`, `yellow-ink`, `magenta-ink`
- no fourth ink color on Aquilo
- one raw resource per planet
- one upgraded administrative building per planet
- any-order access for Vulcanus, Gleba, and Fulgora
- faxing as remote reconstruction rather than teleportation

Detailed planet breakdowns live in:

- [Vulcanus Plan](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-vulcanus-plan.md)
- [Gleba Plan](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-gleba-plan.md)
- [Fulgora Plan](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-fulgora-plan.md)
- [Aquilo Plan](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-aquilo-plan.md)
- [Public Finance Plan](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-public-finance-plan.md)
- [Professions Plan](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-professions-plan.md)

## Current Code Constraints

Space Age is currently blocked in [`info.json`](~/Library/Application Support/factorio/mods/administratorio/info.json) by `! space-age`.

The current mod architecture also imposes three important limits:

1. Complaint handling is runtime-heavy.
   Waiting biters, protests, frustration, desk reservations, and complaint inventories are tracked in Lua in [biters.lua](~/Library/Application Support/factorio/mods/administratorio/scripts/biters.lua) and [biters_protests.lua](~/Library/Application Support/factorio/mods/administratorio/scripts/biters_protests.lua).
2. The admin desk is inventory-constrained.
   The main station inventory is only 20 slots in [admin-buildings.lua](~/Library/Application Support/factorio/mods/administratorio/prototypes/entity/admin-buildings.lua), and it currently mixes complaint items, outputs, and payout.
3. Resolution is item-matching, not case-aware.
   The current runtime consumes one matching resolved item against one complaint item. It does not understand bundles, reserved outputs, or multi-target routing.

These constraints are why the Space Age direction should stay item-heavy and avoid multiplying live complaint state.

## Locked Design Rules

These are the current non-negotiable rules.

- No intermediate item should exist for only one recipe, except in a very rare joke or quest exception.
- Each planet gets exactly one new raw resource, item or fluid.
- Each planet gets exactly one upgraded administrative building with value outside its home planet.
- Vulcanus, Gleba, and Fulgora must be visitable in any order.
- Vanilla Space Age native buildings do not consume recurring work orders on their native recipe families.
- Planet-specific recipes require matching planet-specific paperwork and the appropriate chromatic inputs.
- Aquilo does not add a fourth ink color. The only primary bureaucratic colors are `cyan`, `yellow`, and `magenta`.

## Shared Progression Spine

The intended expansion spine is:

1. Unlock `Chromatic Printing`.
2. Visit any of `Vulcanus`, `Gleba`, or `Fulgora`.
3. Rebuild local paperwork through that planet's own chromatic route.
4. Export each planet's special intermediate and upgraded office building.
5. Build the fax network.
6. Convert recruited enemies into training, management, and orbital logistics.
7. Reach Aquilo for transfer-media printing and late high-speed bureaucracy.

This keeps the mod centered on documents, offices, queues, and logistics instead of combat reskins.

## Interstellar Public Finance

The current preferred money model is:

- raw `taxpayer-money` stays mostly sovereign to Nauvis
- the player should be able to export only small amounts directly, ideally through `money-case`
- offworld infrastructure should mostly consume compact derivatives such as `treasury-bond`, `government-grant`, and a dedicated `offworld-allocation`
- local planet paperwork loops should avoid raw `taxpayer-money` in their first self-sufficient stage
- large late-game money income should come from redeeming imported offworld goods and claims on Nauvis, not from printing raw cash in space

This gives money a central role in interstellar travel without turning every planet into a raw-cash sink.

The detailed candidate system lives in [space-age-public-finance-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-public-finance-plan.md).

The current workforce specialization draft lives in [space-age-professions-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-professions-plan.md).

## Shared Printing Model

### Printer Tiers

- `mechanical-printer`, `printer-t1`, and `printer-t2` stay black-ink printers.
- `Chromatic Printing` unlocks the `Chromatic Printer`.
- `Chromatic Printer` is the first machine allowed to print CMY paperwork and fulfill fax reconstruction jobs.
- `Laser Printer` is the late Aquilo speed reward. It is not the first color printer.

### Color Model

The bureaucracy color model is:

- `black-ink` remains the Nauvis baseline
- `cyan-ink` is the Vulcanus branch
- `yellow-ink` is the Gleba branch
- `magenta-ink` is the Fulgora branch
- Aquilo uses `thermal-transfer-sheet` and `composite-chroma-ribbon`, not a fourth color

Important consequence:

- some paperwork families are easier to produce on their home planet even when black ink is scarce or absent
- late premium paperwork can ask for two or three chromatic channels together
- there is never a `white-ink`

### Reconstruction Rule

Planet paperwork should not be a flat recolor recipe.

The target structure is:

1. local raw resource
2. pigment, toner, resin, or transfer stage
3. planet ink or transfer medium
4. local stock or draft layer
5. final paperwork family
6. exported intermediate or building unlocks

That gives each planet a distinct paperwork ecology and avoids `existing-paperwork + one ink = everything`.

## Planet Matrix

| Planet | Raw resource | Local color or medium | Shared intermediate(s) | Upgraded building | Local strength | Global export |
| --- | --- | --- | --- | --- | --- | --- |
| Vulcanus | `verdigris-crust` | `cyan-ink` | `embossed-seal`, `heatproof-form-stock` | `Notary Office` | permits, charters, land and industrial certification | productive non-printed paperwork |
| Gleba | `spore-resin` | `yellow-ink` | `conciliation-spores`, `symbiosis-record`, `mycelial-form-stock` | `Conciliation Desk` | enemy luring, biosafety, personnel simplification | recruitment and one-slot shortcut bureaucracy |
| Fulgora | `static-dust` | `magenta-ink` | `signal-toner`, `signal-form-stock` | `Interplanetary Fax Exchange` | directives, archive recovery, relay paperwork | interplanetary paperwork routing |
| Aquilo | `cryo-phosphor` | `thermal-transfer-sheet`, `composite-chroma-ribbon` | `thermal-transfer-sheet`, `composite-chroma-ribbon`, `cryo-form-stock` | `Laser Printer` | very fast print and copy throughput | fast local reconstruction and late mixed-planet paperwork |

## Building Identity Split

### Vulcanus: `Notary Office`

The `Notary Office` is the premium non-printing office.

It should handle:

- approvals
- charters
- permits
- grants and bonds
- personnel packets
- certification folders
- notarized dossiers

It should not handle:

- raw printing
- copy steps
- reprint steps
- anything that is clearly "paper goes through a printer"

The core reward is productivity on expensive administrative intermediates.

### Gleba: `Conciliation Desk`

The `Conciliation Desk` is a one-slot organic desk.

Its role is:

- lure one nearby enemy at a time
- process that enemy slowly through a euphemistic biological recipe
- export the same mechanism back to Nauvis as a recruitment and simplification shortcut

On Gleba its flagship recipe is `Voluntary Egg Reassignment`.

On Nauvis its flagship recipe is `Voluntary Workforce Reassignment`.

### Fulgora: `Interplanetary Fax Exchange`

The `Interplanetary Fax Exchange` is not a throughput assembler. It is a network hub.

Its role is:

- own the incoming fax queue for one surface
- expose that queue to local printers
- let the player route urgent paperwork to a planet or spaceship without physically shipping the finished form

There should be:

- many `Fax Sender` entities per surface
- exactly one `Interplanetary Fax Exchange` receiver per destination surface
- many local `Chromatic Printer` and `Laser Printer` entities attached to that receiver by circuit network

### Aquilo: `Laser Printer`

The `Laser Printer` is the late high-speed print building.

It should handle only explicit printing work:

- print stages
- copy stages
- reprint stages
- bulk blank forms
- fax reconstruction jobs

It should not handle the Notary Office recipe list.

Its main advantages are:

- speed
- no liquid-ink handling at point of print
- high-value use of `thermal-transfer-sheet` and `composite-chroma-ribbon`

## Any-Order Basic Planet Rule

Vulcanus, Gleba, and Fulgora are parallel first planets.

That means:

- their first viable local paperwork loops cannot require each other
- none of their upgraded buildings can be required to start another basic planet
- their local paperwork must be reconstructable from local resource plus imported Nauvis basics
- cross-planet paperwork should be an upgrade before Aquilo, not an access gate

Aquilo is allowed to be later and can intentionally depend on earlier chromatic infrastructure.

## Planet-Specific Paperwork Rule

Every planet-specific recipe should follow this logic:

- use the appropriate local paperwork
- use the appropriate local chromatic input
- add existing Nauvis administrative items where useful

Examples:

- Vulcanus industrial, zoning, and demolisher recipes use Vulcanus paperwork plus `cyan-ink`
- Gleba biosafety, conciliation, and luring recipes use Gleba paperwork plus `yellow-ink`
- Fulgora relay, archive, and routing recipes use Fulgora paperwork plus `magenta-ink`
- Aquilo cryogenic and transfer-print recipes use Aquilo paperwork plus `thermal-transfer-sheet` and, where appropriate, imported CMY

## Vanilla Space Age Building Rule

The following buildings should not consume recurring work orders for their native recipe families:

- `foundry`
- `biochamber`
- `electromagnetic assembler`
- `advanced chemical plant`

Instead, they should use one-time or build-time paperwork.

Recommended permit mapping:

- `foundry` -> `industrial-charter` and `lava-safety-endorsement`
- `biochamber` -> `biosafety-waiver` and `conciliation-order`
- `electromagnetic assembler` -> `signal-allocation-directive`
- `advanced chemical plant` -> `cryogenic-operations-license`

These are build-time thematic gates, not permanent taxes.

## Fax Network

### Functional Model

Faxing is remote reconstruction, not teleportation.

The intended behavior is:

1. A `Fax Sender` consumes a completed form.
2. The sender targets one destination surface.
3. Runtime writes a `fax_request` to that destination receiver queue.
4. The destination `Interplanetary Fax Exchange` exposes pending jobs on circuit.
5. A connected `Chromatic Printer` or `Laser Printer` claims a compatible job.
6. That printer consumes local materials and reconstructs the requested form.

### Destination Targeting

A destination can be:

- one planet surface
- one spaceship surface

This is technically plausible because both planets and spaceships are normal Factorio surfaces with stable runtime identifiers.

### Topology Rule

- many senders per surface are allowed
- one receiver per destination surface is allowed
- many printers may attach to that receiver

This mirrors the landing-pad pattern without turning the fax network into trivial infinite throughput.

### Ink Rule At Destination

The destination printer must have the correct materials for the document family being recreated.

Examples:

- a Vulcanus form needs `cyan-ink`
- a Gleba form needs `yellow-ink`
- a Fulgora form needs `magenta-ink`
- an Aquilo form needs `thermal-transfer-sheet` and, if the form is chromatic, the required CMY ribbon or inks

This is why already-made cross-planet forms are good fax targets. The network moves urgency, not free matter.

### Why Faxing Matters

Before Aquilo:

- foreign paperwork should mostly be nice-to-have upgrades
- faxing is already useful for urgent permits and relay forms

After Aquilo:

- mixed-planet paperwork should become common enough that faxing is strategically superior to moving every finished form by ship

This is the point where the fax network becomes a major quality-of-life and throughput tool instead of a novelty.

## Gleba And Nauvis Enemy / Workforce Loop

### Gleba

Pentapods should not imitate Nauvis complaint queues.

The preferred Gleba loop is:

1. Pentapods wander toward attractive organic infrastructure.
2. If ignored, they damage buildings directly.
3. A loaded `Conciliation Desk` attracts one nearby target.
4. The desk slowly processes that target through `Voluntary Egg Reassignment`.
5. The outputs are `pentapod-egg` and `symbiosis-record`.

Rotten eggs should still hatch ferals.

Those ferals should:

- remain able to damage buildings
- be calmable by `conciliation-spores` or related Gleba paperwork
- either despawn naturally or become lure-eligible for the desk

### Nauvis

The exported Gleba spore family should also work on Nauvis.

That lets the `Conciliation Desk` do:

- `Voluntary Workforce Reassignment` on nearby biters, spitters, and optionally protesters
- an ultra-slow emergency simplification recipe for one complaint at a time

The result is a premium shortcut machine, not a replacement for the main complaint economy.

### Satirical Management Sink

The cross-planet satire loop is:

- `enrolled-biter -> management-trainee -> middle-management-managing-manager`

Only a minority should branch into useful specialists such as astronauts or negotiators.

Most should become `middle-management-managing-manager`, abbreviated as `MMMM`.

`MMMM` then feeds the space asteroid system as a continuous consumable.

## Space Asteroid Loop

The approved non-weapon asteroid answer is:

- a platform building such as `trajectory-compliance-array`
- continuous consumption of `MMMM`
- failure mode when management supply dries up

The thematic joke is that middle management is burned out in pointless orbital oversight until the platform is safe again.

If direct asteroid deviation is technically awkward, the implementation can still be framed as deviation while using themed interception under the hood.

## Expected Multi-Use Intermediates

These are the current required multi-use intermediates.

- `embossed-seal`
- `heatproof-form-stock`
- `conciliation-spores`
- `symbiosis-record`
- `mycelial-form-stock`
- `signal-toner`
- `signal-form-stock`
- `thermal-transfer-sheet`
- `composite-chroma-ribbon`
- `cryo-form-stock`
- `money-case`
- `offworld-allocation`
- `cargo-manifest`
- `customs-appraisal`

Each of these should have at least three meaningful uses, with at least one offworld or late-game use.

## Technical Fit Review

### Strong Fits

- chromatic inks and local reconstruction routes
- the fax network
- planet-specific paperwork families
- one upgraded building per planet
- management as a continuous orbital consumable
- tier-3 modules as a repeatable trained-biter sink
- archive recovery on Fulgora

### Manageable But Scripted

- `Conciliation Desk` lure logic
- one-receiver-per-surface fax topology
- asteroid deviation backed by `MMMM`
- demolisher diplomacy or throughput bribery on Vulcanus

### Bad Fits To Avoid

- complaint spam measured in complaints per second
- per-biter accept or reject dialogue trees
- loose floor-item pickup as a primary gameplay system
- new planets that duplicate the Nauvis complaint runtime

## Technical Notes

### Data Stage Work

1. Remove `! space-age` from [info.json](~/Library/Application Support/factorio/mods/administratorio/info.json).
2. Add `Chromatic Printing` and `Chromatic Printer`.
3. Add one raw resource, one paperwork family, and one upgraded office building per planet.
4. Add new printing and non-printing recipe categories as needed.
5. Mark vanilla Space Age native recipes as exempt from recurring work orders on their native buildings.

### Runtime Work

1. Add `Conciliation Desk` target-claim and lure logic.
2. Add surface-scoped singleton logic for `Interplanetary Fax Exchange`.
3. Add a fax queue keyed by destination surface id.
4. Add printer claim and reconstruction logic for connected `Chromatic Printer` and `Laser Printer` entities.
5. Add `trajectory-compliance-array` drain and failure handling for `MMMM`.

### Likely Script Shapes

The most plausible technical shapes are:

- `Conciliation Desk` as an assembling-machine-like entity with scripted occupant targeting
- `Interplanetary Fax Exchange` as a scripted queue owner plus visible building
- fax printers as normal crafting entities with script-assigned reconstruction jobs
- `trajectory-compliance-array` as a continuous platform consumer with stock and timeout state

## Open Questions

These are still worth settling before implementation starts.

1. Should complaint-based enrollment remain the slow orthodox path on Nauvis, with spores as the premium shortcut?
2. Should `Voluntary Workforce Reassignment` work on all nearby biters and spitters, or only protesters and special cases?
3. How aggressive should the `Notary Office` productivity bonus be before it starts invalidating other admin chains?
4. Should fax targeting support both manual destination UI and circuit-signal control?
5. How should connected printers prioritize jobs around a receiver: first compatible, filtered by item signal, or both?
6. How much mixed-planet paperwork should exist before Aquilo, so faxing is valuable but first-visit loops remain open?
7. What is the cleanest direct implementation for demolisher diplomacy on Vulcanus?

## Recommended Implementation Order

### Phase 1

- remove the hard incompatibility
- add `Chromatic Printing`
- add `Chromatic Printer`
- make startup and progression safe under Space Age

### Phase 2

- add Vulcanus, Gleba, and Fulgora raw resources
- add their local paperwork reconstruction loops
- add their upgraded buildings

### Phase 3

- add `Fax Sender`
- add `Interplanetary Fax Exchange`
- add destination-printer reconstruction

### Phase 4

- add `Conciliation Desk` enemy handling
- add `Voluntary Workforce Reassignment`
- add `enrolled-biter -> management-trainee -> MMMM`
- add astronaut and specialist branches

### Phase 5

- add `space-office`
- add `trajectory-compliance-array`
- add Aquilo transfer-media printing and `Laser Printer`

## Final Direction

The safest strong Space Age version is:

- local chromatic bureaucracy
- any-order first planets
- one powerful administrative building per planet
- faxing as long-range paperwork reconstruction
- Gleba as one-slot lure bureaucracy rather than complaint spam
- recruited enemies converted into management, then burned in space

That direction stays in theme, is technically plausible, and avoids fighting the weakest parts of the current runtime.
