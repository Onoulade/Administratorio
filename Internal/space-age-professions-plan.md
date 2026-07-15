# Space Age Professions Plan

This file investigates how recruited biters should branch into professions during Space Age play.

It focuses on practical hooks that already exist in the mod, especially the current `overtime-exemption` module and working-hours runtime.

## Current Code Anchors

The current night-work system is simple and exact-name based.

- The recipe is defined in [modules.lua](~/Library/Application Support/factorio/mods/administratorio/prototypes/recipe/modules.lua).
- The item is defined in [modules.lua](~/Library/Application Support/factorio/mods/administratorio/prototypes/item/modules.lua).
- Runtime checks for the literal item name `overtime-exemption` in [working_hours.lua](~/Library/Application Support/factorio/mods/administratorio/scripts/working_hours.lua).

That means:

- changing the recipe to use a profession is easy
- adding a differently named upgraded night module requires runtime changes
- replacing the current module completely with an offworld-gated profession recipe may break early progression

## Core Design Goal

Professions should do three jobs at once:

1. absorb `enrolled-biter` items so the player does not drown in them
2. make specific buildings and advanced paperwork feel staffed rather than magically self-running
3. avoid producing too many single-use specialists

The correct scale is a small profession roster with clear reuse, not a profession for every joke.

## Recommended Workforce Spine

The cleanest training ladder is:

1. `enrolled-biter`
2. `personnel-dossier`
3. `clerical-trainee` or `management-trainee`
4. specialist profession

Recommended split:

- `clerical-trainee` is the branch for hands-on administrative specialists
- `management-trainee` is the branch for senior, mobile, or mostly useless roles

This keeps the system readable and gives the player only two main training bases to understand.

## Surface Rule

Current implementation uses a hybrid workforce rule:

- taxpayer-funded recruitment and selected seed roles stay Nauvis-bound:
  - `job-offer-production`
  - `worker-biter-formation`
  - `management-trainee-formation`
  - `licensed-notary-formation`
- post-seed specialist routing is portable once the player has a Formation Center, the required trainee item, and the relevant prerequisite science:
  - `clerical-trainee-formation`
  - `astronaut-formation`
  - `night-shift-supervisor-formation`
  - `conciliation-officer-formation`
  - `relay-clerk-formation`
  - `cryoprint-technician-formation`
  - `field-negotiator-formation`
  - `middle-management-managing-manager-formation`

This keeps the expensive public hiring loop anchored on Nauvis without making every planet specialist require another Nauvis round trip after the player has already established off-world science and a Formation Center.

## Candidate Shared Training Items

### `clerical-trainee`

This should be the main source for:

- `night-shift-supervisor`
- `licensed-notary`
- `conciliation-officer`
- `relay-clerk`
- `cryoprint-technician`

### `management-trainee`

This should be the main source for:

- `astronaut`
- `field-negotiator`
- `middle-management-managing-manager`

This is a good satirical split: most useful specialists still come from bureaucracy, but the true management branch remains a little ridiculous.

## Profession Set

### `night-shift-supervisor`

This is the strongest candidate for the first profession-backed module.

Best uses:

- `overtime-exemption`
- `space-office`
- one high-tier after-hours paperwork recipe such as `overnight-audit-order`

Why it works:

- it directly explains why a building can stay open overnight
- it ties Space Age staffing into an existing high-value mechanic
- it gives a shared profession that is not locked to one planet

### `licensed-notary`

Home identity:

- Vulcanus

Best uses:

- `Notary Office`
- `industrial-charter`
- `foundry-operating-charter`
- premium notarization recipes

Why it works:

- it reinforces the Notary Office recipe split
- it gives Vulcanus a staff identity, not just a material identity

### `conciliation-officer`

Home identity:

- Gleba

Best uses:

- `Conciliation Desk`
- `Voluntary Egg Reassignment`
- `Voluntary Workforce Reassignment`
- `conciliation-order`

Why it works:

- it connects enemy handling and workforce capture into the same personnel branch
- it gives Gleba a specialist export that matters on Nauvis too

### `relay-clerk`

Home identity:

