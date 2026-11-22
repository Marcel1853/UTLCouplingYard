--- Eigener Reiter im UTL-Manager, gebaut wie UTLs Reiter „Einstellungen“ (Kästen mit Kopfleiste, Tabellen mit feinen
--- Linien): Karteneinstellungen dieses Mods (⟲ | Beschriftung | Häkchen | Hinweis; ändern dürfen nur Admins), eine
--- Übersicht, die Rangierloks und die Züge, die auf angestellte Wagen warten. UTL ruft `build` beim Wählen des
--- Reiters und bei ⟲ auf; nach einer Änderung baut der Reiter sich selbst neu.
local Const = require("scripts.core.const")
local Registry = require("scripts.stations.registry")

local Manager = {}

local SETTINGS = { "ucy-crawl", "ucy-attach", "ucy-partial" }
local BETA = { ["ucy-attach"] = true }
local GREY = { 0.7, 0.7, 0.7 }

--- Kasten im Vanilla-Stil wie in UTL: heller Rahmen, dunkle Kopfleiste, Inhalt mit Innenabstand.
local function section(parent, caption)
  local frame = parent.add({ type = "frame", style = "inside_shallow_frame", direction = "vertical" })
  frame.style.horizontally_stretchable = true
  local head = frame.add({ type = "frame", style = "subheader_frame" })
  head.style.horizontally_stretchable = true
  head.add({ type = "label", style = "subheader_caption_label", caption = caption })
  local body = frame.add({ type = "flow", direction = "vertical" })
  body.style.padding = { 8, 12, 12, 12 }
  body.style.vertical_spacing = 6
  return body
end

local function note(parent, caption)
  local label = parent.add({ type = "label", caption = caption })
  label.style.single_line = false
  label.style.font_color = GREY
  return label
end

local function grid(parent, columns)
  local t = parent.add({ type = "table", column_count = columns })
  t.draw_horizontal_lines = true
  t.style.horizontal_spacing = 8
  t.style.vertical_spacing = 6
  t.style.vertical_align = "center"
  return t
end

local function size(list)
  local n = 0
  for _ in pairs(list) do n = n + 1 end
  return n
end

local function settings_box(parent, admin)
  local body = section(parent, { "utl-coupling-yard.manager-settings" })
  note(body, { admin and "utl-coupling-yard.manager-admin-note" or "utl-coupling-yard.manager-admin-only" })
  local t = grid(body, 4)
  for _, name in ipairs(SETTINGS) do
    local proto = prototypes.mod_setting[name]
    local value = settings.global[name].value == true
    local tooltip = { "mod-setting-description." .. name }
    t.add({ type = "sprite-button", style = "utl_reset_button", sprite = "utility/reset",
      tooltip = { "utl-coupling-yard.manager-reset" }, enabled = admin and value ~= proto.default_value,
      tags = { ucy_setting_reset = name } })
    local label = t.add({ type = "label", caption = { "mod-setting-name." .. name }, tooltip = tooltip })
    label.style.width = 420
    t.add({ type = "checkbox", state = value, enabled = admin, tooltip = tooltip, tags = { ucy_setting = name } })
    local hint = t.add({ type = "label", caption = { "", BETA[name] and "[color=255,180,60]Beta[/color]  " or "",
      { "utl-coupling-yard.manager-default", { proto.default_value and "utl-coupling-yard.manager-on"
        or "utl-coupling-yard.manager-off" } } } })
    hint.style.font_color = GREY
  end
end

