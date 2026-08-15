# Aquilo Space Age Plan

This file records the Aquilo principles and the current first-pass implementation under the shared rules in [space-age-compatibility-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-compatibility-plan.md).

> **Superseded in part.** The fax network described in earlier revisions of this file is being **deleted outright** and replaced by the Interplanetary Tube Network, which unlocks *before* Aquilo. Aquilo's compute, heat, and colored-transport identity is designed in [space-age-automation-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-automation-plan.md). Sections below have been updated; treat that file as canonical where the two disagree.

## Planet Role

Aquilo is the compute, heat, and multicolor convergence planet.

Its themes are:

- cryogenic handling and transfer media
- liquid ink freezes here — only solid transfer printing works
- electricity converted into compute, and compute's waste heat converted into survival
- multicolor composite forms that combine the work of multiple planets
- late-game paperwork unification rather than early bootstrap

Its global rewards are the `Laser Printer`, the `AI Server`, and colored interplanetary transport.

Aquilo is **no longer the gate for cross-planet paperwork logistics**. The Interplanetary Tube Network unlocks earlier, on `{pneumatic-capacity-2, cyan-yellow-bureaucracy}`, carrying regular forms only. Aquilo's remaining logistics role is unlocking the **colored tier** of that network.

## Current Implementation Snapshot

The current codebase ships a first Aquilo pass, parts of which are now scheduled for deletion:

**Kept:**

- `laser-printer` is in-game and Aquilo-limited to craft
- `transfer-emulsion`, `thermal-transfer-sheet`, `composite-chroma-ribbon`, `cyan-yellow-form`, `cyan-magenta-form`, `yellow-magenta-form`, `trichromatic-permit`, `unified-operations-charter`, and `cryogenic-operations-license` are implemented

**Scheduled for deletion** (no save compatibility burden — no Space Age save exists yet):

- `fax-emitter`, `interplanetary-fax-exchange`, `fax-network-combinator`
- `scripts/fax.lua`, `scripts/fax_shared.lua`, `tests/test_fax_runtime.lua`
- technologies `aquilo-fax-network`, `color-faxing`, `fax-queue-capacity-1/2/3`
- the `faxed-document-reconstruction-*` recipe family and the `fax-reconstruction` category scaffolding on the `Laser Printer`
- the fax queue signals and associated locale

**Not present:** `composite-form` was never implemented; older notes mentioning it are stale.

## Planned Design Principles

### 1. Aquilo is not a first basic planet

Aquilo can assume earlier planetary progress.

That means its plan is allowed to assume:

- access to the chromatic printer family already exists somewhere
- CMY paperwork and forms can be imported
- multiple planet intermediates are already in the player's logistics network

Aquilo should therefore solve late convergence, multicolor unification, compute, and heat — not early bootstrap.

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

### 5. The AI Server is Aquilo's administrative building

The `AI Server` converts the one resource Aquilo genuinely punishes you for — electricity — into compute, and its waste heat into survival.

It owns:

- Inference Tokens, and through them Administrative Slop and low-rank synthetic paperwork
- **real vanilla heat**, fed into heat pipes and heat exchangers: unfreezing an Aquilo base, or driving steam power
- Fabricated Citations as a byproduct that must be handled

This is the correct Aquilo identity because the constraint is native to the planet. Aquilo power is expensive, imported, and freezes if unattended, so compute is self-governing here in a way it would not be on Nauvis.

The server hard-stops when it cannot dump its heat. The recovered `lufter` fan becomes a Heat Exhaust for players who want compute without power generation, and must never be more efficient than actually using the heat.

Full design in [space-age-automation-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-automation-plan.md), section 2.

**Superseded rationale, recorded deliberately.** Earlier revisions argued that cross-planet paperwork logistics must unlock on Aquilo so that "before Aquilo, players must physically ship all paperwork between planets," making the network the reward for reaching the final planet. That decision has been reversed: the Interplanetary Tube Network now unlocks pre-Aquilo with regular forms only, and Aquilo unlocks the colored tier. The protection against trivialized logistics is no longer the unlock gate but the trunk's own design — a separate narrow pool, explicit hand-off, and per-item transit latency.

### 6. Aquilo science unlocks multicolor form recipes

Aquilo research technologies unlock recipes for multicolor composite forms. These forms:

- are produced in the Laser Printer using solid transfer media
- require imported colored forms or transfer media derived from 2-3 other planets
- gate late-game recipes that consume intermediates from multiple planets
- represent the bureaucratic convergence of all planetary administrations into unified documents

Planned multicolor form family:

- `cyan-yellow-form`, `cyan-magenta-form`, and `yellow-magenta-form`: bicolor forms combining two planet inks — gate recipes using intermediates from two different planets
- `trichromatic-permit`: advanced three-color form combining all three planet inks — gates the most advanced multi-planet recipes
- `unified-operations-charter`: top-tier composite authorization for late-game production chains
- `cryogenic-operations-license`: Aquilo-specific operations permit using transfer media

The multicolor forms answer a real gameplay question: "I have a recipe that uses both tungsten and carbon fiber — do I need both a cyan form AND a yellow form?" Current answer: the recipe consumes the matching bicolor form, such as `cyan-yellow-form`. The implementation still needs a final decision on whether bicolor forms should remain liquid-ink outputs made before Aquilo, or whether Aquilo should convert that role to transfer-media printing.

### 7. Aquilo should consume imported bureaucracy, not replace it

Aquilo should intensify the value of the earlier planets:

- import Vulcanus cyan forms and industrial paperwork
- import Gleba yellow forms and biosafety paperwork
- import Fulgora magenta forms and digital certificates
- combine them into multicolor composites and high-speed reconstructions

