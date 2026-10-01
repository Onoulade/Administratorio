local M = {}

local metrics = require("scripts.metrics")

M.SECTIONS = {
  {
    caption = "gui.win-section-department",
    rows = {
      {caption = "gui.stat-rockets-launched", metric = "rockets_launched"},
      {caption = "gui.stat-cases-resolved", metric = "cases_resolved"},
      {caption = "gui.stat-complaints-resolved", metric = "complaints_resolved"},
      {caption = "gui.stat-money-earned", metric = "money_earned"},
      {caption = "gui.stat-forms-crafted", derived = "forms_crafted"},
      {caption = "gui.stat-workers-hired", metric = "biters_hired"},
      {caption = "gui.stat-tourists-served", metric = "tourists_served", space_age = true},
      {caption = "gui.stat-field-office-shifts", metric = "field_office_shifts"},
      {caption = "gui.stat-managed-crafts", metric = "managed_crafts"},
    },
  },
  {
    caption = "gui.win-section-logistics",
    rows = {
      {caption = "gui.stat-pneumatic-items-delivered", metric = "pneumatic_items_delivered"},
      {caption = "gui.stat-passenger-trips-completed", metric = "passenger_trips_completed"},
      {caption = "gui.stat-personnel-routed", metric = "personnel_routed"},
      {caption = "gui.stat-biterport-items-delivered", metric = "biterport_items_delivered"},
      {caption = "gui.stat-biterport-constructions", metric = "biterport_constructions"},
      {caption = "gui.stat-biterport-deconstructions", metric = "biterport_deconstructions"},
    },
  },
  {
    caption = "gui.win-section-enforcement",
    rows = {
      {caption = "gui.stat-protests-suppressed", metric = "protests_suppressed"},
      {caption = "gui.stat-nests-evicted", metric = "nests_evicted"},
      {caption = "gui.stat-nests-calmed", metric = "nests_calmed"},
      {caption = "gui.stat-eviction-notices-delivered", metric = "eviction_notices_delivered"},
    },
  },
  {
    caption = "gui.win-section-offworld",
    space_age = true,
    rows = {
      {caption = "gui.stat-interplanetary-items-delivered", metric = "interplanetary_items_delivered"},
      {caption = "gui.stat-personnel-relocated", metric = "personnel_relocated"},
      {caption = "gui.stat-territories-arbitrated", metric = "territories_arbitrated"},
      {caption = "gui.stat-trajectory-orders-issued", metric = "trajectory_orders_issued"},
      {caption = "gui.stat-asteroids-processed", metric = "asteroids_processed"},
    },
  },
}

function M.should_finish_on_rocket_launch(space_age_enabled)
  return not space_age_enabled
end

function M.record_rocket_launch(stats)
  if not stats then return 0 end
  return metrics.increment(stats, "rockets_launched", 1)
end

function M.rows_for_section(section, stats, forms_crafted, space_age_enabled)
  local rows = {}
  if section.space_age and not space_age_enabled then return rows end
  for _, row in ipairs(section.rows) do
    if not row.space_age or space_age_enabled then
      rows[#rows + 1] = {
        caption = row.caption,
        value = row.derived == "forms_crafted" and forms_crafted or (stats[row.metric] or 0),
      }
    end
  end
  return rows
end

return M
