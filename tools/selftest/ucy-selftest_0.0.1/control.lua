-- Selbsttest für UTL Coupling Yard (nur headless, wird nicht veröffentlicht). Baut auf einer eigenen
-- Oberfläche gerade Strecken (jede für sich, Haltestellen rechts in Fahrtrichtung) und prüft:
--   A  Wagenbahnhof „nur abstellen“: Lok fährt allein weiter, Wagen bleiben stehen
--   B  Wagenbahnhof „nur abholen“: Lok schiebt heran, kuppelt die wartenden Wagen, fährt mit ihnen weiter
--   C  Wagenbahnhof „tauschen“: eigene Wagen abstellen, wartende mitnehmen
--   D  Rangierdepot: Lok in beide Richtungen taugt, Lok in eine Richtung nicht
--   E  Umbauten sind bei UTL angemeldet (on_train_rebuilt mit changing = true)
--   F  Rangierlok: Zug stellt Wagen ab, Rangierlok bringt sie sofort zur Ladebucht
--   G  Rangierlok: an der Ladebucht warten die Wagen auf „leer“ (Test entlädt), dann zurück ins Lager
--   H  Staffel: UTL-Lieferung hält am Staffel-Bahnhof (Signal am Abnehmer), Wagen bleiben mit der
--      Lieferung stehen, Lok fährt ins Depot, ein zweiter Zug holt die Wagen und liefert sie aus
--   I  Übergabe auf einem Gleis (Marcels Blaupause): zwei Halte gegenüber in der Mitte. Zug A schiebt die
--      Wagen von Westen heran, kuppelt ab und fährt rückwärts zurück; Zug B kommt von Osten, kuppelt an und
--      zieht sie nach Osten
local MOD = "UTLCouplingYard"
local CY = "ucy-selftest"

local function say(text) log("[UCY] " .. text) end

