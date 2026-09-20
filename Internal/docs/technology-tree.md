# Technology Tree

The entire research tree is reworked around bureaucratic milestones instead of military ones. New branches cover paperwork throughput, renewable wood and coal, approvals, public finance, queue capacity, workforce management, logistics formations, Space Age jurisdictions, and the late complaint families. Science counts and prerequisites below describe the current prototype graph; the in-game technology cards remain the final authority when another mod changes vanilla research.

## Trigger Technologies (Discovery)

### Discovery: Redundant Rubble (`discovery-redundant-rubble`)

- **Trigger:** Hand-mine `redundant-rubble`
- **Unlocks:** `provisional-approval-production`, `burner-mining-drill`
- **Meaning:** First custom technology; the bureaucracy finds its first form.

### Discovery: Bullshit (`discovery-bullshit`)

- **Trigger:** Hand-mine `bullshit-ore`
- **Unlocks:** `dubious-data-refining`, `basic-excuse-production`, `safety-waiver-draft`, `safety-waiver-printing`, `construction-permit-draft`, `construction-permit-printing`
- **Meaning:** The certificate supply chain begins.

### Administrative Science Research (`administrative-science-research`)

- **Prerequisites:** `automation`
- **Science:** 10 automation-science-pack (15s)
- **Unlocks:** `administrative-science-pack-production`

### Printing Technology (`printing-technology`)

- **Prerequisites:** `administrative-science-research`
- **Science:** 20 automation + 20 admin science-pack (15s)
- **Unlocks:** `printer-t1`

### Steam Power and Field Office (`steam-power` → `field-office-deployment`)

- `steam-power` unlocks the `field-office` recipe.
- Crafting the first Field Office triggers `field-office-deployment`; this is a craft trigger, not a research card.
- The trigger unlocks provisional approvals, promises, and the Biter Administration Desk.
- `printing-technology` and `biter-employment` depend on this deployment milestone, so the Office Desk is not an opening handcraft.

## Early Game

### Wood Production (`administrative-bureaucracy`)

- **Prerequisites:** `automation`, `discovery-redundant-rubble`
- **Science:** 20 automation-science-pack (15s)
- **Unlocks:** `greenhouse`, `greenhouse-wood`
- **Note:** Display name is "Wood Production"; sits on red science only.

### Littering Resolution (`littering-resolution`)

- **Prerequisites:** `printing-technology`
- **Science:** 25 auto + 25 admin science-pack (20s)
- **Unlocks:** `crappy-report-production`, `filing-littering`, `littering-final`

## Mid Game

### Industrial Printing (`industrial-printing`)

- **Prerequisites:** `administrative-bureaucracy`, `steel-processing`, `advanced-circuit`, `chemical-science-pack`
- **Science:** 90 auto + 90 logistic + 90 chemical + 90 admin science-pack (30s)
- **Unlocks:** `printer-t2`, copy-blank-form, copy-blank-approval, copy-carbon-offset-certificate, copy-form-27b-6, copy-environmental-impact-report

### Local Precedents (`local-precedents`)

- **Prerequisites:** `administrative-bureaucracy`, `littering-resolution`
- **Science:** 60 auto + 60 logistic + 60 admin science-pack (30s)
- **Unlocks:** `useless-documentation-production`, `form-27b-6`

### Nest Pacification (`nest-pacification`)

- **Prerequisites:** `industrial-printing`, `local-precedents`
- **Science:** 90 auto + 90 logistic + 90 chemical + 90 admin science-pack (30s)
- **Unlocks:** `hush-money`

### Pneumatic Form Transport (`pneumatic-form-transport`)

- **Prerequisites:** `local-precedents`, `rubble-compaction`, `filing-logistics`
- **Science:** 90 auto + 90 logistic + 90 chemical + 90 admin science-pack (30s)
- **Unlocks:** pneumatic pipes, tube intakes/outtakes, all pneumatic intake recipes
- **Payload scope:** all core administrative payloads and, with Space Age, every finished planetary document. Raw heatproof, mycelial, and signal form stock is excluded. Interplanetary payload eligibility remains a separate whitelist.

### Biter Employment Office (`biter-employment-office`)

- **Prerequisites:** `biter-employment`, `fluid-handling`
- **Science:** 140 auto + 140 logistic + 140 admin science-pack (30s)
- **Unlocks:** `biter-station`

### Biter Employment (`biter-employment`)

- **Unlocks:** `office-desk`, `job-offer-production`, and the base-game `resolution-office`.
- **Space Age:** `job-offer-production` remains here, while `worker-formation` supplies the Resolution Office unlock after the Formation Center route exists.

### Streamlined Work Orders (`streamlined-work-orders`)

