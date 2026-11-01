--- Rangierlok: bringt einen Wagenverband von seinem Wagenbahnhof zum Rangierziel.
--- Ablauf (alles über die UTL-Schnittstelle):
---   fetch   – Auftrag (send_job) zu einem Punkt kurz vor dem Ende des Verbands
---   couple  – Auftrag fertig: festhalten, im Schritttempo heranschieben, ankuppeln (scripts/coupling/crawl.lua)
---   deliver – Auftrag zum Ziel (falls nötig über eine Wende)
---   drop    – am Ziel: Auftrag beenden, abkuppeln, Verband dort anmelden, Lok fährt mit ihrem Fahrplan ins Depot
--- „Wagen je Rangierfahrt“: nach dem Ankuppeln nur die ersten N Wagen mitnehmen, der Rest bleibt stehen.
--- Anstellen an einen wartenden Zug und Anhängen an stehende Wagen: scripts/shunting/onto.lua.
local Const = require("scripts.core.const")
local Registry = require("scripts.stations.registry")
local Couple = require("scripts.coupling.couple")
local Crawl = require("scripts.coupling.crawl")
local Groups = require("scripts.shunting.groups")
local Gate = require("scripts.yard.gate")
local H = require("scripts.shunting.helpers")
local Onto = require("scripts.shunting.onto")

local Shunter = {}

local WAIT, warn, unit_vector, job, rail_at = H.WAIT, H.warn, H.unit_vector, H.job, H.rail_at

