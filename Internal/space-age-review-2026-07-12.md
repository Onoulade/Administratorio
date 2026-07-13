# Administratorio Space Age Review

Date: 2026-07-12  
Branch: `space-age` at `fedd837`  
Factorio used for prototype validation: 2.0.77, macOS arm64, Space Age enabled where applicable

## Executive verdict

Administratorio already has a strong identity, several genuinely original systems, and a much better engineering foundation than the average overhaul mod. The core fantasy is clear: industrial growth is converted from a military problem into a logistics, labor, public-finance, and paperwork problem. The mod is funniest when the joke is also a machine the player can optimize. Complaint queues, pneumatic paperwork, staffed machines, protests, territorial arbitration, and fax reconstruction all satisfy that principle.

The Space Age branch is not release-ready yet. It is a broad and technically functional first pass whose quality varies sharply by planet. Vulcanus is the most complete local progression. Gleba is the most inventive but also the most mechanically overloaded. Fulgora has a good theme but the thinnest actual gameplay and currently fails the ordinary-local-production standard. Aquilo has the strongest capstone concept, but its ink-freezing fiction conflicts with its implemented fax inputs.

The most important issue is not balance: every routine Space Age cargo rocket currently triggers Administratorio's old base-game victory handler and marks the game finished. This must be fixed before meaningful campaign playtesting.

### Scorecard

| Area | Assessment | Confidence |
| --- | --- | --- |
| Core theme | Excellent and unusually coherent | High |
| Core mechanics | Deep, useful, and mostly complementary | High |
| Space Age planet identity | Strong concepts, uneven execution | High |
| Progression correctness | Prototype-valid, not yet campaign-valid | Medium |
| Balance | Plausible first pass, insufficiently playtested | Low-medium |
| Code quality | Defensive and well-tested, but increasingly monolithic | High |
| Onboarding and readability | Insufficient for the number of interacting systems | High |
| Localization and presentation | Base content substantial; Space Age incomplete | High |

This review distinguishes between acceptable imports and bad imports:

- Acceptable: specialist staff, conflict-resolution outputs, intentionally unique planetary exports, optional systems, and Aquilo's deliberate dependence on earlier planets.
- Not acceptable: imports required for ordinary machines, normal paperwork inputs, or basic launch production on Vulcanus, Gleba, or Fulgora, unless the import is an explicitly designed conflict or staffing milestone.

## Scope and evidence

The branch adds roughly 19,895 lines across 72 changed files and is 51 commits ahead of `main` in the inspected history. The current Lua/prototype/test footprint is about 52,519 lines.

Validation performed:

- All Lua files parse with `luac -p`.
- All standalone Lua tests in `tests/run-tests.sh --repo-root .` pass.
- Base-only prototypes load successfully in Factorio 2.0.77.
- Space Age, Quality, and Administratorio prototypes load successfully together in Factorio 2.0.77.
- The strict base progression report completes.
- The Space Age planet escape analyzer finds no graph deadlocks.
- Additional targeted route analysis was run for assemblers, chemical plants, planet machines, rocket silos, and rocket parts on Vulcanus, Gleba, and Fulgora.

Not performed:

- A full human campaign playthrough.
- Multiplayer validation.
- Long-duration UPS profiling on a large factory.
- Real-map abundance validation for the custom planetary resources.
- Timed logistics validation for Gleba spoilage, interplanetary shipping, and fax throughput.

Accordingly, statements about fun and balance below are design assessments backed by code and route graphs, not a substitute for playtest telemetry.

## Release blockers

### P0. Routine cargo rockets trigger the victory screen

[`control.lua`](../control.lua) handles every `on_rocket_launched` event by showing the Department Performance Review and calling:

```lua
game.set_game_state{game_finished = true, player_won = true, can_continue = true}
```

That is appropriate for a base-only rocket victory. In Space Age, cargo rockets are routine infrastructure and the first launch occurs before the planetary campaign. The current handler therefore declares victory at the beginning of the expansion arc.

