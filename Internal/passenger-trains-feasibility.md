# Passenger trains: feasibility and implementation sketch

## Conclusion

Factorio 2.0 can support a dedicated passenger wagon without putting biter items
in a movable inventory. A cloned `cargo-wagon` prototype with `inventory_size = 0`
loaded successfully under Factorio 2.0.77 in a temporary data-stage probe. The
passengers would live in mod storage keyed by the wagon's `unit_number`; the
wagon inventory would contain nothing for players, inserters, or belts to move.

## Proposed flow

1. A boarding platform works only when a train containing a passenger wagon is
   stopped at its associated stop. It selects eligible, currently walking
   complaint visitors within a small boarding radius.
2. Boarding copies each visitor's complaint progress, frustration, identity,
   and home information into a serializable passenger record. It then removes
   the world entity and releases any reserved desk slot. An occupied desk is
   not a boarding source: taking a partially filed case out of a desk needs a
   separate, explicit transfer rule.
3. A bounded periodic update advances the frustration of each onboard record.
   The wagon displays a passenger count and worst frustration. Its contents
   are inaccessible through ordinary cargo operations.
4. A deboarding platform at a stopped train restores entities near the
   platform, reattaches their case state, and routes them to local desks.
   Deboarding waits if no safe spawn position is available; records stay in
   the wagon until restoration succeeds.
5. When any passenger reaches the protest threshold, the entire wagon's
   manifest is removed atomically and every passenger is spawned near the
   wagon and handed to the existing protest controller. If safe positions are
   temporarily unavailable, queue the outbreak and block deboarding until it
   can be completed. Never discard a passenger because a tile is blocked.

## Engine hooks and lifecycle

- `on_train_changed_state` plus `LuaTrain.station` identifies a stopped train
  at a boarding or deboarding platform. `LuaTrain.carriages` finds dedicated
  wagons regardless of their order in the train.
- Key manifests by wagon `unit_number`, not train ID: coupling, splitting,
  and train creation can change train IDs while wagons remain the same.
- Register wagon build, mine, death, clone, and script-raised events. Define
  exact behavior for a loaded wagon removed from the world before shipping.
  The safe default is to prevent manual mining while occupied and to spill
  protesting passengers when destroyed.
- Store primitive case records, not `LuaEntity` references, once boarded.
  Restore all existing complaint bookkeeping carefully: home spawner,
  filed/unfiled tickets, partial resolutions, force, and frustration.
- Use the current biter protest and desk-routing APIs after restoration;
  avoid a second protest implementation.

## Gameplay decision before implementation

The current 10-minute frustration threshold is likely too short for arbitrary
rail trips plus service. The boarding rule should define whether the clock
starts at boarding or continues from its current value, and whether an occupied
wagon has a longer deadline. An explicit deadline in the wagon UI makes the
failure mode readable. Station placement near distant nests still matters for
boarding and deboarding access.

## Evidence

- The supplied save has 12 Administration Desks, 120 total slots, 75 free
  slots, 32 pathfinding visitors, and 4 protesters at load time. The observed
  protesters were about 292 to 426 tiles from their nearest desk.
- A temporary Factorio 2.0.77 prototype probe accepted a cloned cargo wagon
  with zero inventory slots. This proves the no-cargo wagon shape loads, not
  the complete boarding/deboarding behavior.
