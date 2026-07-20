-- The Space Age tree now distributes workforce and orbital recipes across
-- dedicated technologies. Reapply researched effects so existing forces no
-- longer retain stale unlocks from the removed workforce-formation node.
for _, force in pairs(game.forces) do
  force.reset_technology_effects()
end
