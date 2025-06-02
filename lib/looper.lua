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
  if params:get("looper_" .. self.id .. "_recording_enable") == 2 then
    -- add to the record queue
    print("record_note_on", ch, note, velocity)
    self.record_queue[note] = {ch=ch, note=note, velocity=velocity, beat_start=clock.get_beats()}
    self.beat_last_recorded = clock.get_beats()
    -- find any notes in the loop that are within 0.25 beats of the current beat:

    local current_beat_mod = clock.get_beats() % self.total_beats
    local notes_to_delete = {}
    for i = 1, #self.loop do
      local note_data = self.loop[i]  
      local note_start_beat = note_data.beat_start % self.total_beats
      if math.abs(note_start_beat - current_beat_mod) < 0.25 and note_data.times_played > 1 then 
        -- remove this note from the loop
        print("removing note", note_data.note, "from loop, beat_start:", note_data.beat_start, "current beat:",
              clock.get_beats())
        table.insert(notes_to_delete, i)
      end
    end

  if #notes_to_delete>0 then 
    local new_loop = {}
    for i = 1, #self.loop do
      if not self:table_contains(notes_to_delete, i) then table.insert(new_loop, self.loop[i]) end
    end
    self.loop = new_loop
  end

  end

end

function Looper:record_note_off(ch, note)
  if params:get("looper_" .. self.id .. "_recording_enable") == 2 then
    -- find the note in the record queue and add it to the loop
    if self.record_queue[note] then
      print("recording note off for", note, "at", clock.get_beats())
      table.insert(self.loop, {
        ch=self.record_queue[note].ch,
        note=self.record_queue[note].note,
        velocity=self.record_queue[note].velocity,
        beat_start=self.record_queue[note].beat_start,
        beat_end=clock.get_beats(),
        times_played=0,
      })
      -- remove the note from the record queue
      self.record_queue[note] = nil
    end
  end
end

function Looper:clear_loop()
  -- turn off every note in playing_notes 
  for note, _ in pairs(self.playing_notes) do self:note_off(note) end
  self.loop = {}
  self.record_queue = {}
end

function Looper:table_contains(tbl, i)
  for j = 1, #tbl do if tbl[j] == i then return true end end
  return false
end

function Looper:note_on(note, velocity)
  if params:get("looper_" .. self.id .. "_playback_enable") == 1 then return end

  self.midi_device[params:get("looper_" .. self.id .. "_midi_device") - 1]:note_on(note, velocity, params:get(
                                                                                       "looper_" .. self.id ..
                                                                                           "_midi_channel_out"))
  self.playing_notes[note] = true
end

function Looper:note_off(note)
  if params:get("looper_" .. self.id .. "_midi_device") == 1 then return end
  self.midi_device[params:get("looper_" .. self.id .. "_midi_device") - 1]:note_off(note, 0, params:get(
                                                                                        "looper_" .. self.id ..
                                                                                            "_midi_channel_out"))
  self.playing_notes[note] = nil
end

function Looper:beat_in_range(beat, beat_before, beat_after, total_beats)
  if beat_after < beat_before then
    return (beat >= beat_before and beat <= total_beats) or (beat >= 0 and beat <= beat_after)
  else
    return beat >= beat_before and beat <= beat_after
  end
end

function Looper:emit()
  self.beat_current = clock.get_beats()
  local beat_after = self.beat_current % self.total_beats
  local beat_before = self.beat_last % self.total_beats
  local notes_to_erase = {}
  for i = 1, #self.loop do
    local note_data = self.loop[i]
    local note_start_beat = note_data.beat_start % self.total_beats
    local note_end_beat = note_data.beat_end % self.total_beats
    -- check if a note starting
    if self:beat_in_range(note_start_beat, beat_before, beat_after, self.total_beats) then
      if next(self.record_queue) ~= nil or self.beat_current - self.beat_last_recorded < 0.25 then
        -- erase this  note
        table.insert(notes_to_erase, i)
        print("queuing note to remove: ", note_data.note, "from loop")
      else
        -- print("emit note_on", note_data.ch, note_data.note, note_data.velocity)
        self:note_on(note_data.note, note_data.velocity)
        self.loop[i].times_played = self.loop[i].times_played + 1
      end
    end
    -- check if a note is ending
    if self:beat_in_range(note_end_beat, beat_before, beat_after, self.total_beats) then
      -- print("emit note_off", note_data.ch, note_data.note)
      self:note_off(note_data.note)
    end
  end

  if #notes_to_erase > 0 then
    local new_loop = {}
    for i = 1, #self.loop do
      if not self:table_contains(notes_to_erase, i) then table.insert(new_loop, self.loop[i]) end
    end
    self.loop = new_loop
  end

  if self.erase_start ~= nil then
    if self.beat_current - self.erase_start > 2.0 then
      -- erase the loop
      print("erasing loop")
      self:clear_loop()
      self.erase_start = nil
    end

  end

  self.beat_last = self.beat_current
end

