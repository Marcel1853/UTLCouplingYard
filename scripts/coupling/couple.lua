--- Kuppel-Kern: Wagen trennen und zusammenkuppeln, jeweils bei UTL angemeldet
--- (begin_train_change / end_train_change), damit Lieferung, Festhalten und Auftrag mit umziehen.
--- Zug-IDs ändern sich dabei – wer einen Zug wiederfinden will, merkt sich einen Wagen (`wagen.train`).
local Couple = {}

local DIRS = { defines.rail_direction.front, defines.rail_direction.back }

--- Trennt den Zug zwischen den benachbarten Wagen `keep` und `other`. Der Teil mit `keep` übernimmt
--- bei UTL alles vom alten Zug, den anderen Teil vergisst UTL. Liefert (Zug mit keep, Zug mit other)
--- oder nil, wenn die beiden nicht nebeneinander hängen.
function Couple.split(keep, other)
  local train = keep.train
  if not (train and other.train == train) then return nil end
  for _, dir in pairs(DIRS) do
    if keep.get_connected_rolling_stock(dir) == other then
      local old = train.id
      remote.call("utl", "begin_train_change", { old })
      local ok = keep.disconnect_rolling_stock(dir)
      local kept, rest = keep.train, other.train
      remote.call("utl", "end_train_change", { old }, kept)
      if not ok or kept == rest then return nil end
      rest.manual_mode = true -- hängt hinten noch eine Lok dran, fährt sie nicht mit dem kopierten Fahrplan los
      remote.call("utl", "forget_train", rest.id)
      return kept, rest
    end
  end
  return nil
end

--- Umbau anmelden, bevor `stock` an `target` gekuppelt wird. Liefert die alten IDs (eigener Zug zuerst:
--- dessen Lieferung bleibt).
function Couple.announce(stock, target)
  local ids = { stock.train.id }
  if target.train ~= stock.train then ids[2] = target.train.id end
  remote.call("utl", "begin_train_change", ids)
  return ids
end

--- Versucht, `stock` in Richtung `dir` an `target` zu kuppeln (nach Couple.announce). Liefert den neuen
--- Zug, wenn beide jetzt zusammenhängen, sonst nil (die Anmeldung bleibt offen).
function Couple.try(stock, dir, target)
  if not stock.connect_rolling_stock(dir) then return nil end
  if stock.train ~= target.train then return nil end
  return stock.train
end

--- Umbau abschließen: alles von `ids` auf `train` umziehen (auch wenn das Kuppeln nicht geklappt hat –
--- dann bleibt der Zug derselbe).
function Couple.finish(ids, train)
  return remote.call("utl", "end_train_change", ids, train)
end

return Couple
