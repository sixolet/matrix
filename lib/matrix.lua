local number = require 'core/params/number'
local control = require 'core/params/control'
local taper = require 'core/params/taper'
local binary = require 'core/params/binary'

local ModMatrix = {
    tBINARY = 1,
    tUNIPOLAR = 2,
    tBIPOLAR = 3,
    matrix = {}, -- modulation -> param -> depth
    bangers = {{}, {}, {}, {}},
    sources_list = {}, -- List of mod sources
    sources_indexes = {}, -- mod sources by index
    post_init_hooks = {}, -- functions to call after init
}

function ModMatrix:install()
    -- Only install once
    if self.installed then return end
    
    self.global_raw = false
    local outer_self = self
    
    function binary:get()
        if self.modulation == nil or outer_self.global_raw then
            return self.value
        end
        if self.value > 0 then return self.value end
        for _, v in pairs(self.modulation) do
            if v > 0 then return 1 end
        end
        return 0
    end
    
    function number:get(raw)
        if self.modulation == nil or raw == true or outer_self.global_raw then
            return self.value
        end
        local val = self.value
        for _, v in pairs(self.modulation) do
            val = val + (v*self.range)
        end
        val = util.round(val, 1)
        if self.wrap then
            val = util.wrap(val, self.min, self.max)
        else
            val = util.clamp(val, self.min, self.max)
        end
        return val
    end

    function number:bang()
        self.action(self:get())
    end
    
    function number:delta(d)
        self:set(self:get(true) + d)
    end

    function taper:get_modulated_raw()
        if self.modulation == nil then
            return self.value
        else
            local val = self.value
            for _, v in pairs(self.modulation) do
                val = val + v
            end
            if controlspec.wrap then
                val = val % 1
            else
                val = util.clamp(val, 0, 1)
            end
            return val
        end
    end

    function taper:get(raw)
        if raw == true or outer_self.global_raw then
            return self:map_value(self.value)
        end
        return self:map_value(self:get_modulated_raw())
    end

    function control:get_modulated_raw()
        if self.modulation == nil then
            return self.raw
        else
            local val = self.raw
            for _, v in pairs(self.modulation) do
                val = val + v
            end
            if controlspec.wrap then
                val = val % 1
            else
                val = util.clamp(val, 0, 1)
            end
            return val
        end
    end

    function control:get(unmodded)
        if unmodded == true or outer_self.global_raw then
            return self:map_value(self.raw)
        end
        return self:map_value(self:get_modulated_raw())
    end

    function params:get_unmodded(p)
        return self:lookup_param(p):get(true)
    end
    
    -- Since a script might use the official write callback, we
    -- are wrapping the write function instead. Ugly, I know.
    local old_write = params.write
    function params:write(filename, name)
      local old_global_raw = outer_self.global_raw
      outer_self.global_raw = true        
      outer_self.pset_filename = filename or 1
      local pset_number;
      if type(outer_self.pset_filename) == "number" then
        local n = outer_self.pset_filename
        outer_self.pset_filename = norns.state.data .. norns.state.shortname
        pset_number = string.format("%02d",n)
        outer_self.pset_filename = outer_self.pset_filename .. "-" .. pset_number .. ".pset"
      end
      outer_self.matrix_filename = outer_self.pset_filename .. ".matrix"
      local err = tab.save(outer_self.matrix, outer_self.matrix_filename)
      if err then
        print("Failed to save matrix data", err)
      end
      old_write(self, filename, name)
      outer_self.global_raw = old_global_raw
    end
    
    local old_read = params.read
    function params:read(filename, silent)
      outer_self.pset_filename = filename or norns.state.pset_last
      local pset_number;
      if type(outer_self.pset_filename) == "number" then
        local n = outer_self.pset_filename
        outer_self.pset_filename = norns.state.data .. norns.state.shortname
        pset_number = string.format("%02d",n)
        outer_self.pset_filename = outer_self.pset_filename .. "-" .. pset_number .. ".pset"
      end
      outer_self.matrix_filename = outer_self.pset_filename .. ".matrix"
      print("loading matrix from", outer_self.matrix_filename)
      outer_self.matrix, err = tab.load(outer_self.matrix_filename)
      if err then
        outer_self.matrix = {}
        print("Error reading matrix data:", err)
      end
      old_read(self, filename, silent)
    end
    
    self.installed = true
end -- install

