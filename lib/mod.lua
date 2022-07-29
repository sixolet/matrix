local mod = require 'core/mods'

local menu = require('toolkit/lib/menu')
local matrix = require('toolkit/lib/modmatrix')

mod.hook.register("system_post_startup", "hack the matrix", function()
    matrix:install()
end)

mod.hook.register("script_pre_init", "install matrix post-init hooks", function()
    local old_init = init
    init = function()
        old_init()
        matrix:call_post_init_hooks()
        -- One last params read. Don't bang except the things we explicitly deferred a bang of.
        params:read(nil, true)
    end
end

mod.hook.register("script_post_cleanup", "clear the matrix for the next script", function()
    matrix:clear()
end)

return matrix