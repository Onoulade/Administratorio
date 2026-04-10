# Administratorio Progression Ledger

Derived from the code in `prototypes/`, `data-final-fixes.lua`, `overrides/vanilla.lua`, and the runtime scripts.

This file tracks the actual progression model implemented by the mod, not just the intended design.

## Core Loops

### Bootstrap loop

1. Gather `wood` and `coal`.
2. Handcraft `paper` and `ink`.
3. Use the starting `mechanical-printer` to print `blank-form` and `blank-approval`.
4. Handcraft `office-desk`.
5. Hand-mine `redundant-rubble` to trigger `discovery-redundant-rubble`.
6. Use the desk to make `provisional-approval`.
7. Handcraft `admin-station` and `resolution-office`.
8. Hand-mine `bullshit-ore` to trigger `discovery-bullshit`.
9. Use a stone furnace plus `carbon-offset-certificate-basic` to batch-smelt plates and `dubious-data`.
10. Use the desk to make `basic-excuse`.
11. Process landscape complaints for the first steady `taxpayer-money`.

### Science loop

1. Craft a `lab` to trigger vanilla `automation-science-pack`.
2. That unlocks `automation-science-pack` and, via mod hook, `research-grant-approval-production`.
3. Produce `automation-science-pack`.
4. Research `automation` to unlock `work-order-production` and the early combined work-order recipes.
5. Research `administrative-science-research` to unlock `administrative-science-pack-production`.
6. Produce `administrative-science-pack` at the `office-desk`.

### Bureaucracy loop

1. Forms gate automation.
2. Complaint resolution gates `taxpayer-money`.
3. `taxpayer-money` gates bonds, grants, late Union HQ policy work, and several late-game buildings.
4. Coffee, lies, misinformation, credentials, data, narrative, policy, and regulation form the late-game admin economy.

## Building Roles

| Building | Category / role | Notes |
| --- | --- | --- |
| `office-desk` | `bureaucracy-registration` | Base forms, approvals, work-orders, science, excuses, bonds input chain, verified certificates, environmental permits |
| `resolution-office` | `bureaucracy-resolution`, `bureaucratic-bootstrap` | All complaint filing / case / final recipes plus legacy brief compatibility crafts; now also covers the shared bootstrap complaint filing entry points |
| `mechanical-printer` | `printing` | Early printer, burner powered |
| `printer-t1` | `printing`, `printing-workorder` | Midgame printer |
| `printer-t2` | `printing`, `printing-advanced`, `printing-workorder` | Copying and high-throughput printing |
| `greenhouse` | `admin-greenhouse` | Renewable wood, coffee discovery, coffee cultivation |
| `corporate-breakroom` | `watercooler-gossip` | Coffee, gossip, good excuses, verbal approvals |
| `propaganda-distillery` | `propaganda-distillery` | Lie, misinformation, slush fund, justification chain |
| `union-headquarters` | `union-negotiation`, `bureaucracy-policy` | Union approval, grants, narrative, written approvals, policy work, tax audits |
| `admin-station` | storage + complaint desk | Holds tickets, resolved items, and payouts |

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
| Furnaces | `carbon-offset-certificate-basic` / `carbon-offset-certificate-verified` | Smelting and rubble compression already run on certificates |
| Oil processing | `petrochemical-operating-permit` | Reusable refinery permit built from safety, construction, EIR, and Form 27B-6 |
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
| `pneumatic-form-transport` | `compacted-rubble-production`, pneumatic buildings | Form logistics and rubble compression |
| `local-precedents` | `printer-t2`, copy recipes, `useless-documentation-production`, `form-27b-6` | Real midgame paperwork acceleration |
| `streamlined-work-orders` | direct draft-to-work-order printing | Throughput upgrade for early combined forms |
| `industrial-propaganda` | distillery, lie / misinformation chain, coffee discovery, blank directives | Opens the true admin economy |

### Chemical and late stage

| Tech | Main unlocks | Progression meaning |
| --- | --- | --- |
| `environmental-compliance` | breakroom, coffee refining, verbal approvals, treasury bonds, verified certificates, environmental reports, petrochemical permit, smog + hazmat resolution, eviction notices | First real funding, coffee economy, steel/compliance paperwork, and process-industry permitting |
| `health-and-safety` | union HQ, justification, narrative, written approvals, radiological work order, government grants | Opens late-form, executive paperwork, centrifuge paperwork, and grant chain |
| `board-meetings` | written management proposal + heavy printer approval pass | Opens the executive committee layer inside Union HQ |
| `eminent-domain-zoning` | white paper, policy, verified certificates, noise + loitering resolution, slush fund | High-bureaucracy policy tier |
| `federal-regulation` | regulation | Formal law layer for the final complaint tier |
| `creative-accounting` | tax audit | Converts slush funds back into official revenue through a dedicated late-game funding loop |
| `constitutional-law` | unemployment + vagrancy resolution | Final complaint tier |

## Complaint Unlock Ladder

| Complaint pair | Available after | Recipe depth |
| --- | --- | --- |
| `landscape` | start | filing -> final |
| `littering` | `littering-resolution` | filing -> final |
| `smog` + `hazmat` | `environmental-compliance` | filing -> case -> final |
| `noise` + `loitering` | `eminent-domain-zoning` | filing -> case -> final |
| `unemployment` + `vagrancy` | `constitutional-law` | filing -> case -> final |

### Runtime complaint generation

| Enemy | Complaint count | Max tier |
| --- | --- | --- |
| small biter / spitter | 1 | tier 1 |
| medium biter / spitter | 3 | tier 2 |
| big biter / spitter | 6 | tier 3 |
| behemoth biter / spitter | 10 | tier 4 |

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
3. `coffee-refining` turns `coffee-bean` + `water` + `work-order` into `liquid-coffee`.
4. `politician-fluid-refining` makes `lie`.
5. `misinformation-production` + `credentials-production` + `data-production` build the admin-intelligence layer.
6. `justification` -> `narrative` -> `white-paper` -> `policy` -> `regulation` is the late chain.

## Machine-Category Notes

- `assembling-machine-1` only crafts `crafting-regulated`.
- `assembling-machine-2` and `assembling-machine-3` only keep regulated categories as well, but fluid-capable vanilla recipes are reassigned onto `advanced-crafting-regulated` so they remain machine-usable.
- Above red science, the original vanilla recipe is repurposed onto a regulated category instead of leaving a handcraft-only fallback.

## Important Structural Bottlenecks

### 1. Desk inventory is the real complaint cap

- `admin-station` has `inventory_size = 20`.
- Each waiting zone has 8 biter slots.
- Big and behemoth citizens generate 6 to 10 tickets each.
- Practical desk throughput is inventory-limited long before zone capacity is reached.

### 2. Complaint tech unlocks lag vanilla evolution

- Medium enemies can generate tier-2 complaints before `environmental-compliance`.
- Big enemies can generate tier-3 complaints before `eminent-domain-zoning`.
- Behemoths can generate tier-4 complaints before `constitutional-law`.
- Nothing in runtime filters complaint tiers by player tech.

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
## Files To Re-check When Rebalancing

- `prototypes/technology.lua`
- `prototypes/recipe/paperwork.lua`
- `prototypes/recipe/resolution.lua`
- `prototypes/recipe/economy.lua`
- `data-final-fixes.lua`
- `scripts/biters.lua`
- `scripts/constants.lua`
- `locale/en/config.cfg`
