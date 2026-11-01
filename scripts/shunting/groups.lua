--- Wagenverbände: abgestellte Wagen an einem Wagenbahnhof. Der Mod kennt sie aus seinen eigenen
--- Kuppelvorgängen (kein Suchen). Hat der Bahnhof ein Rangierziel, meldet sich der Verband bei der
--- Rangierlok – sofort oder, wenn er auf „leer“/„voll“ wartet, über einen kurzen Prüftakt, der nur läuft,
--- solange Verbände warten.
local Const = require("scripts.core.const")
local Registry = require("scripts.stations.registry")

local Groups = {}

--- Wird gesetzt (scripts/core/setup.lua): Verband ist bereit zum Weiterbringen → Rangierlok anfordern.
Groups.on_ready = function(group, to) end
--- Wird gesetzt: Wartet ein Zug auf genau diese Wagen (Betriebsart „anstellen“)? true = vergeben.
Groups.claim = function(group) return false end

--- Steht der Verband noch so da (alle Wagen gültig, ein Zug, keine Lok)?
function Groups.valid(group)
  local train
  for _, w in pairs(group.wagons) do
    if not (w.valid and w.train) then return false end
    train = train or w.train
    if w.train ~= train then return false end
  end
  if not train then return false end
  local locos = train.locomotives
  return #locos.front_movers + #locos.back_movers == 0
end

local function inventory_state(w)
  if w.type == "cargo-wagon" then
    local inv = w.get_inventory(defines.inventory.cargo_wagon)
    if not inv then return true, true end
    return inv.is_empty(), inv.is_full()
  elseif w.type == "fluid-wagon" then
    local fluid, capacity = w.fluidbox[1], w.fluidbox.get_capacity(1)
    local amount = fluid and fluid.amount or 0
    return amount < 0.1, amount >= capacity - 0.1
  end
  return true, true
end

--- Erfüllt der Verband die Bedingung `when`?
function Groups.ready(group, when)
  if when == "now" then return true end
  for _, w in pairs(group.wagons) do
    local empty, full = inventory_state(w)
    if (when == "empty" and not empty) or (when == "full" and not full) then return false end
  end
  return true
end

local function check()
  local waiting = storage.waiting
  for _ = 1, math.min(Const.CHECK_BUDGET, #waiting) do
    local group = table.remove(waiting, 1)
    local to, when = Registry.shunt(group.unit)
    if Groups.valid(group) and to then
      if Groups.ready(group, when) then
        Groups.on_ready(group, to)
      else
        waiting[#waiting + 1] = group -- hinten wieder anstellen
      end
    end
  end
  if #waiting == 0 then script.on_nth_tick(Const.CHECK_TICKS, nil) end
end

--- Neuer Verband an Station `unit` aus dem (lokfreien) Zug `train`. Trägt er eine Lieferung (Staffel),
--- holt ihn der nächste Zug ab, nicht die Rangierlok.
function Groups.add(unit, train, carrying)
  local group = { unit = unit, wagons = {}, delivery = carrying or nil }
  for i, w in ipairs(train.carriages) do group.wagons[i] = w end
  storage.parked[unit] = group
  if carrying or Groups.claim(group) then return group end
  local to, when = Registry.shunt(unit)
  if not to then return group end
  if Groups.ready(group, when) then
    Groups.on_ready(group, to)
  else
    storage.waiting[#storage.waiting + 1] = group
    script.on_nth_tick(Const.CHECK_TICKS, check)
  end
  return group
end

--- Steht an der Station noch ein Verband, den der Mod dort abgestellt hat? (Ein Verband, der inzwischen
--- woanders steht, zählt nicht mehr.)
function Groups.occupied(unit)
  local group = storage.parked[unit]
  local stop = Registry.stop(unit)
  if group and stop and Groups.valid(group) then
    local p, q = group.wagons[1].position, stop.position
    if (p.x - q.x) ^ 2 + (p.y - q.y) ^ 2 < Const.NEAR ^ 2 then return true end
  end
  storage.parked[unit] = nil
  return false
end

--- Lokfreie Züge entlang des Gleises an einer Haltestelle (Const.SEARCH in beide Richtungen): { train, d }.
local function nearby(stop)
  local o = stop.orientation * 2 * math.pi
  local fx, fy = math.sin(o), -math.cos(o)
  local p, r = stop.position, Const.SEARCH
  local area = { { p.x - math.abs(fx) * r - 4, p.y - math.abs(fy) * r - 4 },
    { p.x + math.abs(fx) * r + 4, p.y + math.abs(fy) * r + 4 } }
  local list, seen = {}, {}
  for _, e in pairs(stop.surface.find_entities_filtered({ area = area, type = Const.ROLLING_STOCK })) do
    local train = e.train
    if train and not seen[train.id] then
      seen[train.id] = true
      local locos = train.locomotives
      if #locos.front_movers + #locos.back_movers == 0 then
        local q = train.front_stock.position
        list[#list + 1] = { train = train, d = (q.x - p.x) ^ 2 + (q.y - p.y) ^ 2 }
      end
    end
  end
  return list
end

--- Wagen erfassen, die schon an Wagenbahnhöfen stehen (aus Blaupausen oder von Hand hingestellt): eine kleine
--- Suche entlang des Gleises an jeder Haltestelle; jeder Wagenverband gehört zum nächsten Wagenbahnhof. Nur beim
--- Start bzw. auf Anfrage (on_init, Fernaufruf „scan“). Liefert die Zahl neuer Verbände.
function Groups.scan_all()
  local best = {}
  for unit, role in pairs(storage.stations) do
    local stop = role == Const.ROLE.yard and Registry.stop(unit)
    if stop and not Groups.occupied(unit) then
      for _, found in ipairs(nearby(stop)) do
        local id = found.train.id
        if not best[id] or found.d < best[id].d then best[id] = { unit = unit, train = found.train, d = found.d } end
      end
    end
  end
  local count, used = 0, {}
  for _, entry in pairs(best) do
    if entry.train.valid and not used[entry.unit] and not Groups.occupied(entry.unit) then
      used[entry.unit] = true
      Groups.add(entry.unit, entry.train)
      count = count + 1
    end
  end
  return count
end

--- on_load: Prüftakt wieder anmelden, wenn Verbände warten.
function Groups.resume()
  if storage.waiting and #storage.waiting > 0 then script.on_nth_tick(Const.CHECK_TICKS, check) end
end

return Groups
