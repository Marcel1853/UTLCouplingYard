--- Eigener Reiter im UTL-Manager: die Karteneinstellungen dieses Mods (ohne Umweg über das Pausenmenü; ändern
--- dürfen nur Admins) und eine kleine Übersicht. UTL ruft `build` beim Wählen des Reiters und bei ⟲ auf.
local Const = require("scripts.core.const")

local Manager = {}

local SETTINGS = { "ucy-crawl", "ucy-attach", "ucy-partial" }

local function count_roles()
  local count = { yard = 0, depot = 0, turn = 0 }
  for _, role in pairs(storage.stations) do
    local name = role:sub(#Const.MOD + 2)
    if count[name] then count[name] = count[name] + 1 end
  end
  return count
end

local function size(list)
  local n = 0
  for _ in pairs(list) do n = n + 1 end
  return n
end

--- Rückruf von UTL: Inhalt des Reiters bauen.
function Manager.build(flow, player_index)
  local player = game.get_player(player_index)
  local admin = player ~= nil and player.admin
  flow.add({ type = "label", style = "caption_label", caption = { "utl-coupling-yard.manager-settings" } })
  for _, name in ipairs(SETTINGS) do
    flow.add({ type = "checkbox", state = settings.global[name].value == true, enabled = admin,
      caption = { "mod-setting-name." .. name }, tooltip = { "mod-setting-description." .. name },
      tags = { ucy_setting = name } })
  end
  if not admin then flow.add({ type = "label", caption = { "utl-coupling-yard.manager-admin-only" } }) end
  flow.add({ type = "line" })
  flow.add({ type = "label", style = "caption_label", caption = { "utl-coupling-yard.manager-overview" } })
  local roles = count_roles()
  local grid = flow.add({ type = "table", column_count = 2 })
  local function row(key, value)
    grid.add({ type = "label", caption = { "utl-coupling-yard.manager-" .. key } })
    grid.add({ type = "label", caption = tostring(value) })
  end
  row("yards", roles.yard)
  row("depots", roles.depot)
  row("turns", roles.turn)
  row("shunters", ("%d / %d"):format(size(storage.free), size(storage.shunters)))
  row("tasks", #storage.tasks + size(storage.jobs))
  row("waiting", #storage.waiting)
  row("attach", size(storage.attach))
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
end

return Manager