- **Prerequisites:** `industrial-printing`
- **Science:** 90 auto + 90 logistic + 90 chemical + 90 admin science-pack (30s)
- **Unlocks:** direct draft-to-work-order printing shortcuts

### Industrial Propaganda (`industrial-propaganda`)

- **Prerequisites:** `littering-resolution`, `fluid-handling`, `rubble-compaction`, `biter-employment-office`
- **Science:** 70 auto + 70 logistic + 70 admin science-pack (30s)
- **Unlocks:** `propaganda-distillery`, `politician-fluid-refining`, `misinformation-production`, `refined-nonsense-production`, `credentials-production`

### Corporate Hospitality (`corporate-hospitality`)

- **Prerequisites:** `administrative-bureaucracy`, `biter-employment-office`
- **Science:** 70 auto + 70 logistic + 70 admin science-pack (30s)
- **Unlocks:** `corporate-breakroom`, `greenhouse-discovery`, `coffee-refining`, `watercooler-gossip-production`, `office-drama-recycling`

### Information Management (`information-management`)

- **Prerequisites:** `corporate-hospitality`, `industrial-propaganda`, `advanced-circuit`
- **Science:** 85 auto + 85 logistic + 85 admin science-pack (30s)
- **Unlocks:** `data-production`, `good-excuse-production`

### Verbal Approvals (`verbal-approvals`)

- **Prerequisites:** `corporate-hospitality`
- **Science:** 80 auto + 80 logistic + 80 admin science-pack (30s)
- **Unlocks:** `blank-directive-production`, `copy-blank-directive`, `management-verbal-work-order-production`, `management-verbal-draft`, `management-verbal-printing`

## Late Game

### Environmental Compliance (`environmental-compliance`)

- **Prerequisites:** `local-precedents`, `fluid-handling`, `steel-processing`, `biter-employment-office`
- **Science:** 95 auto + 95 logistic + 95 admin science-pack (30s)
- **Unlocks:** `environmental-impact-report`, `chemical-handling-work-order-production`, `carbon-offset-certificate-verified`

### Medium Complaint Administration (`administratorio-medium-complaints`)

- **Prerequisites:** environmental compliance, chemical-operator training, industrial propaganda, printing, and biter employment
- **Science:** 100 auto + 100 logistic + 100 admin science-pack (30s)
- **Unlocks:** smog and hazmat resolution chains; raises the evolution ceiling from 20% to 45%
- **Progression gate:** required before chemical science

### Nest Expropriation (`nest-expropriation`)

- **Prerequisites:** `information-management`, `industrial-propaganda`, `nest-pacification`, `chemical-science-pack`
- **Science:** 90 auto + 90 logistic + 90 chemical + 90 admin science-pack (30s)
- **Unlocks:** `eviction-notice-production`

### Synthetic Stationery (`synthetic-stationery`)

- **Prerequisites:** `environmental-compliance`, `plastics`, `sulfur-processing`
- **Science:** 120 auto + 120 logistic + 120 chemical + 120 admin science-pack (30s)
- **Unlocks:** `synthetic-paper-production`

### Public Finance (`public-finance`)

- **Prerequisites:** `verbal-approvals`, `local-precedents`, `advanced-circuit`, `union-delegate-training`, `chemical-science-pack`, `steel-processing`, `biter-employment-office`
- **Science:** 145 auto + 145 logistic + 145 chemical + 145 admin science-pack (45s)
- **Unlocks:** `treasury-bond-production`, `union-headquarters`, `union-approval-production`, `government-grant-production`

### Health and Safety (`health-and-safety`)

- **Prerequisites:** `public-finance`, `information-management`
- **Science:** 150 auto + 150 logistic + 150 chemical + 150 admin science-pack (45s)
- **Unlocks:** `justification-production`, `narrative-production`, `osha-scrubbing`, `osha-violation-recycling`

### Board Meetings (`board-meetings`)

- **Prerequisites:** `public-finance`, `health-and-safety`
- **Science:** 135 auto + 135 logistic + 135 chemical + 135 admin science-pack (45s)
- **Unlocks:** `management-written-proposal`, `management-written-1st-printing`

### Charcoal Production (`charcoal-production`)

- **Prerequisites:** `verbal-approvals`
- **Science:** 140 auto + 140 logistic + 140 admin science-pack (45s)
- **Unlocks:** certified 5x furnace batch: 25 wood + 1 carbon-offset-certificate-basic → 5 coal

### Executive Review (`executive-review`)

- **Prerequisites:** `board-meetings`, `health-and-safety`
- **Science:** 175 auto + 175 logistic + 175 chemical + 175 admin science-pack (45s)
- **Unlocks:** `management-written-work-order-production`

### Radiological Compliance (`radiological-compliance`)

