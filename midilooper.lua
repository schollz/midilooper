-- midi looper
looper_ = include("lib/looper")

global_shift = false
global_num_loops = 4
global_loops = {}
global_current_loop = 1

function init()
  print("midilooper init")

  for i = 1, global_num_loops do global_loops[i] = looper_:new({id=i}) end
  params:bang()

  -- connect to all midi devices
  local midi_device = {}
  for i = 1, #midi.vports do
    local name = midi.vports[i].name
    midi_device[i] = midi.connect(i)
    midi_device[i].event = function(data)
      local d = midi.to_msg(data)
      if d.type == "clock" then
        return
      elseif d.type == "note_on" then
        global_loops[global_current_loop]:record_note_on(d.ch, d.note, d.vel)
      elseif d.type == "note_off" then
        global_loops[global_current_loop]:record_note_off(d.ch, d.note)
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
  elseif global_shift then
    global_loops[global_current_loop]:key(k, v)
  elseif v == 1 then
    local current_loop_new = global_current_loop + (k == 3 and 1 or -1)
    if current_loop_new < 1 then
      current_loop_new = global_num_loops
    elseif current_loop_new > global_num_loops then
      current_loop_new = 1
    end
    global_current_loop = current_loop_new
  end
end

function enc(k, d)
  if global_shift then
    if k == 1 then
      -- change the global tempo
      print(params:get("clock_tempo"), d)
      params:delta("clock_tempo", d)
    else
      global_loops[global_current_loop]:enc(k, d)
    end
  else
  end
end

function redraw()
  screen.clear()
  screen.move(128, 5)
  screen.text_right(string.format("bpm %d", params:get("clock_tempo")))

  global_loops[global_current_loop]:redraw()

  screen.update()
end
