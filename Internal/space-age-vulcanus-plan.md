# Vulcanus Space Age Plan

This file records the implemented Vulcanus principles under the shared rules in [space-age-compatibility-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-compatibility-plan.md).

## Planet Role

Vulcanus is the industrial certification planet.

Its themes are:

- durable paperwork
- hot-process approvals
- shortcuts for heavy metallurgy and calcite chemistry
- productive non-printed bureaucracy

Its global reward is the `Notary Office`.

## Implemented Design Principles

### 1. Vulcanus must be a real first-planet bootstrap

The implemented target is not full Nauvis parity. The target is:

- locally stand up the admin base
- locally reach `rocket-silo` and `rocket-part`
- avoid bulk imports of the old administrative blockers

This is why Vulcanus has dedicated bootstrap recipes for:

- `paper-production-vulcanus`
- `carbon-offset-certificate-basic-vulcanus`
- `redundant-rubble-recovery-vulcanus`
- `plastic-bar-vulcanus`
- `refined-nonsense-production-vulcanus`

The first three are input bridges. The canonical provisional approval,
research-grant, administrative-science, public-finance, and executive-approval
recipes remain unchanged. The rocket silo therefore needs one shipped
`government-grant` and one shipped `management-approval-written`.

### 2. The planet's easy administrative output is `lie`

Vulcanus should be dramatically better than Nauvis at turning local materials into politician-fluid derivatives.

The implemented direction is:

- `molten-promises-production`
- `vulcanus-lie-distillation`

This makes `lie` cheap and abundant while keeping `dubious-data` as the more constrained useful byproduct.

### 3. The chromatic printer stays narrow

The `chromatic-printer` is not a general bureaucratic reactor.

Its Vulcanus role is:

- consume paper-like stock plus ink fluids
- produce cyan stock and direct print intermediates
- avoid support-heavy inputs like `liquid-coffee` or rhetoric materials

The core printer outputs are:

- `heatproof-form-stock`
- `blank-cyan-form-production`
- `permit-draft`
- `inspection-docket`

### 4. The notary office handles support-heavy conversion

The `notary-office` is the real Vulcanus reward building.

Its role is:

- legalize and finalize chromatic paperwork
- consume support materials like `lie`, `dubious-data`, `cyan-slurry`, and `liquid-coffee`
- turn printed cyan substrates into the forms that actually matter

The notarial family currently includes:

- `embossed-seal`
- `industrial-charter`
- `thermal-process-license`
- `calcite-reagent-waiver`
- `offworld-metallurgy-charter`

### 5. Cyan paperwork should be shorter than black paperwork

The Vulcanus advantage is not "cyan can copy everything." The advantage is:

- fewer steps
- fewer draft layers
- direct bypass recipes for hot industrial paperwork

Standard black-ink copying still exists for ordinary forms. Vulcanus chromatic forms are their own family and are not meant to become a universal replacement for the normal copy economy.

### 6. Vanilla restrictions remain authoritative

Vulcanus should retain its vanilla industrial identity. Administratorio does not rewrite the restrictions on the Foundry or native Vulcanus processes, and it does not add off-world clones for them.

The clean pattern is instead:

- keep one canonical building recipe
- preserve vanilla recipe and entity surface conditions
- provide local routes for Administratorio intermediates needed by the canonical building costs

The forms carrying that export role are:

- `thermal-process-license`
- `calcite-reagent-waiver`
- `offworld-metallurgy-charter`

These forms remain useful in Administratorio construction permits and interplanetary convergence paperwork without changing vanilla production recipes.

### 7. The notary office requires a worker but no operating paperwork

The `notary-office` requires a `licensed-notary` worker to craft but no operating paperwork. `licensed-notary-formation` is intentionally Nauvis-bound as part of the taxpayer-funded workforce seed, so the worker must be trained on Nauvis and shipped to Vulcanus.

### 8. Tax evasion applies — no taxpayer money

Vulcanus recipes should not require `taxpayer-money`. The planet operates outside the Nauvis tax authority's reach. Local paperwork uses volcanic resources and cyan ink instead of cash.

## Implemented Local Pipelines

### Cyan input chain

- `verdigris-crust`
- `cyan-slurry-production`
- `cyan-ink-production`

This is the basic local paper-color identity for Vulcanus.

### Stimulant and coffee chain

- `liquid-stimulant-production`
- `liquid-coffee-vulcanus`

This exists specifically so Vulcanus can satisfy coffee-backed support work without requiring greenhouse farming.

### Paper and rubble chain

- `paper-production-vulcanus`
- `redundant-rubble-recovery-vulcanus`

This makes the generic paperwork feedstock practical without recreating a
second set of finished forms.

### Draft and docket chain

- `heatproof-form-stock`
- `blank-cyan-form-production`
- `permit-draft`
- `inspection-docket`

This is the core bridge between the printer and the office.

### Notarial certification chain

- `embossed-seal`
- `industrial-charter`
- `thermal-process-license`
- `calcite-reagent-waiver`
- `offworld-metallurgy-charter`

### Narrow launch-gate imports

`good-excuse`, `management-approval-written`, and the Nauvis-issued
`government-grant` remain finished-document imports. The local notary chain
creates Vulcanus-specific charters and resettlement paperwork, not generic
executive approvals. Everything else uses the canonical recipe or is an
import/tube need.

## What Vulcanus Intentionally Does Not Do

- It does not recreate the full Nauvis executive or policy tree.
- It does not turn `cyan-ink` into a universal copy medium.
- It does not use the `Corporate Breakroom` as the main Vulcanus special-case machine.
- It does not solve export pressure by making every home-planet Vulcanus recipe carry extra paperwork.

If a copyable seed form would require a dead-end local subtree, the preferred answer is still import-seeding plus black-ink copying rather than bloating the Vulcanus identity.

## Current Result

The current implemented pass is solver-clean for the intended first target:

- Vulcanus can locally satisfy `rocket-silo`
- Vulcanus can locally satisfy `100x rocket-part`

That is the success condition this document should preserve as the planet evolves.

## Follow-up Constraints

- Do not let later additions break the strict printer/office split.
- Do not let off-world export paperwork leak back into the home-planet recipes unless there is a very good reason.
- Keep greenhouse-style agriculture off Vulcanus.
- Keep Vulcanus focused on industrial permits, not general office omnipotence.

## Building Requirements

- `Notary Office`: requires 1x `licensed-notary` worker to craft, no operating paperwork
- Crafting recipe should include volcanic/industrial components
- Surface-limited crafting to Vulcanus only
