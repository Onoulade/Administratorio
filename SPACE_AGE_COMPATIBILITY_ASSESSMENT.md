# Administratorio × Factorio: Space Age — Comprehensive Compatibility & Integration Assessment

**Assessment Date:** 2026-07-15  
**Mod Version:** 0.5.7  
**Factorio Version:** 2.0  
**Space Age Status:** Optional dependency (`? space-age >= 2.0.0`)

---

## Executive Summary

Administratorio is an ambitious total-conversion mod that replaces Factorio's military/biters gameplay with a bureaucracy/paperwork paradigm. Its Space Age integration is a **broad first-pass implementation** with all four planets (Vulcanus, Gleba, Fulgora, Aquilo) receiving administrative content, plus orbital/space-platform systems. The integration is structurally functional—automated validation passes—but still has implementation, test, mod-compatibility, and polish work to close.

**Overall Assessment:** **Functional Prototype / Early Access Grade** — Not yet a finished compatibility layer.

---

## 1. Code Quality Assessment

### 1.1 Architecture & Patterns

| Aspect | Status | Notes |
|--------|--------|-------|
| **Separation of concerns** | ✅ Good | Data stage (`data.lua`, `data-updates.lua`, `data-final-fixes.lua`) cleanly separated from control stage (`control.lua` + `scripts/`). |
| **Shared constants** | ✅ Good | `prototypes/shared.lua` is the single source of truth for paperwork items, batch multipliers, form requirements, admin buildings, etc. |
| **Feature flags** | ✅ Good | `feature_flags.lua` cleanly gates Space Age content and settings. |
| **Space Age rules split** | ✅ Good | `prototypes/shared/space_age_rules.lua` vs `non_space_age_rules.lua` keeps conditional logic isolated. |
| **Data-stage mocking for tests** | ✅ Good | Custom test framework loads real prototype files against a minimal `data` mock. |

### 1.2 Critical Code Quality Issues

#### **ISSUE-001: Massive `data-final-fixes.lua` — Monolithic God File**
- **File:** `data-final-fixes.lua`
- **Severity:** **High** — Maintenance burden, cognitive load, bug surface
- **Description:** This single file handles: recipe categories, character setup, military hiding, biter pacification, taxpayer money fuel injection, AM category reassignment, machine-family operating paperwork, factoriopedia merges, red-science detection, full recipe regulation (vanilla + admin buildings), oil-processing bulking, handcrafting visibility, admin recipe UI ordering, colored ink gating, space-platform permits, pneumatic tube notes, admin station collision masks, biterport fallback, rideable biter sounds, rocket silo finance, science pack stripping — **all in one linear pass**.
- **Impact:** Changes to one system risk breaking others; no modular testing of individual final-fix passes; difficult to reason about order dependencies.
- **Progress (2026-07-15):** Extracted independent military-hiding, collision/module-mask, science-pack stripping, colored-ink gating, and space-platform permit passes into `prototypes/final_fixes/`. The orchestrator fell from 1,926 to 1,523 lines; the central recipe-regulation engine remains the next large seam.
- **Solution:** Split into logical modules loaded from a thin orchestrator:
  - `final-fixes/recipe_regulation.lua`
  - `final-fixes/colored_ink_gating.lua`
  - `final-fixes/space_platform_permits.lua`
  - `final-fixes/collision_masks.lua`
  - `final-fixes/military_hiding.lua`
  - `final-fixes/science_pack_stripping.lua`
  - `final-fixes/fuel_injection.lua`
  - `final-fixes/factoriopedia.lua`
- **Trade-off:** More files, but each becomes independently testable and reviewable.

#### **ISSUE-002: Duplicated Recipe Regulation Logic**
- **Status:** **Resolved (2026-07-15)**
- **Resolution:** The fallback now delegates to `regulate_recipe()` with explicit options to preserve existing paperwork, convert tier forms to combined forms, and supply a fallback requirement. Timing, ingredient scaling, result scaling, and paperwork merging have one implementation.

#### **ISSUE-003: `shared.is_admin_recipe()` — Over-Broad Pattern Matching**
- **Status:** **Resolved (2026-07-15)**
- **Resolution:** `data.lua` registers every Administratorio recipe while loading this mod's prototype files. `shared.is_admin_recipe()` now uses that registry plus two intentional regulation exemptions (`paper-production`, `ink-production`); it no longer guesses from recipe-name patterns. A regression test proves third-party bureaucratic-looking names remain unclassified.

