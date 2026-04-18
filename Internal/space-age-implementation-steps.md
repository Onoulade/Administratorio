# Space Age Implementation Steps

This file tracks the next concrete implementation steps for the Space Age expansion, in recommended order.

## Assessment Snapshot — 2026-04-18

Branch assessed: `space-age`.

Working tree status before assessment: clean.

Static scope checked:

- `prototypes/recipe/space_age.lua`
- `prototypes/item/space_age.lua`
- `prototypes/entity/space_age.lua`
- `prototypes/entity/admin-buildings.lua`
- `prototypes/shared.lua`
- `prototypes/shared/space_age_rules.lua`
- `data-final-fixes.lua`
- `scripts/fax.lua`
- `scripts/fax_shared.lua`
- Space Age plan files under `Internal/`
- Space Age and runtime Lua tests under `tests/`

Verification actually run:

- Lua suite command: `for f in tests/test_*.lua; do lua "$f" || exit 1; done`
- Result: passed.
- Factorio binary supplied and used:
  - `~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio`
  - Reported version: Factorio 2.0.76, build 84451, mac-arm64, Steam, Space Age.
- Space Age planet escape analyzer command:
  - `python3 tests/test_planet_escape.py --factorio-bin "~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio" --show-steps --import-depth 2`
  - Result: passed.
  - Generated report path:
    - `/var/folders/6j/hmy0cn8s4zj369_0jzj21t940000gn/T/administratorio-planet-escape-rocayff4/script-output/administratorio-planet-escape-report.txt`
- Base-only strict progression command:
  - `python3 tests/test_progression_report.py --factorio-bin "~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio" --strict`
  - Result: passed.
  - Generated report path:
    - `/var/folders/6j/hmy0cn8s4zj369_0jzj21t940000gn/T/administratorio-techtest-z1co670p/script-output/administratorio-progression-report.txt`

Current confidence:

- The implemented prototype pass is broad and mostly covered by Lua tests.
- The current Space Age dump-based route analyzer reports no aggregate imports and no aggregate deadlocks for its selected escape targets.
- Base-only compatibility now loads and passes strict progression analysis while Space Age remains optional.
- No current automated validation blocker is known from the Lua suite, base-only strict progression analyzer, or Space Age route analyzer.
- Gameplay balance is not complete. The current work is a functional first pass, not a compatibility completion pass.

Resolved during the 2026-04-18 make-it-work pass:

- Restored the fax receiver queue header to `Required inks`, matching `tests/test_fax_runtime.lua`.
- Added `process_space_tourist_returns` to the startup cleanup test dependency stub, matching the controller dependency contract.
- Gated `amber-sap-seep` and `verdigris-crust` resource prototypes behind `feature_flags.space_age_enabled()`.
- Gated the shared admin-building `capture-bureau` entity and admin-station paste target reference so base-only loading does not reference missing Space Age items or entities.
- Locked the workforce surface rule in tests and documentation: recruitment/selected seed roles are Nauvis-bound, later specialist routing is portable.
- Made `notary-office` crafting Vulcanus-bound to match its planet-specific building role.

## Remaining Completion Blockers

These should still be resolved before calling Space Age compatibility complete.

1. Space Age route analyzer passes structurally but still needs design review.
   - Current run reports aggregate imports: `(none)`.
   - Current run reports aggregate deadlocks: `(none)`.
   - The detailed routes still include many bootstrap cycles and many required building categories; this proves graph reachability, not a polished gameplay curve.
   - Needed review: inspect the generated report for planet-by-planet weirdness, especially Aquilo bootstrapping, exported paperwork pressure, and whether the broad machine category requirements are intended.

2. A few planet-identity surface rules remain unresolved.
   - `admin-station-gleba` crafts an `admin-station` item even though Space Age restricts `admin-station` placement to Nauvis.
   - `public-transportation-contract-production` is wrapped in `surface_limited(...)` without a planet argument, which is effectively a no-op.

3. Fax reconstruction economy and faxability policy remain unresolved.
   - Runtime currently reconstructs directly from `paper` plus required liquid inks.
   - Older plan text points toward Aquilo transfer media / Laser Printer reconstruction.
   - The intended faxable and intentionally non-faxable Space Age paperwork list needs to be explicit.

## Current Implemented Work

The following pieces appear implemented in code and are covered at least partially by Lua tests.

Cross-planet foundation:

- Space Age is still optional in `info.json`.
- `feature_flags.space_age_enabled()` gates Space Age item, recipe, entity, technology, category, and shared-rule loading.
- Space Age-specific categories exist:
  - `printing-chromatic`
  - `printing-multicolor`
  - `fax-reconstruction`
  - `bureaucracy-certification`
  - `bureaucracy-conciliation`
  - `hostile-acquisition`
  - `territorial-arbitration`
  - `workforce-formation`
  - `orbital-bureaucracy`
- Native Space Age machine categories are exempt from recurring operating paperwork:
  - `metallurgy`
  - `organic`
  - `electromagnetics`
  - `cryogenics`
