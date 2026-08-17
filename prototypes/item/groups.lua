local item_icons = "__administratorio__/graphics/icons/"
local feature_flags = require("feature_flags")

-- Item Groups
data:extend({
  {
    type = "item-group",
    name = "admin-paperwork-group",
    order = "za",
    icon = item_icons .. "blank-form.png",
    icon_size = 64
  },
  {
    type = "item-group",
    name = "admin-infrastructure-group",
    order = "zb",
    icon = item_icons .. "office-building.png",
    icon_size = 64
  },
  {
    type = "item-group",
    name = "admin-biter-group",
    order = "zd",
    icon = "__base__/graphics/icons/behemoth-biter.png",
    icon_size = 64
  }
})

-- Subgroups (Paperwork Group) - Organized by workflow stage
data:extend({
  -- Base permits & forms (Tier 0)
  { type = "item-subgroup", name = "admin-base-permits",        group = "admin-paperwork-group", order = "b" },
  -- Tier 1 permits (safety, transit, research)
  { type = "item-subgroup", name = "admin-tier1-permits",       group = "admin-paperwork-group", order = "c" },
  -- Tier 2 permits (construction, management verbal)
  { type = "item-subgroup", name = "admin-tier2-permits",       group = "admin-paperwork-group", order = "d" },
  -- Tier 3 permits (management written, environmental)
  { type = "item-subgroup", name = "admin-tier3-permits",       group = "admin-paperwork-group", order = "e" },
  -- Combined work orders
  { type = "item-subgroup", name = "admin-work-orders",         group = "admin-paperwork-group", order = "f" },
  -- Printed/finalized documents
  { type = "item-subgroup", name = "admin-printed-forms",       group = "admin-paperwork-group", order = "g" },
  -- Gossip & bootstrap economy (watercooler, excuses, data)
  { type = "item-subgroup", name = "admin-gossip-economy",      group = "admin-paperwork-group", order = "h" },
  -- Legacy form subgroups (item display only, still referenced by 60+ items)
  { type = "item-subgroup", name = "forms-base",                group = "admin-paperwork-group", order = "i" },
  { type = "item-subgroup", name = "forms-permits",             group = "admin-paperwork-group", order = "j" },
  { type = "item-subgroup", name = "forms-work-orders",         group = "admin-paperwork-group", order = "k" },
  { type = "item-subgroup", name = "forms-printed",             group = "admin-paperwork-group", order = "l" },
})

-- Subgroups (Infrastructure/Logistics Group)
data:extend({
  { type = "item-subgroup", name = "admin-raw",                 group = "admin-infrastructure-group", order = "a" },
  { type = "item-subgroup", name = "admin-paper-supplies",      group = "admin-infrastructure-group", order = "b" },
  -- Split bs-economy into focused subgroups
  { type = "item-subgroup", name = "admin-data-economy",        group = "admin-infrastructure-group", order = "c" },
  { type = "item-subgroup", name = "admin-fluid-economy",       group = "admin-infrastructure-group", order = "d" },
  { type = "item-subgroup", name = "admin-fluids",              group = "admin-infrastructure-group", order = "d2" },
  { type = "item-subgroup", name = "admin-policy-economy",      group = "admin-infrastructure-group", order = "e" },
  { type = "item-subgroup", name = "admin-money",               group = "admin-infrastructure-group", order = "f" },
  { type = "item-subgroup", name = "admin-infrastructure",      group = "admin-infrastructure-group", order = "g" },
  { type = "item-subgroup", name = "admin-buildings",           group = "admin-infrastructure-group", order = "h" },
  { type = "item-subgroup", name = "admin-printers",            group = "admin-infrastructure-group", order = "i" },
  { type = "item-subgroup", name = "admin-production",          group = "admin-infrastructure-group", order = "j" },
  -- Train stops get their own row so they don't pile into admin-infrastructure
  -- alongside the pneumatic tube network. Registered unconditionally: the
  -- transit permit chest (non-Space-Age) lives here too.
  { type = "item-subgroup", name = "admin-transit",             group = "admin-infrastructure-group", order = "g2" },
})