#### **ISSUE-004: `get_recipe_batch_multiplier()` — Heuristic-Driven Configuration**
- **File:** `data-final-fixes.lua` (lines 619–647)
- **Severity:** **Medium** — Maintenance risk
- **Description:** Batch multiplier defaults to 5×, but drops to 1× if:
  - Result stack size = 1
  - Result subgroup in `UNBATCHED_RESULT_SUBGROUPS`
  - Result is equipment-grid item
  - Explicit override in `BATCH_MULTIPLIERS`
- **Problem:** The multiplier values themselves are deliberate economy tuning. The implementation concern is that a stack-size heuristic plus a large exception table makes those intentional values difficult to audit and modify safely.
- **Evidence:** `BATCH_MULTIPLIERS` table (lines 500–587) contains 100+ explicit overrides.
- **Solution:** Keep the chosen multiplier values, but encode the policy explicitly per recipe (or in a dedicated configuration table) so changes are reviewable without relying on implicit stack-size behavior.

#### **ISSUE-005: `operating_form` Logic Split Across Category & Recipe Tables**
- **Status:** **Resolved (2026-07-15)**
- **Resolution:** The compatibility rules now use one `OPERATING_FORM_CONFIG` with category and recipe entries that each declare either `form` or `exempt`. Legacy lookup tables are generated compatibility views, not independent sources of truth.

#### **ISSUE-006: Pneumatic Tube System — Half Script, Half Data**
- **Status:** **Resolved (2026-07-15)**
- **Resolution:** A dependency-free `prototypes/shared/pneumatic_items.lua` now supplies the same payload list to data-stage descriptions and runtime validation. Its set/list parity is covered by a regression test; Factorio dump-data validation also removed a stale non-existent payload entry.

#### **ISSUE-007: Collision Mask Mutation — Global Side Effects**
- **File:** `data-final-fixes.lua` (lines 1753–1848)
- **Severity:** **Medium** — Mod compatibility risk
- **Description:** Iterates **ALL prototypes** in `data.raw`, adds `administratorio_station_footprint` layer to any entity with collision box, unless excluded by name/type/flag. Also forces `allowed_module_categories` on all entities with module slots > 0.
- **Risk:** Other mods adding entities after Administratorio's final-fixes won't get the layer. Mods removing the layer for their own reasons get it re-added. Module category forcing breaks mods that intentionally restrict modules.
- **Solution:** Use `data-final-fixes` only for Administratorio's own entities. For vanilla entities, use a targeted list or event-based runtime application.

---

### 1.3 Missed Opportunities for Reuse

| Pattern | Current State | Reusable Abstraction |
|---------|---------------|---------------------|
| Recipe ingredient manipulation | 6+ helper functions duplicated across regulation loops | `RecipeBuilder` fluent API |
| Paperwork requirement resolution | `get_paperwork_requirements()`, `normalize_paperwork_requirements()`, `paperwork_accum` in fallback | `PaperworkResolver` class |
| Icon layer composition | `clone_icon_layers()`, `shift_icon_layer()`, `apply_bulk_recipe_icon_overlay()`, `icon_layers.orbital_infrastructure_permit_overlay()` | `IconComposer` |
| Surface condition helpers | `surface_limited()`, `not_on_planet()`, `not_in_space()` in recipe files | `SurfaceCondition.planet(name)`, `.not_planet(name)`, `.space()`, `.vacuum()` |
| Technology prerequisite/unlock helpers | `add_tech_prerequisite()`, `add_tech_unlock()`, `remove_tech_unlock()` in 3 files | `TechGraph` mutation API |

---

## 2. Test Quality Assessment

### 2.1 Test Infrastructure

| Test Type | Count | Framework |
|-----------|-------|-----------|
| Lua unit tests (data-stage mocks) | 28 files | Custom minimal framework |
| Python integration tests | 3 files (`test_planet_escape.py`, `test_progression_report.py`, `test_planet_escape_policy.py`) | Custom Factorio dump analyzer |
| Runtime Lua tests | Several (`test_biterport_runtime.lua`, `test_fax_runtime.lua`, etc.) | Same custom framework |

### 2.2 Critical Test Quality Issues

