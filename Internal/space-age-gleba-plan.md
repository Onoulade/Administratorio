# Gleba Space Age Plan

This file records the planned Gleba principles under the shared rules in [space-age-compatibility-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-compatibility-plan.md).

## Planet Role

Gleba is the biological exception-handling planet.

Its themes are:

- biological nonsense instead of policy nonsense
- calming, luring, intake, and reassignment instead of direct force
- biosafety and personnel paperwork
- short-lived, perishable exception handling instead of durable industrial certification
- high-leverage one-target-at-a-time interaction rather than bulk office throughput

Its local reward pair is the `Capture Bureau` plus the `Conciliation Desk`.

## Planned Design Principles

### 1. Use Gleba's actual vanilla strengths first

Gleba should not get fake bootstrap replacements for things it already does well.

The intended base is:

- paper stays local through greenhouse wood
- coffee stays local through greenhouse agriculture
- vanilla organic substitutes such as jelly-based rocket fuel remain first-class
- the new Gleba layer should sit on top of that, not replace it

### 2. Add only one new raw resource

Gleba should get exactly one new raw resource:

- `amber-sap` from `amber-sap-seep`

That resource should do the planet-defining work:

- make local `bullshit-ore` cheap in an indirect, biological way
- make `dubious-data` practical as a derivative
- feed yellow paperwork
- never make local `lie` or local `redundant-rubble` trivial

The point is not "Gleba mines bullshit ore." The point is "Gleba grows a strange fluid that lets you cheaply precipitate nonsense."

### 3. Gleba should be escape-viable, not mall-self-sufficient

Gleba should be able to reach spaceship escape, but it should not become a full standalone replacement for Nauvis logistics.

Intended behavior:

- selected launch-critical paperwork bottlenecks are eased locally
- ordinary factory expansion should still run into the lack of direct `lie` and `redundant-rubble`
- building a mall or a broad generic factory should still reward imports and normal form-copy workflows
- if a copyable form only needs a seed, import one and black-copy it rather than localizing a dead-end bureaucracy branch

### 4. Do not duplicate vanilla output recipes

Gleba should not get a second set of `-gleba` recipes for ordinary vanilla outputs just to force local self-sufficiency.

The preferred pattern is:

- keep vanilla items and buildings on their ordinary recipes
- add new Gleba items, new Gleba forms, and new Gleba buildings
- let those new items feed selected administrative shortcuts rather than cloning `rocket-silo`, `advanced-circuit`, or every office building
- put planet-specific behavior on the new content, not by forking the whole recipe graph

### 5. Keep the machine split strict

The Gleba split should stay narrow and readable:

- the `Chromatic Printer` prints yellow stock and blank yellow stationery
- the `Capture Bureau` is the hostile-intake building and should integrate with the biter-handling loop
- the `Conciliation Desk` finalizes the actual yellow exception paperwork

The desk should stay:

- slow
- one-role
- support-heavy
- specialized

### 6. Yellow paperwork should be perishable

Gleba-special paperwork should feel alive and temporary.

Planned rule:

- `mycelial-form-stock` spoils back into `paper`
- `blank-yellow-form` spoils back into `paper`
- finalized Gleba yellow paperwork also spoils back into `paper`
- these forms should reward just-in-time use rather than stockpiling

This is the main place where Gleba should feel visibly different from Vulcanus and Nauvis.

### 7. Black ink remains the general copy medium

Gleba should not replace the global copy rules.

That means:

- ordinary copy chains stay black-ink based
- yellow paperwork is not a universal copier
- yellow paperwork is for Gleba-specific exceptions, not for bulk duplication

### 8. Gleba shortcuts should stay narrow and biological

Gleba's special forms should be good at:

- pacification
- biosafety
- hostile-intake handling
- reassignment
- `biochamber`-adjacent authorization

They should not become universal better versions of generic management paperwork.

### 9. Yellow forms gate carbon fiber usage everywhere

Any recipe that consumes carbon fiber must also consume a yellow form as an ingredient. This is the primary mechanism making Gleba's ink production essential even on Nauvis and other planets.

On Gleba, yellow forms are cheap and locally produced (but perishable). Off-world, they must be shipped, creating natural export pressure — and their spoilage means the player must manage logistics carefully.

### 10. Buildings require workers but no operating paperwork

Both `Capture Bureau` and `Conciliation Desk` require a `conciliation-officer` worker to craft but no operating paperwork. Current implementation makes the Nauvis workforce seed portable: once the player has worker/trainee stock, a Formation Center, and agricultural science, `conciliation-officer-formation` can happen anywhere rather than requiring a return trip to Nauvis.

### 11. Tax evasion applies — no taxpayer money

Gleba recipes should not require `taxpayer-money`. The planet operates outside the Nauvis tax authority's reach. Local paperwork uses biological resources and yellow ink instead of cash.

## Planned Paperwork Family

The family should stay compact and purposeful.

Working names and roles:

- `mycelial-form-stock`: local yellow paperwork stock
- `blank-yellow-form`: yellow substrate for final paperwork
- `symbiosis-record`: registry and bookkeeping form for local biological handling
- `conciliation-order`: narrow exception-order form for living-target and facility handling
- `biochamber-operating-waiver`: build-time or process-time biochamber permission

All of these should be short-lived and spoil back into `paper`.

## Planned Enemy And Workforce Loop

Gleba should be the planet where hostile biology becomes administratively tractable.

The building split should support two related loops:

- `Capture Bureau` handles local intake, capture, and the hostile-to-bureaucratic transition
- `Conciliation Desk` turns that local control into paperwork value and selected export paperwork

The intended character of the loop is:

- lure a living target
- process one target at a time
- require actual staffing, including `worker-biter` where appropriate
- produce a useful biological or staffing output
- also produce Gleba-native paperwork value

The loop should feel like a targeted premium shortcut, not an infinite free labor machine.

## Export Identity

Gleba's exported value should center on:

- `bullshit-ore` and derived `dubious-data`
- luring and calming consumables
- hostile-intake infrastructure
- personnel conversion paperwork
- biosafety waivers
- `biochamber` operating permissions

This makes Gleba the natural home for biological exception handling and satirical workforce reassignment.

## Constraints For Future Implementation

- Keep the `Conciliation Desk` slow and specialized.
- Do not solve the planet by inventing a local `taxpayer-money` economy.
- Do not let yellow paperwork replace standard black-ink copy logic.
- Do not fork ordinary vanilla outputs into a Gleba clone ladder.
- Use import-seeding for copyable dead-end forms instead of bloating the local tree.
- Preserve the sense that Gleba handles living problems unusually well, rather than handling every paperwork problem well.

## Building Requirements

- `Capture Bureau`: requires 1x `conciliation-officer` worker to craft, no operating paperwork
- `Conciliation Desk`: requires 1x `conciliation-officer` worker to craft, no operating paperwork
- Both buildings should include biological/organic components in their crafting recipes
- Surface-limited crafting to Gleba only

## Open Questions

1. Which generic administrative bottlenecks should stay intentionally imported on the escape path so Gleba does not over-localize?
2. What spoil times feel good for yellow stock, yellow blanks, and finalized yellow forms?
3. Which off-world labor or biosafety recipes should require Gleba paperwork variants first?
