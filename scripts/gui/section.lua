--- Eigener Abschnitt im UTL-Stationsfenster: nur an Stationen mit einer Rolle dieses Mods.
--- Wagenbahnhof: Betriebsart, Rangierziel (Name eines anderen Wagenbahnhofs), wann die Rangierlok die
--- abgestellten Wagen dorthin bringt, und die Staffel-Nummer.
local Const = require("scripts.core.const")
local Registry = require("scripts.stations.registry")

local Section = {}

local function dropdown(flow, list, prefix, current, tags, tooltip)
  local items, selected = {}, 1
  for i, value in ipairs(list) do
    items[i] = { "utl-coupling-yard." .. prefix .. value }
    if value == current then selected = i end
  end
  return flow.add({ type = "drop-down", items = items, selected_index = selected, tooltip = tooltip, tags = tags })
end

local function yard(flow, unit)
  dropdown(flow, Const.MODES, "mode-", Registry.mode(unit), { ucy_mode = unit },
    { "utl-coupling-yard.mode-tooltip" })
  local to, when = Registry.shunt(unit)
  local row = flow.add({ type = "flow", direction = "horizontal" })
  row.style.vertical_align = "center"
  row.add({ type = "label", caption = { "utl-coupling-yard.shunt-to" }, tooltip = { "utl-coupling-yard.shunt-to-tooltip" } })
  local field = row.add({ type = "textfield", text = to or "", tags = { ucy_target = unit },
    tooltip = { "utl-coupling-yard.shunt-to-tooltip" } })
  field.style.width = 160
  dropdown(flow, Const.WHEN, "when-", when or Const.WHEN[1], { ucy_when = unit })
  local relay = Registry.relay(unit)
  row = flow.add({ type = "flow", direction = "horizontal" })
  row.style.vertical_align = "center"
  row.add({ type = "label", caption = { "utl-coupling-yard.relay" }, tooltip = { "utl-coupling-yard.relay-tooltip" } })
  field = row.add({ type = "textfield", text = relay > 0 and tostring(relay) or "", numeric = true,
    tags = { ucy_relay = unit }, tooltip = { "utl-coupling-yard.relay-tooltip" } })
  field.style.width = 60
end

--- Rückruf von UTL beim Öffnen des Stationsfensters.
function Section.build(flow, unit)
  local role = Registry.role(unit)
  if not role then return end
  flow.add({ type = "line" })
  flow.add({ type = "label", style = "caption_label", caption = { "utl-coupling-yard.section" } })
  if role == Const.ROLE.yard then yard(flow, unit) end
  local name = role:sub(#Const.MOD + 2)
  local hint = flow.add({ type = "label", caption = { "utl-coupling-yard.hint-" .. name } })
  hint.style.single_line = false
  hint.style.maximal_width = 300
end

local function set(unit, key, value)
  remote.call("utl", "set_station_data", unit, Const.MOD, key, value)
end

--- Ereignis on_gui_selection_state_changed.
function Section.changed(event)
  local element = event.element
  if not element.valid then return end
  local tags = element.tags
  if tags.ucy_mode then
    Registry.set_mode(tags.ucy_mode, Const.MODES[element.selected_index] or Const.MODES[1])
  elseif tags.ucy_when then
    set(tags.ucy_when, "shunt_when", Const.WHEN[element.selected_index] or Const.WHEN[1])
  end
end

--- Ereignis on_gui_text_changed.
function Section.text(event)
  local element = event.element
  if not element.valid then return end
  local tags, text = element.tags, element.text
  if tags.ucy_target then
    set(tags.ucy_target, "shunt_to", text ~= "" and text or nil)
  elseif tags.ucy_relay then
    local n = tonumber(text)
    set(tags.ucy_relay, "relay", n and n > 0 and math.floor(n) or nil)
  end
end

return Section
