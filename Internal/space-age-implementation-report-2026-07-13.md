# Administratorio Space Age Implementation Report

Date: 2026-07-13  
Branch: `space-age`  
Design source: `Internal/space-age-remediation-plan-2026-07-13.md`

## Delivered systems

- Space Age cargo rockets no longer invoke Administratorio's base-only victory state; base-only victory and statistics remain covered by regression tests.
- Vulcanus is propaganda-rich: local lie production is abundant, Territorial Arbitration consumes 50/100/200 lie per second by demolisher tier, and the rocket authorization uses the local deed/cyan/propaganda identity.
- Gleba is bullshit-rich: amber sap seeds eight bullshit ore per cycle and deterministic local routes cover data, excuses, credentials, justification, documentation, approvals, and rocket administration.
- Fulgora is rubble/archive-rich: scrap yields rubble, toner, and Old Archives; archives recycle in 0.5 seconds into forms only; deterministic rubble analysis covers ordinary data throughput alongside local electrolyte, lubricant, rocket fuel, and authorization routes.
- The Archive Reassignment Recycler is a native Furnace/Recycler variant with a normal one-item source inventory and result inventory. Each of 31 supported documents selects its own hidden reassignment recipe. That recipe has three deterministic, same-rank, color-safe candidate forms, each rolled independently at 25%; an operation can therefore return zero to three forms without runtime scripting or a custom interface.
- A Relay Clerk is consumed in Recycler construction as its permanent employee. There is no custom GUI, pair registration, hidden power helper, archival substrate, residue loop, or archive-specific data/excuse recovery recipe.
- Every item in the paperwork form subgroups—including restricted planetary permits outside Bureau eligibility—has an explicit recycling recipe yielding one paper at 25% probability.
- Aquilo fax reconstruction is dry: tiered transfer-sheet costs and compressed chroma ribbons replace liquid ink and archival substrate. Source documents are still destroyed, and one CMY set yields ten ribbon charges.
- Rocket-silo authorization is planet-specific rather than a universal taxpayer-money toll.
- Import analysis now classifies ordinary resources, ordinary paperwork, staffing, conflict resolution, planetary exports, and capstones, with named profiles and strict per-planet policy enforcement.
- Planet manifests, Factoriopedia-facing descriptions, achievements, and archive/fax player guidance were added.
- Base-only worker hiring was restored as deterministic direct worker production, while Space Age retains the enrolled-biter workforce-formation route.

## Automated acceptance results

- Full repository Lua/Python suite: pass.
- Lua syntax lint across all 208 Lua files: pass and integrated into `tests/run-tests.sh`.
- The previously tracked Python bytecode cache was removed; the test runner now suppresses bytecode regeneration.
- Strict base progression report: zero missing recipes, science-pack gaps, gated enabled recipes, provider cycles, blocked unlocks, delayed unlocks, or premature unlocks.
- Vulcanus named profiles: pass with only approved staffing/conflict imports.
- Gleba named profiles: pass with only approved staffing imports.
- Fulgora named profiles, including local escape and colored-form production: pass with only approved staffing imports.
- Fulgora Archive Bureau profile: pass; no ordinary resource or ordinary paperwork imports.
- Aquilo fax/native/escape profile: pass under its intentionally broad convergence import policy.
- Factorio 2.0.77 Space Age prototype load and fresh map creation: pass.
- Headless runtime smoke test: 600 ticks, no script errors, approximately 0.57 ms/update on an otherwise empty map.
- Live Recycler smoke test: the Archive Reassignment Recycler consumed one Work Order per operation and returned only its three configured same-rank candidates through the native result inventory. A separate vanilla Recycler consumed Work Orders through the finalized `work-order-recycling` prototype, whose sole product is one paper at 25% probability; no production ingredients were refunded.
- `git diff --check`: pass.

## Balance posture

The implemented numbers are conservative starting values. Each Archive Reassignment operation consumes one form and makes three independent 25% output rolls: the expected return is 0.75 forms, a 25% expected net sink. The result distribution is 42.1875% zero forms, 42.1875% one, 14.0625% two, and 1.5625% three. At base speed the one-second recipe takes two seconds, or 30 operations per minute. Old Archives process in 0.5 seconds and average one starter form with no rubble byproduct. Every paperwork form can be shredded in an ordinary Recycler into one paper at 25% probability. Scrap adds 0.70 expected rubble, 0.12 toner, 0.08 documentation, and a 6% archive chance per scrap operation.

No required basic-planet progression path depends on archive randomness. Vulcanus, Gleba, and Fulgora can produce regular supplies and launch materials locally; only explicit specialist staffing and Vulcanus conflict resolution remain deliberate imports/milestones. Aquilo remains intentionally import-dependent.

## Human playtest gates

Before release, complete timed first-landing playthroughs and one full campaign to tune—not invent—the implemented systems. Record time to printer/native machine/silo, imported staffing, Bureau failure streaks, recycler slot pressure, fax media consumption, demolisher arbitration duration, and yellow-form spoilage losses. These measurements may change recipe numbers but should not change the planetary identities or import policy above.