Required change:

- Keep the existing rocket victory behavior only when Space Age is not active.
- Under Space Age, use the expansion's actual victory progression or define an Administratorio capstone tied to the late interplanetary bureaucracy arc.
- Add a runtime test proving that a Space Age cargo launch increments statistics without finishing the game.
- Add a second test for the chosen real Space Age victory condition.

### P0. Fulgora cannot support ordinary local production

The targeted analyzer reports these imports:

| Fulgora target | Reported imports |
| --- | --- |
| 1 assembling machine 2 | 4.297 bullshit ore, 1.759 coal |
| 1 oil refinery | 6.969 bullshit ore, 3.112 coal |
| 1 chemical plant | 1.922 bullshit ore, 0.992 coal, plus a chemical-operator staffing input |
| 100 rocket parts | 2,425 bullshit ore, 485.556 coal, 2,222.222 crude oil |

The fractional worker value is analyzer amortization, not an actual fractional item. A specialist worker import can be an intentional staffing milestone. Coal, crude oil, and Nauvis dubious-data inputs blocking normal machines and rocket parts are not acceptable under the stated planet rule.

The existing Fulgora loop already provides good local ingredients:

- scrap directly yields charged toner, redundant rubble, useless documentation, magenta stock, and some completed forms;
- charged toner can be made from scrap;
- archive recovery produces paper and documentation;
- the Digital Services Bureau provides fast registration work.

What is missing is a complete local bridge from those materials into the ordinary black-paperwork and machine-operation chain.

Required change:

- Add a Fulgora-local black ink or equivalent print medium based on charged toner.
- Add a local route to basic excuses/dubious data that does not require bullshit ore.
- Add a Fulgora-local carbon/smelting authorization route that does not require coal.
- Resolve the lubricant/electric-engine route without crude oil, using an electromagnetic or recycled substitute.
- Re-run targeted analysis for AM2, oil refinery, chemical plant, rocket silo, and 100 rocket parts.
- Treat a specialist worker seed as an allowed import in the analyzer; fail on coal, crude oil, bullshit ore, or other ordinary production inputs.

### P0. Gleba rocket production depends on Nauvis industrial bureaucracy

Gleba can produce an assembling machine 2 locally. A chemical plant only reports its specialist worker input, which can be accepted as staffing. The larger launch chain is not local:

| Gleba target | Reported imports |
| --- | --- |
| 1 biochamber | 1 clerical trainee, 100 politician fluid, 2 redundant rubble |
| 1 rocket silo | 620 politician fluid, 46 redundant rubble, 220 taxpayer money |
| 100 rocket parts | 12,400 politician fluid, 160 redundant rubble |

The clerical trainee can be an intentional workforce seed if the required starter manifest is explicit. The bulk politician fluid and rubble are ordinary-production blockers, not interesting specialist imports.

Required change:

- Use amber sap, spoilage, fruit products, local bullshit ore, and yellow paperwork to create Gleba-native versions of the late black-paperwork inputs currently derived from lie, narrative, refined nonsense, and useless documentation.
- Add a local recyclable or biological source of redundant rubble/document filler.
- Decide whether the biochamber's conciliation officer is a deliberate mandatory import. If yes, put the requirement in tips, technology descriptions, and the pre-launch checklist. If no, allow one local starter conversion.
- Remove taxpayer money from the ordinary off-world rocket silo path or provide a planet-local public-finance substitute.
- Re-run targeted analysis and fail on bulk politician fluid and redundant rubble imports.

### P0. The route analyzer's pass criteria do not match the design rule

The analyzer reports “Aggregate deadlocks: none,” but a route without a graph deadlock can still require thousands of imported basic resources. The implementation notes previously treated no deadlocks as broad viability; that conclusion is too weak.

Required change:

