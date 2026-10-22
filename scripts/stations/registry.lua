--- Bahnhofsliste: welche UTL-Stationen eine Rolle dieses Mods haben, dazu die Haltestellen aller
--- UTL-Stationen (für das Staffel-Signal). Wird über UTLs Stations-Ereignisse gepflegt und nur beim Start
--- bzw. nach Mod-Änderungen einmal komplett von UTL geholt – nie auf Zeit.
local Const = require("scripts.core.const")

local Registry = {}

local OWN = {}
for _, key in pairs(Const.ROLE) do OWN[key] = true end

--- Einmal komplett neu aufbauen (on_init, on_configuration_changed).
function Registry.rebuild()
  storage.stations, storage.stops, storage.utl_stops = {}, {}, {}
  for _, s in pairs(remote.call("utl", "get_stations") --[[@as table]]) do
    storage.utl_stops[s.unit] = s.stop
    if OWN[s.addon_role] then
      storage.stations[s.unit] = s.addon_role
      storage.stops[s.unit] = s.stop
    end
  end
end

--- Ereignis on_station_created / on_station_changed.
function Registry.update(event)
  local role = event.addon_role
  storage.stations[event.station] = OWN[role] and role or nil
  storage.stops[event.station] = OWN[role] and event.stop or nil
  storage.utl_stops[event.station] = event.stop
end

--- Ereignis on_station_removed.
function Registry.remove(event)
  storage.stations[event.station] = nil
  storage.stops[event.station] = nil
  storage.utl_stops[event.station] = nil
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

--- Steuert der Mod das Zuglimit dieses Wagenbahnhofs?
function Registry.gate(unit)
  local data = remote.call("utl", "get_station_data", unit, Const.MOD) --[[@as table?]]
  return data ~= nil and data.gate == true
end

--- Staffel-Nummer des Wagenbahnhofs (0 = keine).
function Registry.relay(unit)
  local data = remote.call("utl", "get_station_data", unit, Const.MOD) --[[@as table?]]
  return data and tonumber(data.relay) or 0
end

local RELAY = { type = "virtual", name = "ucy-relay" }

--- Wert des Staffel-Signals an der Haltestelle einer beliebigen UTL-Station (0 = keins).
function Registry.relay_signal(unit)
  local stop = unit and storage.utl_stops[unit]
  if not (stop and stop.valid) then return 0 end
  local W = defines.wire_connector_id
  return stop.get_signal(RELAY, W.circuit_red, W.circuit_green) or 0
end

--- Wagenbahnhof mit Staffel-Nummer `n`, der der Haltestelle `near` am nächsten liegt (unit oder nil).
function Registry.find_relay(n, near)
  local best, best_d
  for unit, role in pairs(storage.stations) do
    local stop = role == Const.ROLE.yard and Registry.stop(unit)
    if stop and stop.surface == near.surface and Registry.relay(unit) == n then
      local d = (stop.position.x - near.position.x) ^ 2 + (stop.position.y - near.position.y) ^ 2
      if not best_d or d < best_d then best, best_d = unit, d end
    end
  end
  return best
end

--- Haltestelle einer beliebigen UTL-Station oder nil.
function Registry.utl_stop(unit)
  local stop = unit and storage.utl_stops[unit]
  return stop and stop.valid and stop or nil
end

--- Wagenbahnhof mit dem Haltestellen-Namen `name` auf derselben Oberfläche wie die Haltestelle `near`,
--- für den `free(unit)` gilt (nächster zuerst). Liefert (unit oder nil, ob es den Namen überhaupt gibt).
function Registry.find_yard(name, near, free)
  local best, best_d, exists
  for unit, role in pairs(storage.stations) do
    local stop = role == Const.ROLE.yard and Registry.stop(unit)
    if stop and stop.backer_name == name and stop.surface == near.surface then
      exists = true
      if free(unit) then
        local d = (stop.position.x - near.position.x) ^ 2 + (stop.position.y - near.position.y) ^ 2
        if not best_d or d < best_d then best, best_d = unit, d end
      end
    end
  end
  return best, exists
end

return Registry
