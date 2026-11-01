--- Kleine Helfer der Rangierlok (scripts/shunting/shunter.lua und onto.lua): Warnung, Aufträge bei UTL, Wenden,
--- Lok vom Rest trennen, Heimfahrt.
local Const = require("scripts.core.const")
local Registry = require("scripts.stations.registry")
local Couple = require("scripts.coupling.couple")

local H = {}

H.WAIT = { { type = "time", ticks = 30 } }

local RAILS = { "straight-rail", "curved-rail-a", "curved-rail-b", "half-diagonal-rail" }

function H.warn(stop, key)
  if not (stop and stop.valid) then return end
  local p = stop.position
  stop.force.print({ "utl-coupling-yard." .. key, stop.backer_name,
    string.format("[gps=%d,%d,%s]", math.floor(p.x), math.floor(p.y), stop.surface.name) })
end

function H.unit_vector(dx, dy)
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 0.001 then return 0, 0 end
  return dx / len, dy / len
end

function H.job(train, stops)
  local id, why = remote.call("utl", "send_job", train.id, Const.MOD, stops)
  return id, why
end

function H.rail_at(surface, position)
  return surface.find_entities_filtered({ position = position, radius = 1.5, type = RAILS })[1]
end

--- Wende-Halte, nächste zuerst (bei mehreren Rangierbahnhöfen auf der Karte die eigene).
function H.turns(train)
  local q = train.front_stock.position
  local list = {}
  for unit, role in pairs(storage.stations) do
    local stop = role == Const.ROLE.turn and Registry.stop(unit)
    if stop and stop.surface == train.front_stock.surface then
      list[#list + 1] = { unit = unit, d = (stop.position.x - q.x) ^ 2 + (stop.position.y - q.y) ^ 2 }
    end
  end
  table.sort(list, function(a, b) return a.d < b.d end)
  return list
end

--- Kommt die Rangierlok mit den Wagen voran am Gleis `rail` an? Eine Pfadsuche, nur beim Losschicken.
--- nil, wenn es keinen Weg gibt.
function H.wagons_lead(task, train, rail)
  if not rail then return nil end
  local goals = {}
  for _, direction in pairs(defines.rail_direction) do goals[#goals + 1] = { rail = rail, direction = direction } end
  local result = game.train_manager.request_train_path({ train = train, goals = goals })
  if not result.found_path then return nil end
  local leading = result.is_front and train.front_stock or train.back_stock
  return leading ~= nil and not task.locos[leading.unit_number]
end

--- Rangierlok freigeben: automatisch, bei UTL loslassen – sie fährt mit ihrem Fahrplan ins Depot.
function H.home(train)
  train.manual_mode = false
  remote.call("utl", "release_train", train.id)
end

--- Lok-Block der Rangierlok vom Rest trennen. Liefert (Rangierlok, Rest) oder nil. `to_other`: Lieferung und
--- Festhalten bleiben beim Rest (an einen wartenden Zug angestellt).
function H.split(task, train, to_other)
  local carriages = train.carriages
  for i = 1, #carriages - 1 do
    local a, b = carriages[i], carriages[i + 1]
    local la, lb = task.locos[a.unit_number], task.locos[b.unit_number]
    if la and not lb then return Couple.split(a, b, to_other) end
    if lb and not la then return Couple.split(b, a, to_other) end
  end
  return nil
end

return H
