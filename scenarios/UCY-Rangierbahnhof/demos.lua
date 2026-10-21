--- Vorführstrecken unter dem Rangierbahnhof: je eine gerade Strecke für Abstellen, Abholen, Tauschen und die
--- Staffel (echte UTL-Lieferung mit Greifarmen am Anbieter und Abnehmer). Ist eine Vorführung durch, werden
--- ihre Fahrzeuge nach 20 s neu gesetzt und sie beginnt von vorn.
local Common = require("__UTLCouplingYard__/scenarios/UCY-Rangierbahnhof/common")

local MOD = "UTLCouplingYard"
local X1, X2 = -151, 151
local PAUSE = 20 * 60
local ROLLING = { "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon" }

local Demos = {}

local function yard(stop, mode, data)
  remote.call("utl", "set_station_data", stop.unit_number, MOD, "mode", mode)
  for k, v in pairs(data or {}) do remote.call("utl", "set_station_data", stop.unit_number, MOD, k, v) end
  remote.call("utl", "set_station_role", stop.unit_number, MOD .. "/yard")
end

local function drive(loco, stations)
  local schedule = loco.train.get_schedule()
  schedule.clear_records()
  for _, name in ipairs(stations) do
    schedule.add_record({ station = name, wait_conditions = { { type = "time", ticks = 600 } } })
  end
  schedule.go_to_station(1)
  loco.train.manual_mode = false
end

local function fill(wagon)
  wagon.insert({ name = "iron-plate", count = 400 })
end

local function at(loco, name)
  local train = loco and loco.valid and loco.train
  return train and train.state == defines.train_state.wait_station and train.station
    and train.station.backer_name == name
end

--- Greifarme an einem Wagenplatz (Nordseite der Strecke) von x1 bis x2.
local function inserters(surface, y, x1, x2, load)
  for x = x1, x2 do
    local inserter = Common.place(surface, "bulk-inserter", { x + 0.5, y - 1.5 },
      { direction = load and defines.direction.north or defines.direction.south })
    local chest = inserter and Common.place(surface, "infinity-chest", { x + 0.5, y - 2.5 })
    if chest then
      if load then
        chest.infinity_container_filters = { { index = 1, name = "iron-plate", count = 200, mode = "at-least" } }
      else
        chest.remove_unfiltered_items = true
      end
    end
  end
  Common.power_row(surface, y - 3.5, x1, x2)
end

-- ── Die Vorführungen: build (einmal), spawn (Fahrzeuge), done (fertig?) ─────────────────────────────
local LANES = {}

LANES.drop = {
  build = function(s, y)
    Common.rail(s, y, X1, X2)
    local hof = Common.stop(s, "Abstellen", 0, y)
    yard(hof, "drop")
    Common.stop(s, "Abstellen-Ende", 140, y, false, false)
    Common.sign(hof, "drop")
  end,
  spawn = function(s, y, d)
    d.loco = Common.stock(s, "locomotive", -100, y)
    fill(Common.stock(s, "cargo-wagon", -107, y))
    fill(Common.stock(s, "cargo-wagon", -114, y))
    drive(d.loco, { "Abstellen", "Abstellen-Ende" })
  end,
  done = function(d) return at(d.loco, "Abstellen-Ende") end,
}

LANES.pickup = {
  build = function(s, y)
    Common.rail(s, y, X1, X2)
    local hof = Common.stop(s, "Abholen", 0, y)
    yard(hof, "pickup")
    Common.stop(s, "Abholen-Ende", 140, y, false, false)
    Common.sign(hof, "pickup")
  end,
  spawn = function(s, y, d)
    d.loco = Common.stock(s, "locomotive", -100, y)
    fill(Common.stock(s, "cargo-wagon", 14, y))
    fill(Common.stock(s, "cargo-wagon", 21, y))
    drive(d.loco, { "Abholen", "Abholen-Ende" })
  end,
  done = function(d) return at(d.loco, "Abholen-Ende") end,
}

LANES.swap = {
  build = function(s, y)
    Common.rail(s, y, X1, X2)
    local hof = Common.stop(s, "Tauschen", 0, y)
    yard(hof, "swap")
    Common.stop(s, "Tauschen-Ende", 140, y, false, false)
    Common.sign(hof, "swap")
  end,
  spawn = function(s, y, d)
    d.loco = Common.stock(s, "locomotive", -100, y)
    fill(Common.stock(s, "cargo-wagon", -107, y))
    Common.stock(s, "cargo-wagon", 14, y)
    drive(d.loco, { "Tauschen", "Tauschen-Ende" })
  end,
  done = function(d) return at(d.loco, "Tauschen-Ende") end,
}

