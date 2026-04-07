# Aquilo Space Age Plan

This file details the Aquilo paperwork and high-speed print loop under the shared rules in [space-age-compatibility-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-compatibility-plan.md).

## Planet Role

Aquilo is the transfer-media and print-speed planet.

Its themes are:

- cryogenic handling
- transfer printing instead of wet ink
- extremely fast reproduction of paperwork
- mixed-planet documents becoming worth faxing instead of shipping

Its global reward is the `Laser Printer`.

## Locked Outputs

- Raw resource: `cryo-phosphor`
- No new ink color
- Upgraded building: `Laser Printer`
- Shared intermediates:
  - `transfer-emulsion`
  - `thermal-transfer-sheet`
  - `composite-chroma-ribbon`
  - `cryo-form-stock`
- Core paperwork family:
  - `polar-routing-sheet`
  - `thermal-clearance`
  - `cryogenic-operations-license`
  - `precision-duplicate-order`
  - `advanced-chemistry-license`

## Access Assumption

Aquilo is not a first basic planet.

Because of that, Aquilo is allowed to assume:

- the player already has `Chromatic Printer`
- imported `cyan-ink`, `yellow-ink`, and `magenta-ink` exist somewhere in the interplanetary network
- faxing foreign forms is now a real strategic option

Aquilo should still have one local raw resource and one local building reward, but it is intentionally the first place where mixed-planet paperwork becomes normal instead of optional.

## Paperwork Tree

### Stage 1: Transfer Medium

- `cryo-phosphor -> transfer-emulsion`
- `transfer-emulsion + paper + plastic-bar -> thermal-transfer-sheet`
- `transfer-emulsion + cyan-ink + yellow-ink + magenta-ink -> composite-chroma-ribbon`

`transfer-emulsion` must feed at least:

- `thermal-transfer-sheet`
- `composite-chroma-ribbon`
- one cryogenic maintenance or recovery route

### Stage 2: Local Stock

- `thermal-transfer-sheet + composite-chroma-ribbon -> cryo-form-stock`

`thermal-transfer-sheet` must feed at least:

- `cryo-form-stock`
- `Laser Printer`
- fax reconstruction on Aquilo
- high-speed reprint or copy jobs

`composite-chroma-ribbon` must feed at least:

- `cryo-form-stock`
- `polar-routing-sheet`
- `precision-duplicate-order`
- premium fax reconstruction

### Stage 3: Final Aquilo Paperwork

- `cryo-form-stock + magenta-ink + signal-toner -> polar-routing-sheet`
- `cryo-form-stock + yellow-ink + biosafety-waiver -> thermal-clearance`
- `cryo-form-stock + cyan-ink + industrial-charter -> cryogenic-operations-license`
- `thermal-transfer-sheet + composite-chroma-ribbon + polar-routing-sheet -> precision-duplicate-order`
- `cryogenic-operations-license + thermal-clearance + composite-chroma-ribbon -> advanced-chemistry-license`

The intended shape is deliberate:

- Aquilo does not invent a fourth color
- it turns imported CMY into a stable high-speed print medium
- it is the first planet where mixed-planet paperwork should feel efficient rather than awkward

## Laser Printer

### Identity

The `Laser Printer` is the speed reward.

It should be the best machine for:

- explicit print steps
- copies and reprints
- blank form throughput
- fax reconstruction throughput

It should not be the best machine for:

- grants
- bonds
- permits that are fundamentally certification work
- personnel and management paperwork
- anything better suited to the `Notary Office`

### Recipe Split

The intended global split is:

- `Notary Office` prepares dense non-printed authorizations and certified office packets
- `Laser Printer` performs the final fast print or copy step

That means a late Aquilo document can intentionally be two-step:

1. a certified dossier or permit packet prepared elsewhere
2. the final fast transfer print on Aquilo

## Why Aquilo Makes Faxing Much Better

Before Aquilo, faxing is mostly an urgency tool.

Once Aquilo exists:

- foreign permits are more common in final recipes
- the local printer is extremely fast
- the local medium no longer relies on ordinary wet ink at point of print

This means the best workflow often becomes:

1. make the paperwork on its home planet
2. fax it to Aquilo
3. reconstruct it at speed
4. use it immediately in late recipes

That is exactly the behavior the design should encourage.

## Global Export Value

Aquilo exports should matter everywhere:

- `Laser Printer` as the best local high-speed paperwork printer
- `thermal-transfer-sheet` for premium fax or reprint chains
- `composite-chroma-ribbon` for mixed-planet late documents
- `advanced-chemistry-license` as the build-time permit for `advanced chemical plant`

## Multi-Use Audit

- `transfer-emulsion`: `thermal-transfer-sheet`, `composite-chroma-ribbon`, maintenance route
- `thermal-transfer-sheet`: `cryo-form-stock`, `Laser Printer`, premium fax reconstruction, reprints
- `composite-chroma-ribbon`: `cryo-form-stock`, `polar-routing-sheet`, `precision-duplicate-order`, premium fax reconstruction
- `cryo-form-stock`: `polar-routing-sheet`, `thermal-clearance`, `cryogenic-operations-license`

## Balance Notes

- Aquilo can intentionally depend on earlier planets because it is not part of the any-order basic trio.
- The `Laser Printer` must be much faster than other printers, but it must not steal the Notary Office's recipe space.
- `thermal-transfer-sheet` should be common enough that the player actually uses the machine, while `composite-chroma-ribbon` should stay premium enough to preserve the value of imported CMY.
- `advanced-chemistry-license` should be meaningful for `advanced chemical plant`, but still one-time or build-time only.

## Open Questions

1. Should `composite-chroma-ribbon` require all three CMY inks in equal amounts, or should premium variants skew toward one color family?
2. How much faster should fax reconstruction be on `Laser Printer` than on `Chromatic Printer`?
3. Should `precision-duplicate-order` become a general late-game copy accelerator, or stay mostly in the Aquilo paperwork family?
