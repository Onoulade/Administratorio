# Space Age Public Finance Plan

This file drafts the preferred taxpayer-money economy for Space Age Administratorio.

It builds on the current base-game chain:

- `taxpayer-money`
- `treasury-bond`
- `government-grant`
- `slush-fund`
- `tax-audit`

The key change is that Space Age should split public finance into two connected spheres:

- sovereign cash on Nauvis
- offworld capital and redemption paperwork across the stars

## Core Direction

### Raw Cash Should Stay Mostly On Nauvis

`taxpayer-money` should remain the sovereign local currency of Nauvis.

That means:

- most recipes outside Nauvis should not consume raw `taxpayer-money`
- players should not be encouraged to fill platforms with stacks of cash
- if raw money can travel at all, it should travel poorly and in small quantity

Preferred soft restriction:

- raw `taxpayer-money` is technically movable because Factorio items are items
- but almost no offworld recipe accepts it directly
- the only practical export form is a compact but intentionally inefficient `money-case`

This is much easier to implement than trying to hard-ban a specific item from space logistics.

### Space Travel Should Be Prepaid

Going to space should cost money, but the payment should happen mostly at the point of authorization, not as loose cash spent everywhere later.

Preferred rule:

- the trip is funded on Nauvis
- the offworld mission consumes funding paperwork
- the destination mostly runs on local paperwork plus imported capital documents

This preserves the feeling that space is expensive without making every alien printer eat cash.

### Local Planet Loops Should Be Cash-Light

The basic rule for Vulcanus, Gleba, and Fulgora should be:

- first self-sufficient local paperwork routes should avoid raw `taxpayer-money`
- local chromatic ink and local resource should replace raw cash in those specific planet families
- higher-sovereignty, offworld, or build-time permits can still reintroduce `government-grant` or similar financial paperwork

This matches the Space Age pattern where planets are different, not simply poorer or richer.

### Exploration Should Create Redeemable Wealth

Late Space Age should not rely on complaint farming alone for money.

The big money engine should be:

- bring back offworld goods
- document them correctly
- redeem them on Nauvis into `taxpayer-money`, `treasury-bond`, or `government-grant`

That gives space exploration a direct treasury payoff.

## Preferred Shared Finance Set

The smallest useful new shared set is:

- `money-case`
- `offworld-allocation`
- `cargo-manifest`
- `customs-appraisal`

These four items are enough to connect travel cost, offworld logistics, and imported wealth without creating an entire second economy tree.

## Existing Chain Reuse

The current base chain should remain valid:

1. complaints create `taxpayer-money`
2. `taxpayer-money -> treasury-bond`
3. `treasury-bond -> government-grant`
4. `treasury-bond -> slush-fund`
5. `slush-fund + paperwork -> taxpayer-money` through `tax-audit`

Space Age should not replace this chain. It should extend it.

Recommended extension:

6. `government-grant -> offworld-allocation`
7. offworld expeditions and imports -> `cargo-manifest`
8. returned imports + manifests -> `customs-appraisal`
9. `customs-appraisal -> taxpayer-money / treasury-bond / government-grant`

## Candidate Shared Items

### `money-case`

Role:

- a tiny amount of portable petty cash
- emergency bootstrap finance, not real capital transport

Why it exists:

- the user can send "some money" into space
- raw `taxpayer-money` stays impractical as normal cargo

Suggested uses:

- bootstrap a new offworld office
- emergency diplomatic payments or bribes
- small portable expense line in specialty travel recipes

Suggested rule:

- deliberately poor value density
- useful for edge cases, not for megabase funding

### `offworld-allocation`

Role:

- the main space-capital instrument
- a dedicated public budget line for offworld bureaucracy

Suggested inputs:

- `government-grant`
- management-grade approval or written authorization
- one existing planning or work-order item

Suggested uses:

- first platform departures
- `space-office`
- `Fax Sender`
- `Interplanetary Fax Exchange`
- platform reactor operating budget
- `trajectory-compliance-array`
- late offworld buildings or upgrades

This is the main item that makes "going to space costs a lot" readable in gameplay.

### `cargo-manifest`

Role:

- the documented proof that cargo was sent or returned under public authority

Suggested uses:

- high-tier space departures
- customs redemption on Nauvis
- selected import or export control recipes
- maybe queue or routing priority for high-value freight

This keeps trade bureaucratic instead of magical.

### `customs-appraisal`

Role:

- the Nauvis-side monetization document

Suggested inputs:

- imported goods
- `cargo-manifest`
- data or credentials
- matching planet paperwork where appropriate

Suggested uses:

- redeem to `taxpayer-money`
- redeem to `treasury-bond`
- justify a `government-grant`

This is the core answer to "how does space exploration actually make money?"

## Travel Economy

The clean model is:

1. Nauvis creates `offworld-allocation`.
2. The player spends it on travel authorization and offworld setup.
3. A small `money-case` can be carried for bootstrap or edge cases.
4. Local planetary bureaucracy then runs mainly on local inks, local resources, and local paperwork.

This means:

- space is expensive to enter
- offworld infrastructure is capital-intensive
- the player is not expected to continuously feed raw cash into every remote printer

## Platform Power Budget

The best reactor-money version is:

- platform reactors consume a compact finance document, not raw `taxpayer-money`
- the preferred recurring fuel is `offworld-allocation`
- `money-case` remains an emergency bootstrap item, not the main fuel

Why `offworld-allocation` is the best fit:

- it already has several other offworld uses
- it does not create a single-use finance intermediate
- it reads as budget authorization rather than literal cash being burned in a furnace

Design intent:

- major platform power should feel publicly funded
- space travel should stay expensive even after the first launch
- the player should solve this with treasury throughput on Nauvis, not by stuffing raw cash into every recipe

Technical note:

- if the chosen platform reactor implementation can consume an item fuel directly, `offworld-allocation` should be the item it burns
- if direct fuel burning is not viable on the final reactor prototype, the fallback is to consume `offworld-allocation` through a scripted operating-budget or maintenance-permit layer
- avoid introducing a reactor-only finance item unless it also has several other uses

## Where Money Should Matter

### Nauvis

Nauvis should remain the main place where raw `taxpayer-money` matters.

It should remain central to:

- early public finance
- bond and grant issuance
- audits and treasury expansion
- final redemption of offworld value

### Vulcanus

Vulcanus local paperwork should mostly avoid raw cash in its first loop.

Raw money should return only at the high-sovereignty layer through:

- `government-grant`
- `offworld-allocation`
- land and expropriation documents

This makes the planet feel industrial rather than cash-fed.

### Gleba

Gleba should be the most cash-light of the four planets.

Its local loops should mainly consume:

- `yellow-ink`
- `spore-resin`
- personnel or conciliation paperwork

The financial value of Gleba comes back later through:

- eggs
- bioscience
- workforce conversion
- grant justification

### Fulgora

Fulgora local loops should also be mostly cash-light.

Its local value is:

- restored archives
- transmission permits
- relay control
- salvageable documents and components

This should monetize on Nauvis as import value and policy leverage rather than raw local cash printing.

### Aquilo

Aquilo should consume premium media and imported CMY, not raw cash.

Its value is in:

- speed
- mixed-planet paperwork throughput
- high-grade late documents
- advanced chemistry authorization

That value should feed back into Nauvis through customs and central treasury conversion.

## Redemption Loop

The recommended late money loop is:

1. Offworld planet produces valuable goods or claimable materials.
2. Those goods are paired with the right paperwork into `cargo-manifest`.
3. Returned cargo is processed on Nauvis into `customs-appraisal`.
4. `customs-appraisal` is redeemed into money-tier outputs.

Recommended redemption targets:

- bulk or routine imports -> `taxpayer-money`
- industrial or durable imports -> `treasury-bond`
- strategic or scientific imports -> `government-grant`

This gives the player a clear reason to bring things home instead of only producing locally forever.

## Planet-Specific Monetization Flavor

These should be distinct without becoming four separate finance trees.

### Vulcanus

Best import stories:

- mineral rights
- foundry outputs
- industrial charters
- land and extraction packets

Best redemption tendency:

- `treasury-bond`

### Gleba

Best import stories:

- eggs
- biospecimens
- growth media
- trained workforce conversions

Best redemption tendency:

- `government-grant`

### Fulgora

Best import stories:

- archives
- salvage
- transmission hardware
- recovered directives

Best redemption tendency:

- `taxpayer-money` and `treasury-bond`

### Aquilo

Best import stories:

- cryogenic media
- precision duplicates
- advanced chemistry authorizations
- high-grade transfer goods

Best redemption tendency:

- `government-grant` and late `offworld-allocation`

## Design Benefits

This model solves several problems at once.

- Money matters to space travel.
- Raw `taxpayer-money` does not have to become the universal ingredient on every planet.
- Offworld exploration can outscale complaint payouts in the late game.
- Colored local paperwork can feel like a true local substitute instead of just a recolor tax.
- The fax network becomes more valuable because expensive finished forms and finance paperwork are better transmitted than physically moved.

## Technical Fit

This design is technically friendly because it does not require hard inventory bans.

The mod only needs to ensure:

- offworld recipes mostly ask for derivative finance items, not raw cash
- redemption recipes live on Nauvis
- local first-planet paperwork families have cash-light or cashless routes

The player can still technically launch raw money if they insist, but the design makes that a bad idea.

## Current Strong Recommendation

The strongest version is:

- keep raw `taxpayer-money` mainly on Nauvis
- add `money-case` as a small portable exception
- add `offworld-allocation` as the main travel and infrastructure finance item
- add `cargo-manifest` and `customs-appraisal` as the import-redemption loop
- keep local planet paperwork mostly free of raw `taxpayer-money` during their first self-sufficient stage

That is the cleanest way to make money central to interstellar bureaucracy without turning every remote recipe into cash spam.

## Open Questions

1. Should `money-case` be a real item, or is it enough to keep raw `taxpayer-money` movable but useless offworld?
2. Should `offworld-allocation` be crafted from `government-grant` only, or also require `management-approval-written` or `management-written-work-order`?
3. Should `customs-appraisal` redeem directly into three different outputs, or should the player choose one specialization path?
4. How early should import redemption begin: immediately after first planet return, or only once the fax and space-office layers exist?
5. Which existing Nauvis buildings should own the new finance recipes: `meeting-room`, `union-headquarters`, `office-desk`, or a new treasury-specific office?
