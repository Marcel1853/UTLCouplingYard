--- Prüft, ob UTL die Add-on-Schnittstelle in der nötigen Fassung hat (remote.call("utl", "api_version")).
local Api = {}

Api.MOD = "UTLCouplingYard"
Api.NEEDED = 1

function Api.check()
  local utl = remote.interfaces["utl"]
  if not (utl and utl.api_version) then
    log("[UTLCouplingYard] UTL ohne Add-on-Schnittstelle – mindestens UTLogistics 0.0.20 nötig.")
    return false
  end
  ---@diagnostic disable-next-line: param-type-mismatch
  local level = remote.call("utl", "api_version") --[[@as integer]]
  if level < Api.NEEDED then
    log("[UTLCouplingYard] UTL-Schnittstelle Stufe " .. level .. ", gebraucht " .. Api.NEEDED .. ".")
    return false
  end
  return true
end

return Api
