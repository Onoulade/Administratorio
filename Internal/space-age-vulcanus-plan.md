# Vulcanus Space Age Plan

This file details the Vulcanus paperwork loop under the shared rules in [space-age-compatibility-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-compatibility-plan.md).

## Planet Role

Vulcanus is the certification planet.

Its themes are:

- durable paperwork
- industrial approval
- land claims, zoning, and expropriation
- productive non-printed bureaucracy

Its global reward is the `Notary Office`.

## Locked Outputs

- Raw resource: `verdigris-crust`
- Planet ink: `cyan-ink`
- Upgraded building: `Notary Office`
- Shared intermediates:
  - `heatproof-form-stock`
  - `embossed-seal`
  - `permit-draft`
  - `inspection-docket`
- Core paperwork family:
  - `industrial-charter`
  - `zoning-variance`
  - `lava-safety-endorsement`
  - `expropriation-dossier`
  - `foundry-operating-charter`

## First-Visit Accessibility

Vulcanus must work as a first basic planet.

That means:

- no Gleba or Fulgora resource is required to start
- black ink from Nauvis helps, but is not required for the local core loop
- the first self-sufficient Vulcanus permit loop should not require raw `taxpayer-money`
- the player should be able to arrive with only `Chromatic Printer`, paper, and a small Nauvis admin seed kit

The intended bootstrap is:

1. mine or collect `verdigris-crust`
2. convert it into `cyan-pigment`
3. print `cyan-ink`
4. make `heatproof-form-stock`
5. rebuild the Vulcanus permit tree locally

## Paperwork Tree

### Stage 1: Pigment And Certification Material

- `verdigris-crust -> cyan-pigment`
- `cyan-pigment + sulfuric-acid -> cyan-ink`
- `cyan-pigment + useless-documentation -> embossed-seal`

`cyan-pigment` is not allowed to be a dead-end. It must feed at least:

- `cyan-ink`
- `embossed-seal`
- one low-tier recycle or recovery recipe

### Stage 2: Local Stock

- `paper + cyan-ink + sulfuric-acid -> heatproof-form-stock`

`heatproof-form-stock` is the local substitute for black-heavy permit paper.

It must feed at least:

- `permit-draft`
- `inspection-docket`
- `industrial-charter`
- `zoning-variance`

### Stage 3: Shared Draft Layer

- `heatproof-form-stock + cyan-ink -> permit-draft`
- `heatproof-form-stock + dubious-data + cyan-ink -> inspection-docket`

`permit-draft` is the reusable permit shell. It must feed at least:

- `industrial-charter`
- `zoning-variance`
- `foundry-operating-charter`

`inspection-docket` is the reusable industrial review shell. It must feed at least:

- `industrial-charter`
- `lava-safety-endorsement`
- `foundry-operating-charter`

### Stage 4: Final Vulcanus Paperwork

- `permit-draft + inspection-docket + embossed-seal -> industrial-charter`
- `permit-draft + construction-permit + embossed-seal -> zoning-variance`
- `inspection-docket + basic-excuse + cyan-ink -> lava-safety-endorsement`
- `industrial-charter + zoning-variance + government-grant -> expropriation-dossier`
- `industrial-charter + lava-safety-endorsement + government-grant -> foundry-operating-charter`

This keeps the tree readable:

- one local stock item
- two reusable draft layers
- one seal intermediate
- a small family of high-value certified outputs
- raw `taxpayer-money` only returning at the higher sovereignty layer through `government-grant`

## Notary Office

### Identity

The `Notary Office` is the reward for solving Vulcanus.

It should be the best machine for:

- `embossed-seal`
- `industrial-charter`
- `foundry-operating-charter`
- grants, bonds, personnel packets, and other non-printed official work

It should not be the best machine for:

- `heatproof-form-stock`
- `permit-draft`
- any explicit printing or copy step

### Recipe Split

The intended split is:

- `Chromatic Printer` handles cyan print steps and stock creation
- `Notary Office` handles certification, sealing, notarization, and dense office intermediates

If the same final item is craftable efficiently in both places, the split has failed.

## Global Export Value

Vulcanus should export value in several directions:

- `embossed-seal` for high-tier certified paperwork everywhere
- `industrial-charter` as a build-time permit ingredient
- `foundry-operating-charter` for `foundry`
- `Notary Office` as the premium productivity office for non-printed admin chains

Late cross-planet uses should include at least:

- one orbital construction packet
- one mixed-planet development permit
- one Aquilo license dossier pre-step

## Demolisher Interaction

Demolisher diplomacy is intentionally not part of the bootstrap loop.

The clean direction is:

- `expropriation-dossier` becomes the premium input for a future throughput-based land-claim system
- that system can be added later without changing the core Vulcanus paperwork tree

This keeps first-visit Vulcanus readable and prevents the whole planet from depending on a single runtime gimmick.

## Multi-Use Audit

Every notable Vulcanus intermediate already has at least three real uses:

- `cyan-pigment`: `cyan-ink`, `embossed-seal`, recycle or recovery route
- `heatproof-form-stock`: `permit-draft`, `inspection-docket`, `industrial-charter`, `zoning-variance`
- `permit-draft`: `industrial-charter`, `zoning-variance`, `foundry-operating-charter`
- `inspection-docket`: `industrial-charter`, `lava-safety-endorsement`, `foundry-operating-charter`
- `embossed-seal`: `zoning-variance`, `expropriation-dossier`, `foundry-operating-charter`, late cross-planet dossiers

## Balance Notes

- Vulcanus must not require another basic planet to become locally self-sufficient.
- raw `taxpayer-money` should matter mainly for offworld grants and late sovereign paperwork, not the local first loop
- `Notary Office` productivity should feel significant on expensive paperwork, not universal on every office recipe.
- `embossed-seal` should be premium enough that the player does not spam it into trivial items.
- `foundry-operating-charter` should be a meaningful build-time cost, not a recurring production tax.

## Open Questions

1. Should `cyan-pigment` be an item or fluid-adjacent slurry?
2. Should `inspection-docket` come from printing, notarization, or a mixed two-step chain?
3. How expensive should `expropriation-dossier` be before demolisher diplomacy feels earned rather than tedious?
