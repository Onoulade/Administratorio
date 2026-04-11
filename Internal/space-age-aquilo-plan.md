# Aquilo Space Age Plan

This file records the Aquilo principles and the current first-pass implementation under the shared rules in [space-age-compatibility-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-compatibility-plan.md).

## Planet Role

Aquilo is the interplanetary convergence and multicolor paperwork planet.

Its themes are:

- cryogenic handling and transfer media
- liquid ink freezes here — only solid transfer printing works
- the Interplanetary Fax Exchange as the capstone of cross-planet logistics
- multicolor composite forms that combine the work of multiple planets
- late-game paperwork unification rather than early bootstrap

Its global rewards are the `Laser Printer` and the `Interplanetary Fax Exchange`.

## Current Implementation Snapshot

The current codebase already ships a first Aquilo pass:

- `laser-printer`, `fax-emitter`, and `interplanetary-fax-exchange` are in-game and Aquilo-limited to craft
- `transfer-emulsion`, `thermal-transfer-sheet`, `composite-chroma-ribbon`, `composite-form`, `trichromatic-permit`, `unified-operations-charter`, and `cryogenic-operations-license` are implemented
- the runtime fax network already handles destination selection, per-planet receiver uniqueness, queue reservations, circuit reporting, quality-preserving reconstruction, and queue-safe stalling
- the current runtime reconstructs faxed paperwork directly inside the exchange logic and consumes generic `paper` plus `ink`
- the `Laser Printer` still carries the Aquilo print identity and `fax-reconstruction` category scaffolding, but the live fax runtime is not currently recipe-driven through it

## Planned Design Principles

### 1. Aquilo is not a first basic planet

Aquilo can assume earlier planetary progress.

That means its plan is allowed to assume:

- access to the chromatic printer family already exists somewhere
- CMY paperwork and forms can be imported
- multiple planet intermediates are already in the player's logistics network

Aquilo should therefore solve late convergence, multicolor unification, and fax logistics — not early bootstrap.

### 2. Liquid ink freezes on Aquilo

The Chromatic Printer uses liquid ink and cannot operate on Aquilo. The cryogenic conditions freeze all liquid inks (cyan, yellow, magenta, black).

This means:

- no Chromatic Printer on Aquilo
- no local ink production
- all colored forms must be imported from other planets
- the Laser Printer is the only printer, using solid transfer media instead of liquid ink

This constraint is the defining characteristic of Aquilo's paperwork identity: it consumes what others produce rather than competing with them.

### 3. Aquilo should not add a fourth ink

The Aquilo identity is not a new color. It is:

- transfer media (solid, toner-based)
- cryogenic stability
- premium reprint speed
- convergence of already-existing CMY paperwork into composite documents

This keeps the color model readable and reinforces the earlier planets rather than replacing them.

### 4. The Laser Printer owns fast final printing and multicolor work

The `Laser Printer` should be the best machine for:

- explicit final print steps
- multicolor composite form production
- rapid copy throughput
- premium Aquilo-side print throughput

It should not become the best machine for:

- dense certification work (that's the Notary Office)
- biological exception handling (that's the Conciliation Desk)
- general admin processing (that's the Digital Services Bureau)
- anything fundamentally belonging to another planet's office

The Laser Printer uses solid transfer media: `transfer-emulsion`, `thermal-transfer-sheet`, and `composite-chroma-ribbon` instead of liquid ink.

### 5. The Interplanetary Fax Exchange is Aquilo's administrative building

The `Interplanetary Fax Exchange` owns:

- queuing and routing of cross-planet document transfers
- first-pass runtime reconstruction of faxed documents
- destination management and priority handling
- coordination of paperwork flows between planets

It requires a `cryoprint-technician` worker to craft and no operating paperwork.

The fax network unlocking on Aquilo (not earlier) means:

- before Aquilo, players must physically ship all paperwork between planets
- this keeps the early game focused on local planet identity and real logistics
- Aquilo becomes the reward for reaching the final planet: your bureaucracy goes interplanetary
- faxing solves transport friction without deleting the value of each planet's specialization

### 6. Aquilo science unlocks multicolor form recipes

Aquilo research technologies unlock recipes for multicolor composite forms. These forms:

- are produced in the Laser Printer using solid transfer media
- require imported colored forms or transfer media derived from 2-3 other planets
- gate late-game recipes that consume intermediates from multiple planets
- represent the bureaucratic convergence of all planetary administrations into unified documents

Planned multicolor form family:

- `composite-form`: basic multicolor form combining two planet inks — gates recipes using intermediates from two different planets
- `trichromatic-permit`: advanced three-color form combining all three planet inks — gates the most advanced multi-planet recipes
- `unified-operations-charter`: top-tier composite authorization for late-game production chains
- `cryogenic-operations-license`: Aquilo-specific operations permit using transfer media

The multicolor forms answer a real gameplay question: "I have a recipe that uses both tungsten and carbon fiber — do I need both a cyan form AND a yellow form?" Answer: on Aquilo, you can produce a single composite form that covers both, using the Laser Printer and imported materials.

### 7. Aquilo should consume imported bureaucracy, not replace it

Aquilo should intensify the value of the earlier planets:

- import Vulcanus cyan forms and industrial paperwork
- import Gleba yellow forms and biosafety paperwork
- import Fulgora magenta forms and digital certificates
- combine them into multicolor composites and high-speed reconstructions

That makes Aquilo a capstone for the interplanetary paperwork economy instead of an independent replacement for it. Every planet's paperwork becomes more valuable because Aquilo can combine them.

### 8. Faxing should make logistics better, not trivial

Before Aquilo, paperwork must be physically shipped.

After Aquilo, faxing should become attractive because:

- reconstruction is automated and queue-aware
- local destination supplies are cheaper than repeated physical shipping for many documents
- the Fax Exchange handles routing and prioritization
- multicolor forms are increasingly common in late recipes

But faxing should not replace all shipping:

- buildings still need physical shipping
- fluids still need physical shipping
- bulk cargo still needs physical shipping
- faxing reconstructs form value by consuming destination-side supplies

### 9. Tax evasion applies — no taxpayer money

Aquilo recipes should not require `taxpayer-money`. Like all off-world planets, operations are outside the Nauvis tax authority's reach.

## Planned Paperwork Family

### Transfer Media (Laser Printer inputs)

- `transfer-emulsion`: cryogenic transfer medium — base fluid/material for all Laser Printer work
- `thermal-transfer-sheet`: common solid transfer substrate — the "paper" equivalent for Laser Printing
- `composite-chroma-ribbon`: premium imported-CMY carrier — requires colored forms from multiple planets to produce

### Multicolor Forms (Aquilo science unlocks)

- `composite-form`: two-color composite form — requires forms from any two planets, gates dual-intermediate recipes
- `trichromatic-permit`: three-color composite form — requires forms from all three basic planets, gates tri-intermediate recipes
- `unified-operations-charter`: top-tier composite authorization — requires trichromatic-permit plus additional bureaucracy, gates the most advanced production
- `cryogenic-operations-license`: Aquilo-specific operations permit — gates cryogenic plant usage and Aquilo-native recipes

### Fax Infrastructure

- `fax-emitter`: sender building with destination selection
- `interplanetary-fax-exchange`: destination building with queue, routing, and reconstruction runtime
- queue-capacity technologies and circuit signals for network visibility

## Current Fax Loop

The implemented first-pass shape is:

1. source paperwork is created on its home planet
2. the source is loaded into a `fax-emitter` and assigned a destination planet
3. the destination planet's `interplanetary-fax-exchange` reserves queue space and receives the job
4. the exchange reconstructs the document from its own inventory once `paper` and `ink` are available
5. the reconstructed form is available in the exchange inventory for local use or further logistics

The current fax network is a throughput and convenience system, not free teleportation. Queue space is limited, quality is preserved, and the destination must provide reconstruction supplies.

## Export Identity

Aquilo's exported value should center on:

- multicolor composite forms (the primary unique export)
- transfer media for Aquilo printing and multicolor form production
- the `Laser Printer` itself (fast printing on any planet)
- the `Interplanetary Fax Exchange` itself (fax capability on any planet)
- `cryogenic plant`-adjacent licensing
- high-speed reconstruction services

## Building Requirements

- `Laser Printer`: requires 1x `cryoprint-technician` worker to craft, no operating paperwork
- `Interplanetary Fax Exchange`: requires 1x `cryoprint-technician` worker to craft, no operating paperwork
- Both buildings should include cryogenic components (processing units, fluoroketone, lithium) in their crafting recipes
- Surface-limited crafting to Aquilo only

## Constraints For Future Implementation

- Do not add a fourth chromatic ink.
- Keep the `Laser Printer` in the print/reconstruction lane, not the certification lane.
- Make Aquilo depend on earlier planetary paperwork enough that the interplanetary network matters.
- Use Aquilo to reward faxing and convergence logistics, not to erase the value of shipping entirely.
- The Fax Exchange should feel like a capstone reward, not something the player needed three planets ago.
- Multicolor forms should feel like a real progression reward, not just "craft three colored forms together."

## Open Questions

1. How much faster should the Laser Printer be than the Chromatic Printer?
2. Which first late-game recipes should explicitly require multicolor forms?
3. Should faxing have a per-planet relay cost or only a destination reconstruction cost?
4. How should the fax network interact with existing logistics (trains, rockets, cargo pods)?
5. Should `composite-form` require literal colored forms as ingredients, or processed transfer media derived from them?