That makes Aquilo a capstone for the interplanetary paperwork economy instead of an independent replacement for it. Every planet's paperwork becomes more valuable because Aquilo can combine them.

### 8. Interplanetary transport should make logistics better, not trivial

This principle survives the fax deletion unchanged. Only the mechanism protecting it has moved.

The Interplanetary Tube Network must never replace shipping:

- buildings still need physical shipping
- fluids still need physical shipping
- bulk cargo still needs physical shipping
- biters, managers, and couriers move by rocket or by cannon, never by tube

The protections are now structural rather than gated by planet order:

- the trunk is a **separate pool** from the local pneumatic network and must never merge with it — merging would produce free 200-capacity teleportation
- arrivals require **explicit hand-off** out of the Terminus inventory
- transit is **per item** with real latency, from 30 s down to 1 s across the upgrade ladder
- trunk capacity opens at 2–3 and reaches only 20, against a local network capacity of 200

Aquilo's remaining contribution is the colored tier, which matters because multicolor forms are increasingly common in late recipes.

### 9. Tax evasion applies — no taxpayer money

Aquilo recipes should not require `taxpayer-money`. Like all off-world planets, operations are outside the Nauvis tax authority's reach.

## Planned Paperwork Family

### Transfer Media (Laser Printer inputs)

- `transfer-emulsion`: cryogenic transfer medium — base fluid/material for all Laser Printer work
- `thermal-transfer-sheet`: common solid transfer substrate — the "paper" equivalent for Laser Printing
- `composite-chroma-ribbon`: premium imported-CMY carrier — requires colored forms from multiple planets to produce

### Multicolor Forms (Aquilo science unlocks)

- `cyan-yellow-form`, `cyan-magenta-form`, `yellow-magenta-form`: two-color forms — require inks from two planets and gate dual-intermediate recipes
- `trichromatic-permit`: three-color composite form — requires forms from all three basic planets, gates tri-intermediate recipes
- `unified-operations-charter`: top-tier composite authorization — requires trichromatic-permit plus additional bureaucracy, gates the most advanced production
- `cryogenic-operations-license`: Aquilo-specific operations permit — gates cryogenic plant usage and Aquilo-native recipes

### Compute And Heat Infrastructure

- `AI Server`: electricity plus a training corpus into Inference Tokens, with real heat as the byproduct
- `Heat Exhaust`: optional heat sink for players who want compute without power generation
- Inference Tokens, Administrative Slop, and Fabricated Citations as the Aquilo compute chain

Detailed in [space-age-automation-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-automation-plan.md), section 2.

## Interplanetary Transport Loop

The fax loop is gone. The replacement shape is:

1. source paperwork is created on its home planet and placed into the local pneumatic network
2. a Terminus hands it to the interplanetary trunk, addressed to another planet
3. each item travels independently with its own transit timer, subject to trunk capacity
4. arrivals land in the destination Terminus inventory
5. moving them into the local pneumatic pool, onto a belt, or into a chest is an explicit player step

Regular forms move from the pre-Aquilo base tier. **Colored forms require the Aquilo tier.** Fluids, buildings, bulk cargo, biters, and managers never move by tube.

## Export Identity

Aquilo's exported value should center on:

- multicolor composite forms (the primary unique export)
- transfer media for Aquilo printing and multicolor form production
- the `Laser Printer` itself (fast printing on any planet)
- Inference Tokens and the low-rank synthetic paperwork they enable
- `cryogenic plant`-adjacent licensing
- colored interplanetary transport capability

Whether the `AI Server` itself exports off Aquilo is an open question. Every other planet reward in this mod exports, but Aquilo's power and cooling constraints are what make compute self-governing, and those constraints do not travel.

## Building Requirements

- `Laser Printer`: requires 1x `cryoprint-technician` worker to craft, no operating paperwork
- `AI Server`: requires 1x `cryoprint-technician` worker to craft, no operating paperwork; hard-stops when it cannot dump heat
- Both buildings should include cryogenic components (processing units, fluoroketone, lithium) in their crafting recipes
- Surface-limited crafting to Aquilo only
- The **Terminus** must *not* require a `cryoprint-technician` at base tier — it unlocks pre-Aquilo, and an unbuildable building behind a reachable technology is a bad first impression

## Constraints For Future Implementation

- Do not add a fourth chromatic ink.
- Keep the `Laser Printer` in the print lane, not the certification lane.
- Make Aquilo depend on earlier planetary paperwork enough that the interplanetary network matters.
- **Slop must never produce colored paperwork, at any tier.** This is what preserves the ink economy, the chromatic printer chain, and the planetary import loop the whole Space Age pass rests on.
- Slop is capped at rank 0–1 until Administratorium, then rank 2–3 at a huge token cost, and never the 16 `restricted_documents`.
- The interplanetary trunk must never merge with the local pneumatic pool.
- Multicolor forms should feel like a real progression reward, not just "craft three colored forms together."
- Aquilo's compute identity must not turn it into a paperwork replacement. Aquilo consumes imported bureaucracy; it does not make the other planets optional.

## Open Questions

1. How much faster should the Laser Printer be than the Chromatic Printer?
2. Which first late-game recipes should explicitly require multicolor forms?
3. Should bicolor forms stay as direct liquid-ink recipes, or should Aquilo replace them with processed transfer media derived from colored paperwork?
4. Does the `AI Server` export off Aquilo, or is it Aquilo-craftable only?
5. What is the Heat Exhaust's dump rate relative to a server's output, and how many exhausts does one server need?
6. Does the Terminus need one-per-planet uniqueness, as the fax receiver had?
