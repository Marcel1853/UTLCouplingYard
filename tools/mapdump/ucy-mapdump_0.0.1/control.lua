--- Kartenauszug für Bilder ohne Grafik: Nach MAPDUMP_TICKS schreibt der Mod alle Gleise, Signale, Halte, Fahrzeuge
--- und Ladestellen der ersten Oberfläche außer nauvis nach script-output/ucy-map-<tick>.json (tools/render-map.py
--- zeichnet daraus Bilder). Alle 30 Sekunden bis Minute 6.
local TICKS = {}
for t = 1800, 21600, 1800 do TICKS[#TICKS + 1] = t end

local function xy(e) return { math.floor(e.position.x * 10 + 0.5) / 10, math.floor(e.position.y * 10 + 0.5) / 10 } end

local function dump(tick)
  local surface
  for _, s in pairs(game.surfaces) do if s.name ~= "nauvis" then surface = s end end
  if not surface then return end
  local out = { tick = tick, rails = {}, signals = {}, stops = {}, stock = {}, other = {} }
  for _, e in pairs(surface.find_entities_filtered({ type = { "straight-rail", "curved-rail-a", "curved-rail-b",
    "half-diagonal-rail" } })) do
    out.rails[#out.rails + 1] = { e.type, xy(e)[1], xy(e)[2], e.direction }
  end
  for _, e in pairs(surface.find_entities_filtered({ type = { "rail-signal", "rail-chain-signal" } })) do
    out.signals[#out.signals + 1] = { e.type == "rail-chain-signal" and "K" or "G", xy(e)[1], xy(e)[2], e.direction,
      e.signal_state }
  end
  for _, e in pairs(surface.find_entities_filtered({ type = "train-stop" })) do
    out.stops[#out.stops + 1] = { e.backer_name, xy(e)[1], xy(e)[2], e.direction }
  end
  for _, e in pairs(surface.find_entities_filtered({ type = { "locomotive", "cargo-wagon" } })) do
    out.stock[#out.stock + 1] = { e.type == "locomotive" and "L" or "W", xy(e)[1], xy(e)[2], e.orientation,
      e.train and e.train.id or 0, e.train and e.train.state or -1 }
  end
  for _, e in pairs(surface.find_entities_filtered({ type = { "inserter", "infinity-container", "electric-pole",
    "electric-energy-interface", "display-panel" } })) do
    out.other[#out.other + 1] = { e.type, xy(e)[1], xy(e)[2] }
  end
  helpers.write_file("ucy-map-" .. tick .. ".json", helpers.table_to_json(out))
  log("[UCY-MAP] Auszug " .. tick .. ": " .. #out.rails .. " Gleise, " .. #out.signals .. " Signale, "
    .. #out.stock .. " Fahrzeuge")
end

script.on_nth_tick(1800, function(event) if event.tick <= TICKS[#TICKS] then dump(event.tick) end end)
