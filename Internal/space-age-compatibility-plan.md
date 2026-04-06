# Space Age Compatibility Plan

This document organizes candidate Space Age ideas for Administratorio and evaluates them against the mod's current implementation.

It is intentionally blunt. Some ideas are strong thematic fits but poor architectural fits unless the complaint runtime is simplified first.

## Current Baseline

Space Age compatibility is currently blocked at the dependency level in [`info.json`](~/.codex/worktrees/35bf/administratorio/info.json) with `! space-age`.

The current mod architecture also has three important constraints:

1. Complaint handling is runtime-heavy.
   Each biter at a desk is a live tracked unit with state, frustration, protest logic, desk slot reservation, and an in-memory complaint list. This lives mainly in [`scripts/biters.lua`](~/.codex/worktrees/35bf/administratorio/scripts/biters.lua) and [`scripts/biters_protests.lua`](~/.codex/worktrees/35bf/administratorio/scripts/biters_protests.lua).

2. The admin station is both inbox and payout chest.
   The desk only has `inventory_size = 20` in [`prototypes/entity/admin-buildings.lua`](~/.codex/worktrees/35bf/administratorio/prototypes/entity/admin-buildings.lua), and that inventory currently stores complaint tickets, resolved items, and taxpayer payout.

3. Resolution matching is item-by-item, not case-based.
   [`scripts/biters.lua`](~/.codex/worktrees/35bf/administratorio/scripts/biters.lua) removes one matching complaint from one waiting biter for each `resolved-*` item found in the desk chest. There is no notion of a bundled case file, reservation token, or per-biter output channel.

Those three constraints should drive every Space Age decision.

## Design Goals

1. Preserve the mod's identity.
   Space Age content should still feel like bureaucracy replacing violence, not vanilla combat with paperwork layered on top.

2. Prefer itemized logistics over bespoke runtime AI.
   New content should mostly be recipes, buildings, technologies, and logistics items. New "live creature state machines" should be rare.

3. Avoid planet-specific one-off control logic unless the loop is exceptional enough to justify it.

4. Keep interplanetary gameplay paperwork-centric.
   Faxing, permits, archives, office satellites, astronaut clerks, and cross-planet form routing are all strong fits.

## Executive Review Of The Proposed Ideas

| Idea | Theme fit | Implementation fit | Feasibility | Recommendation |
| --- | --- | --- | --- | --- |
| Enroll biters as workers through complaint resolution | Very high | Medium-low | Medium | Keep, but redesign around deterministic conversion outputs |
| Train enrolled biters into astronauts | High | Medium | Medium-high | Keep |
| Space office crafting paperwork in space | Very high | High | High | Keep, likely core Space Age loop |
| Non-weapon asteroid solution | High | Unknown | Medium-low | Keep only after picking a concrete logistics-based mechanic |
| Pay demolishers with taxpayer money on Vulcanus | Very high | Medium | Medium | Keep, but make it building-driven rather than floor-item gimmick |
| Gleba complaints arrive in rapid rot bursts | High | Low | Low-medium | Rework heavily before implementation |
| Gleba forms rot into regular paper | High | High | High | Keep |
| Fulgora archive salvage yields random forms | Very high | High | High | Keep |
| Planet-specific inks and universal fax network | Very high | High | High | Strong candidate for main Space Age backbone |
| Negotiator spidertron with biter asset | Very high | Medium | Medium | Keep as late-game prestige feature, not core progression |

## Recommended Expansion Shape

The cleanest Space Age version is not "every planet gets a custom enemy runtime."

The cleanest version is:

1. Nauvis introduces biter enrollment and astronaut training.
2. Fulgora introduces archive recovery and random paperwork reconstruction.
3. Vulcanus introduces territorial bribery through a dedicated diplomacy building.
4. Gleba introduces rot-sensitive paperwork and biological office hazards, but with minimal live-entity complaint logic.
5. Cross-planet progression is tied together by colored inks, cartridges, faxing, and orbital/space-office bureaucracy.

