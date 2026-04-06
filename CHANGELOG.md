# Changelog

## Unreleased

## 0.2.8 - 2026-04-06

### Fixed
- Fixed the rocket-launch win screen crash on Factorio 2.0 by reading paperwork production statistics through the per-surface `LuaForce.get_item_production_statistics(surface)` API.

## 0.2.7 - 2026-04-06

### Added
- Replaced the Resolution Office placeholder visuals with dedicated scrubber art.

### Changed
- Split oil-chain operating paperwork into clearer tiers: `petrochemical-operating-permit` now covers baseline refinery startup and simple petrochem, while `chemical-handling-work-order` handles chemical plants, advanced oil processing, coal liquefaction, and heavier chemistry.
- Moved `promise-production` to `discovery-redundant-rubble`, making Bureaucratic Promises available with the first complaint-desk bootstrap instead of waiting for printing tech.
- Restored a civilian cliff-clearing path: `cliff-explosives` no longer depends on military tech or grenades, but still requires `explosives` and explicit construction paperwork.

### Fixed
- Fixed transit permit chest placement at train stops. The chest now sits on the rail-adjacent tile before the stop in train direction, and existing stations migrate there from both overlapping and misaligned legacy positions on init/config-change.
- Fixed protesting biters getting stranded on removed or invalid protest targets. They now immediately retarget to another reachable building, and protest alerts wait until arrival instead of firing on abandoned path attempts.
- Fixed robot, blueprint, and paste placement metadata across custom buildings and pneumatic entities so construction robots consistently use the canonical item/entity pairings.
- Fixed admin station and office desk circuit connector alignment, and now lock the admin station's runtime rotation so its footprint and wiring stay consistent.
- Fixed `smelting-basic` furnace UI duplication by keeping that category limited to the explicit batch-smelting recipes instead of cloning vanilla single-output smelting recipes into it.

## 0.2.6 - 2026-03-30

### Changed
- `pneumatic-pipe-to-ground` now requires a `construction-permit`, moving underground pneumatic transport onto the construction-paperwork tier.

### Fixed
- Fixed the hidden `form-solidifier` outtake inserter so it drops onto a stable belt lane instead of flipping lanes when rotated.
- Removed the stale electric-pole supply-area bonus so small, medium, and big power poles keep their vanilla reach.

## 0.2.5 - 2026-03-30

### Added
- Added `work-order-duplication`, a production-science printer upgrade that unlocks 6x industrial-copy recipes for every work-order family, from basic `work-order`s through chemical and radiological paperwork.

### Changed
- Printer workflows now consistently consume `ink` only in printer categories, and direct `printing-workorder` shortcuts are limited to safety and construction forms while higher-tier work orders move to industrial copy recipes.
- Deepened vanilla integration across bureaucracy chains: multiple admin buildings, pneumatic devices, paperwork stages, and complaint cases now consume more vanilla materials such as stone brick, pipes, barrels, coal, electronic/advanced/processing circuits, batteries, and steel, and office desks can now handle 10-ingredient recipes to support the denser paperwork mix.
- Rebalanced paperwork tiers for vanilla infrastructure: splitters now use safety paperwork in 5x batches, elevated rail ramps and supports require construction paperwork, electric furnaces move to verbal-management paperwork, chemistry now runs on `chemical-handling-work-order`, and steel furnaces get hidden certified `smelting-basic` variants so certificate-gated smelting stays distinct from electric-furnace progression.
- Batched regulated recipes now show their batch size directly on recipe icons, and batching coverage has been expanded across more vanilla/admin recipes including paper, ink, repair packs, heat pipes, belts, and selected equipment.
- Tightened vanilla tech prerequisites so paperwork-gated unlocks appear only when usable: solar, accumulators, electric furnaces, robotics and personal roboports, oil processing, uranium processing, nuclear power, `automation-3`, `effect-transmission`, and `rocket-silo` now wait for the matching bureaucracy branch.

### Fixed
- Fixed regulated recipe localization and Factoriopedia mapping for repair tools, equipment, place-result items, and other item-like prototypes so regulated and bulk-copy recipes inherit the correct names and descriptions.
- Fixed protesting biters losing complaint text before arrival, stalling after interrupted movement, or reviving back into broken desk/protest states after pathing recovery.
- Fixed promise pacification when no desk is free: promised biters now stay visible with a `No available desk` marker, roam between desks instead of freezing, keep 50% frustration while pacified, and cleanly resume queueing or protesting when the promise expires.

