# Administratorio

**The factory must grow. Subject to approval.**

Overhaul mod for Factorio 2.0 that replaces military conflict with corporate bureaucracy. No guns. No turrets. No military science. Every machine you build, every inserter you place, and every furnace you fire up requires the proper paperwork — and the biters you used to shoot now have HR representation and a grievance process.

This is a **Beta**. The full progression arc is playable and the core systems are in place, but balance, compatibility, translations, and late-game polish are still being tuned. Bug reports and save-breaking edge cases are welcomed with the solemn gratitude of a man whose backlog is larger than his will to live.

## Full Documentation

A comprehensive internal documentation system is available in the `Internal/docs/` directory:

- **[Internal/docs/index.md](Internal/docs/index.md)** — Documentation index and quick links to all pages
- **[Internal/docs/core-mechanics.md](Internal/docs/core-mechanics.md)** — Core loops, paperwork tiers, complaint system, frustration/protest mechanics, resolution chains
- **[Internal/docs/biter-employment.md](Internal/docs/biter-employment.md)** — Hiring workers, Biter Employment Office, Biterport (walking-worker roboport), Field Office
- **[Internal/docs/buildings-and-structures.md](Internal/docs/buildings-and-structures.md)** — All buildings, production facilities, administrative buildings, pneumatic tube network, support structures
- **[Internal/docs/technology-tree.md](Internal/docs/technology-tree.md)** — Complete tech tree from discovery through Constitutional Law, specialization training, capacity upgrades
- **[Internal/docs/advanced-topics.md](Internal/docs/advanced-topics.md)** — Hired Biter (field agents), working hours system, modules, funding chain, coffee economy, train transit, bottlenecks

## Quick Overview

### Paperwork gates everything

Machines, smelting, chemistry, centrifuging, research — all of it now needs the correct form stapled to the usual ingredients. Iron and copper stop being your bottleneck somewhere around the first hour. After that, your bottleneck is paper, ink, Work Orders, and the one permit you forgot exists until the whole factory quietly stops moving.

### Complaints replace combat

Biters don't raid your walls. They get intercepted and rerouted to your **Biter Administration Desk**, where they queue up as neutral citizens and file complaint tickets about landscape, smog, noise, and unemployment. You process each ticket through a **Resolution Office** chain, and the satisfied citizen leaves paying you in **Taxpayer Money**. It's restorative justice with positive externalities.

Leave them waiting too long and they *protest* — walk to one of your buildings and disable it until you intervene. Throw a **Bureaucratic Promise** capsule to pacify them with temporary, legally non-binding reassurance. Throw an **Eviction Notice** to clear a nest, but be warned: the displaced biters show up at your desk already halfway to furious and freshly opinionated about property law.

### Your former enemies are now on payroll

Resolve a complaint with a **Job Offer** waiting in the desk, and the biter picks up the contract on its way out. Congratulations, you just hired a **Biter Worker**. They come in small, medium, big, and behemoth — bigger biter, more workers per hire, same health plan.

From there, the workforce branches out:

- **Formation Center** — the only building that can train biters into specialists (Union Delegates, Chemical Operators, Nuclear Technicians), logistics formations, and rideable assignments. Chemical plants, centrifuges, nuclear reactors, and Union HQs require certified specialists to construct. Credentials matter.
- **Biter Employment Office** — dispatches workers to nearby managed machines, one authorized craft per visit. Breakrooms, Union HQs, Propaganda Distilleries, oil refineries, centrifuges, and the industrial printer all run on biter visits. Which means the biters are now upstream of your own paperwork supply.
- **Biterport** — a roboport, but staffed by walking biters instead of flying robots. Progress.
- **Rideable Biter** — personal transport that runs on Taxpayer Money, available well before the vanilla car. Cannot be picked back up once placed, because the assignment is permanent by design. Run out of funding for 10 minutes and it reverts to a regular biter and files a complaint about you. Which is fair.
- **Hired Biter (Field Agent)** — a controllable worker you deploy via capsule to evict enemy nests and follow waypoints.

### Labor relations

Because the workforce is real, the paperwork is too. Your Union Headquarters negotiates **Union Approval** as a fluid, and neglected workplaces eventually produce **OSHA Violations** that have to be scrubbed away in union-brokered cleanup runs. You fund the workers, the workers file the forms, the forms cite you, you pay the workers to make the citation go away. The loop closes. The loop is the point.

### Office hours

