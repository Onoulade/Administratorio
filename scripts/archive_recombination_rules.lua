local taxonomy = require("prototypes.shared.paperwork_taxonomy")

local M = {}

M.CANDIDATE_COUNT = 3
M.OUTPUT_PROBABILITY = 0.25

local COLOR_ORDER = {"cyan", "yellow", "magenta"}

local function colors_subset(subset, superset)
  for color, enabled in pairs(subset or {}) do
    if enabled and not (superset and superset[color]) then return false end
  end
  return true
end

local function color_count(colors)
  local count = 0
  for _, color in ipairs(COLOR_ORDER) do
    if colors and colors[color] then count = count + 1 end
  end
  return count
end

local function stable_hash(value)
  -- Keep the mapping deterministic across multiplayer peers and platforms.
  local hash = 5381
  for index = 1, #value do
    hash = (hash * 65599 + value:byte(index)) % 2147483647
  end
  return hash
end

local function candidate_score(input_name, input, output_name, output)
  local score = output.family ~= input.family and 100 or 20
  local input_color_count = color_count(input.colors)
  local output_color_count = color_count(output.colors)

  -- Prefer preserving an existing chromatic identity, but never invent one.
  if input_color_count > 0 and output_color_count == input_color_count then
    score = score + 50
  elseif output_color_count == 0 then
    score = score + 10
  end

  return score + (stable_hash(input_name .. ">" .. output_name) % 37)
end

function M.recipe_name(input_name)
  return input_name and (input_name .. "-archive-reassignment") or nil
end

function M.generate_candidates(input_name)
  local input = taxonomy.get(input_name)
  if not input or not taxonomy.is_recyclable(input_name) then return nil end

  local candidates = {}
  for output_name, output in pairs(taxonomy.documents) do
    if output_name ~= input_name
      and taxonomy.is_generatable(output_name)
      and output.rank == input.rank
      and colors_subset(output.colors, input.colors)
    then
      candidates[#candidates + 1] = {
        name = output_name,
        rank = output.rank,
        family = output.family,
        colors = output.colors,
        unlock_technology = output.unlock_technology,
        score = candidate_score(input_name, input, output_name, output),
      }
    end
  end

  table.sort(candidates, function(left, right)
    if left.score ~= right.score then return left.score > right.score end
    return left.name < right.name
  end)

  if #candidates < M.CANDIDATE_COUNT then return nil end
  local selected = {}
  for index = 1, M.CANDIDATE_COUNT do
    local candidate = candidates[index]
    selected[index] = {
      name = candidate.name,
      rank = candidate.rank,
      family = candidate.family,
      colors = candidate.colors,
      unlock_technology = candidate.unlock_technology,
    }
  end
  return selected
end

function M.generate_all_reassignments()
  local assignments = {}
  local invalid = {}
  for _, input_name in ipairs(taxonomy.recyclable_names()) do
    local candidates = M.generate_candidates(input_name)
    if candidates then
      assignments[input_name] = {input = input_name, candidates = candidates}
    else
      invalid[#invalid + 1] = input_name
    end
  end
  return assignments, invalid
end

M.colors_subset = colors_subset
M.color_count = color_count

return M
