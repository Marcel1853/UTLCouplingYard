--- Sperre über das Zuglimit (Einstellung „Zuglimit steuern“ je Wagenbahnhof): Ein Zug fährt einen Halt nur an,
--- wenn es dort passt.
---   abstellen / abstellen und abholen: gesperrt, solange auf dem Platz des haltenden Zuges noch Wagen stehen
---   abholen: gesperrt, solange keine Wagen direkt vor dem Halt warten
--- Geprüft wird nur nach Ereignissen (Kuppeln, Wagen gebaut oder entfernt), mit einer kleinen Suche je Halt.
local Const = require("scripts.core.const")
local Registry = require("scripts.stations.registry")

local Gate = {}

local NO_LIMIT = 4294967295 -- Zuglimit aus
local REACH = 30            -- so weit vor bzw. hinter dem Halt zählen Wagen

--- Stehen abgestellte Wagen (Zug ohne Lok) vor (`side` = 1) bzw. hinter (`side` = -1) dem Halt?
local function parked(stop, side)
  local rail = stop.connected_rail
  if not rail then return false end
  local o = stop.orientation * 2 * math.pi
  local fx, fy = math.sin(o) * side, -math.cos(o) * side
  local p = rail.position
  local q = { x = p.x + fx * REACH, y = p.y + fy * REACH }
  local area = { { math.min(p.x, q.x) - 1.5, math.min(p.y, q.y) - 1.5 },
    { math.max(p.x, q.x) + 1.5, math.max(p.y, q.y) + 1.5 } }
  for _, e in pairs(stop.surface.find_entities_filtered({ area = area, type = Const.ROLLING_STOCK })) do
    local train = e.train
    if train then
      local locos = train.locomotives
      if #locos.front_movers + #locos.back_movers == 0 then return true end
    end
  end
  return false
end

--- Einen Halt neu bewerten.
function Gate.update(unit)
  local stop = Registry.stop(unit)
  if not stop then return end
  if not Registry.gate(unit) then
    if storage.gated[unit] then
      storage.gated[unit] = nil
      stop.trains_limit = NO_LIMIT
    end
    return
  end
  storage.gated[unit] = true
  local closed
  if Registry.mode(unit) == "pickup" then
    closed = not parked(stop, 1)
  else
    closed = parked(stop, -1)
  end
  stop.trains_limit = closed and 0 or NO_LIMIT
end

--- Alle Wagenbahnhöfe mit Sperre neu bewerten (nach Kuppeln, Wagen gebaut/entfernt, Einstellung geändert).
function Gate.refresh()
  for unit, role in pairs(storage.stations) do
    if role == Const.ROLE.yard and (storage.gated[unit] or Registry.gate(unit)) then Gate.update(unit) end
  end
end

local function later()
  script.on_nth_tick(1, nil)
  storage.gate_pending = nil
  Gate.refresh()
end

--- Wagen gebaut oder entfernt: im nächsten Tick neu bewerten (ein entfernter Wagen steht beim Ereignis noch da).
function Gate.soon()
  if not next(storage.gated) or storage.gate_pending then return end
  storage.gate_pending = true
  script.on_nth_tick(1, later)
end

--- on_load: offene Prüfung wieder anmelden.
function Gate.resume()
  if storage.gate_pending then script.on_nth_tick(1, later) end
end

return Gate
