-- UTL Coupling Yard: An- und Abkuppeln für Unified Train Logistics (Add-on über die UTL-Schnittstelle).
-- Plan und Schnittstelle stehen in docs/PLAN.md und docs/API.md.
local Const = require("scripts.core.const")
local Setup = require("scripts.core.setup")
local Worker = require("scripts.yard.worker")
local Groups = require("scripts.shunting.groups")
local Section = require("scripts.gui.section")

-- Rückrufe für UTL (Abschnitt im Stationsfenster) und Abfragen für andere Mods
remote.add_interface(Const.MOD, {
  section = Section.build,
  --- Taugliche Rangierloks: Zug-ID → Rangierdepot (unit). Kopie.
  get_shunters = function()
    local copy = {}
    for id, unit in pairs(storage.shunters) do copy[id] = unit end
    return copy
  end,
})

script.on_init(function()
  Setup.storage()
  Setup.register()
  Setup.listen()
end)

script.on_configuration_changed(function()
  Setup.storage()
  Setup.register()
end)

script.on_load(function()
  Setup.listen()
  Worker.resume()
  Groups.resume()
end)

script.on_event(defines.events.on_gui_selection_state_changed, Section.changed)
script.on_event(defines.events.on_gui_text_changed, Section.text)