Office Desks, Corporate Breakrooms, and Union Headquarters clock out at night unless you install an **Overtime Exemption**. Biter Employment Offices and Biterports keep working past sunset, but their night dispatches require Liquid Coffee piped into any of the four side entrances. The biters, it turns out, also get tired. If you'd rather skip the whole circadian subplot, there's a startup setting to keep the factory on 24/7.

### New resources, new fluids, new red tape

**Bullshit Ore**, **Redundant Rubble**, and **Politician Fluid** feed a parallel economy of excuses, justifications, narratives, misinformation, policy, and slush funds. It is exactly as dignified as it sounds. Coffee is the lifeblood of the operation — you grow it in **Greenhouses**, brew it, and pipe it into anything important. When the coffee stops, the office stops, and then so does everything else, in that order.

### A full tech tree built on red tape

The entire research tree is reworked around bureaucratic milestones instead of military ones. New branches for paperwork throughput, renewable wood and coal, approvals, public finance, queue capacity, workforce management, logistics formations, and the late complaint families. The complaint endgame runs through **Constitutional Law** for biters and **Vagrancy Ordinances** for spitters. The rocket is still there, if you can justify it to finance.

### Pneumatic Form Transport

Forms travel through pneumatic tubes — Tube Intakes consume items into a per-network signal pool, and Tube Outtakes dispense them. Network capacity scales from 10 to 25, 50, 100, and 200 shared items via research. Tube Intakes use furnace-style intake validation with hidden per-paperwork recipes, so inserters feed only valid pneumatic paperwork items.

### Administrative Certification (optional Quality integration)

If Factorio's optional Quality mod is active, its native Quality system is rethemed as **Administrative Certification**. The native grades, probabilities, and unlock effects remain exactly native; only the paperwork, costs, and selected facility metrics are administratively reinterpreted. Quality Modules become **Accreditation Modules 1–3**, and their technologies become Certification Standards, Advanced Certification, Executive Certification, Cabinet Accreditation, and Ministerial Accreditation.

Accreditation Modules are made in the `bureaucracy-modules` category and are deliberately expensive: their taxpayer-money costs are 25, 100, and 500 respectively, with five modules required at each upgrade. A T3 module therefore embodies 1,625 Taxpayer Money. This is not a mistake. It is an institution.

Ordinary administrative production facilities use native Quality speed and module-department curves without extra energy use. Fax Emitters and Interplanetary Fax Exchanges shorten sending and reconstruction time by their placed grade; receivers also gain one queue slot per Quality level. Biterports increase only their own logistics and construction radii by 10% per level, while connection distance and payload stay research-gated. Field Offices scale their nearby-spawner range and placement preview on that same 10%-per-level curve. Biter Stations otherwise retain native health/inventory behavior only.

Paperwork may be high quality, but its permit strength, form cost, research value, and recipe yield never change. Faxes, pneumatic tubes, and biterport logistics preserve a document's exact grade. In particular, unqualified biterport requester filters request normal stock only; an explicit Quality filter requests that exact grade, including for construction ghosts.

Pneumatic hardware itself is Quality-neutral and cannot be produced at a Quality grade. Archive recombination, territorial arbitration, trajectory compliance, orbital employment, and MMMM systems treat Quality as cosmetic only: no extra speed, range, damage, yield, staffing, payload, or module departments.

## Current State

Beta status means the mod is ready for broader playtesting, not that the paperwork has achieved enlightenment. Expect balance changes, UI/locale cleanup, and the occasional migration wart as the late-game systems get more miles on them.

Compatible with base Factorio 2.0 and Space Age. Space Age adds planet-specific administrative economies, dry interplanetary fax logistics, and Fulgora archive recombination. Quality is an optional `? quality >= 2.0.0` integration; without it, base Administratorio behavior is unchanged.

One caveat: the Working Hours shutdown is runtime logic, so planner mods like Factory Planner will mis-model those buildings unless you account for it manually. If you prefer planner accuracy over the day/night subplot, disable Working Hours in startup settings.

## Development

This repo uses a manual GitHub Actions release workflow for Factorio mod releases. See [CONTRIBUTING.md](CONTRIBUTING.md) for the version input, commit structure, and changelog behavior expected by the workflow.

## Credits

The **Resolution Office** scrubber art and **Propaganda Distillery** art are by **Hurricane** ([Hurricane046](https://mods.factorio.com/user/Hurricane046)).

---

*Disclaimer: This mod was vibecoded by a real programmer who does not have enough free time to code himself, but it's still made with love and attention.*
