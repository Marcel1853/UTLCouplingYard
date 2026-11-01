-- Tipps & Tricks: eigene Kategorie. Vier Einträge mit Szene (Tauschen, Abholen, Rangieren, Anstellen) (UTL und dieser Mod laufen darin wirklich), drei als
-- reiner Text. Sofort sichtbar – der Mod hat keine eigene Forschung.
local code = require("prototypes.tips.scenes")

local function item(name, order, scene, extra)
  local entry = { type = "tips-and-tricks-item", name = name, category = "ucy", order = order, indent = 1,
    starting_status = "unlocked",
    simulation = scene and { init = code[scene], mods = { "UTLogistics", "flib", "UTLCouplingYard" },
      init_update_count = 60 } }
  for key, value in pairs(extra or {}) do entry[key] = value end
  return entry
end

data:extend({
  { type = "tips-and-tricks-item-category", name = "ucy", order = "f-[trains]-z[ucy]" },
  item("ucy-overview", "a", "swap", { is_title = true, indent = 0 }),
  item("ucy-pickup", "b", "pickup", { tag = "[item=cargo-wagon]" }),
  item("ucy-shunting", "c", "shunt", { tag = "[item=locomotive]" }),
  item("ucy-attach", "d", "attach", { tag = "[item=locomotive]" }),
  item("ucy-queue", "e", nil, { tag = "[item=cargo-wagon]" }),
  item("ucy-relay", "f", nil, { tag = "[virtual-signal=ucy-relay]" }),
  item("ucy-signals", "g", nil, { tag = "[item=rail-signal]" }),
})
