# Gleba Space Age Plan

This file details the Gleba paperwork and enemy loop under the shared rules in [space-age-compatibility-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-compatibility-plan.md).

## Planet Role

Gleba is the organic conciliation planet.

Its themes are:

- luring nuisances instead of waiting for them
- biosafety and calming paperwork
- satirical "reassignment" of hostile creatures into eggs or workforce
- simplifying selected bureaucracy through biological shortcuts

Its global reward is the `Conciliation Desk`.

## Locked Outputs

- Raw resource: `spore-resin`
- Planet ink: `yellow-ink`
- Upgraded building: `Conciliation Desk`
- Shared intermediates:
  - `conciliation-spores`
  - `mycelial-form-stock`
  - `symbiosis-record`
- Core paperwork family:
  - `conciliation-order`
  - `biosafety-waiver`
  - `personnel-dossier`
  - `calming-writ`
  - `biochamber-operating-waiver`

## First-Visit Accessibility

Gleba must work as a first basic planet.

That means:

- no Vulcanus or Fulgora resource is required to start
- local paperwork must be reconstructable without coal-derived black ink
- the first self-sufficient Gleba loop should not require raw `taxpayer-money`
- the enemy answer must exist entirely inside the Gleba loop once the player has `Chromatic Printer`

The intended bootstrap is:

1. gather `spore-resin`
2. convert it into `yellow-pigment`
3. make `yellow-ink`
4. produce `mycelial-form-stock`
5. print the first Gleba calming and biosafety paperwork
6. feed a `Conciliation Desk`

## Paperwork Tree

### Stage 1: Pigment And Spores

- `spore-resin -> yellow-pigment`
- `yellow-pigment + nutrients -> yellow-ink`
- `yellow-pigment + nutrients -> conciliation-spores`

`yellow-pigment` must feed at least:

- `yellow-ink`
- `conciliation-spores`
- one low-tier recovery or recycling route

### Stage 2: Local Stock

- `paper + yellow-ink + nutrients -> mycelial-form-stock`

`mycelial-form-stock` is the local substitute for black-heavy personnel and conciliation paper.

It must feed at least:

- `conciliation-order`
- `biosafety-waiver`
- `personnel-dossier`
- `calming-writ`

### Stage 3: Core Gleba Paperwork

- `mycelial-form-stock + bureaucratic-promise + yellow-ink -> conciliation-order`
- `mycelial-form-stock + basic-excuse + spore-resin -> biosafety-waiver`
- `mycelial-form-stock + credentials + yellow-ink -> personnel-dossier`
- `mycelial-form-stock + watercooler-gossip + yellow-ink -> calming-writ`
- `biosafety-waiver + conciliation-order + yellow-ink -> biochamber-operating-waiver`

The local family stays intentionally compact:

- one stock item
- one lure consumable
- one satirical byproduct
- a small set of paperwork that all matters on and off planet

## Conciliation Desk

### Identity

The `Conciliation Desk` is not a regular complaint desk.

It is:

- one slot
- one occupant at a time
- low throughput
- extremely high leverage

### Gleba Enemy Loop

Pentapods should not behave like Nauvis biters.

The intended loop is:

1. pentapods wander toward attractive organic infrastructure
2. if ignored, they damage buildings directly
3. a loaded `Conciliation Desk` claims one nearby target
4. the target moves to the desk
5. the desk processes it through `Voluntary Egg Reassignment`
6. the outputs are `pentapod-egg` and `symbiosis-record`

Recommended recipe shape:

- occupant pentapod
- `conciliation-spores`
- `conciliation-order`
- optional `biosafety-waiver` for bigger or nastier targets

Outputs:

- `pentapod-egg`
- `symbiosis-record`

### Rotten Eggs

Rotten eggs should still create feral threats.

The intended response is:

- `conciliation-spores` or `calming-writ` can calm them
- a calmed feral can either despawn naturally or be lured into a free desk
- successful desk processing should still yield eggs, so getting rid of the threat remains materially useful

### Nauvis Export Loop

The same desk family should export back to Nauvis.

Preferred offworld recipe:

- `Voluntary Workforce Reassignment`

Inputs:

- occupant biter or spitter
- `conciliation-spores`
- `personnel-dossier`

Outputs:

- `enrolled-biter`
- optional small chance or side output of `symbiosis-record`

This makes Gleba the premium shortcut for recruitment without deleting the original complaint loop.

## Symbiosis Record Uses

`symbiosis-record` must stay multi-use. It should feed at least:

- upgraded promise or pacification paperwork
- specialist deployment paperwork
- one limited one-step complaint simplification recipe

That last recipe should stay deliberately narrow so the desk does not replace the normal factory-scale resolution chain.

## Global Export Value

Gleba exports should matter everywhere:

- `conciliation-spores` let the player lure targets instead of waiting for them
- `personnel-dossier` supports workforce conversion and specialist training
- `biochamber-operating-waiver` is the build-time permit for `biochamber`
- `Conciliation Desk` is a premium one-slot shortcut building on any surface

## Multi-Use Audit

- `yellow-pigment`: `yellow-ink`, `conciliation-spores`, recovery route
- `mycelial-form-stock`: `conciliation-order`, `biosafety-waiver`, `personnel-dossier`, `calming-writ`
- `conciliation-spores`: Gleba luring, feral calming, Nauvis workforce recruitment, optional pacification paperwork
- `symbiosis-record`: promise upgrades, deployment paperwork, limited simplification recipe

## Balance Notes

- The `Conciliation Desk` must stay one-slot and slow.
- Gleba core paperwork should stay essentially cashless once the local yellow loop is running.
- Gleba should give a powerful shortcut, not infinite free eggs or free recruited workforce.
- `Voluntary Workforce Reassignment` should be strong enough to justify importing spores to Nauvis, but weaker in bulk than solving the normal complaint economy well.
- Rotten eggs must remain dangerous enough that the player still cares about containment.

## Open Questions

1. Should `conciliation-spores` be consumed only when a target is claimed, or continuously while the desk is broadcasting?
2. Which Nauvis targets should be valid for `Voluntary Workforce Reassignment`: wild biters, protesters, spitters, or all of them?
3. Should `biochamber-operating-waiver` also gate one or two advanced Gleba recipes, or only the building itself?
