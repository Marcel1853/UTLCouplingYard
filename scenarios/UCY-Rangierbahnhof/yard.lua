--- Rangierbahnhof (Marcels Blaupause) mit echtem Be- und Entladen:
---   Abstellgleise (links, Wagen am Westende): Greifarme beladen aus Unendlich-Kisten. Voll → die Rangierlok
---   bringt die Wagen in eine freie Ladebucht.
---   Ladebuchten (rechts): Greifarme entladen in Kisten, die alles verschlucken. Leer → zurück auf ein
---   freies Abstellgleis. Dazwischen wendet die Lok im Stummel unten, damit die Wagen geschoben ankommen.
local BLUEPRINT = require("__UTLCouplingYard__/scenarios/UCY-Rangierbahnhof/blueprint")
local Common = require("__UTLCouplingYard__/scenarios/UCY-Rangierbahnhof/common")

local MOD = "UTLCouplingYard"
local Yard = {}

local RAIL = { ["straight-rail"] = 1, ["curved-rail-a"] = 1, ["curved-rail-b"] = 1, ["half-diagonal-rail"] = 1 }
local CAPACITY = 4 -- Plätze je Wagen (begrenzt), damit Laden und Entladen nicht ewig dauern

--- Blaupause als Geister setzen und wiederbeleben: erst Gleise, dann Signale/Haltestellen, dann Fahrzeuge.
local function build_blueprint(surface, position)
  local inv = game.create_inventory(1)
  inv[1].import_stack(BLUEPRINT)
  local ghosts = inv[1].build_blueprint({ surface = surface, force = "player", position = position,
    build_mode = defines.build_mode.forced })
  local function rank(g)
    local name = g.valid and g.ghost_name or ""
    if RAIL[name] then return 0 end
    if g.valid and (g.ghost_type == "locomotive" or g.ghost_type == "cargo-wagon") then return 2 end
    return 1
  end
  table.sort(ghosts, function(a, b) return rank(a) < rank(b) end)
  for _, g in ipairs(ghosts) do
    if g.valid then g.revive({ raise_revive = true }) end
  end
  inv.destroy()
end

--- Haltestelle samt UTL-Zubehör (Einstellungs-/Ausgabe-Kombinator) entfernen.
local function remove_stop(stop)
  local p = stop.position
  for _, e in pairs(stop.surface.find_entities_filtered({ area = { { p.x - 3, p.y - 3 }, { p.x + 3, p.y + 3 } } })) do
    if e.valid and e ~= stop and e.name:find("^utl%-station") then e.destroy({ raise_destroy = true }) end
  end
  stop.destroy({ raise_destroy = true })
end

local function station(stop, name, role, data)
  stop.backer_name = name
  for key, value in pairs(data or {}) do
    remote.call("utl", "set_station_data", stop.unit_number, MOD, key, value)
  end
  remote.call("utl", "set_station_role", stop.unit_number, role and (MOD .. "/" .. role) or nil)
end

--- Greifarme an einem Gleisstück von x1 bis x2 auf der Seite `side` (-1 = Norden, 1 = Süden).
--- `load` = beladen aus Unendlich-Kisten, sonst entladen in Kisten, die alles verschlucken.
local function station_equipment(surface, rail_y, x1, x2, side, load)
  local placed = 0
  for x = x1, x2 do
    local ix, iy = x + 0.5, rail_y + side * 1.5
    local inserter = Common.place(surface, "bulk-inserter", { ix, iy },
      { direction = (side < 0) == load and defines.direction.north or defines.direction.south })
    if inserter then
      local chest = Common.place(surface, "infinity-chest", { ix, iy + side })
      if chest then
        if load then
          chest.infinity_container_filters = { { index = 1, name = "iron-plate", count = 200, mode = "at-least" } }
        else
          chest.remove_unfiltered_items = true
        end
        placed = placed + 1
      else
        inserter.destroy()
      end
    end
  end
  Common.power_row(surface, rail_y + side * 3.5, x1, x2)
  return placed
end

--- Bauen. Liefert den Startpunkt der Spieler (beim Depot) und die unterste Höhe des Bahnhofs.
function Yard.build(surface, position)
  build_blueprint(surface, position)
  local bottom = -math.huge
  for _, rail in pairs(surface.find_entities_filtered({ type = { "straight-rail", "curved-rail-a", "curved-rail-b" } })) do
    bottom = math.max(bottom, rail.position.y)
  end
  local stops = surface.find_entities_filtered({ name = "utl-train-stop" })
  local sidings, bays, depot, turn = {}, {}, nil, nil
  for _, stop in pairs(stops) do
    local name = stop.backer_name
    if name == "Svein Hofseth" then depot = stop
    elseif name == "Veixus" then turn = stop
    elseif name == "Jordan30001" then sidings[#sidings + 1] = stop
    elseif name == "Siggy" then bays[#bays + 1] = stop
    elseif name == "Michael O'Harra" then remove_stop(stop) end
  end
  -- Abstellgleise: je Gleis zwei Halte; der westliche bleibt (Wagen stehen am Westende)
  local min_x = math.huge
  for _, s in pairs(sidings) do min_x = math.min(min_x, s.position.x) end
  local kept = {}
  for _, s in pairs(sidings) do
    if s.position.x > min_x + 1 then remove_stop(s) else kept[#kept + 1] = s end
  end
  if depot then station(depot, "Rangierdepot", "depot") end
  if turn then station(turn, "Wende", "turn") end
  local loaders = 0
  for _, s in pairs(kept) do
    station(s, "Abstellgleis", "yard", { mode = "drop", shunt_to = "Ladebucht", shunt_when = "full" })
    local y = s.connected_rail.position.y
    loaders = loaders + station_equipment(surface, y, math.floor(s.position.x) - 16, math.floor(s.position.x) + 13, 1, true)
  end
  for _, s in pairs(bays) do
    station(s, "Ladebucht", "yard", { mode = "drop", shunt_to = "Abstellgleis", shunt_when = "empty" })
    local y = s.connected_rail.position.y
    loaders = loaders + station_equipment(surface, y, math.floor(s.position.x) - 15, math.floor(s.position.x) - 1, -1, false)
  end
  -- Wagen begrenzen, Rangierlok tanken und ins Depot schicken
  for _, w in pairs(surface.find_entities_filtered({ type = "cargo-wagon" })) do
    w.get_inventory(defines.inventory.cargo_wagon).set_bar(CAPACITY + 1)
  end
  for _, loco in pairs(surface.find_entities_filtered({ type = "locomotive" })) do
    loco.insert({ name = "coal", count = 50 })
    local schedule = loco.train.get_schedule()
    schedule.clear_records()
    schedule.add_record({ station = "Rangierdepot", wait_conditions = { { type = "inactivity", ticks = 300 } } })
    schedule.go_to_station(1)
    loco.train.manual_mode = false
  end
  local groups = remote.call(MOD, "scan")
  log(("[UCY-SZENARIO] Rangierbahnhof: %d Abstellgleise, %d Ladebuchten, %d Greifarme, %d Wagenverbände")
    :format(#kept, #bays, loaders, groups))
  for _, s in pairs(kept) do Common.sign(s, "siding") end
  if bays[1] then Common.sign(bays[1], "bay") end
  if depot then Common.sign(depot, "depot") end
  if turn then Common.sign(turn, "turn") end
  return depot and depot.position or { x = 0, y = 0 }, bottom
end

return Yard
