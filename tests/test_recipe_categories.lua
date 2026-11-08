local categories = require("prototypes.shared.recipe_categories")

assert(categories.has({}, "crafting"), "recipes default to hand crafting")
assert(not categories.has({}, "chemistry"))
assert(categories.primary({}) == "crafting")

local shared = {categories = {"electronics", "crafting"}}
assert(categories.primary(shared) == "crafting", "regulation follows the assembler route")
assert(categories.has(shared, "electronics"), "specialist access survives")
assert(categories.matches(shared, {electronics = true}))
assert(categories.matches(shared, {crafting = true}))
assert(not categories.matches(shared, {chemistry = true}))
assert(shared.categories[1] == "electronics", "inspection does not mutate categories")

assert(categories.primary({categories = {"organic", "chemistry"}}) == "chemistry")
assert(categories.primary({categories = {"specialist-approval"}}) == "specialist-approval")
assert(categories.matches({}, {crafting = true}))

print("Factorio 2.1 recipe category tests passed")