#### **ISSUE-008: Tests Validate Constants, Not Behavior**
- **Files:** `test_recipes.lua`, `test_technology_gating.lua`, `test_space_age_content.lua`
- **Severity:** **High** — False confidence
- **Description:** Many tests assert that a recipe's ingredient list **exactly matches** a hardcoded table defined in the test itself — which was copied from the prototype. This validates *copy-paste fidelity*, not *design correctness*.
- **Example** (`test_recipes.lua:230`):
  ```lua
  test("paper-production recipe has correct ingredients", function()
      local recipe = get_recipe("paper-production")
      assert_ingredients(recipe, {
          {type = "item", name = "wood", amount = 10},
          {type = "item", name = "water", amount = 50},
      })
  end)
  ```
  The test data is copied from `prototypes/recipe/paperwork.lua`. If the prototype is wrong, the test passes.
- **Impact:** Incorrect ingredients, missing gates, and wrong tiers can pass alongside the copied expectation.
- **Solution:** Tests should validate **invariants and derived properties**, not raw data:
  - "Every T1+ building recipe requires a combined form"
  - "No regulated recipe has stack-size-1 results with multiplier > 1"
  - "All Space Age planet-specific recipes have correct surface conditions"
  - "Colored ink gating: every tungsten-carbide recipe has cyan form"
- **Progress:** Ownership registration and pneumatic payload parity now have invariant tests. The broader recipe suite still needs the same treatment.

#### **ISSUE-009: No End-to-End Scenario Tests for Critical Paths**
- **Severity:** **High** — Cannot establish real playability
- **Description:** The repository has mocked runtime tests and a headless smoke test, but no scripted Factorio scenarios that verify end-to-end critical paths such as:
  - Can a player actually reach Vulcanus with only local paperwork?
  - Does the fax network deliver documents under backpressure?
  - Do biter stations actually spawn workers?
  - Does pneumatic transport move items at expected rates?
- **Evidence:** `test_planet_escape.py` does static graph analysis on dumped prototypes — it proves *reachability in the prototype graph*, not *playability*.
- **Solution:** Add headless Factorio scenario tests for critical paths:
  - `scenarios/space-age-vulcanus-bootstrap/test.lua`
  - `scenarios/fax-roundtrip/test.lua`
  - `scenarios/biter-station-spawn/test.lua`

#### **ISSUE-011: Python Analyzers Not Integrated Into Test Suite**
- **Status:** **Resolved**
- **Resolution:** `tests/run-tests.sh` accepts `--factorio-bin` and runs both dump-data analyzers when provided; the full run was verified against Factorio 2.0.77.

---

## 3. Gameplay Coverage Assessment

### 3.1 Space Age Planet Coverage Matrix

| Gameplay System | Nauvis | Vulcanus | Gleba | Fulgora | Aquilo | Orbital/Space |
|-----------------|--------|----------|-------|---------|--------|---------------|
| **Raw Admin Resources** | bullshit-ore, redundant-rubble, politician-fluid | verdigris-crust (lie) | amber-sap (bullshit-ore) | charged-toner (static charge), redundant-rubble (salvage) | — | — |
| **Ink Production** | black ink | cyan ink | yellow ink | magenta ink | **frozen** (no liquid ink) | — |
| **Printer Tier** | Printer T1/T2 | Chromatic Printer (cyan) | Chromatic Printer (yellow) | Chromatic Printer (magenta) | Laser Printer (transfer media) | — |
| **Admin Building** | Admin Station, Field Office, Resolution Office, Union HQ, etc. | Notary Office, Territorial Arbitration Post | Capture Bureau, Conciliation Desk | Digital Services Bureau | Laser Printer, Fax Emitter, Interplanetary Fax Exchange | Admin Space Station, Trajectory Compliance Arrays, Orbital Employment Cannon |
| **Workforce** | Worker Biter, Clerical Trainee, Management Trainee, Astronaut, Licensed Notary | Licensed Notary | Conciliation Officer | Relay Clerk | Cryoprint Technician | Middle Management Managing Manager (MMMM) |
| **Paperwork Family** | Full T0–T7 tree | Cyan forms, permits, charters, thermal process license | Yellow forms (spoiling), symbiosis, conciliation | Magenta forms, archive recovery, digital certs | Bicolor/trichromatic forms, cryogenic licenses, unified charter | Orbital permits, deviation orders, asteroid dockets |
| **Unique Mechanic** | Pneumatic tubes, protests, working hours | Lie distillation, territorial arbitration | Spore lures, hostile acquisition, tourism, spoilage | Scrap→toner, archive recovery, 24/7 bureau | Frozen ink constraint, fax reconstruction, transfer media | Asteroid redirection, orbital employment, platform permits |

