--- Blinds tab: control the current blind and choose this ante's boss.
local CS = Cardsharp
local UI, A = CS.UI, CS.A
local R, C, O = G.UIT.R, G.UIT.C, G.UIT.O

local ACCENT = function() return G.C.BOOSTER end
local COLS, ROWS, CHIP = 7, 3, 1.15
local GRID_W, GRID_H = 11.8, 5.9

local function boss_list()
    local filter = CS.state.blinds.filter or 'all'
    local out = {}
    for _, v in ipairs(SMODS.collection_pool(G.P_BLINDS)) do
        if v.boss then
            local showdown = v.boss.showdown and true or false
            if filter == 'all' or (filter == 'showdown') == showdown then out[#out + 1] = v end
        end
    end
    return out
end

local function current_boss_key()
    return G.GAME and G.GAME.round_resets and G.GAME.round_resets.blind_choices and G.GAME.round_resets.blind_choices.Boss
end

local build_grid

local function refresh_grid() UI.replace('cshp_boss_grid', build_grid) end

local function blind_card(area, v)
    local sprite = SMODS.create_sprite(area.T.x + area.T.w / 2, area.T.y, CHIP, CHIP, v.atlas or 'blind_chips', v.pos, v.sprite_args)
    sprite.states.click.can = false
    sprite.states.drag.can = false
    sprite.states.hover.can = true
    local card = Card(area.T.x + area.T.w / 2, area.T.y, CHIP, CHIP, G.P_CARDS.empty, G.P_CENTERS.c_base)
    card.states.drag.can = false
    card.states.hover.can = true
    card.states.collide.can = true
    card.children.center = sprite
    sprite:set_role({ major = card, role_type = 'Glued', draw_major = card })
    card.set_sprites = function(...)
        local args = { ... }
        if not args[1].animation then return end
        local keep = card.children.center
        Card.set_sprites(...)
        card.children.center = keep
    end
    sprite:define_draw_steps({ { shader = 'dissolve', shadow_height = 0.05 }, { shader = 'dissolve' } })
    sprite.float = true
    card.config.blind = v
    card.config.force_focus = true
    card.hover = function()
        if not G.CONTROLLER.dragging.target or G.CONTROLLER.using_touch then
            if not card.hovering and card.states.visible then
                card.hovering = true
                card.hover_tilt = 3
                card:juice_up(0.05, 0.02)
                play_sound('chips1', math.random() * 0.1 + 0.55, 0.12)
                card.config.h_popup = create_UIBox_blind_popup(v, true)
                card.config.h_popup_config = card:align_h_popup()
                Node.hover(card)
            end
        end
        card.stop_hover = function()
            card.hovering = false
            Node.stop_hover(card)
            card.hover_tilt = 0
        end
    end
    card.click = function()
        CS.safe(A.set_boss, v.key)
        refresh_grid()
    end
    return card
end

build_grid = function()
    local s = CS.state.blinds
    local list = boss_list()
    local per = COLS * ROWS
    local pages = math.max(1, math.ceil(#list / per))
    s.page = CS.clamp(s.page or 1, 1, pages)
    CS.view.blind_pages = pages
    local first = (s.page - 1) * per
    local current = current_boss_key()
    local marked = {}

    local rows = {}
    for r = 1, ROWS do
        local area = CardArea(G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2, G.ROOM.T.h, COLS * 1.6, CHIP * 1.3,
            { card_limit = COLS, type = 'title_2', highlight_limit = 0 })
        for c = 1, COLS do
            local v = list[first + (r - 1) * COLS + c]
            if v then
                local card = blind_card(area, v)
                area:emplace(card)
                if v.key == current then marked[#marked + 1] = card end
            end
        end
        rows[#rows + 1] = { n = R, config = { align = 'cm', padding = 0.02, no_fill = true }, nodes = { { n = O, config = { object = area } } } }
    end

    G.E_MANAGER:add_event(Event({ trigger = 'immediate', blockable = false, blocking = false, func = function()
        for _, card in ipairs(marked) do
            if not card.REMOVED then
                card.children.alert = UIBox({
                    definition = create_UIBox_card_alert({ text = 'NOW', bg_col = G.C.GREEN, scale = 0.34, text_rot = 0.15 }),
                    config = { align = 'tri', offset = { x = 0.15, y = 0.1 }, parent = card },
                })
                card.children.alert.states.collide.can = false
            end
        end
        return true
    end }))

    if #list == 0 then
        return UI.root({ UI.notice('No bosses match', { 'Try a different filter.' }) }, { minw = GRID_W, minh = GRID_H })
    end
    return UI.root({ UI.col(rows) }, { minw = GRID_W, minh = GRID_H })
end

local function turn_page(d)
    local s = CS.state.blinds
    local pages = CS.view.blind_pages or 1
    if pages <= 1 then return end
    s.page = s.page + d
    if s.page < 1 then s.page = pages elseif s.page > pages then s.page = 1 end
    CS.sfx('paper1', 0.95, 0.5)
    refresh_grid()
end

local function info_line(label, get, colour)
    return UI.row({
        { n = C, config = { align = 'cl', minw = 1.9 }, nodes = { UI.text(label, 0.3, UI.muted()) } },
        UI.pill(get, colour, 3.0, 0.42, 0.32),
    }, { padding = 0.03 })
end

local function current_panel()
    local function b(label, sub, colour, f, enabled, confirm)
        local args = { label = label, sub = sub, colour = colour, w = 4.95, h = 0.6, scale = 0.34, enabled = enabled, on_click = f }
        return UI.row({ confirm and UI.confirm_button(args) or UI.button(args) }, { padding = 0.04 })
    end
    local blind = function() return G.GAME.blind end
    return UI.section({ title = 'CURRENT BLIND', colour = ACCENT(), w = 5.6, h = 7.5, align = 'tm', nodes = { UI.col({
        info_line('Blind', function()
            if not CS.in_blind() then return 'Not in a blind' end
            local b = blind()
            local name = CS.blind_name(b.config.blind)
            return b.disabled and (name .. ' (disabled)') or name
        end, G.C.UI.TEXT_LIGHT),
        info_line('Goal', function() return CS.in_blind() and CS.fmt(blind().chips) or '-' end, G.C.RED),
        info_line('Reward', function() return CS.in_blind() and ('$' .. CS.fmt(blind().dollars)) or '-' end, G.C.MONEY),
        info_line('Ante boss', function()
            local key = current_boss_key()
            return key and G.P_BLINDS[key] and CS.blind_name(G.P_BLINDS[key]) or '-'
        end, G.C.FILTER),
        UI.row({ UI.spacer(0.1, 0.12) }),
        b('Win blind', 'skip straight to cash-out', G.C.GREEN, A.win_blind, function() return CS.state_is('SELECTING_HAND') end),
        b('Disable boss ability', 'like Chicot or Luchador', G.C.PURPLE, A.disable_boss,
            function() return CS.in_blind() and G.GAME.blind.boss and not G.GAME.blind.disabled end),
        b('Halve the goal', nil, G.C.RED, function() A.set_blind_target(CS.num(blind().chips) / 2) end, CS.in_blind),
        b('Goal = 1 chip', 'any hand wins', G.C.RED, function() A.set_blind_target(1) end, CS.in_blind),
        b('Reroll boss', 'free, at blind select', G.C.GREEN, function() A.reroll_boss(); refresh_grid() end,
            function() return CS.state_is('BLIND_SELECT') end),
    }, { align = 'tm' }) } })
end

local function build()
    local s = CS.state.blinds
    s.filter = s.filter or 'all'
    return UI.row({
        current_panel(),
        UI.section({ title = 'BOSS BLINDS', subtitle = "click one to make it this ante's boss", colour = ACCENT(), w = 12.6, h = 7.5, align = 'tm', nodes = { UI.col({
            UI.row({
                UI.cycler({ w = 2.6, colour = ACCENT(),
                    options = { { key = 'all', label = 'All bosses' }, { key = 'regular', label = 'Regular bosses' }, { key = 'showdown', label = 'Showdown (final)' } },
                    get = function() return s.filter end,
                    set = function(k) s.filter = k; s.page = 1; refresh_grid() end }),
            }, { padding = 0.04 }),
            UI.row({ UI.slot('cshp_boss_grid', build_grid, { minw = GRID_W, minh = GRID_H }) }),
            UI.row({
                UI.button({ label = '<', w = 0.6, h = 0.4, scale = 0.34, colour = ACCENT(), on_click = function() turn_page(-1) end }),
                { n = C, config = { align = 'cm', minw = 2.4 }, nodes = { UI.live(function() return ('Page %d / %d'):format(s.page or 1, CS.view.blind_pages or 1) end, 0.3) } },
                UI.button({ label = '>', w = 0.6, h = 0.4, scale = 0.34, colour = ACCENT(), on_click = function() turn_page(1) end }),
            }, { padding = 0.03 }),
        }, { align = 'tm' }) } }),
    }, { align = 'tm', padding = 0.05 })
end

CS.register_tab({
    id = 'blinds', label = 'Blinds', colour = function() return G.C.BOOSTER end, order = 6, needs_run = true,
    build = build,
    wheel = function(y) turn_page(y > 0 and -1 or 1) end,
})