- Classify imports into `ordinary`, `staffing`, `conflict`, `planet-export`, and `capstone` groups.
- Maintain a per-planet allowlist. Aquilo can allow broad imports; the three basic planets should allow only deliberate staffing/conflict/specialist imports.
- Add named target profiles instead of only silo plus rocket parts:
  - bootstrap printer and office;
  - assembling machine 2;
  - chemical plant or native planet machine;
  - oil/planet process building;
  - rocket silo;
  - 100 rocket parts.
- Make CI fail when an ordinary target pulls an unapproved ordinary import.

## High-priority design and balance changes

### P1. Fix the Aquilo fax/ink contradiction

The stated Aquilo identity is that liquid ink freezes and only solid transfer media works. The current implementation does this correctly for the Laser Printer itself, which has no fluid boxes. However:

- fax reconstruction recipes consume one thermal-transfer sheet plus 5 units of each exact required liquid ink;
- the Interplanetary Fax Exchange has four fluid inputs;
- the exchange is an Aquilo capstone and is expected to operate on Aquilo;
- the Laser Printer advertises `fax-reconstruction` but cannot craft the fluid-based reconstruction recipes because it has no fluid boxes.

This is both thematic and mechanical incoherence. It also weakens faxing: to fax a colored form to a planet, the player must already ship that planet's colored liquid ink to the destination. In many cases the player may as well ship the form.

Recommended resolution:

- Make fax reconstruction consume solid transfer media or color cartridges derived from planetary forms, not raw liquid ink.
- Keep the cost destination-side so faxing is not free.
- Let a consolidated Aquilo ribbon/cartridge reconstruct multiple forms, providing a real logistical compression reward.
- Remove `fax-reconstruction` from the Laser Printer if reconstruction is runtime-owned by the exchange, or make the recipes genuinely craftable in the Laser Printer.
- Update the Aquilo plan to match the chosen implementation.

### P1. Fulgora scrap recycling bypasses too much of its own gameplay

The scrap recipe currently gains all of the following probabilistic outputs:

- charged toner at 18%;
- redundant rubble at 35%;
- useless documentation at 16%;
- signal form stock at 8%;
- blank magenta forms at 5%;
- four finalized Fulgora documents at 1.5-2.5% each.

The concept is excellent: ruined archives emerge from scrap. The current output set risks two problems:

1. belts and recycler outputs gain many additional item types, creating sorting clutter;
2. finished permits drop directly from scrap, bypassing the Chromatic Printer and Digital Services Bureau that are supposed to define the planet.

Recommended change:

- Let scrap yield toner, rubble, documentation, fragments, and damaged templates.
- Make the Digital Services Bureau reconstruct the finalized permits quickly and productively.
- Keep at most one rare completed-document jackpot if the loot moment is fun in testing.
- Measure recycler output saturation and item-filter burden on an actual Fulgora base.

### P1. Specialist buildings may over-compress the bureaucracy economy

The Notary Office, Territorial Arbitration Post, Conciliation Desk, Digital Services Bureau, and Laser Printer have 50% base productivity. Several also have four to six module slots. The Digital Services Bureau combines speed 3, 50% base productivity, six slots, and 24/7 operation; the Laser Printer combines speed 5, 50% base productivity, and six slots.

This mirrors Space Age's powerful native specialist-machine rewards, so the numbers are not inherently wrong. The risk is specific to Administratorio: paperwork is the mod's central constraint. A Fulgora building available after a basic planet can potentially erase much of the core economy instead of improving it.

Required playtest question:

- Does one quality Digital Services Bureau replace an entire Nauvis administrative district?

Recommended tuning order if it does:

1. preserve the building's speed and 24/7 identity;
2. reduce or remove base productivity on generic black paperwork;
3. restrict productivity to Fulgora-specific recipes;
4. reduce module slots only if the first three measures are insufficient.

The reward should feel transformative, not like an `infinite paperwork` cheat code with an office-building icon.

### P1. Gleba's five-minute yellow-form spoilage needs logistics testing

