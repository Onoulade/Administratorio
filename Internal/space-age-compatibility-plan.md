# Space Age Compatibility Plan

This file is the canonical design reference for the mod's Space Age support.

It records the shared principles that all planet passes should follow, the current implementation status, and the specific rules established by the implemented Vulcanus pass.

## Current Status

- Space Age remains an optional compatibility target rather than a hard dependency.
- Vulcanus has a working first-pass implementation and a solver-clean launch path.
- Gleba, Fulgora, and Aquilo are still planning-stage design work.
- The shared rules below should be treated as the baseline for future planet work unless a later implementation proves they need revision.

## Shared Principles

### 1. First-planet independence is local launch viability

For the three basic planets, "works as a first planet" means:

- the planet can reach a basic ship-send milestone with its own local paperwork ecosystem
- the planet does not need bulk imports of administrative raw materials just to become usable
- the planet does not need full Nauvis paperwork parity

It is acceptable for some later or niche forms to remain import-seeded or fax-targeted if localizing them would only add a dead-end subtree.

### 2. Each base planet gets one easy administrative derivative

Each of the three any-order basic planets should trivialize one bureaucratic bottleneck in the same way Space Age planets trivialize selected industrial materials.

The intended identities are:

- Vulcanus: `lie`
- Gleba: `dubious-data`
- Fulgora: `useless-documentation`

The goal is not to clone Nauvis raw administrative resources everywhere. The goal is to give each planet one strong local shortcut and then build its paperwork family around that advantage.

### 3. Prefer derivatives and shortcuts over cloned raw resources

Space Age planet support should generally avoid:

- adding local equivalents of `taxpayer-money`
- adding local equivalents of every Nauvis-only complaint resource
- recreating a whole Nauvis subtree just to make one form once

Instead, prefer:

- local substitute forms
- local derivative-heavy shortcuts
- alternate recipes that compress a planet-themed chain into fewer steps

### 4. Machine identities must stay strict

Each upgraded planet machine should have a narrow identity.

Shared rule:

- printers print stock, blanks, drafts, and explicit print steps
- support-heavy conversion belongs in the upgraded office or other planet reward building

The implemented Vulcanus split is the reference example:

- `chromatic-printer` consumes paper-like solids and ink fluids only
- `chromatic-printer` produces cyan stock, `blank-cyan-form`, and a few direct printed intermediates
- `notary-office` consumes those printed substrates plus support materials like `lie`, `dubious-data`, `cyan-slurry`, and `liquid-coffee`

Future planets should follow the same pattern:

- Gleba printer prints yellow stock and base blanks; `Conciliation Desk` handles the living or support-heavy conversions
- Fulgora printer/fax printers handle stock and reconstruction; `Interplanetary Fax Exchange` owns routing and queue logic
- Aquilo `Laser Printer` should own the fast final print and reconstruction layer, not general certification

### 5. Black ink remains the general copy medium

Standard duplication rules should stay simple:

- ordinary copy recipes remain black-ink based
- chromatic inks do not replace black ink as the universal copier
- chromatic or planet-special forms are not copyable unless there is a strong later-game reason to carve out a specific exception

This keeps copying readable and preserves a clear role for imported or locally produced black ink.

### 6. Import-seed copyable forms instead of localizing dead-end trees

If a form is copyable and the only reason to localize it would be to support a one-off recipe chain, prefer:

- import one seed
- copy it locally with the normal black-ink path

This rule should especially apply to deep executive, policy, or funding trees that do not become part of the target planet's core identity.

### 7. Export pressure should live in off-world variants

When a planet should export paperwork for its own technology family, the clean pattern is:

- keep the home-planet recipe straightforward
- add off-world recipe variants that require the exported form

That keeps the home planet readable while still giving the paperwork a shipping or fax value everywhere else.

The Vulcanus implementation uses this pattern for selected foundry, tungsten, calcite, and molten-metal chains.

### 8. Space Age compatibility should not erase cross-planet identity

The planets should complement each other rather than collapse into interchangeable paperwork factories.

That means:

- local launch viability does not imply late-game self-sufficiency
- some forms should remain natural exports
- later faxing should solve transport friction without deleting planetary specialties

### 9. Faxing is reconstruction, not teleportation

Fulgora and Aquilo should make it easier to move administrative value between planets, but the network should still feel like paperwork reconstruction:

- source-side paperwork still matters
- local receiver-side media or print capacity still matters
- buildings, fluids, and bulk cargo still need shipping

## Planet Matrix

| Planet | Local Admin Advantage | Upgraded Building | Printer Identity | Export Identity | Status |
| --- | --- | --- | --- | --- | --- |
| Vulcanus | `lie` | `Notary Office` | cyan stock, blanks, industrial drafts | industrial and metallurgical certification | Implemented first pass |
| Gleba | `dubious-data` | `Conciliation Desk` | yellow stock, calming/personnel blanks | biosafety, pacification, workforce paperwork | Planned |
| Fulgora | `useless-documentation` | `Interplanetary Fax Exchange` | magenta stock, relay stock, reconstruction jobs | archive recovery, routing, fax throughput | Planned |
| Aquilo | none; mixed-planet transfer efficiency instead | `Laser Printer` | transfer-medium final printing and rapid reconstruction | high-speed mixed-planet paperwork | Planned |

