--- Kuppel-Anlage im Netz, wie die große Strecke im Szenario „Rangierbahnhof“ – aber der Erzzug A fährt durch das
--- Netz, zusammen mit den UTL-Zügen:
---   Erzmine (Kopfbahnhof an einem Außenarm) → quer durchs Netz → Wagenbahnhof (an einem anderen Außenarm):
---   volle Wagen auf „Voll“ schieben → Wende West → leere von „Leer“ holen → durchs Netz zurück zur Erzmine.
---   Zug B (hinter dem Wagenbahnhof): volle Wagen von „Voll“ holen → Entladebahnhof → leere auf „Leer“ schieben →
---   Wende Ost.
--- Alles hier ist im Rahmen „Ostarm eines Kreisels“ aufgeschrieben (Kreiselmitte = 0/0, Arm endet bei x = 53); für
--- einen Westarm wird der Rahmen um 180° gedreht.
---
--- Anschluss an den Arm: Vom Bahnhofsgleis-Abzweig (y = 19, raus aus dem Netz) versetzt eine S-Kurve auf y = 11, das
--- einfahrende Streckengleis (y = -5) wird zum Ausfahrgleis; eine Weiche führt beide auf ein Gleis in beide
--- Richtungen (y = 3). Weichen und S-Kurven aus Marcels Rangier-Blaupause.
---
--- Signale: Am Anschluss je ein Signal hinein und hinaus. Voll- und Leer-Gleis haben in der Mitte zwischen den beiden
--- Halten ein Signalpaar: So steht ein abgestellter Wagen nie im selben Block, in den ein Zug aus dem Netz einfahren
--- will – sonst bliebe das Einfahrsignal für immer rot. Die Halte auf beiden Seiten liegen 8 Felder auseinander,
--- den Rest fährt der Zug mit „Heranfahren“ (Karteneinstellung) bis an die Wagen.
local MOD = "UTLCouplingYard"
local CAPACITY = 4 -- Plätze je Wagen (begrenzt), damit Laden und Entladen nicht ewig dauern

local Facility = {}

local XM = 248 -- Halte „West“ auf Voll und Leer; Halte „Ost“ 8 Felder weiter

local function connect(F)
  F:straight(19, 55, 71)
  F:throat(71, 11, false, "lower") -- S-Kurve 19 → 11
  F:straight(11, 87, 111)
  F:straight(-5, 55, 111)
  F:throat(111, 3, false)
  F:straight(3, 127, 193)
end

local function connect_signals(F)
  F:signal(false, 109.5, 12.5, 12) -- hinein (nach Osten)
  F:signal(false, 108.5, -6.5, 4)  -- hinaus (nach Westen)
end

local function yard(stop, mode)
  remote.call("utl", "set_station_data", stop.unit_number, MOD, "mode", mode)
  remote.call("utl", "set_station_data", stop.unit_number, MOD, "gate", true)
  remote.call("utl", "set_station_role", stop.unit_number, MOD .. "/yard")
  return stop
end

--- Greifarme an Gleis `y` von `x1` bis `x2`, Seite `side` (-1 nördlich, 1 südlich im Rahmen).
local function inserters(F, y, x1, x2, side, load)
  for x = x1, x2 do
    local inserter = F:create("bulk-inserter", x + 0.5, y + side * 1.5, (side < 0) == load and 0 or 8)
    local chest = inserter and F:create("infinity-chest", x + 0.5, y + side * 2.5)
    if chest and load then
      chest.infinity_container_filters = { { index = 1, name = "iron-ore", count = 100, mode = "at-least" } }
    elseif chest then
      chest.remove_unfiltered_items = true
    end
  end
  for x = x1, x2 + 6, 6 do F:create("medium-electric-pole", x + 0.5, y + side * 3.5) end
  local eei = F:create("electric-energy-interface", x1 - 3, y + side * 3.5)
  if eei then
    eei.power_production = 2000000
    eei.electric_buffer_size = 20000000
  end
end

local function wagon(F, x, y)
  local w = F:stock("cargo-wagon", x, y)
  if w then w.get_inventory(defines.inventory.cargo_wagon).set_bar(CAPACITY + 1) end
  return w
end

local function drive(loco, records)
  local schedule = loco.train.get_schedule()
  schedule.clear_records()
  for _, r in ipairs(records) do schedule.add_record({ station = r[1], wait_conditions = { r[2] } }) end
  schedule.go_to_station(1)
  loco.train.manual_mode = false
end

--- Gleise des Wagenbahnhofs (Rahmen F an einem Außenarm) und der Erzmine (Rahmen E an einem anderen).
function Facility.rails(F, E)
  connect(F)
  F:throat(209, 3, true)
  F:straight(-5, 209, 317)
  F:straight(11, 209, 317)
  F:throat(317, 3, false)
  F:straight(3, 333, 601)
  connect(E)
  E:straight(3, 195, 281)
end

--- Signale, Halte, Ladestellen und Züge der Anlage Nummer `n`. Liefert die Loks (zum Nachtanken) und die Mitte des
--- Wagenbahnhofs.
function Facility.build(F, E, n)
  local function name(text) return text .. " " .. n end
  connect_signals(F)
  connect_signals(E)
  for _, y in ipairs({ -5, 11 }) do -- Signalpaar mitten zwischen den Halten
    F:signal(false, XM + 3.5, y - 1.5, 4)
    F:signal(false, XM + 3.5, y + 1.5, 12)
  end
  local erz = E:stop(name("Erzmine"), 240, 3, false)
  F:stop(name("Wende West"), 150, 3, true)
  local voll = yard(F:stop(name("Voll West"), XM, -5, false, true), "drop")
  yard(F:stop(name("Voll Ost"), XM + 8, -5, true, true), "pickup")
  local leer = yard(F:stop(name("Leer West"), XM, 11, false, true), "pickup")
  yard(F:stop(name("Leer Ost"), XM + 8, 11, true, true), "drop")
  F:stop(name("Wende Ost"), 450, 3, false)
  local unload = F:stop(name("Entladebahnhof"), 560, 3, false)
  inserters(E, 3, 213, 227, -1, true)
  inserters(F, 3, 532, 546, -1, false)
  -- Erzzug A an der Erzmine (Loks vorn, Wagen dahinter), leere Wagen auf „Leer“ (wie Zug B sie abstellt),
  -- Zug B am Entladebahnhof
  local a = E:stock("locomotive", 236.3, 3)
  local a2 = E:stock("locomotive", 229.3, 3, true)
  wagon(E, 222.3, 3)
  wagon(E, 215.3, 3)
  wagon(F, XM + 8 + 3.7, 11)
  wagon(F, XM + 8 + 10.7, 11)
  local b = F:stock("locomotive", 556.3, 3)
  local b2 = F:stock("locomotive", 549.3, 3, true)
  remote.call(MOD, "scan") -- Sperren setzen, bevor die Züge losfahren
  local wait = { type = "time", ticks = 60 }
  drive(a, { { name("Erzmine"), { type = "full" } }, { name("Voll West"), wait }, { name("Wende West"), wait },
    { name("Leer West"), wait } })
  drive(b, { { name("Voll Ost"), wait }, { name("Entladebahnhof"), { type = "empty" } }, { name("Leer Ost"), wait },
    { name("Wende Ost"), wait } })
  return { locos = { a, a2, b, b2 }, center = F:pos(XM, 3), a = a, b = b, stops = { erz = erz, voll = voll,
    leer = leer, unload = unload } }
end

return Facility
