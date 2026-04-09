# Fulgora Space Age Plan

This file records the planned Fulgora principles under the shared rules in [space-age-compatibility-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-compatibility-plan.md).

## Planet Role

Fulgora is the archive and transmission planet.

Its themes are:

- ruined records and recoverable templates
- relay paperwork and routing authority
- turning archival junk into useful documents
- reconstructing paperwork remotely instead of shipping every sheet

Its global reward is the `Interplanetary Fax Exchange`.

## Planned Design Principles

### 1. Fulgora should be the easy-`useless-documentation` planet

Fulgora should not just mine "paper junk ore" and call it done. The real local advantage should be:

- extremely easy `useless-documentation`
- salvage and archive recovery loops
- practical access to paperwork filler, template fragments, and routing material

This makes Fulgora the natural place to rebuild, pad out, and relay administrative value.

### 2. Fulgora must still work as a first basic planet

Like Vulcanus and Gleba, Fulgora should be able to reach a local launch threshold without depending on another basic planet for bulk paperwork materials.

That does not require full parity. Copyable forms that would demand a dead-end subtree should remain import-seeded and black-copied if that is the cleaner outcome.

### 3. Keep stock printing separate from routing logic

Fulgora should follow the same machine-identity discipline:

- printers handle magenta stock, relay stock, and reconstruction jobs
- the `Interplanetary Fax Exchange` owns queues, destinations, and routing authority

The exchange should not become a generic crafting machine. Its value is:

- routing
- receiving
- prioritization
- coordinating reconstruction throughput

### 4. Faxing should reconstruct paperwork, not erase logistics

The network should help with urgency and mixed-planet workflows, but it should not replace all shipping.

Planned rules:

- buildings still need shipping
- fluids still need shipping
- bulk cargo still needs shipping
- faxing moves form value by reconstruction, consuming destination-side media and print capacity

### 5. Black ink remains the standard copy medium

Fulgora should not delete the core copy rules.

That means:

- standard copy chains stay black-ink based
- magenta paperwork is for relay, transmission, archive, and reconstruction roles
- Fulgora special forms can stay non-copyable when that keeps the planet's export identity clearer

## Planned Paperwork Family

The exact recipe graph is still open, but the family should stay centered on relay and recovery work.

Working names and roles:

- `charged-toner`: electrical toner intermediate
- `signal-toner`: premium relay and recovery input
- `signal-form-stock`: local magenta paperwork stock
- `directive-sheet`: routing shell
- `transmission-warrant`: authority to send administrative value
- `archive-recovery-permit`: salvage/reconstruction permit
- `priority-directive`: premium queueing or bandwidth control
- `relay-order`: destination and routing authority
- `signal-allocation-directive`: high-tier network or building permit

## Planned Archive Recovery Loop

Fulgora needs productive work even when the player is not actively faxing.

The archive side should therefore:

- consume ruined or partial paperwork artifacts
- recover low-tier forms, fragments, or fillers
- turn documentation abundance into useful relay inputs

This is also the clean place to express the planet's `useless-documentation` advantage.

## Planned Fax Loop

The intended late shape is:

1. source paperwork is created on its home planet
2. a sender queues a destination
3. the `Interplanetary Fax Exchange` receives and routes the job
4. attached printers consume local media and reconstruct the form

Fulgora should supply the network's routing authority and early reconstruction model. Aquilo can later become the premium high-speed endpoint.

## Export Identity

Fulgora's exported value should center on:

- relay orders
- priority directives
- archive recovery permits
- fax infrastructure
- `electromagnetic assembler`-adjacent permissions

This makes Fulgora the planet that turns paperwork logistics from awkward shipping into deliberate network planning.

## Constraints For Future Implementation

- Keep the exchange focused on routing and queue ownership.
- Do not make magenta ink a universal better copier.
- Use Fulgora's documentation abundance for salvage and relay work, not as a generic answer to every paperwork problem.
- Preserve the import-seed rule for copyable dead-end forms.
- Make sure the first fax loop is useful before Aquilo exists, but not complete enough to trivialize later Aquilo design.

## Open Questions

1. Which salvage items should become the main source of early archive recovery?
2. How much of the reconstruction cost should be paid in printer media versus exchange-side routing paperwork?
3. Which late off-world recipes should first consume Fulgora relay paperwork?
