--- Szenario „UCY-Rangierbahnhof“: großer Rangierbahnhof mit Rangierlok und echtem Be- und Entladen, darunter
--- Vorführstrecken für Abstellen, Abholen, Tauschen und die Staffel. Gebaut wird nach einer Sekunde – dann
--- haben sich UTL und UTL Coupling Yard angemeldet.
local Yard = require("__UTLCouplingYard__/scenarios/UCY-Rangierbahnhof/yard")
local Demos = require("__UTLCouplingYard__/scenarios/UCY-Rangierbahnhof/demos")
local BigLine = require("__UTLCouplingYard__/scenarios/UCY-Rangierbahnhof/bigline")

local SURFACE = "ucy-rangierbahnhof"

local function place(player)
  local surface = game.surfaces[SURFACE]
  if not (surface and storage.start) then return end
  player.teleport(surface.find_non_colliding_position("character", storage.start, 20, 1) or storage.start, surface)
  player.cheat_mode = true
  player.print({ "ucy-scenario.welcome" })
end

local function listen()
  local ids = remote.call("utl", "get_event_ids") --[[@as table]]
  script.on_event(ids.on_delivery_completed, Demos.delivery_completed)
end

--- Szenario: Loks einmal je Minute nachtanken (ohne Tankstelle läuft der Bahnhof sonst nach ein paar
--- Fahrten leer).
local function refuel(surface)
  for _, loco in pairs(surface.find_entities_filtered({ type = "locomotive" })) do
    local fuel = loco.get_fuel_inventory()
    if fuel and fuel.get_item_count("coal") < 50 then fuel.insert({ name = "coal", count = 50 }) end
  end
end

local function tick()
  local surface = game.surfaces[SURFACE]
  if surface then Demos.tick(surface) end
  if surface and game.tick % 3600 == 0 then refuel(surface) end
end

local function setup()
  script.on_nth_tick(60, nil)
  local s = game.create_surface(SURFACE)
  s.generate_with_lab_tiles = true
  s.always_day = true
  s.request_to_generate_chunks({ 0, 0 }, 8)
  s.force_generate_chunk_requests()
  local force = game.forces["player"]
  force.research_all_technologies()
  local center, bottom = Yard.build(s, { 0, 0 })
  local last = Demos.build(s, math.floor(bottom) + 31)
  s.request_to_generate_chunks({ 0, last + 60 }, 20)
  s.force_generate_chunk_requests()
  BigLine.build(s, last + 60)
  storage.start = { x = center.x, y = center.y + 10 }
  force.chart(s, { { -600, -160 }, { 600, last + 100 } })
  listen()
  script.on_nth_tick(60, tick)
  for _, player in pairs(game.players) do place(player) end
end

script.on_init(function() script.on_nth_tick(60, setup) end)
script.on_load(function()
  if storage.start then
    listen()
    script.on_nth_tick(60, tick)
  else
    script.on_nth_tick(60, setup)
  end
end)
script.on_event(defines.events.on_player_created, function(event)
  local player = game.get_player(event.player_index)
  if player then place(player) end
end)
