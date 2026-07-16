# Space Age Compatibility Plan

This file is the canonical design reference for the mod's Space Age support.

It records the shared principles that all planet passes should follow, the current implementation status, and the specific rules established by the implemented Vulcanus pass.

## Current Status

- Space Age remains an optional compatibility target rather than a hard dependency.
- The current branch is a broad first-pass implementation, not a completed compatibility pass. The detailed completion backlog and 2026-04-18 assessment live in [space-age-implementation-steps.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-implementation-steps.md).
- Vulcanus has a working first-pass implementation and the latest Space Age route analyzer run reports no aggregate imports or aggregate deadlocks for selected escape targets.
- Gleba has a working first-pass implementation (yellow ink, conciliation paperwork, spoilage, and bootstrap variants).
- Fulgora has a working first-pass implementation (Digital Services Bureau, salvage-backed magenta paperwork, and holmium gating).
- Aquilo has a working first-pass implementation (Laser Printer, Interplanetary Fax Exchange runtime, frozen-ink restrictions, and multicolor paperwork).
- Current automated validation status: all Lua tests pass, base-only strict progression passes, and Space Age route analysis passes on Factorio 2.0.76.
- Current known blockers are design/completion issues rather than load-test failures: remaining planet-identity surface-rule cleanup, the bicolor-form versus Aquilo transfer-media decision, fax reconstruction economy decisions, faxability policy, and manual balance review of analyzer routes.
- Latest validation note: Space Age remains optional; `amber-sap-seep`, `verdigris-crust`, and `capture-bureau` are now gated so base-only `--dump-data` no longer receives Space Age-only resources/entities.
- The shared rules below should be treated as the baseline for future planet work unless a later implementation proves they need revision.

## Shared Principles

### 1. First-planet independence is local launch viability

For the three basic planets, "works as a first planet" means:

- the planet can reach a basic ship-send milestone with its own local paperwork ecosystem
- the planet does not need bulk imports of administrative raw materials just to become usable
- the planet does not need full Nauvis paperwork parity

It is acceptable for some later or niche forms to remain import-seeded or fax-targeted if localizing them would only add a dead-end subtree.

### 2. Each base planet gets one easy administrative bottleneck indirectly

Each of the three any-order basic planets should trivialize one bureaucratic bottleneck in the same way Space Age planets trivialize selected industrial materials.

The intended identities are:

- Vulcanus: `lie`
- Gleba: `bullshit-ore`, with `dubious-data` as an easy local derivative
- Fulgora: `redundant-rubble`, with `useless-documentation` and archive filler as easy local derivatives

The goal is not to clone Nauvis raw administrative resources everywhere. The goal is to give each planet one strong local shortcut, reached in a planet-themed indirect way, and then build its paperwork family around that advantage.

### 3. Prefer derivatives and shortcuts over cloned raw resources

Space Age planet support should generally avoid:

- adding local equivalents of `taxpayer-money`
- adding local equivalents of every Nauvis-only complaint resource
- recreating a whole Nauvis subtree just to make one form once
- cloning vanilla item and building recipes with `-planet` variants unless there is no cleaner administrative alternative

Instead, prefer:

- local substitute forms
- local derivative-heavy shortcuts
- a small number of new planet-native intermediates that feed the shared recipe graph
- import-seeding plus black-ink copying when the player only needs a seed form rather than a new local bureaucracy

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
- Fulgora printer prints magenta stock and base blanks; `Digital Services Bureau` handles fast computerized processing
- Aquilo `Laser Printer` owns fast final print and reconstruction; `Interplanetary Fax Exchange` owns routing and queue logic

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

### 7. Preserve vanilla restrictions; localize Administratorio inputs

Vanilla Space Age owns the availability of its buildings and native processes. Administratorio must not rewrite those surface conditions or clone vanilla processes merely to make them portable.

- keep one construction recipe per building
- leave vanilla recipe and entity restrictions untouched
- add planet-local alternatives for Administratorio intermediates when a canonical building would otherwise need excessive imports