### 3.2 Genuine Coverage Gaps

The following intentional gameplay choices are **not** defects: Aquilo is an import-dependent capstone rather than a first planet; liquid ink freezes there; yellow paperwork spoils on Gleba; workers gate planet-specific buildings; and the Digital Services Bureau is a portable, 24/7 upgrade to the standard admin office. They should be judged in playtests as tuning, not tracked as compatibility failures.

#### **GAP-003: Gleba Spoilage — Missing Scenario-Level Validation**
- **Severity:** **Medium** — Validation gap
- **Description:** Short-lived yellow paperwork is intentional, but the suite only verifies that spoilage fields exist. It does not establish whether a normal local Conciliation Desk loop behaves as designed under real belt, insertion, and production timing.
- **Solution:** Add a headless scenario or documented playtest target that sustains one Conciliation Desk from local Gleba production and records spoilage losses. Treat its result as tuning evidence, not as a presumption that the mechanic is defective.

#### **GAP-004: Space Tourism — Disconnected from Core Loop**
- **Severity:** **Medium** — Content isolation
- **Description:** Tourism captures spitters on Nauvis → packages → launches to Admin Space Station → spoils → hatches → jettison for money. Uses `cyan-yellow-form` gating (requires Vulcanus + Gleba science).
- **Problem:** Tourism is a **side activity** with no connection to main progression (rocket parts, science, paperwork). Payouts: 75/175/450/1200 taxpayer-money. No tech unlocks, no paperwork consumption beyond cyan-yellow-form.
- **Impact:** Feels like a minigame, not integrated bureaucracy.
- **Solution:** Tie tourism to `public-transportation-contract` or `bureaucratic-transcendence`. Tourists generate `office-drama` or `narrative` on return.
- **Arbitration:** **NOT deliberate** — user confirmed should integrate. This remains a genuine integration gap.


---

## 4. Thematic Consistency Assessment

### 4.1 Strengths

| Theme | Implementation | Verdict |
|-------|----------------|---------|
| **Vulcanus = Industrial Bureaucracy** | Lie distillation, notary offices, thermal process licenses, territorial arbitration, industrial charters | ✅ **Excellent** — Coherent industrial/legal theme |
| **Gleba = Biological Bureaucracy** | Amber sap → bullshit-ore, spore lures, conciliation, spoiling forms, bio-pacification | ✅ **Excellent** — Organic/administrative fusion |
| **Fulgora = Digital/Archive Bureaucracy** | Static charge → toner, scrap → rubble/docs, digital services bureau, electromagnetic permits | ✅ **Strong** — Computerized paperwork |
| **Aquilo = Cryogenic/Transfer Bureaucracy** | Frozen ink constraint, laser printer, transfer media, fax reconstruction, multicolor convergence | ✅ **Strong** — Physical constraint drives design |
| **Taxpayer Money = Nauvis Only** | Explicit "tax evasion" rule — offworld recipes use local resources/chromatic inks | ✅ **Excellent** — Clear thematic boundary |

### 4.2 Thematic Polish Opportunities

#### **THEME-003: Space Tourism Uses Spitter Icons — Confusing**
- **Issue:** Tourism items use spitter icons with admin overlays. But spitters are **Nauvis enemies** being captured for tourism. The thematic link (biters → tourists) is clever but the visual language conflates "enemy" with "customer."
- **Solution:** Distinct "space tourist" icon (biter in Hawaiian shirt / camera) vs "captured spitter" icon.

#### **THEME-004: Fax Queue/Recovery State Could Be More Visible**
- **Status:** **Polish opportunity, not a compatibility defect**
- **Description:** Faxing is intentionally reconstruction with destination-side supplies and queueing. The UI could make the queue and reconstruction states more legible, so its non-teleportation fiction reads immediately.
- **Potential improvement:** Show transmission/reconstruction progress and the destination-side media requirement.

---

## 5. Progression & Technology Tree Assessment

### 5.1 Technology Tree Structure

