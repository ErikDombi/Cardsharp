--- Cardsharp: an in-game mod menu for Balatro.
Cardsharp = Cardsharp or {}
Cardsharp.mod = SMODS.current_mod

-- icon shown in the Mods menu
SMODS.Atlas({ key = 'modicon', path = 'icon.png', px = 34, py = 34 })

local function load_module(path)
    local chunk, err = SMODS.load_file(path)
    if not chunk then error(('Cardsharp could not load %s: %s'):format(path, tostring(err))) end
    return chunk()
end

load_module('src/core.lua')
load_module('src/ui.lua')
load_module('src/actions.lua')
load_module('src/cheats.lua')
load_module('src/tabs/spawn.lua')
load_module('src/tabs/forge.lua')
load_module('src/tabs/edit.lua')
load_module('src/tabs/run.lua')
load_module('src/tabs/hands.lua')
load_module('src/tabs/blinds.lua')
load_module('src/tabs/cheats.lua')
load_module('src/tabs/tools.lua')
load_module('src/menu.lua')