local function check(name, ok, detail)
  storage.results[#storage.results + 1] = { name = name, ok = ok }
  say((ok and "OK    " or "FEHLER ") .. name .. (detail and ("  " .. detail) or ""))
end

local function rail(s, y)
  for x = -95, 95, 2 do s.create_entity({ name = "straight-rail", position = { x, y }, direction = 4, force = "player" }) end
end

local function stop(s, name, x, y, utl, west)
  local e = s.create_entity({ name = utl and "utl-train-stop" or "train-stop", position = { x, y + (west and -2 or 2) },
    direction = west and 12 or 4, force = "player", raise_built = true }) --[[@as LuaEntity]]
  e.backer_name = name
  return e
end

local function stock(s, name, x, y, dir)
  local e = s.create_entity({ name = name, position = { x, y }, direction = dir or 4, force = "player" }) --[[@as LuaEntity]]
  if name == "locomotive" then e.insert({ name = "coal", count = 150 }) end
  return e
end

local function run(loco, records)
  local schedule = loco.train.get_schedule()
  for _, r in ipairs(records) do
    schedule.add_record({ station = r, wait_conditions = { { type = "time", ticks = 36000 } } })
  end
  schedule.go_to_station(1)
  loco.train.manual_mode = false
end

local function yard(e, mode)
  remote.call("utl", "set_station_role", e.unit_number, MOD .. "/yard")
  remote.call("utl", "set_station_data", e.unit_number, MOD, "mode", mode)
end

local function build()
  local s = game.create_surface(CY)
  s.generate_with_lab_tiles = true
  s.request_to_generate_chunks({ 0, 0 }, 5)
  s.force_generate_chunk_requests()
  local t = {}
  -- A: nur abstellen
  rail(s, 1)
  yard(stop(s, "A-Hof", 0, 1, true), "drop")
  stop(s, "A-Ende", 80, 1)
  t.a_loco = stock(s, "locomotive", -40, 1)
  t.a_w1 = stock(s, "cargo-wagon", -47, 1)
  t.a_w2 = stock(s, "cargo-wagon", -54, 1)
  run(t.a_loco, { "A-Hof", "A-Ende" })
  -- B: nur abholen (wartende Wagen stehen vor der Haltestelle)
  rail(s, 21)
  yard(stop(s, "B-Hof", 0, 21, true), "pickup")
  stop(s, "B-Ende", 80, 21)
  t.b_loco = stock(s, "locomotive", -40, 21)
  t.b_x1 = stock(s, "cargo-wagon", 12, 21)
  t.b_x2 = stock(s, "cargo-wagon", 19, 21)
  run(t.b_loco, { "B-Hof", "B-Ende" })
  -- C: tauschen
  rail(s, 41)
  yard(stop(s, "C-Hof", 0, 41, true), "swap")
  stop(s, "C-Ende", 80, 41)
  t.c_loco = stock(s, "locomotive", -40, 41)
  t.c_w = stock(s, "cargo-wagon", -47, 41)
  t.c_x = stock(s, "cargo-wagon", 12, 41)
  run(t.c_loco, { "C-Hof", "C-Ende" })
  -- D: Rangierdepots, je ein Gleis
  for i, both in ipairs({ true, false }) do
    local y = 41 + 20 * i
    rail(s, y)
    local depot = stop(s, "D-Depot-" .. i, 0, y, true)
    remote.call("utl", "set_station_role", depot.unit_number, MOD .. "/depot")
    local l = stock(s, "locomotive", -40, y)
    if both then stock(s, "locomotive", -47, y, 12) end
    run(l, { "D-Depot-" .. i })
    t["d_loco" .. i] = l
  end
  -- F/G: Rangierlok. Depot westlich (Halt Richtung Westen), Zug stellt am F-Hof ab, Rangierlok bringt die
  -- Wagen zur F-Bucht (sofort), von dort wenn leer zurück ins F-Lager (Halt Richtung Westen).
  local y = 101
  rail(s, y)
  local depot = stop(s, "F-Depot", -85, y, true, true)
  remote.call("utl", "set_station_role", depot.unit_number, MOD .. "/depot")
  local hof, bucht = stop(s, "F-Hof", 0, y, true), stop(s, "F-Bucht", 40, y, true)
  local lager = stop(s, "F-Lager", -30, y, true, true)
  yard(hof, "drop")
  yard(bucht, "drop")
  yard(lager, "drop")
  remote.call("utl", "set_station_data", hof.unit_number, MOD, "shunt_to", "F-Bucht")
  remote.call("utl", "set_station_data", bucht.unit_number, MOD, "shunt_to", "F-Lager")
  remote.call("utl", "set_station_data", bucht.unit_number, MOD, "shunt_when", "empty")
  stop(s, "F-Ende", 90, y)
  local shunter = stock(s, "locomotive", -68, y, 12)
  stock(s, "locomotive", -75, y, 4)
  run(shunter, { "F-Depot" })
  t.f_shunter = shunter
  t.f_loco = stock(s, "locomotive", -40, y)
  t.f_w1 = stock(s, "cargo-wagon", -47, y)
  t.f_w2 = stock(s, "cargo-wagon", -54, y)
  t.f_w1.insert({ name = "iron-plate", count = 100 })
  t.f_w2.insert({ name = "iron-plate", count = 100 })
  run(t.f_loco, { "F-Hof", "F-Ende" })
  -- H: Staffel. Depot ganz im Westen (Halt Richtung Westen), Anbieter Richtung Osten, Staffel-Bahnhof
  -- (Richtung Westen) davor: Zug A lädt, fährt zurück zum Staffel-Bahnhof, stellt den Wagen ab und fährt
  -- weiter ins Depot. Zug B (wird erst dann eingesetzt) holt den Wagen und fährt zum Abnehmer im Osten.
  y = 141
  rail(s, y)
  local W = defines.wire_connector_id
  local function combinator(x, cy, target, signal, count)
    local c = s.create_entity({ name = "constant-combinator", position = { x, cy }, force = "player" }) --[[@as LuaEntity]]
    local behavior = c.get_or_create_control_behavior() --[[@as LuaConstantCombinatorControlBehavior]]
    behavior.get_section(1).set_slot(1, { value = signal, min = count })
    c.get_wire_connector(W.circuit_green, true).connect_to(target.get_wire_connector(W.circuit_green, true))
  end
  local function cfg(e, changes) changes.network = "H"; remote.call("utl", "configure_station", e.unit_number, changes) end
  local hdepot = stop(s, "H-Depot", -85, y, true, true)
  cfg(hdepot, { mode = "depot" })
  local prov = stop(s, "H-Anbieter", 30, y, true)
  cfg(prov, { mode = "station", provide = true, request = false })
  combinator(33.5, y + 5.5, prov, { type = "item", name = "iron-plate", quality = "normal", comparator = "=" }, 2000)
  local req = stop(s, "H-Abnehmer", 70, y, true)
  cfg(req, { mode = "station", provide = false, request = true, request_threshold = 100 })
  remote.call("utl", "set_request", req.unit_number, 1, { type = "item", name = "iron-plate" }, 400)
  combinator(73.5, y + 5.5, req, { type = "virtual", name = "ucy-relay", quality = "normal", comparator = "=" }, 1)
  t.h_req, t.h_prov = req.unit_number, prov.unit_number
  local relay = stop(s, "H-Hof", 0, y, true, true)
  yard(relay, "drop")
  remote.call("utl", "set_station_data", relay.unit_number, MOD, "relay", 1)
  yard(stop(s, "H-Abhol", 8, y, true), "pickup")
  -- I: Übergabe auf einem Gleis
  local iy = 161
  rail(s, iy)
  yard(stop(s, "I-Ost", 0, iy, true), "swap")
  yard(stop(s, "I-West", 0, iy, true, true), "swap")
  stop(s, "I-West-Ende", -90, iy, false, true)
  stop(s, "I-Ost-Ende", 90, iy)
  t.i_w1 = stock(s, "cargo-wagon", -40, iy)
  t.i_w2 = stock(s, "cargo-wagon", -47, iy)
  t.i_a = stock(s, "locomotive", -54, iy, 4)
  stock(s, "locomotive", -61, iy, 12)
  run(t.i_a, { "I-Ost", "I-West-Ende" })
  t.h_w = stock(s, "cargo-wagon", -46, y)
  stock(s, "locomotive", -53, y, 4)
  t.h_a = stock(s, "locomotive", -60, y, 12)
  run(t.h_a, { "H-Depot" })
  return t
end

local function listen()
  local ids = remote.call("utl", "get_event_ids") --[[@as table]]
  script.on_event(ids.on_delivery_created, function(event) ---@param event table
    if event.requester == storage.t.h_req then storage.h_delivery = event.id end
  end)
  script.on_event(ids.on_delivery_state_changed, function(event) ---@param event table
    local train = event.train
    if event.id ~= storage.h_delivery or not (train and train.valid) then return end
    if event.state == "loading" then
      for key, amount in pairs(event.manifest) do
        local name = key:match("^item|([^|]+)|")
        if name then train.insert({ name = name, count = amount }) end
      end
    elseif event.state == "unloading" then
      train.clear_items_inside()
      remote.call("utl", "configure_station", storage.t.h_req, { request = false })
    end
  end)
  script.on_event(ids.on_delivery_completed, function(event) ---@param event table
    if event.id == storage.h_delivery then storage.h_done = event.train_id end
  end)
  script.on_event(ids.on_delivery_canceled, function(event) ---@param event table
    if event.id == storage.h_delivery then storage.h_canceled = event.reason end
  end)
  script.on_event(ids.on_train_rebuilt, function(event) ---@param event table
    storage.rebuilt = storage.rebuilt or { yes = 0, no = 0 }
    if event.changing then storage.rebuilt.yes = storage.rebuilt.yes + 1 else storage.rebuilt.no = storage.rebuilt.no + 1 end
  end)
end

script.on_init(function()
  storage.results = {}
  remote.call("utl", "set_map_config", "utl-debug-log", true)
  storage.t = build()
  listen()
  say("Aufbau fertig")
end)
script.on_load(listen)

local function at(loco, name)
  local train = loco.valid and loco.train
  return train and train.state == defines.train_state.wait_station and train.station
    and train.station.backer_name == name and train or nil
end

local function waiting_wagons(e) return e.valid and e.train and #e.train.carriages or 0 end

script.on_nth_tick(60, function()
  local t = storage.t
  if not t or storage.done then return end
  local s = storage.seen or {}
  storage.seen = s
  local train = at(t.a_loco, "A-Ende")
  if train and not s.a then
    s.a = true
    check("A nur abstellen: Lok allein am Ende, Wagen bleiben zusammen stehen",
      #train.carriages == 1 and t.a_w1.train == t.a_w2.train and waiting_wagons(t.a_w1) == 2
        and t.a_w1.train.manual_mode, "Lok-Zug " .. #train.carriages .. " Wagen")
  end
  train = at(t.b_loco, "B-Ende")
  if train and not s.b then
    s.b = true
    check("B nur abholen: Lok kam mit beiden wartenden Wagen am Ende an",
      #train.carriages == 3 and t.b_x1.train == train and t.b_x2.train == train, #train.carriages .. " Wagen")
  end
  train = at(t.c_loco, "C-Ende")
  if train and not s.c then
    s.c = true
    check("C tauschen: eigener Wagen abgestellt, wartender mitgenommen",
      #train.carriages == 2 and t.c_x.train == train and t.c_w.train ~= train and waiting_wagons(t.c_w) == 1,
      #train.carriages .. " Wagen")
  end
  if not s.d and game.tick > 60 * 60 then
    s.d = true
    local shunters = remote.call(MOD, "get_shunters") --[[@as table]]
    local one, two = t.d_loco1.train, t.d_loco2.train
    check("D Rangierdepot: Lok in beide Richtungen taugt, Lok in eine Richtung nicht",
      shunters[one.id] ~= nil and shunters[two.id] == nil, serpent.line(shunters))
  end
  -- F: Wagen stehen ohne Lok an der F-Bucht (östlich), Rangierlok wieder im Depot → entladen für G
  local w1, w2 = t.f_w1, t.f_w2
  local parked = w1.valid and w2.valid and w1.train == w2.train and #w1.train.carriages == 2
  if parked and not s.f and w1.position.x > 20 and at(t.f_shunter, "F-Depot") then
    s.f = true
    check("F Rangierlok: Wagen zur Ladebucht gebracht, Lok zurück im Depot", true, "x " .. math.floor(w1.position.x))
    w1.get_inventory(defines.inventory.cargo_wagon).clear()
    w2.get_inventory(defines.inventory.cargo_wagon).clear()
  end
  if parked and s.f and not s.g and w1.position.x < 0 and at(t.f_shunter, "F-Depot") then
    s.g = true
    check("G Rangierlok: leere Wagen zurück ins Lager, Lok zurück im Depot", true, "x " .. math.floor(w1.position.x))
  end
  -- H: Wagen steht ohne Lok am Staffel-Bahnhof und trägt die Lieferung → zweiten Zug losschicken
  local hw = t.h_w
  if not s.h_parked and hw.valid and hw.train and #hw.train.carriages == 1 and hw.position.x > 0 and hw.position.x < 28 then
    s.h_parked = true
    local info = remote.call("utl", "get_delivery", storage.h_delivery or 0) --[[@as table?]]
    check("H Staffel: Wagen abgestellt, Lieferung hängt am Wagen", info ~= nil and info.train_id == hw.train.id,
      serpent.line({ lieferung = info and info.train_id, wagen = hw.train.id }))
  end
  local loco = t.h_a.valid and t.h_a.train
  local home = loco and remote.call("utl", "get_train", loco.id) --[[@as table?]]
  if s.h_parked and not t.h_b and home and home.idle then
    check("H Staffel: Lok des ersten Zuges frei im Depot", loco and #loco.carriages == 2)
    t.h_b = stock(game.surfaces[CY], "locomotive", -30, 141)
    run(t.h_b, { "H-Abhol" })
  end
  if storage.h_done and not s.h then
    s.h = true
    check("H Staffel: zweiter Zug hat mit dem Wagen ausgeliefert", t.h_b ~= nil and hw.valid and hw.train == t.h_b.train,
      serpent.line({ abbruch = storage.h_canceled }))
  end
  -- I: Wagen ohne Lok in der Mitte, Loks von A zurück → Zug B einsetzen
  local iw = t.i_w1
  if not s.i_dropped and iw.valid and iw.train and #iw.train.carriages == 2 and at(t.i_a, "I-West-Ende") then
    s.i_dropped = true
    check("I Übergabe: A hat geschoben abgestellt und ist rückwärts zurück", #t.i_a.train.carriages == 2
      and iw.position.x < 0 and iw.position.x > -20, "Wagen x " .. math.floor(iw.position.x))
    t.i_b = stock(game.surfaces[CY], "locomotive", 50, 161, 12)
    stock(game.surfaces[CY], "locomotive", 57, 161, 4)
    run(t.i_b, { "I-West", "I-Ost-Ende" })
  end
  if t.i_b and not s.i and at(t.i_b, "I-Ost-Ende") then
    s.i = true
    check("I Übergabe: B hat die Wagen angekuppelt und nach Osten gezogen",
      iw.valid and iw.train == t.i_b.train and #t.i_b.train.carriages == 4)
  end
  if (s.a and s.b and s.c and s.d and s.f and s.g and s.h and s.i) or game.tick > 60 * 300 then
    storage.done = true
    local r = storage.rebuilt or { yes = 0, no = 0 }
    check("E Umbauten bei UTL angemeldet", r.no == 0, "angemeldet " .. r.yes .. ", unangemeldet " .. r.no)
    if storage.h_canceled then check("H Lieferung abgebrochen: " .. tostring(storage.h_canceled), false) end
    for _, k in ipairs({ "a", "b", "c", "d", "f", "g", "h", "i" }) do
      if not s[k] then check(string.upper(k) .. " nicht angekommen", false) end
    end
    local bad = 0
    for _, r2 in ipairs(storage.results) do if not r2.ok then bad = bad + 1 end end
    say(bad == 0 and "ALLE TESTS OK" or (bad .. " TEST(S) FEHLGESCHLAGEN"))
  end
end)
