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

--- Wann die Rangierlok abgestellte Wagen weiterbringt (Stationsdaten "shunt_when"). Erste = Vorgabe.
Const.WHEN = { "now", "empty", "full" }

Const.ROLLING_STOCK = { "locomotive", "cargo-wagon", "fluid-wagon", "artillery-wagon" }

Const.TICK = 5          -- Takt beim Rangieren (nur angemeldet, solange etwas zu tun ist)
Const.CRAWL_SPEED = 0.05 -- Schritttempo beim Heranschieben (Kacheln je Tick)
Const.SEARCH = 40       -- so weit vor dem Zug (Kacheln) werden Wagen zum Abholen gesucht
Const.STALL_STEPS = 12  -- so viele Takte ohne Bewegung: Heranschieben aufgeben
Const.CRAWL_TIMEOUT = 60 * 60 -- spätestens nach einer Minute aufgeben
Const.APPROACH = 12     -- so weit vor dem Ende eines Wagenverbands hält die Rangierlok, dann schiebt sie heran
Const.CHECK_TICKS = 120 -- Prüftakt für Wagen, die auf „leer“/„voll“ warten (nur solange welche warten)
Const.CHECK_BUDGET = 10 -- so viele Wagenverbände je Prüftakt
Const.SHUNT_RANGE = 400 -- Rangierloks arbeiten nur so weit (Kacheln) von ihrem Wagenverband entfernt
Const.NEAR = 60         -- so nah an seiner Haltestelle muss ein Verband stehen, damit das Gleis belegt ist

return Const
