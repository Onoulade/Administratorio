# Space Age Implementation Steps

This file tracks the next concrete implementation steps for the Space Age expansion, in recommended order.

## Phase 1: Colored Ink Gating (Cross-Planet, High Priority)

This is the single most impactful missing mechanic. Without it, colored inks are optional. With it, they become essential.

### Step 1.1: Identify all vanilla recipes consuming planet intermediates

Scan all vanilla Space Age recipes for:

- **Tungsten plate** consumers: turrets, railgun ammo, mech armor, etc.
- **Carbon fiber** consumers: power armor, rocket parts, etc.
- **Holmium plate** consumers: beacons, quality modules, electromagnetic science, etc.

Produce a complete list of recipes to gate.

### Step 1.2: Define the gating forms

Decide which specific cyan/yellow/magenta form is consumed per recipe:

- Simple recipes: consume a basic colored blank (e.g., `blank-cyan-form`)
- Advanced recipes: consume a more specialized form (e.g., `thermal-process-license`)
- Recipes using intermediates from 2+ planets: will later require Aquilo multicolor forms

### Step 1.3: Implement gating as recipe modifications in data-final-fixes

Add the colored form as an additional ingredient to each identified recipe. This should be done in `data-final-fixes.lua` so it catches modded recipes too if desired, or in a dedicated Space Age recipe file.

### Step 1.4: Verify solver still reaches targets

Run the planner/solver for each planet's escape path to confirm the new form requirements don't create impossible loops (e.g., needing a cyan form to craft something needed to make cyan forms).

---

## Phase 2: Vulcanus Worker Requirement for Notary Office

### Step 2.1: Add `licensed-notary` to Notary Office crafting recipe

The Notary Office recipe should include 1x `licensed-notary` as an ingredient, matching how the Foundry already requires one.

### Step 2.2: Verify solver still works

Confirm the Vulcanus escape path still resolves with the added worker requirement.

---

## Phase 3: Gleba Completion

### Step 3.1: Add worker requirements to Capture Bureau and Conciliation Desk recipes

Both should require 1x `conciliation-officer` in their crafting recipe.

### Step 3.2: Implement yellow form gating for carbon fiber recipes

Add yellow forms as ingredients to all vanilla recipes consuming carbon fiber.

### Step 3.3: Implement spoilage for yellow paperwork

Configure spoil timers on `mycelial-form-stock`, `blank-yellow-form`, and all finalized yellow forms. They should spoil back into `paper`.

### Step 3.4: Complete Gleba bootstrap recipes

Following the Vulcanus bootstrap pattern, add any missing local recipes needed for Gleba to reach rocket escape without bulk Nauvis imports.

### Step 3.5: Add operating paperwork exemptions for Gleba buildings

Ensure Capture Bureau and Conciliation Desk are exempt from operating paperwork.

### Step 3.6: Verify solver for Gleba escape path

---

## Phase 4: Fulgora — Digital Services Bureau

### Step 4.1: Define Digital Services Bureau entity

- Crafting categories: same as admin station (or superset)
- Speed: significantly faster than admin station (3-4x?)
- Energy: high (electromagnetic-powered)
- No night closure mechanic
- Module slots: TBD
- Requires 1x `relay-clerk` in crafting recipe
- Crafting recipe includes electromagnetic components (processing units, holmium)
- Surface-limited to Fulgora for crafting

### Step 4.2: Define magenta ink production chain

- Source material from Fulgora salvage (charged-toner, signal-toner)
- `magenta-ink` fluid production
- `signal-form-stock` and `blank-magenta-form` printing

### Step 4.3: Define Fulgora paperwork family

- Archive recovery permits
- Digital processing certificates
- Electromagnetic operating licenses
- Fulgora bootstrap recipes for escape viability

### Step 4.4: Implement magenta form gating for holmium recipes

Add magenta forms as ingredients to all vanilla recipes consuming holmium plate.

### Step 4.5: Define Fulgora's `redundant-rubble` advantage

Design the salvage-to-rubble loop using Fulgora's scrap resources.

### Step 4.6: Verify solver for Fulgora escape path

---

## Phase 5: Aquilo — Fax Exchange and Multicolor Forms

### Step 5.1: Move Interplanetary Fax Exchange to Aquilo

- Update entity definition: surface-limited to Aquilo for crafting
- Requires 1x `cryoprint-technician` in crafting recipe
- Update technology unlock to Aquilo progression

### Step 5.2: Define Laser Printer entity

- Crafting categories: printing, multicolor printing, fax reconstruction
- Speed: fastest printer in the game
- Uses solid transfer media inputs (no liquid ink pipes)
- Requires 1x `cryoprint-technician` in crafting recipe
- Surface-limited to Aquilo for crafting

### Step 5.3: Implement frozen ink constraint

- Prevent Chromatic Printer placement/operation on Aquilo (surface condition or category restriction)
- Ensure no liquid ink recipes are available on Aquilo

### Step 5.4: Define transfer media items

- `transfer-emulsion`: cryogenic transfer medium
- `thermal-transfer-sheet`: solid transfer substrate
- `composite-chroma-ribbon`: premium multi-ink carrier (requires imported colored forms)

### Step 5.5: Define multicolor form family

- `composite-form`: two-color form (gates dual-intermediate recipes)
- `trichromatic-permit`: three-color form (gates tri-intermediate recipes)
- `unified-operations-charter`: top-tier composite
- `cryogenic-operations-license`: Aquilo-specific permit

### Step 5.6: Implement multicolor gating for multi-planet recipes

Identify recipes using intermediates from 2+ planets and add multicolor form requirements.

### Step 5.7: Define fax network mechanics

Design the actual faxing loop: sender, routing, reconstruction, transfer media consumption.

### Step 5.8: Verify all planet escape paths still work

---

## Phase 6: Cross-Cutting Cleanup

### Step 6.1: Audit all operating paperwork exemptions

Verify every planet-specific building (both vanilla and mod) is properly exempt from operating paperwork.

### Step 6.2: Audit all worker requirements

Verify every planet-specific building requires the correct specialist worker in its crafting recipe.

### Step 6.3: Audit tax evasion

Verify no planet-local recipe requires raw `taxpayer-money`.

### Step 6.4: Update professions plan

Ensure the professions plan aligns with all new building requirements (especially Digital Services Bureau needing relay-clerk, Fax Exchange needing cryoprint-technician).

### Step 6.5: Update public finance plan

Ensure the finance plan reflects the tax evasion principle and any new derivative finance instruments needed.
