--- Feste Werte des Mods: Name, Rollen-Schlüssel, Betriebsarten des Wagenbahnhofs, Rangier-Werte.
local Const = {}

Const.MOD = "UTLCouplingYard"

--- Eigene Rollen (Schlüssel bei UTL: "UTLCouplingYard/<name>").
Const.ROLE = {
  yard = Const.MOD .. "/yard",   -- Wagenbahnhof: Wagen abstellen und abholen
  depot = Const.MOD .. "/depot", -- Rangierdepot: Loks gehören diesem Mod
  turn = Const.MOD .. "/turn",   -- Wende: Rangierlok wechselt hier die Richtung
}

--- Betriebsarten des Wagenbahnhofs (Stationsdaten "mode"). Erste = Vorgabe.
Const.MODES = { "swap", "drop", "pickup" }

Const.ROLLING_STOCK = { "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon" }

Const.TICK = 5          -- Takt beim Rangieren (nur angemeldet, solange etwas zu tun ist)
Const.CRAWL_SPEED = 0.05 -- Schritttempo beim Heranschieben (Kacheln je Tick)
Const.SEARCH = 40       -- so weit vor dem Zug (Kacheln) werden Wagen zum Abholen gesucht
Const.STALL_STEPS = 12  -- so viele Takte ohne Bewegung: Heranschieben aufgeben
Const.CRAWL_TIMEOUT = 60 * 60 -- spätestens nach einer Minute aufgeben

return Const
