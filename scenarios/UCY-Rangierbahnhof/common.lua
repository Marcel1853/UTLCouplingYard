--- Kleine Helfer für das Szenario: Bauteile nur auf freie Plätze setzen, Stromreihe, Schilder.
local Common = {}

--- Bauteil setzen, wenn der Platz frei ist. Liefert das Bauteil oder nil.
function Common.place(surface, name, position, extra)
  local spec = { name = name, position = position, force = "player" }
  for k, v in pairs(extra or {}) do spec[k] = v end
  if not surface.can_place_entity(spec) then return nil end
  return surface.create_entity(spec)
end

--- Strom: Masten in Reihe `y` von x1 bis x2, am Anfang eine Stromquelle (Szenario, kein Kraftwerk).
function Common.power_row(surface, y, x1, x2)
  for x = x1, x2 + 6, 6 do Common.place(surface, "medium-electric-pole", { x + 0.5, y }) end
  for dx = 2, 6 do
    local eei = Common.place(surface, "electric-energy-interface", { x1 - dx, y })
    if eei then
      eei.power_production = 2000000
      eei.electric_buffer_size = 20000000
      return
    end
  end
end

-- Plätze rund um den Wunschort, nächste zuerst
local OFFSETS = {}
for r = 0, 5 do
  for dx = -r, r do
    for dy = -r, r do
      if math.max(math.abs(dx), math.abs(dy)) == r then OFFSETS[#OFFSETS + 1] = { dx, dy } end
    end
  end
end

--- Anzeigefeld mit Erklärtext (ucy-sign.<key>, in der Sprache jedes Spielers) neben der Haltestelle.
function Common.sign(stop, key)
  if not (stop and stop.valid) then return end
  local surface, p = stop.surface, stop.position
  for _, o in ipairs(OFFSETS) do
    local at = { p.x + o[1], p.y + o[2] - 3 }
    if surface.can_place_entity({ name = "display-panel", position = at, force = "player" }) then
      local panel = surface.create_entity({ name = "display-panel", position = at, force = "player" })
      if panel then
        panel.display_panel_icon = { type = "item", name = "utl-train-stop" }
        rendering.draw_text({ text = { "ucy-sign." .. key }, surface = surface, target = { at[1], at[2] - 0.6 },
          color = { 1, 1, 1 }, scale = 1.4, font = "default-bold", alignment = "center",
          vertical_alignment = "bottom", use_rich_text = true })
        return panel
      end
    end
  end
end

--- Gerade Strecke (Ost–West) von x1 bis x2 auf Höhe y.
function Common.rail(surface, y, x1, x2)
  for x = x1, x2, 2 do
    surface.create_entity({ name = "straight-rail", position = { x, y }, direction = defines.direction.east, force = "player" })
  end
end

--- Haltestelle an der Strecke y bei x: Richtung Osten (Süden der Strecke) oder Westen (Norden).
function Common.stop(surface, name, x, y, west, utl)
  local e = surface.create_entity({ name = utl == false and "train-stop" or "utl-train-stop",
    position = { x, y + (west and -2 or 2) }, direction = west and defines.direction.west or defines.direction.east,
    force = "player", raise_built = true }) --[[@as LuaEntity]]
  e.backer_name = name
  return e
end

--- Fahrzeug setzen (Loks mit Kohle).
function Common.stock(surface, name, x, y, west)
  local e = surface.create_entity({ name = name, position = { x, y },
    direction = west and defines.direction.west or defines.direction.east, force = "player" }) --[[@as LuaEntity]]
  if name == "locomotive" then e.insert({ name = "coal", count = 50 }) end
  return e
end

return Common
