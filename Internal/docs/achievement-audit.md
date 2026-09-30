# Achievement audit

Reviewed against the current prototypes and complaint runtime on 2026-09-30.
There are **31 Administratorio achievements without Space Age, 84 with it**,
plus the existing Space Age science-pack achievement whose text the mod rethemes.
Working Hours does not change the catalogue.

## Changes

- Kept every existing achievement ID. Reworked `know-it-all` into a 1,000-document production goal instead of all research.
- Separated identical triggers: `frozen-pdf` now researches Aquilo printing; `chromatic-trunk` retains coloured tube transport. `archive-recombinator` now researches Fulgora salvage; `file-not-found` retains the form-reassignment machine.
- Separated the two ribbon totals: `cyan-magenta-yellow-black` now tracks 1,000 liquid-printed Trichromatic Permits, while `ribbon-collector` retains 2,000 solid ribbons.
- Added ten milestones for Field Offices, logistics-worker training, Biterports, personal transport, passenger wagons, personnel routing, AI servers, slop production, synthetic personnel and relocation.
- Restored four previously unimplemented orbital milestones: senior/executive arrays, miner-ammunition throughput and orbital-permit throughput.
- Removed the unused returning-miner locale entries. A returning employee is an asteroid chunk, not a craftable item; recovery needs a dedicated runtime goal if introduced later.
- Made cartridge-ink production available without Space Age.
- Production totals and capsule-use counts now belong to one game. Existing thresholds remain except for the repurposed all-research goal and the former 1,000-ribbon goal. Previously these totals accumulated across unrelated saves.
- Corrected obsolete research names, archive recovery versus consumption, public-transport contracts versus tourism, train-route planning versus travel, desk count versus power, and the final array cooldown (1.5 seconds).
- Reworked titles and punchlines in English, French and Russian. Native goal text uses prototype-name substitutions so future building/technology renames appear automatically.
- Replayed completed scripted milestones when players are created or join, including after reconnecting. Native achievements continue to use Factorio's own tracking.

Research unlocks and building placements serve different purposes: access to a chain versus installing its infrastructure. Rate goals reward throughput, while totals reward sustained production. Placement achievements do not certify connected or functioning networks; descriptions state the placement requirement directly.

