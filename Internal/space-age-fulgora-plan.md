# Fulgora Space Age Plan

This file records the planned Fulgora principles under the shared rules in [space-age-compatibility-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-compatibility-plan.md).

## Planet Role

Fulgora is the computerized processing and archive recovery planet.

Its themes are:

- ruined records and recoverable templates from salvage
- electromagnetic-powered digital bureaucracy
- a faster, modernized administrative office that never closes
- archive recovery as an indirect source of paperwork value
- the government's promise of "digital transformation" — same forms, same nonsense, now with blinking lights

Its global reward is the `Digital Services Bureau`.

## Planned Design Principles

### 1. Fulgora should be the easy-`redundant-rubble` planet indirectly

Fulgora should not just mine "paper junk ore" and call it done. The real local advantage should be:

- extremely easy `redundant-rubble`
- salvage and archive recovery loops
- practical access to paperwork filler, template fragments, and routing material
- easy `useless-documentation` as a derived filler output of the salvage economy

This makes Fulgora the natural place to rebuild, pad out, and process administrative material without turning it into a universal free-paper planet.

### 2. Fulgora must still work as a first basic planet

Like Vulcanus and Gleba, Fulgora should be able to reach a local launch threshold without depending on another basic planet for bulk paperwork materials.

That does not require full parity. Copyable forms that would demand a dead-end subtree should remain import-seeded and black-copied if that is the cleaner outcome.

### 3. Do not duplicate ordinary vanilla outputs

Fulgora should not get a second ladder of ordinary recipes just to pretend it is Nauvis with lightning.

The preferred pattern is:

- add new archive, recovery, and digital processing paperwork
- let those new items make documentation and processing easier
- avoid cloning ordinary buildings or vanilla launch items with `-fulgora` recipes unless there is no cleaner paperwork solution

### 4. The Digital Services Bureau is a computerized upgrade to the admin office

The `Digital Services Bureau` is the planet's administrative reward building. It is:

- a direct upgrade to the standard administrative office
- significantly faster crafting speed (electromagnetic-powered computation)
- operates 24/7 — no night closure, unlike regular admin offices
- requires a `relay-clerk` worker to craft; current implementation routes clerical trainees into relay clerks at any Formation Center after electromagnetic science
- no operating paperwork required (compensated by the worker cost)
- craftable only on Fulgora (requires electromagnetic components)
- useful on every planet once shipped — everyone wants a faster 24/7 office

The comedy is deliberate: the government finally went digital. It's the same bureaucracy, same forms, same red tape — but now with electricity and blinking lights. Every government's "digital transformation" promise made physical.

The Digital Services Bureau should handle the same crafting categories as the regular admin office but at higher speed and without the night-time productivity penalty. It does not replace the Chromatic Printer or the Notary Office — it replaces the admin station.

### 5. Keep stock printing separate from digital processing

Fulgora should follow the same machine-identity discipline:

- printers handle magenta stock, blanks, and print steps
- the `Digital Services Bureau` handles fast computerized processing of forms

The bureau should not become a printer. Its value is:

- speed
- availability (24/7)
- general administrative throughput
- a universally desirable building worth shipping to every planet

### 6. Black ink remains the standard copy medium

Fulgora should not delete the core copy rules.

That means:

- standard copy chains stay black-ink based
- magenta paperwork is for archive recovery, electromagnetic permits, and digital certification
- Fulgora special forms can stay non-copyable when that keeps the planet's export identity clearer

### 7. Escape viability should not imply mall viability

Fulgora should support a first-planet escape path, but that should not mean the player can build a full generic factory there without feeling the planet's identity.

Intended behavior:

- launch-critical paperwork gets a clear salvage and archive path
- a broad mall still wants shipped materials, imported forms, or copied paperwork
- the planet should reward archive recovery and digital processing rather than brute local duplication

### 8. Magenta forms gate holmium usage everywhere

Any recipe that consumes holmium plate must also consume a magenta form as an ingredient. This is the primary mechanism making Fulgora's ink production essential even on Nauvis and other planets.