- Mod Space Age admin categories are also exempt:
  - `bureaucracy-certification`
  - `bureaucracy-conciliation`
  - `orbital-bureaucracy`

Colored paperwork gating:

- `data-final-fixes.lua` adds generic colored form gates after normal recipe regulation.
- Current single-intermediate gates:
  - recipes consuming `tungsten-plate` or `tungsten-carbide` get `blank-cyan-form`
  - recipes consuming `carbon-fiber` get `blank-yellow-form`
  - recipes consuming `holmium-plate` get `blank-magenta-form`
- Current two-color gates:
  - cyan + yellow requirements collapse to `cyan-yellow-form`
  - cyan + magenta requirements collapse to `cyan-magenta-form`
  - yellow + magenta requirements collapse to `yellow-magenta-form`
- Current three-color gate:
  - three CMY requirements collapse to `trichromatic-permit`
- Current explicit top-tier override:
  - `quantum-processor` consumes `unified-operations-charter`
- Current Aquilo native gates:
  - `lithium` and `lithium-plate` consume `cyan-yellow-form`
  - `fluoroketone`, `fluoroketone-cooling`, and `cryogenic-plant` consume `cryogenic-operations-license`

Important correction to older notes:

- `composite-form` is not currently implemented.
- The live code uses the explicit bicolor forms `cyan-yellow-form`, `cyan-magenta-form`, and `yellow-magenta-form`.
- Any plan text that still says dual-planet convergence uses `composite-form` is stale.

Vulcanus:

- Local resources and registration:
  - `verdigris-crust`
  - `vulcanus_verdigris_crust` autoplace control
  - direct planet map generation injection in `data-updates.lua`
- Bootstrap and local admin:
  - `paper-production-vulcanus`
  - `heatproof-paper-production`
  - `carbon-offset-certificate-basic-vulcanus`
  - `printer-t1-vulcanus`
  - `propaganda-distillery-vulcanus`
  - `dubious-data-analysis-vulcanus`
  - `research-grant-approval-vulcanus`
  - `administrative-science-pack-production-vulcanus`
  - `plastic-bar-vulcanus`
  - `liquid-stimulant-production`
  - `liquid-coffee-vulcanus`
  - `molten-promises-production`
  - `vulcanus-lie-distillation`
  - `refined-nonsense-production-vulcanus`
- Cyan paperwork:
  - `cyan-slurry`
  - `cyan-ink`
  - `heatproof-form-stock`
  - `blank-cyan-form`
  - `permit-draft`
  - `inspection-docket`
- Certification and export paperwork:
  - `notary-office`
  - `territorial-arbitration-post`
  - `territorial-arbitration-processing`
  - `embossed-seal`
  - `industrial-charter`
  - `territorial-resettlement-order`
  - `territorial-deed`
  - `thermal-process-license`
  - `calcite-reagent-waiver`
  - `offworld-metallurgy-charter`
  - `good-excuse-vulcanus`
  - `safety-waiver-vulcanus`
  - `construction-permit-vulcanus`
  - `management-approval-verbal-vulcanus`
  - `management-approval-written-vulcanus`
  - `heatproof-filler-documentation`
  - `form-27b-6-vulcanus`
- Off-world clones exist for selected Vulcanus recipes:
  - `foundry-offworld`
  - `tungsten-plate-offworld`
  - `tungsten-carbide-offworld`
  - `molten-iron-offworld`
  - `molten-iron-from-lava-offworld`
  - `molten-copper-offworld`
  - `molten-copper-from-lava-offworld`
  - `simple-coal-liquefaction-offworld`
  - `acid-neutralisation-offworld`
  - `casting-low-density-structure-offworld`

Gleba:

- Local resource and registration:
  - `amber-sap`
  - `amber-sap-seep`
  - `gleba_amber_sap_seep` autoplace control
  - direct planet map generation injection in `data-updates.lua`
- Bootstrap and local admin:
  - `amber-sap-nonsense-seeding`
  - `ink-production-gleba`
  - `carbon-offset-certificate-basic-gleba`
  - `admin-station-gleba`
  - `printer-t1-gleba`
  - `corporate-breakroom-gleba`
  - `administrative-science-pack-production-gleba`
- Yellow paperwork:
  - `yellow-ink`
  - `mycelial-form-stock`
  - `blank-yellow-form`
  - `symbiosis-record`
  - `conciliation-order`
  - `biochamber-operating-waiver`
- Spoilage is implemented for:
  - `mycelial-form-stock`
  - `blank-yellow-form`
  - `symbiosis-record`
  - `conciliation-order`
  - `biochamber-operating-waiver`
- Hostile-acquisition and tourism:
  - `capture-bureau`
  - `conciliation-desk`
  - `capture-bureau-workforce`
  - `capture-bureau-pentapod-eggs`
  - `capture-bureau-tourism`
  - spitter tourism package items
  - space tourist items
  - orbital tourism payout recipes
  - jettison recipes