-- Recycling: folded into the Administrative tab rather than its own tab.
-- Still Recycler-only content (archive recovery, form conversion), just
-- browsable as rows here instead of a dedicated group.
if feature_flags.space_age_enabled() then
  data:extend({
    { type = "item-subgroup", name = "archive-recovery-recipes",    group = "admin-infrastructure-group", order = "k" },
    { type = "item-subgroup", name = "form-reassignment-recipes",   group = "admin-infrastructure-group", order = "k2" },
    { type = "item-subgroup", name = "form-paper-recycling-recipes", group = "admin-infrastructure-group", order = "k3" },
  })
end

-- Space Age: AI infrastructure and involuntary relocation each get their own
-- row so they don't pile into the generic admin-infrastructure subgroup.
if feature_flags.space_age_enabled() then
  data:extend({
    { type = "item-subgroup", name = "admin-ai",                 group = "admin-infrastructure-group", order = "g3" },
    { type = "item-subgroup", name = "admin-relocation",         group = "admin-infrastructure-group", order = "l" },
  })
end

-- Space Age planetary subgroups (Infrastructure group)
if feature_flags.space_age_enabled() then
  data:extend({
    { type = "item-subgroup", name = "admin-planet-gleba",      group = "admin-infrastructure-group", order = "la" },
    { type = "item-subgroup", name = "admin-planet-fulgora",    group = "admin-infrastructure-group", order = "lb" },
    { type = "item-subgroup", name = "admin-planet-vulcanus",   group = "admin-infrastructure-group", order = "lc" },
    { type = "item-subgroup", name = "admin-planet-aquilo",     group = "admin-infrastructure-group", order = "ld" },
    -- Space platform buildings and orbital-only paperwork (vacuum_only
    -- recipes) stay in the vanilla space group, not the Administrative tab.
    { type = "item-subgroup", name = "admin-space-compliance",  group = "space", order = "za" },
    { type = "item-subgroup", name = "admin-space-orbital",     group = "space", order = "zb" },
    { type = "item-subgroup", name = "admin-space-buildings",   group = "space", order = "zc" },
    { type = "item-subgroup", name = "admin-orbital",           group = "space", order = "zd" },
  })
end

-- Biter Group Subgroups
data:extend({
  { type = "item-subgroup", name = "admin-biter-buildings",     group = "admin-biter-group", order = "a" },
  -- Biterport, its chest-buildings, and the logistic biter: the storage/logistics cluster
  { type = "item-subgroup", name = "admin-biter-logistics",     group = "admin-biter-group", order = "a2" },
  { type = "item-subgroup", name = "admin-biter-training",      group = "admin-biter-group", order = "b" },
  { type = "item-subgroup", name = "admin-biter-management",    group = "admin-biter-group", order = "c" },
  { type = "item-subgroup", name = "admin-biter-operations",    group = "admin-biter-group", order = "d" },
})

-- Admin intermediate subgroup in vanilla intermediate-products group
data:extend({
  { type = "item-subgroup", name = "admin-intermediate", group = "intermediate-products", order = "za" },
})

-- Biter complaint resolution subgroups (Military/Combat tab) - KEEP IN COMBAT
data:extend({
  { type = "item-subgroup", name = "resolution-landscape",      group = "combat", order = "za" },
  { type = "item-subgroup", name = "resolution-smog",           group = "combat", order = "zb" },
  { type = "item-subgroup", name = "resolution-noise",          group = "combat", order = "zc" },
  { type = "item-subgroup", name = "resolution-unemployment",   group = "combat", order = "zd" },
  { type = "item-subgroup", name = "resolution-littering",      group = "combat", order = "ze" },
  { type = "item-subgroup", name = "resolution-hazmat",         group = "combat", order = "zf" },
  { type = "item-subgroup", name = "resolution-loitering",      group = "combat", order = "zg" },
  { type = "item-subgroup", name = "resolution-vagrancy",       group = "combat", order = "zh" },
})