```
T0: Administrative Science (automation + admin-sci)
  ├─ Printing Technology (printer-t1)
  ├─ Administrative Bureaucracy (greenhouse, wood)
  └─ Discovery chains (bullshit-ore, redundant-rubble)

T1: Industrial Printing (printer-t2, copies) → requires chemical-sci
  ├─ Local Precedents (useless-documentation, form-27b-6)
  ├─ Rubble Compaction
  ├─ Streamlined Work Orders (combined forms)
  ├─ Littering Resolution
  ├─ Nest Pacification (hush money)
  └─ Pneumatic Form Transport

T2: Corporate Hospitality (breakroom, coffee, gossip) 
  ├─ Office Agriculture (coffee plantation)
  ├─ Charcoal Production
  ├─ Industrial Propaganda (distillery, politician fluid, lies)
  ├─ Information Management (data, good excuse)
  └─ Verbal Approvals (directives, verbal work-orders)

T3: Environmental Compliance (impact reports, chemical work-orders, verified carbon offset)
  ├─ Smog Abatement
  ├─ Hazmat Response
  ├─ Nest Expropriation (eviction notices)
  └─ Synthetic Stationery (synthetic paper)

T4: Public Finance (bonds, grants, union HQ) → requires union-delegate-training
  ├─ Health & Safety (justification, narrative, OSHA)
  ├─ Board Meetings (written proposals)

T5: Executive Review (written work-orders)
  ├─ Radiological Compliance (radiological work-orders)

T6: Eminent Domain & Zoning (white paper, policy, slush fund) → requires production-sci
  ├─ Work Order Duplication (copy all work-orders)
  ├─ Federal Regulation (regulation production)
  ├─ Noise Ordinances
  └─ Loitering Ordinances → requires utility-sci

T7: Constitutional Law (unemployment) → requires federal regulation
  └─ Vagrancy Ordinances → requires constitutional law + utility-sci
```

**Space Age Branch (h):**
```
h-a: Chromatic Printing (cyan/yellow/magenta inks, blank forms) → requires executive-review
h-b: Workforce Formation (formation center, trajectory arrays, orbital cannon, astronauts, MMMM) → requires space-sci + executive-review
h-c: Vulcanus Certification (notary, territorial arbitration, vulcanus forms) → requires chromatic-printing
h-c2: Vulcanus Export Charters (thermal license, calcite waiver, metallurgy charter) → requires vulcanus-cert + metallurgic-sci
h-d: Gleba Conciliation (capture bureau, conciliation desk, yellow ink) → trigger: craft 50 bullshit-ore
h-e: Fulgora Digital Services (digital bureau, archive recovery, magenta ink) → trigger: craft 20 charged-toner
h-e1: Cyan-Yellow Bureaucracy → requires vulcanus-cert + gleba-conciliation + metallurgic + agricultural
h-e2: Cyan-Magenta Bureaucracy → requires vulcanus-cert + fulgora-digital + metallurgic + electromagnetic
h-e3: Yellow-Magenta Bureaucracy → requires gleba-conciliation + fulgora-digital + agricultural + electromagnetic
h-f: Aquilo Fax Network (laser printer, fax exchange, transfer media, trichromatic, unified charter) → requires all 3 bicolor + cryogenic-sci
h-f-a: Bureaucratic Transcendence (public train stop) → requires aquilo-fax
h-f-b: Color Faxing → requires aquilo-fax
h-g/h-h/h-i: Fax Queue Capacity upgrades
```

### 5.2 Intentional Progression Boundaries

The administrative-science timing, science-pack distribution, profession-access order, technology costs, batch multipliers, and Aquilo’s CMY-import restriction are progression and difficulty choices. They are not compatibility defects. Future playtests may tune their values, but this assessment does not prescribe alternative values.

---

## 6. Exploitability & Edge Cases

#### **EXPLOIT-001: Pneumatic Tube Item Duplication via Quality**
- **Severity:** **Medium** — If quality enabled
- **Status:** **Resolved (2026-07-15)**
- **Resolution:** Tube signal-pool entries now key both item name and quality. Intake removal, outtake insertion, circuit signals, and last-endpoint rescue spills preserve that identity; legacy name-only save entries decode as normal quality. `test_pneumatic_runtime.lua` verifies exact one-for-one transport of a legendary document with no residual pool entry.

## 7. Cross-Cutting Integration Issues

### 7.1 Base-Only vs Space Age Boundary Leaks

| Leak | File | Status |
|------|------|--------|
| `amber-sap-seep` resource prototype | `prototypes/resources.lua` | ✅ Fixed (gated by feature_flags) |
| `verdigris-crust` resource prototype | `prototypes/resources.lua` | ✅ Fixed |
| `static-charge-deposit` resource prototype | `prototypes/resources.lua` | ✅ Fixed |
| `capture-bureau` entity extension | `prototypes/entity/admin-buildings.lua` | ✅ Fixed |
| `admin-station.additional_pastable_entities` reference | `prototypes/entity/admin-buildings.lua` | ✅ Fixed |
| Surface conditions (pressure/gravity) in recipes | `data-final-fixes.lua`, recipe files | ⚠️ **Needs audit** — some may leak |