- Off-world bio variants exist for:
  - `rocket-fuel-from-jelly-offworld`
  - `bioplastic-offworld`
  - `biosulfur-offworld`
  - `biolubricant-offworld`

Fulgora:

- Magenta and salvage first pass:
  - `charged-toner`
  - `archive-rubble-recovery`
  - `archive-documentation-recovery`
  - `magenta-ink`
  - `signal-form-stock`
  - `blank-magenta-form`
  - `archive-recovery-permit`
  - `digital-processing-certificate`
  - `electromagnetic-operating-license`
  - `data-recovery-order`
- `digital-services-bureau` exists.
- `digital-services-bureau` currently crafts:
  - `bureaucracy-registration`
  - `bureaucratic-bootstrap`
- Current Digital Services Bureau stats:
  - crafting speed `3`
  - energy `1MW`
  - module slots `6`
  - no working-hours shutdown integration

Aquilo and orbital:

- Frozen-ink restriction first pass:
  - `chromatic-printer` recipe and entity are blocked on Aquilo by pressure condition
  - `liquid-black-ink` recipe is blocked on Aquilo
  - cyan, yellow, and magenta liquid ink production remains planet-limited away from Aquilo
- Aquilo buildings and media:
  - `laser-printer`
  - `fax-emitter`
  - `interplanetary-fax-exchange`
  - `transfer-emulsion`
  - `thermal-transfer-sheet`
  - `composite-chroma-ribbon`
  - `trichromatic-permit`
  - `unified-operations-charter`
  - `cryogenic-operations-license`
- `laser-printer` currently has:
  - categories `printing`, `printing-advanced`, `printing-workorder`, `printing-multicolor`, `fax-reconstruction`
  - speed `5`
  - no fluid boxes
- `interplanetary-fax-exchange` currently has:
  - category `fax-reconstruction`
  - four input fluid boxes
  - queue/circuit runtime
  - one receiver per planet enforced by runtime
- Orbital bureaucracy:
  - `administrative-space-station`
  - `thermal-process-license-orbital`
  - `calcite-reagent-waiver-orbital`
  - `offworld-metallurgy-charter-orbital`
  - `orbital-deviation-order`
  - `asteroid-processing-docket`
  - `trajectory-compliance-array`

Professions:

- Implemented workforce items:
  - `job-offer`
  - `enrolled-biter`
  - `worker-biter`
  - `clerical-trainee`
  - `management-trainee`
  - `astronaut`
  - `night-shift-supervisor`
  - `licensed-notary`
  - `conciliation-officer`
  - `relay-clerk`
  - `cryoprint-technician`
  - `field-negotiator`
  - `middle-management-managing-manager`
- Implemented profession recipes include:
  - `worker-biter-formation`
  - `clerical-trainee-formation`
  - `management-trainee-formation`
  - `astronaut-formation`
  - `night-shift-supervisor-formation`
  - `licensed-notary-formation`
  - `conciliation-officer-formation`
  - `relay-clerk-formation`
  - `cryoprint-technician-formation`
  - `field-negotiator-formation`
  - `middle-management-managing-manager-formation`
- Implemented profession hooks:
  - `foundry` and `foundry-offworld` require `licensed-notary`
  - `notary-office` requires `licensed-notary`
  - `territorial-arbitration-post` requires `licensed-notary`
  - `biochamber` requires `conciliation-officer`
  - `capture-bureau` requires `conciliation-officer` and `worker-biter`
  - `conciliation-desk` requires `conciliation-officer`
  - `electromagnetic-plant` requires `relay-clerk`
  - `digital-services-bureau` requires `relay-clerk`
  - `cryogenic-plant` requires `cryoprint-technician`
  - `laser-printer`, `fax-emitter`, and `interplanetary-fax-exchange` require `cryoprint-technician`
  - `overtime-exemption-staffed` uses `night-shift-supervisor`
  - `trajectory-compliance-array` consumes `middle-management-managing-manager` / `orbital-deviation-order` as ammo

Fax runtime:

- Implemented:
  - sender-side destination selection GUI
  - receiver custom screen GUI
  - one receiver per planet
  - queue reservations and backpressure
  - circuit status signals for queued/free/reserved slots
  - receiver request mirroring to emitters
  - source quality preservation
  - direct destination-side reconstruction from paper and required inks
  - black-only faxing before `color-faxing`
  - color faxing after `color-faxing`
- Current faxable colored documents:
  - `blank-cyan-form`
  - `blank-yellow-form`
  - `blank-magenta-form`
  - `cyan-yellow-form`
  - `cyan-magenta-form`
  - `yellow-magenta-form`
  - `cryogenic-operations-license`
  - `trichromatic-permit`
  - `unified-operations-charter`
- Important correction to older notes:
  - colored paperwork is not excluded from transmission anymore; it is gated by `color-faxing`.

## Missing, Incomplete, Unsure, Weird, Or Unbalanced

