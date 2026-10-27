--- Rangierdepot: Rangierloks müssen in beide Richtungen fahren können (mindestens eine Lok je
--- Richtung). Geprüft wird, wenn UTL meldet, dass ein Zug frei im Depot steht (on_train_idle).
local Const = require("scripts.core.const")
local Shunter = require("scripts.shunting.shunter")

local Depot = {}

--- Fährt der Zug in beide Richtungen?
function Depot.both_ways(train)
  local locos = train.locomotives
  return #locos.front_movers > 0 and #locos.back_movers > 0
end

--- Ohne eigenen Halt im Fahrplan fände die Rangierlok nach einem Auftrag nicht zurück: Depot eintragen.
function Depot.home_record(train, stop)
  if not (stop and stop.valid) then return end
  local schedule = train.get_schedule()
  if not schedule then return end
  for _, record in pairs(schedule.get_records() or {}) do
    if not record.temporary then return end
  end
  schedule.add_record({ station = stop.backer_name, wait_conditions = { { type = "inactivity", ticks = 300 } } })
end

--- Ereignis on_train_idle. Liefert true, wenn der Zug als Rangierlok taugt.
function Depot.idle(event)
  if event.role ~= Const.ROLE.depot then return false end
  local train = event.train
  if not (train and train.valid) then return false end
  -- Zug-IDs ändern sich bei jedem Kuppeln: alte Einträge wegräumen (selten, nur bei Depot-Besuchen)
  for _, list in pairs({ storage.shunters, storage.warned, storage.free }) do
    for id in pairs(list) do
      if not game.train_manager.get_train_by_id(id) then list[id] = nil end
    end
  end
  if Depot.both_ways(train) then
    storage.shunters[train.id] = event.station
    storage.free[train.id] = event.station
    Depot.home_record(train, event.stop)
    Shunter.assign()
    return true
  end
  storage.shunters[train.id] = nil
  storage.free[train.id] = nil
  if not storage.warned[train.id] then
    storage.warned[train.id] = true
    local stop, loco = event.stop, train.front_stock
    if stop and stop.valid and loco then
      local p = loco.position
      stop.force.print({ "utl-coupling-yard.warn-one-way", stop.backer_name,
        string.format("[gps=%d,%d,%s]", math.floor(p.x), math.floor(p.y), loco.surface.name) })
    end
  end
  return false
end

return Depot
