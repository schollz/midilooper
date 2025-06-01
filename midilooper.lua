-- midi looper
looper_ = include("lib/looper")

global_shift = false
global_num_loops = 4
global_loops = {}

function init()
  print("midilooper init")

  local midi_names = {}
  local midi_device = {}
  table.insert(midi_names, "None")
  for i = 1, #midi.vports do
    table.insert(midi_names, midi.vports[i].name)
    midi_device[i] = midi.connect(i)
  end

  -- global parameters
  params:add_number("selected_loop", "Selected Loop", 1, global_num_loops, 1)
  params:add_option("looper_midi_in_device", "MIDI In", midi_names, 2)
  params:add_number("looper_midi_in_channel", "MIDI In Channel", 1, 16, 1)

  for i = 1, global_num_loops do global_loops[i] = looper_:new({id=i, midi_names=midi_names, midi_device=midi_device}) end
  params:bang()

  -- connect to all midi devices
  for i = 1, #midi_device do
    midi_device[i].event = function(data)
      if i ~= params:get("looper_midi_in_device") - 1 then do return end end
      local d = midi.to_msg(data)
      if d.ch ~= params:get("looper_midi_in_channel") then do return end end
      if d.type == "clock" then
        return
      elseif d.type == "note_on" then
        global_loops[params:get("selected_loop")]:record_note_on(d.ch, d.note, d.vel)
      elseif d.type == "note_off" then
        global_loops[params:get("selected_loop")]:record_note_off(d.ch, d.note)
      end
    end
  end

  clock.run(function()
    while true do
      redraw()
      clock.sleep(1 / 60)
    end
  end)

  clock.run(function()
    while true do
      clock.sync(1 / 32)
      for i = 1, global_num_loops do global_loops[i]:emit() end
    end
  end)
end

function key(k, v)
  if k == 1 then
    global_shift = v == 1
  else
    global_loops[params:get("selected_loop")]:key(k, v, global_shift)
    -- elseif v == 1 then
    --   local current_loop_new = params:get("selected_loop") + (k == 3 and 1 or -1)
    --   if current_loop_new < 1 then
    --     current_loop_new = global_num_loops
    --   elseif current_loop_new > global_num_loops then
    --     current_loop_new = 1
    --   end
    --   params:get("selected_loop") = current_loop_new
  end
end

function enc(k, d)
  if global_shift then
    if k == 1 then
      -- change the global tempo
      print(params:get("clock_tempo"), d)
      params:delta("clock_tempo", d)
    else
      global_loops[params:get("selected_loop")]:enc(k, d)
    end
  else
  end
end

function redraw()
  screen.clear()

  global_loops[params:get("selected_loop")]:redraw(global_shift)

  screen.update()
end