This preserves planet identity while keeping the mod's own building costs practical.

### 8. Space Age compatibility should not erase cross-planet identity

The planets should complement each other rather than collapse into interchangeable paperwork factories.

That means:

- local launch viability does not imply late-game self-sufficiency
- some forms should remain natural exports
- later faxing should solve transport friction without deleting planetary specialties
- mall-scale and generic-factory-scale buildouts should still expose the costs of a planet's missing paperwork families

### 9. Faxing is reconstruction, not teleportation

Fulgora and Aquilo should make it easier to move administrative value between planets, but the network should still feel like paperwork reconstruction:

- source-side paperwork still matters
- local receiver-side media or print capacity still matters
- buildings, fluids, and bulk cargo still need shipping

### 10. Colored ink forms are required to use planet-specific intermediates anywhere

Each planet introduces new industrial intermediates that are used in advanced recipes. Any recipe that consumes a planet-specific intermediate must also consume the corresponding colored ink form as an ingredient.

The gating rule is:

- **Tungsten plate** (Vulcanus): any recipe using tungsten requires a cyan form
- **Carbon fiber** (Gleba): any recipe using carbon fiber requires a yellow form
- **Holmium plate** (Fulgora): any recipe using holmium requires a magenta form

This is the primary mechanism that makes the colored ink system essential rather than optional. Even on Nauvis, if you want to build turrets that use tungsten, you must import cyan forms from Vulcanus. This drives real interplanetary trade in paperwork and ensures every planet's ink production has lasting value.

On the home planet, the forms are cheap and locally produced. Off-world, they must be shipped or (later) faxed, creating natural export pressure.

Aquilo intermediates (lithium, fluoroketone) should require multicolor forms unlocked by Aquilo science, reinforcing the capstone convergence role.

### 11. Taxpayer money stays on Nauvis — off-world is tax evasion

Raw `taxpayer-money` can only be obtained on Nauvis. Planet-specific recipes should not require taxpayer money because the thematic justification is tax evasion: these remote operations are outside the reach of the Nauvis tax authority.

This means:

- Nauvis recipes remain the primary consumer of `taxpayer-money`
- planet bootstrap and local paperwork recipes use local resources and chromatic inks instead of cash
- derivative finance instruments (`offworld-allocation`, `money-case`) may carry pre-authorized funding for specific purposes
- the absence of taxpayer money on other planets is a feature, not a bug

### 12. Planet-specific buildings require a worker but no operating paperwork

All planet-specific factory buildings — both vanilla Space Age machines and the mod's own administrative buildings — follow the same rule:

- **No operating paperwork required**: they are exempt from recurring administrative permits
- **A specialist worker must be included in the crafting recipe**: the Nauvis workforce seed creates portable staffing, then planet-science credentials route those workers into specialist roles

The specialist workers are:

- `licensed-notary` for Vulcanus buildings (Foundry, Notary Office, Territorial Arbitration Post)
- `conciliation-officer` for Gleba buildings (Biochamber, Capture Bureau, Conciliation Desk)
- `relay-clerk` for Fulgora buildings (Electromagnetic Plant, Digital Services Bureau)
- `cryoprint-technician` for Aquilo buildings (Cryogenic Plant, Laser Printer, Fax Emitter, Interplanetary Fax Exchange)

The worker requirement compensates for the operating paperwork exemption: you pay upfront in workforce logistics instead of ongoing in bureaucratic overhead.

Current surface rule:

- `job-offer-production`, `worker-biter-formation`, `management-trainee-formation`, and `licensed-notary-formation` are Nauvis-bound.
- `clerical-trainee-formation`, `astronaut-formation`, `night-shift-supervisor-formation`, `conciliation-officer-formation`, `relay-clerk-formation`, `cryoprint-technician-formation`, `field-negotiator-formation`, and `middle-management-managing-manager-formation` are portable once their prerequisites are unlocked.
- This keeps taxpayer-funded recruitment anchored on Nauvis without forcing every planet-specialist conversion back to Nauvis after the player already has a Formation Center and the relevant planet science.

