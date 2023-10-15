local mod = require 'core/mods'
local hook = require 'core/hook'
local tab = require 'tabutil'
-- Begin post-init hack block
if hook.script_post_init == nil and mod.hook.patched == nil then
    mod.hook.patched = true
    local old_register = mod.hook.register
    local post_init_hooks = {}
    mod.hook.register = function(h, name, f)
        if h == "script_post_init" then
            post_init_hooks[name] = f
        else
            old_register(h, name, f)
        end
    end
    mod.hook.register('script_pre_init', '!replace init for fake post init', function()
        local old_init = init
        init = function()
            old_init()
            for i, k in ipairs(tab.sort(post_init_hooks)) do
                local cb = post_init_hooks[k]
                print('calling: ', k)
                local ok, error = pcall(cb)
                if not ok then
                    print('hook: ' .. k .. ' failed, error: ' .. error)
                end
            end
        end
    end)
end
-- end post-init hack block

local menu = require('matrix/lib/menu')
local matrix = require('matrix/lib/matrix')

mod.hook.register("system_post_startup", "hack the matrix", function()
    matrix:install()
end)

mod.hook.register("script_post_init", "aa metrix mod depth params", function()
    matrix:add_modulation_depth_params()
end)

mod.hook.register("script_post_init", "~ matrix one last param read", function()
    matrix:call_post_init_hooks() -- preserved for back compat
    params:read(nil, true)
end)

mod.hook.register("script_pre_init", "maybe this is not necessary", function()
    menu.page = nil
end)

mod.hook.register("script_post_cleanup", "clear the matrix for the next script", function()
    menu.reset()
    matrix:clear()
end)

mod.menu.register("matrix", menu)


return matrix