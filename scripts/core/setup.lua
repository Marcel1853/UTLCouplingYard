--- Anmeldung bei UTL: storage anlegen, Rollen und Fensterabschnitt registrieren, UTL-Ereignisse hören.
local Const = require("scripts.core.const")
local Api = require("scripts.api")
local Registry = require("scripts.stations.registry")
local Yard = require("scripts.yard.yard")
local Worker = require("scripts.yard.worker")
local Depot = require("scripts.shunting.depot")
local Groups = require("scripts.shunting.groups")
local Shunter = require("scripts.shunting.shunter")
local Relay = require("scripts.yard.relay")

Groups.on_ready = Shunter.request

local Setup = {}

--- storage nur ergänzen, nie umbauen.
function Setup.storage()
  storage.stations = storage.stations or {} -- unit → Rollen-Schlüssel
  storage.queue = storage.queue or {}       -- Ankünfte am Wagenbahnhof, noch nicht abgearbeitet
  storage.crawls = storage.crawls or {}     -- laufendes Heranschieben
  storage.shunters = storage.shunters or {} -- Zug-ID → Rangierdepot (unit), taugliche Rangierloks
  storage.warned = storage.warned or {}     -- Zug-ID → schon gewarnt (fährt nur in eine Richtung)
  storage.stops = storage.stops or {}       -- unit → Haltestelle (LuaEntity) der Stationen dieses Mods
  storage.free = storage.free or {}         -- Zug-ID → Rangierdepot (unit), frei für einen Auftrag
  storage.tasks = storage.tasks or {}       -- Rangieraufträge ohne Lok: { group, to }
  storage.jobs = storage.jobs or {}         -- UTL-Auftrags-ID → Rangierauftrag
  storage.waiting = storage.waiting or {}   -- Wagenverbände, die auf „leer“/„voll“ warten
  storage.utl_stops = storage.utl_stops or {} -- unit → Haltestelle aller UTL-Stationen (Staffel-Signal)
  storage.homeward = storage.homeward or {}   -- Lok (unit_number) → Name des Heimatdepots nach einer Übergabe
  storage.relayed = storage.relayed or {}     -- Lieferungs-ID → Staffel-Halt schon eingefügt
  storage.parked = storage.parked or {}       -- Wagenbahnhof (unit) → dort abgestellter Verband
  storage.reserved = storage.reserved or {}   -- Wagenbahnhof (unit) → Rangierlok ist mit Wagen dorthin unterwegs
  storage.gated = storage.gated or {}         -- Wagenbahnhof (unit) → Zuglimit wird vom Mod gesteuert
end

local function role(name, extra)
  local spec = { mod = Const.MOD, name = name, caption = { "utl-coupling-yard.role-" .. name },
    tooltip = { "utl-coupling-yard.role-" .. name .. "-tooltip" } }
  for k, v in pairs(extra or {}) do spec[k] = v end
  local ok, why = remote.call("utl", "register_role", spec)
  if not ok then log("[UCY] Rolle " .. name .. " nicht angemeldet: " .. tostring(why)) end
end

--- Rollen und Fensterabschnitt (on_init, on_configuration_changed). Liefert false ohne passende UTL.
function Setup.register()
  if not Api.check() then return false end
  role("yard")
  role("depot", { base = "depot", own_trains = true })
  role("turn")
  remote.call("utl", "register_gui_section", { mod = Const.MOD, interface = Const.MOD, build = "section" })
  Registry.rebuild()
  return true
end

--- UTL-Ereignisse anmelden (on_init, on_load).
function Setup.listen()
  local utl = remote.interfaces["utl"]
  if not (utl and utl.api_version and utl.get_event_ids) then return end
  local ids = remote.call("utl", "get_event_ids") --[[@as table]]
  script.on_event(ids.on_station_created, Registry.update)
  script.on_event(ids.on_station_changed, Registry.update)
  script.on_event(ids.on_station_removed, Registry.remove)
  script.on_event(ids.on_train_arrived, function(event)
    if Shunter.arrived(event) then return end
    if Yard.arrived(event) then Worker.wake() end
  end)
  script.on_event(ids.on_job_finished, function(event) ---@param event table
    if event.mod ~= Const.MOD then return end
    Shunter.job_finished(event)
    Worker.wake()
  end)
  script.on_event(ids.on_train_idle, Depot.idle)
  script.on_event(ids.on_delivery_state_changed, Relay.state_changed)
  script.on_event(ids.on_delivery_completed, Relay.ended)
  script.on_event(ids.on_delivery_canceled, Relay.ended)
end

return Setup
