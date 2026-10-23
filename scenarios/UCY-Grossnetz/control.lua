--- Szenario „UCY-Großnetz“: eigenes Netz aus Kreiseln (Marcels Blaupause „kreisel_signale“) mit UTL-Bahnhöfen und
--- rund 36 UTL-Zügen, die echte Lieferungen fahren, dazu zwei Kuppel-Anlagen, deren Erzzüge quer durch dieses Netz
--- fahren (facility.lua). Gebaut wird nach einer Sekunde – dann haben sich UTL und UTL Coupling Yard angemeldet.
local Network = require("__UTLCouplingYard__/scenarios/UCY-Grossnetz/network")
local Stations = require("__UTLCouplingYard__/scenarios/UCY-Grossnetz/stations")
local Facility = require("__UTLCouplingYard__/scenarios/UCY-Grossnetz/facility")
local Common = require("__UTLCouplingYard__/scenarios/UCY-Rangierbahnhof/common")

local SURFACE = "ucy-grossnetz"

local function L(message) log("[UCY-GROSSNETZ] " .. message) end

local function place(player)
  local surface = game.surfaces[SURFACE]
  if not (surface and storage.start) then return end
  player.teleport(surface.find_non_colliding_position("character", storage.start, 20, 1) or storage.start, surface)
  player.cheat_mode = true
  player.print({ "ucy-grossnetz.welcome" })
end

--- Loks einmal je Minute nachtanken (das Szenario hat keine Tankstellen).
local function refuel(surface)
  for _, loco in pairs(surface.find_entities_filtered({ type = "locomotive" })) do
    local fuel = loco.get_fuel_inventory()
    if fuel and fuel.get_item_count("coal") < 50 then fuel.insert({ name = "coal", count = 50 }) end
  end
end

--- Kurzer Stand im Log (für den Test ohne Fenster): Lieferungen, freie Züge, wo die Anlagenzüge sind.
local function report()
  local parts = {}
  for _, loco in ipairs(storage.watch or {}) do
    if loco.valid and loco.train then
      local schedule = loco.train.get_schedule()
      local record = schedule.get_record({ schedule_index = schedule.current })
      parts[#parts + 1] = ("%s: %d Fahrzeuge, Zustand %d"):format(record and record.station or "?",
        #loco.train.carriages, loco.train.state)
    end
  end
  -- warten: am Signal vor dem eigenen Depot (Warteplatz) oder irgendwo sonst; Handbetrieb: Wagen ohne Lok oder Zug
  local count = { queue = 0, signal = 0, wagons = 0, manual = 0, moving = 0, other = 0 }
  local S = defines.train_state
  for _, train in pairs(game.train_manager.get_trains({ surface = SURFACE })) do
    local state = train.state
    if state == S.wait_signal then
      local stop = train.path_end_stop
      if stop and stop.backer_name:find("^Depot") then count.queue = count.queue + 1 else count.signal = count.signal + 1 end
    elseif state == S.manual_control or state == S.manual_control_stop then
      local locos = train.locomotives
      if #locos.front_movers + #locos.back_movers == 0 then count.wagons = count.wagons + 1
      else count.manual = count.manual + 1 end
    elseif state == S.on_the_path or state == S.arrive_signal or state == S.arrive_station then
      count.moving = count.moving + 1
    else
      count.other = count.other + 1
    end
  end
  L(("Lieferungen %d laufend, %d fertig, freie Züge %d | fahren %d, Warteplatz Depot %d, warten am Signal %d, "
    .. "abgestellte Wagen %d, Handbetrieb %d, sonst %d | %s"):format(remote.call("utl", "delivery_count"),
    storage.completed or 0, remote.call("utl", "idle_train_count"), count.moving, count.queue, count.signal,
    count.wagons, count.manual, count.other, table.concat(parts, " | ")))
end

local function tick(event)
  local surface = game.surfaces[SURFACE]
  if not surface then return end
  if event.tick % 3600 == 0 then refuel(surface) end
  if event.tick % 1800 == 0 then report() end
end

local function completed() storage.completed = (storage.completed or 0) + 1 end

local function listen()
  local ids = remote.call("utl", "get_event_ids") --[[@as table]]
  script.on_event(ids.on_delivery_completed, completed)
end

local function generate(surface)
  local x1, y1 = -700, -120
  local x2, y2 = Network.D * (Network.COLS - 1) + 700, Network.D * (Network.ROWS - 1) + 120
  for x = x1, x2, 160 do
    for y = y1, y2, 160 do surface.request_to_generate_chunks({ x, y }, 3) end
  end
  surface.force_generate_chunk_requests()
  return { { x1, y1 }, { x2, y2 } }
end

local function setup()
  script.on_nth_tick(60, nil)
  local surface = game.create_surface(SURFACE)
  surface.generate_with_lab_tiles = true
  surface.always_day = true
  local area = generate(surface)
  local force = game.forces["player"]
  force.research_all_technologies()
  -- Die Halte auf beiden Seiten eines Wagenbahnhofs liegen auseinander (Signal dazwischen): heranfahren
  remote.call("UTLCouplingYard", "crawl", true)
  local stats = { rails_failed = 0, signals_failed = 0, signals = 0 }
  local sidings = Network.build(surface, stats)
  local count = Stations.build(sidings)
  -- Anlage 1: Wagenbahnhof am Ostarm oben rechts, Erzmine am Westarm oben links; Anlage 2 um 180° gedreht
  local last_i, last_j = Network.COLS - 1, Network.ROWS - 1
  local frames = {
    { Network.arm(surface, last_i, 0, "east", stats), Network.arm(surface, 0, 0, "west", stats) },
    { Network.arm(surface, 0, last_j, "west", stats), Network.arm(surface, last_i, last_j, "east", stats) },
  }
  for _, f in ipairs(frames) do Facility.rails(f[1], f[2]) end
  storage.watch = {}
  for n, f in ipairs(frames) do
    local made = Facility.build(f[1], f[2], n)
    storage.watch[#storage.watch + 1] = made.a
    storage.watch[#storage.watch + 1] = made.b
    if n == 1 then storage.start = { x = made.center[1], y = made.center[2] + 12 } end
    Common.sign(made.stops.erz, "ore")
    Common.sign(made.stops.voll, "full-track")
    Common.sign(made.stops.leer, "empty-track")
    Common.sign(made.stops.unload, "unload")
  end
  force.chart(surface, area)
  L(("gebaut: %d Bahnhöfe (%d Depots, %d Anbieter, %d Abnehmer), %d UTL-Züge, Halte ohne Gleis %d, Signale %d, "
    .. "Gleise fehlgeschlagen %d, Signale fehlgeschlagen %d"):format(count.stations, count.depot, count.provider,
    count.requester, count.trains, count.unconnected, stats.signals, stats.rails_failed, stats.signals_failed))
  listen()
  script.on_nth_tick(60, tick)
  for _, player in pairs(game.players) do place(player) end
end

script.on_init(function() script.on_nth_tick(60, setup) end)
script.on_load(function()
  if storage.start then
    listen()
    script.on_nth_tick(60, tick)
  else script.on_nth_tick(60, setup) end
end)
script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player then place(player) end
end)