### Release and Validation

- The current automated validation set passes:
  - all Lua tests
  - base-only `test_progression_report.py --strict`
  - Space Age `test_planet_escape.py --show-steps --import-depth 2`
- Keep the base-only optional dependency boundary covered:
  - `amber-sap-seep` and `verdigris-crust` are now Space Age-gated resources
  - `capture-bureau` is now excluded from base-only entity extension and from base-only admin-station paste targets
  - future Space Age-only prototypes must not leak into base-only `data.raw` unless their items, recipes, categories, feature flags, and surface constraints are also valid without Space Age
- Keep rerunning Space Age dump-data planner validation after any recipe, technology, resource, surface-condition, fax, or paperwork-gating changes.
  - latest checked command passed on Factorio 2.0.76 with Space Age enabled
  - latest result: no aggregate imports and no aggregate deadlocks for selected escape targets
  - latest result does not guarantee fun, balance, or sensible first-planet pacing
- Add the Factorio binary path to local test instructions or an environment variable convention so these validation runs are repeatable.
- Add CI or a documented local script that runs:
  - all Lua tests
  - base-only `test_progression_report.py --strict`
  - Space Age `test_planet_escape.py`
- Decide whether the Python analyzers should fail on import-heavy planets or only report them. They currently do not prove good playability; they mainly prove no hard structural deadlock.
- Preserve and compare analyzer reports between compatibility passes. The current route report is too large to inspect manually from terminal output alone, so the workflow should save it into `Internal/` or a git-ignored diagnostics folder when doing release validation.

### Documentation Drift

- Keep `composite-form` out of implementation-facing docs unless that item is intentionally reintroduced.
- Align the Aquilo plan with the live bicolor form system:
  - current code uses direct bicolor forms from liquid inks
  - current code uses `trichromatic-permit` and `unified-operations-charter` as Aquilo-capstone paperwork
  - no `composite-form` prototype exists
- Align fax documentation:
  - current runtime allows colored faxing after `color-faxing`
  - current runtime does not use transfer media for fax reconstruction
  - current runtime reconstructs directly inside the receiver script
- Worker documentation now matches the portable specialist surface rule:
  - Nauvis-bound seed: `job-offer-production`, `worker-biter-formation`, `management-trainee-formation`, `licensed-notary-formation`
  - portable specialist routing: clerical, astronaut, supervisor, conciliation, relay, cryoprint, field-negotiator, and MMMM formation recipes
- Decide whether `admin-station-gleba` is still a true bootstrap item. It crafts an `admin-station` item on Gleba, but `admin-station` placement is restricted to Nauvis when Space Age is enabled.

### Surface Conditions And Planet Identity

- Worker surface policy is now explicit and covered by `tests/test_space_age_content.lua`:
  - Nauvis-bound recruitment and seed recipes: `job-offer-production`, `worker-biter-formation`, `management-trainee-formation`, `licensed-notary-formation`
  - portable post-seed specialist recipes: `clerical-trainee-formation`, `astronaut-formation`, `night-shift-supervisor-formation`, `conciliation-officer-formation`, `relay-clerk-formation`, `cryoprint-technician-formation`, `field-negotiator-formation`, `middle-management-managing-manager-formation`
- Remaining likely mismatches:
  - `admin-station-gleba` crafts an `admin-station` item that cannot be placed on Gleba under Space Age placement rules.
  - `public-transportation-contract-production` is wrapped in `surface_limited(...)` without a planet argument, which is effectively a no-op.

### Base-Only Compatibility

- Base-only loading now passes strict progression validation.
- Fixed leak points from the 2026-04-18 make-it-work pass:
  - `prototypes/resources.lua` now only defines `amber-sap-seep` and `verdigris-crust` when `feature_flags.space_age_enabled()` is true
  - `prototypes/entity/admin-buildings.lua` no longer extends the `capture-bureau` entity in base-only mode
  - `admin-station.additional_pastable_entities` no longer references `capture-bureau` in base-only mode
- Keep confirming base-only mode does not receive:
  - `amber-sap-seep`
  - `verdigris-crust`
  - `capture-bureau`
  - pressure/gravity surface conditions that only make sense with Space Age planets
  - references to Space Age resource autoplace controls that are only registered under `feature_flags.space_age_enabled()`
- Add a small Lua or Python check that proves Space Age resource prototypes are absent from a base-only dump.
- After future optional-dependency boundary changes, rerun:
  - `python3 tests/test_progression_report.py --factorio-bin "~/Library/Application Support/Steam/steamapps/common/Factorio/factorio.app/Contents/MacOS/factorio" --strict`
  - expected state: dump succeeds and the progression report passes or exposes actual recipe/technology issues.

### Space Age Route Analyzer Follow-Up

- Current Space Age analyzer run passed structurally.
- Current selected-target summary:
  - aggregate imports: `(none)`
  - aggregate deadlocks: `(none)`
  - buildings needed include many categories across administration, printing, metallurgy, chemistry, cryogenics, organic processing, electromagnetics, and rocket building