## Implemented Vulcanus Principles

Vulcanus is the reference pass because it already exists in-game.

Its design principles are:

- solve launch viability with local shortcuts, not by recreating the entire Nauvis office tree
- make the planet good at `lie`, with `dubious-data` arriving as a constrained useful byproduct
- keep the `chromatic-printer` narrow and coherent
- move the support-heavy or legally dense work into the `notary-office`
- use Vulcanus-exclusive paperwork as off-world gates for Vulcanus tech

### Vulcanus bootstrap layer

The first playable Vulcanus pass adds early bootstrap recipes so the planet can stand up its own admin base:

- `paper-production-vulcanus`
- `carbon-offset-certificate-basic-vulcanus`
- `admin-station-vulcanus`
- `printer-t1-vulcanus`
- `research-grant-approval-vulcanus`
- `administrative-science-pack-production-vulcanus`
- `plastic-bar-vulcanus`
- `refined-nonsense-production-vulcanus`

These exist specifically so the planner can actually route into the local Vulcanus paperwork loop instead of insisting on bulk Nauvis imports.

### Vulcanus chromatic layer

Vulcanus adds:

- `verdigris-crust`
- `cyan-slurry`
- `cyan-ink`
- `heatproof-form-stock`
- `blank-cyan-form`
- `permit-draft`
- `inspection-docket`

The printer's role is intentionally limited to the stock and direct print layer:

- `heatproof-form-stock`
- `blank-cyan-form-production`
- `permit-draft`
- `inspection-docket`

### Vulcanus support and shortcut layer

The notarial and chemical support layer handles the non-printer part of the planet:

- `liquid-stimulant-production`
- `liquid-coffee-vulcanus`
- `molten-promises-production`
- `vulcanus-lie-distillation`
- `heatproof-filler-documentation`
- `good-excuse-vulcanus`
- `safety-waiver-vulcanus`
- `construction-permit-vulcanus`
- `management-approval-verbal-vulcanus`

### Vulcanus export paperwork

Vulcanus creates non-copyable forms that matter off-world:

- `thermal-process-license`
- `calcite-reagent-waiver`
- `offworld-metallurgy-charter`

These forms are consumed by off-world variants of important Vulcanus-tech recipes rather than polluting the core home-planet recipes.

### Vulcanus implementation result

The current implementation target has been reached:

- Vulcanus can locally satisfy the planner path for `rocket-silo`
- Vulcanus can locally satisfy the planner path for `100x rocket-part`
- bulk imports of the old blocking administrative materials are no longer required for that escape target

## Planned Gleba Principles

Gleba should inherit the shared rules, but with a biological identity rather than an industrial one.

Key design principles:

- Gleba should be the easy-`dubious-data` planet
- its shortcuts should come from biological manipulation, calming, and reassignment rather than from cash or policy
- the yellow printer should make stock and base forms, while the `Conciliation Desk` handles the high-leverage living conversion work
- if a normal form is copyable and only needs one seed, it should stay import-seeded instead of forcing Gleba to grow a dead-end executive tree

The export identity should center on:

- workforce reassignment
- pacification and luring paperwork
- biosafety waivers
- `biochamber`-adjacent operating paperwork

## Planned Fulgora Principles

Fulgora should be the archive and routing planet.

Key design principles:

- Fulgora should be the easy-`useless-documentation` planet
- its local shortcuts should come from salvage, routing, archive recovery, and template reconstruction
- magenta work should stay focused on relay stock and transmission paperwork rather than replacing the whole copy ecosystem
- the `Interplanetary Fax Exchange` should own queueing and routing, not generic assembling

The export identity should center on:

- archive recovery
- relay orders and priority paperwork
- fax infrastructure
- `electromagnetic assembler`-adjacent paperwork

## Planned Aquilo Principles

Aquilo is intentionally not part of the any-order first-planet trio.

Key design principles:

- Aquilo should not introduce a fourth ink
- Aquilo should convert imported CMY and transfer media into extremely fast reconstruction and reprint throughput
- the `Laser Printer` should be the best machine for final print speed and fax reconstruction, not for dense office certification work
- mixed-planet paperwork should become normal on Aquilo rather than awkward

Its export identity should center on:

- transfer media
- high-speed reconstruction
- mixed-planet late paperwork
- `advanced chemical plant`-adjacent licensing

## Recommended Implementation Order

1. Keep Vulcanus maintained as the reference implementation.
2. Build Gleba next using the same machine-split and import-seed rules.
3. Build Fulgora after that so the fax network has a clear role.
4. Use Aquilo as the late-game throughput and transfer-media capstone.