--- Verband ist bereit (Groups.on_ready): Auftrag anlegen und eine freie Rangierlok suchen. Das Ziel
--- (ein freies Gleis mit dem Namen) wird erst gewählt, wenn eine Lok losfährt.
function Shunter.request(group, to_name)
  local from = Registry.stop(group.unit)
  if not from then return end
  local _, exists = Registry.find_yard(to_name, from, function() return true end)
  if not exists then
    warn(from, "warn-no-target")
    return
  end
  group.busy = true
  storage.tasks[#storage.tasks + 1] = { group = group, to_name = to_name }
  Shunter.assign()
end

--- Frei: keine Rangierlok unterwegs dorthin und keine Wagen da (außer bei „an vorhandene Wagen anhängen“).
local function free_target(unit)
  return not storage.reserved[unit] and (Registry.append(unit) or not Groups.occupied(unit))
end

--- Zum Ende des Verbands schicken: Punkt Const.APPROACH Kacheln davor. Welches Ende, entscheidet die Wegsuche des
--- Spiels (ein belegter Block kostet Aufschlag – so wird nicht durch die Wagen hindurch angefahren); sonst das nähere
--- Ende zuerst; geht es nicht, das andere. Eine Wegsuche je Auftrag.
local function fetch(task, train)
  local wagons = task.group.wagons[1].train
  local a, b = wagons.front_stock, wagons.back_stock
  if not (a and b) then return false end
  local q = train.front_stock.position
  local reach = Const.APPROACH + 4
  local options = {}
  for _, pair in ipairs({ { a, b }, { b, a } }) do
    local e, other = pair[1], pair[2]
    local ux, uy = unit_vector(e.position.x - other.position.x, e.position.y - other.position.y)
    if ux == 0 and uy == 0 then -- nur ein Wagen: in Richtung des Wagens bzw. entgegen
      local o = e.orientation * 2 * math.pi
      ux, uy = math.sin(o), -math.cos(o)
      if e == b then ux, uy = -ux, -uy end
    end
    local at = { x = e.position.x + ux * reach, y = e.position.y + uy * reach }
    options[#options + 1] = { e = e, at = at, d = (e.position.x - q.x) ^ 2 + (e.position.y - q.y) ^ 2 }
  end
  table.sort(options, function(x, y) return x.d < y.d end)
  local goals, owner = {}, {}
  for i, option in ipairs(options) do
    local rail = rail_at(option.e.surface, option.at)
    if rail then
      for _, direction in pairs(defines.rail_direction) do
        goals[#goals + 1] = { rail = rail, direction = direction }
        owner[#goals] = i
      end
    end
  end
  if #goals > 0 then
    local result = game.train_manager.request_train_path({ train = train, goals = goals, type = "path" })
    if result.found_path and owner[result.goal_index] == 2 then options[1], options[2] = options[2], options[1] end
  end
  for _, option in ipairs(options) do
    local e = option.e
    local id = job(train, { { position = option.at, surface = e.surface.index, wait = WAIT } })
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
      local from = Registry.stop(task.group.unit)
      task.to = task.fixed or (from and Registry.find_yard(task.to_name, from, free_target))
      local p = task.group.wagons[1].position
      local list = {}
      for id in pairs(free) do
        local train = game.train_manager.get_train_by_id(id)
        if train and train.valid and train.front_stock then
          local q = train.front_stock.position
          local d = (q.x - p.x) ^ 2 + (q.y - p.y) ^ 2
          if d <= Const.SHUNT_RANGE ^ 2 then list[#list + 1] = { train = train, d = d } end
        else
          free[id] = nil
        end
      end
      table.sort(list, function(x, y) return x.d < y.d end)
      local started = false
      for _, entry in ipairs(task.to and list or {}) do
        local train = entry.train
        if train.front_stock.surface == task.group.wagons[1].surface and fetch(task, train) then
          free[train.id] = nil
          task.locos = {}
          for _, c in pairs(train.carriages) do task.locos[c.unit_number] = true end
          task.loco = train.front_stock
          storage.reserved[task.to] = true
          started = true
          break
        end
      end
      if started then table.remove(tasks, i) else i = i + 1 end
      if next(free) == nil then return end
    end
  end
end

--- Kommt der Zug am Ziel mit den Wagen voran an (geschoben)? Dann kann die Lok danach rückwärts wieder
--- heraus – wichtig bei Stumpfgleisen. Eine Pfadsuche, nur beim Losschicken.
local function pushing(task, train, stop)
  local result = game.train_manager.request_train_path({ train = train, goals = { { train_stop = stop } } })
  if not result.found_path then return nil end
  local leading = result.is_front and train.front_stock or train.back_stock
  return leading ~= nil and not task.locos[leading.unit_number]
end

--- Auftrag zum Ziel: direkt, wenn die Wagen dabei vorn sind; sonst über die nächste Wende (dort wechselt die
--- Richtung); geht beides nicht, direkt.
local function deliver(task, train)
  local onto = Onto.deliver(task, train)
  if onto ~= nil then return onto end
  local target = { station = task.to, wait = WAIT }
  local stop = Registry.stop(task.to)
  local id
  if stop and pushing(task, train, stop) then id = job(train, { target }) end
  if not id then
    for _, turn in ipairs(H.turns(train)) do
      id = job(train, { { station = turn.unit, wait = WAIT }, target })
      if id then break end
    end
  end
  if not id then id = job(train, { target }) end
  if not id then return false end
  task.job, task.phase = id, "deliver"
  storage.jobs[id] = task
  return true
end

--- „Wagen je Rangierfahrt“: Nach dem Ankuppeln nur die ersten `n` Wagen (von der Lok aus) behalten, der Rest
--- bleibt als neuer Verband am Wagenbahnhof stehen und meldet sich wieder. Liefert den Zug der Rangierlok.
local function take(task, train, n)
  local c = train.carriages
  local first, step = 1, 1
  if not task.locos[c[1].unit_number] then first, step = #c, -1 end
  local i = first
  while c[i] and task.locos[c[i].unit_number] do i = i + step end
  local last = i + step * (n - 1)
  local after = c[last + step]
  if not (c[last] and after) or task.locos[after.unit_number] then return train end
  local kept, rest = Couple.split(c[last], after)
  if rest then Groups.add(task.group.unit, rest) end
  return kept or train
end

--- Heranschieben fertig (aus dem Rangier-Takt).
function Shunter.coupled(task, train, ok)
  if task.phase == "onto-couple" then
    Onto.finish(task, train, ok)
    return
  end
  if not ok then
    storage.reserved[task.to] = nil
    warn(Registry.stop(task.group.unit), "warn-shunt-failed")
    H.home(train)
    return
  end
  local n = Registry.count(task.group.unit)
  if n > 0 then train = take(task, train, n) end
  Gate.refresh()
  if not deliver(task, train) then
    storage.reserved[task.to] = nil
    warn(Registry.stop(task.to), "warn-unreachable")
    H.home(train)
  end
end

--- Ereignis on_job_finished.
function Shunter.job_finished(event)
  local task = storage.jobs[event.job_id]
  if not task then return end
  storage.jobs[event.job_id] = nil
  local train = event.train
  if task.phase == "onto" then
    if not (train and train.valid and not event.canceled and Onto.arrived(task, train)) then
      storage.reserved[task.to] = nil
    end
    return
  end
  if task.phase ~= "fetch" then return end -- deliver endet mit cancel_job beim Abkuppeln
  if not (train and train.valid) then return end
  if event.canceled or not (task.target.valid and Groups.valid(task.group)) then
    storage.reserved[task.to] = nil
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
  local loco, wagons = H.split(task, train)
  storage.reserved[task.to] = nil
  if wagons then Groups.add(task.to, wagons) end
  H.home(loco or train)
  Gate.refresh()
  Shunter.assign()
  return true
end

Onto.on_assign = Shunter.assign

return Shunter
