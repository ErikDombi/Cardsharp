--- Edit tab: change cards you already own (selected, hovered, or whole groups).
local CS = Cardsharp
local UI, A = CS.UI, CS.A
local R, C = G.UIT.R, G.UIT.C

local ACCENT = function() return G.C.PURPLE end
local VALUES_PER_PAGE = 7

local function card_label(c)
    if CS.is_playing_card(c) and c.base and c.base.value then
        return ('%s of %s'):format(CS.loc_or(c.base.value, c.base.value, 'ranks'), CS.loc_or(c.base.suit, c.base.suit, 'suits_plural'))
    end
    return CS.name_of(c.config and c.config.center)
end

local function summary()
    local t = A.targets()
    local scope = CS.state.edit.scope
    if #t == 0 then
        if scope == 'selected' then return 'Nothing selected - close the menu, click cards to select them, then reopen' end
        if scope == 'focus' then return 'The hovered card is gone' end
        return 'There are no cards in this group'
    end
    local names = {}
    for i = 1, math.min(3, #t) do names[i] = card_label(t[i]) end
    local more = #t > 3 and (', +' .. (#t - 3) .. ' more') or ''
    return ('%d card%s: %s%s'):format(#t, #t == 1 and '' or 's', table.concat(names, ', '), more)
end

local function with_targets(fn)
    return function()
        fn(A.targets())
        UI.replace('cshp_edit_values', CS.edit_values_panel)
    end
end

function CS.edit_values_panel()
    local W, H = 6.2, 5.0
    local t = A.targets()
    local function wrap(nodes) return UI.root({ UI.col(nodes, { align = 'tm' }) }, { minw = W, minh = H, align = 'tm' }) end
    if #t ~= 1 then
        CS.state.edit.value_card = nil
        return wrap({ UI.notice('Pick exactly one card', {
            'Target a single card to edit',
            'its numbers - e.g. the mult a',
            'scaling joker has built up.',
        }) })
    end
    local card = t[1]
    if CS.state.edit.value_card ~= card then CS.state.edit.value_page = 1 end
    CS.state.edit.value_card = card
    local fields = A.value_fields(card)
    local nodes = { UI.row({ UI.text(card_label(card), 0.38, G.C.UI.TEXT_LIGHT, { maxw = W - 0.3 }) }, { padding = 0.05 }) }
    if #fields == 0 then
        nodes[#nodes + 1] = UI.notice('No editable numbers', { 'This card has no numeric values.' })
        return wrap(nodes)
    end
    local pages = math.max(1, math.ceil(#fields / VALUES_PER_PAGE))
    local page = CS.clamp(CS.state.edit.value_page or 1, 1, pages)
    CS.state.edit.value_page = page
    for i = (page - 1) * VALUES_PER_PAGE + 1, math.min(#fields, page * VALUES_PER_PAGE) do
        local f = fields[i]
        nodes[#nodes + 1] = UI.stepper({
            label = f.label, label_w = 1.95, value_w = 1.35, btn_w = 0.52, colour = G.C.FILTER,
            get = function() return CS.fmt(f.tbl[f.key]) end,
            buttons = {
                { '/2', function() A.change_value(f, 'mul', 0.5) end },
                { '-1', function() A.change_value(f, 'add', -1 * CS.step_mult()) end },
                { '+1', function() A.change_value(f, 'add', 1 * CS.step_mult()) end },
                { 'x2', function() A.change_value(f, 'mul', 2) end },
            },
        })
    end
    if pages > 1 then
        nodes[#nodes + 1] = UI.row({
            UI.button({ label = '<', w = 0.55, h = 0.38, scale = 0.3, colour = ACCENT(), on_click = function()
                CS.state.edit.value_page = page == 1 and pages or page - 1
                UI.replace('cshp_edit_values', CS.edit_values_panel)
            end }),
            { n = C, config = { align = 'cm', minw = 1.6 }, nodes = { UI.text(('%d / %d'):format(page, pages), 0.3) } },
            UI.button({ label = '>', w = 0.55, h = 0.38, scale = 0.3, colour = ACCENT(), on_click = function()
                CS.state.edit.value_page = page == pages and 1 or page + 1
                UI.replace('cshp_edit_values', CS.edit_values_panel)
            end }),
        }, { padding = 0.05 })
    end
    nodes[#nodes + 1] = UI.row({ UI.text('Shift-click for +/-10', 0.24, UI.muted()) }, { padding = 0.04 })
    return wrap(nodes)
end

local function build()
    local e = CS.state.edit
    local reg = CS.registry()
    if e.scope == 'focus' and not A.focus_valid() then e.scope = 'selected' end

    -- Scope chips
    local scopes = {
        { key = 'selected', label = function() return ('Selected (%d)'):format(#A.targets('selected')) end },
    }
    if A.focus_valid() then scopes[#scopes + 1] = { key = 'focus', label = 'Hovered card' } end
    scopes[#scopes + 1] = { key = 'hand', label = function() return ('Hand (%d)'):format(#G.hand.cards) end }
    scopes[#scopes + 1] = { key = 'jokers', label = function() return ('Jokers (%d)'):format(#G.jokers.cards) end }
    scopes[#scopes + 1] = { key = 'consumables', label = function() return ('Consumables (%d)'):format(#G.consumeables.cards) end }
    scopes[#scopes + 1] = { key = 'deck', label = function() return ('Entire deck (%d)'):format(#G.playing_cards) end }
    local scope_row = UI.section({
        title = 'APPLY TO', colour = ACCENT(), w = 18.4, align = 'cm',
        nodes = { UI.col({
            UI.radio(scopes, e, 'scope', { per_row = 6, w = 2.5, h = 0.44, scale = 0.3, colour = ACCENT(), on_change = function()
                UI.replace('cshp_edit_values', CS.edit_values_panel)
            end }),
            UI.row({ UI.live(summary, 0.3, G.C.UI.TEXT_LIGHT, { maxw = 17.5 }) }, { padding = 0.04 }),
        }) },
    })

    local function action_buttons(items, id, per_row, max_rows)
        return UI.group(items, function(it, w, h)
            return UI.button({ label = it.label, colour = it.colour, w = w, h = h, scale = 0.29,
                tooltip = it.tooltip, on_click = with_targets(it.fn) })
        end, { per_row = per_row or 4, max_rows = max_rows or 2, width = 5.6, h = 0.42, id = 'edit_' .. id })
    end

    -- Column A: edition / enhancement / seal
    local eds = { { label = 'None', colour = G.C.GREY, fn = function(t) A.set_edition(t, 'none') end } }
    for _, ed in ipairs(reg.editions) do eds[#eds + 1] = { label = ed.label, colour = ed.colour, fn = function(t) A.set_edition(t, ed.key) end } end
    local enhs = { { label = 'None', colour = G.C.GREY, fn = function(t) A.set_enhancement(t, 'none') end } }
    for _, en in ipairs(reg.enhancements) do enhs[#enhs + 1] = { label = en.label, colour = en.colour, fn = function(t) A.set_enhancement(t, en.key) end } end
    local seals = { { label = 'None', colour = G.C.GREY, fn = function(t) A.set_seal(t, 'none') end } }
    for _, s in ipairs(reg.seals) do seals[#seals + 1] = { label = s.label, colour = s.colour, fn = function(t) A.set_seal(t, s.key) end } end

    local col_a = UI.col({
        UI.row({ UI.section({ title = 'EDITION', colour = ACCENT(), w = 5.8, nodes = { action_buttons(eds, 'ed', 4, 2) } }) }, { padding = 0.03 }),
        UI.row({ UI.section({ title = 'ENHANCEMENT', subtitle = 'playing cards', colour = ACCENT(), w = 5.8, nodes = { action_buttons(enhs, 'enh', 4, 3) } }) }, { padding = 0.03 }),
        UI.row({ UI.section({ title = 'SEAL', subtitle = 'playing cards', colour = ACCENT(), w = 5.8, nodes = { action_buttons(seals, 'seal', 4, 2) } }) }, { padding = 0.03 }),
    }, { align = 'tm' })

    -- Column B: stickers / rank & suit / actions
    local stickers = {}
    for _, st in ipairs(reg.stickers) do
        stickers[#stickers + 1] = { label = st.label, colour = st.colour, fn = function(t) A.toggle_sticker(t, st.key) end,
            tooltip = { text = { 'Adds it to every target,', 'or removes it if all have it' } } }
    end
    local suit_buttons = {
        { label = 'Rank -1', colour = G.C.BLUE, fn = function(t) A.shift_rank(t, -1) end },
        { label = 'Rank +1', colour = G.C.BLUE, fn = function(t) A.shift_rank(t, 1) end },
    }
    for _, s in ipairs(reg.suits) do
        suit_buttons[#suit_buttons + 1] = { label = s.label, colour = CS.suit_colour(s.key), fn = function(t) A.set_suit(t, s.key) end }
    end

    local actions = UI.col({
        UI.row({
            UI.button({ label = 'Duplicate', colour = G.C.GREEN, w = 1.75, h = 0.42, scale = 0.3, on_click = with_targets(A.duplicate) }),
            UI.confirm_button({ label = 'Destroy', colour = G.C.RED, w = 1.75, h = 0.42, scale = 0.3, on_click = with_targets(A.destroy) }),
            UI.button({ label = 'Flip', colour = G.C.BLUE, w = 1.75, h = 0.42, scale = 0.3, on_click = with_targets(A.flip) }),
        }, { padding = 0.04 }),
        UI.row({
            UI.button({ label = 'Debuff', colour = G.C.RED, w = 1.75, h = 0.42, scale = 0.3, on_click = with_targets(function(t) A.set_debuff(t, true) end) }),
            UI.button({ label = 'Undebuff', colour = G.C.GREEN, w = 1.75, h = 0.42, scale = 0.3, on_click = with_targets(function(t) A.set_debuff(t, false) end) }),
            UI.button({ label = 'Sell +$5', colour = G.C.MONEY, w = 1.75, h = 0.42, scale = 0.3, on_click = with_targets(function(t) A.add_sell_value(t, 5 * CS.step_mult()) end) }),
        }, { padding = 0.04 }),
    })

    local col_b = UI.col({
        UI.row({ UI.section({ title = 'STICKERS', subtitle = 'toggle', colour = ACCENT(), w = 5.8, nodes = { action_buttons(stickers, 'st', 3, 2) } }) }, { padding = 0.03 }),
        UI.row({ UI.section({ title = 'RANK & SUIT', subtitle = 'playing cards', colour = ACCENT(), w = 5.8, nodes = { action_buttons(suit_buttons, 'suit', 4, 2) } }) }, { padding = 0.03 }),
        UI.row({ UI.section({ title = 'ACTIONS', colour = ACCENT(), w = 5.8, nodes = { actions } }) }, { padding = 0.03 }),
    }, { align = 'tm' })

    local col_c = UI.section({
        title = 'NUMBERS', subtitle = 'single card', colour = ACCENT(), w = 6.2, h = 5.45, align = 'tm',
        nodes = { UI.slot('cshp_edit_values', CS.edit_values_panel, { minw = 6.2, minh = 5.0 }) },
    })

    return UI.col({
        UI.row({ scope_row }, { padding = 0.02 }),
        UI.row({ col_a, col_b, col_c }, { align = 'tm', padding = 0.03 }),
    }, { align = 'tm' })
end

CS.register_tab({
    id = 'edit', label = 'Edit', colour = function() return G.C.PURPLE end, order = 3, needs_run = true,
    build = build,
})