This keeps the expansion centered on paperwork logistics, which matches the existing mod structure far better than building three new live complaint AI subsystems.

## System Proposals

### 1. Biter Enrollment

Original idea:
Resolve a complaint by outputting a job offer instead of a normal resolution, and let the waiting biter accept or reject it.

Assessment:
The fantasy is excellent, but the current desk system is not built for branching per-biter interactions. A desk chest is just a shared inventory. If multiple biters are waiting with multiple complaints, there is currently no safe way to say "this job offer belongs to that exact biter and replaces the normal resolution path" without extra state.

Main conflicts with current implementation:

- Resolutions are matched by item name only, not by case identity.
- A single biter can have multiple complaints in `info.complaints`.
- The desk chest is shared by all waiting biters at that desk.
- The runtime does not support a "pending offer decision" state.

Recommended redesign:

1. Add a new final-tier alternative output per complaint family, such as `job-offer-landscape` or a generic `employment-offer`.
2. When the desk consumes a matching offer, convert exactly one complaint into an `enrolled-biter` item instead of sending the unit home.
3. Do not model explicit acceptance/rejection initially.
4. Treat enrollment as deterministic if the complaint is eligible.

Why this is better:

- It avoids adding dialogue state to live entities.
- It converts a runtime-managed unit into a normal item as early as possible.
- It gives a clean handoff into Space Age logistics and training.

Feasibility:
Medium. Requires runtime changes in complaint resolution, but the state model stays manageable if acceptance is not simulated.

Open design question:
Should enrollment consume the entire biter after resolving one complaint, or require all complaints on that biter to be cleared first?

Recommendation:
Require all complaints to be cleared first, then allow a final "employment conversion" step. That is much cleaner than mixing partial complaint completion with worker extraction.

### 2. Astronaut Training

Original idea:
Enrolled biters can be trained in a new building into astronauts.

Assessment:
This is one of the strongest ideas in the set. Once an `enrolled-biter` exists as an item, training is mostly standard Factorio content: item -> recipe chain -> specialist item.

Recommended implementation:

- Add `training-center` building.
- Recipes:
  - `biter-orientation`
  - `astronaut-certification`
  - `negotiator-certification`
- Inputs should likely include paperwork, coffee, protective equipment, and maybe planet-specific inks or directives.

Potential conflicts:

- None at the runtime level if `enrolled-biter` is already an item.
- Balance concern: if enrollment is too cheap, this becomes a free conversion of enemy pressure into high-value specialists.

Feasibility:
Medium-high.

Recommendation:
Keep. This should likely be one of the first Space Age features implemented.

### 3. Space Office

Original idea:
Astronauts are needed to craft a "space office" that crafts paperwork in space.

Assessment:
Strong fit mechanically and thematically. This is the most obvious bridge between Administratorio and Space Age platform gameplay.

Recommended implementation:

- New building: `space-office`.
- Crafted from astronaut workforce, high-tier paperwork, electronics, and platform-compatible materials.
- Crafting categories:
  - orbital paperwork
  - fax relay setup
  - space administration
- Primary purpose:
  - produce forms in orbit
  - support interplanetary paperwork demand
  - potentially satisfy offworld permit requirements

Potential conflicts:

- Need to decide whether space-office is a normal assembling machine clone or something platform-specific.
- Existing progression may need a new science/tech bridge so orbital bureaucracy does not appear too early.

Feasibility:
High.

Recommendation:
Make this the centerpiece of Space Age compatibility.

### 4. Asteroid Handling Without Weapons

Original idea:
Need a way of dealing with asteroids without weapons.

Assessment:
Correct problem, but the mechanic is currently underspecified.

Bad direction:

- Recreating vanilla combat with "non-lethal weapons" disguised as bureaucracy.

Better directions:

1. Permitting beam / rerouting signal.
   Asteroids are redirected by filing transit permits or orbital traffic directives.

2. Insurance claim interception.
   Asteroids become claimable hazards that are converted into paperwork and salvage if processed by a special office structure.

3. Debris compliance net.
   A platform building captures and reclassifies asteroids as archived debris instead of destroying them militarily.