On Fulgora, magenta forms are cheap and locally produced. Off-world, they must be shipped, creating natural export pressure.

### 9. Tax evasion applies — no taxpayer money

Fulgora recipes should not require `taxpayer-money`. The planet operates outside the Nauvis tax authority's reach. Local paperwork uses electromagnetic resources and magenta ink instead of cash.

### 10. Escape exceptions remain electromagnetic and archival

Fulgora keeps only the material and terminal-document exceptions that the
unchanged launch chain actually needs:

- `salvage-electrolyte-fulgora`, `electromagnetic-rocket-fuel-fulgora`, and the deliberately expensive `electromagnetic-lubricant-fulgora` cover the local engine and fuel bottlenecks.
- Completed magenta/archive paperwork feeds Fulgora's recovery and operating loops. The final `management-approval-written` and one `government-grant` for a silo remain dense Nauvis imports.

Fulgora does not receive a local liquid-black-ink route, crude-oil processing,
or a general petroleum economy. Those remain difficult or unavailable by
design.

## Planned Paperwork Family

The family should stay centered on archive recovery and electromagnetic processing.

Working names and roles:

- `charged-toner`: electrical toner intermediate, base material for magenta ink production
- `signal-form-stock`: local magenta paperwork stock
- `blank-magenta-form`: magenta substrate for final paperwork
- `archive-recovery-permit`: salvage and reconstruction permit for processing ruined records
- `digital-processing-certificate`: authorization for computerized form processing
- `electromagnetic-operating-license`: permit for electromagnetic plant operations off-world
- `data-recovery-order`: directive to recover and reconstruct archived paperwork

All Fulgora-specific forms should be durable (not perishable like Gleba's yellow forms) — electromagnetic records are robust, fitting the digital theme.

## Planned Archive Recovery Loop

Fulgora needs productive work from its salvage abundance.

The archive side should:

- consume ruined or partial paperwork artifacts from Fulgora's scrap piles
- recover low-tier forms, fragments, rubble, or fillers
- turn salvage abundance into useful administrative inputs
- feed the `redundant-rubble` and `useless-documentation` advantage

This is where the planet's easy access to filler and waste documentation becomes a real economic asset.

## Planned Digital Processing Loop

The `Digital Services Bureau` should support a processing loop:

1. magenta forms and archive materials are prepared via the Chromatic Printer
2. the Digital Services Bureau processes them at high speed into finalized documents
3. those documents gate electromagnetic plant usage and serve as general fast-processed administrative output
4. the bureau's 24/7 operation makes it the preferred office on any planet that has one

## Export Identity

Fulgora's exported value should center on:

- magenta forms (required for any holmium recipe everywhere)
- the `Digital Services Bureau` itself (ship it to other planets for fast 24/7 admin)
- archive recovery permits
- electromagnetic operating licenses
- `electromagnetic plant`-adjacent permissions
- redundant-rubble-heavy filler recovery

This makes Fulgora the planet that modernizes your bureaucracy — same paperwork, now faster, now 24/7, now with magnets.

## Building Requirements

- `Digital Services Bureau`: requires 1x `relay-clerk` worker to craft, no operating paperwork
- Crafting recipe should include electromagnetic components (processing units, holmium, electromagnetic plant parts)
- Surface-limited crafting to Fulgora only

## Constraints For Future Implementation

- Keep the Digital Services Bureau focused on fast general admin processing, not printing or certification.
- Do not make magenta ink a universal better copier.
- Use Fulgora's salvage and documentation abundance for archive recovery, not as a generic answer to every paperwork problem.
- Preserve the import-seed rule for copyable dead-end forms.
- The Digital Services Bureau is standalone valuable — it does not exist to serve Aquilo's fax network.

## Open Questions

1. Which salvage items should become the main source of early `redundant-rubble` recovery?
2. What crafting categories should the Digital Services Bureau handle? (Same as admin station, or a superset?)
3. Which late off-world recipes should first consume Fulgora magenta paperwork?
4. Should the Digital Services Bureau have module slots for productivity bonuses?
