-- Führt eine Tipps-&-Tricks-Szene (prototypes/tips/scenes.lua) in einer normalen Welt aus und schreibt alle
-- 5 Sekunden die Züge ins Log (Halt, Fahrzeuge, Lage). Welche Szene: scene.lua.
local code = require("__UTLCouplingYard__/prototypes/tips/scenes")
local scene = require("scene")
script.on_nth_tick(30, function(e)
  if e.tick == 30 then
    game.surfaces[1].request_to_generate_chunks({ 0, 0 }, 3)
    game.surfaces[1].force_generate_chunk_requests()
    assert(load(code[scene]))()
    return
  end
  if e.tick % 300 ~= 0 then return end
  local parts = {}
  for _, t in pairs(game.train_manager.get_trains({ surface = 1 })) do
    local locos = t.locomotives
    parts[#parts + 1] = ("%s %d Fz (%d Loks) x=%.0f Zustand %d"):format(t.station and t.station.backer_name or "-",
      #t.carriages, #locos.front_movers + #locos.back_movers, t.front_stock.position.x, t.state)
  end
  table.sort(parts)
  log(("[TIPS] %s %d s: %s | Rangierloks %s"):format(scene, (e.tick - 30) / 60, table.concat(parts, " | "),
    serpent.line(remote.call("UTLCouplingYard", "get_shunters"))))
end)
