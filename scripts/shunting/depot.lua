--- Rangierdepot: Rangierloks müssen in beide Richtungen fahren können (mindestens eine Lok je
--- Richtung). Geprüft wird, wenn UTL meldet, dass ein Zug frei im Depot steht (on_train_idle).
local Const = require("scripts.core.const")

local Depot = {}

--- Fährt der Zug in beide Richtungen?
function Depot.both_ways(train)
  local locos = train.locomotives
  return #locos.front_movers > 0 and #locos.back_movers > 0
end

--- Ereignis on_train_idle. Liefert true, wenn der Zug als Rangierlok taugt.
function Depot.idle(event)
  if event.role ~= Const.ROLE.depot then return false end
  local train = event.train
  if not (train and train.valid) then return false end
  if Depot.both_ways(train) then
    storage.shunters[train.id] = event.station
    return true
  end
  storage.shunters[train.id] = nil
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
