--- The overlay frame, opening/closing, hotkeys and integration points.
local CS = Cardsharp
local UI = CS.UI
local R, C, O = G.UIT.R, G.UIT.C, G.UIT.O

local DIM_ALPHA = { 0.3, 0.6, 0.85 }

function CS.is_open()
    return G.OVERLAY_MENU ~= nil and G.OVERLAY_MENU ~= true and G.OVERLAY_MENU.cardsharp == true
end

function CS.apply_dim()
    if CS.view.bg_colour then CS.view.bg_colour[4] = DIM_ALPHA[CS.config.dim] or 0.6 end
end

-------------------------------------------------------------------------------
-- Header
-------------------------------------------------------------------------------
local function badge(label, get, colour)
    return {
        n = C,
        config = { align = 'cm', padding = 0.06, r = 0.1, colour = G.C.BLACK, emboss = 0.04 },
        nodes = {
            UI.text(label, 0.26, UI.muted()),
            UI.spacer(0.06),
            UI.live(get, 0.34, colour),
        },
    }
end

local function header()
    local title = {
        { n = O, config = { object = DynaText({ string = { 'CARD' }, colours = { G.C.UI.TEXT_LIGHT }, shadow = true, float = true, scale = 0.62, silent = true, pop_in = 0, pop_in_rate = 4 }) } },
        { n = O, config = { object = DynaText({ string = { 'SHARP' }, colours = { G.C.MONEY }, shadow = true, float = true, scale = 0.62, silent = true, pop_in = 0.15, pop_in_rate = 4 }) } },
        UI.spacer(0.15),
        { n = C, config = { align = 'bl', padding = 0.02 }, nodes = {
            UI.text(('mod menu  -  %s to close'):format(string.upper(CS.config.hotkey or 'f1')), 0.26, UI.muted()),
        } },
    }
    local right = {}
    if CS.in_run() then
        local gm = G.GAME
        right = {
            badge('$', function() return CS.fmt(gm.dollars) end, G.C.MONEY), UI.spacer(0.07),
            badge('ANTE', function() return CS.fmt(gm.round_resets.ante) .. '/' .. CS.fmt(gm.win_ante) end, G.C.FILTER), UI.spacer(0.07),
            badge('ROUND', function() return CS.fmt(gm.round) end, G.C.FILTER), UI.spacer(0.07),
            badge('HANDS', function() return gm.current_round.hands_left end, G.C.BLUE), UI.spacer(0.07),
            badge('DISCARDS', function() return gm.current_round.discards_left end, G.C.RED), UI.spacer(0.07),
        }
    end
    right[#right + 1] = {
        n = C,
        config = { align = 'cm', padding = 0.06, r = 0.1, colour = G.C.BLACK, emboss = 0.04, func = 'cshp_sync', cs_sync = function(e)
            local on = CS.active_cheats() > 0
            if on ~= e.config.cs_on then
                e.config.cs_on = on
                e.config.colour = on and UI.tint(G.C.ETERNAL, 0.7) or G.C.BLACK
            end
        end },
        nodes = { UI.live(function()
            local n = CS.active_cheats()
            return n == 0 and 'no cheats on' or (n .. ' cheat' .. (n == 1 and '' or 's') .. ' on')
        end, 0.28, G.C.UI.TEXT_LIGHT) },
    }
    return UI.row({
        { n = C, config = { align = 'cl', minw = 6.5 }, nodes = title },
        { n = C, config = { align = 'cr', minw = UI.W - 6.5 }, nodes = right },
    }, { padding = 0.02 })
end

-------------------------------------------------------------------------------
-- Tabs
-------------------------------------------------------------------------------
local function tab_bar()
    local in_run = CS.in_run()
    local nodes = {}
    for _, t in ipairs(CS.TABS) do
        local enabled = in_run or not t.needs_run
        local col = t.colour()
        nodes[#nodes + 1] = UI.chip({
            label = t.label, w = 2.18, h = 0.56, scale = 0.38, colour = col,
            off_colour = enabled and UI.tint(col, 0.32) or G.C.UI.BACKGROUND_INACTIVE,
            tooltip = (not enabled) and { text = { 'Start a run to use this tab' } } or nil,
            selected = function() return CS.state.tab == t.id end,
            on_click = function()
                if not enabled then return CS.warn('Start a run to use the ' .. t.label .. ' tab') end
                CS.switch_tab(t.id)
            end,
        })
    end
    return UI.row(nodes, { padding = 0.05 })
end