function Looper:init()
  self.loop = {}
  self.currentLoop = nil
  self.total_beats = 16
  self.erase_start = nil
  self.record_queue = {}
  self.beat_current = clock.get_beats()
  self.beat_last = clock.get_beats()
  self.beat_last_recorded = clock.get_beats()
  self.playing_notes = {}
  self.do_quantize = false
  params:add_group("looper_" .. self.id, "Looper " .. self.id, 7)
  -- midi channelt to record on 
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
  params:add_option("looper_" .. self.id .. "_recording_enable", "Recording", {"Disabled", "Enabled"}, 1)
  params:set_action("looper_" .. self.id .. "_recording_enable", function(value)
    self.record_queue = {}
  end)
  params:add_option("looper_" .. self.id .. "_playback_enable", "Playback", {"Disabled", "Enabled"}, 1)
  params:add_option("looper_" .. self.id .. "_quantize", "Quantization", {"1/32", "1/16", "1/8", "1/4"}, 1)
end

function Looper:key(k, v, shift)
  if shift then
    if k == 2 then
      if v == 1 then
        self.erase_start = clock.get_beats()
      else
        self.erase_start = nil
      end
    elseif k == 3 then
      self.do_quantize = v == 1
      -- quantize
      local quantas = {8, 4, 2, 1}
      local quanta = quantas[params:get("looper_" .. self.id .. "_quantize")]
      for i = 1, #self.loop do
        self.loop[i].beat_start = util.round(self.loop[i].beat_start * quanta) / quanta
        self.loop[i].beat_end = util.round(self.loop[i].beat_end * quanta) / quanta
        if self.loop[i].beat_end <= self.loop[i].beat_start then
          self.loop[i].beat_end = self.loop[i].beat_start + 1 / quanta
        end
      end
    end
  else
    if k == 2 and v == 1 then
      -- toggle recording 
      params:set("looper_" .. self.id .. "_recording_enable",
                 3 - params:get("looper_" .. self.id .. "_recording_enable"))
    elseif k == 3 and v == 1 then
      -- toggle playback
      params:set("looper_" .. self.id .. "_playback_enable", 3 - params:get("looper_" .. self.id .. "_playback_enable"))
    end
  end
end

function Looper:enc(k, d)
  if k == 2 then params:delta("looper_" .. self.id .. "_beats", d) end
  if k == 3 then params:delta("looper_" .. self.id .. "_bars", d) end
end

function Looper:redraw(shift)
  screen.move(1, 5)
  screen.text(string.format("loop %d, %d/%d", self.id, 1 + math.floor(clock.get_beats() % self.total_beats),
                            self.total_beats))

  local x = util.round(128 * (clock.get_beats() % self.total_beats) / self.total_beats)
  -- draw a line for the current beat:
  screen.level(3)
  screen.rect(x, 8, 1, 48)
  screen.fill()
  -- -- draw a dot
  -- screen.level(3)
  -- screen.rect(0, 8, x, 2)
  -- screen.fill()
  -- screen.move(x, 11)
  -- screen.text("o")
  -- screen.level(15)

  screen.move(x, 55)
  -- plot recorded beats
  screen.blend_mode(2)
  for i = 1, #self.loop do
    local note_data = self.loop[i]
    local y_pos = util.round(util.linlin(16, 90, 64, 10, note_data.note))
    local note_start_beat = note_data.beat_start % self.total_beats
    local note_end_beat = note_data.beat_end % self.total_beats
    local start_x = util.round(128 * note_start_beat / self.total_beats)
    local end_x = util.round(128 * note_end_beat / self.total_beats)
    screen.level(5)
    screen.rect(start_x, y_pos - 2, 3, 3)
    screen.fill()
    screen.rect(end_x, y_pos - 1, 1, 1)
    screen.fill()
    screen.level(1)
    screen.move(start_x, y_pos)
    if end_x > start_x then
      screen.line(end_x, y_pos)
    else
      screen.line(128, y_pos)
      screen.move(0, y_pos)
      screen.line(end_x, y_pos)
    end
    screen.stroke()
    screen.level(15)
  end

  -- plot starts in the queue
  for note, data in pairs(self.record_queue) do
    local note_start_beat = data.beat_start % self.total_beats
    local y_pos = util.round(util.linlin(16, 90, 64, 10, note))
    local start_x = util.round(128 * note_start_beat / self.total_beats)
    screen.rect(start_x, y_pos - 2, 3, 3)
    screen.fill()
  end
  screen.blend_mode(0)

  if not shift then
    if params:get("looper_" .. self.id .. "_recording_enable") == 2 then
      screen.level(15)
      screen.rect(0, 56, 15, 10)
      screen.fill()
      screen.level(0)
    else
      screen.level(10)
    end
    screen.move(1, 62)
    screen.text("rec")
    screen.level(15)

    if params:get("looper_" .. self.id .. "_playback_enable") == 2 then
      screen.level(15)
      screen.rect(20, 56, 18, 10)
      screen.fill()
      screen.level(0)
    else
      screen.level(10)
    end
    screen.move(21, 62)
    screen.text("play")
    screen.level(15)

  else
    screen.level(15)
    screen.move(1, 62)
    screen.text("erase")
    screen.blend_mode(1)
    if self.erase_start then
      local erase_x = util.round(25 * (clock.get_beats() - self.erase_start) / 2.0)
      screen.rect(0, 56, erase_x, 8)
      screen.fill()
    end
    screen.blend_mode(0)

    if self.do_quantize then
      screen.level(15)
      screen.rect(26, 56, 38, 10)
      screen.fill()
      screen.level(0)
    else
      screen.level(10)
    end
    screen.move(27, 62)
    screen.text("quantize")
    screen.level(15)

  end
end

return Looper
