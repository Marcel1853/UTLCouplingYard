--- Init-Code der Tipps-&-Tricks-Szenen (laufen in der Simulation mit UTL und diesem Mod; tools/tipstest.sh führt
--- denselben Text in einer normalen Welt aus). Ein gerades Gleis, Haltestellen rechts in Fahrtrichtung; die Szene
--- baut sich nach `TIME` Ticks neu auf, damit man den Ablauf immer wieder sieht.
local COMMON = [[
local s = game.surfaces[1]
local force = game.forces.player
local MOD = "UTLCouplingYard"
local AREA = { { -42, -12 }, { 42, 14 } }
if game.simulation then
  game.simulation.camera_position = { 0, 1 }
  game.simulation.camera_zoom = 0.75
end
local function stop(name, x, east, utl)
  local e = s.create_entity({ name = utl and "utl-train-stop" or "train-stop", position = { x, east and 3 or -1 },
    direction = east and 4 or 12, force = force, raise_built = true })
  e.backer_name = name
  return e
end
local function role(e, name, data)
  remote.call("utl", "set_station_role", e.unit_number, MOD .. "/" .. name)
  for key, value in pairs(data or {}) do remote.call("utl", "set_station_data", e.unit_number, MOD, key, value) end
  return e
end
local function stock(name, x, dir)
  local e = s.create_entity({ name = name, position = { x, 1 }, direction = dir, force = force })
  if name == "locomotive" then e.insert({ name = "coal", count = 50 }) end
  return e
end
local function run(loco, records)
  local schedule = loco.train.get_schedule()
  for _, r in ipairs(records) do
    schedule.add_record({ station = r, wait_conditions = { { type = "time", ticks = 240 } } })
  end
  schedule.go_to_station(1)
  loco.train.manual_mode = false
end
local function shunter()
  role(stop("Rangierdepot", -36, false, true), "depot")
  local loco = stock("locomotive", -26, 12) -- ein Stück vor dem Halt: fährt hin und meldet sich frei
  stock("locomotive", -19, 4)
  run(loco, { "Rangierdepot" }) -- erst nach dem Ankuppeln der zweiten Lok (sonst ist der Fahrplan weg)
end
local function build()
  for _, e in pairs(s.find_entities_filtered({ area = AREA })) do
    if e.type ~= "character" then e.destroy({ raise_destroy = true }) end
  end
  s.build_checkerboard(AREA)
  for x = -37, 37, 2 do s.create_entity({ name = "straight-rail", position = { x, 1 }, direction = 4, force = force }) end
  SCENE()
  remote.call(MOD, "scan")
end
]]

local function scene(time, body)
  return COMMON .. "function SCENE()\n" .. body .. "\nend\nbuild()\nscript.on_nth_tick(" .. time .. ", build)\n"
end

return {
  -- Zug stellt seine Wagen ab und fährt allein weiter
  drop = scene(1500, [[
role(stop("Wagenbahnhof", 0, true, true), "yard", { mode = "drop" })
stop("Ende", 34, true)
local loco = stock("locomotive", -20, 4)
stock("cargo-wagon", -27, 4)
stock("cargo-wagon", -34, 4)
run(loco, { "Wagenbahnhof", "Ende" })]]),
  -- Zug holt die Wagen, die direkt vor dem Halt warten
  pickup = scene(1500, [[
role(stop("Wagenbahnhof", 0, true, true), "yard", { mode = "pickup" })
stop("Ende", 34, true)
stock("cargo-wagon", 3.7, 4)
stock("cargo-wagon", 10.7, 4)
run(stock("locomotive", -25, 4), { "Wagenbahnhof", "Ende" })]]),
  -- Rangierlok bringt abgestellte Wagen von der Ankunft zum Ladegleis
  shunt = scene(2400, [[
shunter()
role(stop("Ankunft", 0, false, true), "yard", { mode = "drop", shunt_to = "Ladegleis", shunt_when = "now" })
role(stop("Ladegleis", 36, true, true), "yard", { mode = "drop" })
stock("cargo-wagon", 3.5, 4)
stock("cargo-wagon", 10.5, 4)]]),
  -- Zug (nur eine Lok vorn) wartet, die Rangierlok stellt Wagen an sein Ende
  attach = scene(3000, [[
shunter()
role(stop("Lager", 0, false, true), "yard", { mode = "drop" })
role(stop("Abfahrt", 30, true, true), "yard", { mode = "attach", attach_from = "Lager" })
stop("Ende", 36, true)
stock("cargo-wagon", 3.5, 4)
stock("cargo-wagon", 10.5, 4)
run(stock("locomotive", 20, 4), { "Abfahrt", "Ende" })]]),
}
