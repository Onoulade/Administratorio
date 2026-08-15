local item_icons = "__administratorio__/graphics/icons/"
local manager_briefings = require("prototypes.shared.manager_briefings")
local building_icons = require("prototypes.shared.building_icons")

local briefing_overlay_icons = {
  training = "__base__/graphics/icons/iron-gear-wheel.png",
  staffing = "__base__/graphics/icons/repair-pack.png",
  compliance = item_icons .. "blank-form.png",
  liaison = "__base__/graphics/icons/electronic-circuit.png",
  orbital = "__base__/graphics/icons/rocket-fuel.png",
}

local manager_items = {
  {
    type = "item",
    name = manager_briefings.REGULAR_MANAGER,
    icons = {
      {icon = "__base__/graphics/icons/behemoth-biter.png", icon_size = 64},
      {icon = item_icons .. "policy.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    subgroup = "admin-biter-management",
    order = "j-j",
    stack_size = 20,
  },
}

for _, briefing in ipairs(manager_briefings.BRIEFINGS) do
  manager_items[#manager_items + 1] = {
    type = "item",
    name = briefing.item,
    icons = {
      {icon = "__base__/graphics/icons/behemoth-biter.png", icon_size = 64},
      {icon = briefing_overlay_icons[briefing.key], icon_size = 64, scale = 0.42, shift = {8, 8}},
    },
    subgroup = "admin-biter-management",
    order = briefing.order,
    stack_size = 5,
    spoil_ticks = manager_briefings.SPOIL_TICKS,
    spoil_result = manager_briefings.REGULAR_MANAGER,
  }
end

data:extend(manager_items)

data:extend({
  {
    type = "item",
    name = "job-offer",
    icons = {{icon = item_icons .. "blank-form.png", icon_size = 64, tint = {r = 0.4, g = 0.9, b = 0.4, a = 1}}},
    subgroup = "admin-biter-employees",
    order = "j-0",
    stack_size = 20
  },
  {
    type = "item",
    name = "enrolled-biter",
    icons = {
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64, tint = {r = 0.68, g = 0.82, b = 1, a = 1}},
      {icon = item_icons .. "blank-approval.png", icon_size = 64, scale = 0.32, shift = {8, 8}},
    },
    subgroup = "admin-biter-employees",
    order = "j-a",
    stack_size = 20
  },
  {
    type = "item",
    name = "worker-biter",
    icons = {
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64, tint = {r = 0.62, g = 1, b = 0.62, a = 1}},
      {icon = item_icons .. "work-order.png", icon_size = 64, scale = 0.32, shift = {8, 8}},
    },
    subgroup = "admin-biter-employees",
    order = "j-a2",
    stack_size = 20
  },
  {
    type = "item",
    name = "clerical-trainee",
    icons = {
      {icon = "__base__/graphics/icons/medium-biter.png", icon_size = 64, tint = {r = 0.72, g = 0.88, b = 1, a = 1}},
      {icon = item_icons .. "paper.png", icon_size = 64, scale = 0.32, shift = {8, 8}},
    },
    subgroup = "admin-biter-employees",
    order = "j-b",
    stack_size = 20
  },
  {
    type = "item",
    name = "management-trainee",
    icons = {
      {icon = "__base__/graphics/icons/big-biter.png", icon_size = 64, tint = {r = 1, g = 0.72, b = 0.34, a = 1}},
      {icon = item_icons .. "policy.png", icon_size = 64, scale = 0.32, shift = {8, 8}},
    },
    subgroup = "admin-biter-employees",
    order = "j-c",
    stack_size = 20
  },
  {
    type = "item",
    name = "astronaut",
    icons = {
      {icon = "__base__/graphics/icons/big-biter.png", icon_size = 64},
      {icon = item_icons .. "transit-authorization.png", icon_size = 64, scale = 0.35, shift = {8, 8}},
    },
    subgroup = "admin-biter-employees",
    order = "j-c1",
    stack_size = 20
  },
  {
    type = "item",
    name = "licensed-notary",
    icons = {
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64},
      {icon = item_icons .. "construction-permit.png", icon_size = 64, scale = 0.5, shift = {8, 8}},
    },
    subgroup = "admin-biter-operations",
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
    subgroup = "admin-biter-operations",
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
    subgroup = "admin-biter-operations",
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
    subgroup = "admin-biter-operations",
    order = "j-h",
    stack_size = 20
  },
  {
    type = "ammo",
    name = "orbital-deviation-order",
    icons = {
      {icon = item_icons .. "management-approval-written.png", icon_size = 64},
      {icon = "__base__/graphics/icons/radar.png", icon_size = 64, scale = 0.35, shift = {8, 8}},
    },
    ammo_category = "trajectory-compliance",
    ammo_type = {
      target_type = "entity",
      action = {
        type = "direct",
        action_delivery = {
          type = "instant",
          target_effects = {
            {type = "script", effect_id = "administratorio-trajectory-deviation", affects_target = true},
            {type = "create-explosion", entity_name = "explosion-hit"},
          },
        },
      },
    },
    magazine_size = 1,
    subgroup = "admin-space-compliance",
    order = "j-i",
    stack_size = 100
  },
  {
    type = "ammo",
    name = "priority-orbital-deviation-order",
    icons = {
      {icon = item_icons .. "management-approval-written.png", icon_size = 64, tint = {r = 1, g = 0.35, b = 0.25, a = 1}},
      {icon = "__base__/graphics/icons/radar.png", icon_size = 64, scale = 0.35, shift = {8, 8}},
    },
    ammo_category = "trajectory-compliance",
    ammo_type = {
      target_type = "entity",
      action = {
        type = "direct",
        action_delivery = {
          type = "instant",
          target_effects = {
            {type = "script", effect_id = "administratorio-priority-trajectory-deviation", affects_target = true},
            {type = "create-explosion", entity_name = "explosion-hit"},
          },
        },
      },
    },
    magazine_size = 1,
    subgroup = "admin-space-compliance",
    order = "j-i2",
    stack_size = 100
  },
  -- Voluntary Exploration Space Miners inherit the former orbital employee
  -- deployment behavior. Managers now remain in the factory, where they can
  -- attend meetings and obstruct otherwise useful workforce processes.
  {
    type = "ammo",
    name = manager_briefings.VESM,
    icons = {
      {icon = "__base__/graphics/icons/behemoth-biter.png", icon_size = 64},
      {icon = "__base__/graphics/icons/electric-mining-drill.png", icon_size = 64, scale = 0.42, shift = {8, 8}},
    },
    ammo_category = "orbital-biter-ballistics",
    ammo_type = {
      target_type = "entity",
      action = {
        type = "direct",
        action_delivery = {
          {
            type = "projectile",
            projectile = "orbital-biter-projectile",
            starting_speed = 0.36,
            source_effects = {
              {
                type = "create-explosion",
                entity_name = "explosion-gunshot",
                only_when_visible = true,
              },
            },
          },
          {
            type = "instant",
            target_effects = {
              {
                type = "script",
                effect_id = "administratorio-asteroid-biter-launched",
                affects_target = true,
              },
            },
          },
        },
      },
    },
    magazine_size = 1,
    subgroup = "admin-biter-management",
    order = "j-j",
    stack_size = 20
  },
  {
    type = "item",
    name = "trajectory-compliance-array",
    icons = building_icons.trajectory_array("junior"),
    subgroup = "admin-space-compliance",
    order = "i",
    place_result = "trajectory-compliance-array",
    stack_size = 20
  },
  {
    type = "item",
    name = "senior-trajectory-compliance-array",
    icons = building_icons.trajectory_array("senior"),
    subgroup = "admin-space-compliance",
    order = "i-b",
    place_result = "senior-trajectory-compliance-array",
    stack_size = 20
  },
  {
    type = "item",
    name = "executive-trajectory-compliance-array",
    icons = building_icons.trajectory_array("executive"),
    subgroup = "admin-space-compliance",
    order = "i-c",
    place_result = "executive-trajectory-compliance-array",
    stack_size = 20
  },
  {
    type = "item",
    name = "orbital-employment-cannon",
    icons = {
      {icon = "__space-age__/graphics/icons/railgun-turret.png", icon_size = 64},
      {icon = "__base__/graphics/icons/electric-mining-drill.png", icon_size = 64, scale = 0.38, shift = {8, 8}},
    },
    subgroup = "admin-space-orbital",
    order = "i-d",
    place_result = "orbital-employment-cannon",
    stack_size = 10
  },
  {
    type = "item",
    name = "chromatic-printer",
    icon = item_icons .. "space-age/chromatic-printer.png",
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
    name = "charged-toner",
    icons = {
      {icon = item_icons .. "data.png", icon_size = 64},
      {icon = item_icons .. "ink-cartridge.png", icon_size = 64, scale = 0.35, shift = {8, 8}, tint = {r = 0.85, g = 0.18, b = 0.65, a = 1}},
    },
    subgroup = "admin-raw",
    order = "b6",
    stack_size = 100
  },
  {
    type = "item",
    name = "transfer-emulsion",
    icons = {
      {icon = item_icons .. "ink-cartridge.png", icon_size = 64, tint = {r = 0.72, g = 0.9, b = 1, a = 1}},
      {icon = item_icons .. "data.png", icon_size = 64, scale = 0.3, shift = {8, 8}, tint = {r = 0.82, g = 0.95, b = 1, a = 1}},
    },
    subgroup = "admin-paper-supplies",
    order = "c1",
    stack_size = 100
  },
  {
    type = "item",
    name = "thermal-transfer-sheet",
    icons = {
      {icon = item_icons .. "blank-form.png", icon_size = 64, tint = {r = 0.88, g = 0.95, b = 1, a = 1}},
      {icon = item_icons .. "ink-cartridge.png", icon_size = 64, scale = 0.3, shift = {8, 8}, tint = {r = 0.72, g = 0.9, b = 1, a = 1}},
    },
    subgroup = "admin-paper-supplies",
    order = "c2",
    stack_size = 100
  },
  {
    type = "item",
    name = "composite-chroma-ribbon",
    icons = {
      {icon = item_icons .. "ink-cartridge.png", icon_size = 64, tint = {r = 0.92, g = 0.92, b = 0.98, a = 1}},
      {icon = item_icons .. "ink-cartridge.png", icon_size = 64, scale = 0.25, shift = {-8, 8}, tint = {r = 0.1, g = 0.75, b = 0.85, a = 1}},
      {icon = item_icons .. "ink-cartridge.png", icon_size = 64, scale = 0.25, shift = {0, 8}, tint = {r = 0.8, g = 0.72, b = 0.1, a = 1}},
      {icon = item_icons .. "ink-cartridge.png", icon_size = 64, scale = 0.25, shift = {8, 8}, tint = {r = 0.85, g = 0.18, b = 0.65, a = 1}},
    },
    subgroup = "admin-paper-supplies",
    order = "c3",
    stack_size = 100
  },
  {
    type = "item",
    name = "heatproof-form-stock",
    icon = item_icons .. "heatproof-form-stock.png",
    icon_size = 64,
    subgroup = "forms-printed",
    order = "da",
    stack_size = 100
  },
  {
    type = "item",
    name = "blank-cyan-form",
    icon = item_icons .. "blank-cyan-form.png",
    icon_size = 64,
    subgroup = "forms-printed",
    order = "db",
    stack_size = 100
  },
  {
    type = "item",
    name = "mycelial-form-stock",
    icon = item_icons .. "mycelial-form-stock.png",
    icon_size = 64,
    subgroup = "forms-printed",
    order = "dc",
    stack_size = 100,
    spoil_ticks = 18000,
    spoil_result = "paper",
  },
  {
    type = "item",
    name = "blank-yellow-form",
    icon = item_icons .. "blank-yellow-form.png",
    icon_size = 64,
    subgroup = "forms-printed",
    order = "dd",
    stack_size = 100,
    spoil_ticks = 18000,
    spoil_result = "paper",
  },
  {
    type = "item",
    name = "signal-form-stock",
    icon = item_icons .. "signal-form-stock.png",
    icon_size = 64,
    subgroup = "forms-printed",
    order = "dde",
    stack_size = 100
  },
  {
    type = "item",
    name = "blank-magenta-form",
    icon = item_icons .. "blank-magenta-form.png",
    icon_size = 64,
    subgroup = "forms-printed",
    order = "ddf",
    stack_size = 100
  },
  {
    type = "item",
    name = "cyan-yellow-form",
    icon = item_icons .. "cyan-yellow-form.png",
    icon_size = 64,
    subgroup = "forms-printed",
    order = "ddg",
    stack_size = 100
  },
  {
    type = "item",
    name = "cyan-magenta-form",
    icon = item_icons .. "cyan-magenta-form.png",
    icon_size = 64,
    subgroup = "forms-printed",
    order = "ddh",
    stack_size = 100
  },
  {
    type = "item",
    name = "yellow-magenta-form",
    icon = item_icons .. "yellow-magenta-form.png",
    icon_size = 64,
    subgroup = "forms-printed",
    order = "ddi",
    stack_size = 100
  },
  {
    type = "item",
    name = "permit-draft",
    icon = item_icons .. "permit-draft.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "de",
    stack_size = 100
  },
  {
    type = "item",
    name = "inspection-docket",
    icon = item_icons .. "inspection-docket.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "df",
    stack_size = 100
  },
  {
    type = "item",
    name = "symbiosis-record",
    icon = item_icons .. "symbiosis-record.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dg",
    stack_size = 100,
    spoil_ticks = 36000,
    spoil_result = "paper",
  },
  {
    type = "item",
    name = "conciliation-order",
    icon = item_icons .. "conciliation-order.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dh",
    stack_size = 100,
    spoil_ticks = 36000,
    spoil_result = "paper",
  },
  {
    type = "item",
    name = "archive-recovery-permit",
    icon = item_icons .. "archive-recovery-permit.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dia",
    stack_size = 100
  },
  {
    type = "item",
    name = "digital-processing-certificate",
    icon = item_icons .. "digital-processing-certificate.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dib",
    stack_size = 100
  },
  {
    type = "item",
    name = "electromagnetic-operating-license",
    icon = item_icons .. "electromagnetic-operating-license.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dic",
    stack_size = 100
  },
  {
    type = "item",
    name = "data-recovery-order",
    icon = item_icons .. "data-recovery-order.png",
    icon_size = 64,
    subgroup = "forms-work-orders",
    order = "cid",
    stack_size = 100
  },
  {
    type = "item",
    name = "hardened-data-vault",
    icon = item_icons .. "hardened-data-vault.png",
    icon_size = 64,
    subgroup = "forms-work-orders",
    order = "cie",
    stack_size = 100
  },
  {
    type = "item",
    name = "trichromatic-permit",
    icon = item_icons .. "trichromatic-permit.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "die",
    stack_size = 100
  },
  {
    type = "item",
    name = "unified-operations-charter",
    icon = item_icons .. "unified-operations-charter.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dif",
    stack_size = 100
  },
  {
    type = "item",
    name = "public-transportation-contract",
    icon = item_icons .. "public-transportation-contract.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dig",
    stack_size = 100
  },
  {
    type = "item",
    name = "cryogenic-operations-license",
    icon = item_icons .. "cryogenic-operations-license.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dig",
    stack_size = 100
  },
  {
    type = "item",
    name = "promethium-research-charter",
    icon = item_icons .. "promethium-research-charter.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dih",
    stack_size = 100
  },
  {
    type = "item",
    name = "embossed-seal",
    icon = item_icons .. "embossed-seal.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dj",
    stack_size = 100
  },
  {
    type = "item",
    name = "industrial-charter",
    icon = item_icons .. "industrial-charter.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dk",
    stack_size = 100
  },
  {
    type = "item",
    name = "territorial-resettlement-order",
    icon = item_icons .. "territorial-resettlement-order.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dk1",
    stack_size = 100
  },
  {
    type = "item",
    name = "territorial-deed",
    icon = item_icons .. "territorial-deed.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dk2",
    stack_size = 100
  },
  {
    type = "item",
    name = "thermal-process-license",
    icon = item_icons .. "thermal-process-license.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dl",
    stack_size = 100
  },
  {
    type = "item",
    name = "calcite-reagent-waiver",
    icon = item_icons .. "calcite-reagent-waiver.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dm",
    stack_size = 100
  },
  {
    type = "item",
    name = "offworld-metallurgy-charter",
    icon = item_icons .. "offworld-metallurgy-charter.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dn",
    stack_size = 100
  },
  {
    type = "item",
    name = "orbital-operations-form",
    icons = {
      {icon = item_icons .. "blank-form.png", icon_size = 64, tint = {r = 0.55, g = 0.8, b = 1, a = 1}},
      {icon = "__space-age__/graphics/icons/space-platform-foundation.png", icon_size = 64, scale = 0.32, shift = {8, 8}},
    },
    subgroup = "forms-permits",
    order = "dn1",
    stack_size = 200
  },
  {
    type = "item",
    name = "asteroid-processing-docket",
    icon = item_icons .. "asteroid-processing-docket.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "do",
    stack_size = 100
  },
  {
    type = "item",
    name = "orbital-infrastructure-permit",
    icon = item_icons .. "orbital-infrastructure-permit.png",
    icon_size = 64,
    subgroup = "forms-permits",
    order = "dp",
    stack_size = 100
  },
  {
    type = "item",
    name = "capture-bureau",
    icons = {
      {icon = item_icons .. "admin-desk.png", icon_size = 64},
      {icon = "__base__/graphics/icons/small-biter.png", icon_size = 64, scale = 0.35, shift = {8, 8}},
    },
    subgroup = "admin-biter-buildings",
    order = "j",
    place_result = "capture-bureau",
    stack_size = 20
  },
  {
    type = "item",
    name = "conciliation-desk",
    icon = item_icons .. "space-age/conciliation-desk.png",
    icon_size = 64,
    subgroup = "admin-biter-buildings",
    order = "k",
    place_result = "conciliation-desk",
    stack_size = 20
  },
  {
    type = "item",
    name = "territorial-arbitration-post",
    icon = item_icons .. "space-age/territorial-arbitration-post.png",
    icon_size = 64,
    subgroup = "admin-buildings",
    order = "k1",
    place_result = "territorial-arbitration-post",
    stack_size = 20
  },
  {
    type = "item",
    name = "digital-services-bureau",
    icon = item_icons .. "space-age/digital-services-bureau.png",
    icon_size = 64,
    subgroup = "admin-buildings",
    order = "l",
    place_result = "digital-services-bureau",
    stack_size = 20
  },
  {
    type = "item",
    name = "laser-printer",
    icon = item_icons .. "space-age/laser-printer.png",
    icon_size = 64,
    subgroup = "admin-buildings",
    order = "m",
    place_result = "laser-printer",
    stack_size = 20
  },
  {
    type = "item",
    name = "administrative-space-station",
    icon = item_icons .. "space-age/administrative-space-station.png",
    icon_size = 64,
    subgroup = "admin-space-buildings",
    order = "m1",
    place_result = "administrative-space-station",
    stack_size = 20
  },
  {
    type = "item",
    name = "interplanetary-terminus",
    icon = item_icons .. "space-age/interplanetary-terminus.png",
    icon_size = 64,
    subgroup = "admin-space-buildings",
    order = "n",
    place_result = "interplanetary-terminus",
    stack_size = 20
  },
  {
    type = "item",
    name = "notary-office",
    icon = item_icons .. "space-age/notary-office.png",
    icon_size = 64,
    subgroup = "admin-buildings",
    order = "j",
    place_result = "notary-office",
    stack_size = 20
  },
  {
    type = "item",
    name = "public-train-stop",
    icons = building_icons.public_train_stop(),
    subgroup = "admin-infrastructure",
    order = "z",
    place_result = "public-train-stop",
    stack_size = 10
  },
})

