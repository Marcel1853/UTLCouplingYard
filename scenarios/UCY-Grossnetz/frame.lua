--- Bau-Rahmen: Ein Teil des Netzes wird einmal in eigenen Koordinaten aufgeschrieben (z. B. „Strecke nach Osten“)
--- und mit Verschiebung und Drehung in Vierteln (im Uhrzeigersinn) an seinen Platz gesetzt. Gedreht wird um ganze
--- Viertel, verschoben um gerade Werte – so passen Gleise und Signale ins 2er-Raster, und der Rechtsverkehr bleibt
--- erhalten (gespiegelt wird nie).
local Frame = {}
Frame.__index = Frame

local RAILS = { ["straight-rail"] = true, ["curved-rail-a"] = true, ["curved-rail-b"] = true,
  ["half-diagonal-rail"] = true }
local SIGNALS = { ["rail-signal"] = true, ["rail-chain-signal"] = true }

--- `stats` zählt Gleise und Signale, die sich nicht setzen ließen.
function Frame.new(surface, ox, oy, turns, stats)
  return setmetatable({ surface = surface, ox = ox, oy = oy, turns = turns % 4, stats = stats }, Frame)
end

function Frame:pos(x, y)
  for _ = 1, self.turns do x, y = -y, x end
  return { self.ox + x, self.oy + y }
end

function Frame:dir(d)
  return (d + 4 * self.turns) % 16
end

--- Bauteil in Rahmen-Koordinaten setzen. Gerade Gleise und Halbdiagonalen sind nach einer halben Drehung dasselbe
--- Stück, daher deren Richtung nur bis 8.
function Frame:create(name, x, y, d, extra)
  local dir = self:dir(d or 0)
  if name == "straight-rail" or name == "half-diagonal-rail" then dir = dir % 8 end
  local spec = { name = name, position = self:pos(x, y), direction = dir, force = "player" }
  for k, v in pairs(extra or {}) do spec[k] = v end
  local made = self.surface.create_entity(spec)
  if not made then
    if RAILS[name] then
      self.stats.rails_failed = self.stats.rails_failed + 1
    elseif SIGNALS[name] then
      self.stats.signals_failed = self.stats.signals_failed + 1
    end
  elseif SIGNALS[name] then
    self.stats.signals = self.stats.signals + 1
  end
  return made
end

--- Gerade Strecke in Rahmen-Richtung Ost–West auf Höhe `y` von `x1` bis `x2` (Mitten der Gleisstücke, ungerade).
function Frame:straight(y, x1, x2)
  for x = x1, x2, 2 do self:create("straight-rail", x, y, 4) end
end

function Frame:signal(chain, x, y, d)
  return self:create(chain and "rail-chain-signal" or "rail-signal", x, y, d)
end

--- Weiche aus Marcels Rangier-Blaupause (wie im Szenario „Rangierbahnhof“): Die Gleise `Y - 8` und `Y + 8` laufen
--- auf das Stammgleis `Y`. `east` = die beiden Gleise beginnen bei `x` und liegen östlich, der Stamm endet bei
--- `x - 16`; sonst enden die beiden Gleise bei `x` und der Stamm beginnt bei `x + 16`. `only` = "upper" bzw.
--- "lower" setzt nur einen Zweig – eine S-Kurve, die ein Gleis um 8 Felder versetzt.
function Frame:throat(x, Y, east, only)
  local A, B = "curved-rail-a", "curved-rail-b"
  if east then
    if only ~= "upper" then
      self:create(A, x - 3, Y + 8, 14); self:create(B, x - 8, Y + 6, 14)
      self:create(B, x - 12, Y + 2, 6); self:create(A, x - 17, Y, 6)
    end
    if only ~= "lower" then
      self:create(A, x - 3, Y - 8, 12); self:create(B, x - 8, Y - 6, 12)
      self:create(B, x - 12, Y - 2, 4); self:create(A, x - 17, Y, 4)
    end
  else
    if only ~= "lower" then
      self:create(A, x + 3, Y - 8, 6); self:create(B, x + 8, Y - 6, 6)
      self:create(B, x + 12, Y - 2, 14); self:create(A, x + 17, Y, 14)
    end
    if only ~= "upper" then
      self:create(A, x + 3, Y + 8, 4); self:create(B, x + 8, Y + 6, 4)
      self:create(B, x + 12, Y + 2, 12); self:create(A, x + 17, Y, 12)
    end
  end
end

-- Gleisstücke aus UTLs Lasttest (scenarios/UTL-Lasttest/track-pieces.lua, dort im Spiel ermittelt):
-- { Name, Richtung, dx, dy } relativ zum letzten geraden Stück davor.
-- 90°-Kurve: von Norden nach Osten; das nächste gerade Stück liegt bei (14, -14).
local RIGHT_N = { { "curved-rail-a", 2, 0, -3 }, { "curved-rail-b", 2, 2, -8 }, { "curved-rail-b", 12, 6, -12 },
  { "curved-rail-a", 12, 11, -14 } }
-- Abzweig nach rechts (6 Felder versetzt, Fahrt nach Osten): Zweig gerade ab (20, 6).
local DIVERGE_E = { { "curved-rail-a", 6, 3, 0 }, { "half-diagonal-rail", 6, 8, 2 },
  { "half-diagonal-rail", 6, 12, 4 }, { "curved-rail-a", 14, 17, 6 } }
-- Einmündung von rechts (Fahrt nach Osten): Zweig gerade bis (-20, 6).
local MERGE_E = { { "curved-rail-a", 12, -3, 0 }, { "half-diagonal-rail", 4, -8, 2 },
  { "half-diagonal-rail", 4, -12, 4 }, { "curved-rail-a", 4, -17, 6 } }

--- Gleisstücke um `turns` Viertel gedreht an (x, y) setzen.
function Frame:pieces(list, x, y, turns)
  for _, p in ipairs(list) do
    local dx, dy = p[3], p[4]
    for _ = 1, turns or 0 do dx, dy = -dy, dx end
    self:create(p[1], x + dx, y + dy, (p[2] + 4 * (turns or 0)) % 16)
  end
end

--- 90°-Kurve. `turns` = 0: von Norden nach Osten (Ende bei +14/-14), 1: Osten → Süden, 2: Süden → Westen,
--- 3: Westen → Norden. Rückwärts befahren ist dieselbe Kurve eine Linkskurve.
function Frame:curve(x, y, turns) self:pieces(RIGHT_N, x, y, turns) end
function Frame:diverge(x, y) self:pieces(DIVERGE_E, x, y, 0) end
function Frame:merge(x, y) self:pieces(MERGE_E, x, y, 0) end

--- Senkrechte Strecke bei `x` von `y1` bis `y2`.
function Frame:vertical(x, y1, y2)
  for y = y1, y2, 2 do self:create("straight-rail", x, y, 0) end
end

--- Haltestelle rechts vom Gleis `y` bei `x`: Fahrt nach Osten (Halt südlich) oder Westen (nördlich), im Rahmen.
function Frame:stop(name, x, y, west, utl)
  local stop = self:create(utl and "utl-train-stop" or "train-stop", x, y + (west and -2 or 2), west and 12 or 4,
    { raise_built = true })
  if stop then stop.backer_name = name end
  return stop
end

--- Fahrzeug auf dem Gleis, Blick nach Osten oder Westen (im Rahmen); Loks mit Kohle.
function Frame:stock(name, x, y, west)
  local made = self:create(name, x, y, west and 12 or 4)
  if made and name == "locomotive" then made.insert({ name = "coal", count = 50 }) end
  return made
end

return Frame
