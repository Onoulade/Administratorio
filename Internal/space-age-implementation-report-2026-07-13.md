# Administratorio Space Age Implementation Report

Date: 2026-07-13  
Branch: `space-age`  
Design source: `Internal/space-age-remediation-plan-2026-07-13.md`

## Delivered systems

- Space Age cargo rockets no longer invoke Administratorio's base-only victory state; base-only victory and statistics remain covered by regression tests.
- Vulcanus is propaganda-rich: local lie production is abundant, Territorial Arbitration consumes 50/100/200 lie per second by demolisher tier, and the rocket authorization uses the local deed/cyan/propaganda identity.
- Gleba is bullshit-rich: amber sap seeds eight bullshit ore per cycle and deterministic local routes cover data, excuses, credentials, justification, documentation, approvals, and rocket administration.
- Fulgora is rubble/archive-rich: scrap yields rubble, toner, and Old Archives; archives re-recycle into a starter portfolio; deterministic recovery recipes cover ordinary factory throughput, electrolyte, lubricant, rocket fuel, and local authorization.
- The Archive Recombination Bureau supports all 465 unordered pairs across 31 selected documents. Every pair has two or three frozen, visible, technology-filtered candidates. Attempts take 20 seconds, consume two different same-quality forms plus same-quality substrate, succeed 50% of the time, preserve quality, and produce residue on failure.
- The Bureau exposes input-ready, valid-pair, working, success, failure, and output-blocked circuit signals. Its GUI shows actual conditional candidate weights and locked candidates.
- Aquilo fax reconstruction is dry: transfer sheets, Fulgora archival substrate, and compressed chroma ribbons replace liquid ink. Source documents are still destroyed, and one CMY set yields ten ribbon charges.
- Rocket-silo authorization is planet-specific rather than a universal taxpayer-money toll.
- Import analysis now classifies ordinary resources, ordinary paperwork, staffing, conflict resolution, planetary exports, and capstones, with named profiles and strict per-planet policy enforcement.
- Planet manifests, Factoriopedia-facing descriptions, achievements, circuit signal locale, and archive/fax player guidance were added.
- Base-only worker hiring was restored as deterministic direct worker production, while Space Age retains the enrolled-biter workforce-formation route.

## Automated acceptance results

- Full repository Lua/Python suite: pass.
- Lua syntax lint across all 207 Lua files: pass and integrated into `tests/run-tests.sh`.
- The previously tracked Python bytecode cache was removed; the test runner now suppresses bytecode regeneration.
- Strict base progression report: zero missing recipes, science-pack gaps, gated enabled recipes, provider cycles, blocked unlocks, delayed unlocks, or premature unlocks.
- Vulcanus named profiles: pass with only approved staffing/conflict imports.
- Gleba named profiles: pass with only approved staffing imports.
- Fulgora named profiles, including local escape and colored-form production: pass with only approved staffing imports.
- Fulgora Archive Bureau profile: pass; no ordinary resource or ordinary paperwork imports.
- Aquilo fax/native/escape profile: pass under its intentionally broad convergence import policy.
- Factorio 2.0.77 Space Age prototype load and fresh map creation: pass.
- Headless runtime smoke test: 600 ticks, no script errors, approximately 0.33 ms/update on an otherwise empty map.
- `git diff --check`: pass.

## Balance posture

The implemented numbers are conservative starting values. The Archive Bureau is a 75% expected net form sink before candidate usefulness: three attempts per minute consume six forms and yield 1.5 forms on average. Old Archives average 0.72 starter forms plus two rubble. Scrap adds 0.70 expected rubble, 0.12 toner, 0.08 documentation, and a 6% archive chance per scrap operation.

No required basic-planet progression path depends on archive randomness. Vulcanus, Gleba, and Fulgora can produce regular supplies and launch materials locally; only explicit specialist staffing and Vulcanus conflict resolution remain deliberate imports/milestones. Aquilo remains intentionally import-dependent.

## Human playtest gates

Before release, complete timed first-landing playthroughs and one full campaign to tune—not invent—the implemented systems. Record time to printer/native machine/silo, imported staffing, Bureau failure streaks, recycler slot pressure, fax media consumption, demolisher arbitration duration, and yellow-form spoilage losses. These measurements may change recipe numbers but should not change the planetary identities or import policy above.