function CS.build_content()
    local def = CS.TAB_BY_ID[CS.state.tab]
    local ok, node = xpcall(def.build, debug.traceback)
    if not ok then
        CS.log(node)
        node = UI.notice('This tab hit an error', { 'Details were written to the log.', 'Other tabs still work.' }, G.C.RED)
    end
    return UI.root({ node }, { minw = UI.W, minh = UI.H, align = 'tm' })
end

function CS.switch_tab(id)
    if CS.state.tab == id then return end
    CS.state.tab = id
    CS.refresh()
end

function CS.refresh()
    if not CS.is_open() then return end
    if G.CONTROLLER.text_input_hook then G.CONTROLLER.text_input_hook = nil end
    UI.replace('cshp_content', CS.build_content)
end

-------------------------------------------------------------------------------
-- Frame
-------------------------------------------------------------------------------
local function footer()
    return UI.row({
        { n = C, config = { align = 'cl', minw = UI.W - 3.0, minh = 0.5, padding = 0.05 }, nodes = {
            { n = C, config = { align = 'cm', minw = 0.1, minh = 0.32, r = 0.05, colour = G.C.MONEY } },
            UI.spacer(0.12),
            { n = O, config = { ref_table = CS.view, ref_value = 'status', object = CS.view.status } },
        } },
        UI.button({ label = 'Close', w = 2.8, h = 0.55, colour = G.C.ORANGE, on_click = function() CS.close() end }),
    }, { padding = 0.02 })
end

local function frame()
    CS.view.bg_colour = { G.C.GREY[1], G.C.GREY[2], G.C.GREY[3], DIM_ALPHA[CS.config.dim] or 0.6 }
    return {
        n = G.UIT.ROOT,
        config = { align = 'cm', minw = G.ROOM.T.w * 5, minh = G.ROOM.T.h * 5, padding = 0.1, r = 0.1, colour = CS.view.bg_colour },
        nodes = {
            { n = R, config = { align = 'cm', r = 0.3, padding = 0.07, colour = G.C.JOKER_GREY, emboss = 0.1 }, nodes = {
                { n = C, config = { align = 'cm', r = 0.2, padding = 0.12, colour = G.C.L_BLACK }, nodes = {
                    header(),
                    tab_bar(),
                    UI.row({ UI.slot('cshp_content', CS.build_content, { minw = UI.W, minh = UI.H }) }),
                    footer(),
                } },
            } },
        },
    }
end

-------------------------------------------------------------------------------
-- Open / close
-------------------------------------------------------------------------------
function CS.open(tab)
    if not G.ROOM or G.STAGE == G.STAGES.SPLASH then return end
    if tab then CS.state.tab = tab end
    local def = CS.TAB_BY_ID[CS.state.tab]
    if not def or (def.needs_run and not CS.in_run()) then CS.state.tab = 'tools' end
    if G.CONTROLLER.text_input_hook then G.CONTROLLER.text_input_hook = nil end

    -- Pause first: objects created while unpaused don't move while the game is paused.
    G.SETTINGS.paused = true
    local msg = CS.last_msg or ('Welcome! ' .. (CS.in_run() and 'Pick a tab to get started.' or 'Start a run to unlock every tab.'))
    local col = (CS.last_msg and CS.last_col) or G.C.UI.TEXT_LIGHT
    CS.view.status = DynaText({ string = { msg }, colours = { col }, shadow = true, silent = true, pop_in = 0, pop_in_rate = 6, scale = 0.36, maxw = 11 })

    local prev = G.OVERLAY_MENU
    local ok, err = xpcall(function()
        -- Build while flagged as an overlay (like the game does) so preview cards are never
        -- counted as part of the run - otherwise they would be kept out of shops and packs.
        if not prev then G.OVERLAY_MENU = true end
        local definition = frame()
        if G.OVERLAY_MENU == true then G.OVERLAY_MENU = nil end
        G.FUNCS.overlay_menu({ definition = definition })
    end, debug.traceback)
    if G.OVERLAY_MENU == true then G.OVERLAY_MENU = nil end
    if not ok then
        CS.log(err)
        if G.OVERLAY_MENU and G.OVERLAY_MENU ~= true then G.FUNCS.exit_overlay_menu() end
        G.SETTINGS.paused = false
        return
    end
    G.OVERLAY_MENU.cardsharp = true
    CS.sfx('cardSlide1', 1.1, 0.6)
end

function CS.close()
    if CS.is_open() then
        G.FUNCS.exit_overlay_menu()
        CS.sfx('cardSlide2', 1, 0.5)
    end
