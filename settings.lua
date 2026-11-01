-- Karteneinstellungen.
data:extend({
  -- Am Wagenbahnhof im Schritttempo an die wartenden Wagen heranfahren. Aus (Vorgabe): Die Haltestelle steht so,
  -- dass der Zug direkt an den Wagen hält, und kuppelt sofort.
  { type = "bool-setting", name = "ucy-crawl", setting_type = "runtime-global", default_value = false, order = "a" },
  -- Betriebsart „Wagen von hinten anstellen“: Ein Zug wartet, die Rangierlok schiebt Wagen an sein Ende.
  { type = "bool-setting", name = "ucy-attach", setting_type = "runtime-global", default_value = true, order = "b" },
  -- „Wagen je Rangierfahrt“ und „an vorhandene Wagen anhängen“ (Wagenreihen, z. B. für Direkt-Beladung).
  { type = "bool-setting", name = "ucy-partial", setting_type = "runtime-global", default_value = true, order = "c" },
})
