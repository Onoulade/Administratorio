# Third-Party Notices

Administratorio includes material from other projects. Each entry below records
what was used, from whom, and under which licence.

---

## Moshine — snouz

- Project: <https://github.com/snouz/Moshine>
- Author: **snouz**

### Artwork

| File in this mod | Source | Upstream licence |
|---|---|---|
| `graphics/icons/third-party/inference-token.png` | `Moshine/graphics/icons/ai-trainer.png` | GNU LGPLv3 + CC BY — see below |
| `graphics/entities/third-party/optical-fibre/*.png` (27 files) | `Moshine-assets/graphics/entity/opticalfiber/` | **Not covered by a credited licence — see "Outstanding" below** |

### AI Trainer icon

Per Moshine's own credits, the AI Trainer artwork is a composite:

- includes or is a modified version of artwork from **Krastorio 1 and 2**,
  licensed **GNU LGPLv3**
- contains artwork from **Hurricane046**'s buildings, licensed **CC BY**

Both licences permit reuse and modification with attribution. The LGPLv3
portions remain under LGPLv3; this notice is the required attribution and
licence notice, and the unmodified source file is available from the Moshine
project linked above. The CC BY portions are attributed to Hurricane046 here.

### Optic fibre artwork — **Outstanding**

Moshine's credits name the Neural Computer, Data Extractor, Indexer, AI
Trainer, Data Processor and sand artwork as carrying the Krastorio (LGPLv3)
and Hurricane046 (CC BY) licences. The **optical fibre sprites are not in that
list**, and neither Moshine nor Moshine-assets ships a top-level `LICENSE`, so
they are snouz's own work with no stated grant.

They are used here on the mod author's instruction. Before any public release,
**snouz's explicit permission should be obtained**, or the sprites replaced.
Removing them is a single-file change: `prototypes/entity/optical_fiber.lua`
falls back to tinted vanilla pipe art, which is what it used before.

Licence texts:

- GNU LGPLv3 — <https://www.gnu.org/licenses/lgpl-3.0.html>
- CC BY 4.0 — <https://creativecommons.org/licenses/by/4.0/>

### Design

The **optic fibre** mechanic is inspired by Moshine's optical cable: a `pipe`
prototype carrying data as a fluid on its own `connection_category`, so it will
not join the ordinary fluid network.

Administratorio's implementation is its own code. It reuses the mod's existing
`connection_category` pattern — the same one the pneumatic tube network already
uses to stay isolated from real pipes — and no Moshine code was copied. The
idea is credited here because it is a good one and it came from Moshine.

---

## Long range delivery drones — Sacredanarchy, Klonan

- Project: <https://mods.factorio.com/mod/Long_Range_Delivery_Drones>
- Authors: **Sacredanarchy**, **Klonan**
- Licence: **GNU LGPLv3**

### Artwork

| File in this mod | Source | Upstream licence |
|---|---|---|
| `graphics/entities/relocation-cannon/relocation-receiver.png` | Long range delivery drones `request-depot.png` | GNU LGPLv3 |
| `graphics/icons/relocation-receiver.png` | Same source, padded square and resized to a 64×64 icon | GNU LGPLv3 |

Used as the [entity=involuntary-relocation-receiver] building's sprite and
inventory icon. The LGPLv3 licence permits reuse and modification with
attribution; this notice is that attribution, and the unmodified source file
is available from the project linked above.

---

## Notes for future contributors

Moshine's entity graphics live in a separate `Moshine-assets` mod and are **not**
vendored here. If any are added later, they must be listed in the table above
with their specific upstream licence before shipping. Moshine itself ships no
top-level `LICENSE` file, so material not covered by one of the licences its
credits name should not be assumed to be freely reusable — ask snouz first.
