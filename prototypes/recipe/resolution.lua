local function item(name, amount)
  return {type = "item", name = name, amount = amount}
end

local function fluid(name, amount)
  return {type = "fluid", name = name, amount = amount}
end

local function append_all(target, values)
  if not values then return end
  for _, value in ipairs(values) do
    target[#target + 1] = value
  end
end

local function make_resolution_recipe(name, ingredients, result_name, energy_required, category)
  return {
    type = "recipe",
    name = name,
    category = category or "bureaucracy-resolution",
    enabled = false,
    ingredients = ingredients,
    results = {{type = "item", name = result_name, amount = 1}},
    energy_required = energy_required,
  }
end

local function build_stage_pipeline(stage, filing_energy)
  local recipes = {}
  local category = stage.category or "bureaucracy-resolution"

  -- Filing
  recipes[#recipes + 1] = make_resolution_recipe(
    "filing-" .. stage.slug,
    {item(stage.ticket, 1), item("blank-form", 1)},
    stage.filing,
    filing_energy,
    category
  )

  -- Case (optional)
  if stage.case then
    local case_ingredients = {item(stage.filing, 1)}
    append_all(case_ingredients, stage.case.ingredients)
    recipes[#recipes + 1] = make_resolution_recipe(
      "case-" .. stage.slug,
      case_ingredients,
      stage.case.result,
      stage.case.energy,
      category
    )
  end

  -- Brief (optional)
  if stage.brief and stage.case then
    local brief_ingredients = {item(stage.case.result, 1)}
    append_all(brief_ingredients, stage.brief.ingredients)
    recipes[#recipes + 1] = make_resolution_recipe(
      "brief-" .. stage.slug,
      brief_ingredients,
      stage.brief.result,
      stage.brief.energy,
      category
    )
  end

  -- Final (always present)
  local final_source = stage.case and stage.case.result or stage.filing
  local final_ingredients = {item(final_source, 1)}
  append_all(final_ingredients, stage.final.ingredients)
  recipes[#recipes + 1] = make_resolution_recipe(
    stage.slug .. "-final",
    final_ingredients,
    stage.final.result,
    stage.final.energy,
    category
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

-- The automation grievance is filed by the union rather than carried in from a
-- nest, but it runs the identical four-stage chain. Its resolution costs the
-- outputs of the machinery it complains about, so automating the biter economy
-- away funds the complaints about having done so.
local AUTOMATION_PIPELINE = {
  filing_energy = 20,
  stage = {
    slug = "automation",
    ticket = "ticket-automation",
    filing = "filing-a",
    case = {
      result = "case-a",
      ingredients = {
        item("data", 1),
        item("credentials", 1),
        fluid("liquid-coffee", 25),
      },
      energy = 45,
    },
    brief = {
      result = "brief-a",
      ingredients = {
        item("regulation", 1),
        item("treasury-bond", 1),
        item("refined-nonsense", 3),
      },
      energy = 75,
    },
    final = {
      result = "resolved-automation",
      ingredients = {
        item("policy", 5),
        item("treasury-bond", 1),
        fluid("liquid-coffee", 200),
        item("narrative", 1),
      },
      energy = 270,
    },
  },
}

local recipes = {}
for _, pair in ipairs(PAIRED_PIPELINES) do
  append_all(recipes, build_stage_pipeline(pair.biter, pair.filing_energy))
  append_all(recipes, build_stage_pipeline(pair.spitter, pair.filing_energy))
end

append_all(recipes, build_stage_pipeline(AUTOMATION_PIPELINE.stage, AUTOMATION_PIPELINE.filing_energy))

data:extend(recipes)
