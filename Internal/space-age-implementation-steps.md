# Space Age Implementation Steps

This file tracks the next concrete implementation steps for the Space Age expansion, in recommended order.

## Current Status Snapshot

Implemented first pass:

- Generic colored-form gating in `data-final-fixes.lua`
  - `tungsten-plate` / `tungsten-carbide` -> `blank-cyan-form`
  - `carbon-fiber` -> `blank-yellow-form`
  - `holmium-plate` -> `blank-magenta-form`
- `notary-office` now requires `licensed-notary`
- `capture-bureau` and `conciliation-desk` now require `conciliation-officer`
- Gleba yellow paperwork spoilage is in place
- Gleba bootstrap variants now exist:
  - `carbon-offset-certificate-basic-gleba`
  - `admin-station-gleba`
  - `printer-t1-gleba`
  - `corporate-breakroom-gleba`
  - `administrative-science-pack-production-gleba`
- Fulgora first pass now exists:
  - `digital-services-bureau`
  - `charged-toner`
  - `magenta-ink`
  - `signal-form-stock`
  - `blank-magenta-form`
  - `archive-recovery-permit`
  - `digital-processing-certificate`
  - `electromagnetic-operating-license`
  - `data-recovery-order`
- Targeted Lua coverage exists for the current Vulcanus, Gleba, Fulgora, and final-fixes passes

Still missing:

- Actual solver / planner verification for the new CMY gating and worker requirements
- Fulgora's salvage-to-`redundant-rubble` advantage
- Any extra Fulgora bootstrap recipes that the solver proves necessary
- Aquilo / fax / multicolor implementation
- Cross-cutting audits

---

## Phase 1: Colored Ink Gating (Cross-Planet, High Priority)

Status: first pass implemented. Remaining work is verification plus later refinement of which higher-tier recipes should use specialized forms instead of the base blanks.

### Step 1.1: Identify all vanilla recipes consuming planet intermediates

Status: effectively superseded by the generic ingredient scan in `data-final-fixes.lua`.

### Step 1.2: Define the gating forms

Status: first-pass choice made.

- Current rule: all current planet-intermediate gates use the basic blank CMY forms
- Later refinement: selected high-tier recipes may be upgraded to consume specialized forms instead
- Aquilo multicolor forms will still own the multi-planet convergence case later

### Step 1.3: Implement gating as recipe modifications in data-final-fixes

Status: done.

### Step 1.4: Verify solver still reaches targets

Run the planner / solver for:

- Vulcanus escape after cyan gating and worker requirements
- Gleba escape after yellow gating, spoilage, and bootstrap additions
- Fulgora escape after magenta gating and the first-pass bureau chain

Record any loops or dead ends before moving deeper into Aquilo.

---

## Phase 2: Vulcanus Worker Requirement for Notary Office

### Step 2.1: Add `licensed-notary` to Notary Office crafting recipe

Status: done.

### Step 2.2: Verify solver still works

Still pending. This should be rolled into Phase 1.4's broader solver verification pass.

---

## Phase 3: Gleba Completion

### Step 3.1: Add worker requirements to Capture Bureau and Conciliation Desk recipes

Status: done.

### Step 3.2: Implement yellow form gating for carbon fiber recipes

Status: done in `data-final-fixes.lua`.

### Step 3.3: Implement spoilage for yellow paperwork

Status: done for:

- `mycelial-form-stock`
- `blank-yellow-form`
- `symbiosis-record`
- `conciliation-order`
- `biochamber-operating-waiver`

### Step 3.4: Complete Gleba bootstrap recipes

Status: first pass done.

Added:

- `carbon-offset-certificate-basic-gleba`
- `admin-station-gleba`
- `printer-t1-gleba`
- `corporate-breakroom-gleba`
- `administrative-science-pack-production-gleba`

Follow-up only if solver requires more:

- add further narrow escape-path variants rather than cloning broad Nauvis production ladders

### Step 3.5: Add operating paperwork exemptions for Gleba buildings

Status: done by current admin-recipe handling and native Space Age operating-paperwork exemptions.

### Step 3.6: Verify solver for Gleba escape path

Still pending. Run the actual planner and only add more Gleba-local shortcuts if the solver proves they are necessary.

---

## Phase 4: Fulgora — Digital Services Bureau