- **Prerequisites:** `executive-review`, `environmental-compliance`, `battery`
- **Science:** 160 auto + 160 logistic + 160 chemical + 160 admin science-pack (45s)
- **Unlocks:** `radiological-work-order-production`

### Eminent Domain & Zoning (`eminent-domain-zoning`)

- **Prerequisites:** `executive-review`, `processing-unit`
- **Science:** 210 auto + 210 logistic + 210 chemical + 210 admin science-pack (60s)
- **Unlocks:** `white-paper-production`, `policy-production`, `slush-fund-production`

### Work Order Duplication (`work-order-duplication`)

- **Prerequisites:** `industrial-printing`, `radiological-compliance`, `processing-unit`, `synthetic-stationery`
- **Science:** 180 auto + 180 logistic + 180 chemical + 180 admin science-pack (60s)
- **Unlocks:** copy recipes for all 8 work-order families

### Federal Regulation (`federal-regulation`)

- **Prerequisites:** `eminent-domain-zoning`, `work-order-duplication`
- **Science:** 175 auto + 175 logistic + 175 chemical + 175 admin science-pack (60s)
- **Unlocks:** `regulation`

### Large Complaint Administration (`administratorio-large-complaints`)

- **Prerequisites:** medium complaints, federal regulation, information management, and health and safety
- **Science:** 200 auto + 200 logistic + 200 chemical + 200 admin science-pack (60s)
- **Unlocks:** noise and loitering resolution chains; raises the evolution ceiling from 45% to 60%
- **Progression gate:** required before production and utility science

### Behemoth Complaint Administration (`administratorio-behemoth-complaints`)

- **Base science:** 400 auto + logistic + chemical + production + utility + admin science-pack (60s)
- **Space Age science:** the base set plus space, metallurgic, electromagnetic, and agricultural science; no cryogenic science
- **Unlocks:** unemployment and vagrancy resolution chains; removes the evolution ceiling
- **Progression gate:** required before Aquilo discovery in Space Age and before space science in the base game

### Creative Accounting (`creative-accounting`)

- **Prerequisites:** `eminent-domain-zoning`, `narrative`
- **Unlocks:** `tax-audit`

## Specialization Training

| Technology | Prerequisites | Unlocks |
| --- | --- | --- |
| `union-delegate-training` | `biter-employment-office` | Union Delegate specialist |
| `chemical-operator-training` | `environmental-compliance`, `biter-employment-office` | Chemical Operator specialist (required for chemical plants) |
| `nuclear-technician-training` | `executive-review`, `production-science-pack` | Nuclear Technician specialist (required for nuclear power) |

### Labor Efficiency

<!-- BEGIN GENERATED: labor-efficiency-facts -->
<!-- Generated by tools/generate-reference-docs.lua; do not edit by hand. -->
| Technology | Managed-machine Visits per Trip | Worker Entity |
| --- | --- | --- |
| Base | 1 | `biter-worker-t1` |
| `biter-labor-efficiency-1` | 3 | `biter-worker-t2` |
| `biter-labor-efficiency-2` | 5 | `biter-worker-t3` |
<!-- END GENERATED: labor-efficiency-facts -->

## Biterport Technologies

`biterport-logistics` unlocks the building and its basic formations and chests.

<!-- BEGIN GENERATED: biterport-transport-facts -->
<!-- Generated by tools/generate-reference-docs.lua; do not edit by hand. -->
| Technology | Items per Worker |
| --- | --- |
| Base | 1 |
| `biterport-transport-capacity-1` | 2 |
| `biterport-transport-capacity-2` | 5 |
| `biterport-transport-capacity-3` | 10 |
| `biterport-transport-capacity-4` | 25 |
<!-- END GENERATED: biterport-transport-facts -->

<!-- BEGIN GENERATED: biterport-speed-facts -->
<!-- Generated by tools/generate-reference-docs.lua; do not edit by hand. -->
| Technology | Movement Multiplier | Worker Entity |
| --- | --- | --- |
| Base | 1.00× | `biterport-worker` |
| `biterport-worker-speed-1` | 1.35× | `biterport-worker-fast` |
| `biterport-worker-speed-2` | 1.70× | `biterport-worker-express` |
<!-- END GENERATED: biterport-speed-facts -->

## Pneumatic Capacity

<!-- BEGIN GENERATED: pneumatic-capacity-facts -->
<!-- Generated by tools/generate-reference-docs.lua; do not edit by hand. -->
| Technology | Total Network Capacity |
| --- | --- |
| Base | 10 |
| `pneumatic-capacity-1` | 25 |
| `pneumatic-capacity-2` | 50 |
| `pneumatic-capacity-3` | 100 |
| `pneumatic-capacity-4` | 200 |
<!-- END GENERATED: pneumatic-capacity-facts -->

## Rideable Biter (`rideable-biter`)