## 0.2.4 - 2026-03-29

### Changed
- Robot-network infrastructure now uses heavier automation paperwork: `flying-robot-frame`, `construction-robot`, `logistic-robot`, logistic chests, and related network pieces now require the T3 management-approval track instead of basic work orders.
- Personal roboports now follow the same T3 management-approval path as the rest of the robot network, and `pump` now requires construction paperwork instead of a basic work order.
- Demolition recipes now require explicit construction paperwork, adding permit gating to `explosives` and pushing `cliff-explosives` onto the construction-permit tier.
- Nuclear support hardware now uses written management approval, and `nuclear-power` waits for the matching executive-review paperwork branch before unlocking those recipes.
- `charcoal-production` now runs as a certified 5x furnace batch: `25 wood + 1 carbon-offset-certificate-basic -> 5 coal`, matching the rest of the regulated `smelting-basic` throughput recipes.

### Fixed
- Fixed promised protesters with no open admin-station slot so pacified biters stay visible in place, show an explicit `WAITING FOR DESK` marker, and no longer flicker in and out while waiting for capacity. Recovered desk-bound biters now also restore their reserved desk slot before resuming, preventing invalidated `pathfinding` protesters from repeatedly respawning near the desk center instead of settling into a stable waiting position.
- Fixed protesting biters losing their overhead message while moving or idling away from their target, and reworked promise pacification so it only drops frustration to 50%, restores full protest urgency when the promise expires, removes the yellow ground circle, and keeps pacified biters roaming between desks instead of freezing in place while they wait for capacity.
- Fixed Tips & Tricks and related technology copy that mislabeled the biter complaint branch as human complaints.

## 0.2.3 - 2026-03-28

### Fixed
- Fixed a crash on the first bug complaint dispatch by deferring gathered unit-group reroutes until the next main tick instead of converting and rerouting group members inside the unit-group event callback.

## 0.2.2 - 2026-03-28

### Fixed
- Fixed remaining plain `crafting` and `advanced-crafting` recipes so they always get regulated assembling-machine copies instead of being left handcraft-only. This restores AM crafting for `paper` and `ink` and adds regression coverage for the broader invariant.

## 0.2.1 - 2026-03-28

### Changed
- Moved the first landscape complaint chain off science-pack research: `filing-landscape` now unlocks from `discovery-redundant-rubble` and `landscape-final` from `discovery-bullshit`, while `administrative-bureaucracy` keeps only the separate greenhouse and wood bootstrap.

## 0.2.0 - 2026-03-28

### Added
- Administrative buildings (office desk, admin station, resolution office, greenhouse, printers, pneumatic buildings, etc.) can now be crafted in assembling machines via regulated recipe copies. Original recipes remain handcraftable.
- Added a Working Hours system for office desks, corporate breakrooms, union headquarters, and meeting rooms. These buildings now shut down at night by default unless fitted with an `Overtime Exemption`, which is unlocked by the new `After-Hours Operations` research, documented in Tips & Tricks, and surfaced in the runtime debug profiler.
- Added a startup setting to disable Working Hours entirely for players who want those buildings to remain 24/7. Disabling it also removes the module, research, tip, runtime checks, and daytime speed rebalance.
- Added evolution-threshold warnings that alert connected players shortly before new complaint tiers become mandatory, so the required bureaucracy tech can be researched before filings start upgrading.
- Added dedicated `Synthetic Stationery` and `Creative Accounting` technologies to gate synthetic paper and tax audits as explicit progression milestones.
- Added a dump-driven progression audit that runs against Factorio's real prototype graph and reports blocked unlocks, premature access, missing building recipes, and enabled recipes that still depend on tech-gated ingredients.
- Added a startup cleanup regression test and now seed one `admin-station` directly into the crash-site ship inventory so the complaint desk path is always available from minute one.