Yellow stock and forms spoil after 18,000 ticks, or five minutes. Spoilage is thematically perfect for Gleba and gives its administration a genuinely different texture. Five minutes may be too short before faxing exists, particularly when yellow paperwork must be transported off-world to create bicolor documents.

Recommended change only if timed playtests show failure:

- increase the window to 10-15 minutes; or
- spoil into an `expired-form` item that can be revalidated; or
- add a cold-storage/revalidation mechanic rather than simply making the timer generous.

Do not remove spoilage. It is one of the planet's best ideas.

### P1. Technology unlocks and actual craftability are misaligned

The strict base progression report identifies nine direct unlocks that remain blocked by runtime-acquired worker/specialist materials and ten unlocks that only become craftable after a later dependent technology.

Runtime-acquired workers are analyzer knowledge gaps, not necessarily progression bugs. The delayed ordinary unlocks are a player-facing clarity problem. Examples include:

- Printer T1 unlocked at Printing Technology but reported machine-reachable only much later.
- Printer T2 unlocked at Industrial Printing but machine-reachable after Work Order Duplication.
- fast belts unlocked at Logistics 2 but only resolved by a later dependent technology.
- tier-3 modules become craftable only around Rocket Silo.

Required change:

- Teach the analyzer about runtime-acquired materials.
- For genuine delayed unlocks, move the recipe unlock to the real enabling technology or make all ingredients available at the displayed unlock.
- Avoid technologies that advertise rewards the player cannot use. That is the Tech Tree Catfish Principle: the icon looked available; the relationship was not.

### P1. Space Age needs its own onboarding layer

The branch adds four planetary bureaucracies, workforce routing, chromatic forms, surface restrictions, territorial arbitration, capture modes, tourism, asteroid trajectory compliance, fax requests, multicolor forms, and planet-specific imports. Existing tests cover only four tips-and-tricks entries, and most documentation is internal Markdown rather than player-facing guidance.

Add unlock-triggered tips for:

- what to bring to a first basic planet;
- specialist worker portability and where each worker is formed;
- Vulcanus territorial deeds and why one may gate escape;
- Gleba yellow-form spoilage and Capture Bureau modes;
- Fulgora archive recovery and the Digital Services Bureau;
- Aquilo solid transfer media and fax reconstruction costs;
- bicolor/tricolor form rules;
- trajectory compliance on platforms.

Every planet should have a concise “minimum viable administration” checklist in Factoriopedia.

## Planet-by-planet assessment

### Vulcanus: strongest and closest to complete

What works:

- Cyan certification is an intuitive match for heat, metallurgy, calcite, and notarial seals.
- The planet has a real bootstrap path for paper, certificates, printing, admin science, plastic, coffee substitute, and lies.
- Local variants solve actual progression needs instead of cloning every Nauvis recipe.
- Territorial arbitration is an excellent non-military replacement for demolisher conflict. It changes how territory is claimed rather than merely renaming damage.
- The Notary Office has a clear global export identity.

Balance/progression concern:

- The analyzer reports one imported `territorial-deed` for the rocket silo. This is acceptable if the deed is explicitly the conflict-resolution milestone that replaces defeating a demolisher.
- It must be signposted before landing and in the rocket-silo tooltip/technology chain.
- Confirm that a player can obtain the deed from a normal starting-area demolisher without an excessive waiting or resource grind.

Verdict: keep the design; polish, signpost, and playtest quantities.

### Gleba: most inventive, most overloaded

What works:

- Amber sap, biological ink, perishable yellow forms, conciliation, and spore lures produce a coherent biological bureaucracy.
- Capture Bureau modes create active interaction with native creatures rather than a passive recipe reskin.
- Space tourism converts creature handling into an orbital public-finance mechanic, which is memorable and useful.
- Pentapod egg payouts scale by size, which is a better risk/reward shape than a flat payout.

Concerns:

- The planet simultaneously introduces perishable forms, three lure fluids, capture modes, tourism packages, tourist items, jettison recipes, workforce conversion, pentapod egg harvesting, and conciliation paperwork. That is enough mechanics for two planets.
- Basic launch production still consumes bulk Nauvis politician fluid and rubble.
- The Capture Bureau is a large runtime-managed building with multiple modes; its feedback must be exceptionally clear.
- Tourism payouts of 75/175/450/1200 taxpayer money are roughly an order of magnitude above ordinary complaint payouts. This may be appropriate for late orbital logistics, but it could trivialize the public-finance chain.
- “Jettison the already-paid tourist” is funny but works against the mod's nonviolent/restorative premise. If that dissonance is not intentional, use repatriation, indefinite layover, or liability transfer instead.

Recommended shape:

- Keep yellow spoilage, conciliation, and one Capture Bureau loop as the core.
- Treat tourism as the advanced reward after the player understands capture.
- Consider merging the three lure fluids into one base culture plus mode-specific items or signals if the GUI and pipe burden becomes noisy.
- Add a local administrative substitute for politician fluid and rubble.

Verdict: high potential; needs simplification, local-production fixes, and pacing tests.

### Fulgora: good fiction, shallow gameplay

What works:

- Digital bureaucracy and archive salvage are exactly the right satire for Fulgora.
- Charged toner from scrap is better than adding another map deposit.
- The Digital Services Bureau is a desirable interplanetary reward.
- Magenta forms clearly communicate holmium/electromagnetic provenance.

What is missing:

- A complete local route for ordinary black paperwork and machine authorization.
- An active mechanic comparable to territorial arbitration, creature capture, or fax routing.
- A reason to operate the Digital Services Bureau beyond receiving free finished documents from scrap.
- Distinct visual identity: several Fulgora/Aquilo entities and technologies still reuse generic office-building or steel-forge art.

Recommended additions:

- Recover corrupted form fragments from scrap and route them through circuit-controlled reconstruction.
- Let the Digital Services Bureau accept a signal specifying which archive document to reconstruct, giving Fulgora a small programmable administrative puzzle.
- Add a “data corruption” choice: fast lossy reconstruction versus slower certified reconstruction.
- Use electromagnetic energy or electrolyte as the local substitute for black ink and lubricant-adjacent needs.

Verdict: the planet needing the most design and progression work.

### Aquilo: excellent capstone with one major contradiction

What works:

- Aquilo as convergence rather than a fourth color is the correct design.
- Solid transfer media distinguishes it from the Chromatic Printer.
- Bicolor, tricolor, and unified documents create a readable interplanetary escalation.
- The fax system is unusually complete: destination selection, receiver uniqueness, queue reservation, quality preservation, circuit signals, stalling, and reconstruction costs all exist.
- Base queue capacity 5, rising to 20 through research, gives the network an upgrade path.

Concerns:

- Fax reconstruction still consumes frozen liquid inks.
- Shipping each exact ink to the receiver can erase the logistical advantage of faxing.
- The Laser Printer claims a reconstruction category it cannot use with fluid recipes.
- Aquilo should remain import-dependent, but imported materials should arrive as compact standardized transfer media, not as a contradictory recreation of every liquid ink network.

Verdict: strong capstone architecture; redesign reconstruction inputs and then tune throughput.

## Core mechanics: fun, usefulness, and balance

### Complaint resolution and protests

This remains the mod's defining success. It replaces enemy waves with a queueing and service-capacity problem while preserving urgency and map interaction.

Good balance properties:

- complaint count scales 1/3/6/10 with enemy size;
- payout scales 5/15/50/100, so larger enemies are more valuable per complaint rather than merely more tedious;
- ten minutes to protest is forgiving enough to diagnose a backlog;
- promises create a temporary recovery window instead of deleting the problem;
- protest targeting is capped and load-aware.

Risks:

- A desk has 20 inventory slots while a behemoth can carry ten complaints, so two large citizens can dominate a desk.
- The player can encounter higher complaint tiers before researching their resolution chains; warnings exist, but the progression pressure must be tested on high-evolution settings.
- The default ten-minute timer may make protests too rare for experienced players, while hard mode jumps from inconvenience to building damage.

