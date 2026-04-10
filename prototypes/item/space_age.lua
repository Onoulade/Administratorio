local item_icons = "__administratorio__/graphics/icons/"

data:extend({
  {
    type = "item",
    name = "job-offer",
    icon = "__administratorio__/graphics/icons/management-written-proposal.png",
    icon_size = 64,
    subgroup = "admin-bs-economy",
    order = "j-0",
    stack_size = 20
  },
  {
    type = "item",
    name = "enrolled-biter",
    icon = "__base__/graphics/icons/small-biter.png",
    icon_size = 64,
    subgroup = "admin-bs-economy",
    order = "j-a",
    stack_size = 20
  },
  {
    type = "item",
    name = "worker-biter",
    icon = "__base__/graphics/icons/small-biter.png",
    icon_size = 64,
    subgroup = "admin-bs-economy",
    order = "j-a2",
    stack_size = 20
  },
  {
    type = "item",
    name = "clerical-trainee",
    icon = "__base__/graphics/icons/medium-biter.png",
    icon_size = 64,
    subgroup = "admin-bs-economy",
    order = "j-b",
    stack_size = 20
  },
  {
    type = "item",
    name = "management-trainee",
    icon = "__base__/graphics/icons/big-biter.png",
    icon_size = 64,
    subgroup = "admin-bs-economy",
    order = "j-c",
    stack_size = 20
  },
  {
    type = "item",
    name = "night-shift-supervisor",
    icons = {
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64},
      {icon = item_icons .. "overtime-module.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    subgroup = "admin-bs-economy",
    order = "j-d",
    stack_size = 20
  },
  {
    type = "item",
    name = "licensed-notary",
    icons = {
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64},
      {icon = item_icons .. "construction-permit.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    subgroup = "admin-bs-economy",
    order = "j-e",
    stack_size = 20
  },
  {
    type = "item",
    name = "conciliation-officer",
    icons = {
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64},
      {icon = item_icons .. "promise.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    subgroup = "admin-bs-economy",
    order = "j-f",
    stack_size = 20
  },
  {
    type = "item",
    name = "relay-clerk",
    icons = {
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64},
      {icon = item_icons .. "data.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    subgroup = "admin-bs-economy",
    order = "j-g",
    stack_size = 20
  },
  {
    type = "item",
    name = "cryoprint-technician",
    icons = {
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64},
      {icon = item_icons .. "steel-forge-icon.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    subgroup = "admin-bs-economy",
    order = "j-h",
    stack_size = 20
  },
  {
    type = "item",
    name = "field-negotiator",
    icons = {
      {icon = "__base__/graphics/icons/big-biter.png", icon_size = 64},
      {icon = item_icons .. "eviction-notice.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    subgroup = "admin-bs-economy",
    order = "j-i",
    stack_size = 20
  },
  {
    type = "ammo",
    name = "middle-management-managing-manager",
    icons = {
      {icon = "__base__/graphics/icons/behemoth-biter.png", icon_size = 64},
      {icon = item_icons .. "policy.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    ammo_category = "trajectory-compliance",
    ammo_type = {
      target_type = "entity",
      action = {
        type = "direct",
        action_delivery = {
          type = "instant",
          source_effects = {
            type = "create-explosion",
            entity_name = "explosion-hit",
          },
        },
      },
    },
    magazine_size = 1,
    subgroup = "admin-bs-economy",
    order = "j-j",
    stack_size = 20
  },
  {
    type = "item",
    name = "trajectory-compliance-array",
    icon = "__base__/graphics/icons/radar.png",
    icon_size = 64,
    subgroup = "admin-buildings",
    order = "i",
    place_result = "trajectory-compliance-array",
    stack_size = 20
  },
  {
    type = "item",
    name = "formation-center",
    icon = "__base__/graphics/icons/biter-spawner.png",
    icon_size = 64,
    subgroup = "admin-buildings",
    order = "h",
    place_result = "formation-center",
    stack_size = 20
  },
  {
    type = "item",
    name = "chromatic-printer",
    icon = "__administratorio__/graphics/icons/steel-forge-icon.png",
    icon_size = 64,
    subgroup = "admin-printers",
    order = "d",
    place_result = "chromatic-printer",
    stack_size = 50
  },
  {
    type = "item",
    name = "verdigris-crust",
    icons = {
      {icon = item_icons .. "bullshit-ore.png", icon_size = 64, tint = {r = 0.25, g = 0.9, b = 0.75, a = 1}},
    },
    subgroup = "admin-raw",
    order = "b5",
    stack_size = 100
  },
  {
    type = "item",
    name = "heatproof-form-stock",
    icons = {
      {icon = item_icons .. "blank-form.png", icon_size = 64, tint = {r = 0.75, g = 0.95, b = 0.95, a = 1}},
    },
    subgroup = "forms-printed",
    order = "da",
    stack_size = 100
  },
  {
    type = "item",
    name = "blank-cyan-form",
    icons = {
      {icon = item_icons .. "blank-form.png", icon_size = 64, tint = {r = 0.8, g = 1, b = 1, a = 1}},
      {icon = item_icons .. "ink-cartridge.png", icon_size = 64, scale = 0.35, shift = {8, 8}, tint = {r = 0.1, g = 0.75, b = 0.85, a = 1}},
    },
    subgroup = "forms-printed",
    order = "db",
    stack_size = 100
  },
  {
    type = "item",
    name = "mycelial-form-stock",
    icons = {
      {icon = item_icons .. "blank-form.png", icon_size = 64, tint = {r = 0.95, g = 0.88, b = 0.45, a = 1}},
    },
    subgroup = "forms-printed",
    order = "dc",
    stack_size = 100,
    spoil_ticks = 18000,
    spoil_result = "paper",
  },
  {
    type = "item",
    name = "blank-yellow-form",
    icons = {
      {icon = item_icons .. "blank-form.png", icon_size = 64, tint = {r = 0.98, g = 0.92, b = 0.55, a = 1}},
      {icon = item_icons .. "ink-cartridge.png", icon_size = 64, scale = 0.35, shift = {8, 8}, tint = {r = 0.8, g = 0.72, b = 0.1, a = 1}},
    },
    subgroup = "forms-printed",
    order = "dd",
    stack_size = 100,
    spoil_ticks = 18000,
    spoil_result = "paper",
  },
  {
    type = "item",
    name = "permit-draft",
    icons = {
      {icon = item_icons .. "construction-permit-draft.png", icon_size = 64},
      {icon = item_icons .. "ink-cartridge.png", icon_size = 64, scale = 0.35, shift = {8, 8}, tint = {r = 0.1, g = 0.75, b = 0.85, a = 1}},
    },
    subgroup = "forms-permits",
    order = "de",
    stack_size = 100
  },
  {
    type = "item",
    name = "inspection-docket",
    icons = {
      {icon = item_icons .. "form-27b-6.png", icon_size = 64},
      {icon = item_icons .. "ink-cartridge.png", icon_size = 64, scale = 0.35, shift = {8, 8}, tint = {r = 0.1, g = 0.75, b = 0.85, a = 1}},
    },
    subgroup = "forms-permits",
    order = "df",
    stack_size = 100
  },
  {
    type = "item",
    name = "symbiosis-record",
    icons = {
      {icon = item_icons .. "form-27b-6.png", icon_size = 64},
      {icon = item_icons .. "ink-cartridge.png", icon_size = 64, scale = 0.35, shift = {8, 8}, tint = {r = 0.8, g = 0.72, b = 0.1, a = 1}},
    },
    subgroup = "forms-permits",
    order = "dg",
    stack_size = 100,
    spoil_ticks = 36000,
    spoil_result = "paper",
  },
  {
    type = "item",
    name = "conciliation-order",
    icons = {
      {icon = item_icons .. "construction-permit.png", icon_size = 64},
      {icon = item_icons .. "ink-cartridge.png", icon_size = 64, scale = 0.35, shift = {8, 8}, tint = {r = 0.8, g = 0.72, b = 0.1, a = 1}},
    },
    subgroup = "forms-permits",
    order = "dh",
    stack_size = 100,
    spoil_ticks = 36000,
    spoil_result = "paper",
  },
  {
    type = "item",
    name = "biochamber-operating-waiver",
    icons = {
      {icon = item_icons .. "safety-waiver.png", icon_size = 64},
      {icon = item_icons .. "ink-cartridge.png", icon_size = 64, scale = 0.35, shift = {8, 8}, tint = {r = 0.8, g = 0.72, b = 0.1, a = 1}},
    },
    subgroup = "forms-permits",
    order = "di",
    stack_size = 100,
    spoil_ticks = 36000,
    spoil_result = "paper",
  },
  {
    type = "item",
    name = "embossed-seal",
    icons = {
      {icon = item_icons .. "blank-approval.png", icon_size = 64},
      {icon = item_icons .. "management-approval-written.png", icon_size = 64, scale = 0.35, shift = {8, 8}},
    },
    subgroup = "forms-permits",
    order = "dj",
    stack_size = 100
  },
  {
    type = "item",
    name = "industrial-charter",
    icons = {
      {icon = item_icons .. "construction-permit.png", icon_size = 64},
      {icon = item_icons .. "steel-forge-icon.png", icon_size = 64, scale = 0.35, shift = {8, 8}},
    },
    subgroup = "forms-permits",
    order = "dk",
    stack_size = 100
  },
  {
    type = "item",
    name = "thermal-process-license",
    icons = {
      {icon = item_icons .. "construction-permit.png", icon_size = 64},
      {icon = item_icons .. "steel-forge-icon.png", icon_size = 64, scale = 0.35, shift = {8, 8}},
    },
    subgroup = "forms-permits",
    order = "dl",
    stack_size = 100
  },
  {
    type = "item",
    name = "calcite-reagent-waiver",
    icons = {
      {icon = item_icons .. "safety-waiver.png", icon_size = 64},
      {icon = item_icons .. "ink-cartridge.png", icon_size = 64, scale = 0.35, shift = {8, 8}, tint = {r = 0.1, g = 0.75, b = 0.85, a = 1}},
    },
    subgroup = "forms-permits",
    order = "dm",
    stack_size = 100
  },
  {
    type = "item",
    name = "offworld-metallurgy-charter",
    icons = {
      {icon = item_icons .. "management-approval-written.png", icon_size = 64},
      {icon = item_icons .. "steel-forge-icon.png", icon_size = 64, scale = 0.35, shift = {8, 8}},
    },
    subgroup = "forms-permits",
    order = "dn",
    stack_size = 100
  },
  {
    type = "item",
    name = "capture-bureau",
    icons = {
      {icon = item_icons .. "admin-desk.png", icon_size = 64},
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64, scale = 0.35, shift = {8, 8}},
    },
    subgroup = "admin-buildings",
    order = "j",
    place_result = "capture-bureau",
    stack_size = 20
  },
  {
    type = "item",
    name = "conciliation-desk",
    icon = "__administratorio__/graphics/icons/promise.png",
    icon_size = 64,
    subgroup = "admin-buildings",
    order = "k",
    place_result = "conciliation-desk",
    stack_size = 20
  },
  {
    type = "item",
    name = "notary-office",
    icon = "__administratorio__/graphics/icons/management-approval-written.png",
    icon_size = 64,
    subgroup = "admin-buildings",
    order = "j",
    place_result = "notary-office",
    stack_size = 20
  },
})