-- The base building loader owns this item. Keep a standalone fallback for
-- isolated Space Age prototype tests without overwriting its custom icon in
-- the real load order.
if not (data.raw.item and data.raw.item["formation-center"]) then
  data:extend({
    {
      type = "item",
      name = "formation-center",
      icon = item_icons .. "formation-center.png",
      icon_size = 64,
      subgroup = "admin-biter-buildings",
      order = "d",
      place_result = "formation-center",
      stack_size = 20,
    },
  })
end

local SPACE_TOURISM_VARIANTS = {
  {spitter = "small-spitter", package_item = "small-spitter-tourism-package", tourist_item = "small-space-tourist", order = "j-k1"},
  {spitter = "medium-spitter", package_item = "medium-spitter-tourism-package", tourist_item = "medium-space-tourist", order = "j-k2"},
  {spitter = "big-spitter", package_item = "big-spitter-tourism-package", tourist_item = "big-space-tourist", order = "j-k3"},
  {spitter = "behemoth-spitter", package_item = "behemoth-spitter-tourism-package", tourist_item = "behemoth-space-tourist", order = "j-k4"},
}

local function spitter_icon_layers(spitter_name, overlays)
  local icons = {
    {icon = "__base__/graphics/icons/" .. spitter_name .. ".png", icon_size = 64},
  }
  for _, overlay in ipairs(overlays) do
    icons[#icons + 1] = overlay
  end
  return icons
end

local tourism_items = {}

tourism_items[#tourism_items + 1] = {
  type = "item",
  name = "capture-bureau-processing-token",
  icons = {
    {icon = item_icons .. "admin-desk.png", icon_size = 64, tint = {r = 1, g = 0.68, b = 0.46, a = 1}},
  },
  hidden = true,
  hidden_in_factoriopedia = true,
  stack_size = 1,
}

tourism_items[#tourism_items + 1] = {
  type = "item",
  name = "captured-pentapod-specimen",
  icons = {
    {icon = item_icons .. "admin-desk.png", icon_size = 64, tint = {r = 0.75, g = 1, b = 0.7, a = 1}},
    {icon = "__space-age__/graphics/icons/pentapod-egg.png", icon_size = 64, scale = 0.4, shift = {8, 8}},
  },
  localised_name = {"", "Captured Pentapod Specimen"},
  localised_description = {
    "",
    "Internal Gleba hostile-acquisitions stock. The ",
    {"entity-name.capture-bureau"},
    " converts it into eggs.",
  },
  hidden = true,
  hidden_in_factoriopedia = true,
  stack_size = 20,
}

for _, variant in ipairs(SPACE_TOURISM_VARIANTS) do
  tourism_items[#tourism_items + 1] = {
    type = "item",
    name = variant.package_item,
    icons = spitter_icon_layers(variant.spitter, {
      {icon = item_icons .. "admin-desk.png", icon_size = 64, scale = 0.32, shift = {-8, 8}},
      {icon = item_icons .. "transit-authorization.png", icon_size = 64, scale = 0.3, shift = {8, 8}},
    }),
    localised_name = {"", {"entity-name." .. variant.spitter}, " Tourism Package"},
    localised_description = {
      "",
      "Captured for orbital sightseeing. It spoils like an egg, so launch it fast and process it at an ",
      {"entity-name.administrative-space-station"},
      " before it hatches back into an angry spitter.",
    },
    subgroup = "admin-bs-economy",
    order = variant.order,
    stack_size = 20,
    spoil_ticks = 18000,
    spoil_to_trigger_result = {
      items_per_trigger = 1,
      trigger = {
        type = "direct",
        action_delivery = {
          type = "instant",
          source_effects = {
            {type = "script", effect_id = "administratorio-" .. variant.spitter .. "-tourism-hatch"},
          },
        },
      },
    },
  }

  tourism_items[#tourism_items + 1] = {
    type = "item",
    name = variant.tourist_item,
    icons = spitter_icon_layers(variant.spitter, {
      {icon = item_icons .. "office-building.png", icon_size = 64, scale = 0.3, shift = {-8, 8}},
      {icon = item_icons .. "taxpayer-money.png", icon_size = 64, scale = 0.32, shift = {8, 8}},
    }),
    localised_name = {"", {"entity-name." .. variant.spitter}, " Space Tourist"},
    localised_description = {
      "",
      "Already paid up. Return it to a Nauvis administrative desk so it can wander off and complete the tour.",
    },
    subgroup = "admin-bs-economy",
    order = variant.order .. "a",
    stack_size = 20,
  }
end

data:extend(tourism_items)