### 13. Liquid ink freezes on Aquilo

The Chromatic Printer uses liquid ink and cannot operate on Aquilo because the ink freezes in cryogenic conditions. Only the Laser Printer works on Aquilo, using solid transfer media instead of liquid ink.

This means:

- Aquilo cannot locally produce cyan, yellow, or magenta ink
- colored forms must be imported or faxed to Aquilo
- the Laser Printer uses transfer media (toner-based) for its printing
- this constraint naturally explains why Aquilo's identity is about transfer and reconstruction rather than ink production

### 14. Aquilo science unlocks multicolor forms

Aquilo research unlocks recipes for multicolor forms that combine ingredients from multiple planets. These composite forms:

- use the Laser Printer (the only printer that works on Aquilo)
- require imported colored forms or inks from 2-3 other planets
- gate late-game recipes that use multiple planet intermediates
- represent the bureaucratic convergence of all planetary administrations

This makes Aquilo the natural capstone where the separate planetary paperwork systems finally merge into unified composite documents.

## Planet Matrix

| Planet | Local Admin Advantage | Admin Building(s) | Printer | Export Identity | Ink | Status |
| --- | --- | --- | --- | --- | --- | --- |
| Vulcanus | `lie` | `Notary Office` | Chromatic Printer (cyan) | industrial and metallurgical certification | cyan | Implemented first pass |
| Gleba | `bullshit-ore` via `amber-sap`; easy `dubious-data` | `Capture Bureau` + `Conciliation Desk` | Chromatic Printer (yellow) | biosafety, pacification, hostile-intake, workforce paperwork | yellow | Implemented first pass |
| Fulgora | `redundant-rubble` via salvage; easy `useless-documentation` | `Digital Services Bureau` | Chromatic Printer (magenta) | fast computerized processing, archive recovery, electromagnetic permits | magenta | Implemented first pass |
| Aquilo | none; multi-planet convergence | `Interplanetary Fax Exchange` | Laser Printer only (ink freezes) | multicolor composite forms, fax routing, transfer media | none (uses imported CMY) | Implemented first pass |

## Implemented Vulcanus Principles

Vulcanus is the reference pass because it already exists in-game.

Its design principles are:

- solve launch viability with local shortcuts, not by recreating the entire Nauvis office tree
- make the planet good at `lie`, with `dubious-data` arriving as a constrained useful byproduct
- keep the `chromatic-printer` narrow and coherent
- move the support-heavy or legally dense work into the `notary-office`
- use Vulcanus-exclusive paperwork in Administratorio's interplanetary paperwork chains
- the `notary-office` requires a `licensed-notary` worker to craft but no operating paperwork

### Vulcanus bootstrap layer

The first playable Vulcanus pass adds early bootstrap recipes so the planet can stand up its own admin base:

- `paper-production-vulcanus`
- `carbon-offset-certificate-basic-vulcanus`
- `redundant-rubble-recovery-vulcanus`
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
- `good-excuse-vulcanus`
- `management-approval-written-vulcanus`
- `government-grant-vulcanus`

### Vulcanus export paperwork

Vulcanus creates non-copyable forms that matter off-world:

- `thermal-process-license`
- `calcite-reagent-waiver`
- `offworld-metallurgy-charter`

These forms feed Administratorio's interplanetary permits and convergence paperwork. They do not alter or clone vanilla Vulcanus processes.

Additionally, cyan forms are required as ingredients in any recipe consuming tungsten plate, making Vulcanus paperwork essential for late-game manufacturing everywhere.

### Vulcanus implementation result

The current implementation target has been reached:

- Vulcanus can locally satisfy the planner path for `rocket-silo`
- Vulcanus can locally satisfy the planner path for `100x rocket-part`
- bulk imports of the old blocking administrative materials are no longer required for that escape target

## Planned Gleba Principles

Gleba should inherit the shared rules, but with a biological identity rather than an industrial one.

Key design principles:

