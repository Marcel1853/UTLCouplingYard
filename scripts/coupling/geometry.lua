--- Richtungen am Zug: welches Ende an der Haltestelle steht (Kopf), wohin der Zug weiterfährt und in
--- welche rail_direction ein Wagen nach außen zeigt. Fahrtrichtung = Richtung der Haltestelle.
local Geometry = {}

--- Einheitsvektor einer Orientierung (0 = Norden, 0,25 = Osten).
local function vector(orientation)
  local a = orientation * 2 * math.pi
  return math.sin(a), -math.cos(a)
end

--- Fahrtrichtung an einer Haltestelle als Vektor (Züge halten dort in Richtung der Haltestelle).
function Geometry.forward(stop)
  return vector(stop.orientation)
end

--- Zeigt der Wagen in Fahrtrichtung (fx, fy)?
function Geometry.faces(stock, fx, fy)
  local x, y = vector(stock.orientation)
  return x * fx + y * fy > 0
end

--- Kopf (Ende an der Haltestelle) und Schluss eines Zuges.
function Geometry.ends(train, stop)
  local front, back = train.front_stock, train.back_stock
  if not (front and back) then return nil, nil end
  local p = stop.position
  local function d(e) return (e.position.x - p.x) ^ 2 + (e.position.y - p.y) ^ 2 end
  if d(front) <= d(back) then return front, back end
  return back, front
end

--- rail_direction, in die `stock` in Fahrtrichtung (fx, fy) zeigt.
function Geometry.ahead(stock, fx, fy)
  return Geometry.faces(stock, fx, fy) and defines.rail_direction.front or defines.rail_direction.back
end

--- Geschwindigkeit mit Vorzeichen, damit der Zug in Fahrtrichtung fährt (positiv = Richtung front_stock).
function Geometry.speed_towards_head(train, head, speed)
  return train.front_stock == head and speed or -speed
end

--- Abstand von `a` nach `b` entlang der Fahrtrichtung.
function Geometry.along(a, b, fx, fy)
  return (b.x - a.x) * fx + (b.y - a.y) * fy
end

return Geometry
