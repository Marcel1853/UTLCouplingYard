--- Wagenbahnhof: Ein Zug hält, lässt alle Wagen hinter seinen Loks stehen (abstellen) und kuppelt die
--- Wagen, die vor ihm warten (abholen). Danach fährt er mit seinem Fahrplan weiter.
--- Ablauf: Ankunft (UTL-Ereignis) → festhalten und in die Warteschlange → im Rangier-Takt abarbeiten.
local Const = require("scripts.core.const")
local Registry = require("scripts.stations.registry")
local Couple = require("scripts.coupling.couple")
local Crawl = require("scripts.coupling.crawl")
local Geometry = require("scripts.coupling.geometry")
local Groups = require("scripts.shunting.groups")
local Relay = require("scripts.yard.relay")

local Yard = {}

local function warn(stop, key)
  if not (stop and stop.valid) then return end
  local p = stop.position
  stop.force.print({ "utl-coupling-yard." .. key, stop.backer_name,
    string.format("[gps=%d,%d,%s]", math.floor(p.x), math.floor(p.y), stop.surface.name) })
end

--- Ereignis on_train_arrived. Liefert true, wenn der Zug in die Warteschlange kam.
function Yard.arrived(event)
  if Registry.role(event.station) ~= Const.ROLE.yard then return false end
  local train, stop = event.train, event.stop
  if not (train and train.valid and stop and stop.valid) then return false end
  if event.held_by and event.held_by ~= Const.MOD then return false end -- gehört einem anderen Mod
  if event.job_id then return false end -- Aufträge (auch eigene Rangierfahrten) nicht anfassen
  if not remote.call("utl", "hold_train", train.id, Const.MOD) then return false end
  train.manual_mode = true
  storage.queue[#storage.queue + 1] = { ref = train.front_stock, stop = stop, unit = event.station }
  return true
end

--- Zug weiterschicken: nächster Halt im Fahrplan, automatisch, bei UTL freigeben. Lok nach einer
--- Übergabe → Heimatdepot; hat der Zug gerade eine Lieferung übernommen, hat UTL die Halte schon gesetzt.
function Yard.release(train, info)
  if not (train and train.valid) then return end
  for _, c in pairs(train.carriages) do
    local depot = storage.homeward[c.unit_number]
    if depot then
      storage.homeward[c.unit_number] = nil
      Relay.send_home(train, depot)
      remote.call("utl", "release_train", train.id)
      return
    end
  end
  if info and not info.had_delivery and Relay.has_delivery(train) then
    train.manual_mode = false
    remote.call("utl", "release_train", train.id)
    return
  end
  local schedule = train.get_schedule()
  local count = schedule and schedule.get_record_count() or 0
  if count > 0 then
    local current = schedule.current
    local record = schedule.get_record({ schedule_index = current })
    if record and record.temporary then
      schedule.remove_record({ schedule_index = current })
      count = schedule.get_record_count() or 0
      if current > count then current = 1 end
    else
      current = current % count + 1
    end
    if count > 0 then schedule.go_to_station(current) end
  end
  train.manual_mode = false
  remote.call("utl", "release_train", train.id)
end

--- Alle Wagen hinter dem Lok-Block am Kopf abkuppeln (`to_wagons`: UTL-Lieferung bleibt bei den Wagen).
--- Liefert den Zug, der weiterfährt, und die abgestellten Wagen (Zug) oder nil.
local function drop(train, head, stop, fx, fy, to_wagons)
  local carriages = train.carriages
  local first, step = 1, 1
  if carriages[1] ~= head then first, step = #carriages, -1 end
  local last_loco
  local can_leave = false
  for i = first, #carriages - first + 1, step do
    local c = carriages[i]
    if c.type ~= "locomotive" then break end
    last_loco = i
    if Geometry.faces(c, fx, fy) then can_leave = true end
  end
  if not last_loco then
    warn(stop, "warn-no-loco-ahead")
    return train
  end
  local next_i = last_loco + step
  if next_i < 1 or next_i > #carriages then return train end -- nur Loks: nichts abzustellen
  if not can_leave then
    warn(stop, "warn-cannot-leave")
    return train
  end
  local kept, rest = Couple.split(carriages[last_loco], carriages[next_i], to_wagons)
  return kept or train, rest
end

--- Nächster Wagen vor dem Kopf des Zuges (höchstens Const.SEARCH Kacheln). Einmalige kleine Suche je
--- Halt, kein Abscannen.
local function find_ahead(train, head, fx, fy)
  local p = head.position
  local far = { x = p.x + fx * Const.SEARCH, y = p.y + fy * Const.SEARCH }
  local area = { { math.min(p.x, far.x) - 1.5, math.min(p.y, far.y) - 1.5 },
    { math.max(p.x, far.x) + 1.5, math.max(p.y, far.y) + 1.5 } }
  local best, best_d
  for _, e in pairs(head.surface.find_entities_filtered({ area = area, type = Const.ROLLING_STOCK })) do
    if e.train ~= train then
      local d = Geometry.along(p, e.position, fx, fy)
      if d > 0 and (not best_d or d < best_d) then best, best_d = e, d end
    end
  end
  return best
end

--- Einen Eintrag der Warteschlange abarbeiten.
function Yard.process(entry)
  local train = entry.ref.valid and entry.ref.train
  if not train then return end
  local stop = entry.stop
  if not (stop.valid and Registry.role(entry.unit) == Const.ROLE.yard) then
    Yard.release(train)
    return
  end
  local mode = Registry.mode(entry.unit)
  local fx, fy = Geometry.forward(stop)
  local head = Geometry.ends(train, stop)
  if mode ~= "pickup" then
    local home = Relay.handover(train, entry.unit)
    local rest
    train, rest = drop(train, head, stop, fx, fy, home ~= nil)
    head = Geometry.ends(train, stop)
    if rest then
      Groups.add(entry.unit, rest, home ~= nil)
      if home then storage.homeward[train.carriages[1].unit_number] = home end
    end
  end
  if mode ~= "drop" then
    local target = find_ahead(train, head, fx, fy)
    if target then
      Crawl.start(head, target, fx, fy, nil, { had_delivery = Relay.has_delivery(train) })
      return
    end
  end
  Yard.release(train)
end

return Yard