### Changed
- Rebalanced the affected administrative buildings around daytime throughput: they run faster during office hours when Working Hours is enabled, and revert to their original always-on speeds when the feature is disabled.
- `Overtime Exemption` is now crafted in the Union Headquarters instead of the office desk pipeline.
- Rebuilt the bureaucracy tech tree into narrower branches: `environmental-reporting`, `office-agriculture`, `information-management`, `verbal-approvals`, `public-finance`, `board-meetings`, `radiological-compliance`, `environmental-certification`, `federal-regulation`, `noise-ordinances`, and `loitering/vagrancy` now sit as separate unlocks instead of being bundled into a few broad umbrella techs.
- Greenhouse and wood bootstrap now unlock with `administrative-bureaucracy`; coffee discovery lives in `corporate-hospitality`; office-scale coffee farming moved to `office-agriculture`; and bulk-copy throughput is pushed to the chemical-era `industrial-printing`.
- Split remaining mixed administrative unlocks into single-purpose branches, including a dedicated `rubble-compaction` tech, a separate `verbal-approvals` step, and an optional `industrial-printing` throughput upgrade that no longer gates unique content.
- Late complaint progression now splits cleanly by family and science tier: human complaints top out on the production-science `constitutional-law` branch, while spitter complaints finish on the utility-science `vagrancy-ordinances` branch.
- Several vanilla branches now wait for the matching paperwork path before unlocking usable recipes, including rail/solar/accumulators/robotics on `verbal-approvals`, uranium processing on `radiological-compliance`, and late megaprojects on `executive-review`.
- Simplified the coffee growth loop by removing fertilizer from plantations; coffee now scales directly from beans and water, while more mid/late-game funding, meeting-room, and high-tier complaint recipes consume brewed coffee.
- Reworked the public-money loop so `slush-fund` is laundered from treasury bonds and lies, and `tax-audit` converts that slush fund back into a much larger `taxpayer-money` payout.
- Early bootstrap paperwork now comes from `discovery-bullshit`, the office desk keeps its original circuit recipe under `electronics`, and every research inherits at least the science packs already required by its parent chain.

### Fixed
- Regulated `-regulated` recipe variants now unlock correctly on research completion and when loading existing saves, instead of depending on duplicated technology effects.
- Factoriopedia now points affected vanilla and administrative products at the correct regulated automation recipe, and single-output admin recipes merge under their product pages without duplicate labels.
- The admin-station footprint no longer blocks placement across walkable entities such as belts, inserters, rails, signals, and display panels.
- Restored non-combat armor progression by remapping `heavy-armor` and `power-armor-mk2` away from removed military prerequisites.
- Protest notifications now refresh for ongoing protests instead of only appearing at the moment a protest begins.
- Retimed the key Tips & Tricks entries so complaint desks, protest handling, operating paperwork, evictions, and working-hours guidance unlock when the mechanic first becomes relevant, and refreshed the copy to better explain promises, protests, evictions, and the complaint chain.
- Fixed a crash that occurred when a biter was redirected to protest while it was scheduled to be despawned by the game.

### Optimized
- Eliminated full-surface enemy unit scan that ran every 3 seconds; unit groups are now discovered once on load and tracked via events thereafter.
- Cached protest target entity searches with a 1-second TTL so frustrated biters share a single surface scan instead of each triggering their own.
- Replaced per-candidate linear scans over all protesting biters with a single-pass count snapshot, reducing protest target selection from O(protesters × candidates) to O(protesters + candidates).
- Implemented sharding for all biter state processing (protesting, waiting, pathfinding, etc.), distributing the update load across multiple ticks to eliminate performance spikes.
- Optimized protest target selection Pass 1 to avoid all table allocations and engine calls for invalid targets.
- Added per-tick caching for the protester snapshot used in spacing and load calculations.
- Suppressed excessive debug logging in the protest, rendering, and unit-group systems to reduce log file size and minor I/O overhead.

## 0.1.9 - 2026-03-26

### Fixed
 - Fixed handcrafting category of basic excuse production to be handcraftable

## 0.1.8 - 2026-03-26

### Fixed
- Fixed placing burner miners (and other buildings) on ore patches failing with "ore is in the way" caused by the admin station collision footprint layer being added to resource entities.
- Fixed all buildings losing their default collision mask (water, object, player, item layers) when they had no explicit collision_mask, allowing placement on water and overlapping other buildings.
- Fixed "invalid key to 'next'" runtime error in `process_frustration_and_protests` caused by modifying `storage.waiting_biters` during `pairs()` iteration.
- Excluded natural map features (trees, rocks, cliffs, fish), enemy structures (nests, worms), and vehicles from the admin station collision footprint layer to prevent unintended placement conflicts.

## 0.1.7 - 2026-03-26

### Changed
- Replaced the one-off `bureaucratic-handcrafting` split with a shared `bureaucratic-bootstrap` category used by both the player and the office desk for starter paperwork and promises.

## 0.1.6 - 2026-03-26

