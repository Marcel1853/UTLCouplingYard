--- Eigenes Netz: Kreisel aus Marcels Blaupause (kreisel.lua) im Raster COLS × ROWS, Abstand D. Zwischen zwei
--- Kreiseln je eine gerade Strecke mit zwei Gleisen je Richtung (Rechtsverkehr) und Blocksignalen; die beiden
--- äußeren Gleise sind Bahnhofsgleise – Abzweig und Einmündung liefert der Kreisel mit, ebenso die Signale an den
--- Armen (Einfahrt Bahnhofsgleis, Kettensignal vor der Einmündung). Auf jedem Bahnhofsgleis: Haltestelle kurz vor
--- der Einmündung und zwei Warteplätze dahinter.
---
--- Eine Strecke wird einmal „nach Osten“ aufgeschrieben (Kreisel bei x = 0, Nachbar bei x = D) und für die
--- senkrechten Strecken um ein Viertel gedreht. Gleise: y = -13, -5 nach Westen, 5, 13 nach Osten; Bahnhofsgleise
--- y = -19 (nach Westen) und 19 (nach Osten). Die Arme der Kreisel enden bei ±53.
local Frame = require("__UTLCouplingYard__/scenarios/UCY-Grossnetz/frame")
local Kreisel = require("__UTLCouplingYard__/scenarios/UCY-Grossnetz/kreisel")

local Network = { COLS = 4, ROWS = 3, D = 320 }
local D = Network.D

local NAMES = { S = "straight-rail", A = "curved-rail-a", B = "curved-rail-b", H = "half-diagonal-rail",
  G = "rail-signal", K = "rail-chain-signal" }
local TRACKS = { -19, -13, -5, 5, 13, 19 }
local BLOCKS = { 100, 152, 204 } -- Blocksignale auf den Streckengleisen (ungefähr alle 52 Felder)
local WAIT = { 86.5, 112.5 }     -- Warteplätze hinter dem Bahnsteig (Abstand vom Kreisel)

--- Mitte des Kreisels in Spalte i, Zeile j.
function Network.center(i, j) return i * D, j * D end

local function kreisel(F, signals)
  for _, e in ipairs(Kreisel) do
    local is_signal = e[1] == "G" or e[1] == "K"
    if is_signal == signals then F:create(NAMES[e[1]], e[2], e[3], e[4]) end
  end
end

local function corridor_rails(F)
  for _, y in ipairs(TRACKS) do F:straight(y, 55, D - 55) end
end

--- Signale einer Strecke; liefert ihre beiden Bahnhofsgleise (Halt, Gleispunkt am Halt, Fahrtrichtung).
--- `facility`: das Bahnhofsgleis nach Osten gehört einer Kuppel-Anlage im Block darunter (kein UTL-Bahnhof).
local function corridor_signals(F, sidings, facility)
  for _, x in ipairs(BLOCKS) do
    -- nach Westen: Signal nördlich (rechts), nach Osten: südlich; Blick jeweils zum ankommenden Zug
    F:signal(false, x + 0.5, -14.5, 4)
    F:signal(false, x + 0.5, -6.5, 4)
    F:signal(false, D - x - 0.5, 6.5, 12)
    F:signal(false, D - x - 0.5, 14.5, 12)
  end
  for _, x in ipairs(WAIT) do
    F:signal(false, x, -20.5, 4)
    if not facility then F:signal(false, D - x, 20.5, 12) end
  end
  sidings[#sidings + 1] = { frame = F, x = 62, y = -19, west = true }
  if not facility then sidings[#sidings + 1] = { frame = F, x = D - 62, y = 19, west = false } end
end

--- Netz bauen. `blocks` = Liste { i, j } der Blöcke mit Kuppel-Anlage (unter der Strecke von Kreisel i, j nach
--- Osten). Liefert die Bahnhofsgleise für UTL und die Rahmen der Anlagen (gleiche Reihenfolge wie `blocks`).
function Network.build(surface, stats, blocks)
  local kreisels, corridors, frames, facility = {}, {}, {}, {}
  local wanted = {}
  for n, b in ipairs(blocks) do wanted[b[1] .. "/" .. b[2]] = n end
  for i = 0, Network.COLS - 1 do
    for j = 0, Network.ROWS - 1 do
      local x, y = Network.center(i, j)
      kreisels[#kreisels + 1] = Frame.new(surface, x, y, 0, stats)
      if i < Network.COLS - 1 then
        local F = Frame.new(surface, x, y, 0, stats)
        corridors[#corridors + 1] = F
        local n = wanted[i .. "/" .. j]
        if n then frames[n], facility[F] = F, true end
      end
      if j < Network.ROWS - 1 then corridors[#corridors + 1] = Frame.new(surface, x, y, 1, stats) end
    end
  end
  -- erst alle Gleise, dann die Signale (ein Signal ohne sein Gleis rutscht ans nächste)
  for _, F in ipairs(kreisels) do kreisel(F, false) end
  for _, F in ipairs(corridors) do corridor_rails(F) end
  for _, F in ipairs(kreisels) do kreisel(F, true) end
  local sidings = {}
  for _, F in ipairs(corridors) do corridor_signals(F, sidings, facility[F]) end
  return sidings, frames
end

return Network
