# Administratorio

**The factory must grow. Subject to approval.**

Administratorio is a bureaucratic overhaul for Factorio 2.0. It keeps the belts, furnaces, pollution and spectacularly irresponsible copper consumption, then adds the one thing every factory was missing: an administrative department large enough to become the real bottleneck.

Forms and Work Orders sit beside iron and copper in your production chains. Machines need permits, staff, money or all three. Offices observe working hours. Night shifts require coffee. A factory can be perfectly supplied and still do nothing because somebody forgot to file the appropriate little rectangle of paper.

That is not a bug. It is governance.

## What changes?

### Paperwork replaces military progression

Weapons, turrets and military science are out. Bureaucracy is in. You begin by handcrafting paper and ink, printing basic forms, and assembling the first administrative buildings. From there, regulated production grows alongside the usual Factorio progression:

- Work Orders and form tiers gate machines, logistics, construction and science.
- Permits and operating documents are consumed by selected recipes and machine families.
- Administrative Science joins the research queue.
- Taxpayer Money, bonds, grants, coffee, credentials, data and increasingly questionable documentation sustain the late-game economy.

The factory must grow, the paperwork must flow; if the stamp says no, the belts will politely refuse to go.

### Biters become citizens

Biters do not attack you by default. They arrive at **Administration Desks**, file complaints about the landscape, smog, noise, unemployment and other amenities your industrial paradise emits, then wait for your **Resolution Offices** to process their cases.

Resolve a complaint and the citizen leaves peacefully, paying **Taxpayer Money**. Ignore the queue for too long and frustration becomes a protest: a building is selected, operations stop, and a very determined employee of the public walks over to make the point in person.

Larger biters file more complicated complaints and pay more. Complaint milestones also control native evolution, so the ecosystem is not allowed to become more troublesome until your administration has demonstrated the paperwork throughput to deserve it. A modest incentive to keep the queue moving; civilization is apparently a throughput problem.

### Hire the people you used to shoot

Resolve a complaint with a **Job Offer** in the desk and the departing biter can join your workforce. Depending on the configuration, workers can be trained for increasingly specific duties:

- **Biter Employment Office** dispatches workers to staff managed machines.
- **Biterport** provides walking-worker logistics and construction support.
- **Formation Centers** train workers into union delegates, chemical operators, nuclear technicians and logistics specialists.
- **Field Offices** summon temporary workers from nearby nests to bridge the gap before your first hires.
- **Rideable Biters** provide personal transport, because apparently the next logical step after industrial bureaucracy is commuting by insect.
- **Hired Biters** act as controllable field agents for nest eviction and other approved interventions.

Workers require salaries. Night dispatches require coffee. The union is real, and it has noticed your staffing model.

### Build a logistics network made of paperwork

Research **Pneumatic Form Transport** to send administrative items through a script-managed tube network. Tube Intakes feed the network, Outtakes retrieve filtered items, and Pumps move paperwork between connected networks. Capacity and throughput grow through research, because even documents need an upgrade path.

Trains also participate in the civic order: stations use transit authorization paperwork unless you eventually earn the privilege of bureaucratic transcendence.

### Working hours, coffee and other workplace realities

With **Working Hours** enabled (the default), Office Desks, Corporate Breakrooms and Union Headquarters close during the night window. Install an **Overtime Exemption** module to keep an eligible building open around the clock. Biter Employment Offices and Biterports can work night shifts too, but they charge the company in liquid coffee.

The **Administrative Clock** exposes daytime, shift boundaries and working-hours state to the circuit network. At last, a clock that can tell you exactly when the factory is closed for lunch.

## Space Age

Space does not repeal the weapons ban. It introduces asteroids, multiple planetary jurisdictions and a fresh opportunity to discover that one permit was only valid on the previous planet.

With Space Age installed, Administratorio expands into:

- Planet-specific paperwork for Vulcanus, Gleba, Fulgora and Aquilo.
- Administrative space stations and orbital printing.
- **Trajectory Compliance Arrays** that push inconvenient asteroids away from your platform using legally approved deviation orders.
- Orbital employment and interplanetary tube infrastructure.
- Planetary field offices, territorial arbitration and archive recombination.
- Space Age-specific workforce, chemistry, metallurgy, biological and digital administration chains.

The result is the same factory problem at a larger scale: more planets, more jurisdictions, more forms. The void is cold, but the filing cabinet is warm.

## Optional integrations

