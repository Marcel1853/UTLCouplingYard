--- Heranschieben: Der Zug fährt im Schritttempo in Fahrtrichtung, bis sein Kopf an den Zielwagen
--- gekuppelt ist. Läuft nur im Rangier-Takt (scripts/yard/worker.lua), solange ein Vorgang offen ist.
local Const = require("scripts.core.const")
local Couple = require("scripts.coupling.couple")
local Geometry = require("scripts.coupling.geometry")

local Crawl = {}

--- Neuen Vorgang anlegen: `head` = Kopfwagen des Zuges, `target` = nächster Wagen vor ihm,
--- (fx, fy) = Fahrtrichtung, `task` = Rangierauftrag (nil am Wagenbahnhof), `info` = Angaben des
--- Wagenbahnhofs (z. B. ob der Zug vorher eine Lieferung hatte).
function Crawl.start(head, target, fx, fy, task, info)
  storage.crawls[#storage.crawls + 1] = {
    head = head, target = target, dir = Geometry.ahead(head, fx, fy), task = task, info = info,
    ids = Couple.announce(head, target), started = game.tick, still = 0,
  }
end

--- Ein Schritt. Liefert den Zug, wenn der Vorgang fertig ist (gekuppelt oder aufgegeben), sonst nil.
--- Liefert false, wenn der Zug verschwunden ist.
local function step(c)
  if not (c.head.valid and c.head.train) then return false end
  local train = c.head.train
  if not c.target.valid then
    train.speed = 0
    Couple.finish(c.ids, train)
    return train
  end
  local joined = Couple.try(c.head, c.dir, c.target)
  if joined then
    joined.speed = 0
    Couple.finish(c.ids, joined)
    return joined
  end
  local p = c.head.position
  if c.last and math.abs(p.x - c.last.x) + math.abs(p.y - c.last.y) < 0.01 then
    c.still = c.still + 1
  else
    c.still = 0
  end
  c.last = p
  if c.still >= Const.STALL_STEPS or game.tick - c.started > Const.CRAWL_TIMEOUT then
    train.speed = 0
    Couple.finish(c.ids, train)
    return train
  end
  train.speed = Geometry.speed_towards_head(train, c.head, Const.CRAWL_SPEED)
  return nil
end

--- Alle offenen Vorgänge einen Schritt weiter. Ruft `done(train, coupled, vorgang)` für jeden fertigen.
function Crawl.run(done)
  local crawls = storage.crawls
  for i = #crawls, 1, -1 do
    local c = crawls[i]
    local result = step(c)
    if result ~= nil then
      table.remove(crawls, i)
      if result then done(result, c.target.valid and c.target.train == result, c) end
    end
  end
end

return Crawl
