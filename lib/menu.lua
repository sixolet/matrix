local mod = require 'core/mods'

local fileselect = require 'fileselect'
local textentry = require 'textentry'

local matrix = require 'matrix/lib/matrix'

local mPARAM = 0
local mSOURCE = 1

local m = {
  pos = 0,
  oldpos = 0,
  group = false,
  groupid = 0,
  alt = false,
  mode = mPARAM,
  mode_prev = mPARAM,
  mode_pos = 1,
  mpos = 1,
}

local page

-- called from mod on script reset
m.reset = function()
  page = nil
  m.pos = 0
  m.group = false
  m.mode = mPARAM
end

local function build_page()
  page = {}
  local i = 1
  repeat
    if params:visible(i) then table.insert(page, i) end
    if params:t(i) == params.tGROUP then
      i = i + params:get(i) + 1
    else i = i + 1 end
  until i > params.count
end

local function build_sub(sub)
  page = {}
  for i = 1,params:get(sub) do
    if params:visible(i + sub) then
      table.insert(page, i + sub)
    end
  end
end

local function build_sources(t)
    page = {}
    local i = 1
    for idx, source in ipairs(matrix.sources_list) do
        if t == params.tBINARY or t == params.tTRIGGER then
            if source.t == matrix.tBINARY then
                table.insert(page, idx)
            end
        else
            table.insert(page, idx)
        end
        i = i + 1
    end
end

m.key = function(n,z)
  if n==1 and z==1 then
    m.alt = true
  elseif n==1 and z==0 then
    m.alt = false
  -- MODE MENU
  elseif m.mode == mPARAM then
    local i = page[m.pos+1]
    local t = params:t(i)
    if n==2 and z==1 then
      if m.group==true then
        m.group = false
        build_page()
        m.pos = m.oldpos
      else
        mod.menu.exit()
      end
    elseif n==3 and z==1 then
      if t == params.tGROUP then
        build_sub(i)
        m.group = true
        m.groupid = i
        m.groupname = params:string(i)
        m.oldpos = m.pos
        m.pos = 0
      elseif t == params.tSEPARATOR then
        local n = m.pos+1
        repeat
          n = n+1
          if n > #page then n = 1 end
        until params:t(page[n]) == params.tSEPARATOR
        m.pos = n-1
      else
        build_sources(t)
        m.paramname = params:lookup_param(i).name
        m.param_id = i
        m.oldpos = m.pos
        m.pos = 0
        m.mode = mSOURCE        
      end
    end
    -- PARAM
  elseif m.mode == mSOURCE then
    local i = m.pos+1
    if n == 2 and z == 1 then 
      -- back
      m.pos = m.oldpos
      m.mode = mPARAM
      m.calculated = false
      if m.group == true then
        build_sub(m.groupid)
      else
        build_page()
      end
    elseif n == 3 and z == 1 and m.alt then
      local source = matrix:lookup_source(i)
      if matrix:has_active_depth_param(m.param_id, source.id) then
        matrix:deactivate_depth_param(m.param_id, source.id)
      else
        matrix:activate_depth_param(m.param_id, source.id)
      end
    elseif n == 3 and z == 1 then
      matrix:set_depth(m.param_id, i, nil)
      m.calculated = false
    end
  end
  _menu.redraw()
end

