-- Selbsttest für UTL Coupling Yard (nur headless, wird nicht veröffentlicht). Baut auf einer eigenen
-- Oberfläche gerade Strecken (jede für sich, Haltestellen rechts in Fahrtrichtung) und prüft:
--   A  Wagenbahnhof „nur abstellen“: Lok fährt allein weiter, Wagen bleiben stehen
--   B  Wagenbahnhof „nur abholen“: Lok schiebt heran, kuppelt die wartenden Wagen, fährt mit ihnen weiter
--   C  Wagenbahnhof „tauschen“: eigene Wagen abstellen, wartende mitnehmen
--   D  Rangierdepot: Lok in beide Richtungen taugt, Lok in eine Richtung nicht
--   E  Umbauten sind bei UTL angemeldet (on_train_rebuilt mit changing = true)
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

local function stop(s, name, x, y, utl)
  local e = s.create_entity({ name = utl and "utl-train-stop" or "train-stop", position = { x, y + 2 }, direction = 4,
    force = "player", raise_built = true }) --[[@as LuaEntity]]
  e.backer_name = name
  return e
end

local function stock(s, name, x, y, dir)
  local e = s.create_entity({ name = name, position = { x, y }, direction = dir or 4, force = "player" }) --[[@as LuaEntity]]
  if name == "locomotive" then e.insert({ name = "coal", count = 50 }) end
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
  return t
end

local function listen()
  local ids = remote.call("utl", "get_event_ids") --[[@as table]]
  script.on_event(ids.on_train_rebuilt, function(event)
    storage.rebuilt = storage.rebuilt or { yes = 0, no = 0 }
    if event.changing then storage.rebuilt.yes = storage.rebuilt.yes + 1 else storage.rebuilt.no = storage.rebuilt.no + 1 end
  end)
end

script.on_init(function()
  storage.results = {}
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
  if (s.a and s.b and s.c and s.d) or game.tick > 60 * 150 then
    storage.done = true
    local r = storage.rebuilt or { yes = 0, no = 0 }
    check("E Umbauten bei UTL angemeldet", r.no == 0, "angemeldet " .. r.yes .. ", unangemeldet " .. r.no)
    for _, k in ipairs({ "a", "b", "c", "d" }) do
      if not s[k] then check(string.upper(k) .. " nicht angekommen", false) end
    end
    local bad = 0
    for _, r2 in ipairs(storage.results) do if not r2.ok then bad = bad + 1 end end
    say(bad == 0 and "ALLE TESTS OK" or (bad .. " TEST(S) FEHLGESCHLAGEN"))
  end
end)