end

G.FUNCS.cshp_open = function() CS.open() end

--- Hotkey: toggle the menu; when hovering one of your cards, jump to editing it.
function CS.on_hotkey()
    if CS.capturing or G.CONTROLLER.text_input_hook then return end
    if CS.is_open() then return CS.close() end
    local target = G.CONTROLLER.hovering and G.CONTROLLER.hovering.target
    if CS.config.hover_edit and CS.in_run() and target and type(target.is) == 'function' and target:is(Card)
        and CS.card_alive(target) and (target.area == G.jokers or target.area == G.hand or target.area == G.consumeables) then
        CS.state.focus_card = target
        CS.state.edit.scope = 'focus'
        return CS.open('edit')
    end
    CS.open()
end

CS.keybind = CS.keybind or SMODS.Keybind({
    key = 'open_menu',
    key_pressed = CS.config.hotkey or 'f1',
    action = function() CS.safe(CS.on_hotkey) end,
})

-------------------------------------------------------------------------------
-- Hooks (installed once, so the module can be hot-reloaded)
-------------------------------------------------------------------------------
if not CS._menu_hooks then
    CS._menu_hooks = true

    -- Hotkey capture for rebinding.
    local key_press_ref = Controller.key_press_update
    function Controller:key_press_update(key, dt)
        if CS.capturing then
            CS.capturing = false
            if key == 'escape' then
                CS.toast('Hotkey unchanged', G.C.UI.TEXT_LIGHT, 'cancel')
            else
                CS.config.hotkey = key
                if CS.keybind then CS.keybind.key_pressed = key end
                CS.save_config()
                CS.toast('Menu hotkey is now ' .. string.upper(key), G.C.GREEN, 'generic1')
            end
            return
        end
        return key_press_ref(self, key, dt)
    end

    -- Mouse wheel flips pages on tabs that page.
    local wheel_ref = love.wheelmoved
    function love.wheelmoved(x, y)
        if wheel_ref then wheel_ref(x, y) end
        if y ~= 0 and CS.is_open() and not G.CONTROLLER.text_input_hook then
            local def = CS.TAB_BY_ID[CS.state.tab]
            if def and def.wheel then CS.safe(def.wheel, y) end
        end
    end

    -- A Cardsharp button in the pause / options menu.
    local options_ref = create_UIBox_options
    function create_UIBox_options(...)
        local t = options_ref(...)
        local ok = pcall(function()
            local contents = t.nodes[1].nodes[1].nodes[1].nodes
            local last = 0
            for k in pairs(contents) do if type(k) == 'number' and k > last then last = k end end
            contents[last + 1] = UIBox_button({ label = { 'Cardsharp' }, button = 'cshp_open', minw = 5, colour = G.C.MONEY })
        end)
        if not ok then CS.log('could not add the options-menu button') end
        return t
    end

    -- Repair runs that predate installed mods whenever a run starts or loads (see A.repair_run).
    local start_run_ref = Game.start_run
    function Game:start_run(...)
        local ret = start_run_ref(self, ...)
        pcall(CS.A.repair_run)
        pcall(CS.A.ensure_shop_rates)
        return ret
    end

    -- Forget a focused card once it leaves play.
    local remove_ref = Card.remove
    function Card:remove(...)
        if CS.state.focus_card == self then CS.state.focus_card = nil end
        if CS.state.edit.value_card == self then CS.state.edit.value_card = nil end
        return remove_ref(self, ...)
    end
end

-- Mods-menu config tab.
CS.mod.config_tab = function()
    return {
        n = G.UIT.ROOT,
        config = { align = 'cm', padding = 0.2, r = 0.1, colour = G.C.BLACK, minw = 8, minh = 4 },
        nodes = {
            UI.row({ UI.text('Cardsharp', 0.6, G.C.MONEY) }, { padding = 0.1 }),
            UI.row({ UI.text(('Press %s in a run to open the menu.'):format(string.upper(CS.config.hotkey or 'f1')), 0.36) }, { padding = 0.05 }),
            UI.row({ UI.text('Hover one of your cards first to jump straight to editing it.', 0.3, UI.muted()) }, { padding = 0.05 }),
            UI.row({ UIBox_button({ label = { 'Open Cardsharp' }, button = 'cshp_open', minw = 4, colour = G.C.MONEY }) }, { padding = 0.15 }),
        },
    }
end

CS.log(('Cardsharp %s loaded - press %s to open'):format(CS.VERSION, string.upper(CS.config.hotkey or 'f1')))
