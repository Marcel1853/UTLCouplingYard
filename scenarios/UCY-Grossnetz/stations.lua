--- UTL-Bahnhöfe auf den Bahnhofsgleisen des Netzes: Depots (je drei Züge: einer am Halt, zwei auf den
--- Warteplätzen), Anbieter (Unendlich-Kisten, verkabelt – so sieht UTL den Bestand) und Abnehmer (Kisten, die alles
--- verschlucken – der Bedarf reißt nie ab, damit immer Verkehr ist). Maße der Ladestellen wie in UTLs Szenario
--- „UTL-Beispiele“: erster Wagen 10 Felder hinter dem Gleis des Halts, Greifarm 1,5 und Kiste 2,5 Felder daneben.
local Stations = {}

local W = defines.wire_connector_id
local ITEMS = { "iron-plate", "copper-plate", "steel-plate", "coal", "stone", "iron-gear-wheel" }
local KINDS = { "depot", "provider", "requester" }
local WAGONS = 2
local QUEUE = { 0, 26, 52 } -- Zugspitze der Depotzüge: am Halt und auf den beiden Warteplätzen

-- Fahrtrichtung (16er) → Vorwärts- und Rechtsvektor
local DIRS = {
  [0] = { f = { 0, -1 }, r = { 1, 0 } },
  [4] = { f = { 1, 0 }, r = { 0, 1 } },
  [8] = { f = { 0, 1 }, r = { -1, 0 } },
  [12] = { f = { -1, 0 }, r = { 0, -1 } },
}

local function add(p, v, k) return { p[1] + v[1] * k, p[2] + v[2] * k } end

local function direction_of(v)
  if v[2] < 0 then return 0 elseif v[1] > 0 then return 4 elseif v[2] > 0 then return 8 end
  return 12
end

local function entity(surface, name, position, extra)
  local spec = { name = name, position = position, force = "player" }
  for k, v in pairs(extra or {}) do spec[k] = v end
  return surface.create_entity(spec)
end

local function link(a, b)
  if not (a and b and a.valid and b.valid) then return false end
  return a.get_wire_connector(W.circuit_green, true).connect_to(b.get_wire_connector(W.circuit_green, true))
end

--- Ladestelle je Wagen: Greifarm + Kiste, dazu Strom. Anbieter laden aus Unendlich-Kisten (verkabelt über zwei
--- Masten zur Haltestelle – ein Kabel reicht nur 9 Felder), Abnehmer entladen in Kisten, die alles löschen.
local function bay(stop, item, provide)
  local surface, d = stop.surface, DIRS[stop.direction]
  local base = { stop.connected_rail.position.x, stop.connected_rail.position.y }
  local grab = provide and d.r or { -d.r[1], -d.r[2] }
  local previous = stop
  for n = 0, WAGONS - 1 do
    local at = add(add(base, d.f, -10 - 7 * n), d.f, -0.5)
    entity(surface, "bulk-inserter", add(at, d.r, 1.5), { direction = direction_of(grab) })
    local chest = entity(surface, "infinity-chest", add(at, d.r, 2.5))
    local pole = entity(surface, "medium-electric-pole", add(add(at, d.r, 3.5), d.f, 2))
    local relay = entity(surface, "medium-electric-pole", add(add(at, d.r, 3.5), d.f, -3))
    if chest and provide then
      chest.infinity_container_filters = { { index = 1, name = item, count = 4000, mode = "at-least" } }
      link(chest, pole); link(pole, previous)
      previous = pole
    elseif chest then
      chest.remove_unfiltered_items = true
    end
    if relay and n == WAGONS - 1 then
      local eei = entity(surface, "electric-energy-interface", add(add(at, d.r, 6), d.f, -3))
      if eei then
        eei.power_production = 2000000
        eei.electric_buffer_size = 20000000
      end
    end
  end
end

--- Zug für ein Depot: eine Lok, zwei Wagen; `front` = Abstand der Zugspitze vom Gleispunkt des Halts.
local function train(stop, front, depot)
  local surface, d = stop.surface, DIRS[stop.direction]
  local base = { stop.connected_rail.position.x, stop.connected_rail.position.y }
  local loco = entity(surface, "locomotive", add(base, d.f, -3 - front), { direction = stop.direction })
  if not loco then return nil end
  loco.insert({ name = "coal", count = 50 })
  for n = 1, WAGONS do
    entity(surface, "cargo-wagon", add(base, d.f, -3 - front - 7 * n), { direction = stop.direction })
  end
  local schedule = loco.train.get_schedule()
  schedule.add_record({ station = depot, wait_conditions = { { type = "inactivity", ticks = 300 } } })
  schedule.go_to_station(1)
  loco.train.manual_mode = false
  return loco.train
end

local function configure(stop, kind, item)
  local unit = stop.unit_number
  if kind == "depot" then
    remote.call("utl", "configure_station", unit, { mode = "depot", max_trains = #QUEUE })
    stop.trains_limit = #QUEUE
  elseif kind == "provider" then
    remote.call("utl", "configure_station", unit,
      { mode = "station", provide = true, request = false, provide_threshold = 100, max_trains = 2 })
  else
    remote.call("utl", "configure_station", unit,
      { mode = "station", provide = false, request = true, request_threshold = 100, max_trains = 2 })
    remote.call("utl", "set_request", unit, 1, { type = "item", name = item }, 400)
  end
end

--- Bahnhöfe bauen. Liefert Zahlen für das Log: Bahnhöfe, Züge, Haltestellen ohne Gleis.
function Stations.build(sidings)
  local count = { stations = 0, trains = 0, unconnected = 0, depot = 0, provider = 0, requester = 0 }
  for k, siding in ipairs(sidings) do
    local kind = KINDS[(k - 1) % #KINDS + 1]
    count[kind] = count[kind] + 1
    local item = ITEMS[(count[kind] - 1) % #ITEMS + 1]
    local name = kind == "depot" and ("Depot " .. count.depot)
      or ("[item=" .. item .. "] " .. (kind == "provider" and "Anbieter " or "Abnehmer ") .. count[kind])
    local stop = siding.frame:stop(name, siding.x, siding.y, siding.west, true)
    if stop and stop.connected_rail then
      count.stations = count.stations + 1
      configure(stop, kind, item)
      if kind == "depot" then
        for _, front in ipairs(QUEUE) do
          if train(stop, front, name) then count.trains = count.trains + 1 end
        end
      else
        bay(stop, item, kind == "provider")
      end
    else
      count.unconnected = count.unconnected + 1
    end
  end
  return count
end

return Stations
