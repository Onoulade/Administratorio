local M = {}

function M.should_finish_on_rocket_launch(space_age_enabled)
  return not space_age_enabled
end

function M.record_rocket_launch(stats)
  if not stats then return 0 end
  stats.rockets_launched = (stats.rockets_launched or 0) + 1
  return stats.rockets_launched
end

return M