**Remaining Risk:** Any new Space Age prototype added without `feature_flags.space_age_enabled()` guard will break base-only loading.

### 7.2 Mod Compatibility

- **Hidden Military Prototypes:** `data-final-fixes.lua` lines 195–233 hide **all** vanilla guns, ammo, turrets, railgun, tesla. **Breaks mods adding military content** (they get hidden).
- **Collision Mask Mutation:** Adds layer to all entities (lines 1833–1848). **Breaks mods relying on specific collision masks**.
- **Module Category Forcing:** Forces all module slots to accept all standard categories (lines 1840–1846). **Breaks mods with restricted modules** (e.g., "only efficiency modules").
- **Recipe Regulation:** Regulates **all** vanilla crafting recipes. **Breaks mods adding recipes to crafting/advanced-crafting categories** — they get regulated copies with paperwork.
- **Science Pack Stripping:** Removes science packs from **all** recipe ingredients (lines 1940–1966). **Breaks mods using science packs as crafting ingredients**.

**Solution:** Add mod compatibility layer:
- `data-final-fixes.lua` should check `mods["mod-name"]` and skip aggressive overrides for known mods.
- Provide API: `administratorio.exempt_recipe(name)`, `administratorio.exempt_entity(name)`, `administratorio.exempt_technology(name)`.

---

## 8. Prioritized Non-Design Action Plan

### **P0 — Critical (Blockers for "Complete" Status)**

| ID | Task | Owner | Effort |
|----|------|-------|--------|
| ISSUE-001 | Split `data-final-fixes.lua` into modular passes | Dev | 3 days |
| ISSUE-008 | Convert static prototype tests → invariant tests | Dev | 5 days |
| ISSUE-009 | Add headless critical-path scenario tests | Dev | 3 days |

### **P1 — High (Validation & Integration)**

| ID | Task | Owner | Effort |
|----|------|-------|--------|
| GAP-003 | Add Gleba spoilage runtime test | Dev | 2 days |
| GAP-004 | Integrate space tourism into main progression | Dev | 3 days |

### **P2 — Medium (Polish & Consistency)**

| ID | Task | Owner | Effort |
|----|------|-------|--------|
| ISSUE-004 | Make batch-multiplier policy explicit per recipe/configuration | Dev | 2 days |
| Mod compatibility | Add targeted exemptions/API for aggressive global prototype changes | Dev | 3 days |

### **P3 — Low (Nice to Have)**

| ID | Task | Owner | Effort |
|----|------|-------|--------|
| THEME-003 | Distinct space tourist icons | Art | 1 day |
| THEME-004 | Fax UI shows reconstruction progress | Dev/UI | 2 days |
| ISSUE-007 | Targeted collision mask/module category application | Dev | 1 day |
| EXPLOIT-001 | Pneumatic quality duplication test | Dev | 1 day |

---

## 9. Conclusion

Administratorio's Space Age integration is **architecturally ambitious and thematically coherent** — each planet has a distinct bureaucratic identity that mirrors its industrial identity. The paperwork gating system (colored forms for planet intermediates) is a **brilliant design** that creates genuine interplanetary trade.

However, the implementation is a **broad first pass** with:

1. **Significant code quality debt** (monolithic final-fixes and configuration that relies on implicit heuristics)
2. **Insufficient scenario-level validation** for critical gameplay paths
3. **Mod compatibility risks** from aggressive global prototype changes
4. **One confirmed integration gap:** space tourism remains disconnected from the main progression loop

The planet asymmetries and constraints are intentional gameplay doctrine, not defects: Aquilo is a late import-dependent capstone; its ink freezes; Gleba paperwork spoils; specialist workers are an upfront cost in place of operating permits; and Fulgora's bureau is a portable 24/7 office upgrade.

**Recommendation:** Prioritize the remaining implementation and validation work before marking Space Age compatibility "complete." Preserve the documented planet identities while making their code paths and tests easier to trust.

---

*Report generated by comprehensive static analysis of prototypes, scripts, tests, and canonical internal design documentation. Deliberate gameplay choices are recorded as design boundaries, not issues.*
