# Administratorio

**The factory must grow. Subject to approval.**

Overhaul mod for Factorio 2.0 that replaces military conflict with corporate bureaucracy. There are no guns, no turrets, and no military science. Instead, every machine you build, every inserter you place, and every furnace you fire up requires the proper paperwork.

This is an **Alpha** — it is buggy, and evolves fast, some graphics and sounds are still placeholders, and I'm still balancing the economy. If you run into issues, feel free to file a report, it genuinely helps.

## What Does This Mod Actually Do?

### Paperwork gates everything

Most recipes now require an administrative form on top of their regular ingredients. Crafting in assembling machines needs Work Orders and tiered assembler paperwork. Smelting in furnaces requires Carbon Offset Certificates. Oil refineries, chemical plants, and centrifuges each run on their own specialist operating documents built from lower-tier approvals. Higher-tier buildings still need permits — Construction Permits, Management Approvals, and so on. Most of the mod's own buildings now also have regulated assembling-machine copies, so scaling the office eventually becomes factory automation instead of endless handcrafting. Your growth is limited not just by iron and copper, but by the speed of your printers and the depth of your filing cabinets.

### Complaints replace combat

Biters don't attack your base in the usual way. Attack groups get intercepted and rerouted to your **Biter Administration Desk** instead. Each registered biter occupies one waiting slot, turns into a neutral citizen, and drops complaint-ticket items into the desk inventory. Admin Stations now start at **4 waiting slots** by default and can be expanded to **12** through the **Admin Station Capacity** research chain. You process those tickets through the **Resolution Office** chain, return the matching resolved item to the desk, and the citizen leaves satisfied while paying you in **Taxpayer Money**.

There are two complaint families: biters escalate through landscape, smog, noise, and unemployment; spitters escalate through littering, hazmat, loitering, and vagrancy. Bigger enemies can generate higher tiers, and the mod warns you as evolution approaches the thresholds where new paperwork tiers start mattering.

### Protests and promise capsules

Every waiting biter has its own frustration bar. If the queue backs up long enough, that biter leaves the desk queue, picks a reachable player building, and **disables it** by protesting there. Active protests raise alerts, show map tags, and keep the outage alive until you intervene.

Your emergency tool is the **Bureaucratic Promise** capsule. Throw it at the protesting biter, not the building. If a desk slot is available, the biter reroutes straight back into the nearest queue. If no slot is free, it becomes temporarily pacified for about 60 seconds and then resumes protesting if capacity still has not opened. A promise suppresses the outage, but it does **not** erase the complaint or any partial case progress already moving through your factory.

### Eviction notices are expansion paperwork

The other capsule is the **Eviction Notice**. Research **Nest Expropriation**, throw the notice into enemy territory, and it destroys the nearest nest or spawner in the target area. This is your expansion tool in place of vanilla combat.

The catch is that nearby biters are not deleted. They get displaced into your complaint system with roughly half a protest bar already filled. If you evict before your desks and resolution offices can absorb the surge, you create your own riot.

### Working hours and overtime exemptions

The bureaucracy now has office hours. When night falls, the lights go out, the clerks go home, and some of your most important administrative buildings simply stop pretending to care. **Office Desks**, **Corporate Breakrooms**, and **Union Headquarters** all close for the night unless you've filed the proper exception.

That exception is the **Overtime Exemption**. Research **After-Hours Operations**, install a single exemption module in the building, and suddenly the paperwork machine keeps humming long after sunset. Unsurprisingly, the permit for legally forcing night shift work is expensive, caffeine-dependent, and held together by public money. It only protects against the night shutdown, though — a protester can still disable that building during the day.

If you do not want that mechanic at all, there is also a startup setting to disable Working Hours entirely and keep those buildings on 24/7 behavior.

### New resources to extract

Alongside your usual ores, you'll be mining **Bullshit Ore** — a naturally occurring deposit of pure, unrefined nonsense — and **Redundant Rubble**, the mineralized waste of excessive procedural oversight. These feed into a whole parallel economy of excuses, justifications, narratives, and eventually, policy. You'll also need **Politician Fluid**, distilled into Lies and Misinformation at the **Propaganda Distillery**.

### New buildings to manage

I added a bunch of new buildings to support the bureaucratic machine:

- **Office Desk** — Core workstation for forms, science packs, early funding paperwork, and general admin throughput
- **Printers** — Produce forms, permits, and approvals at industrial scale
- **Corporate Breakroom** — Turns coffee and dubious data into gossip, good excuses, and verbal management drafts
- **Union Headquarters** — Negotiates union approvals, grants, narratives, written approvals, policy work, tax audits, and OSHA cleanup. The first HQ now bootstraps from treasury bonds and verbal paperwork instead of already needing a grant.
- **Propaganda Distillery** — Weaponizes misinformation for administrative purposes
- **Resolution Office** — Processes complex complaint chains
- **Biter Administration Desk** — Receives intercepted attack groups and has a fixed central waiting zone inside a larger walk-through station footprint
- **Pneumatic Form Transport** — A sealed pipe network dedicated entirely to moving paperwork

And yes, coffee is the lifeblood of the operation. You'll grow it in **Greenhouses**, brew it, and funnel it into every critical workflow.

### A full tech tree built on red tape

I reworked the entire research tree. Military milestones are replaced with bureaucratic ones, and the tree now splits into narrower branches like **Local Precedents**, **Environmental Compliance**, **Corporate Hospitality**, **Information Management**, **Verbal Approvals**, **Public Finance**, **Board Meetings**, **Executive Review**, **Radiological Compliance**, **Federal Regulation**, **Admin Station Capacity**, and the separate late complaint ordinances. Each branch unlocks a different slice of the office: paperwork throughput, coffee, approvals, funding, queue capacity, expansion, or one of the late complaint families.


## Current State

Currently incompatible with Space Age and Quality. Requires Factorio 2.0. I'd love to make a Space Age and Quality version down the line — no promises, but it's on my radar.

One current caveat: the Working Hours shutdown is runtime logic, so planner mods like Factory Planner will currently mis-model those buildings unless you account for it manually. I do want to address this somehow, but there is no proper compatibility solution in place yet. If you prefer planner accuracy over the day/night mechanic, disable Working Hours in the startup settings.

## Credits

The **Resolution Office** scrubber art and **Propaganda Distillery** art are by **Hurricane** ([Hurricane046](https://mods.factorio.com/user/Hurricane046)).

---

*Disclaimer: This mod was vibecoded by a real programmer that does not have enough free time to code himself, but it's still made with love and attention.*