Best fit:
Use an orbital bureaucracy building that "reclassifies" asteroids into paperwork-compatible debris streams.

Main risk:
If the mechanic ultimately still needs to function like damage-dealing combat, the thematic layer may feel fake.

Feasibility:
Medium-low until a concrete non-combat loop is chosen.

Recommendation:
Do not start implementation until the exact loop is specified in one sentence.

Suggested rule:
"Asteroids are neutralized by administrative interception buildings that consume cartridges/forms and output classified debris."

### 5. Vulcanus: Buying Land From Demolishers

Original idea:
A demolisher can be bribed by feeding it taxpayer money fast enough; larger demolishers need higher throughput.

Assessment:
This is very on-brand. It also maps fairly well onto Factorio throughput gameplay.

The floor-drop money-fountain version is probably not the right implementation.

Problems with the current phrasing:

- Item-on-ground interactions are awkward and unreliable compared to inventory or machine interactions.
- Designing this around entities picking up items from the floor risks jank and performance edge cases.
- "Need multiple to keep the pace" is good gameplay, but the delivery method should be cleaner.

Recommended redesign:

- New building: `eminent-domain-disperser` or `taxpayer-fountain`.
- It targets nearby demolishers and continuously spends `taxpayer-money` or higher-value bribe documents.
- Each demolisher has a required bribery rate.
- Insufficient sustained throughput causes the negotiation to fail or decay.

Possible resource ladder:

- early: raw `taxpayer-money`
- mid: `treasury-bond`
- late: `government-grant` or `land-acquisition-package`

Potential conflicts:

- If demolishers are not easily interceptable via existing APIs, this may need custom runtime tracking.
- Balance risk: taxpayer money is already central to the main economy, so this could overcompete with current progression.

Feasibility:
Medium.

Recommendation:
Keep, but implement as a dedicated building with a visible "bribery pressure" mechanic, not as loose dropped items.

### 6. Gleba: Complaint Swarms And Rot

Original idea:
Enemies complain like Nauvis, but send many complaints per second; forms rot; eggs need special handling; gleba-specific forms can rot into regular paper.

Assessment:
This has good atmosphere but is the weakest architectural fit in its current form.

Main problems:

- The current complaint runtime is already the heaviest bespoke system in the mod.
- "Multiple complaints per second" multiplies desk inventory pressure, runtime matching work, and frustration instability.
- Rot on complaint items inside a shared desk chest could become chaotic and unreadable.
- Egg handling adds another special-case logistics object on top of that.

Direct conflicts with current implementation:

- Desk inventory is only 20 slots.
- Walk-ins currently insert all complaint tickets at registration time.
- A high-frequency complaint burst would cause immediate chest-full failures and protests.
- Complaint tracking is per waiting biter with a normal Lua table of items, not designed for continuous inflow after registration.

Recommended redesign:

Keep only the rot side of the idea.

Better Gleba loop:

1. Gleba introduces biodegradable paperwork.
2. Special Gleba forms decay into `paper` or `spoiled-paper-pulp`.
3. Biological hazards create office contamination recipes, not live complaint swarms.
4. Eggs are processed as items through a `quarantine desk` or `biorecords office`, not by requiring enemy walk-ins at high frequency.

If enemy interaction is still desired:

- Use occasional high-value "inspection incidents", not continuous complaint spray.

Feasibility:
Current version: low-medium.
Reworked item-centric version: high.

Recommendation:
Do not implement "multiple complaints per second" literally.

### 7. Fulgora: Scrapyard Archives

Original idea:
Old archives appear in scrap and yield random forms that must be recycled or reassembled. No enemy.

Assessment:
Excellent fit. This is one of the easiest ideas to integrate with existing recipe/item patterns.

Good reasons:

- It is item-centric.
- It does not need runtime enemy logic.
- It adds a new source of paperwork materials without competing with Nauvis complaints directly.
- Random recovery and reconstruction matches Fulgora well.

Recommended implementation:

