# Technology Tree

The entire research tree is reworked around bureaucratic milestones instead of military ones. New branches for paperwork throughput, renewable wood and coal, approvals, public finance, queue capacity, workforce management, logistics formations, and the late complaint families.

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

### Biter Employment Office (`biter-employment-office`)

- **Prerequisites:** `industrial-printing`, `local-precedents`
- **Science:** 90 auto + 90 logistic + 90 chemical + 90 admin science-pack (30s)
- **Unlocks:** `biter-station`

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

### Smog Abatement (`smog-abatement`)

- **Prerequisites:** `environmental-compliance`
- **Science:** 90 auto + 90 logistic + 90 admin science-pack (30s)
- **Unlocks:** `filing-smog`, `case-smog`, `smog-final`

### Hazmat Response (`hazmat-response`)

- **Prerequisites:** `environmental-compliance`
- **Science:** 100 auto + 100 logistic + 100 admin science-pack (30s)
- **Unlocks:** `filing-hazmat`, `case-hazmat`, `hazmat-final`

### Nest Expropriation (`nest-expropriation`)

- **Prerequisites:** `information-management`, `industrial-propaganda`
- **Science:** 90 auto + 90 logistic + 90 admin science-pack (30s)
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

- **Prerequisites:** `executive-review`, `processing-unit`, `production-science-pack`
- **Science:** 210 auto + 210 logistic + 210 chemical + 210 production + 210 admin science-pack (60s)
- **Unlocks:** `white-paper-production`, `policy-production`, `slush-fund-production`

### Work Order Duplication (`work-order-duplication`)

- **Prerequisites:** `industrial-printing`, `radiological-compliance`, `processing-unit`, `production-science-pack`
- **Science:** 180 auto + 180 logistic + 180 chemical + 180 production + 180 admin science-pack (60s)
- **Unlocks:** copy recipes for all 8 work-order families

### Federal Regulation (`federal-regulation`)

- **Prerequisites:** `eminent-domain-zoning`
- **Science:** 240 auto + 240 logistic + 240 chemical + 240 production + 240 admin science-pack (60s)
- **Unlocks:** `regulation`

### Noise Ordinances (`noise-ordinances`)

- **Prerequisites:** `federal-regulation`, `utility-science-pack`
- **Unlocks:** `filing-noise`, `case-noise`, `noise-final`

### Loitering Ordinances (`loitering-ordinances`)

- **Prerequisites:** `federal-regulation`, `utility-science-pack`
- **Unlocks:** `filing-loitering`, `case-loitering`, `loitering-final`

### Constitutional Law (`constitutional-law`)

- **Prerequisites:** `federal-regulation`, `production-science-pack`
- **Science:** 260 auto + 260 logistic + 260 chemical + 260 production + 260 admin science-pack (60s)
- **Unlocks:** `filing-unemployment`, `case-unemployment`, `unemployment-final`, `filing-vagrancy`, `case-vagrancy`, `vagrancy-final`

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
| Base | 1 | `small-biter` |
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