- Important limitation: the analyzer's successful route for a target can still include bootstrap cycles that need gameplay judgement.
- Manual report review still needed for:
  - Aquilo first-start experience, because the route output shows many paper, ink, coffee, and office-drama bootstrap cycles even though the final selected target is graph-valid
  - whether every required building category is actually placeable and unlockable on the planet where the route says it is needed
  - whether off-world recipe variants are doing too much hidden work for first-planet escape
  - whether imports shown inside non-selected intermediate explanations are expected diagnostics or signal a real rough edge
  - whether the analyzer should treat building availability as a stricter requirement instead of reporting categories separately
  - whether the route should validate one complete planet escape path per planet with local buildings, not only item reachability and selected escape targets

### Fax System Completion

- Decide the final reconstruction economy:
  - current implementation: receiver consumes `paper` plus only the required liquid inks
  - older plan direction: Aquilo-style transfer media / Laser Printer reconstruction
  - hybrid option: black paperwork uses paper + black ink; colored paperwork uses paper + matching inks; premium or late faxing uses transfer media
- Decide whether `fax-reconstruction` hidden recipes are for UI/Factoriopedia scaffolding only or should become the real production path.
- Audit all Space Age paperwork for faxability.
  - Current faxable list excludes many new Space Age forms:
    - `permit-draft`
    - `inspection-docket`
    - `embossed-seal`
    - `industrial-charter`
    - `territorial-resettlement-order`
    - `thermal-process-license`
    - `calcite-reagent-waiver`
    - `offworld-metallurgy-charter`
    - `symbiosis-record`
    - `conciliation-order`
    - `biochamber-operating-waiver`
    - `archive-recovery-permit`
    - `digital-processing-certificate`
    - `electromagnetic-operating-license`
    - `data-recovery-order`
    - `public-transportation-contract`
    - `asteroid-processing-docket`
    - `orbital-deviation-order`
  - This may be intentional, but it must be explicit because faxing is supposed to move administrative value between planets.
- Add tests for:
  - color faxing blocked before `color-faxing`
  - color faxing allowed after `color-faxing`
  - every intended faxable Space Age document
  - every intentionally non-faxable Space Age document
  - receiver GUI wording after the current failing test is resolved
- Balance fax throughput:
  - `TRANSMIT_TICKS = 60`
  - `PRINT_TICKS = 120`
  - base queue capacity `5`
  - queue tech bonuses `+5`, `+5`, `+5`
  - ink cost `5` per required ink
  - paper cost `1`
- Decide whether source-side ejection of the original document after delivery is the intended UX. Current tests expect successful faxing to spill the original document back at the emitter surface rather than consuming it.

### Planet Escape And Bootstrap

- Vulcanus:
  - latest Space Age route analyzer run completed successfully after recent fax/UI/public transportation work
  - current selected-target aggregate reports no imports and no deadlocks
  - `notary-office` crafting is now Vulcanus-bound and covered by Space Age content tests
  - verify `thermal-process-license` / `calcite-reagent-waiver` / `offworld-metallurgy-charter` are valuable off-world without polluting home-planet recipes
- Gleba:
  - latest Space Age route analyzer run completed successfully, but still needs manual report review for import-like diagnostics and bootstrap roughness
  - verify whether `admin-station-gleba` is useful if `admin-station` can only be placed on Nauvis
  - verify the player can practically reach the intended escape milestone without over-importing `lie`, `redundant-rubble`, advanced paperwork, or nonlocal buildings
  - decide whether more narrow Gleba shortcuts are needed or whether import-heavy is intended
  - validate yellow paperwork spoil times in real play
- Fulgora:
  - latest Space Age route analyzer run completed successfully, but still needs manual report review for import-like diagnostics and bootstrap roughness
  - still lacks explicit bootstrap variants comparable to Vulcanus and Gleba for:
    - local admin station equivalent
    - local printer bootstrap
    - local administrative science pack route
    - local breakroom / gossip bridge if needed
  - decide whether the `Digital Services Bureau` is enough as the local admin upgrade or whether Fulgora needs a cheaper first-planet bootstrap layer
  - balance `scrap -> charged-toner`, `scrap -> redundant-rubble`, and `scrap + charged-toner -> useless-documentation + paper`
- Aquilo:
  - not intended as a first planet
  - verify that the Aquilo tech and recipe model assumes prior planets cleanly without making the fax network awkward to bootstrap
  - decide whether bicolor paperwork should remain liquid-ink printing outside Aquilo or move toward Aquilo transfer media
  - bicolor form recipes currently have no surface conditions and consume liquid inks; document that as the intended pre-Aquilo convergence layer or move them into the Aquilo transfer-media lane
  - expand late-game `unified-operations-charter` usage beyond `quantum-processor` if the capstone form currently feels too narrow

### Public Transportation / Bureaucratic Transcendence