Recommendation:

- Keep the default generous.
- Add a middle difficulty setting that shortens queue tolerance or raises administrative demand without enabling attacks.
- Track mean wait time, protest count, and desk occupancy in the existing runtime debug export.

### Workforce, Biter Stations, Field Offices, and Biterports

This is the strongest secondary pillar. The player does not merely pacify enemies; they turn them into the labor system that operates the bureaucracy. Biterports in particular are mechanically useful rather than decorative satire.

Risks:

- Staffing is upstream of paperwork, and paperwork is upstream of staffing/buildings. The loops are interesting only while recovery paths remain obvious.
- `scripts/biterport.lua` is over 3,100 lines and owns networking, reservations, job discovery, worker movement, item handling, construction, coffee, hidden entities, rebuilding, and GUI/hover behavior. The mechanic is valuable, but the implementation has become difficult to reason about.

Recommendation:

- Preserve the system.
- Split job discovery, network topology, worker state, inventory transfer, and migration/rebuild logic into separate modules before adding more Space Age behaviors.

### Working hours and coffee

The mechanic is thematically excellent and creates time-based factory planning. The startup setting to disable it is the correct accessibility valve.

Risks:

- It is difficult for planning mods to model.
- Night shutdown, station coffee, building modules, and worker visits form several overlapping exceptions.

Recommendation:

- Keep it opt-out.
- Make every affected entity's tooltip state its night rule directly.
- Add a circuit signal for “closed due to working hours” if one does not already exist.

### Pneumatic paperwork

This is a clear, useful logistics mechanic with scalable capacity. It gives paperwork a transport identity separate from belts and bots. It should remain central and receive Space Age integration rather than being superseded by faxing.

Recommendation:

- Keep faxing interplanetary and pneumatic tubes local.
- Consider a late Space Age tube endpoint that can automatically feed fax reconstruction requests without merging the two networks.

### Public finance and tourism

Taxpayer money is a good connective resource because it closes the complaint loop and finances administration. The danger is binary dependence: if complaints stop, large parts of progression stop.

Recommended balance checks:

- time to first treasury bond;
- taxpayer income per minute by evolution tier;
- percentage of income from complaints versus tourism after Gleba;
- whether tourism completely replaces complaints;
- whether off-world ordinary production can proceed without imported taxpayer money.

### Chromatic gates

Adding a form based on tungsten, carbon fiber, and holmium ingredients is elegant and broadly compatible. Collapsing two colors into a bicolor form prevents ingredient-list explosion.

Risks:

- Dynamic post-processing in `data-final-fixes.lua` can affect other mods unpredictably.
- Fixed per-craft form cost interacts unevenly with recipes that have different batch sizes.
- A third-party recipe that happens to consume a planetary intermediate may receive a progression gate its author did not expect.

Recommendation:

- Add a documented remote interface or prototype flag for opt-out/override.
- Emit a startup log of recipes receiving chromatic gates.
- Test common Space Age overhaul/recipe mods before release.

## Code quality assessment

### Strengths

- Space Age loading is centrally feature-gated and base-only loading succeeds.
- Surface restrictions use shared helpers rather than scattered raw condition tables in most places.
- Runtime code is defensive about invalid entities, stale state, migration cleanup, and registry rebuilds.
- The event router centralizes event registration.
- Fax document requirements are centralized in `scripts/fax_shared.lua`.
- Tests execute real prototype files through mocks rather than merely searching strings.
- Dump-driven tests validate Factorio's real post-final-fixes prototype graph.
- Quality is preserved in fax jobs and reconstruction.
- Runtime debug instrumentation already exists for expensive systems.

### Weaknesses

