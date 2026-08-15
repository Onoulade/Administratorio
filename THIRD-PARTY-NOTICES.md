# Third-Party Notices

Administratorio includes material from other projects. Each entry below records
what was used, from whom, and under which licence.

---

## Moshine — snouz

- Project: <https://github.com/snouz/Moshine>
- Author: **snouz**

### Artwork

| File in this mod | Source file | Notes |
|---|---|---|
| `graphics/icons/third-party/inference-token.png` | `Moshine/graphics/icons/ai-trainer.png` | Used as the Inference Token fluid icon. |

Per Moshine's own credits, the AI Trainer artwork is a composite:

- includes or is a modified version of artwork from **Krastorio 1 and 2**,
  licensed **GNU LGPLv3**
- contains artwork from **Hurricane046**'s buildings, licensed **CC BY**

Both licences permit reuse and modification with attribution. The LGPLv3
portions remain under LGPLv3; this notice is the required attribution and
licence notice, and the unmodified source file is available from the Moshine
project linked above. The CC BY portions are attributed to Hurricane046 here.

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

## Notes for future contributors

Moshine's entity graphics live in a separate `Moshine-assets` mod and are **not**
vendored here. If any are added later, they must be listed in the table above
with their specific upstream licence before shipping. Moshine itself ships no
top-level `LICENSE` file, so material not covered by one of the licences its
credits name should not be assumed to be freely reusable — ask snouz first.
