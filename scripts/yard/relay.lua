--- Staffel: Lieferungen über einen Wagenbahnhof leiten. Bekommt die Haltestelle des Abnehmers (sonst
--- des Anbieters) das Signal „Staffel“ = N, fügt der Mod den nächsten Wagenbahnhof mit Staffel-Nummer N
--- nach dem Anbieter in die Lieferung ein. Dort stellt der Zug die Wagen ab, die Lieferung bleibt bei den
--- Wagen (scripts/yard/yard.lua), der nächste Zug, der sie abholt, bringt sie zum Abnehmer.
--- Gelesen wird einmal je Lieferung (beim Laden) – kein Abscannen.
local Registry = require("scripts.stations.registry")

local Relay = {}

--- Ereignis on_delivery_state_changed: Beim Laden am Anbieter den Staffel-Halt einfügen. Erst hier, weil
--- UTL die Erreichbarkeit vom Zug aus prüft – beim Anlegen stünde er noch im Depot.
function Relay.state_changed(event)
  if event.state ~= "loading" or storage.relayed[event.id] then return end
  if not next(storage.stations) then return end -- ohne eigene Stationen: nichts tun
  local n = Registry.relay_signal(event.requester)
  if n <= 0 then n = Registry.relay_signal(event.provider) end
  if n <= 0 then return end
  local near = Registry.utl_stop(event.provider)
  local yard = near and Registry.find_relay(n, near)
  if not yard then return end
  storage.relayed[event.id] = true
  local ok, why = remote.call("utl", "add_delivery_stop", event.id,
    { station = yard, where = "after_provider", wait = { { type = "time", ticks = 60 } } })
  if not ok then log("[UCY] Staffel " .. n .. ": Halt nicht eingefügt (" .. tostring(why) .. ")") end
end

--- Ereignis on_delivery_completed / on_delivery_canceled: Merker wegräumen.
function Relay.ended(event)
  storage.relayed[event.id] = nil
end

--- Übergabe beim Abstellen: Hat der Zug eine Lieferung und ist der Bahnhof ein Staffel-Bahnhof, soll die
--- Lieferung bei den Wagen bleiben. Liefert den Namen des Heimatdepots der Lok oder nil.
function Relay.handover(train, unit)
  if Registry.relay(unit) <= 0 then return nil end
  local info = remote.call("utl", "get_train", train.id) --[[@as table?]]
  if not (info and info.delivery) then return nil end
  return info.depot or ""
end

--- Lok nach einer Übergabe ins Heimatdepot schicken: UTL-Halte der Lieferung raus, Depot als
--- temporärer Halt (dort meldet UTL sie wieder als frei).
function Relay.send_home(train, depot)
  local schedule = train.get_schedule()
  if not schedule then return end
  for i = schedule.get_record_count() or 0, 1, -1 do
    local record = schedule.get_record({ schedule_index = i })
    if record and record.temporary then schedule.remove_record({ schedule_index = i }) end
  end
  if depot ~= "" then
    schedule.add_record({ station = depot, temporary = true,
      wait_conditions = { { type = "inactivity", ticks = 300 } } })
  end
  local count = schedule.get_record_count() or 0
  if count > 0 then schedule.go_to_station(depot ~= "" and count or 1) end
  train.manual_mode = false
end

--- Hat der Zug (bei UTL) eine Lieferung?
function Relay.has_delivery(train)
  local info = remote.call("utl", "get_train", train.id) --[[@as table?]]
  return info ~= nil and info.delivery ~= nil
end

return Relay