- New item drops such as `damaged-archive`, `burned-ledger`, `partial-form`.
- Recyclers or archive offices convert them into:
  - random low-tier forms
  - archive fragments
  - repairable legal templates
- Optional recipe chain:
  - `archive sorting`
  - `form reconstruction`
  - `certified reassembly`

Potential conflicts:

- Random output should not bypass the intended bureaucracy tiering too hard.
- Need to avoid showering the player with high-tier approvals too early.

Feasibility:
High.

Recommendation:
Implement early in the Space Age roadmap.

### 8. Planet-Specific Inks And Fax Network

Original idea:
Each planet unlocks a new ink color, used for its forms; combined inks produce cartridges for a fax machine and antenna that transmit forms across planets without ships.

Assessment:
This is probably the best idea in the whole set.

Why it fits:

- It turns interplanetary logistics into paperwork logistics instead of cargo rocket micromanagement.
- It naturally uses items, recipes, buildings, and techs.
- It gives each planet a clear bureaucratic identity.
- It creates a strong reward loop for visiting all planets.

Recommended structure:

- Vulcanus ink: blue
- Gleba ink: green
- Fulgora ink: red
- Existing Nauvis/base ink stays black
- Combined product: `interplanetary-ink-cartridge`

Buildings:

- `fax-machine`
- `bureaucratic-antenna`
- maybe `orbital-relay-office`

Likely rules:

- Only paperwork-class items can be faxed.
- Faxing consumes power, cartridges, and maybe transmission permits.
- Some rare items should stay unfaxable for balance.

Potential conflicts:

- Existing pneumatic transport already creates a fluidized logistics layer for paperwork.
- Need to define whether faxing complements or replaces ships for paperwork.

Recommendation on that conflict:
Faxing should complement ships, not replace them entirely. Restrict faxing to paperwork items and perhaps low-stack official capsules/documents, while buildings, fluids, and bulk materials still require normal logistics.

Feasibility:
High.

Recommendation:
Make this the second major backbone after space-office content.

### 9. Negotiator Spidertron

Original idea:
Training center can also train a negotiator, a spidertron-like remote-controlled unit with a biter asset that delivers eviction notices and bureaucratic promises.

Assessment:
Very strong fantasy. Moderate implementation risk.

Good fit points:

- The mod already conceptually replaces military tools with paperwork tools.
- A negotiator unit is a natural late-game mobility/expansion tool.
- Existing code already knows about spidertron-related prototypes in [`data-final-fixes.lua`](~/.codex/worktrees/35bf/administratorio/data-final-fixes.lua).

Risks:

- Vehicle compatibility can get messy with Space Age and other mods.
- If this becomes mandatory for core progression, it may overcomplicate the first compatibility release.

Recommended role:

- Late-game utility unit.
- Can deploy eviction notices at range.
- Can pacify protesters remotely.
- Can perform offworld diplomatic errands if lore permits.

Feasibility:
Medium.

Recommendation:
Keep, but ship after the core Space Age logistics systems are stable.

## Cross-Cutting Risks

### Runtime Performance Risk

Anything that increases the number of simultaneously tracked live complaint entities is dangerous. The current runtime already tracks:

- waiting
- pathfinding
- protesting
- pacified
- returning_home

New planet systems should favor item transformations over additional unit states.

### Inventory Pressure Risk

The `admin-station` chest is already a bottleneck. Space Age content that adds more complaint item churn will fail unless the desk model changes.

Possible future fixes:

1. Increase desk inventory.
2. Separate complaint inbox from payout storage.
3. Move to case bundles rather than many loose tickets.

Of those, separating inbox/payout storage is the healthiest medium-term change.

### Progression Dilution Risk

Space Age can easily flood the mod with side systems. The expansion should preserve one readable progression spine:

1. resolve / enroll
2. train specialists
3. establish orbital office
4. unlock planet inks
5. build fax network
6. solve planet-specific bureaucracy problems

### Theme Drift Risk

The expansion should avoid:

- stealth weapons renamed as office tools
- too many biology gimmicks detached from paperwork
- new planets that ignore the complaint/permit/administration identity

## Conflicts With Existing Progression