- `control.lua` is still about 2,260 lines despite extraction.
- `scripts/biterport.lua` is about 3,133 lines.
- `scripts/biters_protests.lua` is about 2,790 lines.
- `scripts/fax.lua` is about 2,209 lines.
- `prototypes/recipe/space_age.lua` is about 2,167 lines and mixes all planets, helpers, cloning, scrap mutation, tourism, and fax recipes.
- `data-final-fixes.lua` is about 1,777 lines and is the compatibility-critical center of recipe mutation.
- Many tests recreate large partial Factorio environments. This gives good unit coverage but also risks testing the mock's assumptions rather than the game.
- No Lua linter configuration was found; syntax is validated, style and global misuse are not.
- `prototypes/entity/space_age.lua` contains a duplicate `sound` key in the Administrative Space Station's `working_sound` table. It is harmless because both values are identical, but it is evidence that linting would help.
- A compiled `tests/__pycache__` artifact is tracked on the branch.

Recommended refactor boundaries:

- `prototypes/recipe/space_age/{shared,vulcanus,gleba,fulgora,aquilo,orbital}.lua`
- `scripts/fax/{registry,queue,reconstruction,circuit,gui}.lua`
- `scripts/biterport/{network,jobs,workers,inventory,migrations}.lua`
- `scripts/biters/{registration,complaints,protests,pacification}.lua`

Do not perform a giant rewrite. Extract one stable responsibility at a time while preserving the existing tests.

## Documentation, localization, and presentation gaps

### README is wrong on this branch

The README says Administratorio is incompatible with Space Age and Quality. The branch demonstrably loads with both. Before release, replace that statement with the actual status and known limitations.

### Internal notes are useful but not authoritative

Several plan snapshots describe states no longer present, including prior fax inputs, old Fulgora resource concepts, and aggregate-import claims. Plans should not be the only source of current truth.

Recommended structure:

- `design-principles.md`: stable intent;
- `implemented-state.md`: generated or manually verified current behavior;
- `open-issues.md`: current blockers;
- dated historical plans moved to an archive folder.

### Localization is incomplete

Unique locale-key counts from the current files:

- English: 866
- French: 688
- Russian: 690

Roughly 176-178 English keys are absent from each translation, dominated by Space Age content. In addition, some Space Age recipe names and descriptions are constructed as hard-coded English localized-string fragments in Lua, making them impossible to translate cleanly.

Required change:

- Move all player-visible Space Age strings into locale keys.
- Add an automated locale parity report by section.
- Translation completion can follow beta release, but raw English fragments in Lua should be removed first.

### Visual identity is incomplete

Several major Space Age technologies and buildings reuse the steel-forge or office-building icons and cloned machine art. Functional placeholders are acceptable during implementation, but they reduce recipe readability in a mod already asking the player to distinguish many forms.

Priority art targets:

1. Chromatic Printer and Laser Printer;
2. Digital Services Bureau;
3. Interplanetary Fax Exchange and Fax Emitter;
4. Administrative Space Station;
5. planet technology icons;
6. stronger bicolor/tricolor silhouettes.

## Missing mechanics and additions worth considering

These are additions, not blockers. The branch already contains enough systems; only add them after progression cleanup.

### 1. Administrative manifests

Before launching to a planet, show an optional checklist of specialist workers and unique documents needed for a viable first base. This turns forgotten imports from a wiki trap into deliberate planning.

### 2. Fulgora programmable reconstruction

Use circuit signals to request a document from corrupted archive fragments. The Digital Services Bureau then reconstructs the requested form. This gives Fulgora an active mechanic and makes circuits thematically relevant.

### 3. Expired-form revalidation

Let spoiled yellow forms become expired records that can be revalidated at the Conciliation Desk. The player still pays for neglect, but the item does not become generic paper and erase its history.

### 4. Fax service levels

Offer a choice between:

- standard: cheap, queued;
- priority: more transfer media, faster;
- certified: preserves higher quality or handles multicolor work.

This would make fax capacity upgrades and circuit requests more expressive without adding another resource family.

### 5. Space Age achievements

Add achievements for:

