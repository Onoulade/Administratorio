local taxonomy = require("prototypes.shared.paperwork_taxonomy")

local M = {}

M.SUCCESS_PERCENT = 50
M.THREE_CANDIDATE_WEIGHTS = {45, 35, 20}
M.TWO_CANDIDATE_WEIGHTS = {60, 40}

local COLOR_ORDER = {"cyan", "yellow", "magenta"}

local function copy_colors(colors)
  local copy = {}
  for color, enabled in pairs(colors or {}) do
    if enabled then copy[color] = true end
  end
  return copy
end

local function union_colors(left, right)
  local union = copy_colors(left)
  for color, enabled in pairs(right or {}) do
    if enabled then union[color] = true end
  end
  return union
end

local function colors_subset(subset, superset)
  for color, enabled in pairs(subset or {}) do
    if enabled and not (superset and superset[color]) then
      return false
    end
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

local function color_signature(colors)
  local names = {}
  for _, color in ipairs(COLOR_ORDER) do
    if colors and colors[color] then names[#names + 1] = color end
  end
  return table.concat(names, "+")
end

local function stable_hash(value)
  -- Keep every multiply below 2^53 so Lua's numeric representation remains
  -- exact and the mapping is identical across multiplayer hosts/platforms.
  local hash = 5381
  for index = 1, #value do
    hash = (hash * 65599 + value:byte(index)) % 2147483647
  end
  return hash
end

function M.sorted_pair(left, right)
  if not left or not right or left == right then return nil end
  if left < right then return left, right end
  return right, left
end

function M.pair_key(left, right)
  local first, second = M.sorted_pair(left, right)
  if not first then return nil end
  return first .. "|" .. second
end

local function candidate_score(pair_key, first, second, output_name, output)
  local score = output.rank * 100
  if output.family ~= first.family and output.family ~= second.family then
    score = score + 30
  elseif output.family ~= first.family or output.family ~= second.family then
    score = score + 12
  end

  local union = union_colors(first.colors, second.colors)
  local union_count = color_count(union)
  local output_count = color_count(output.colors)
  if union_count > 0 and output_count == union_count and color_signature(output.colors) == color_signature(union) then
    score = score + 50
  elseif output_count > 0 then
    score = score + 20
  end

  return score + (stable_hash(pair_key .. ">" .. output_name) % 17)
end

function M.generate_candidates(left_name, right_name)
  local first_name, second_name = M.sorted_pair(left_name, right_name)
  if not first_name then return nil end

  local first = taxonomy.get(first_name)
  local second = taxonomy.get(second_name)
  if not first or not second or not taxonomy.is_recyclable(first_name) or not taxonomy.is_recyclable(second_name) then
    return nil
  end

  local minimum_rank = math.min(first.rank, second.rank)
  local maximum_rank = math.min(math.max(first.rank, second.rank), minimum_rank + 1)
  local available_colors = union_colors(first.colors, second.colors)
  local pair_key = M.pair_key(first_name, second_name)
  local candidates = {}

  for output_name, output in pairs(taxonomy.documents) do
    if output_name ~= first_name
      and output_name ~= second_name
      and taxonomy.is_generatable(output_name)
      and output.rank >= minimum_rank
      and output.rank <= maximum_rank
      and colors_subset(output.colors, available_colors)
    then
      candidates[#candidates + 1] = {
        name = output_name,
        rank = output.rank,
        family = output.family,
        colors = output.colors,
        unlock_technology = output.unlock_technology,
        score = candidate_score(pair_key, first, second, output_name, output),
      }
    end
  end

  table.sort(candidates, function(left, right)
    if left.score ~= right.score then return left.score > right.score end
    return left.name < right.name
  end)

  local limit = math.min(3, #candidates)
  local selected = {}
  for index = 1, limit do
    local candidate = candidates[index]
    selected[index] = {
      name = candidate.name,
      rank = candidate.rank,
      family = candidate.family,
      colors = candidate.colors,
      unlock_technology = candidate.unlock_technology,
    }
  end

  if #selected < 2 then return nil end
  local weights = #selected == 2 and M.TWO_CANDIDATE_WEIGHTS or M.THREE_CANDIDATE_WEIGHTS
  for index, candidate in ipairs(selected) do
    candidate.weight = weights[index]
  end
  return selected
end

function M.generate_all_pairs()
  local names = taxonomy.recyclable_names()
  local pairs = {}
  local invalid = {}
  for left_index = 1, #names - 1 do
    for right_index = left_index + 1, #names do
      local left = names[left_index]
      local right = names[right_index]
      local key = M.pair_key(left, right)
      local candidates = M.generate_candidates(left, right)
      if candidates then
        pairs[key] = {left = left, right = right, candidates = candidates}
      else
        invalid[#invalid + 1] = {left = left, right = right}
      end
    end
  end
  return pairs, invalid
end

function M.technology_unlocked(force, technology_name)
  if not technology_name then return true end
  if not force or not force.valid or not force.technologies then return false end
  local technology = force.technologies[technology_name]
  return technology ~= nil and technology.researched == true
end

function M.available_candidates(candidates, force)
  local available = {}
  for _, candidate in ipairs(candidates or {}) do
    if M.technology_unlocked(force, candidate.unlock_technology) then
      available[#available + 1] = candidate
    end
  end
  return available
end

function M.choose_candidate(candidates, roll_percent)
  if not candidates or #candidates == 0 then return nil end
  local roll = math.max(0, math.min(99.999999, roll_percent or 0))
  local total = 0
  for _, candidate in ipairs(candidates) do
    total = total + (candidate.weight or 0)
  end
  if total <= 0 then return candidates[1] end
  local target = roll / 100 * total
  local accumulated = 0
  for _, candidate in ipairs(candidates) do
    accumulated = accumulated + (candidate.weight or 0)
    if target < accumulated then return candidate end
  end
  return candidates[#candidates]
end

function M.deterministic_roll(unit_number, attempt_count, left_name, right_name, salt)
  local key = table.concat({
    tostring(unit_number or 0),
    tostring(attempt_count or 0),
    tostring(left_name or ""),
    tostring(right_name or ""),
    tostring(salt or ""),
  }, ":")
  return (stable_hash(key) % 1000000) / 10000
end

M.colors_subset = colors_subset
M.union_colors = union_colors
M.color_count = color_count

return M