local function overview_box(parent)
  local body = section(parent, { "utl-coupling-yard.manager-overview" })
  local count = { yard = 0, depot = 0, turn = 0 }
  for _, role in pairs(storage.stations) do
    local name = role:sub(#Const.MOD + 2)
    if count[name] then count[name] = count[name] + 1 end
  end
  local rows = {
    { "item/cargo-wagon", "yards", count.yard },
    { "item/locomotive", "depots", count.depot },
    { "item/rail", "turns", count.turn },
    { "item/locomotive", "shunters", ("%d / %d"):format(size(storage.free), size(storage.shunters)) },
    { "utility/clock", "tasks", #storage.tasks + size(storage.jobs) },
    { "item/cargo-wagon", "waiting", #storage.waiting },
    { "item/locomotive", "attach", size(storage.attach) },
  }
  local t = grid(body, 3)
  for _, r in ipairs(rows) do
    local icon = t.add({ type = "sprite", sprite = r[1] })
    icon.style.size = 24
    icon.style.stretch_image_to_widget_size = true
    local label = t.add({ type = "label", caption = { "utl-coupling-yard.manager-" .. r[2] } })
    label.style.width = 420
    t.add({ type = "label", style = "bold_label", caption = tostring(r[3]) })
  end
end

local function shunters_box(parent)
  local body = section(parent, { "utl-coupling-yard.manager-shunter-list" })
  if not next(storage.shunters) then
    note(body, { "utl-coupling-yard.manager-none" })
    return
  end
  local t = grid(body, 3)
  for id, unit in pairs(storage.shunters) do
    local stop = Registry.stop(unit)
    t.add({ type = "label", style = "bold_label", caption = { "utl-coupling-yard.manager-train", id } })
    local depot = t.add({ type = "label", caption = stop and stop.backer_name or "?" })
    depot.style.width = 360
    local free = storage.free[id] ~= nil
    t.add({ type = "label", caption = free and { "utl-coupling-yard.manager-free" }
      or { "", "[color=255,180,60]", { "utl-coupling-yard.manager-busy" }, "[/color]" } })
  end
end

local function waiting_box(parent)
  if not next(storage.attach) then return end
  local body = section(parent, { "utl-coupling-yard.manager-attach" })
  local t = grid(body, 3)
  for unit, waiting in pairs(storage.attach) do
    local stop = Registry.stop(unit)
    local train = waiting.ref.valid and waiting.ref.train
    t.add({ type = "label", style = "bold_label", caption = train and { "utl-coupling-yard.manager-train", train.id } or "?" })
    local name = t.add({ type = "label", caption = stop and stop.backer_name or "?" })
    name.style.width = 360
    t.add({ type = "label", caption = { "", "← ", waiting.from or "?" } })
  end
end

--- Rückruf von UTL: Inhalt des Reiters bauen.
function Manager.build(flow, player_index)
  local player = game.get_player(player_index)
  local admin = player ~= nil and player.admin
  local pane = flow.add({ type = "scroll-pane", style = "flib_naked_scroll_pane_no_padding",
    horizontal_scroll_policy = "never", tags = { ucy_manager = true } })
  pane.style.vertically_stretchable = true
  pane.style.horizontally_stretchable = true
  local box = pane.add({ type = "flow", direction = "vertical" })
  box.style.padding = { 0, 12, 8, 0 }
  box.style.vertical_spacing = 12
  settings_box(box, admin)
  overview_box(box)
  shunters_box(box)
  waiting_box(box)
end

--- Reiter nach einer Änderung neu aufbauen (er liegt im Flow, den UTL übergeben hat).
local function rebuild(element, player_index)
  local pane = element
  while pane and pane.valid and not (pane.tags and pane.tags.ucy_manager) do pane = pane.parent end
  if not (pane and pane.valid) then return end
  local flow = pane.parent
  flow.clear()
  Manager.build(flow, player_index)
end

--- Ereignis on_gui_checked_state_changed: eine Karteneinstellung umschalten (nur Admins).
function Manager.checked(event)
  local element = event.element
  local name = element.valid and element.tags.ucy_setting
  if not name then return end
  local player = game.get_player(event.player_index)
  if not (player and player.admin) then
    element.state = settings.global[name].value == true
    return
  end
  settings.global[name] = { value = element.state }
  rebuild(element, event.player_index)
end

--- Ereignis on_gui_click: ⟲ setzt eine Karteneinstellung auf die Vorgabe zurück (nur Admins).
function Manager.click(event)
  local element = event.element
  local name = element.valid and element.tags.ucy_setting_reset
  if not name then return end
  local player = game.get_player(event.player_index)
  if not (player and player.admin) then return end
  settings.global[name] = { value = prototypes.mod_setting[name].default_value }
  rebuild(element, event.player_index)
end

return Manager
