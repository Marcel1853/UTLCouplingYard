-- UTL Coupling Yard: An- und Abkuppeln für Unified Train Logistics (Add-on über die UTL-Schnittstelle).
-- Plan und Schnittstelle stehen in docs/PLAN.md und docs/API.md.
local Const = require("scripts.core.const")
local Setup = require("scripts.core.setup")
local Worker = require("scripts.yard.worker")
local Groups = require("scripts.shunting.groups")
local Section = require("scripts.gui.section")
local Gate = require("scripts.yard.gate")

Section.on_gate = Gate.update

-- Rückrufe für UTL (Abschnitt im Stationsfenster) und Abfragen für andere Mods
remote.add_interface(Const.MOD, {
  section = Section.build,
  --- Wagen erfassen, die schon an Wagenbahnhöfen stehen (z. B. nach dem Bau aus einer Blaupause), und
  --- gesperrte Halte neu bewerten. Liefert die Zahl neuer Wagenverbände.
  scan = function()
    local count = Groups.scan_all()
    Gate.refresh()
    return count
  end,
  --- Taugliche Rangierloks: Zug-ID → Rangierdepot (unit). Kopie.
  get_shunters = function()
    local copy = {}
    for id, unit in pairs(storage.shunters) do copy[id] = unit end
    return copy
  end,
  --- Karteneinstellung „Heranfahren“ setzen (z. B. aus einem Szenario – das darf Mod-Einstellungen nicht selbst
  --- ändern).
  crawl = function(on)
    settings.global["ucy-crawl"] = { value = on == true }
  end,
})

script.on_init(function()
  Setup.storage()
  if Setup.register() then
    Groups.scan_all()
    Gate.refresh()
  end
  Setup.listen()
end)

script.on_configuration_changed(function()
  Setup.storage()
  if Setup.register() then Gate.refresh() end
end)

script.on_load(function()
  Setup.listen()
  Worker.resume()
  Groups.resume()
  Gate.resume()
end)

script.on_event(defines.events.on_gui_selection_state_changed, Section.changed)
script.on_event(defines.events.on_gui_text_changed, Section.text)
script.on_event(defines.events.on_gui_checked_state_changed, Section.checked)

-- Wagen gebaut oder entfernt: gesperrte Halte neu bewerten (nur wenn es welche gibt)
local STOCK = { { filter = "rolling-stock" } }
for _, id in pairs({ defines.events.on_built_entity, defines.events.on_robot_built_entity,
  defines.events.script_raised_built, defines.events.script_raised_revive, defines.events.on_entity_died,
  defines.events.on_player_mined_entity, defines.events.on_robot_mined_entity, defines.events.script_raised_destroy }) do
  script.on_event(id, Gate.soon, STOCK)
end
