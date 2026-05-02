# Buildings and Structures

## Administrative Buildings

### Office Desk (`office-desk`)

- Crafting speed: **1.0** with working hours, **0.75** without
- Handles bureaucracy recipes: base forms, approvals, work-orders, science, excuses, bonds input chain, verified certificates, environmental permits
- Can handle up to 10-ingredient recipes (unusual for vanilla)
- Subject to working hours: shuts down at night unless overtime-exemption module is installed

### Resolution Office (`resolution-office`)

- Complaint-only building
- Processes resolution chains: filing → case → final
- **Tier 1** (filing → final): landscape and littering
- **Tier 2+** (filing → case → final): smog, hazmat, noise, loitering, unemployment, vagrancy
- Cannot process base forms or approvals

### Mechanical Printer (`mechanical-printer`)

- Early-game, burner-powered printer
- Prints `blank-form` and `blank-approval`
- Starting building for the mod

### Basic Printer (`printer-t1`)

- Unlocked by `printing-technology`
- Midgame printer

### Industrial Printer (`printer-t2`)

- Unlocked by `industrial-printing`
- High-throughput printing
- Enables copy recipes: copy-blank-form, copy-blank-approval, copy-carbon-offset-certificate, copy-form-27b-6, copy-environmental-impact-report
- Managed by biter station
- Supports work-order duplication with `work-order-duplication` tech

---

## Production Buildings

### Greenhouse (`greenhouse`)

- Renewable wood production
- Unlocked by `administrative-bureaucracy` (displayed as "Wood Production")
- First coffee bean discovery (10% probability, hand-mine)
- Coffee plantation bootstraps bean multiplication
- Coffee refining: coffee-bean + water + work-order → liquid-coffee
- Outputs: wood, coffee-bean, water (input-output fluid connections)

### Corporate Breakroom (`corporate-breakroom`)

- Unlocked by `corporate-hospitality`
- Produces: coffee, gossip (`watercooler-gossip`), good excuses, verbal approvals
- Runs on biter visits (managed by biter station)
- Subject to working hours: shuts down at night

### Propaganda Distillery (`propaganda-distillery`)

- Unlocked by `industrial-propaganda`
- Produces: lie, misinformation, slush fund, justification chain
- Powered by politician-fluid (from politician-fluid-refining)
- Runs on biter visits (managed by biter station)
- Art by Hurricane (Hurricane046)

### Union Headquarters (`union-headquarters`)

- Unlocked by `public-finance`
- Produces: union-approval (fluid), grants, narrative, written approvals, policy work, tax audits
- Subject to working hours: shuts down at night
- Negotiates Union Approval as a fluid
- Neglected workplaces produce OSHA Violations that must be scrubbed in union-brokered cleanup runs

### Formation Center (`formation-center`)

- Only building that can train biters into specialists
- Produces: Union Delegate, Chemical Operator, Nuclear Technician, biter logistics formation
- Specialization training requires certified specialists to construct
- Triggered when first built (tips-and-tricks unlock)

---

## Biter Infrastructure

### Biter Administration Desk (`admin-station`)

- Holds complaint tickets, resolved items, and payouts
- Inventory size: 20
- 8 biter slots per waiting zone
- Connected circuit combinator for signal-based automation
- Non-rotatable entity
- Removed legacy directional variants (north/east/west) in v0.3.0

### Biter Employment Office (`biter-station`)

See [biter-employment.md](biter-employment.md)

### Biterport

See [biter-employment.md](biter-employment.md)

### Field Office (`field-office`)

See [biter-employment.md](biter-employment.md)

---

## Support Buildings

### Tube Intake (`tube-intake`)

- Part of pneumatic tube network
- Uses furnace-style intake validation with hidden per-paperwork recipes
- Inserters feed only valid pneumatic paperwork items into tube networks
- Exposes circuit signals showing network contents

### Tube Outtake (`tube-outtake`)

- Item extraction point for pneumatic networks
- Uses player's own inserter to extract (no hidden inserter)
- Supports inventory slot filters

### Transit Permit Chest (`transit-permit-chest`)

- Auto-placed just outside each train stop on the rail-facing side
- Destination Station requires a permit (limit = permits in chest)
- Train consumes one transit-authorization on arrival

---

## Pneumatic Tube Network

### How It Works (v0.3.0+)

The pneumatic system was reworked from fluid-based transport to a script-managed signal chain:

- **Tube Intake**: furnace-style intake with hidden intake inserter
- **Tube Outtake**: container (player uses own inserter to extract)
- Items consumed at intakes, tracked in per-network signal pool
- Dispensed at outtakes
- Network topology detected via BFS through hidden network pipes (max radius 120 tiles)
- Underground pipe range: 16 tiles
- Base capacity: 10 items per item type, upgradeable to 100 per item type via `pneumatic-capacity-1/2/3`

### Transportable Items

All paperwork items, complaint tickets, resolved items, currency items (taxpayer-money, treasury-bond, government-grant), and intermediate documents (paper, ink, credentials, data, good-excuse, justification, narrative, policy, regulation, white-paper, useless-documentation, refined-nonsense) can flow through pneumatic tubes.
