local Looper = {}

function Looper:new(args)
    local m = setmetatable({}, {
        __index = Looper
    })
    local args = args == nil and {} or args
    for k, v in pairs(args) do
        m[k] = v
    end
    m:init()
    return m
end


function Looper:init()
    self.loops = {}
    self.currentLoop = nil
    self.beats = 16
    params:add_group("looper_" .. self.id, "Looper " .. self.id, 1)
    params:add_number("looper_" .. self.id .. "_beats", "Beats", 1, 64,16)
end


function Looper:enc(k,d)
    if k==1 then 
        params:delta("looper_" .. self.id .. "_beats", d)
    end
end

function Looper:redraw()
    screen.move(1,15)
    screen.text("Looper " .. self.id)
    screen.move(1,25)
    screen.text("Beats: " .. params:get("looper_" .. self.id .. "_beats"))
end


return Looper