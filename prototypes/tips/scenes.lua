--- Init-Code der Tipps-&-Tricks-Szenen (laufen in der Simulation mit UTL und diesem Mod; tools/tipstest.sh führt
--- denselben Text in einer normalen Welt aus). Ein langes gerades Gleis, Haltestellen rechts in Fahrtrichtung, über
--- jeder Haltestelle ein Schild, was sie tut. Jede Szene zeigt einen ganzen Ablauf und baut sich danach (nach `TIME`
--- Ticks) neu auf.
local COMMON = [[
local s = game.surfaces[1]
local force = game.forces.player
local MOD = "UTLCouplingYard"
local AREA = { { -64, -14 }, { 64, 16 } }
if game.simulation then
  game.simulation.camera_position = { 0, 1 }
  game.simulation.camera_zoom = 0.55
end
local function label(x, y, text)
  rendering.draw_text({ text = text, surface = s, target = { x, y }, color = { 1, 1, 1 }, scale = 1.6,
    alignment = "center", vertical_alignment = "bottom", use_rich_text = true, font = "default-bold" })
end
local function stop(name, x, east, utl, text)
  local e = s.create_entity({ name = utl and "utl-train-stop" or "train-stop", position = { x, east and 3 or -1 },
    direction = east and 4 or 12, force = force, raise_built = true })
  e.backer_name = name
  if text then label(x, east and 7 or -3, text) end
  return e
end
local function role(e, name, data)
  remote.call("utl", "set_station_role", e.unit_number, MOD .. "/" .. name)
  for key, value in pairs(data or {}) do remote.call("utl", "set_station_data", e.unit_number, MOD, key, value) end
  return e
end
local function stock(name, x, dir, cargo)
  local e = s.create_entity({ name = name, position = { x, 1 }, direction = dir, force = force })
  if name == "locomotive" then e.insert({ name = "coal", count = 50 }) end
  if cargo then e.insert({ name = cargo, count = 2000 }) end
  return e
end
local function run(loco, records)
  local schedule = loco.train.get_schedule()
  for _, r in ipairs(records) do
    schedule.add_record({ station = r, wait_conditions = { { type = "time", ticks = 120 } } })
  end
  schedule.go_to_station(1)
  loco.train.manual_mode = false
end
local function yard_text(mode) return { "", { "utl-coupling-yard.role-yard" }, "\n", { "utl-coupling-yard.mode-" .. mode } } end
local function shunter()
  role(stop("Rangierdepot", -56, false, true, { "utl-coupling-yard.role-depot" }), "depot")
  local loco = stock("locomotive", -50, 12) -- ein Stück vor dem Halt: fährt hin und meldet sich frei
  stock("locomotive", -43, 4)
  run(loco, { "Rangierdepot" }) -- erst nach dem Ankuppeln der zweiten Lok (sonst ist der Fahrplan weg)
end
local function build()
  for _, e in pairs(s.find_entities_filtered({ area = AREA })) do
    if e.type ~= "character" then e.destroy({ raise_destroy = true }) end
  end
  rendering.clear()
  s.build_checkerboard(AREA)
  for x = -59, 59, 2 do s.create_entity({ name = "straight-rail", position = { x, 1 }, direction = 4, force = force }) end
  SCENE()
  remote.call(MOD, "scan")
end
]]

local function scene(time, body)
  return COMMON .. "function SCENE()\n" .. body .. "\nend\nbuild()\nscript.on_nth_tick(" .. time .. ", build)\n"
end

return {
  -- Tauschen: Zug stellt seine vollen Wagen ab, holt die leeren, die vor dem Halt warten, und fährt weiter
  swap = scene(1080, [[
role(stop("Wagenbahnhof", 0, true, true, yard_text("swap")), "yard", { mode = "swap" })
stop("Ende", 56, true)
stock("cargo-wagon", 3.7, 4)
stock("cargo-wagon", 10.7, 4)
local loco = stock("locomotive", -36, 4)
stock("cargo-wagon", -43, 4, "iron-plate")
stock("cargo-wagon", -50, 4, "iron-plate")
run(loco, { "Wagenbahnhof", "Ende" })]]),
  -- Abholen: Lok kommt allein, kuppelt die wartenden Wagen und fährt mit ihnen weiter
  pickup = scene(900, [[
role(stop("Wagenbahnhof", 0, true, true, yard_text("pickup")), "yard", { mode = "pickup" })
stop("Ende", 56, true)
stock("cargo-wagon", 3.7, 4, "iron-plate")
stock("cargo-wagon", 10.7, 4, "iron-plate")
run(stock("locomotive", -40, 4), { "Wagenbahnhof", "Ende" })]]),
  -- Rangieren: Zug stellt Wagen an der Ankunft ab und fährt weiter, die Rangierlok bringt sie zum Ladegleis
  shunt = scene(1800, [[
shunter()
role(stop("Ankunft", 10, true, true, { "", yard_text("drop"), "\n→ Ladegleis" }), "yard",
  { mode = "drop", shunt_to = "Ladegleis", shunt_when = "now" })
role(stop("Ladegleis", 40, true, true, { "utl-coupling-yard.role-yard" }), "yard", { mode = "drop" })
stop("Ende", 56, true)
local loco = stock("locomotive", -15, 4)
stock("cargo-wagon", -22, 4, "iron-plate")
stock("cargo-wagon", -29, 4, "iron-plate")
run(loco, { "Ankunft", "Ende" })]]),
  -- Anstellen: Zug (nur eine Lok vorn) wartet, die Rangierlok stellt Wagen an sein Ende, der Zug fährt gezogen weiter
  attach = scene(1800, [[
shunter()
role(stop("Lager", -20, false, true, { "utl-coupling-yard.role-yard" }), "yard", { mode = "drop" })
role(stop("Abfahrt", 34, true, true, yard_text("attach")), "yard", { mode = "attach", attach_from = "Lager" })
stop("Ende", 56, true)
stock("cargo-wagon", -16.5, 4, "iron-plate")
stock("cargo-wagon", -9.5, 4, "iron-plate")
run(stock("locomotive", 0, 4), { "Abfahrt", "Ende" })]]),
}
