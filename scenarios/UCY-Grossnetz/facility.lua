--- Kuppel-Anlage in einem Block des Netzes (Erzmine oder Fabrik), so wie es bei der echten Bahn läuft:
---   Übergabebahnhof (oben, am Bahnhofsgleis der Strecke): Der Streckenzug fährt gezogen ein, stellt seine Wagen auf
---   dem Ankunftsgleis ab, setzt über die Lokwende um, holt die bereitgestellten Wagen vom Abholgleis und fährt
---   gezogen weiter.
---   Rangierbahnhof (unten, Marcels Blaupause rangier.lua): Die Rangierlok holt die abgestellten Wagen vom
---   Ankunftsgleis an die Ladegleise (Erzmine: beladen) bzw. Entladegleise (Fabrik) und stellt sie danach auf dem
---   Abholgleis bereit.
--- Aufgeschrieben im Rahmen der Strecke über dem Block (Kreisel bei x = 0, Bahnhofsgleis nach Osten bei y = 19).
---
--- Gleise: Abzweig bei x = 63 → Ankunftsgleis y = 25; Verbindungsgleis y = 33 mündet bei x = 91 ein (Weg der
--- Rangierlok); Abholgleis y = 41 (westlich davon das Gleis zum Rangierbahnhof); Weiche bei x = 163 führt Ankunfts-
--- und Abholgleis auf y = 33: geradeaus die Lokwende, über eine S-Kurve zurück aufs Bahnhofsgleis (Einmündung 229).
--- Signale: an jeder Weiche Kettensignal bei der Einfahrt, normales Signal bei der Ausfahrt. Abgestellte Wagen
--- stehen immer in einem eigenen Block, nie im Fahrweg eines Zuges aus dem Netz; die Rangierlok fährt zum Ankuppeln
--- bis 16 Felder vor die Wagen (freier Block) und schiebt dann heran, der Streckenzug am Abholgleis ebenso
--- (Karteneinstellung „Heranfahren“).
local Common = require("__UTLCouplingYard__/scenarios/UCY-Rangierbahnhof/common")
local Rangier = require("__UTLCouplingYard__/scenarios/UCY-Grossnetz/rangier")

local MOD = "UTLCouplingYard"
local CAPACITY = 4    -- Plätze je Wagen (begrenzt), damit Laden und Entladen nicht ewig dauern
local BX, BY = 168, 166 -- Lage der Rangier-Blaupause im Rahmen
local ARRIVE, DEPART, READY, TURN = 158, 148, 140, 248

local NAMES = { S = "straight-rail", A = "curved-rail-a", B = "curved-rail-b", H = "half-diagonal-rail",
  G = "rail-signal", K = "rail-chain-signal" }

local Facility = {}

function Facility.rails(F)
  F:diverge(63, 19)
  F:straight(25, 83, 163)          -- Einfahr- und Ankunftsgleis
  F:straight(33, 85, 91)           -- Verbindungsgleis der Rangierlok …
  F:throat(91, 25, false, "lower") -- … mündet ins Ankunftsgleis
  F:straight(41, 67, 163)          -- Gleis vom Rangierbahnhof, östlich davon das Abholgleis
  F:throat(69, 33, false, "lower") -- Abzweig zum Verbindungsgleis
  F:throat(163, 33, false)         -- Ankunfts- und Abholgleis → y = 33
  F:straight(33, 179, 255)         -- Lokwende (Stumpf)
  F:throat(183, 25, false, "lower")
  F:straight(25, 199, 209)
  F:merge(229, 19)
  -- zum Rangierbahnhof: 90°-Kurve nach Süden, senkrecht, 90°-Kurve nach Osten
  F:curve(53, 55, 0)
  F:vertical(53, 55, 93)
  F:curve(67, 107, 3)
  F:straight(107, 67, 83)
  for _, e in ipairs(Rangier.rails) do
    if not (e[1] == "G" or e[1] == "K") then F:create(NAMES[e[1]], e[2] + BX, e[3] + BY, e[4]) end
  end
end

local function signals(F)
  local list = {
    { true, 59.5, 20.5, 12 }, { false, 72.5, 20.5, 12 }, { false, 81.5, 26.5, 12 },   -- Abzweig
    { true, 89.5, 26.5, 12 }, { true, 89.5, 34.5, 12 }, { false, 89.5, 31.5, 4 },      -- Einmündung Verbindungsgleis
    { false, 109.5, 26.5, 12 }, { true, 109.5, 23.5, 4 },
    { false, 127.5, 23.5, 4 }, { false, 127.5, 26.5, 12 },                             -- Ankunftsgleis geteilt
    { false, 110.5, 39.5, 4 }, { false, 110.5, 42.5, 12 },                             -- Bereitstellung (Block)
    { false, 143.5, 39.5, 4 }, { false, 143.5, 42.5, 12 },                             -- zwischen den Halten
    { true, 161.5, 26.5, 12 }, { true, 161.5, 42.5, 12 }, { false, 161.5, 39.5, 4 },   -- Weiche Ost
    { true, 201.5, 31.5, 4 }, { false, 201.5, 34.5, 12 },
    { true, 207.5, 26.5, 12 }, { true, 219.5, 20.5, 12 }, { true, 230.5, 20.5, 12 },   -- Einmündung
  }
  for _, s in ipairs(list) do F:signal(s[1], s[2], s[3], s[4]) end
  for _, e in ipairs(Rangier.rails) do
    if e[1] == "G" or e[1] == "K" then F:create(NAMES[e[1]], e[2] + BX, e[3] + BY, e[4]) end
  end
end

