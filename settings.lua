-- Karteneinstellung: Am Wagenbahnhof im Schritttempo an die wartenden Wagen heranfahren. Aus (Vorgabe): Die
-- Haltestelle steht so, dass der Zug direkt an den Wagen hält, und kuppelt sofort.
data:extend({ {
  type = "bool-setting",
  name = "ucy-crawl",
  setting_type = "runtime-global",
  default_value = false,
  order = "a",
} })