### Fixed
- Restored early-game paperwork handcrafting so `carbon-offset-certificate-basic`, `safety-waiver-draft`, `construction-permit-draft`, `research-grant-approval`, `provisional-approval`, `work-order`, and `promise` are available through the shared bootstrap path again, preventing early deadlocks.

## 0.1.5 - 2026-03-26

### Added
- Active protests now raise a clearer notification path with custom alerts, a map tag, and a protest alarm sound, and those notifications are replayed when loading saves or when players join an existing game.
- Added detailed enemy unit-group debug logging so gathering, member churn, AI completion, redirects, and unexpected disbands can be traced in `factorio-current.log`.

### Changed
- Biters are now redirected into the complaint system as soon as they join an enemy attack group, so desk traffic arrives as a steadier flow instead of waiting for vanilla gathering groups to finish.
- Desk-bound biters now walk directly to their reserved waiting slot instead of slowing at the queue edge and then teleporting into place.
- The admin station now uses a single fixed footprint with its waiting area centered inside the building instead of relying on rotated waiting-zone variants and overlays.

### Fixed
- Fixed loaded or newly discovered vanilla gathering groups breaking up before they ever reached the desk redirect handoff.
- Fixed a `redirect_enemy_unit_group` runtime error caused by Lua helper initialization order in the unit-group debug path.
- Fixed admin-station placement and migration edge cases by normalizing old directional desk items/entities, clearing obsolete waiting-zone markers, and enforcing the new footprint with corner blockers.

## 0.1.4 - 2026-03-25

### Added
- Added a runtime debug panel toggled with `Ctrl+Shift+D` that profiles recent update costs, shows live administration/biter counts, and can export samples to `script-output` while the panel is open.

### Changed
- `promise-production` is now handcraftable from the start using a player-only crafting category and its existing early-game paperwork ingredients, so protest suppression is available well before the Corporate Breakroom without becoming cheap to spam or automatable in regular assemblers.
- Coffee bootstrapping is less punishing: `greenhouse-discovery` now refunds some of its input wood instead of yielding coal, and `coffee-refining` now brews coffee from beans, water, and a `work-order`.
- Protesters now choose reachable protest targets more deliberately, spread out around building footprints instead of piling onto the same spot, pace around disabled buildings after arrival, and raise clearer custom protest alerts.
- Building and infrastructure recipes now use the crafted entity's actual item name and description in unlocks and Factoriopedia, and unavailable regulated recipes remain visible in the crafting UI instead of disappearing outright.

### Fixed
- Promised or recovered biters now keep their unresolved complaint progress when re-queued, so partially processed cases do not restart from scratch if the biter returns to a different administration desk.
- Added the missing English locale entry for `dubious-data-batch`.
- Corrected furnace paperwork categories so steel furnaces use `smelting-basic` with carbon offset certificates, while electric furnaces use regular `smelting`.

### Performance
- Resolved biters now walk roughly 200 tiles away before despawning, with a 30-second fallback timeout, instead of triggering a map-wide spawner search during the resolution tick.
- Removed a redundant every-tick admin desk surface scan that used to run when no desks existed.

## 0.1.3 - 2026-03-24

### Fixed
- Fixed a runtime error when building an admin station caused by trying to script-unlock `welcome-to-the-department`, which is a `build-entity-achievement` that Factorio unlocks automatically.

### Changed
- Admin stations now show their waiting zone as part of the building sprite, so placement preview, rotation, and blueprint behavior match the actual queue area.
- Protest target selection now spreads biters across available buildings instead of stacking them onto the same target whenever alternatives exist.
- Updated English locale text and tips so complaint processing, protest handling, and nest expropriation guidance match the current implementation.

### Fixed
- Fixed gathered biter attack groups sometimes stalling, never reaching an office, and then breaking apart without entering the complaint flow.
- Fixed resolved biters despawning at the resolution office. They now try to path back to their original nest, or the nearest remaining nest if their home was removed, before despawning.
- Fixed eviction notices so nearby biters are redirected into the complaint system at 50% base frustration instead of disappearing or immediately protesting because an empty desk looked full.
- Fixed admin desk capacity recovery after prototype/state migrations by rebuilding missing desk zone metadata and clearing stale slot reservations from supposedly empty desks.
- Fixed `promise` handling when a protesting biter is pacified but no `admin-station` slot is available. Protesters now enter a temporary pacified state, retry for an open desk for 60 seconds, and only resume protesting if no capacity opens.
