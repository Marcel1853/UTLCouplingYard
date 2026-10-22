--- Große Strecke, von Hand gesetzt (ohne Blaupause): Erzmine im Westen, Wagenbahnhof in der Mitte, Entladebahnhof
--- im Osten, je rund 500 Kacheln auseinander. Der Wagenbahnhof hat zwei Gleise (Voll oben, Leer unten), jedes mit
--- zwei Halten gegenüber in der Mitte – wie in Marcels Blaupause.
---   Erzzug A (Westseite): Erzmine (Greifarme laden Erz) → schiebt die vollen Wagen auf „Voll“, kuppelt ab →
---   Wende West → holt die leeren Wagen von „Leer“ → Erzmine.
---   Zug B (Ostseite): holt die vollen Wagen von „Voll“ → Entladebahnhof (Greifarme entladen) → schiebt die leeren
---   auf „Leer“ → Wende Ost → wieder zu „Voll“.
--- Die vier Halte steuern ihr Zuglimit selbst (Einstellung „Zuglimit steuern“): Ein Zug fährt erst los, wenn sein
--- Platz frei ist bzw. Wagen auf ihn warten.
local Common = require("__UTLCouplingYard__/scenarios/UCY-Rangierbahnhof/common")

local MOD = "UTLCouplingYard"
local BigLine = {}

local XE, XU = -520, 520        -- Erzmine, Entladebahnhof (Halte)
local WEST, EAST = -159, 159    -- Anfang und Ende der Bahnhofsgleise (Weichen davor bzw. dahinter)
local CAPACITY = 4              -- Plätze je Wagen (begrenzt), damit Laden und Entladen nicht ewig dauern

local function rail(s, name, x, y, dir)
  s.create_entity({ name = name, position = { x, y }, direction = dir, force = "player" })
end

--- Weiche (S-Kurven aus Marcels Rangier-Blaupause): Gleise Y-8 und Y+8 laufen auf das Hauptgleis Y.
--- `east` = die beiden Gleise liegen östlich (Weiche am Westende des Bahnhofs), sonst westlich.
local function throat(s, x, Y, east)
  if east then -- um 180° gedreht
    rail(s, "curved-rail-a", x - 3, Y + 8, 14); rail(s, "curved-rail-b", x - 8, Y + 6, 14)
    rail(s, "curved-rail-b", x - 12, Y + 2, 6); rail(s, "curved-rail-a", x - 17, Y, 6)
    rail(s, "curved-rail-a", x - 3, Y - 8, 12); rail(s, "curved-rail-b", x - 8, Y - 6, 12)
    rail(s, "curved-rail-b", x - 12, Y - 2, 4); rail(s, "curved-rail-a", x - 17, Y, 4)
  else
    rail(s, "curved-rail-a", x + 3, Y - 8, 6); rail(s, "curved-rail-b", x + 8, Y - 6, 6)
    rail(s, "curved-rail-b", x + 12, Y - 2, 14); rail(s, "curved-rail-a", x + 17, Y, 14)
    rail(s, "curved-rail-a", x + 3, Y + 8, 4); rail(s, "curved-rail-b", x + 8, Y + 6, 4)
    rail(s, "curved-rail-b", x + 12, Y + 2, 12); rail(s, "curved-rail-a", x + 17, Y, 12)
  end
end

local function yard(stop, mode)
  remote.call("utl", "set_station_data", stop.unit_number, MOD, "mode", mode)
  remote.call("utl", "set_station_data", stop.unit_number, MOD, "gate", true)
  remote.call("utl", "set_station_role", stop.unit_number, MOD .. "/yard")
  return stop
end

--- Greifarme am Wagenplatz: Seite `side` (-1 Norden, 1 Süden), `load` = aus Unendlich-Kisten mit Erz.
local function inserters(s, y, x1, x2, side, load)
  for x = x1, x2 do
    local inserter = Common.place(s, "bulk-inserter", { x + 0.5, y + side * 1.5 },
      { direction = (side < 0) == load and defines.direction.north or defines.direction.south })
    local chest = inserter and Common.place(s, "infinity-chest", { x + 0.5, y + side * 2.5 })
    if chest then
      if load then
        chest.infinity_container_filters = { { index = 1, name = "iron-ore", count = 100, mode = "at-least" } }
      else
        chest.remove_unfiltered_items = true
      end
    end
  end
  Common.power_row(s, y + side * 3.5, x1, x2)
