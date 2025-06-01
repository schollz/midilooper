local Looper = {}

function Looper:new(args)
  local m = setmetatable({}, {__index=Looper})
  local args = args == nil and {} or args
  for k, v in pairs(args) do m[k] = v end
  m:init()
  return m
end

function Looper:queue_clean()
  -- remove any notes that have beat_start > total beats
  notes_to_remove = {}
  for note, data in pairs(self.record_queue) do
    if clock.get_beats() - data.beat_start > self.total_beats * 8 then
      notes_to_remove[note] = true
      print("removing note", note, "from record queue, beat_start:", data.beat_start, "current beat:", clock.get_beats())
    end
  end
  for note, _ in pairs(notes_to_remove) do self.record_queue[note] = nil end
end

function Looper:record_note_on(ch, note, velocity)
  print("record_note_on", ch, note, velocity)
  if ch ~= params:get("looper_" .. self.id .. "_midi_channel") then return end
  self:queue_clean()
  -- add to the record queue
  self.record_queue[note] = {ch=ch, note=note, velocity=velocity, beat_start=clock.get_beats()}
  print("note_on", ch, note, velocity, "at", self.record_queue[note].beat_start)
end

function Looper:record_note_off(ch, note)
  if ch ~= params:get("looper_" .. self.id .. "_midi_channel") then return end
  self:queue_clean()
  -- find the note in the record queue and add it to the loop
  if self.record_queue[note] then
    print("recording note off for", note, "at", clock.get_beats())
    table.insert(self.loop, {
      ch=self.record_queue[note].ch,
      note=self.record_queue[note].note,
      velocity=self.record_queue[note].velocity,
      beat_start=self.record_queue[note].beat_start,
      beat_end=clock.get_beats()
    })
    -- remove the note from the record queue
    self.record_queue[note] = nil
    self.beat_last_recorded = clock.get_beats()
  end
end

function Looper:clear_loop()
  self.loop = {}
  self.record_queue = {}
end

function Looper:table_contains(tbl, i)
  for j = 1, #tbl do if tbl[j] == i then return true end end
  return false
end

function Looper:note_on(ch, note, velocity)
  if params:get("looper_" .. self.id .. "_midi_device") == 1 then return end
  self.midi_device[params:get("looper_" .. self.id .. "_midi_device") - 1]:note_on(note, velocity, params:get(
                                                                                       "looper_" .. self.id ..
                                                                                           "_midi_channel_out"))
end

function Looper:note_off(ch, note)
  if params:get("looper_" .. self.id .. "_midi_device") == 1 then return end
  self.midi_device[params:get("looper_" .. self.id .. "_midi_device") - 1]:note_off(note, 0, params:get(
                                                                                        "looper_" .. self.id ..
                                                                                            "_midi_channel_out"))
end

function Looper:emit()
  self.beat_current = clock.get_beats()
  local current_beat = self.beat_current % self.total_beats
  local last_beat = self.beat_last % self.total_beats
  if current_beat < last_beat then current_beat = current_beat + self.total_beats end
  local notes_to_erase = {}
  for i = 1, #self.loop do
    local note_data = self.loop[i]
    local note_start_beat = note_data.beat_start % self.total_beats
    local note_end_beat = note_data.beat_end % self.total_beats
    if note_start_beat >= last_beat and note_start_beat <= current_beat then
      -- check if anything is in the queue
      if next(self.record_queue) ~= nil or self.beat_current - self.beat_last_recorded < 0.125 then
        -- erase this  note
        table.insert(notes_to_erase, i)
        print("queuing note to remove: ", note_data.note, "from loop")
      else
        -- note is starting in this beat
        print("emit note_on", note_data.ch, note_data.note, note_data.velocity)
        self:note_on(note_data.ch, note_data.note, note_data.velocity)
      end
    end
    if note_end_beat >= last_beat and note_end_beat <= current_beat then
      -- note is ending in this beat
      print("emit note_off", note_data.ch, note_data.note)
      self:note_off(note_data.ch, note_data.note)
    end
  end

  if #notes_to_erase > 0 then
    local new_loop = {}
    for i = 1, #self.loop do
      if not self:table_contains(notes_to_erase, i) then table.insert(new_loop, self.loop[i]) end
    end
    self.loop = new_loop
  end

  self.beat_last = self.beat_current
end

function Looper:init()
  self.loop = {}
  self.currentLoop = nil
  self.total_beats = 16
  self.record_queue = {}
  self.beat_current = clock.get_beats()
  self.beat_last = clock.get_beats()
  self.beat_last_recorded = clock.get_beats()
  params:add_group("looper_" .. self.id, "Looper " .. self.id, 5)
  -- midi channelt to record on 
  params:add_number("looper_" .. self.id .. "_midi_channel", "MIDI IN Channel", 1, 16, 1)
  params:add_number("looper_" .. self.id .. "_beats", "Beats", 1, 64, 4)
  params:set_action("looper_" .. self.id .. "_beats", function(value)
    self.total_beats = value * params:get("looper_" .. self.id .. "_bars")
  end)
  params:add_number("looper_" .. self.id .. "_bars", "Bars", 1, 16, 1)
  params:set_action("looper_" .. self.id .. "_bars", function(value)
    self.total_beats = value * params:get("looper_" .. self.id .. "_beats")
  end)
  params:add_option("looper_" .. self.id .. "_midi_device", "MIDI Out", self.midi_names, 2)
  params:add_number("looper_" .. self.id .. "_midi_channel_out", "MIDI Out Channel", 1, 16, 1)

end

function Looper:key(k, v)
  if k == 3 then
    -- quantize
    print("quantizing")
    for i = 1, #self.loop do
      self.loop[i].beat_start = util.round(self.loop[i].beat_start * 16) / 16
      self.loop[i].beat_end = util.round(self.loop[i].beat_end * 16) / 16
    end
  end
end

function Looper:enc(k, d)
  if k == 2 then params:delta("looper_" .. self.id .. "_beats", d) end
  if k == 3 then params:delta("looper_" .. self.id .. "_bars", d) end
end

function Looper:redraw()
  screen.move(1, 5)
  screen.text(string.format("loop %d, %d/%d", self.id, 1 + math.floor(clock.get_beats() % self.total_beats),
                            self.total_beats))
  screen.move(1, 12)
  screen.text(string.format("beats %d, bars %d", params:get("looper_" .. self.id .. "_beats"),
                            params:get("looper_" .. self.id .. "_bars")))

  local x = util.round(128 * (clock.get_beats() % self.total_beats) / self.total_beats)
  -- draw a dot
  screen.move(x, 45)
  screen.text("x")
  screen.move(x, 55)
  -- plot recorded beats
  for i = 1, #self.loop do
    local note_data = self.loop[i]
    local y_pos = util.round(util.linlin(16, 90, 64, 24, note_data.note))
    local note_start_beat = note_data.beat_start % self.total_beats
    local note_end_beat = note_data.beat_end % self.total_beats
    local start_x = util.round(128 * note_start_beat / self.total_beats)
    local end_x = util.round(128 * note_end_beat / self.total_beats)
    screen.move(start_x, y_pos)
    screen.text("o")
    screen.move(end_x, y_pos)
    screen.text("x")
  end
  -- plot starts in the queue
  for note, data in pairs(self.record_queue) do
    local note_start_beat = data.beat_start % self.total_beats
    local y_pos = util.round(util.linlin(16, 90, 64, 24, note))
    local start_x = util.round(128 * note_start_beat / self.total_beats)
    screen.move(start_x, y_pos)
    screen.text("o")
  end

end

return Looper
