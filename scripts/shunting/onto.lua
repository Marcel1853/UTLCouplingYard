--- Wagen an einen stehenden Zug kuppeln:
---   anstellen – Betriebsart „Wagen von hinten anstellen“ (Karteneinstellung ucy-attach): Ein Zug hält und wartet,
---     die Rangierlok holt Wagen vom Quell-Wagenbahnhof, schiebt sie an sein Ende und kuppelt; der Zug fährt dann
---     gezogen weiter. So braucht ein Streckenzug keine Lok in Gegenrichtung.
---   anhängen – Ziel mit „an vorhandene Wagen anhängen“ (Karteneinstellung ucy-partial): Stehen dort schon Wagen,
---     schiebt die Rangierlok die neuen heran und kuppelt sie an (Wagenreihe).
--- Ablauf: Auftrag zu einem Punkt hinter dem stehenden Zug (Wagen voran, sonst über die nächste Wende) →
--- heranschieben und kuppeln → Rangierlok abtrennen, beide bekommen ihren eigenen Fahrplan zurück.
local Const = require("scripts.core.const")
local Registry = require("scripts.stations.registry")
local Crawl = require("scripts.coupling.crawl")
local Geometry = require("scripts.coupling.geometry")
local Schedule = require("scripts.coupling.schedule")
local Groups = require("scripts.shunting.groups")
local Gate = require("scripts.yard.gate")
local H = require("scripts.shunting.helpers")

local Onto = {}

--- Werden gesetzt (scripts/core/setup.lua): Zug weiterschicken (Yard.release), Rangierloks verteilen.
Onto.on_release = function(train, info) end
Onto.on_assign = function() end

--- Nächster bereitstehender Verband an einem Wagenbahnhof mit dem Namen `from` (oder nil).
local function find(from, stop)
  local best, best_d
  for unit, role in pairs(storage.stations) do
    local s = role == Const.ROLE.yard and Registry.stop(unit)
    if s and s.backer_name == from and s.surface == stop.surface and Groups.occupied(unit) then
      local group = storage.parked[unit]
      if not group.busy and not group.delivery then
        local d = (s.position.x - stop.position.x) ^ 2 + (s.position.y - stop.position.y) ^ 2
        if not best_d or d < best_d then best, best_d = group, d end
      end
    end
  end
  return best
end

local function start(unit, group)
  group.busy = true
  storage.attach[unit].task = true
  storage.tasks[#storage.tasks + 1] = { group = group, fixed = unit, attach = true }
  Onto.on_assign()
end

--- Ein Zug wartet am Wagenbahnhof `unit` (Betriebsart „anstellen“): Wagen anfordern.
function Onto.wait(unit, train, current)
  local stop = Registry.stop(unit)
  local from = Registry.attach_from(unit)
  if not (stop and from) then
    H.warn(stop, "warn-no-source")
    Onto.on_release(train, { current = current })
    return
  end
  storage.attach[unit] = { ref = train.front_stock, current = current, schedule = Schedule.save(train), from = from }
  local group = find(from, stop)
  if group then start(unit, group) end
end

--- Neuer Verband (Groups.claim): Wartet ein Zug auf Wagen von diesem Wagenbahnhof? Dann dorthin anstellen.
function Onto.offer(group)
  local stop = Registry.stop(group.unit)
  if not stop or group.delivery then return false end
  for unit, waiting in pairs(storage.attach) do
    if not (waiting.ref.valid and waiting.ref.train) then
      storage.attach[unit] = nil
    elseif not waiting.task and waiting.from == stop.backer_name and waiting.ref.surface == stop.surface then
      start(unit, group)
      return true
    end
  end
  return false
end

--- Steht am Ziel ein Zug, an den angekuppelt wird? Liefert (Zug, Haltestelle) oder nil.
local function standing(task)
  local stop = Registry.stop(task.to)
  if not stop then return nil end
  if task.attach then
    local waiting = storage.attach[task.to]
    local train = waiting and waiting.ref.valid and waiting.ref.train
    return train or nil, stop
  end
  if Registry.append(task.to) and Groups.occupied(task.to) then
    return storage.parked[task.to].wagons[1].train, stop
  end
  return nil
end

--- Zum stehenden Zug fahren (Ersatz für den normalen Auftrag zum Ziel). Liefert nil, wenn am Ziel nichts steht
--- (dann normal abstellen), sonst ob der Auftrag angelegt wurde.
function Onto.deliver(task, train)
  local target, stop = standing(task)
  if not target then return nil end
  local _, back = Geometry.ends(target, stop)
  if not back then return false end
  local fx, fy = Geometry.forward(stop)
  local reach = Const.APPROACH + 4
  local at = { x = back.position.x - fx * reach, y = back.position.y - fy * reach }
  local goal = { position = at, surface = back.surface.index, wait = H.WAIT }
  local id
  if H.wagons_lead(task, train, H.rail_at(back.surface, at)) then id = H.job(train, { goal }) end
  if not id then
    for _, turn in ipairs(H.turns(train)) do
      id = H.job(train, { { station = turn.unit, wait = H.WAIT }, goal })
      if id then break end
    end
  end
  if not id then
    -- schon nah dran (der Punkt liegt unter den eigenen Wagen): direkt heranschieben, wenn die Wagen vorn sind
    local front, rear = train.front_stock, train.back_stock
    local function d(e) return (e.position.x - back.position.x) ^ 2 + (e.position.y - back.position.y) ^ 2 end
    local head = d(front) <= d(rear) and front or rear
    if task.locos[head.unit_number] or d(head) > Const.SEARCH ^ 2 then return false end
    task.onto = back
    return Onto.arrived(task, train)
  end
  task.job, task.phase, task.onto = id, "onto", back
  storage.jobs[id] = task
  return true
end

--- Auftrag fertig (hinter dem stehenden Zug) oder schon nah dran: festhalten, Fahrplan sichern, heranschieben.
function Onto.arrived(task, train)
  if not task.onto.valid then return false end
  remote.call("utl", "hold_train", train.id, Const.MOD)
  train.manual_mode = true
  task.schedule = Schedule.save(train)
  task.phase = "onto-couple"
  local front, back = train.front_stock, train.back_stock
  local t = task.onto.position
  local function d(e) return (e.position.x - t.x) ^ 2 + (e.position.y - t.y) ^ 2 end
  local head = d(front) <= d(back) and front or back
  local fx, fy = H.unit_vector(t.x - head.position.x, t.y - head.position.y)
  Crawl.start(head, task.onto, fx, fy, task)
  return true
end

--- Heranschieben fertig: Rangierlok abtrennen; angestellter Zug fährt weiter bzw. Wagenreihe wird angemeldet.
function Onto.finish(task, train, ok)
  local waiting = task.attach and storage.attach[task.to]
  if task.attach then storage.attach[task.to] = nil end
  local loco, rest = H.split(task, train, ok and task.attach)
  if loco then
    Schedule.restore(loco, task.schedule)
    H.home(loco)
  end
  if not ok then
    H.warn(Registry.stop(task.to), "warn-shunt-failed")
    if rest then Groups.add(task.to, rest) end
    local target = waiting and waiting.ref.valid and waiting.ref.train
    if target then Onto.on_release(target, { current = waiting.current }) end
  elseif task.attach and rest then
    Schedule.restore(rest, waiting and waiting.schedule)
    Onto.on_release(rest, { current = waiting and waiting.current })
  elseif rest then
    Groups.add(task.to, rest)
  end
  storage.reserved[task.to] = nil
  Gate.refresh()
  Onto.on_assign()
end

return Onto