- `public-transportation-contract-production` exists and consumes `cyan-yellow-form` plus `transit-authorization`.
- `public-train-stop-production` exists and produces `public-train-stop`.
- `scripts/trains.lua` skips transit permit chest setup for `public-train-stop`.
- Missing coverage:
  - add tests that building `public-train-stop` does not create a transit permit chest
  - add tests that `public-train-stop` remains operational without transit forms
  - add tests that ordinary `train-stop` behavior is unchanged
- Check tech/theme consistency:
  - contract is unlocked by `cyan-yellow-bureaucracy`
  - public train stop is unlocked by `bureaucratic-transcendence`
  - locale currently describes transcendence in a way that may not match the actual cyan-yellow contract dependency
- Code cleanup question:
  - `public-transportation-contract-production` is wrapped in `surface_limited(...)` without a planet argument, which is currently a no-op. Remove the wrapper if global crafting is intended, or add a real surface rule if it is not.

### Professions Completion

- Profession surface rule is decided and tested:
  - taxpayer-funded recruitment and selected seed roles stay Nauvis-bound
  - later specialist routing is portable once the player has a Formation Center and prerequisite science
- Implement or explicitly drop the planned tier-3 module workforce sink.
  - Planned but not implemented:
    - `speed-module-3` consumes `management-trainee`
    - `productivity-module-3` consumes `management-trainee`
    - `efficiency-module-3` consumes `management-trainee`
- Add tests if tier-3 modules get the workforce sink.
- Validate `overtime-exemption-staffed` balance:
  - it currently produces the same `overtime-exemption` item
  - it is unlocked by `after-hours-operations`
  - it consumes `night-shift-supervisor`, `productivity-module`, `processing-unit`, `government-grant`, `regulation`, `management-approval-written`, and `liquid-coffee`
  - decide whether this is too expensive for a same-item alternate recipe
- Decide whether `field-negotiator` and `middle-management-managing-manager` are sufficiently useful after their first hooks.

### Public Finance Completion

- The finance plan remains mostly design-stage.
- Not implemented:
  - `money-case`
  - `offworld-allocation`
  - `cargo-manifest`
  - `customs-appraisal`
  - Nauvis-side redemption recipes
  - offworld travel/infrastructure capital budgeting
  - platform power budget hook
- Current local planet recipes mostly follow the no-raw-`taxpayer-money` rule, but this should be verified with dump data.
- Decide whether finance instruments are part of Space Age compatibility completion or a later feature slice.

### Art, Icons, Locale, And Factoriopedia Polish

- Many Space Age entities and items still use existing or tinted placeholder art:
  - `chromatic-printer` uses existing forge/printer-style art
  - `laser-printer` uses the same general visual family
  - `interplanetary-fax-exchange` uses printer/office placeholder visuals
  - `digital-services-bureau` uses office-building icon layers
  - `amber-sap` uses coffee-like visuals
  - `verdigris-crust` uses tinted `bullshit-ore`
  - professions use biter icons with paperwork overlays
- Decide which of these need final assets before release and which are acceptable for first compatibility completion.
- Recheck locale after the code/design decisions above:
  - keep bicolor-form wording clear now that `composite-form` is absent
  - update fax descriptions for color faxing and reconstruction costs
  - update public transportation/transcendence descriptions
  - update profession training descriptions once surface rules are decided

### Balance Passes Still Needed

- Colored form costs:
  - bicolor forms currently produce `2` from `2 paper + 10 + 10 liquid inks`
  - blank colored forms produce `2` through stock plus `5` ink
  - validate whether bicolor forms are too cheap relative to exporting two separate blanks
- Vulcanus:
  - validate `vulcanus-lie-distillation` output of `180 lie + 1 dubious-data`
  - validate whether `thermal-process-license` and `calcite-reagent-waiver` are the right cost for repeated offworld metallurgy
  - validate `territorial-arbitration-post` footprint and upkeep in real maps
- Gleba:
  - validate yellow paperwork spoil times (`18000` and `36000` ticks)
  - validate tourism payouts:
    - small `75`
    - medium `175`
    - big `450`
    - behemoth `1200`
  - validate whether space tourist spoil/hatch behavior is fair
- Fulgora:
  - validate scrap-to-admin-material yields
  - validate Digital Services Bureau speed `3`, energy `1MW`, and module slots `6`
  - decide whether the bureau should be a general admin-station replacement, a registration/bootstrap machine only, or a broader office superset
- Aquilo:
  - validate Laser Printer speed `5`
  - validate whether the Fax Exchange should craft, script-reconstruct, or both
  - validate queue capacity tech values
  - validate whether `unified-operations-charter` has enough recipe demand

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
  - `archive-rubble-recovery`
  - `archive-documentation-recovery`
  - `magenta-ink`
  - `signal-form-stock`
  - `blank-magenta-form`
  - `archive-recovery-permit`
  - `digital-processing-certificate`
  - `electromagnetic-operating-license`
  - `data-recovery-order`