- **Space Age** is optional. The base-game progression remains available without it.
- **Quality** is optional and supported independently of Space Age. Its native quality grades remain meaningful without silently turning paperwork into magic.
- **Factorissimo** compatibility is included for working-hours time handling and pneumatic tube networks through factory walls.
- The mod includes a compatibility hook layer so supported integrations can be added without tangling the core systems into an unholy dependency scrapbook.

## Getting started

1. Gather wood and coal, then handcraft paper and ink.
2. Use the starting **Mechanical Printer** to print basic forms.
3. Research **Steam Power** to unlock the **Field Office** recipe.
4. Mine **Redundant Rubble** and **Bullshit Ore** to trigger the two early discoveries, then use the unlocked paperwork to keep the bootstrap moving.
5. Craft and place your first Field Office near a biter nest. This triggers **Field Office Deployment**, which unlocks provisional approvals and the **Biter Administration Desk**. The Field Office is your early bootstrap workforce; the permanent Office Desk is still waiting for research.
6. Research **Administrative Bureaucracy**, **Rubble Compaction** and then **Biter Employment**. This is when the **Office Desk** and **Resolution Office** become available; bureaucracy has finally approved bureaucracy.
7. Establish complaint filing and resolution before expanding the factory too aggressively.
8. Keep paper, ink and the required forms buffered. The machine may be hungry for iron, but the bureaucracy is hungry for stationery.

The in-game tips and tricks explain individual items and progression gates. The long-form reference is split into maintained documentation:

- [Core Mechanics](Internal/docs/core-mechanics.md) — bootstrap, form tiers, complaints, protests and resolution chains.
- [Biter Employment](Internal/docs/biter-employment.md) — hiring, training, stations, Biterports and Field Offices.
- [Buildings and Structures](Internal/docs/buildings-and-structures.md) — production buildings, support infrastructure and pneumatic tubes.
- [Technology Tree](Internal/docs/technology-tree.md) — progression, research gates and specialization.
- [Advanced Topics](Internal/docs/advanced-topics.md) — working hours, modules, coffee, trains, field agents and structural bottlenecks.
- [Mod Compatibility](Internal/docs/mod-compatibility.md) — compatibility hooks for contributors.

## Current status

**Beta** The main progression and runtime systems are playable, including the base-game and Space Age paths. Balance, compatibility, translations, migrations and late-game polish are still active work.

Please report:

- progression stalls or missing paperwork;
- migration problems in existing saves;
- compatibility issues with other mods;
- balance spikes, especially around staffing, funding and planetary chains;
- translations or tooltips that have wandered into the wilderness.

Real factories are especially valuable test cases. Players routinely discover arrangements that no responsible test suite would think to fear.

## Settings

| Setting | Default | Purpose |
| --- | --- | --- |
| `administratorio-enable-working-hours` | `true` | Enables the night-shutdown system. Disable it for easier planner-mod modelling. |
| `administratorio-debug-protest-belts-and-inserters` | `false` | Allows debug protests to target belts, underground belts, splitters and inserters. |
| `administratorio-debug-hard-mode` | `false` | Enables the harsher protest and hostile-escalation rules for testing. |

The two debug options are runtime-global settings and can be toggled during a save. Working Hours is a startup setting.

## Credits

The **Resolution Office**, **AI Server**, **Interplanetary Terminus**, **Slop Refinery**, **Synthetic Personnel Bureau** and **Propaganda Distillery** art are by **Hurricane** ([Hurricane046](https://mods.factorio.com/user/Hurricane046)). What a hero

The **Office Desk** and **Greenhouse** assets are taken from the **[Krastorio 2](https://mods.factorio.com/mod/Krastorio2)** mod.

The **Inference Token** icon, **optic fibre** artwork and **optic fibre** mechanic come from **[Moshine](https://github.com/snouz/Moshine)** and **[Moshine-assets](https://github.com/snouz/Moshine-assets)** by **snouz**.

The **Involuntary Relocation Receiver** sprite and icon are repurposed from **[Long Range Delivery Drones](https://mods.factorio.com/mod/Long_Range_Delivery_Drones)** (GNU LGPLv3), by **Sacredanarchy** and **Klonan**.

Other assets are images I generated using various AIs and local generation (ComfyUI), lots of Photoshop and were animated using my **[Animatorio tool](https://github.com/Onoulade/Animatorio)**, check it out !

---

*Disclaimer: This mod was vibecoded by a real programmer who does not have enough free time to code himself. It is nevertheless made with love, attention, and an unreasonable number of forms.*