function ModMatrix:bang_all()
    for tn, tier in ipairs(self.bangers) do
        local done = false
        for round=1,3,1 do
            for v, _ in pairs(tier) do
                params:lookup_param(v):bang()
                tier[v] = nil
            end
            if next(tier) == nil then
                done = true
                break
            end
        end
        if not done then
            print("Missing modulation; too much recursion", tn)
            tab.print(tier)
            self.bangers[tn] = {}
        end
    end
    self.bang_deferred = nil
end

function ModMatrix:add_post_init_hook(f)
    table.insert(self.post_init_hooks, f)
end

function ModMatrix:call_post_init_hooks()
    for _, f in ipairs(self.post_init_hooks) do f() end
end

function ModMatrix:defer_bang(param_id, tier)
    if tier == nil then tier = 3 end
    if self.bang_deferred == nil then
        clock.run(function()
            clock.sleep(0)
            self:bang_all()
        end)
    end
    self.bang_deferred = true
    self.bangers[tier][param_id] = true
end

function ModMatrix:lookup_source(id)
    if type(id) == "string" and self.sources_indexes[id] then
        return self.sources_list[self.sources_indexes[id]]
    elseif self.sources_list[id] then
        return self.sources_list[id]
    else
        error("invalid mod matrix index: "..id)
    end
end

function ModMatrix:add(source)
    table.insert(self.sources_list, source)
    self.sources_indexes[source.id] = #self.sources_list
end

function ModMatrix:add_binary(id, name)
    self:add{
        t = self.tBINARY,
        name = name,
        id = id,
    }
end

function ModMatrix:add_unipolar(id, name)
    self:add{
        t = self.tUNIPOLAR,
        name = name,
        id = id,
    }
end

function ModMatrix:add_bipolar(id, name)
    self:add{
        t = self.tBIPOLAR,
        name = name,
        id =id,
    }
end

function ModMatrix:get(id)
    return self:lookup_source(id).value
end

local nilmul = function(depth, modulation)
    if modulation == nil then return nil end
    return depth*modulation
end

function ModMatrix:set_depth(param_id, modulation_id, depth)
    if type(modulation_id) == "number" then
        modulation_id = self.sources_list[modulation_id].id
    end
    local p = params:lookup_param(param_id)
    if depth == nil or depth == 0 then
        if self.matrix[modulation_id] ~= nil then
            self.matrix[modulation_id][p.id] = nil        
            if next(self.matrix[modulation_id]) == nil then
                self.matrix[modulation_id] = nil
            end
        end
    else
        if self.matrix[modulation_id] == nil then
            self.matrix[modulation_id] = {}
        end
        self.matrix[modulation_id][p.id] = depth
        if p.modulation == nil then p.modulation = {} end
        p.modulation[modulation_id] = nilmul(self:get(modulation_id))
        if p.t ~= params.tTRIGGER then
            self:defer_bang(p.id, p.priority)
        end
    end
end

function ModMatrix:get_depth(param_id, modulation_id)
    if type(modulation_id) == "number" then
        modulation_id = self.sources_list[modulation_id].id
    end
    if type(param_id) == "number" then
        param_id = params:lookup_param(param_id).id
    end
    if self.matrix[modulation_id] == nil then return nil end
    return self.matrix[modulation_id][param_id]
end

function ModMatrix:used(modulation_id)
    if type(modulation_id) == "number" then
        modulation_id = self.sources_list[modulation_id].id
    end
    if self.matrix[modulation_id] == nil then return false end
    if next(self.matrix[modulation_id]) == nil then return false end
    return true
end

function ModMatrix:set(modulation_id, value)
    local source = self:lookup_source(modulation_id)
    source.value = value
    if self.matrix[source.id] == nil then self.matrix[source.id] = {} end
    local targets = self.matrix[source.id]
    for param_id, depth in pairs(targets) do
        local p = params:lookup_param(param_id)
        if p.modulation == nil then p.modulation = {} end
        p.modulation[source.id] = nilmul(depth, value)
        if p.t ~= params.tTRIGGER then
            self:defer_bang(p.id, p.priority)
        elseif value > 0 then
            self:defer_bang(p.id, p.priority)
        end
    end
end

function ModMatrix:clear()
    self.matrix = {}
    self.bangers = {{}, {}, {}, {}}
    self.sources_list = {}
    self.sources_indexes = {}
    self.post_init_hooks = {}
end

return ModMatrix