- use Gleba's real vanilla strengths first: easy paper from greenhouse wood, easy coffee from greenhouse agriculture, and organic rocket ingredients where vanilla already provides them
- add exactly one new raw resource, `amber-sap`, and make it the indirect source of cheap local nonsense rather than adding easy `lie` or easy `redundant-rubble`
- make Gleba the easy-`bullshit-ore` planet and therefore an easy-`dubious-data` planet, but only through biological processing and yellow-paperwork shortcuts
- keep the specialized surface rules on Gleba-only items, forms, buildings, and intermediates instead of cloning vanilla end-product recipes
- split the planet reward into a hostile-intake building and a paperwork building: `Capture Bureau` for biter-facing intake, `Conciliation Desk` for yellow exception paperwork
- make Gleba-special paperwork short-lived and organic: yellow stock and finalized yellow forms should spoil back into `paper`
- keep escape viable, but do not make Gleba a full self-sufficient mall planet; ordinary factories should still lean on imports, seed forms, and black-ink copying
- both `Capture Bureau` and `Conciliation Desk` require a `conciliation-officer` worker to craft but no operating paperwork
- yellow forms are required as ingredients in any recipe consuming carbon fiber, making Gleba paperwork essential for late-game manufacturing

The export identity should center on:

- workforce reassignment
- pacification and luring paperwork
- biosafety waivers
- `biochamber`-adjacent operating paperwork

## Planned Fulgora Principles

Fulgora should be the computerized processing and archive recovery planet.

Key design principles:

- make Fulgora the easy-`redundant-rubble` planet indirectly through salvage, archive teardown, and ruined-template recovery rather than through a direct paperwork ore patch
- let `useless-documentation` become an easy derivative of that salvage economy, not the planet's only identity
- the `Digital Services Bureau` is the planet's administrative reward: a computerized, electromagnetic-powered upgrade to the standard admin office that works faster and operates 24/7 (no night closure)
- keep magenta work focused on archive recovery, electromagnetic processing permits, and digital certification rather than on fax routing (faxing belongs to Aquilo)
- avoid cloning vanilla end-product recipes; Fulgora should solve documentation throughput and archive bottlenecks, not become a second Nauvis production graph
- keep first-planet escape viable, but make large generic buildouts still depend on shipped cargo, imported seed forms, and reconstruction capacity
- the `Digital Services Bureau` requires a `relay-clerk` worker to craft but no operating paperwork
- magenta forms are required as ingredients in any recipe consuming holmium plate, making Fulgora paperwork essential for late-game manufacturing

The export identity should center on:

- archive recovery
- electromagnetic processing permits
- fast digital processing (Digital Services Bureau shipped to other planets)
- `electromagnetic plant`-adjacent paperwork

## Planned Aquilo Principles

Aquilo is intentionally not part of the any-order first-planet trio.

Key design principles:

- Aquilo should not introduce a fourth ink; liquid ink freezes on Aquilo so the Chromatic Printer cannot operate there
- only the `Laser Printer` works on Aquilo, using solid transfer media instead of liquid ink
- the `Interplanetary Fax Exchange` is Aquilo's administrative building, owning routing, queuing, and cross-planet document reconstruction
- Aquilo science unlocks multicolor form recipes that combine imported colored forms and inks from multiple planets into composite documents
- multicolor forms gate late-game recipes that use intermediates from multiple planets
- the `Laser Printer` should be the best machine for final print speed and fax reconstruction, not for dense office certification work
- the `Interplanetary Fax Exchange` requires a `cryoprint-technician` worker to craft but no operating paperwork
- mixed-planet paperwork should become normal on Aquilo rather than awkward

Its export identity should center on:

- multicolor composite forms
- transfer media
- high-speed reconstruction
- fax routing and interplanetary document logistics
- `cryogenic plant`-adjacent licensing

## Recommended Implementation Order

1. Keep Vulcanus maintained as the reference implementation.
2. Build Gleba next using the same machine-split and import-seed rules.
3. Build Fulgora after that so the Digital Services Bureau and magenta ink family are established.
4. Use Aquilo as the late-game capstone with faxing and multicolor forms.
