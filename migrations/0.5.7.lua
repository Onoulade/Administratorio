-- Reapply researched technology effects so established forces receive the new
-- deviation-order and orbital-employment-cannon recipe unlocks.
for _, force in pairs(game.forces) do
  force.reset_technology_effects()
end