- Aquilo first pass now exists:
  - `laser-printer`
  - `interplanetary-fax-exchange`
  - `transfer-emulsion`
  - `thermal-transfer-sheet`
  - `composite-chroma-ribbon`
  - `cyan-yellow-form`
  - `cyan-magenta-form`
  - `yellow-magenta-form`
  - `trichromatic-permit`
  - `unified-operations-charter`
  - `cryogenic-operations-license`
  - first-pass Aquilo frozen-ink restrictions for `chromatic-printer` and `liquid-black-ink`
  - first-pass multicolor replacement in `data-final-fixes.lua`:
    - dual-planet CMY convergence -> matching bicolor forms (`cyan-yellow-form`, `cyan-magenta-form`, `yellow-magenta-form`)
    - three-planet convergence -> `trichromatic-permit`
    - top-tier `quantum-processor` convergence -> `unified-operations-charter`
    - Aquilo cryogenic natives -> `cyan-yellow-form` / `cryogenic-operations-license`
- Targeted Lua coverage exists for the current Vulcanus, Gleba, Fulgora, and final-fixes passes

Still missing:

- The two currently failing Lua tests listed in the 2026-04-18 assessment
- Planner-mod / gameplay follow-up beyond the current dump-based escape verification
- Any extra Fulgora bootstrap recipes that broader verification proves necessary
- Cross-cutting audits
- Base-only optional dependency dump validation
- Documentation cleanup for the bicolor-form versus `composite-form` design decision

---

## Phase 1: Colored Ink Gating (Cross-Planet, High Priority)

Status: first pass implemented. Remaining work is verification plus later refinement of which higher-tier recipes should use specialized forms instead of the base blanks.

### Step 1.1: Identify all vanilla recipes consuming planet intermediates

Status: effectively superseded by the generic ingredient scan in `data-final-fixes.lua`.

### Step 1.2: Define the gating forms

Status: first-pass choice made.

- Current rule: all current planet-intermediate gates use the basic blank CMY forms
- Later refinement: selected high-tier recipes may be upgraded to consume specialized forms instead
- Aquilo multicolor forms now own the first-pass multi-planet convergence case

### Step 1.3: Implement gating as recipe modifications in data-final-fixes

Status: done.

### Step 1.4: Verify solver still reaches targets

Status: dump-based first pass run with `tests/test_planet_escape.py`.

Current findings:

- Vulcanus escape looks locally clear for the tested rocket targets
- Gleba, Fulgora, and Aquilo did not show hard deadlocks for the tested targets, but they remain import-heavy in the current local-only analyzer
- Aquilo's new fax-network layer shows up as imports under that analyzer because the tech and resource model is intentionally stricter than real interplanetary progression

Remaining follow-up:

- run a planner-mod or gameplay validation pass instead of treating the dump-based analyzer as the final word
- only add more bootstrap shortcuts if that broader verification proves they are necessary

---

## Phase 2: Vulcanus Worker Requirement for Notary Office

### Step 2.1: Add `licensed-notary` to Notary Office crafting recipe

Status: done.

### Step 2.2: Verify solver still works

Status: first-pass checked through Phase 1.4's dump-based verification. No hard Vulcanus deadlock was found for the tested rocket targets.

Remaining follow-up:

- confirm in planner-mod / gameplay validation, not just the dump-based analyzer

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

Status: first-pass checked with the dump-based analyzer. Gleba's tested rocket targets still lean on imports, but no hard deadlock was found.

Remaining follow-up:

- run a broader planner-mod / gameplay pass
- only add more Gleba-local shortcuts if that broader pass proves they are necessary

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
- `archive-rubble-recovery`
- `archive-documentation-recovery`
- `magenta-ink-production`
- `signal-form-stock`
- `blank-magenta-form-production`

Note:

- the source side is currently simplified to one salvage intermediate, `charged-toner`
- the base Fulgora salvage and magenta stock chain now sits with `chromatic-printing`, not the later bureau tech
- split toner intermediates can be revisited later if the planet needs more texture

### Step 4.3: Define Fulgora paperwork family

Status: mostly done, bootstrap now has an initial recovery pass.

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

Status: first pass done.

Implemented:

- `archive-rubble-recovery`
- `archive-documentation-recovery`
- `charged-toner` now bootstraps directly from scrap

Current shape:

- scrap is the root salvage input
- salvage recovery produces easy `redundant-rubble`
- salvage recovery also produces easy `useless-documentation` plus some recovered `paper`
- the loop feeds both the base paperwork economy and the magenta chain without adding a direct rubble ore clone on Fulgora

Constraint:

- do this through salvage recovery, not by adding a trivial direct paper-ore substitute

Follow-up:

- rebalance yields if solver or actual play shows Fulgora is still too starved or too generous
- decide whether an additional higher-tier archive-recovery recipe should sit on top of the first-pass salvage loop

### Step 4.6: Verify solver for Fulgora escape path

