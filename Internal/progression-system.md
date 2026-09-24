# Administratorio Progression Ledger

Derived from the code in `prototypes/`, `data-final-fixes.lua`, `overrides/vanilla.lua`, and the runtime scripts.

This file tracks the actual progression model implemented by the mod, not just the intended design.

## Core Loops

### Bootstrap loop

1. Gather `wood` and `coal`.
2. Handcraft `paper` and `ink`.
3. Use the starting `mechanical-printer` to print `blank-form` and `blank-approval`.
4. Research `steam-power`, then craft and place the `field-office` near a biter nest.
5. Hand-mine `redundant-rubble` and `bullshit-ore` to trigger both discovery technologies.
6. Craft the first Field Office recipe to trigger `field-office-deployment`, which unlocks provisional approvals, promises, and the `admin-station`.
7. Research the printing, greenhouse, rubble-compaction, and automation branches as they become available.
8. Research `biter-employment` to unlock the `office-desk`, `job-offer` production, and the base-game `resolution-office`.
9. Use the Field Office and early paperwork chain to establish complaint processing, then collect the first steady `taxpayer-money`.

With Space Age enabled, `worker-formation` moves the Resolution Office unlock behind the Formation Center route; the Field Office remains the early bridge that makes the first hire possible.

### Science loop

1. Craft a `lab` to trigger vanilla `automation-science-pack`.
2. Research `automation` to unlock `work-order-production` and the early combined work-order recipes.
3. Research `administrative-science-research` to unlock `administrative-science-pack-production`.
4. Produce `administrative-science-pack` through the available bureaucracy category: the Field Office covers the early bootstrap, and the Office Desk takes over after `biter-employment`.

### Bureaucracy loop

1. Forms gate automation.
2. Complaint resolution gates `taxpayer-money`.
3. `taxpayer-money` gates bonds, grants, late Union HQ policy work, and several late-game buildings.
4. Coffee, lies, misinformation, credentials, data, narrative, policy, and regulation form the late-game admin economy.

## Building Roles

