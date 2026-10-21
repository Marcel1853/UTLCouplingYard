--- Rangierlok: bringt einen Wagenverband von seinem Wagenbahnhof zum Rangierziel.
--- Ablauf (alles über die UTL-Schnittstelle):
---   fetch   – Auftrag (send_job) zu einem Punkt kurz vor dem Ende des Verbands
---   couple  – Auftrag fertig: festhalten, im Schritttempo heranschieben, ankuppeln (scripts/coupling/crawl.lua)
---   deliver – Auftrag zum Ziel (falls nötig über eine Wende)
---   drop    – am Ziel: Auftrag beenden, abkuppeln, Verband dort anmelden, Lok fährt mit ihrem Fahrplan ins Depot
local Const = require("scripts.core.const")
local Registry = require("scripts.stations.registry")
local Couple = require("scripts.coupling.couple")
local Crawl = require("scripts.coupling.crawl")
local Groups = require("scripts.shunting.groups")

local Shunter = {}

local WAIT = { { type = "time", ticks = 30 } }

local function warn(stop, key)
  if not (stop and stop.valid) then return end
  local p = stop.position
  stop.force.print({ "utl-coupling-yard." .. key, stop.backer_name,
    string.format("[gps=%d,%d,%s]", math.floor(p.x), math.floor(p.y), stop.surface.name) })
end

local function unit_vector(dx, dy)
  local len = math.sqrt(dx * dx + dy * dy)
  if len < 0.001 then return 0, 0 end
  return dx / len, dy / len
end

local function job(train, stops)
  local id, why = remote.call("utl", "send_job", train.id, Const.MOD, stops)
  return id, why
end