m.enc = function(n,d)
    -- normal scroll
    if n==2 and m.alt==false then
      local prev = m.pos
      m.pos = util.clamp(m.pos + d, 0, #page - 1)
      if m.pos ~= prev then m.redraw() end
    -- jump section
    elseif m.mode == mSOURCE and n==3 then
      local i = m.pos+1
      local source = matrix:lookup_source(i)
      local param = params:lookup_param(m.param_id)
      if param.t == params.tBINARY or param.t == params.tTRIGGER then
        if d > 0 then 
            matrix:set_depth(m.param_id, i, 1)
        else
            matrix:set_depth(m.param_id, i, nil)
        end
      else
        local depth = matrix:get_depth(m.param_id, i)
        if depth == nil then depth = 0 end
        depth = depth + 0.01 * d
        matrix:set_depth(m.param_id, i, depth)
        m.calculated = false
      end
    elseif m.mode == mPARAM and n==2 and m.alt==true then
      d = d>0 and 1 or -1
      local i = m.pos+1
      repeat
        i = i+d
        if i > #page then i = 1 end
        if i < 1 then i = #page end
      until params:t(page[i]) == params.tSEPARATOR or i==1
      m.pos = i-1
    end
end

function m.modulation_of(p)
    local prm = params:lookup_param(p)
    if prm.t == params.tBINARY or prm.t == params.tTRIGGER then
        if prm.modulation == nil then return nil end
        local c = 0
        for _, v in pairs(prm.modulation) do
            if v and v > 0 then
                return 1
            end
            c = c + 1
        end
        if c > 0 then
            return 0
        end
        return nil
    elseif prm.t == params.tNUMBER or prm.t == params.tTAPER or prm.t == params.tCONTROL then
        if prm.modulation == nil then return nil end
        local c = 0
        local s = 0
        for _, v in pairs(prm.modulation) do
            s = s + v
            c = c + 1
        end
        if c > 0 then return s end
        return nil
    else
        return nil
    end
end

function m.calculate_min_max()
  if m.calculated then return end
  local param = params:lookup_param(m.param_id)
  if param.t == params.tBINARY or param.t == params.tTRIGGER then
    m.max_string = "1"
    m.min_string = "0"
    m.calculated = true
    return
  end
  local min_modulation = 0
  local max_modulation = 0
  for i, source in ipairs(matrix.sources_list) do
    local depth = matrix:get_depth(m.param_id, i)
    if depth ~= nil then
      if source.t == matrix.tBINARY or source.t == matrix.tUNIPOLAR then
        if depth > 0 then
          max_modulation = max_modulation + depth
        else
          min_modulation = min_modulation + depth
        end
      elseif source.t == matrix.tBIPOLAR then
        max_modulation = max_modulation + math.abs(depth)
        min_modulation = min_modulation - math.abs(depth)
      end
    end
  end
  if max_modulation == 0 and min_modulation == 0 then
    m.max_string = ""
    m.min_string = ""
    calculated = true
    return
  end
  if param.t == params.tTAPER or param.t == params.tCONTROL then
    local raw = param:get_raw()
    m.max_string = string.format("%.2f", param:map_value(raw+max_modulation))
    m.min_string = string.format("%.2f", param:map_value(raw+min_modulation))
  elseif param.t == params.tNUMBER then
    local value = param.value
    local range = param:get_range()
    local pos_swing = util.linlin(0, 1, 0, range[2] - range[1], max_modulation)
    local neg_swing = util.linlin(0, 1, 0, range[2] - range[1], math.abs(min_modulation))
    m.max_string = string.format("%i", util.clamp(math.ceil(value + pos_swing), range[1], range[2]))
    m.min_string = string.format("%i", util.clamp(math.floor(value - neg_swing), range[1], range[2]))
  else
    m.max_string = ""
    m.min_string = ""
  end

  m.calculated = true
end

m.redraw = function()
  screen.clear()
  _menu.draw_panel()

  -- SELECT
  if m.mode == mPARAM then
    if m.pos == 0 then
      local n = "MATRIX"
      if m.group then n = n .. " / " .. m.groupname end
      screen.level(4)
      screen.move(0,10)
      screen.text(n)
    end
    for i=1,6 do
      if (i > 2 - m.pos) and (i < #page - m.pos + 3) then
        if i==3 then screen.level(15) else screen.level(4) end
        local p = page[i+m.pos-2]
        local t = params:t(p)
        if t == params.tSEPARATOR then
          screen.move(0,10*i+2.5)
          screen.line_rel(127,0)
          screen.stroke()
          screen.move(63,10*i)
          screen.text_center(params:get_name(p))
        elseif t == params.tGROUP then
          screen.move(0,10*i)
          screen.text(params:get_name(p) .. " >")
        else
          screen.move(0,10*i)
          screen.text(params:get_name(p))
          screen.move(127,10*i)
          local wiggle = m.modulation_of(p)
          if wiggle ~= nil then
            if t == params.tBINARY or t == params.tTRIGGER then
              local fresh = false
              local the_param = params:lookup_param(p)
              if the_param.beatstamp then
                local age = (clock.get_beats() - the_param.beatstamp)*clock.get_beat_sec() 
                fresh = age >= 0 and age < 0.1
              end
              local size = 0
              if t == params.tBINARY then
                if wiggle and wiggle > 0 then
                  if fresh then
                    size = 6
                  else
                    size = 4
                  end
                elseif fresh then
                  size = 1
                end
              else
                if fresh and wiggle and wiggle > 0 then
                  size = 6
                else
                  size = 4
                end
              end
              screen.rect(100 - size/2, 10 * i - (2 + size/2), size, size)
              screen.fill()                
            else
              local width = wiggle * 25
              if math.abs(width) < 1 then
                width = 1
              end
              screen.rect(100, 10 * i - 4, width, 3)
              screen.fill()
            end
          elseif t == params.tBINARY or t == params.tTRIGGER or t == params.tNUMBER or t == params.tCONTROL or t == params.tTAPER then
            -- not modulated but could be
            screen.move(98, 10 * i - 2)
            screen.line_rel(4, 0)
            screen.stroke()
          end
        end
      end
    end
  elseif m.mode == mSOURCE then
    m.calculate_min_max()
    if m.pos == 0 then
      local n = "FOR"
      n = n .. ": " .. m.paramname
      screen.level(4)
      screen.move(0,10)
      screen.text(n)
      local min_depth = 0
      local max_depth = 0
      screen.move(127, 10)
      if m.min_string ~= m.max_string then
        screen.text_right(m.min_string.."-"..m.max_string)
      else
        screen.text_right(params:string(m.param_id))
      end
    end
    for i=1,6 do
      if (i > 2 - m.pos) and (i < #page - m.pos + 3) then
        if i==3 then screen.level(15) else screen.level(4) end
        local p = page[i+m.pos-2]
        local source = matrix:lookup_source(p)
        local star = ""
        if matrix:has_active_depth_param(m.param_id, source.id) then
            star = "*"
        end
        screen.move(0,10*i)
        screen.text(source.name..star)
        screen.move(127,10*i)
        local depth = matrix:get_depth(m.param_id, p)
        if depth ~= nil then
            screen.text_right(string.format("%.2f", matrix:get_depth(m.param_id, p)))
        else
            screen.text_right("-")
        end
        screen.stroke()
        local wiggle = source.value
        if source.t == matrix.tBINARY then
          local fresh = false
          if source.beatstamp then
            local age = (clock.get_beats() - source.beatstamp)*clock.get_beat_sec() 
            fresh = age >= 0 and age < 0.1
          end
          local size = 0
          if wiggle and wiggle > 0 then
            if fresh then
              size = 6
            else
              size = 4
            end
          elseif fresh then
            size = 1
          end
          screen.rect(80 - size/2, 10 * i - (2 + size/2), size, size)
          screen.fill()
        elseif wiggle ~= nil then
          local width = wiggle * 25
          if math.abs(width) < 1 then
            width = 1
          end
          screen.rect(80, 10 * i - 4, width, 3)
          screen.fill()
        else
          -- not modulated but could be
          screen.move(78, 10 * i - 2)
          screen.line_rel(4, 0)
          screen.stroke()
        end
      end
    end    
  end
  screen.update()
end

m.init = function()
  if page == nil then build_page() end
  m.alt = false
  m.fine = false
  m.triggered = {}
  _menu.timer.event = function()
    for k, v in pairs(m.triggered) do
      if v > 0 then m.triggered[k] = v - 1 end
    end
    m.redraw()
  end
  m.on = {}
  for i,param in ipairs(params.params) do
    if param.t == params.tBINARY then
        if params:lookup_param(i).behavior == 'trigger' then 
          m.triggered[i] = 2
        else m.on[i] = params:get(i) end
    end
  end
  _menu.timer.time = 0.1
  _menu.timer.count = -1
  _menu.timer:start()
end

local prev_deinit = _menu.deinit


m.deinit = function()
  _menu.timer:stop()
end

m.rebuild_params = function()
  if m.mode == mPARAM then 
    if m.group then
      build_sub(m.groupid)
    else
      build_page()
    end
    if m.mode then
      m.redraw()
    end
  end
end

return m