local item_icons = "__administratorio__/graphics/icons/"

data:extend({
  -- Line 1: Base Forms
  { type = "item", name = "blank-form",            icon = item_icons .. "blank-form.png",                       icon_size = 64, subgroup = "forms-base", order = "a", stack_size = 100 },
  { type = "item", name = "blank-approval",        icon = item_icons .. "blank-approval.png",                   icon_size = 64, subgroup = "forms-base", order = "a2", stack_size = 100 },
  { type = "item", name = "blank-directive",       icon = item_icons .. "blank-directive.png",                   icon_size = 64, subgroup = "forms-base", order = "a3", stack_size = 50 },
  { type = "item", name = "carbon-offset-certificate-basic", icon = item_icons .. "carbon-offset-certificate-basic.png", icon_size = 64, subgroup = "forms-base", order = "b", stack_size = 50 },
  { type = "item", name = "provisional-approval",  icon = item_icons .. "provisional-approval.png",             icon_size = 64, subgroup = "forms-base", order = "c", stack_size = 5 },

  -- Line 2: Permits & Drafts
  { type = "item", name = "safety-waiver-draft",        icon = item_icons .. "safety-waiver-draft.png",        icon_size = 64, subgroup = "forms-permits", order = "a-a", stack_size = 50 },
  { type = "item", name = "unapproved-safety-waiver",   icon = item_icons .. "safety-waiver.png",              icon_size = 64, subgroup = "forms-permits", order = "a-aa", stack_size = 50 },
  { type = "item", name = "safety-waiver",              icon = item_icons .. "safety-waiver.png",              icon_size = 64, subgroup = "forms-permits", order = "a-b", stack_size = 50 },
  { type = "item", name = "construction-permit-draft",  icon = item_icons .. "construction-permit-draft.png",  icon_size = 64, subgroup = "forms-permits", order = "b-a", stack_size = 50 },
  { type = "item", name = "unapproved-construction-permit", icon = item_icons .. "construction-permit.png",    icon_size = 64, subgroup = "forms-permits", order = "b-aa", stack_size = 50 },
  { type = "item", name = "construction-permit",        icon = item_icons .. "construction-permit.png",        icon_size = 64, subgroup = "forms-permits", order = "b-b", stack_size = 50 },
  { type = "item", name = "management-verbal-draft",    icon = item_icons .. "management-verbal-draft.png",    icon_size = 64, subgroup = "forms-permits", order = "c-a", stack_size = 20 },
  { type = "item", name = "management-approval-verbal", icon = item_icons .. "management-approval-verbal.png", icon_size = 64, subgroup = "forms-permits", order = "c-b", stack_size = 20 },
  { type = "item", name = "management-written-proposal",icon = item_icons .. "management-written-proposal.png",icon_size = 64, subgroup = "forms-permits", order = "d-a", stack_size = 10 },
  { type = "item", name = "management-approval-written",icon = item_icons .. "management-approval-written.png",icon_size = 64, subgroup = "forms-permits", order = "d-c", stack_size = 10 },
  { type = "item", name = "transit-authorization",      icon = item_icons .. "transit-authorization.png",      icon_size = 64, subgroup = "forms-permits", order = "f", stack_size = 50 },
  { type = "item", name = "research-grant-approval",    icon = item_icons .. "research-grant-approval.png",    icon_size = 64, subgroup = "forms-permits", order = "g", stack_size = 50 },
  { type = "item", name = "unapproved-petrochemical-operating-permit", icon = item_icons .. "petrochemical-operating-permit.png", icon_size = 64, subgroup = "forms-permits", order = "h-a", stack_size = 20 },
  { type = "item", name = "petrochemical-operating-permit", icon = item_icons .. "petrochemical-operating-permit.png", icon_size = 64, subgroup = "forms-permits", order = "h", stack_size = 20 },

  -- Line 3: Work Orders & Machinery Forms
  { type = "item", name = "work-order",                       icon = item_icons .. "work-order.png",                       icon_size = 64, subgroup = "forms-work-orders", order = "a",  stack_size = 50 },
  { type = "item", name = "form-27b-6",                       icon = item_icons .. "form-27b-6.png",                       icon_size = 64, subgroup = "forms-work-orders", order = "b",  stack_size = 50 },
  { type = "item", name = "provisional-work-order",           icon = item_icons .. "provisional-work-order.png",           icon_size = 64, subgroup = "forms-work-orders", order = "c0", stack_size = 50 },
  { type = "item", name = "safety-work-order",                icon = item_icons .. "safety-work-order.png",                icon_size = 64, subgroup = "forms-work-orders", order = "c1", stack_size = 50 },
  { type = "item", name = "construction-work-order",          icon = item_icons .. "construction-work-order.png",          icon_size = 64, subgroup = "forms-work-orders", order = "c2", stack_size = 50 },
  { type = "item", name = "management-verbal-work-order",     icon = item_icons .. "management-verbal-work-order.png",     icon_size = 64, subgroup = "forms-work-orders", order = "c3", stack_size = 20 },
  { type = "item", name = "management-written-work-order",    icon = item_icons .. "management-written-work-order.png",    icon_size = 64, subgroup = "forms-work-orders", order = "c4", stack_size = 10 },
  { type = "item", name = "research-grant-work-order",        icon = item_icons .. "research-grant-work-order.png",        icon_size = 64, subgroup = "forms-work-orders", order = "c5", stack_size = 50 },
  { type = "item", name = "chemical-handling-work-order",     icon = item_icons .. "chemical-handling-work-order.png",     icon_size = 64, subgroup = "forms-work-orders", order = "c6", stack_size = 20 },
  { type = "item", name = "unapproved-radiological-work-order", icon = item_icons .. "radiological-work-order.png",        icon_size = 64, subgroup = "forms-work-orders", order = "c7-a", stack_size = 10 },
  { type = "item", name = "radiological-work-order",          icon = item_icons .. "radiological-work-order.png",          icon_size = 64, subgroup = "forms-work-orders", order = "c7", stack_size = 10 },

  -- Line 4: Printed Documents
  { type = "item", name = "carbon-offset-certificate-verified", icon = item_icons .. "carbon-offset-certificate-verified.png", icon_size = 64, subgroup = "forms-printed", order = "a", stack_size = 30 },
  { type = "item", name = "environmental-impact-report",        icon = item_icons .. "environmental-impact-report.png",        icon_size = 64, subgroup = "forms-printed", order = "b", stack_size = 20 },
  { type = "item", name = "white-paper",                        icon = item_icons .. "white-paper.png",                        icon_size = 64, subgroup = "forms-printed", order = "c", stack_size = 20 },

  -- Administrative Science Pack (in vanilla science-pack subgroup)
  { type = "tool", name = "administrative-science-pack", icon = item_icons .. "administrative-science-pack.png", icon_size = 256, icon_mipmaps = 4, subgroup = "science-pack", order = "za", stack_size = 200, durability = 1 },
})