--- Verband ist bereit (Groups.on_ready): Auftrag anlegen und eine freie Rangierlok suchen.
function Shunter.request(group, to_name)
  local from = Registry.stop(group.unit)
  if not from then return end
  local to = Registry.find_yard(to_name, from)
  if not to then
    warn(from, "warn-no-target")
    return
  end
  storage.tasks[#storage.tasks + 1] = { group = group, to = to }
  Shunter.assign()
end

--- Zum Ende des Verbands schicken: Punkt Const.APPROACH Kacheln davor. Das nähere Ende zuerst (sonst
--- führe der Weg womöglich durch die Wagen), geht es nicht, das andere.
local function fetch(task, train)
  local wagons = task.group.wagons[1].train
  local a, b = wagons.front_stock, wagons.back_stock
  if not (a and b) then return false end
  local q = train.front_stock.position
  local function d(e) return (e.position.x - q.x) ^ 2 + (e.position.y - q.y) ^ 2 end
  local order = d(a) <= d(b) and { { a, b }, { b, a } } or { { b, a }, { a, b } }
  for _, pair in ipairs(order) do
    local e, other = pair[1], pair[2]
    local ux, uy = unit_vector(e.position.x - other.position.x, e.position.y - other.position.y)
    if ux == 0 and uy == 0 then -- nur ein Wagen: in Richtung des Wagens bzw. entgegen
      local o = e.orientation * 2 * math.pi
      ux, uy = math.sin(o), -math.cos(o)
      if e == b then ux, uy = -ux, -uy end
    end
    local reach = Const.APPROACH + 4
    local id = job(train, { { position = { x = e.position.x + ux * reach, y = e.position.y + uy * reach },
      surface = e.surface.index, wait = WAIT } })
    if id then
      task.job, task.target, task.phase = id, e, "fetch"
      storage.jobs[id] = task
      return true
    end
  end
  return false
end

--- Freie Rangierloks auf offene Aufträge verteilen (nächste zuerst).
function Shunter.assign()
  local tasks, free = storage.tasks, storage.free
  local i = 1
  while i <= #tasks do
    local task = tasks[i]
    if not Groups.valid(task.group) then
      table.remove(tasks, i)
    else
      local p = task.group.wagons[1].position
      local list = {}
      for id in pairs(free) do
        local train = game.train_manager.get_train_by_id(id)
        if train and train.valid and train.front_stock then
          local q = train.front_stock.position
          list[#list + 1] = { train = train, d = (q.x - p.x) ^ 2 + (q.y - p.y) ^ 2 }
        else
          free[id] = nil
        end
      end
      table.sort(list, function(x, y) return x.d < y.d end)
      local started = false
      for _, entry in ipairs(list) do
        local train = entry.train
        if train.front_stock.surface == task.group.wagons[1].surface and fetch(task, train) then
          free[train.id] = nil
          task.locos = {}
          for _, c in pairs(train.carriages) do task.locos[c.unit_number] = true end
          task.loco = train.front_stock
          started = true
          break
        end
      end
      if started then table.remove(tasks, i) else i = i + 1 end
      if next(free) == nil then return end
    end
  end
end

--- Auftrag zum Ziel, falls nötig über eine Wende.
local function deliver(task, train)
  local target = { station = task.to, wait = WAIT }
  local id = job(train, { target })
  if not id then
    for unit, role in pairs(storage.stations) do
      if role == Const.ROLE.turn and Registry.stop(unit) then
        id = job(train, { { station = unit, wait = WAIT }, target })
        if id then break end
      end
    end
  end
  if not id then return false end
  task.job, task.phase = id, "deliver"
  storage.jobs[id] = task
  return true
end

--- Rangierlok freigeben: automatisch, bei UTL loslassen – sie fährt mit ihrem Fahrplan ins Depot.
local function home(train)
  train.manual_mode = false
  remote.call("utl", "release_train", train.id)
end

--- Heranschieben fertig (aus dem Rangier-Takt).
function Shunter.coupled(task, train, ok)
  if not ok then
    warn(Registry.stop(task.group.unit), "warn-shunt-failed")
    home(train)
    return
  end
  if not deliver(task, train) then
    warn(Registry.stop(task.to), "warn-unreachable")
    home(train)
  end
end

--- Ereignis on_job_finished.
function Shunter.job_finished(event)
  local task = storage.jobs[event.job_id]
  if not task then return end
  storage.jobs[event.job_id] = nil
  if task.phase ~= "fetch" then return end -- deliver endet mit cancel_job beim Abkuppeln
  local train = event.train
  if not (train and train.valid) then return end
  if event.canceled or not (task.target.valid and Groups.valid(task.group)) then
    return -- Lok fährt mit ihrem Fahrplan zurück ins Depot
  end
  remote.call("utl", "hold_train", train.id, Const.MOD)
  train.manual_mode = true
  task.phase = "couple"
  local front, back = train.front_stock, train.back_stock
  if not (front and back) then return end
  local t = task.target.position
  local function d(e) return (e.position.x - t.x) ^ 2 + (e.position.y - t.y) ^ 2 end
  local head = d(front) <= d(back) and front or back
  local fx, fy = unit_vector(t.x - head.position.x, t.y - head.position.y)
  Crawl.start(head, task.target, fx, fy, task)
end

--- Lok-Block der Rangierlok von den Wagen trennen. Liefert (Rangierlok, Wagen) oder nil.
local function split(task, train)
  local carriages = train.carriages
  for i = 1, #carriages - 1 do
    local a, b = carriages[i], carriages[i + 1]
    local la, lb = task.locos[a.unit_number], task.locos[b.unit_number]
    if la and not lb then return Couple.split(a, b) end
    if lb and not la then return Couple.split(b, a) end
  end
  return nil
end

--- Ereignis on_train_arrived. Liefert true, wenn es eine eigene Rangierfahrt war.
function Shunter.arrived(event)
  local task = event.job_id and storage.jobs[event.job_id]
  if not task then return false end
  if task.phase ~= "deliver" or event.station ~= task.to then return true end
  local train = event.train
  task.phase = "drop"
  storage.jobs[event.job_id] = nil
  remote.call("utl", "hold_train", train.id, Const.MOD)
  remote.call("utl", "cancel_job", event.job_id)
  train.manual_mode = true
  local loco, wagons = split(task, train)
  if wagons then Groups.add(task.to, wagons) end
  home(loco or train)
  return true
end

return Shunter
