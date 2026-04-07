# Fulgora Space Age Plan

This file details the Fulgora paperwork and fax loop under the shared rules in [space-age-compatibility-plan.md](~/Library/Application Support/factorio/mods/administratorio/Internal/space-age-compatibility-plan.md).

## Planet Role

Fulgora is the transmission and archive planet.

Its themes are:

- ruined records and recoverable templates
- relay paperwork
- magenta routing without local black-ink dependence
- interplanetary urgency rather than interplanetary bulk

Its global reward is the `Interplanetary Fax Exchange`.

## Locked Outputs

- Raw resource: `static-dust`
- Planet ink: `magenta-ink`
- Upgraded building: `Interplanetary Fax Exchange`
- Shared intermediates:
  - `charged-toner`
  - `signal-toner`
  - `signal-form-stock`
  - `directive-sheet`
- Core paperwork family:
  - `transmission-warrant`
  - `archive-recovery-permit`
  - `priority-directive`
  - `relay-order`
  - `signal-allocation-directive`

## First-Visit Accessibility

Fulgora must work as a first basic planet.

That means:

- no Vulcanus or Gleba resource is required to start
- its core paperwork family cannot rely on local black ink
- the first self-sufficient Fulgora loop should not require raw `taxpayer-money`
- the first usable fax loop must work with only Nauvis plus Fulgora infrastructure

The intended bootstrap is:

1. collect `static-dust`
2. refine it into `charged-toner`
3. produce `magenta-ink`
4. produce `signal-form-stock`
5. rebuild relay and archive paperwork locally
6. unlock the first destination-side fax receiver

## Paperwork Tree

### Stage 1: Toner

- `static-dust -> charged-toner`
- `charged-toner + electrolyte -> magenta-ink`
- `charged-toner + electronic-circuit -> signal-toner`

`charged-toner` must feed at least:

- `magenta-ink`
- `signal-toner`
- one archive-recovery or maintenance route

### Stage 2: Local Stock

- `paper + magenta-ink + electronic-circuit -> signal-form-stock`
- `signal-form-stock + data + magenta-ink -> directive-sheet`

`signal-form-stock` must feed at least:

- `directive-sheet`
- `archive-recovery-permit`
- `transmission-warrant`

`directive-sheet` must feed at least:

- `priority-directive`
- `relay-order`
- `signal-allocation-directive`

### Stage 3: Final Fulgora Paperwork

- `signal-form-stock + data + magenta-ink -> transmission-warrant`
- `signal-form-stock + useless-documentation + signal-toner -> archive-recovery-permit`
- `directive-sheet + signal-toner + blank-directive -> priority-directive`
- `directive-sheet + credentials + magenta-ink -> relay-order`
- `priority-directive + relay-order + signal-toner -> signal-allocation-directive`

This gives Fulgora:

- one stock item
- one directive shell
- one premium signal intermediate
- a compact family of relay and archive outputs

## Interplanetary Fax Exchange

### Identity

The `Interplanetary Fax Exchange` is a queue owner and routing hub, not a generic assembler.

Its rules are:

- one receiver per destination surface
- many senders per source surface
- many local printers attached to the receiver

### Functional Model

The intended job flow is:

1. a `Fax Sender` consumes the source form
2. the sender targets one planet or one spaceship
3. the destination `Interplanetary Fax Exchange` receives a queued request
4. connected local printers claim compatible jobs
5. the claiming printer consumes local paper or transfer media plus the required chromatic inputs
6. the form is reconstructed locally

### Why Fulgora Still Matters After The Network Exists

Fulgora should remain important because it provides:

- the receiver building itself
- the sender building chain
- `relay-order` and `priority-directive` for higher-tier routing
- `signal-toner` for fast or premium signal work

The network should be useful before Aquilo, but it should become truly central once Aquilo starts demanding mixed-planet paperwork at speed.

## Archive Recovery Loop

Fulgora should also have a non-enemy item loop.

Suggested salvage inputs:

- `damaged-archive`
- `burned-ledger`
- `partial-form`

Suggested recovery path:

- salvage item + `archive-recovery-permit` + `signal-toner`

Suggested outputs:

- low-tier forms
- template fragments
- rebuilt directives
- recoverable paperwork ingredients

This keeps Fulgora productive even when the player is not actively faxing.

## Global Export Value

Fulgora exports should matter everywhere:

- urgent remote paperwork routing
- relay paperwork for late mixed-planet recipes
- archive recovery for lost or damaged forms
- `signal-allocation-directive` as the build-time permit for `electromagnetic assembler`

## Multi-Use Audit

- `charged-toner`: `magenta-ink`, `signal-toner`, archive recovery
- `signal-toner`: archive recovery, `priority-directive`, `signal-allocation-directive`, optional premium relay work
- `signal-form-stock`: `directive-sheet`, `archive-recovery-permit`, `transmission-warrant`
- `directive-sheet`: `priority-directive`, `relay-order`, `signal-allocation-directive`

## Balance Notes

- Faxing should never replace ships for buildings, fluids, or bulk cargo.
- Fulgora core paperwork should remain mostly cashless once magenta routes are running locally.
- The receiver should not be the throughput bottleneck by itself; connected printers should still matter.
- `signal-allocation-directive` should feel like a meaningful build-time document for `electromagnetic assembler`, not a recurring annoyance.
- Archive recovery should be useful but not so random that it skips the main paperwork progression.

## Open Questions

1. Should a sender pick a destination through UI, circuit, or both?
2. Should printers claim the first compatible fax job or obey explicit circuit filters?
3. Should `priority-directive` accelerate a queue, reserve bandwidth, or simply unlock premium destinations?