Factorio defines [train-path achievements](https://lua-api.factorio.com/latest/prototypes/TrainPathAchievementPrototype.html) by planned path length. It defines [all-research achievements](https://lua-api.factorio.com/latest/prototypes/ResearchAchievementPrototype.html) over every technology, and [production totals](https://lua-api.factorio.com/latest/prototypes/ProduceAchievementPrototype.html) with an explicit single-game/lifetime switch.

## Purpose of every goal

Requirements below reproduce the English goal text. The in-game description follows each requirement with its joke. Scripted complaint milestones apply to the shared world state, matching their existing runtime behavior.

### Base game

| Achievement | Requirement | Purpose |
| --- | --- | --- |
| Welcome to the Department (`welcome-to-the-department`) | Build Biter Administration Desk. | Introduce the complaint intake building. |
| Discovery of Bullshit (`discovery-of-bullshit`) | Research Empirical Incompetence. | Mark the first custom resource discovery. |
| Ink Stained (`ink-stained`) | Research Basic Printer. | Mark the transition from bootstrap printing to powered printing. |
| Form 27B/6 (`form-27b-6-achievement`) | Produce 100 Form 27B-6 per hour. | Reward automation of the signature bureaucratic form. |
| Paper Pusher (`paper-pusher`) | Produce 1,000 Blank Form per hour. | Reward scaling the common input to the paperwork economy. |
| Ink Hoarder (`ink-hoarder`) | Produce 10,000 Ink in one game. | Reward a substantial cartridge-ink supply, including base-only games. |
| Terms May Change (`capsule-promise`) | Use 1 Bureaucratic Promise. | Introduce the player-operated crowd-control tool. |
| It's a Copy of a Copy (`its-a-copy-of-a-copy`) | Research Local Precedents. | Mark entry into documentation and precedent production. |
| Permit Denied (`permit-denied`) | Build 10 train-stop. | Reward expansion of the regulated railway network. |
| Coffee Break (`coffee-break`) | Build Corporate Breakroom. | Introduce the breakroom and its production/staffing role. |
| Pneumatic Delivery (`pneumatic-delivery`) | Research Pneumatic Form Transport. | Mark access to local paperwork transport through tubes. |
| Boots on the Ground (`boots-on-the-ground`) | Build Field Office. | Introduce supervised work near nests. |
| Human Resources (`human-resources`) | Produce 10 Biter Logistics Worker in one game. | Reward training a useful pool of construction and delivery workers. |
| Last-Mile Management (`last-mile-management`) | Build Biterport. | Introduce the biter-operated construction and delivery network. |
| Company Car (`company-car`) | Build Rideable Biter. | Introduce personal biter transport. |
| Business Class (`business-class`) | Build Passenger Wagon. | Introduce the vehicle used by complaint passengers. |
| Propaganda Machine (`propaganda-machine`) | Build Propaganda Distillery. | Introduce industrial propaganda-fluid production. |
| Endless Meetings (`endless-meetings`) | Research Board Meetings. | Mark entry into higher management paperwork. |
| Union Strong (`union-strong`) | Build Union Headquarters. | Introduce union negotiation infrastructure. |
| Environmental Compliance (`environmental-compliance-achievement`) | Research Environmental Compliance. | Mark regulated access to the chemical/oil economy. |
| Constitutional Scholar (`constitutional-scholar`) | Research Behemoth Complaint Administration. | Mark the final complaint tier and removal of the evolution ceiling. |
| Know It All (`know-it-all`) | Produce 1,000 Useless Documentation in one game. | Reward documentation production without depending on disabled research. |
| Eviction Notice (`eviction-notice-achievement`) | Use 100 Eviction Notice in one game. | Reward repeated use of the native eviction capsule. |
| Mass Transit (`mass-transit`) | Have a train plan a route longer than 2,000 tiles. | Reward planning a long railway route; it does not measure travelled distance. |
| First Complaint (`first-complaint`) | Register your first biter at an Admin Station. | Confirm actual registration, beyond simply placing a desk. |
| First Protest (`first-protest`) | Let a biter's frustration become a protest. | Introduce the consequence of an unresolved waiting visitor. |
| Case Closed (`case-closed`) | Resolve your first biter complaint. | Confirm a real complaint was served, beyond producing a resolution item. |
| Protest Suppressed (`protest-suppressed`) | Pacify a protesting biter with a Promise. | Confirm a Promise actually pacified a protesting visitor. |
| Department of Everything (`department-of-everything`) | Have 10 administration desks at once. | Reward simultaneous complaint-intake capacity; does not require power. |
| Full Resolution (`full-resolution`) | Resolve each of the eight complaint types. | Require successful service of all eight complaint categories. |
| Behemoth Paperwork (`behemoth-paperwork`) | Register a behemoth biter or spitter at an administration desk. | Confirm actual registration of the highest-tier biter or spitter. |

### Space Age

| Achievement | Requirement | Purpose |
| --- | --- | --- |
| Terms and Conditions Apply (`terms-and-conditions-apply`) | Research Vulcanus Certification. | Mark Vulcanus certification and its territorial paperwork. |
| Organically Sourced Nonsense (`organically-sourced-nonsense`) | Research Gleba Conciliation. | Mark Gleba conciliation progression. |
| File Not Found (`file-not-found`) | Build Archive Reassignment Recycler. | Introduce the probabilistic form-reassignment machine. |
| Frozen PDF (`frozen-pdf`) | Research Laser Printer. | Mark Aquilo solid-media printing access, separate from chromatic tube access. |
| Career Opportunities (`workforce-formation-achievement`) | Research Resolution Office. | Mark Space Age regular-worker formation and Resolution Office access. |
| Overhead Costs (`administrative-space-station-achievement`) | Build Administrative Space Station. | Introduce orbital bureaucratic production. |
| Launch Your Career (`orbital-employment-catapult-achievement`) | Build Orbital Miner Deployment Catapult. | Introduce miner deployment infrastructure. |
| Gravity Is a Guideline (`trajectory-compliance-array-achievement`) | Build Trajectory Compliance Array. | Introduce the first asteroid-redirection array. |
| Escalated to Senior Management (`senior-trajectory-compliance-array`) | Build Senior Trajectory Compliance Array. | Reward installing infrastructure for larger asteroids. |
| Executive Decision (`executive-trajectory-compliance-array`) | Build Executive Trajectory Compliance Array. | Reward installing the final array tier. |
| Applicants Must Be Flexible (`vesm-mass-production`) | Produce 10 Voluntary Exploration Space Miner per hour. | Reward automated manufacture of reusable orbital miner ammunition. |
| Vacuum Clause (`orbital-permit-mill`) | Produce 50 Orbital Infrastructure Permit per hour. | Reward scaling the orbital construction permit supply. |
| Brand Compliance (`chromatic-printing-achievement`) | Research Chromatic Printer. | Mark the common Space Age chromatic-printer unlock. |
| Out of Cyan (`chromatic-printer-achievement`) | Build Chromatic Printer. | Reward installing the unlocked printing infrastructure. |
| Triple Ink Threat (`triple-ink-threat`) | Produce 100 Trichromatic Permit per hour. | Reward throughput of four-ink permit production. |
| Cyan, Magenta, Yellow, Black (`cyan-magenta-yellow-black`) | Produce 1,000 Trichromatic Permit in one game. | Reward sustained four-ink production, distinct from solid ribbons. |
| Notary Public (`notary-public`) | Build Notary Office. | Introduce notarisation infrastructure on Vulcanus. |
| Territorial Arbitrator (`territorial-arbitrator`) | Build Territorial Arbitration Post. | Introduce territory arbitration infrastructure. |
| Small Claims Court (`demolisher-eviction-specialist`) | Produce 5 Territorial Deed in one game. | Reward territorial-deed production; five deeds are not five completed evictions. |
| Chartered Accountant (`chartered-accountant`) | Produce 100 Offworld Metallurgy Charter in one game. | Reward scaling Vulcanus metallurgy export paperwork. |
| Let Us Circle Back (`conciliation-officer-achievement`) | Build Conciliation Desk. | Introduce Gleba conciliation infrastructure. |
| Talent Acquisition (`capture-bureau-achievement`) | Build Capture Bureau. | Introduce Gleba wildlife acquisition infrastructure. |
| Ticket to Ride (`space-tourism-mogul`) | Produce 500 Public Transportation Contract in one game. | Reward the public-transport contract supply, rather than imply actual tourist trips. |
| Symbiosis Specialist (`symbiosis-specialist`) | Produce 100 Symbiosis Record per hour. | Reward automation of Gleba specimen bookkeeping. |
| Digital Transformation (`digital-services-bureau-achievement`) | Build Digital Services Bureau. | Introduce Fulgora digital paperwork infrastructure. |
| Legacy Support (`archive-recombinator`) | Research Fulgora Magenta Administration. | Mark Fulgora magenta/salvage research, separate from building its recycler. |
| Records Management (`form-gambler`) | Produce 1,000 Old Archive in one game. | Reward archive recovery from scrap; it does not count archive consumption. |
| Please Keep Me in the Loop (`relay-clerk-corps`) | Produce 10 Relay Clerk in one game. | Reward a pool of electromagnetic paperwork specialists. |
| Pneumatic Diplomacy (`tube-terminus`) | Build Interplanetary Terminus. | Introduce interplanetary paperwork transport infrastructure. |
| Cold Press (`laser-printer-achievement`) | Build Laser Printer. | Reward installation of Aquilo solid-media printing infrastructure. |
| Thermal Paper Pusher (`thermal-paper-pusher`) | Produce 5,000 Thermal Transfer Sheet in one game. | Reward a substantial supply of Aquilo printing substrate. |
| Ribbon Collector (`ribbon-collector`) | Produce 2,000 Composite Chroma Ribbon in one game. | Reward solid chromatic media production rather than repeat an earlier ribbon count. |
| One Shared Vision (`interplanetary-correspondent`) | Produce 50 Unified Operations Charter in one game. | Reward integration of the planetary paperwork chains. |
| Cyan-Yellow Bureaucrat (`cyan-yellow-bureaucrat`) | Produce 500 Cyan-Yellow Form in one game. | Reward production through the Vulcanus/Gleba combined chain. |
| Cyan-Magenta Bureaucrat (`cyan-magenta-bureaucrat`) | Produce 500 Cyan-Magenta Form in one game. | Reward production through the Vulcanus/Fulgora combined chain. |
| Yellow-Magenta Bureaucrat (`yellow-magenta-bureaucrat`) | Produce 500 Yellow-Magenta Form in one game. | Reward production through the Gleba/Fulgora combined chain. |
| Disaster Recovery Plan (`hardened-data-hoarder`) | Produce 100 Hardened Data Vault in one game. | Reward high-tier data custody production. |
| Deregulation Requires Approval (`bureaucratic-transcendence-achievement`) | Research Public Train Stop. | Mark access to stops that bypass per-arrival transit paperwork. |
| Form-Free Transit (`form-free-transit`) | Build 50 Public Train Stop. | Reward a broad public-stop rollout, separate from researching its unlock. |
| Open-Plan Asteroid (`maxed-out-orbital-capacity`) | Research Orbital Mining Capacity 4. | Reward completion of orbital staffing-capacity upgrades. |
| Performance Review (`maxed-out-orbital-damage`) | Research Asteroid Mining Efficiency 5. | Reward completion of orbital mining-efficiency upgrades. |
| Urgent, Please Advise (`speed-demon-arrays`) | Research Trajectory Compliance Speed 9. | Reward the final finite array-speed upgrade; actual cooldown is 1.5 seconds. |
| No Right of Appeal (`executive-jurisdiction`) | Research Executive Asteroid Jurisdiction. | Mark the final asteroid size/range authorisation. |
| Reply All, Across Planets (`chromatic-trunk`) | Research Chromatic Tube Trunk. | Mark coloured interplanetary paperwork transport, separate from Aquilo printing. |
| Vulcanus Export Licensed (`vulcanus-export-licensed`) | Research Vulcanus Export Charters. | Mark permission to export metallurgy beyond Vulcanus. |
| Cyan-Yellow Merged (`cyan-yellow-merged`) | Research Cyan-Yellow Bureaucracy. | Mark access to the Vulcanus/Gleba merged paperwork chain. |
| Cyan-Magenta Merged (`cyan-magenta-merged`) | Research Cyan-Magenta Bureaucracy. | Mark access to the Vulcanus/Fulgora merged paperwork chain. |
| Yellow-Magenta Merged (`yellow-magenta-merged`) | Research Yellow-Magenta Bureaucracy. | Mark access to the Gleba/Fulgora merged paperwork chain. |
| Middle Management (`middle-management`) | Build Personnel Multisign. | Introduce branching personnel routing with the multisign. |
| Per My Last Prompt (`per-my-last-prompt`) | Build AI Server. | Introduce the power-and-heat-driven AI inference server. |
| Procedurally Generated Excuses (`procedurally-generated-excuses`) | Produce 1,000 Administrative Slop in one game. | Reward operation of the inference-to-slop production chain. |
| Manufactured Consent (`manufactured-consent`) | Build Synthetic Personnel Bureau. | Introduce synthesis of specialist personnel. |
| Mandatory Team Building (`mandatory-team-building`) | Build Involuntary Relocation Cannon. | Introduce ballistic personnel and cargo relocation. |

The rethemed native `research-with-promethium` achievement marks using Administratorium science in research, rather than merely producing the pack.

## Validation

- Catalogue checks execute the Lua definitions for base and Space Age, reject identical native goals and all-research conditions, and require complete English/French/Russian names, goal references and descriptions.
- The Factorio startup matrix checks actual target entity/item/capsule existence, visible enabled research, and counted recipe outputs under base, Space Age, and Space Age without Working Hours.
- A runtime unit test checks replay of all seven completed scripted goals and rejects partial/unearned goals.
- Follow-up investigation corrected the standalone fixtures: native rolling stock uses `placeable-off-grid` and a train-only default mask; the recipe fixture needs minimap entities of their real kinds and the native utility-constants table. All 83 Lua suites now pass, including all 60 final-fixes assertions.
- The real-engine startup matrix now also checks that locomotive/wagon masks share no collision layers with rail ramps or supports, while retaining the dedicated managed-biter blocker layer. All three startup configurations pass.
- The 258 supposedly missing GUI keys in each translation already existed under the wrong `[shortcut-name]` section. Moving that section to the end restores full parity: 2,409 English keys covered in French and Russian.
- The local test runner now consistently skips engine-dependent tests without `--factorio-bin`, and leaves save-specific repro scripts to explicit standalone invocation. The complete local runner passes.

The engine checks validate loading and prototype references. They do not simulate unlocking all 84 achievements in a live playthrough. Retargeted goals and the switch to per-game counters can change incomplete progress in existing saves; IDs were retained and no player achievement records are manually reset.
