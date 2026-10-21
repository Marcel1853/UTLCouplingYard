-- UTL Coupling Yard: An- und Abkuppeln für Unified Train Logistics (Add-on über die UTL-Schnittstelle).
-- Noch ein Grundgerüst – Plan und Schnittstelle stehen in docs/PLAN.md und docs/API.md.
local Api = require("scripts.api")

script.on_init(Api.check)
script.on_configuration_changed(Api.check)
