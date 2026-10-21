--- Bahnhofsliste: welche UTL-Stationen eine Rolle dieses Mods haben. Wird über UTLs Stations-Ereignisse
--- gepflegt und nur beim Start bzw. nach Mod-Änderungen einmal komplett von UTL geholt – nie auf Zeit.
local Const = require("scripts.core.const")

local Registry = {}

local OWN = {}
for _, key in pairs(Const.ROLE) do OWN[key] = true end

--- Einmal komplett neu aufbauen (on_init, on_configuration_changed).
function Registry.rebuild()
  storage.stations = {}
  for _, key in pairs(Const.ROLE) do
    for _, s in pairs(remote.call("utl", "get_stations", { addon_role = key }) --[[@as table]]) do
      storage.stations[s.unit] = key
    end
  end
end

--- Ereignis on_station_created / on_station_changed.
function Registry.update(event)
  local role = event.addon_role
  storage.stations[event.station] = OWN[role] and role or nil
end

--- Ereignis on_station_removed.
function Registry.remove(event)
  storage.stations[event.station] = nil
end

--- Rolle dieses Mods an der Station oder nil.
function Registry.role(unit)
  return unit and storage.stations[unit]
end

--- Betriebsart des Wagenbahnhofs ("swap", "drop", "pickup").
function Registry.mode(unit)
  local data = remote.call("utl", "get_station_data", unit, Const.MOD) --[[@as table?]]
  local mode = data and data.mode
  for _, m in pairs(Const.MODES) do
    if m == mode then return mode end
  end
  return Const.MODES[1]
end

function Registry.set_mode(unit, mode)
  return remote.call("utl", "set_station_data", unit, Const.MOD, "mode", mode)
end

return Registry