### Step 4.1: Define Digital Services Bureau entity

Status: first pass done.

Current implementation:

- Crafting categories: `bureaucracy-registration`, `bureaucratic-bootstrap`
- Speed: `3`
- Energy: `1MW`
- No working-hours shutdown integration
- Module slots: `6`
- Craft recipe requires `relay-clerk`
- Craft recipe includes `processing-unit` and `holmium-plate`
- Surface-limited to Fulgora for crafting

### Step 4.2: Define magenta ink production chain

Status: first pass done.

Current implementation:

- `charged-toner`
- `magenta-ink-production`
- `signal-form-stock`
- `blank-magenta-form-production`

Note:

- the source side is currently simplified to one salvage intermediate, `charged-toner`
- split toner intermediates can be revisited later if the planet needs more texture

### Step 4.3: Define Fulgora paperwork family

Status: mostly done, bootstrap still open.

Implemented:

- `archive-recovery-permit`
- `digital-processing-certificate`
- `electromagnetic-operating-license`
- `data-recovery-order`

Still open:

- decide whether Fulgora needs any explicit bootstrap variants comparable to Gleba / Vulcanus for escape viability

### Step 4.4: Implement magenta form gating for holmium recipes

Status: done in `data-final-fixes.lua`.

### Step 4.5: Define Fulgora's `redundant-rubble` advantage

This is the main remaining Fulgora design gap.

Next task:

- design a salvage / scrap / archive-recovery loop that turns Fulgora abundance into easy `redundant-rubble` and `useless-documentation`

Constraint:

- do this through salvage recovery, not by adding a trivial direct paper-ore substitute

### Step 4.6: Verify solver for Fulgora escape path

Still pending. Run after Step 4.5 if the salvage loop is necessary, or immediately if the current first-pass bureau chain might already be enough.

---

## Phase 5: Aquilo — Fax Exchange and Multicolor Forms

This is now the main unimplemented planet slice.

### Step 5.1: Move Interplanetary Fax Exchange to Aquilo

- Update entity definition: surface-limited to Aquilo for crafting
- Requires 1x `cryoprint-technician` in crafting recipe
- Update technology unlock to Aquilo progression

### Step 5.2: Define Laser Printer entity

- Crafting categories: printing, multicolor printing, fax reconstruction
- Speed: fastest printer in the game
- Uses solid transfer media inputs instead of liquid ink
- Requires 1x `cryoprint-technician` in crafting recipe
- Surface-limited to Aquilo for crafting

### Step 5.3: Implement frozen ink constraint

- Prevent Chromatic Printer placement or operation on Aquilo
- Ensure no liquid ink recipes are available on Aquilo

### Step 5.4: Define transfer media items

- `transfer-emulsion`
- `thermal-transfer-sheet`
- `composite-chroma-ribbon`

### Step 5.5: Define multicolor form family

- `composite-form`
- `trichromatic-permit`
- `unified-operations-charter`
- `cryogenic-operations-license`

### Step 5.6: Implement multicolor gating for multi-planet recipes

Identify recipes using intermediates from 2+ planets and add multicolor form requirements.

### Step 5.7: Define fax network mechanics

Design the actual faxing loop:

- sender
- routing
- reconstruction
- transfer media consumption

### Step 5.8: Verify all planet escape paths still work

---

## Phase 6: Cross-Cutting Cleanup

### Step 6.1: Audit all operating paperwork exemptions

Verify every planet-specific building, both vanilla and modded, is properly exempt from recurring operating paperwork.

### Step 6.2: Audit all worker requirements

Verify every planet-specific building requires the correct specialist worker:

- Vulcanus -> `licensed-notary`
- Gleba -> `conciliation-officer`
- Fulgora -> `relay-clerk`
- Aquilo -> `cryoprint-technician`

### Step 6.3: Audit tax evasion

Verify no planet-local recipe requires raw `taxpayer-money`.

### Step 6.4: Update professions plan

Ensure the professions plan matches the actual implemented building requirements, especially:

- `digital-services-bureau` -> `relay-clerk`
- future Aquilo buildings -> `cryoprint-technician`

### Step 6.5: Update public finance plan

Ensure the finance plan reflects the tax-evasion rule and any new off-world finance instruments that become necessary.
