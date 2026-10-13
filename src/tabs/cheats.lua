--- Cheats tab: persistent toggles and game speed.
local CS = Cardsharp
local UI = CS.UI
local R, C, T = G.UIT.R, G.UIT.C, G.UIT.T

local ACCENT = function() return G.C.ETERNAL end

local function cheat_card(def)
    local col = G.C[def.colour] or G.C.GREEN
    local on_bg = UI.tint(col, 0.42)
    local off_bg = G.C.BLACK
    local title_cfg = { text = def.title, scale = 0.38, colour = G.C.UI.TEXT_LIGHT, shadow = true }
    local desc = {}
    for _, line in ipairs(def.desc) do
        desc[#desc + 1] = { n = R, config = { align = 'cl', padding = 0.01 }, nodes = { UI.text(line, 0.27, UI.muted()) } }
    end
    local state_cfg = { align = 'cm', minw = 0.9, minh = 0.36, r = 0.08, colour = G.C.UI.BACKGROUND_INACTIVE }
    local state_text = UI.live(function() return CS.config.cheats[def.key] and 'ON' or 'OFF' end, 0.28, G.C.UI.TEXT_LIGHT)
    return {
        n = C,
        config = {
            align = 'cm', minw = 4.4, minh = 1.65, padding = 0.12, r = 0.12, colour = off_bg, emboss = 0.05,
            hover = true, shadow = true, button = 'cshp_click', func = 'cshp_sync',
            cs_click = function() CS.set_cheat(def.key, not CS.config.cheats[def.key]) end,
            cs_sync = function(e)
                local on = CS.config.cheats[def.key] and true or false
                if on ~= e.config.cs_on then
                    e.config.cs_on = on
                    e.config.colour = on and on_bg or off_bg
                    e.config.outline = on and 1.2 or nil
                    e.config.outline_colour = on and col or nil
                    state_cfg.colour = on and col or G.C.UI.BACKGROUND_INACTIVE
                    title_cfg.colour = on and G.C.UI.TEXT_LIGHT or { 1, 1, 1, 0.85 }
                end
            end,
        },
        nodes = {
            { n = R, config = { align = 'cm' }, nodes = {
                { n = C, config = { align = 'cl', minw = 3.2 }, nodes = { { n = T, config = title_cfg } } },
                { n = C, config = state_cfg, nodes = { state_text } },
            } },
            { n = R, config = { align = 'cl', padding = 0.04 }, nodes = { { n = C, config = { align = 'cl' }, nodes = desc } } },
        },
    }
end

local SPEEDS = { 0.5, 1, 2, 3, 4, 8, 16, 32, 64 }

local function build()
    local cards = {}
    for _, def in ipairs(CS.CHEATS) do cards[#cards + 1] = cheat_card(def) end

    local speed_items = {}
    for _, v in ipairs(SPEEDS) do
        speed_items[#speed_items + 1] = { key = v, label = (v == 0.5 and '0.5' or tostring(v)) .. 'x', colour = v > 4 and G.C.ETERNAL or G.C.BLUE }
    end

    return UI.col({
        UI.row({ UI.section({ title = 'CHEATS', subtitle = 'click a card to toggle - they stay on between runs until you turn them off', colour = ACCENT(), w = 18.4, align = 'cm', nodes = {
            UI.flow(cards, 4, { gap = 0.1 }),
        } }) }, { padding = 0.03 }),
        UI.row({
            UI.section({ title = 'GAME SPEED', subtitle = 'vanilla tops out at 4x', colour = ACCENT(), w = 12.4, align = 'cm', nodes = {
                UI.radio(speed_items, G.SETTINGS, 'GAMESPEED', { per_row = 9, w = 1.18, h = 0.5, scale = 0.32, on_change = function(v)
                    G:save_settings()
                    CS.toast(('Game speed %sx'):format(v), G.C.BLUE, false)
                end }),
            } }),
            UI.spacer(0.1),
            UI.section({ title = 'RESET', colour = ACCENT(), w = 5.8, align = 'cm', nodes = {
                UI.button({ label = 'Turn every cheat off', w = 5.3, h = 0.55, colour = G.C.RED, on_click = CS.all_cheats_off,
                    enabled = function() return CS.active_cheats() > 0 end }),
            } }),
        }, { padding = 0.03, align = 'tm' }),
    }, { align = 'tm' })
end

CS.register_tab({
    id = 'cheats', label = 'Cheats', colour = function() return G.C.ETERNAL end, order = 7, needs_run = false,
    build = build,
})
