--- Fahrplan sichern und wiederherstellen. Kuppeln zwei Züge mit Loks zusammen (Wagen an einen wartenden Zug
--- anstellen), behält Factorio nur einen Fahrplan – nach dem Trennen bekommt jeder Teil seinen eigenen zurück.
local Schedule = {}

function Schedule.save(train)
  if train.group and train.group ~= "" then return { group = train.group } end
  local schedule = train.get_schedule()
  return { records = schedule.get_records() or {}, interrupts = schedule.get_interrupts() or {} }
end

function Schedule.restore(train, saved)
  if not (saved and train and train.valid) then return end
  if saved.group then
    train.group = saved.group
    return
  end
  local schedule = train.get_schedule()
  schedule.set_records(saved.records)
  schedule.set_interrupts(saved.interrupts)
end

return Schedule
