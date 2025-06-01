-- midi looper

looper_ = include("lib/looper")

global_shift = false
global_num_loops = 4
global_loops = {}
global_current_loop = 1

function init()
    print("midilooper init")


    for i=1, global_num_loops do
        global_loops[i] = looper_:new({id=i})
    end


    clock.run(function()
        while true do 
            redraw()
            clock.sleep(1/30)
        end
    end)
end

function key(k,v)
    if k==1 then 
        global_shift = v==1
    end
end

function enc(k,d)
    if global_shift then 
        if k==1 then 
            -- change the global tempo
            print(params:get("clock_tempo"),d)
            params:delta("clock_tempo",d)
        end
    else
        global_loops[global_current_loop]:enc(k,d)
    end
end

function redraw()
    screen.clear()
    screen.move(64, 32)
    screen.text("midilooper")

    screen.move(1,5)
    screen.text("bpm " .. math.floor(clock.get_tempo()))


    global_loops[global_current_loop]:redraw()

    screen.update()
end