--- Wagenverbände: abgestellte Wagen an einem Wagenbahnhof. Der Mod kennt sie aus seinen eigenen
--- Kuppelvorgängen (kein Suchen). Hat der Bahnhof ein Rangierziel, meldet sich der Verband bei der
--- Rangierlok – sofort oder, wenn er auf „leer“/„voll“ wartet, über einen kurzen Prüftakt, der nur läuft,
--- solange Verbände warten.
local Const = require("scripts.core.const")
local Registry = require("scripts.stations.registry")

local Groups = {}

--- Wird gesetzt (scripts/core/setup.lua): Verband ist bereit zum Weiterbringen → Rangierlok anfordern.
Groups.on_ready = function(group, to) end

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
  if carrying then return group end
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

--- on_load: Prüftakt wieder anmelden, wenn Verbände warten.
function Groups.resume()
  if storage.waiting and #storage.waiting > 0 then script.on_nth_tick(Const.CHECK_TICKS, check) end
end

return Groups