### Taxpayer Money Is Already Overcommitted

`taxpayer-money` currently funds important existing chains. If it also becomes the core currency for Vulcanus bribery, astronaut training, fax cartridges, and orbital operations, the economy may become too singular.

Recommendation:

- Keep `taxpayer-money` as the raw base currency.
- Add higher-tier Space Age sinks such as:
  - `offworld-allocation`
  - `planetary-development-grant`
  - `extraterritorial-claim`

### Complaint Resolution Techs Are Already Tight

Current complaint tiers already lag enemy evolution in some cases. Adding Space Age complaint variants before fixing that baseline could make Nauvis stability worse instead of better.

Recommendation:

- Do not add new complaint families until base complaint pacing is fully comfortable.
- Use planet loops that are mostly independent from the core desk runtime.

### Existing Transport Identity Is Pneumatic

The mod already has a paperwork transport fantasy: pneumatic form transport.

Recommendation:

- Position faxing as long-range, low-volume, high-value transmission.
- Keep pneumatic transport as the local factory-scale paperwork backbone.

That makes the logistics stack feel coherent:

- local: belts/inserters
- paperwork local: pneumatic
- interplanetary paperwork: fax
- heavy cargo: ships

## Recommended Implementation Order

### Phase 1: Compatibility Foundation

1. Remove the hard Space Age incompatibility flag.
2. Audit prototype assumptions against Space Age items, planets, and surfaces.
3. Confirm base game startup cleanup and progression still work when Space Age is active.

### Phase 2: Minimal Thematic Bridge

1. Add planet-specific inks.
2. Add fax machine and antenna.
3. Allow paperwork-only interplanetary transmission.

This phase gives a real compatibility win without touching the most fragile runtime systems.

### Phase 3: Workforce Expansion

1. Add enrolled biters.
2. Add training center.
3. Add astronauts.
4. Add space-office.

This phase makes Space Age feel native to Administratorio.

### Phase 4: Planetary Flavor

1. Fulgora archive recovery.
2. Vulcanus bribery/diplomacy.
3. Gleba rot paperwork and biohazard administration.

### Phase 5: Prestige Systems

1. Negotiator spidertron.
2. More exotic orbital bureaucracy.
3. Optional asteroid administration mechanic.

## Concrete Recommendations Per Original Idea

### Keep Mostly As-Is

- astronaut training
- space office
- fulgora archives
- colored inks
- fax network
- negotiator concept

### Keep But Redesign

- biter enrollment through complaint resolution
- vulcanus demolisher bribery
- gleba enemy interaction
- asteroid handling

### Avoid In First Release

- explicit offer acceptance/rejection simulation
- floor-drop money fountain as the primary demolisher interface
- gleba complaint spam measured in complaints per second

## Best Candidate For First Space Age Milestone

If only one feature set should be built first, it should be:

1. planet-specific inks
2. fax machine + antenna
3. training center
4. enrolled biters -> astronauts
5. space office

That set is coherent, valuable, and does not require rewriting the complaint runtime into something more complex than it already is.

## Questions Worth Settling Before Implementation

1. Is enrollment deterministic, or should there be a success chance / eligibility gate?
2. Does an enrolled biter come only from fully resolved cases, or can a partially handled biter be recruited?
3. Is faxing instant, buffered, or recipe-based over time?
4. Are planet-specific forms separate items, or are the inks simply ingredients for existing paperwork?
5. Is asteroid handling mandatory for progression, or a side mechanic?
6. Should Vulcanus bribery consume raw money continuously, or packaged bribe documents?
7. Should Gleba have any live enemy desk loop at all, or should it be purely item/rot based?

## Final Call

The Space Age version should lean harder into paperwork logistics, specialist workforce conversion, and interplanetary administration.

The least safe direction is to multiply the number of bespoke live-enemy complaint systems.

The safest strong direction is:

- convert enemies into workforce items
- train them into specialists
- bureaucratize orbit
- bureaucratize interplanetary logistics through inks and faxing
- give each planet one mostly item-driven paperwork identity