-- Staffel: Depot ganz im Westen, Anbieter (Osten) lädt mit Greifarmen, Zug A fährt zurück zum
-- Staffel-Bahnhof, lässt den Wagen mit der Lieferung stehen und fährt ins Depot. Zug B holt ihn und
-- fährt zum Abnehmer, wo Greifarme entladen.
LANES.relay = {
  build = function(s, y, d)
    Common.rail(s, y, X1, X2)
    local W = defines.wire_connector_id
    local function signal(target, x, value, count)
      local c = s.create_entity({ name = "constant-combinator", position = { x, y + 4.5 }, force = "player" }) --[[@as LuaEntity]]
      local behavior = c.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
      behavior.get_section(1).set_slot(1, { value = value, min = count })
      c.get_wire_connector(W.circuit_green, true).connect_to(target.get_wire_connector(W.circuit_green, true))
    end
    local function cfg(e, changes)
      changes.network = "Staffel"
      remote.call("utl", "configure_station", e.unit_number, changes)
    end
    cfg(Common.stop(s, "Staffel-Depot", -140, y, true), { mode = "depot" })
    local prov = Common.stop(s, "Staffel-Anbieter", 40, y)
    cfg(prov, { mode = "station", provide = true, request = false })
    signal(prov, 43.5, { type = "item", name = "iron-plate", quality = "normal", comparator = "=" }, 4000)
    inserters(s, y, 33, 39, true)
    local req = Common.stop(s, "Staffel-Abnehmer", 120, y)
    cfg(req, { mode = "station", provide = false, request = true, request_threshold = 100 })
    remote.call("utl", "set_request", req.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
    signal(req, 123.5, { type = "virtual", name = "ucy-relay", quality = "normal", comparator = "=" }, 1)
    inserters(s, y, 113, 119, false)
    d.req = req.unit_number
    local relay = Common.stop(s, "Staffel-Übergabe", 0, y, true)
    yard(relay, "drop", { relay = 1 })
    yard(Common.stop(s, "Staffel-Abholen", 10, y), "pickup")
    Common.sign(relay, "relay")
    Common.sign(prov, "relay-provider")
    Common.sign(req, "relay-requester")
  end,
  spawn = function(s, y, d)
    d.wagon = Common.stock(s, "cargo-wagon", -96, y)
    Common.stock(s, "locomotive", -103, y)
    d.loco = Common.stock(s, "locomotive", -110, y, true)
    d.second, d.completed = nil, nil
    drive(d.loco, { "Staffel-Depot" })
  end,
  tick = function(s, y, d)
    if d.second or not (d.wagon.valid and d.loco.valid and d.wagon.train and d.loco.train) then return end
    local parked = #d.wagon.train.carriages == 1 and d.wagon.position.x > 0 and d.wagon.position.x < 30
    local home = remote.call("utl", "get_train", d.loco.train.id) --[[@as table?]]
    if parked and home and home.idle then
      d.second = Common.stock(s, "locomotive", -60, y)
      drive(d.second, { "Staffel-Abholen" })
    end
  end,
  done = function(d) return d.completed end,
}

local ORDER = { "drop", "pickup", "swap", "relay" }

--- Strecken bauen (einmal) und die erste Runde starten. `y0` = Höhe der ersten Strecke.
function Demos.build(surface, y0)
  if y0 % 2 == 0 then y0 = y0 + 1 end -- Gleise liegen auf ungeraden Höhen
  storage.demos = {}
  for i, key in ipairs(ORDER) do
    local y = y0 + (i - 1) * 24
    local d = { key = key, y = y }
    LANES[key].build(surface, y, d)
    LANES[key].spawn(surface, y, d)
    storage.demos[key] = d
  end
end

local function reset(surface, d)
  for _, e in pairs(surface.find_entities_filtered({ area = { { X1, d.y - 3 }, { X2, d.y + 3 } }, type = ROLLING })) do
    e.destroy({ raise_destroy = true })
  end
  d.finished = nil
  LANES[d.key].spawn(surface, d.y, d)
end

--- Jede Sekunde: Fortschritt prüfen, fertige Vorführungen nach der Pause neu starten.
function Demos.tick(surface)
  for key, d in pairs(storage.demos or {}) do
    local lane = LANES[key]
    if lane.tick then lane.tick(surface, d.y, d) end
    if not d.finished and lane.done(d) then d.finished = game.tick end
    if d.finished and game.tick - d.finished > PAUSE then reset(surface, d) end
  end
end

--- UTL-Ereignis on_delivery_completed: Staffel-Lieferung angekommen.
function Demos.delivery_completed(event)
  local d = storage.demos and storage.demos.relay
  if d and event.requester == d.req then d.completed = true end
end

return Demos