- Fulgora

Best uses:

- `Digital Services Bureau`
- `digital-processing-certificate`
- `signal-allocation-directive`
- `priority-directive`

Why it works:

- it makes Fulgora's computerized processing feel staffed rather than magical
- it gives Fulgora a profession that matters on every surface

### `cryoprint-technician`

Home identity:

- Aquilo

Best uses:

- `Laser Printer`
- `fax-emitter`
- `Interplanetary Fax Exchange`
- `precision-duplicate-order`
- premium fax reconstruction
- `advanced-chemistry-license`

Why it works:

- it makes Aquilo feel like expertise plus material, not just material
- it protects the `Laser Printer` from being "just a faster printer"

### `astronaut`

Best uses:

- `space-office`
- orbital paperwork
- high-end offworld crew setup

This remains a flagship useful specialist rather than a generic ingredient.

### `field-negotiator`

Best uses:

- negotiator unit or spidertron-equivalent
- selected high-tier promise and eviction work
- later diplomatic or land-claim systems

This should stay a prestige branch, not a first-release dependency.

### `middle-management-managing-manager`

Best uses:

- Manager Catapult (`orbital-employment-cannon`)
- optional late satirical management paperwork

This is still the main infinite sink.

It should not compete with the useful specialists on efficiency. It exists to turn excess recruitment into an absurd orbital budget drain. The Manager Catapult launches managers that attach visibly to an asteroid and deal damage on one-second work cycles. The base staffing allocation is one manager per asteroid; four `orbital-employment-capacity` researches raise that hard cap to five through early space, three-planet, cryogenic, and Promethium science. A catapult pauses or retargets after filling an asteroid's allocation, while an already-airborne excess manager becomes a collectible return chunk rather than disappearing. When the asteroid breaks, every attached manager becomes a distinct collectible chunk alongside the normal salvage. An asteroid collector mines that chunk directly into reusable manager ammunition in its output inventory, ready for belts and inserters; a missed chunk is deterministic permanent loss, with no burnout roll or recovery research.

Quality invariant: `middle-management-managing-manager` must receive no gameplay bonus from item quality. Higher-quality MMMMs must not gain damage, extra sorties, improved recovery, additional salvage, faster work cycles, or any other advantage. Employee chunks deliberately return normal-quality MMMMs, so this downgrade has no mechanical cost. Preserve this invariant when the broader quality system is designed.

## Night Shift Module Review

The user's instinct is good: the night module is a very natural place to spend a specialist biter.

But there is one major progression conflict.

The current `overtime-exemption` is unlocked by `after-hours-operations`, which is part of the normal non-space progression. If the only recipe for that module suddenly requires a Space Age profession, early games with Space Age enabled could lose their intended night-shift solution before professions are available.

Because of that, there are three viable approaches.

### Option A: Replace The Recipe Entirely

New recipe:

- `productivity-module`
- `night-shift-supervisor`
- `government-grant`
- `regulation`
- coffee and circuits

Pros:

- the module becomes genuinely staffed
- the joke lands immediately

Cons:

- likely breaks the current early progression unless workforce training is also moved earlier

Recommendation:

- not preferred unless the tech tree is deliberately restructured

### Option B: Add A Space Age Alternate Recipe For The Same Item

Keep the current recipe.

Add a second late recipe that uses `night-shift-supervisor` and is more efficient or higher-yield.

Pros:

- no progression break
- Space Age still upgrades the module fantasy
- minimal runtime change because the item name stays `overtime-exemption`

Cons:

- weaker thematic punch than a full replacement

Recommendation:

- safest option

### Option C: Add A New Upgraded Night Module

Add a second item, for example:

- `overtime-exemption-licensed`

That item would require `night-shift-supervisor` and provide a stronger version of after-hours staffing.

Possible bonus ideas:

- reduced extra coffee or budget cost in recipes that run overnight
- slight night-speed bonus
- immunity to one minor night penalty

Pros:

- strongest gameplay differentiation
- gives professions a visible upgrade path

Cons:

