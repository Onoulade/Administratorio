-- The Orbital Employment Cannon is now the Orbital Employment Catapult.
-- Carry over any catapults that were mid-retarget (paused with no eligible
-- asteroid) so they keep being rechecked instead of staying disabled forever
-- under a storage key nothing reads anymore.
local state = storage.trajectory_compliance
if state and state.blocked_cannons then
  state.blocked_catapults = state.blocked_catapults or {}
  for unit_number, entity in pairs(state.blocked_cannons) do
    state.blocked_catapults[unit_number] = entity
  end
  state.blocked_cannons = nil
end
