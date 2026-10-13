--- Hands tab: poker hand levels, chips and mult.
local CS = Cardsharp
local UI, A = CS.UI, CS.A
local R, C = G.UIT.R, G.UIT.C

local PER_PAGE = 15
local LIST_W, LIST_H = 12.9, 7.3

local function hand_list()
    local out = {}
    for _, h in ipairs(G.handlist or {}) do
        if G.GAME.hands[h] then out[#out + 1] = h end
    end
    return out
end

local function level_colour(level)
    local lv = math.floor(CS.num(level))
    return (G.C.HAND_LEVELS and G.C.HAND_LEVELS[math.min(7, math.max(1, lv))]) or G.C.UI.TEXT_LIGHT
end

local function cell(node, w, align)
    return { n = C, config = { align = align or 'cm', minw = w, minh = 0.4 }, nodes = { node } }
end

local function value_box(text, colour, w)
    return { n = C, config = { align = 'cm', minw = w, minh = 0.4, r = 0.08, colour = colour, padding = 0.02 }, nodes = {
        UI.text(text, 0.3, UI.text_on(colour), { maxw = w - 0.1 }),
    } }
end

local build_list

local function refresh() UI.replace('cshp_hands_list', build_list) end

build_list = function()
    local s = CS.state.hands
    local list = hand_list()
    local pages = math.max(1, math.ceil(#list / PER_PAGE))
    s.page = CS.clamp(s.page or 1, 1, pages)
    CS.view.hands_pages = pages

    local header = UI.row({
        cell(UI.text('POKER HAND', 0.26, UI.muted()), 3.2, 'cl'),
        cell(UI.text('LEVEL', 0.26, UI.muted()), 1.05),
        cell(UI.text('CHIPS', 0.26, UI.muted()), 1.55),
        cell(UI.text('', 0.26), 0.3),
        cell(UI.text('MULT', 0.26, UI.muted()), 1.55),
        cell(UI.text('PLAYED', 0.26, UI.muted()), 0.95),
        cell(UI.text('LEVEL UP / DOWN', 0.26, UI.muted()), 2.5),
        cell(UI.text('SHOWN', 0.26, UI.muted()), 1.05),
    }, { padding = 0.02 })

    local rows = { header }
    for i = (s.page - 1) * PER_PAGE + 1, math.min(#list, s.page * PER_PAGE) do
        local hand = list[i]
        local h = G.GAME.hands[hand]
        local visible = SMODS.is_poker_hand_visible and SMODS.is_poker_hand_visible(hand) or h.visible
        local function lvl(d) return function() A.level_hand(hand, d * CS.step_mult()); CS.sfx('button', 1 + d * 0.01, 0.3); refresh() end end
        rows[#rows + 1] = UI.row({
            cell(UI.text(CS.hand_name(hand), 0.32, visible and G.C.UI.TEXT_LIGHT or UI.muted(), { maxw = 3.1 }), 3.2, 'cl'),
            cell(value_box('Lv.' .. CS.fmt(h.level), level_colour(h.level), 0.95), 1.05),
            cell(value_box(CS.fmt(h.chips), G.C.CHIPS, 1.45), 1.55),
            cell(UI.text('X', 0.3, G.C.MULT), 0.3),
            cell(value_box(CS.fmt(h.mult), G.C.MULT, 1.45), 1.55),
            cell(UI.text(CS.fmt(h.played or 0), 0.3, UI.muted()), 0.95),
            UI.button({ label = '-1', w = 0.56, h = 0.38, scale = 0.28, colour = G.C.UI.BACKGROUND_INACTIVE, on_click = lvl(-1) }),
            UI.button({ label = '+1', w = 0.56, h = 0.38, scale = 0.28, colour = G.C.SECONDARY_SET.Planet, on_click = lvl(1) }),
            UI.button({ label = '+5', w = 0.56, h = 0.38, scale = 0.28, colour = G.C.SECONDARY_SET.Planet, on_click = lvl(5) }),
            UI.button({ label = '+25', w = 0.56, h = 0.38, scale = 0.28, colour = G.C.SECONDARY_SET.Planet, on_click = lvl(25) }),
            UI.spacer(0.08),
            UI.chip({ label = visible and 'Shown' or 'Hidden', w = 0.95, h = 0.38, scale = 0.26, colour = G.C.GREEN,
                selected = function() return h.visible end,
                on_click = function() h.visible = not h.visible; refresh() end }),
        }, { padding = 0.015 })
    end
    if pages > 1 then
        rows[#rows + 1] = UI.row({
            UI.button({ label = '<', w = 0.55, h = 0.38, scale = 0.3, colour = G.C.GREEN, on_click = function() s.page = s.page == 1 and pages or s.page - 1; refresh() end }),
            { n = C, config = { align = 'cm', minw = 1.8 }, nodes = { UI.text(('Page %d / %d'):format(s.page, pages), 0.3) } },
            UI.button({ label = '>', w = 0.55, h = 0.38, scale = 0.3, colour = G.C.GREEN, on_click = function() s.page = s.page == pages and 1 or s.page + 1; refresh() end }),
        }, { padding = 0.05 })
    end
    return UI.root({ UI.col(rows, { align = 'tm' }) }, { minw = LIST_W, minh = LIST_H, align = 'tm' })
end

local function bulk_panel()
    local function b(label, sub, colour, f)
        return UI.row({ UI.button({ label = label, sub = sub, colour = colour, w = 4.6, h = 0.62, scale = 0.34, on_click = function() f(); refresh() end }) }, { padding = 0.05 })
    end
    return UI.section({ title = 'ALL HANDS', colour = G.C.GREEN, w = 5.1, h = 7.5, align = 'tm', nodes = { UI.col({
        b('+1 level', 'like a Black Hole', G.C.SECONDARY_SET.Planet, function() A.level_all(1) end),
        b('+10 levels', nil, G.C.SECONDARY_SET.Planet, function() A.level_all(10) end),
        b('+100 levels', 'for the absurd runs', G.C.SECONDARY_SET.Planet, function() A.level_all(100) end),
        b('Reset to level 1', nil, G.C.UI.BACKGROUND_INACTIVE, A.reset_hands),
        UI.row({ UI.spacer(0.1, 0.15) }),
        b('Reveal secret hands', 'Five of a Kind, Flush House...', G.C.GREEN, function()
            for _, hand in ipairs(hand_list()) do G.GAME.hands[hand].visible = true end
            CS.toast('All poker hands are visible', G.C.GREEN, false)
        end),
        UI.row({ UI.spacer(0.1, 0.25) }),
        UI.row({ UI.text('Shift-click a row button', 0.26, UI.muted()) }, { padding = 0.02 }),
        UI.row({ UI.text('for 10x the levels.', 0.26, UI.muted()) }, { padding = 0.02 }),
    }, { align = 'tm' }) } })
end

local function build()
    return UI.row({
        UI.section({ title = 'POKER HANDS', colour = G.C.GREEN, w = LIST_W + 0.2, h = 7.5, align = 'tm', nodes = {
            UI.slot('cshp_hands_list', build_list, { minw = LIST_W, minh = LIST_H }),
        } }),
        bulk_panel(),
    }, { align = 'tm', padding = 0.05 })
end

CS.register_tab({
    id = 'hands', label = 'Hands', colour = function() return G.C.GREEN end, order = 5, needs_run = true,
    build = build,
    wheel = function(y)
        local s = CS.state.hands
        local pages = CS.view.hands_pages or 1
        if pages <= 1 then return end
        s.page = s.page + (y > 0 and -1 or 1)
        if s.page < 1 then s.page = pages elseif s.page > pages then s.page = 1 end
        refresh()
    end,
})
