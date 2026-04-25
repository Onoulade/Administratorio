---
title: Core Mechanics
order: 1
---

# Core Mechanics

**administratorio** is a complete overhaul mod for Factorio 2.0 that replaces military conflict with corporate bureaucracy. No guns, no turrets, no military science. Every machine you build, every inserter you place, and every furnace you fire up requires the proper paperwork — and the biters you used to shoot now have HR representation and a grievance process.

---

## 1. The Three Core Loops

### Bootstrap Loop

Your first hour is less about automation and more about reading fine print. Follow this chain to get from nothing to your first functioning administrative hub:

1. Gather `wood` and `coal`.
2. Handcraft `paper` and `ink`.
3. Use the starting `mechanical-printer` to print `blank-form` and `blank-approval`.
4. Handcraft `office-desk`.
5. Hand-mine `redundant-rubble` to trigger `discovery-redundant-rubble`.
6. Use the desk to make `provisional-approval`.
7. Handcraft `admin-station` and `resolution-office`.
8. Hand-mine `bullshit-ore` to trigger `discovery-bullshit`.
9. Use a stone furnace plus `carbon-offset-certificate-basic` to batch-smelt plates and `dubious-data`.
10. Use the desk to make `basic-excuse`.
11. Process landscape complaints for the first steady `taxpayer-money`.

**Tip:** The bottleneck is always paper and ink early on. Queue a coal-smoked furnace with `carbon-offset-certificate-basic` immediately — it's your first reliable throughput multiplier.

### Science Loop

The research pipeline blends vanilla progression with the mod's administrative layer:

1. Craft a `lab` to trigger vanilla `automation-science-pack`.
2. That unlocks `automation-science-pack` and, via mod hook, `research-grant-approval-production`.
3. Produce `administrative-science-pack` at the `office-desk`.
4. Research `automation` to unlock `work-order-production` and the early combined work-order recipes.
5. Research `administrative-science-research` to unlock `administrative-science-pack-production`.
6. Research `printing-technology` to unlock `printer-t1`.

### Bureaucracy Loop

The economy converges into a single feedback loop once the first three systems interlock:

1. Forms gate automation.
2. Complaint resolution gates `taxpayer-money`.
3. `taxpayer-money` gates bonds, grants, late Union HQ policy work, and several late-game buildings.
4. Coffee, lies, misinformation, credentials, data, narrative, policy, and regulation form the late-game admin economy.

---

## 2. Paperwork Gates Everything

In vanilla Factorio, iron and copper are your bottleneck. Somewhere around the first hour, that flips. After that, your bottleneck is **paper**, **ink**, **Work Orders**, and the one permit you forgot exists until the whole factory quietly stops moving.

### Form Tiers

Each form tier corresponds to a technology/progression stage. You cannot craft a recipe until you have unlocked the required form.

| Tier | Form | Intended use in regulated vanilla recipes |
| --- | --- | --- |
| T0 | `work-order` | Assembler-only basic intermediates, belts, pipes, base utility items |
| T1 | `safety-waiver` / `safety-work-order` | Inserters, poles, boiler / steam tier, AM1 |
| T2 | `construction-permit` / `construction-work-order` | Furnaces, mining drills, pumps, AM2, industrial building recipes, demolition |
| T3 | `management-approval-verbal` / `management-verbal-work-order` | Rail, solar, accumulators, roboport, personal roboports, robot logistics |
| T4 | `management-approval-written` / `management-written-work-order` | AM3, beacon, rocket silo, nuclear support hardware, late megaproject recipes |
| Science | `research-grant-approval` / `research-grant-work-order` | All science packs |

### Machine Operating Paperwork

Some machines require a specific operating document on top of the base work-order. These are consumed per batch, not per craft.