Status: first-pass checked with the dump-based analyzer. Fulgora's tested targets remain import-heavy, but no hard deadlock was found against the salvage-plus-magenta pass.

Remaining follow-up:

- confirm with planner-mod / gameplay validation
- only add more Fulgora bootstrap shortcuts if that broader pass proves they are necessary

---

## Phase 5: Aquilo — Fax Exchange and Multicolor Forms

Status: first pass implemented. The remaining work is solver verification, gameplay validation, and balance cleanup after the new multicolor gates and fax runtime landed.

### Step 5.1: Move Interplanetary Fax Exchange to Aquilo

Status: first pass done.

- `interplanetary-fax-exchange` now exists
- crafting is surface-limited to Aquilo
- recipe requires 1x `cryoprint-technician`
- unlock lives on Aquilo progression via `aquilo-fax-network`

### Step 5.2: Define Laser Printer entity

Status: first pass done.

- `laser-printer` now exists
- current categories:
  - `printing`
  - `printing-advanced`
  - `printing-workorder`
  - `printing-multicolor`
  - `fax-reconstruction`
- currently the fastest printer in the mod
- uses solid inputs only; no fluid ports
- recipe requires 1x `cryoprint-technician`
- crafting is surface-limited to Aquilo

### Step 5.3: Implement frozen ink constraint

Status: first pass done.

- `chromatic-printer` recipe and placement are blocked on Aquilo
- `liquid-black-ink` is blocked on Aquilo
- the existing cyan / yellow / magenta liquid-ink chains remain planet-limited off Aquilo

Remaining follow-up:

- verify in actual play that no unexpected path still allows liquid-ink bureaucracy on Aquilo

### Step 5.4: Define transfer media items

Status: first pass done.

Implemented:

- `transfer-emulsion`
- `thermal-transfer-sheet`
- `composite-chroma-ribbon`

### Step 5.5: Define multicolor form family

Status: first pass done.

Implemented:

- `cyan-yellow-form`
- `cyan-magenta-form`
- `yellow-magenta-form`
- `trichromatic-permit`
- `unified-operations-charter`
- `cryogenic-operations-license`

Note: earlier notes referred to `composite-form`, but that prototype is not present in the current codebase.

### Step 5.6: Implement multicolor gating for multi-planet recipes

Status: first pass done in `data-final-fixes.lua`.

Current rule:

- recipes that would have required 2 distinct CMY blank forms now consume the matching bicolor form:
  - cyan + yellow -> `cyan-yellow-form`
  - cyan + magenta -> `cyan-magenta-form`
  - yellow + magenta -> `yellow-magenta-form`
- recipes that would have required 3 distinct CMY blank forms now consume `trichromatic-permit`
- `quantum-processor` is the current top-tier override and consumes `unified-operations-charter`
- first Aquilo-native cryogenic gates are in place:
  - `lithium` / `lithium-plate` -> `cyan-yellow-form`
  - `fluoroketone` / `fluoroketone-cooling` / `cryogenic-plant` -> `cryogenic-operations-license`

Remaining follow-up:

- expand the explicit top-tier override list if more late recipes should use `unified-operations-charter`
- solver-check whether any Aquilo-native recipes need lighter or heavier paperwork than the first pass

### Step 5.7: Define fax network mechanics

Status: current runtime first pass done.

Implemented:

- sender-side `fax-emitter` destination selection
- one `interplanetary-fax-exchange` receiver per planet with queueing and reservation backpressure
- routing state plus circuit visibility for queue size, free slots, reserved slots, and receiver requests
- faxable-paperwork filtering with colored paperwork gated behind `color-faxing`
- destination-side reconstruction in the receiver runtime, preserving item quality
- queue-safe stalling when output space or reconstruction supplies are missing
- queue-capacity follow-up techs and dedicated runtime coverage in `tests/test_fax_runtime.lua`

Current first-pass behavior:

- the active fax runtime reconstructs documents directly inside the exchange logic rather than through recipe-driven `laser-printer` jobs
- the current reconstruction cost is generic `paper` plus `ink`
- Aquilo transfer media and `fax-reconstruction` category scaffolding exist alongside that runtime, but they are not the active gate for fax completion

Remaining follow-up:

- verify in real gameplay / planner usage that the current fax runtime feels correct before changing the model again
- if the design changes later, revisit whether fax reconstruction should move onto Aquilo transfer media instead of the current generic supplies

### Step 5.8: Verify all planet escape paths still work

Status: first-pass checked with the dump-based analyzer after the Aquilo multicolor replacement landed.

Current findings:

- Vulcanus was locally clear for the tested rocket targets
- Gleba, Fulgora, and Aquilo remained import-heavy in the current analyzer, but none of the tested targets produced a hard deadlock
- Aquilo's new multicolor paperwork, printer, and fax exchange layer currently reads as imported in the strict local-only model, which is acceptable for this first pass

Remaining follow-up:

- run planner-mod / gameplay verification before treating the new multicolor paperwork balance as settled

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