local function station(stop, role, data)
  for key, value in pairs(data or {}) do
    remote.call("utl", "set_station_data", stop.unit_number, MOD, key, value)
  end
  remote.call("utl", "set_station_role", stop.unit_number, MOD .. "/" .. role)
  return stop
end

--- Greifarme am Ladegleis (Weltkoordinaten, Rahmen ungedreht) von x1 bis x2, Seite `side` (-1 Norden, 1 Süden).
local function equipment(s, y, x1, x2, side, load)
  for x = x1, x2 do
    local inserter = Common.place(s, "bulk-inserter", { x + 0.5, y + side * 1.5 },
      { direction = (side < 0) == load and defines.direction.north or defines.direction.south })
    local chest = inserter and Common.place(s, "infinity-chest", { x + 0.5, y + side * 2.5 })
    if chest and load then
      chest.infinity_container_filters = { { index = 1, name = "iron-ore", count = 100, mode = "at-least" } }
    elseif chest then
      chest.remove_unfiltered_items = true
    end
  end
  Common.power_row(s, y + side * 3.5, x1, x2)
end

--- Zwei Wagen auf Gleis `y`, Mitten bei x1 und x2 (Rahmen); `full` = mit Erz.
local function wagons(F, y, x1, x2, full)
  for _, x in ipairs({ x1, x2 }) do
    local w = F:stock("cargo-wagon", x, y)
    if w then
      local inventory = w.get_inventory(defines.inventory.cargo_wagon)
      inventory.set_bar(CAPACITY + 1)
      if full then inventory.insert({ name = "iron-ore", count = 50 * CAPACITY }) end
    end
  end
end

--- Signale, Halte, Ladestellen, Rangierlok und Startwagen. `mine` = Erzmine (sonst Fabrik). Liefert die Halte.
function Facility.build(F, prefix, mine)
  signals(F)
  local s = F.surface
  local function name(text) return prefix .. " " .. text end
  local load_name = name(mine and "Ladegleis" or "Entladegleis")
  local stops = {}
  stops.arrive = station(F:stop(name("Ankunft"), ARRIVE, 25, false, true), "yard",
    { mode = "drop", shunt_to = load_name, shunt_when = "now", gate = true })
  stops.depart = station(F:stop(name("Abfahrt"), DEPART, 41, true, true), "yard", { mode = "pickup", gate = true })
  stops.ready = station(F:stop(name("Bereitstellung"), READY, 41, false, true), "yard", { mode = "drop" })
  stops.turn = F:stop(name("Lokwende"), TURN, 33, false)
  stops.loads = {}
  for _, e in ipairs(Rangier.stops) do
    local stop = F:create("utl-train-stop", e[2] + BX, e[3] + BY, e[4], { raise_built = true })
    if stop then
      if e[1] == "depot" then
        stop.backer_name = name("Rangierdepot")
        stops.depot = station(stop, "depot")
      elseif e[1] == "turn" then
        stop.backer_name = name("Wende")
        stops.shunt_turn = station(stop, "turn")
      else
        stop.backer_name = load_name
        station(stop, "yard", { mode = "drop", shunt_to = name("Bereitstellung"), shunt_when = mine and "full" or "empty" })
        local y, x = stop.connected_rail.position.y, math.floor(stop.position.x)
        if e[1] == "west" then equipment(s, y, x - 16, x + 13, 1, mine) else equipment(s, y, x - 15, x - 1, -1, mine) end
        stops.loads[#stops.loads + 1] = stop
      end
    end
  end
  -- Rangierlok (je eine Lok in beide Richtungen) im Depot
  local l1 = F:create("locomotive", 15 + BX, -102 + BY, 0)
  local l2 = F:create("locomotive", 15 + BX, -95 + BY, 8)
  for _, l in ipairs({ l1, l2 }) do if l then l.insert({ name = "coal", count = 50 }) end end
  if l1 then
    local schedule = l1.train.get_schedule()
    schedule.add_record({ station = name("Rangierdepot"), wait_conditions = { { type = "inactivity", ticks = 300 } } })
    schedule.go_to_station(1)
    l1.train.manual_mode = false
  end
  -- Startwagen: Erzmine – volle Wagen bereitgestellt; Fabrik – leere bereitgestellt, volle am ersten Entladegleis
  wagons(F, 41, READY - 3.7, READY - 10.7, mine)
  if not mine then
    local first = stops.loads[3]
    local y, x = first.connected_rail.position.y - F.oy, first.position.x - F.ox -- Rahmen ungedreht
    wagons(F, y, x - 3.7, x - 10.7, true)
  end
  Common.sign(stops.arrive, "arrive")
  Common.sign(stops.depart, "depart")
  Common.sign(stops.ready, "ready")
  Common.sign(stops.loads[3], mine and "load" or "unload")
  Common.sign(stops.depot, "depot")
  Common.sign(stops.shunt_turn, "turn")
  return stops
end

--- Streckenzug (zwei Loks Rücken an Rücken, zwei leere Wagen) am Ankunftsgleis der Anlage im Rahmen F.
function Facility.train(F, records)
  local a = F:stock("locomotive", ARRIVE - 3.7, 25)
  F:stock("locomotive", ARRIVE - 10.7, 25, true)
  wagons(F, 25, ARRIVE - 17.7, ARRIVE - 24.7, false)
  local schedule = a.train.get_schedule()
  schedule.clear_records()
  for _, r in ipairs(records) do
    schedule.add_record({ station = r, wait_conditions = { { type = "time", ticks = 60 } } })
  end
  schedule.go_to_station(1)
  a.train.manual_mode = false
  return a
end

return Facility
