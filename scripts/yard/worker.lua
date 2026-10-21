--- Rangier-Takt: arbeitet die Warteschlange ab und schiebt Züge heran. on_nth_tick ist nur angemeldet,
--- solange etwas offen ist – ohne Rangiervorgang kostet der Mod nichts.
local Const = require("scripts.core.const")
local Yard = require("scripts.yard.yard")
local Crawl = require("scripts.coupling.crawl")

local Worker = {}

local BUDGET = 4 -- so viele Ankünfte je Takt

local function pending()
  return #storage.queue > 0 or #storage.crawls > 0
end

local function run()
  local queue = storage.queue
  for _ = 1, math.min(BUDGET, #queue) do
    Yard.process(table.remove(queue, 1))
  end
  Crawl.run(function(train) Yard.release(train) end)
  if not pending() then script.on_nth_tick(Const.TICK, nil) end
end

--- Takt anmelden (nach einer neuen Ankunft).
function Worker.wake()
  script.on_nth_tick(Const.TICK, run)
end

--- on_load: Takt wieder anmelden, wenn beim Speichern etwas offen war.
function Worker.resume()
  if storage.queue and pending() then Worker.wake() end
end

return Worker