- first territorial deed;
- first pentapod conciliation/capture;
- first tourist returned or reassigned;
- first Digital Services Bureau;
- first successful fax;
- a full fax queue processed without stalling;
- first trichromatic permit;
- first promethium research charter;
- completing the actual Space Age victory condition.

### 6. Difficulty presets

Expose coherent presets rather than many unrelated toggles:

- Casual Administration: working hours off, slower frustration, generous paperwork.
- Standard: current intended balance.
- Hostile Compliance: faster frustration and tighter staffing, without direct attacks.
- Hard Mode: current attack escalation.

## Recommended implementation order

### Milestone 1: make the campaign semantically playable

1. Disable the base rocket-victory handler under Space Age.
2. Choose and test the Space Age victory/capstone condition.
3. Fix README compatibility claims.
4. Add a regression test for routine cargo launches.

### Milestone 2: guarantee ordinary local production

1. Add import classifications to the route analyzer.
2. Fix Fulgora black paperwork, smelting authorization, and crude/lubricant dependency.
3. Fix Gleba's bulk politician-fluid and rubble dependencies.
4. Decide and document the allowed specialist-worker starter imports.
5. Re-run named target profiles in CI.

### Milestone 3: repair planet identity contradictions

1. Redesign fax reconstruction around solid transfer media.
2. Align Laser Printer categories with recipes it can actually craft.
3. Reduce direct finalized-document drops from Fulgora scrap.
4. Verify five-minute yellow-form logistics.

### Milestone 4: balance and UX

1. Add Space Age Factoriopedia/tips entries.
2. Run timed first-planet playtests on Vulcanus, Gleba, and Fulgora.
3. Measure specialist-building throughput and tourism income.
4. Add missing circuit/status feedback.
5. Complete visual differentiation for the core Space Age machines.

### Milestone 5: maintainability and release polish

1. Split the largest files along stable responsibility boundaries.
2. Add Lua linting.
3. Remove tracked cache artifacts.
4. Move hard-coded English text into locale.
5. Add multiplayer, migration, and stress tests.

## Release acceptance criteria

The Space Age branch should be called ready when all of the following are true:

- A cargo rocket does not finish a Space Age game.
- Base-only and Space Age prototype loads both pass on the supported Factorio version.
- All Lua tests pass.
- Targeted planet profiles pass without unapproved ordinary imports.
- Vulcanus, Gleba, and Fulgora each support ordinary local production and escape, while still requiring their intended specialist/conflict milestones.
- Aquilo remains deliberately import-dependent.
- Fax reconstruction follows the frozen-ink fiction or the fiction is explicitly changed.
- One complete human playthrough has been performed with each basic planet chosen first.
- One full campaign reaches the chosen Space Age victory condition.
- A multiplayer smoke test covers complaints, workers, faxing, and victory.
- A stress save with large biterport, protest, and fax populations remains within an agreed UPS budget.
- All Space Age player-facing strings have locale keys.
- README, Factoriopedia, and current-state documentation match the shipped behavior.

## Final assessment

The branch does not need more raw feature volume. It needs progression truth, clearer contracts, and selective refinement.

Keep:

- territorial arbitration;
- biological conciliation and perishable yellow forms;
- digital archive recovery;
- solid-transfer Aquilo and interplanetary faxing;
- specialist workforce logistics;
- colored paperwork convergence;
- trajectory compliance;
- the existing core complaint, labor, finance, coffee, and pneumatic systems.

Change before release:

- Space Age victory handling;
- Fulgora and Gleba ordinary local-production routes;
- analyzer pass criteria;
- fax reconstruction inputs;
- onboarding, documentation, and locale structure.

Tune through playtesting:

- 50% productivity specialist buildings;
- five-minute yellow-form spoilage;
- tourism income;
- desk congestion at high evolution;
- fax queue and reconstruction costs.

The core is worth preserving. The remaining work is not “invent more.” It is the mildly less glamorous academic discipline of making every promise in the design survive contact with an actual player. Tragically, this is how good mods happen.
