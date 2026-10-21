--- Bahnhofsliste: welche UTL-Stationen eine Rolle dieses Mods haben. Wird über UTLs Stations-Ereignisse
--- gepflegt und nur beim Start bzw. nach Mod-Änderungen einmal komplett von UTL geholt – nie auf Zeit.
local Const = require("scripts.core.const")

local Registry = {}

local OWN = {}
for _, key in pairs(Const.ROLE) do OWN[key] = true end

--- Einmal komplett neu aufbauen (on_init, on_configuration_changed).
function Registry.rebuild()
  storage.stations, storage.stops = {}, {}
  for _, key in pairs(Const.ROLE) do
    for _, s in pairs(remote.call("utl", "get_stations", { addon_role = key }) --[[@as table]]) do
      storage.stations[s.unit] = key
      storage.stops[s.unit] = s.stop
    end
  end
end

--- Ereignis on_station_created / on_station_changed.
function Registry.update(event)
  local role = event.addon_role
  storage.stations[event.station] = OWN[role] and role or nil
  storage.stops[event.station] = OWN[role] and event.stop or nil
end

--- Ereignis on_station_removed.
function Registry.remove(event)
  storage.stations[event.station] = nil
  storage.stops[event.station] = nil
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

--- Haltestelle (LuaEntity) einer Station dieses Mods oder nil.
function Registry.stop(unit)
  local stop = unit and storage.stops[unit]
  return stop and stop.valid and stop or nil
end

--- Rangierziel des Wagenbahnhofs: Name der Zielstation und wann ("now", "empty", "full").
function Registry.shunt(unit)
  local data = remote.call("utl", "get_station_data", unit, Const.MOD) --[[@as table?]]
  local to = data and data.shunt_to
  if type(to) ~= "string" or to == "" then return nil end
  local when = data and data.shunt_when
  for _, w in pairs(Const.WHEN) do
    if w == when then return to, when end
  end
  return to, Const.WHEN[1]
end

--- Wagenbahnhof mit dem Haltestellen-Namen `name` auf derselben Oberfläche wie die Haltestelle `near`
--- (unit oder nil).
function Registry.find_yard(name, near)
  for unit, role in pairs(storage.stations) do
    local stop = role == Const.ROLE.yard and Registry.stop(unit)
    if stop and stop.backer_name == name and stop.surface == near.surface then return unit end
  end
  return nil
end

return Registry