- requires runtime changes because [working_hours.lua](~/Library/Application Support/factorio/mods/administratorio/scripts/working_hours.lua) currently only recognizes `overtime-exemption`

Recommendation:

- best long-term option
- not the first implementation

## Strong Recommendation For Night Shift

The best current answer is:

- keep the existing `overtime-exemption`
- add `night-shift-supervisor`
- add a Space Age alternate recipe for `overtime-exemption` that consumes one `night-shift-supervisor`

That gives the profession a real job without breaking the existing working-hours progression.

Later, if the runtime is expanded, that can graduate into a distinct upgraded module item.

## Other Strong Profession Hooks

Besides the night module, the best profession-backed content is:

- `licensed-notary` in `Notary Office`, `Territorial Arbitration Post`, and high-tier Vulcanus certification
- `relay-clerk` in `Digital Services Bureau` and Fulgora digital paperwork
- `conciliation-officer` in `Conciliation Desk` and reassignment loops
- `cryoprint-technician` in `Laser Printer`, `fax-emitter`, `Interplanetary Fax Exchange`, and premium duplicate work

These are better hooks than scattering specialists across random paperwork recipes, because they attach personnel directly to the most important new buildings.

## Tier-3 Module Rule

Tier-3 vanilla modules are a strong candidate for a generic biter-derived staffing requirement.

Recommended rule:

- when Space Age progression moves tier-3 modules behind first-planet progression, each tier-3 module recipe should also consume one `management-trainee`

Target recipes:

- `speed-module-3`
- `productivity-module-3`
- `efficiency-module-3`

Why `management-trainee` is the best fit:

- it is still clearly "a biter" in economic terms
- it avoids inventing three one-use specialist professions just for module recipes
- tier-3 modules already represent embedded organizational control, so a management body inside the recipe reads well
- it gives the player another repeatable, high-volume sink for recruited workforce without competing directly with `MMMM`

This should be a generic rule, not three different specialist locks.

Recommended recipe shape:

- keep the current flavor-specific paperwork:
  - `narrative` for `speed-module-3`
  - `justification` for `productivity-module-3`
  - `policy` for `efficiency-module-3`
- add one shared staffing ingredient:
  - `management-trainee`

This preserves the identity of the three module families while giving them a consistent Space Age workforce cost.

Why not `enrolled-biter` directly:

- `enrolled-biter` is too raw and should usually pass through at least one training step
- `management-trainee` is reusable elsewhere and keeps the professions tree coherent

Why not a specialist profession:

- modules are repeatable mass-production recipes
- consuming `licensed-notary` or `relay-clerk` directly in bulk would make those professions feel too narrow and too disposable

## Recommended Module Split

The clean profession/module split is:

- `overtime-exemption` uses `night-shift-supervisor`
- tier-3 vanilla modules use `management-trainee`

That creates two different workforce stories:

- night staffing uses a dedicated supervisory specialist
- high-end general-purpose modules use generic trained middle administration

## Things To Avoid

- too many ultra-specific one-use professions
- consuming a unique specialist in only one building recipe
- making every printed form require a person item
- replacing the main management sink with too many useful branches

The system needs some dead-end absurdity. That is what `MMMM` is for.

## Suggested First Profession Bundle

If professions are introduced in one pass, the cleanest first set is:

- `clerical-trainee`
- `management-trainee`
- `night-shift-supervisor`
- `licensed-notary`
- `conciliation-officer`
- `relay-clerk`
- `cryoprint-technician`
- `field-negotiator`
- `middle-management-managing-manager`

That set covers:

- the current module hook
- the tier-3 module sink
- all currently implemented Space Age planet specialists
- current negotiation and space staffing hooks
- the management sink

## Open Questions

1. Should `night-shift-supervisor` be trainable entirely on Nauvis, or should it require one offworld input?
2. Should `clerical-trainee` and `management-trainee` be separate items, or should one shared trainee branch split later?
3. Should tier-3 modules consume `management-trainee` directly, or use a Space Age alternate recipe for the same module items?
4. How many recipes should directly consume professions, versus consuming only the building that was built with them?
5. Which profession should be the first to appear in icons and locale, so naming tone is locked early?