| Machine family | Operating document | Notes |
| --- | --- | --- |
| Furnaces | `carbon-offset-certificate-basic` / `carbon-offset-certificate-verified` | Smelting and rubble compression already run on certificates |
| Oil processing | `petrochemical-operating-permit` | Reusable refinery permit built from safety, construction, EIR, and Form 27B-6 |
| Chemistry | `chemical-handling-work-order` | Chemical-plant operating document; no longer shares assembler `work-order` |
| Centrifuging | `radiological-work-order` | Centrifuge operating document built from chemical paperwork and written approval |

---

## 3. Complaints Replace Combat

Biters don't raid your walls. They get intercepted and rerouted to your **Bitter Administration Desk**, where they queue up as neutral citizens and file complaint tickets about landscape, smog, noise, and unemployment. You process each ticket through a **Resolution Office** chain, and the satisfied citizen leaves paying you in **Taxpayer Money**.

It's restorative justice with positive externalities.

### Protest Mechanics

Leave citizens waiting too long and they **protest** — they walk to one of your buildings and disable it until you intervene.

- After **600 seconds (10 minutes)** of waiting, biters protest.
- They walk to a random player building and disable it until pacified.

**Response items:**

- **Bureaucratic Promise** capsule — temporarily pacifies a protester for up to 60 seconds while it retries to find an open desk. If no desk frees up before the timer expires, the protest resumes.
- **Eviction Notice** capsule — clears a biter nest, but the displaced biters show up at your desk already halfway to furious and freshly opinionated about property law.

### Complaint Types

| Biter Type | Complaints |
| --- | --- |
| Regular biters | landscape, smog, noise, unemployment |
| Spitters | littering, hazmat, loitering, vagrancy |

### Complaint Tiers by Biter Size

Larger biters file more complaints at higher tiers, but also pay more.

| Biter Size | Complaint Count | Max Tier | Payout |
| --- | --- | --- | --- |
| Small | 1 | 1 (landscape / littering) | 5 taxpayer-money |
| Medium | 3 | 2 (adds smog / hazmat) | 15 taxpayer-money |
| Big | 6 | 3 (adds noise / loitering) | 50 taxpayer-money |
| Behemoth | 10 | 4 (adds unemployment / vagrancy) | 100 taxpayer-money |

### Resolution Chains

Each complaint pair requires a specific technology to unlock. Resolved complaints produce a reward item and pay out taxpayer-money.

| Complaint pair | Unlocked after | Recipe depth |
| --- | --- | --- |
| `landscape` | start | filing → final |
| `littering` | `littering-resolution` | filing → final |
| `smog` + `hazmat` | `environmental-compliance` | filing → case → final |
| `noise` + `loitering` | `eminent-domain-zoning` | filing → case → final |
| `unemployment` + `vagrancy` | `constitutional-law` | filing → case → final |

### Admin Station

The `admin-station` is your central complaint desk. It's the primary interface between your factory and the biter economy.

**Specs:**

- Holds tickets, resolved items, and payouts.
- `inventory_size = 20`.
- Each waiting zone has 8 biter slots.
- Practical desk throughput is inventory-limited long before zone capacity is reached.

**Automation:**

- Connected circuit combinator outputs complaint counts (8 types), available slots, and total waiting for signal-based automation.
- Hover inspection panel shows individual biter state and frustration level.

---

## 4. Your Former Enemies Are Now On Payroll

Resolve a complaint with a **Job Offer** waiting in the desk, and the biter picks up the contract on its way out. Congratulations — you just hired a **Biter Worker**.

They come in small, medium, big, and behemoth. Bigger biter, more workers per hire, same health plan.

From there, the workforce branches out to the Formation Center, Biter Employment Office, Biterport, and Rideable Biter — detailed in their own documentation pages.

---

## Current State

- **Incompatible with:** Space Age and Quality.
- **Requires:** Factorio 2.0.
- **Compatibility on the radar:** Space Age and Quality are pending approval.

**Note on planning mods:** The Working Hours shutdown is runtime logic, so planner mods like Factory Planner will mis-model those buildings unless you account for it manually. If you prefer planner accuracy over the day/night subplot, disable Working Hours in startup settings.