- Unlocks personal transport that runs on Taxpayer Money
- Available well before the vanilla car
- Cannot be picked back up once placed — assignment is permanent
- Run out of funding for 10 minutes and it reverts to a regular biter and files a complaint

## Space Age

Space Age progression is a set of jurisdiction branches rather than one straight ladder. Each planet first bootstraps its local paperwork before its science pack becomes part of the wider bureaucracy.

### Planetary Branches

| Branch | Technologies | Main unlocks |
| --- | --- | --- |
| Shared pre-planet | `chromatic-printing` | Chromatic Printer, black ink, shared colored-form framework |
| Vulcanus | `cyan-ink-production`, `vulcanus-certification`, `vulcanus-export-charters` | Cyan paperwork, Notary Office, Territorial Arbitration Post, local and off-world metallurgy charters |
| Gleba | `amber-sap-processing`, `gleba-yellow-administration`, `gleba-conciliation` | Yellow paperwork, Conciliation Desk, Capture Bureau modes, biological exception paperwork |
| Fulgora | `fulgora-salvage-administration`, `fulgora-digital-services`, `archive-recombination` | Magenta salvage, Digital Services Bureau, electromagnetic paperwork, archive reassignment |
| Cross-planet | `cyan-yellow-bureaucracy`, `cyan-magenta-bureaucracy`, `yellow-magenta-bureaucracy` | Pairwise colored forms, tourism and cross-jurisdiction data/permit routes |
| Aquilo | `aquilo-cryogenic-administration` | Laser Printer, solid transfer media, cryogenic operations license, Cryoprint Technician |

### Workforce and Orbital Branches

| Technology family | Unlocks |
| --- | --- |
| `worker-formation` | Worker Biter formation and, in Space Age, the staffed Resolution Office route |
| `management-formation` | Clerical, management, and reusable cross-planet manager briefings |
| `specialized-formation` | Astronaut formation for platform administration |
| `orbital-employment-infrastructure` | Administrative Space Station and platform paperwork production |
| `orbital-compliance-systems` | Trajectory Compliance Array, deviation orders, Orbital Miner Deployment Catapult, and VESM formation |
| `trajectory-compliance-jurisdiction-1..3` | Array range and asteroid-size authority: Junior, Senior, then Executive |
| `trajectory-compliance-speed-1..9` | Array cooldown from 4.5 seconds down to 0.5 seconds |
| `orbital-employment-damage-1..5` | VESM mining damage from 206.25 to 481.25 per second |
| `orbital-employment-capacity-1..4` | One through five simultaneous miners per asteroid |

### Interplanetary Paperwork

| Technology family | Main unlocks |
| --- | --- |
| `interplanetary-tube-network` | Interplanetary Terminus and the black-paperwork trunk; three forms in flight at the base trunk tier |
| `interplanetary-tube-capacity-2..5` | Raises in-flight capacity to 5, 10, 15, and 20 while reducing transit time |
| `interplanetary-tube-additional-terminus-1..3` | Adds parallel terminus capacity; the third tier is infinite |
| `interplanetary-tube-chromatic` | Colored and composite trunk payloads, advanced charter payloads, and Promethium research charters |
| `bureaucratic-transcendence` | Public Train Stop: no transit chest, no per-arrival authorization, no paperwork train limit |

### Aquilo Endgame Systems

- `aquilo-ai-inference` unlocks the AI Server, Slop Refinery, Heat Exhaust, Optic Fibre, and rank 0–1 uncolored slop paperwork.
- `administratorium-slop-synthesis` adds rank 2–3 uncolored paperwork and fabricated citation handling. Slop never creates colored forms.
- `unstaffed-operations` unlocks an unstaffed-operations waiver when Working Hours is enabled. The technology is absent when that startup setting is disabled.
- `synthetic-personnel` unlocks the Synthetic Personnel Bureau and synthesis for Licensed Notaries, Conciliation Officers, Relay Clerks, and Cryoprint Technicians.
- `egg-courier-formation` keeps eggs on Nauvis while trained couriers carry authorization off-world.
- `involuntary-relocation` unlocks the Cannon, Receiver, transfer orders, and staff cargo recipes. It is a request-and-match system, not a manually aimed cannon.

### Space Age Complaint Fast Tracks

The eight chromatic complaint technologies are separate follow-up research rather than automatic unlocks:

`chromatic-landscape-resolution`, `chromatic-littering-resolution`, `chromatic-smog-resolution`, `chromatic-hazmat-resolution`, `chromatic-noise-resolution`, `chromatic-loitering-resolution`, `chromatic-unemployment-resolution`, and `chromatic-vagrancy-resolution`.

Each adds its matching colored or composite complaint recipe and requires the relevant planet science. The final two require the full interplanetary chromatic tier and cryogenic science.