| Building | Category / role | Notes |
| --- | --- | --- |
| `office-desk` | `bureaucracy-registration` | Base forms, approvals, work-orders, science, excuses, bonds input chain |
| `resolution-office` | `bureaucracy-resolution`, `bureaucratic-bootstrap` | All complaint filing / case / final recipes plus legacy brief compatibility crafts; now also covers the shared bootstrap complaint filing entry points |
| `mechanical-printer` | `printing` | Early printer, burner powered |
| `printer-t1` | `printing`, `printing-workorder` | Midgame printer |
| `printer-t2` | `printing`, `printing-advanced`, `printing-workorder` | Copying and high-throughput printing |
| `greenhouse` | `admin-greenhouse` | Renewable wood, coffee discovery, coffee cultivation |
| `corporate-breakroom` | `watercooler-gossip` | Coffee, gossip, good excuses, verbal approvals |
| `propaganda-distillery` | `propaganda-distillery` | Lie, misinformation, slush fund, justification chain |
| `union-headquarters` | `union-negotiation`, `bureaucracy-policy` | Union approval, grants, verified certificates, narrative, written approvals, policy work, tax audits |
| `admin-station` | storage + complaint desk | Holds tickets, resolved items, and payouts |
| `field-office` | `bureaucracy-registration`, `bureaucratic-bootstrap` | Nauvis-only temporary workforce; unlocked by Steam Power and triggers Field Office Deployment on its first craft |
| `formation-center` | `biter-training` | Converts enrolled biters into workers and trains managers or specialists |
| `biter-station` | worker dispatch | Sends hired workers to managed machines; night dispatches consume coffee |
| `biterport` | walking logistics | Provides biter logistics and construction networks |
| `passenger-wagon` | passenger rail | Zero-inventory wagon with a protected manifest for up to 24 unresolved complaint visitors |
| `boarding-platform` / `deboarding-platform` | passenger rail | Rail-adjacent queue and unload points, with circuit controls and train/passenger signals; see [Passenger Rail Service](docs/advanced-topics.md#passenger-rail-service) |

The **Administration Desk Overview** shortcut summarizes force-wide desk capacity, inbound visitors, and protests, and opens Remote View at a selected desk. Passenger Rail Service is unlocked by `passenger-rail-service` after Railway, Biter Employment, and Chemical Science Pack research.

Space Age adds `chromatic-printer`, `laser-printer`, `notary-office`, `territorial-arbitration-post`, `conciliation-desk`, `capture-bureau`, `digital-services-bureau`, `archive-recombination-bureau`, `administrative-space-station`, the three trajectory-compliance arrays, `orbital-employment-catapult`, `interplanetary-terminus`, `ai-server`, `heat-exhaust`, `slop-refinery`, `synthetic-personnel-bureau`, and the involuntary relocation Cannon/Receiver pair. Their behavior is documented in [Buildings & Structures](docs/buildings-and-structures.md).

## Assembler Form Tiers

| Tier | Form | Intended use in regulated vanilla recipes |
| --- | --- | --- |
| T0 | `work-order` | Assembler-only basic intermediates, belts, pipes, base utility items |
| T1 | `safety-waiver` / `safety-work-order` | Inserters, poles, boiler / steam tier, AM1 |
| T2 | `construction-permit` / `construction-work-order` | Furnaces, mining drills, pumps, AM2, industrial building recipes, demolition |
| T3 | `management-approval-verbal` / `management-verbal-work-order` | Rail, solar, accumulators, roboport, personal roboports, robot logistics |
| T4 | `management-approval-written` / `management-written-work-order` | AM3, beacon, rocket silo, nuclear support hardware, late megaproject recipes |
| Science | `research-grant-approval` / `research-grant-work-order` | All science packs |

## Machine Operation Paperwork

| Machine family | Operating document | Notes |
| --- | --- | --- |
| Furnaces | `carbon-offset-certificate-basic` / `carbon-offset-certificate-verified` | Burner-furnace smelting and rubble compression run on certificates; electric furnaces can compact rubble without one |
| Oil processing | None | Refineries are gated by biter-station dispatch instead of operating paperwork |
| Chemistry | `chemical-handling-work-order` | Chemical-plant operating document; no longer shares assembler `work-order` |
| Centrifuging | `radiological-work-order` | Centrifuge operating document built from chemical paperwork and written approval |

## Actual Tech Ladder

### Trigger and red-tech stage

| Step | Unlock source | Important outputs |
| --- | --- | --- |
| Mine `redundant-rubble` | `discovery-redundant-rubble` | `provisional-approval-production`, `burner-mining-drill` |
| Mine `bullshit-ore` | `discovery-bullshit` | `dubious-data-refining`, `basic-excuse-production` |
| Craft `lab` | vanilla `automation-science-pack` | `automation-science-pack`, `research-grant-approval-production` |
| Research `automation` | vanilla | `assembling-machine-1`, `work-order-production`, `safety-work-order-production`, `construction-work-order-production`, `research-grant-work-order-production` |
| Research `administrative-science-research` | custom | `administrative-science-pack-production` |
| Research `printing-technology` | custom | `printer-t1` |

### Green-tech stage

| Tech | Main unlocks | Progression meaning |
| --- | --- | --- |
| `administrative-bureaucracy` | `greenhouse`, `greenhouse-wood` | Early red-science renewable wood bootstrap |
| `littering-resolution` | `crappy-report-production`, `filing-littering`, `littering-final` | First spitter support |
| `rubble-compaction` | `compacted-rubble-production` | Standardized rubble for infrastructure and pneumatic transport |
| `pneumatic-form-transport` | pneumatic buildings and intake recipes | Form logistics through shared tube networks |
| `industrial-printing` | `printer-t2`, bulk copy recipes | Real midgame paperwork acceleration |
| `passenger-rail-service` | Passenger Wagon, Boarding Platform, Unboarding Platform | Chemical-science rail transport for unresolved visitors |
| `local-precedents` | `useless-documentation-production`, `form-27b-6` | Local legal fiction and the precedent archive |
| `streamlined-work-orders` | direct draft-to-work-order printing | Throughput upgrade for early combined forms |
| `industrial-propaganda` | distillery, lie / misinformation chain, refined nonsense, credentials | Opens the true admin economy |
| `corporate-hospitality` | breakroom, coffee discovery/refining, gossip, verbal approvals | Separates the coffee chain from propaganda |

### Chemical and late stage

| Tech | Main unlocks | Progression meaning |
| --- | --- | --- |
| `environmental-compliance` | petrochemical permits and verified environmental reports | First process-industry permitting |
| `health-and-safety` | justification, narrative, OSHA scrubbing, violation recycling | Opens workplace-safety paperwork |
| `public-finance` | Union HQ, grants, union approval, treasury bonds | Opens the funding and executive administration chain |
| `board-meetings` | written management proposal + heavy printer approval pass | Opens the executive committee layer inside Union HQ |
| `eminent-domain-zoning` | white paper, policy, slush fund | Blue-science policy support for large complaints |
| `federal-regulation` | regulation | Formal law layer for the final complaint tier |
| `creative-accounting` | tax audit | Converts slush funds back into official revenue through a dedicated late-game funding loop |
| `administratorio-medium-complaints` | smog + hazmat resolution; 45% evolution ceiling | Required before chemical science |
| `administratorio-large-complaints` | noise + loitering resolution; 60% evolution ceiling | Required before production and utility science |
| `administratorio-behemoth-complaints` | unemployment + vagrancy resolution; removes ceiling | Required before Aquilo, or base-game space science |

## Complaint Unlock Ladder

| Complaint pair | Available after | Recipe depth |
| --- | --- | --- |
| `landscape` | start | filing -> final |
| `littering` | `littering-resolution` | filing -> final |
| `smog` + `hazmat` | `administratorio-medium-complaints` | filing -> case -> final |
| `noise` + `loitering` | `administratorio-large-complaints` | filing -> case -> final |
| `unemployment` + `vagrancy` | `administratorio-behemoth-complaints` | filing -> case -> final |

### Runtime complaint generation

<!-- BEGIN GENERATED: complaint-size-facts -->
<!-- Generated by tools/generate-reference-docs.lua; do not edit by hand. -->
| Biter Size | Complaint Count | Max Tier | Payout |
| --- | --- | --- | --- |
| Small | 1 | 1 (landscape / littering) | 5 taxpayer-money |
| Medium | 2 | 2 (adds smog / hazmat) | 15 taxpayer-money |
| Big | 3 | 3 (adds noise / loitering) | 50 taxpayer-money |
| Behemoth | 4 | 4 (adds unemployment / vagrancy) | 100 taxpayer-money |
<!-- END GENERATED: complaint-size-facts -->

Frustration threshold is `600` seconds. Protesters disable a random player building until pacified.
`promise` capsules now pacify a protester for up to `60` seconds while it retries to find an open desk. If no desk frees up before that timer expires, the protest resumes.

## Funding Chain

1. Resolve biter complaints.
2. Receive `taxpayer-money`.
3. Convert to `treasury-bond`.
4. Build the first `union-headquarters`.
5. Convert to `government-grant`.
6. Spend grants on Union HQ policy work, late modules, and complaint chains.
7. `tax-audit` launders `slush-fund` plus paperwork back into extra `taxpayer-money`.

## Coffee / Propaganda / Policy Chain

1. `greenhouse-discovery` gives the first `coffee-bean` at 10% probability while returning some of the input `wood`.
2. `coffee-plantation` bootstraps bean multiplication.
3. `coffee-refining` turns `coffee-bean` + `water` into `liquid-coffee`.
4. `politician-fluid-refining` makes `lie`.
5. `misinformation-production` + `credentials-production` + `data-production` build the admin-intelligence layer.
6. `justification` -> `narrative` -> `white-paper` -> `policy` -> `regulation` is the late chain.

## Important Structural Bottlenecks

### 1. Desk inventory is the real complaint cap

- Waiting capacity expands one slot per capacity research tier.
- Larger citizens generate several tickets each, as shown in the generated complaint table above.
- Practical desk throughput is inventory-limited long before zone capacity is reached.

<!-- BEGIN GENERATED: admin-station-facts -->
<!-- Generated by tools/generate-reference-docs.lua; do not edit by hand. -->
| Property | Value |
| --- | --- |
| Inventory size | 20 |
| Base waiting slots | 4 |
| Maximum waiting slots | 12 |
| Capacity upgrades | 8 (`admin-station-capacity-1` through `admin-station-capacity-8`) |
<!-- END GENERATED: admin-station-facts -->

### 2. Research gates enemy evolution

- Evolution is capped at 20%, 45%, and 60% until the medium, large, and behemoth complaint milestones are researched.
- Blocked gains are discarded. Raising a ceiling does not create an immediate catch-up spike.
- The most advanced player force controls the shared cap; Gleba evolution remains independent.

### 3. Taxpayer funding depends on complaint stability

- `taxpayer-money` is needed for bonds, grants, breakrooms, Union HQ expansion, and some late regulated recipes.
- Any disruption in complaint resolution directly slows tech progression.

### 4. Coffee starts with RNG

- The first `coffee-bean` still comes from `greenhouse-discovery` at 10% probability per craft.
- The discovery recipe refunds part of the input `wood`, so failed rolls are less punishing without producing unrelated byproducts.
- Coffee is required for verbal approvals, gossip, protest mitigation support, and many midgame recipes.

### 5. Early paper depends on wood availability

- `paper` is foundational.
- On low-tree starts, early paper and printer throughput are map sensitive until greenhouse wood is available.

## Current Implementation Mismatches Worth Remembering

These are not "design intent" notes. They are current-code notes.

- `administrative-science-pack-production` is unlocked by `administrative-science-research`, not by `administrative-bureaucracy`.
- `administrative-bureaucracy` now sits on red science only and no longer depends on `printing-technology`, so greenhouse wood arrives before the admin-science printer ramp.
- `safety-waiver-draft`, `safety-waiver-printing`, `construction-permit-draft`, and `construction-permit-printing` are enabled from the start.
- Because of that, T1 and T2 form production is front-loaded instead of being unlocked by later bureaucracy techs.
- `filing-landscape` still lives in `bureaucratic-bootstrap`, but the `resolution-office` now also has that category so it still handles the full complaint chain. The `office-desk` continues to share `bureaucratic-bootstrap`, but complaint processing is centered on the `resolution-office`.
- Legacy `brief-*` recipes still exist for save compatibility, but normal progression no longer routes through them.
- `assembling-machine-3` only keeps regulated categories in `data-final-fixes.lua`, even though shared comments describe AM3 as a reward that should also keep original categories.

## Files To Re-check When Rebalancing

- `prototypes/technology.lua`
- `prototypes/recipe/paperwork.lua`
- `prototypes/recipe/resolution.lua`
- `prototypes/recipe/economy.lua`
- `data-final-fixes.lua`
- `scripts/biters.lua`
- `scripts/constants.lua`
- `locale/en/config.cfg`
