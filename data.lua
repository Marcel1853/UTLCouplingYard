-- Signal „Staffel“: an der Haltestelle einer Abnehmer- oder Anbieter-Station mit Wert N → Lieferungen
-- laufen über den Wagenbahnhof mit Staffel-Nummer N (Wagen werden dort an den nächsten Zug übergeben).
data:extend({ {
  type = "virtual-signal",
  name = "ucy-relay",
  icons = {
    { icon = "__base__/graphics/icons/cargo-wagon.png", icon_size = 64 },
    { icon = "__base__/graphics/icons/signal/signal_1.png", icon_size = 64, scale = 0.25, shift = { 8, 8 } },
  },
  subgroup = "virtual-signal",
  order = "z[ucy-relay]",
} })
