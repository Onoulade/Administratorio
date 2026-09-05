local function item(name, amount)
  return {type = "item", name = name, amount = amount}
end

local function fluid(name, amount)
  return {type = "fluid", name = name, amount = amount}
end

local feature_flags = require("feature_flags")

local function append_all(target, values)
  if not values then return end
  for _, value in ipairs(values) do
    target[#target + 1] = value
  end
end

local function subgroup_for_slug(slug)
  if slug == "landscape" then return "resolution-landscape" end
  if slug == "smog" then return "resolution-smog" end
  if slug == "noise" then return "resolution-noise" end
  if slug == "unemployment" then return "resolution-unemployment" end
  if slug == "littering" then return "resolution-littering" end
  if slug == "hazmat" then return "resolution-hazmat" end
  if slug == "loitering" then return "resolution-loitering" end
  if slug == "vagrancy" then return "resolution-vagrancy" end
  return "resolution-landscape"
end

local function order_for_stage(stage_type)
  -- stage_type: "filing", "case", "brief", "final"
  if stage_type == "filing" then return "a" end
  if stage_type == "case" then return "b" end
  if stage_type == "brief" then return "c" end
  if stage_type == "final" then return "d" end
  return "z"
end

local function make_resolution_recipe(name, ingredients, result_name, energy_required, category, slug, stage_type)
  return {
    type = "recipe",
    name = name,
    category = category or "bureaucracy-resolution",
    enabled = false,
    subgroup = subgroup_for_slug(slug),
    order = order_for_stage(stage_type),
    ingredients = ingredients,
    results = {{type = "item", name = result_name, amount = 1}},
    energy_required = energy_required,
  }
end

local function build_stage_pipeline(stage, filing_energy)
  local recipes = {}
  local category = stage.category or "bureaucracy-resolution"
  local slug = stage.slug

  -- Filing
  recipes[#recipes + 1] = make_resolution_recipe(
    "filing-" .. slug,
    {item(stage.ticket, 1), item("blank-form", 1)},
    stage.filing,
    filing_energy,
    category,
    slug,
    "filing"
  )

  -- Case (optional)
  if stage.case then
    local case_ingredients = {item(stage.filing, 1)}
    append_all(case_ingredients, stage.case.ingredients)
    recipes[#recipes + 1] = make_resolution_recipe(
      "case-" .. slug,
      case_ingredients,
      stage.case.result,
      stage.case.energy,
      category,
      slug,
      "case"
    )
  end

  -- Brief (optional)
  if stage.brief and stage.case then
    local brief_ingredients = {item(stage.case.result, 1)}
    append_all(brief_ingredients, stage.brief.ingredients)
    recipes[#recipes + 1] = make_resolution_recipe(
      "brief-" .. slug,
      brief_ingredients,
      stage.brief.result,
      stage.brief.energy,
      category,
      slug,
      "brief"
    )
  end

  -- Final (always present)
  local final_source = stage.case and stage.case.result or stage.filing
  local final_ingredients = {item(final_source, 1)}
  append_all(final_ingredients, stage.final.ingredients)
  recipes[#recipes + 1] = make_resolution_recipe(
    slug .. "-final",
    final_ingredients,
    stage.final.result,
    stage.final.energy,
    category,
    slug,
    "final"
  )

  return recipes
end

-- Complaint pipelines are organized by paired severity tiers so the biter and
-- spitter tracks stay structurally aligned and easy to rebalance together.
local PAIRED_PIPELINES = {
  -- Tier 1: direct filing -> final
  {
    filing_energy = 5,
    biter = {
      slug = "landscape",
      category = "resolution-handcraft",
      ticket = "ticket-landscape",
      filing = "filing-l",
      final = {
        result = "resolved-landscape",
        ingredients = {item("basic-excuse", 1)},
        energy = 5,
      },
    },
    spitter = {
      slug = "littering",
      -- Littering is the first spitter complaint and unlocks before the
      -- staffed Resolution Office exists. Keep both stages hand-craftable so
      -- this bootstrap complaint cannot wait on worker formation.
      category = "resolution-handcraft",
      ticket = "ticket-littering",
      filing = "filing-lt",
      final = {
        result = "resolved-littering",
        ingredients = {item("crappy-report", 1)},
        energy = 7,
      },
    },
  },
  -- Tier 2: filing -> case -> final
  {
    filing_energy = 10,
    biter = {
      slug = "smog",
      ticket = "ticket-smog",
      filing = "filing-s",
      case = {
        result = "case-s",
        ingredients = {
          item("paper", 10),
          item("coal", 2),
          item("redundant-rubble", 2),
        },
        energy = 15,
      },
      final = {
        result = "resolved-smog",
        ingredients = {
          fluid("misinformation", 50),
          fluid("liquid-coffee", 50),
        },
        energy = 20,
      },
    },
    spitter = {
      slug = "hazmat",
      ticket = "ticket-hazmat",
      filing = "filing-h",
      case = {
        result = "case-h",
        ingredients = {
          item("paper", 8),
          item("barrel", 1),
          item("compacted-rubble", 2),
        },
        energy = 15,
      },
      final = {
        result = "resolved-hazmat",
        ingredients = {
          fluid("misinformation", 40),
          fluid("liquid-coffee", 60),
        },
        energy = 20,
      },
    },
  },
  -- Tier 3: filing -> case -> brief -> final (finals resolve from case stage)
  {
    filing_energy = 15,
    biter = {
      slug = "noise",
      ticket = "ticket-noise",
      filing = "filing-n",
      case = {
        result = "case-n",
        ingredients = {
          item("data", 7),
          item("processing-unit", 1),
          item("carbon-offset-certificate-verified", 1),
        },
        energy = 30,
      },
      brief = {
        result = "brief-n",
        ingredients = {
          item("white-paper", 1),
          item("refined-nonsense", 1),
        },
        energy = 40,
      },
      final = {
        result = "resolved-noise",
        ingredients = {
          item("refined-nonsense", 2),
          item("policy", 3),
          fluid("liquid-coffee", 120),
          item("narrative", 1),
        },
        energy = 150,
      },
    },
    spitter = {
      slug = "loitering",
      ticket = "ticket-loitering",
      filing = "filing-lo",
      case = {
        result = "case-lo",
        ingredients = {
          item("data", 6),
          item("credentials", 1),
          item("refined-nonsense", 1),
        },
        energy = 30,
      },
      brief = {
        result = "brief-lo",
        ingredients = {
          item("white-paper", 1),
          item("refined-nonsense", 1),
        },
        energy = 40,
      },
      final = {
        result = "resolved-loitering",
        ingredients = {
          item("refined-nonsense", 2),
          item("regulation", 3),
          fluid("liquid-coffee", 120),
          item("narrative", 1),
        },
        energy = 150,
      },
    },
  },
  -- Tier 4: filing -> case -> brief -> final (finals resolve from case stage)
  {
    filing_energy = 20,
    biter = {
      slug = "unemployment",
      ticket = "ticket-unemployment",
      filing = "filing-u",
      case = {
        result = "case-u",
        ingredients = {
          item("data", 1),
          item("treasury-bond", 1),
          fluid("liquid-coffee", 25),
        },
        energy = 45,
      },
      brief = {
        result = "brief-u",
        ingredients = {
          item("regulation", 1),
          item("treasury-bond", 1),
          item("refined-nonsense", 2),
        },
        energy = 75,
      },
      final = {
        result = "resolved-unemployment",
        ingredients = {
          item("regulation", 5),
          item("treasury-bond", 1),
          fluid("liquid-coffee", 200),
          item("narrative", 1),
        },
        energy = 270,
      },
    },
    spitter = {
      slug = "vagrancy",
      ticket = "ticket-vagrancy",
      filing = "filing-v",
      case = {
        result = "case-v",
        ingredients = {
          item("data", 1),
          item("policy", 1),
          fluid("liquid-coffee", 25),
        },
        energy = 45,
      },
      brief = {
        result = "brief-v",
        ingredients = {
          item("policy", 1),
          item("treasury-bond", 1),
          item("refined-nonsense", 3),
        },
        energy = 75,
      },
      final = {
        result = "resolved-vagrancy",
        ingredients = {
          item("policy", 5),
          item("treasury-bond", 1),
          fluid("liquid-coffee", 200),
          item("narrative", 1),
        },
        energy = 270,
      },
    },
  },
}

local recipes = {}
for _, pair in ipairs(PAIRED_PIPELINES) do
  append_all(recipes, build_stage_pipeline(pair.biter, pair.filing_energy))
  append_all(recipes, build_stage_pipeline(pair.spitter, pair.filing_energy))
end

data:extend(recipes)

-- Chromatic fast tracks are a parallel Space Age route through the complaint
-- system. They keep the ordinary black-paper pipelines meaningful while
-- letting specialized forms resolve a complaint in one direct craft.
if feature_flags.space_age_enabled() then
  local fast_tracks = {
    -- Simple complaints use one jurisdiction's paperwork.
    {slug = "landscape", ticket = "ticket-landscape", form = "blank-cyan-form", result = "resolved-landscape", order = "e-a"},
    {slug = "littering", ticket = "ticket-littering", form = "blank-yellow-form", result = "resolved-littering", order = "e-b"},

    -- More severe complaints combine the jurisdictions implicated by the case.
    {slug = "smog", ticket = "ticket-smog", form = "cyan-yellow-form", result = "resolved-smog", order = "e-c"},
    {slug = "hazmat", ticket = "ticket-hazmat", form = "yellow-magenta-form", result = "resolved-hazmat", order = "e-d"},
    {slug = "noise", ticket = "ticket-noise", form = "cyan-magenta-form", result = "resolved-noise", order = "e-e"},
    {slug = "loitering", ticket = "ticket-loitering", form = "yellow-magenta-form", result = "resolved-loitering", order = "e-f"},

    -- Behemoth complaints require the full chromatic authority.
    {slug = "unemployment", ticket = "ticket-unemployment", form = "trichromatic-permit", result = "resolved-unemployment", order = "e-g"},
    {slug = "vagrancy", ticket = "ticket-vagrancy", form = "trichromatic-permit", result = "resolved-vagrancy", order = "e-h"},
  }

  local fast_track_recipes = {}
  for _, track in ipairs(fast_tracks) do
    fast_track_recipes[#fast_track_recipes + 1] = {
      type = "recipe",
      name = "chromatic-" .. track.slug .. "-resolution",
      category = "bureaucracy-resolution",
      enabled = false,
      -- The normal resolution recipe is the product's canonical Factoriopedia
      -- page; this direct route remains an alternate recipe on that page.
      factoriopedia_alternative = track.slug .. "-final",
      subgroup = subgroup_for_slug(track.slug),
      order = track.order,
      ingredients = {
        item(track.ticket, 1),
        item(track.form, 1),
      },
      results = {{type = "item", name = track.result, amount = 1}},
      energy_required = 2,
    }
  end

  data:extend(fast_track_recipes)
end