end

local function wagon(s, x, y)
  local w = Common.stock(s, "cargo-wagon", x, y)
  w.get_inventory(defines.inventory.cargo_wagon).set_bar(CAPACITY + 1)
  return w
end

local function drive(loco, records)
  local schedule = loco.train.get_schedule()
  schedule.clear_records()
  for _, r in ipairs(records) do
    schedule.add_record({ station = r[1], wait_conditions = { r[2] } })
  end
  schedule.go_to_station(1)
  loco.train.manual_mode = false
end

--- Bauen auf Höhe Y (ungerade). Liefert den Mittelpunkt (Wagenbahnhof).
function BigLine.build(s, Y)
  if Y % 2 == 0 then Y = Y + 1 end
  -- Hauptgleis West und Ost (bis unter die Weichen), Bahnhofsgleise
  Common.rail(s, Y, XE - 41, WEST - 15)
  Common.rail(s, Y, EAST + 16, XU + 41)
  Common.rail(s, Y - 8, WEST, EAST)
  Common.rail(s, Y + 8, WEST, EAST)
  throat(s, WEST, Y, true)
  throat(s, EAST, Y, false)
  -- Halte: Erzmine (Richtung Westen, Stumpfende), Entladebahnhof (Richtung Osten, Stumpfende), Wenden
  local erz = Common.stop(s, "Erzmine", XE, Y, true, false)
  local unload = Common.stop(s, "Entladebahnhof", XU, Y, false, false)
  Common.stop(s, "Wende West", -260, Y, true, false)
  Common.stop(s, "Wende Ost", 260, Y, false, false)
  -- Wagenbahnhof: je Gleis zwei Halte gegenüber in der Mitte
  local voll_west = yard(Common.stop(s, "Voll West", 0, Y - 8), "drop")
  yard(Common.stop(s, "Voll Ost", 0, Y - 8, true), "pickup")
  local leer_west = yard(Common.stop(s, "Leer West", 0, Y + 8), "pickup")
  yard(Common.stop(s, "Leer Ost", 0, Y + 8, true), "drop")
  -- Greifarme: Erz laden (Süden der Erzmine), entladen (Norden des Entladebahnhofs)
  inserters(s, Y, XE + 13, XE + 27, 1, true)
  inserters(s, Y, XU - 28, XU - 14, -1, false)
  -- Erzzug A an der Erzmine (Loks vorn nach Westen, Wagen dahinter)
  local a = Common.stock(s, "locomotive", XE + 3.7, Y, true)
  Common.stock(s, "locomotive", XE + 10.7, Y)
  wagon(s, XE + 17.7, Y)
  wagon(s, XE + 24.7, Y)
  -- leere Wagen warten auf „Leer“ (so, wie Zug B sie abstellt)
  wagon(s, 3.7, Y + 8)
  wagon(s, 10.7, Y + 8)
  -- Zug B am Entladebahnhof (Loks vorn nach Osten)
  local b = Common.stock(s, "locomotive", XU - 3.7, Y)
  Common.stock(s, "locomotive", XU - 10.7, Y, true)
  remote.call(MOD, "scan") -- Sperren setzen, bevor die Züge losfahren
  local wait = { type = "time", ticks = 60 }
  drive(a, { { "Erzmine", { type = "full" } }, { "Voll West", wait }, { "Wende West", wait }, { "Leer West", wait } })
  drive(b, { { "Voll Ost", wait }, { "Entladebahnhof", { type = "empty" } }, { "Leer Ost", wait },
    { "Wende Ost", wait } })
  storage.bigline = { a = a, b = b }
  Common.sign(erz, "ore")
  Common.sign(voll_west, "full-track")
  Common.sign(leer_west, "empty-track")
  Common.sign(unload, "unload")
  log(("[UCY-SZENARIO] Große Strecke auf Höhe %d gebaut"):format(Y))
  return { x = 0, y = Y }
end

return BigLine
