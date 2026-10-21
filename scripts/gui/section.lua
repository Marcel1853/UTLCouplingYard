--- Eigener Abschnitt im UTL-Stationsfenster: nur an Stationen mit einer Rolle dieses Mods.
--- Wagenbahnhof: Betriebsart wählen (abstellen und abholen / nur abstellen / nur abholen).
local Const = require("scripts.core.const")
local Registry = require("scripts.stations.registry")

local Section = {}

--- Rückruf von UTL beim Öffnen des Stationsfensters.
function Section.build(flow, unit)
  local role = Registry.role(unit)
  if not role then return end
  flow.add({ type = "line" })
  flow.add({ type = "label", style = "caption_label", caption = { "utl-coupling-yard.section" } })
  if role == Const.ROLE.yard then
    local items, selected = {}, 1
    local mode = Registry.mode(unit)
    for i, m in ipairs(Const.MODES) do
      items[i] = { "utl-coupling-yard.mode-" .. m }
      if m == mode then selected = i end
    end
    flow.add({ type = "drop-down", items = items, selected_index = selected,
      tooltip = { "utl-coupling-yard.mode-tooltip" }, tags = { ucy_mode = unit } })
  end
  local name = role:sub(#Const.MOD + 2)
  local hint = flow.add({ type = "label", caption = { "utl-coupling-yard.hint-" .. name } })
  hint.style.single_line = false
  hint.style.maximal_width = 300
end

--- Ereignis on_gui_selection_state_changed.
function Section.changed(event)
  local element = event.element
  local unit = element.valid and element.tags.ucy_mode
  if not unit then return end
  Registry.set_mode(unit, Const.MODES[element.selected_index] or Const.MODES[1])
end

return Section
