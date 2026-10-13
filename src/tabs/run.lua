--- Run tab: every number that defines the current run.
local CS = Cardsharp
local UI, A = CS.UI, CS.A

local COL_W = 5.95

local function G_() return G.GAME end

local function stat(a)
    a.label_w = a.label_w or 1.9
    a.value_w = a.value_w or 1.3
    a.btn_w = a.btn_w or 0.54
    return UI.stepper(a)
end

local function round_section()
    return UI.section({ title = 'THIS ROUND', colour = G.C.ORANGE, w = COL_W, h = 5.2, align = 'tm', nodes = { UI.col({
        stat({ label = 'Money', colour = G.C.MONEY, steps = { 10, 100 },
            get = function() return '$' .. CS.fmt(G_().dollars) end,
            add = A.add_money }),
        stat({ label = 'Hands left', colour = G.C.BLUE, steps = { 1, 5 },
            get = function() return G_().current_round.hands_left end,
            add = A.add_hands }),
        stat({ label = 'Discards left', colour = G.C.RED, steps = { 1, 5 },
            get = function() return G_().current_round.discards_left end,
            add = A.add_discards }),
        stat({ label = 'Score', colour = G.C.UI.TEXT_LIGHT,
            tooltip = { text = { 'Chips scored so far this blind.', '"Goal" sets it to the blind\'s', 'requirement - play any hand to win.' } },
            get = function() return CS.fmt(G_().chips) end,
            buttons = {
                { '0', function() A.set_score(0) end },
                { '/2', function() A.set_score(CS.num(G_().chips) / 2) end },
                { 'x2', function() A.set_score(math.max(1, CS.num(G_().chips)) * 2) end },
                { 'Goal', function()
                    if not CS.in_blind() then return CS.warn('No blind is active right now') end
                    A.set_score(CS.num(G_().blind.chips))
                end },
            } }),
        stat({ label = 'Blind goal', colour = G.C.RED, enabled = CS.in_blind,
            tooltip = { text = { 'Chips needed to beat', 'the current blind' } },
            get = function() return CS.in_blind() and CS.fmt(G_().blind.chips) or '-' end,
            buttons = {
                { '=1', function() A.set_blind_target(1) end },
                { '/2', function() A.set_blind_target(CS.num(G_().blind.chips) / 2) end },
                { 'x2', function() A.set_blind_target(CS.num(G_().blind.chips) * 2) end },
                { 'x10', function() A.set_blind_target(CS.num(G_().blind.chips) * 10) end },
            } }),
    }, { align = 'tm' }) } })
end

local function run_section()
    return UI.section({ title = 'RUN', colour = G.C.ORANGE, w = COL_W, h = 5.2, align = 'tm', nodes = { UI.col({
        stat({ label = 'Ante', colour = G.C.FILTER, steps = { 1, 5 },
            get = function() return CS.fmt(G_().round_resets.ante) .. ' / ' .. CS.fmt(G_().win_ante) end,
            add = A.add_ante }),
        stat({ label = 'Round', colour = G.C.FILTER, steps = { 1, 5 },
            get = function() return CS.fmt(G_().round) end,
            add = A.add_round }),
        stat({ label = 'Winning ante', colour = G.C.FILTER, steps = { 1, 4 },
            tooltip = { text = { 'Beat this ante\'s boss to win', '(vanilla: 8)' } },
            get = function() return G_().win_ante end,
            add = function(d) G_().win_ante = math.max(1, G_().win_ante + d) end }),
        stat({ label = 'Hands / round', colour = G.C.BLUE, steps = { 1, 5 },
            tooltip = { text = { 'Applies from the next blind' } },
            get = function() return G_().round_resets.hands end,
            add = function(d) G_().round_resets.hands = math.max(1, G_().round_resets.hands + d) end }),
        stat({ label = 'Discards / rnd', colour = G.C.RED, steps = { 1, 5 },
            tooltip = { text = { 'Applies from the next blind' } },
            get = function() return G_().round_resets.discards end,
            add = function(d) G_().round_resets.discards = math.max(0, G_().round_resets.discards + d) end }),
        stat({ label = 'Odds boost', colour = G.C.GREEN,
            tooltip = { text = { 'Multiplies every "1 in X" chance', 'like Oops! All 6s (vanilla: x1)' } },
            get = function() return 'x' .. CS.fmt(G_().probabilities.normal) end,
            buttons = {
                { '=1', function() G_().probabilities.normal = 1 end },
                { '/2', function() G_().probabilities.normal = math.max(0.0001, G_().probabilities.normal / 2) end },
                { 'x2', function() G_().probabilities.normal = G_().probabilities.normal * 2 end },
                { 'x10', function() G_().probabilities.normal = G_().probabilities.normal * 10 end },
            } }),
        stat({ label = 'Interest cap', colour = G.C.MONEY, steps = { 5, 25 },
            tooltip = { text = { 'Money that earns interest', '(vanilla: $25 = $5 max)' } },
            get = function() return '$' .. CS.fmt(G_().interest_cap) end,
            add = function(d) G_().interest_cap = math.max(0, G_().interest_cap + d) end }),
    }, { align = 'tm' }) } })
end

local function slots_section()
    local sp = function() return G_().starting_params end
    return UI.section({ title = 'SLOTS & LIMITS', colour = G.C.ORANGE, w = COL_W, h = 5.2, align = 'tm', nodes = { UI.col({
        stat({ label = 'Hand size', colour = G.C.UI.TEXT_LIGHT, steps = { 1, 5 },
            get = function() return G.hand.config.card_limit end,
            add = function(d) A.resize(G.hand, d, 1) end }),
        stat({ label = 'Joker slots', colour = G.C.UI.TEXT_LIGHT, steps = { 1, 5 },
            get = function() return G.jokers.config.card_limit end,
            add = function(d) A.resize(G.jokers, d, 0) end }),
        stat({ label = 'Consumable slots', colour = G.C.UI.TEXT_LIGHT, steps = { 1, 5 },
            get = function() return G.consumeables.config.card_limit end,
            add = function(d) A.resize(G.consumeables, d, 0) end }),
        stat({ label = 'Cards per play', colour = G.C.BLUE, steps = { 1, 5 },
            tooltip = { text = { 'Most cards you can play', 'in one hand (vanilla: 5)' } },
            get = function() return sp().play_limit or 5 end,
            add = function(d) SMODS.change_play_limit(math.max(d, 1 - (sp().play_limit or 5))) end }),
        stat({ label = 'Cards per discard', colour = G.C.RED, steps = { 1, 5 },
            get = function() return sp().discard_limit or 5 end,
            add = function(d) SMODS.change_discard_limit(math.max(d, 1 - (sp().discard_limit or 5))) end }),
        stat({ label = 'Shop card slots', colour = G.C.GREEN, steps = { 1, 2 },
            get = function() return G_().shop and G_().shop.joker_max or '-' end,
            add = A.add_shop_slots }),
        stat({ label = 'Shop vouchers', colour = G.C.GREEN, steps = { 1, 2 },
            get = function() return (sp().vouchers_in_shop or 1) + (G_().modifiers.extra_vouchers or 0) end,
            add = function(d)
                local cur = (sp().vouchers_in_shop or 1) + (G_().modifiers.extra_vouchers or 0)
                A.ensure_shop_rates()
                SMODS.change_voucher_limit(math.max(d, -cur))
            end }),
        stat({ label = 'Shop boosters', colour = G.C.GREEN, steps = { 1, 2 },
            get = function() return (sp().boosters_in_shop or 2) + (G_().modifiers.extra_boosters or 0) end,
            add = function(d)
                local cur = (sp().boosters_in_shop or 2) + (G_().modifiers.extra_boosters or 0)
                A.ensure_shop_rates()
                SMODS.change_booster_limit(math.max(d, -cur))
            end }),
        stat({ label = 'Reroll cost', colour = G.C.MONEY, steps = { 1, 5 },
            tooltip = { text = { 'Base cost of a shop reroll', '(vanilla: $5)' } },
            get = function() return '$' .. CS.fmt(G_().current_round.reroll_cost) end,
            add = A.add_reroll_cost }),
    }, { align = 'tm' }) } })
end

local function quick_actions()
    local function b(label, colour, f, extra)
        local a = { label = label, colour = colour, w = 2.85, h = 0.62, scale = 0.34, on_click = f }
        if extra then for k, v in pairs(extra) do a[k] = v end end
        return UI.button(a)
    end
    return UI.section({ title = 'QUICK ACTIONS', colour = G.C.ORANGE, w = 18.4, align = 'cm', nodes = {
        b('Win blind', G.C.GREEN, A.win_blind, { sub = 'instantly', enabled = function() return CS.state_is('SELECTING_HAND') end }),
        UI.spacer(0.06),
        b('Win run', G.C.MONEY, A.win_run, { sub = 'trigger the win screen' }),
        UI.spacer(0.06),
        b('Reroll shop', G.C.GREEN, A.reroll_shop, { sub = 'for free', enabled = function() return CS.state_is('SHOP') end }),
        UI.spacer(0.06),
        b('Reroll boss', G.C.GREEN, A.reroll_boss, { sub = 'for free', enabled = function() return CS.state_is('BLIND_SELECT') end }),
        UI.spacer(0.06),
        b('+$1,000', G.C.MONEY, function() A.add_money(1000) end, { sub = 'pocket money' }),
        UI.spacer(0.06),
        b('Full refill', G.C.BLUE, function()
            A.add_hands(G_().round_resets.hands - G_().current_round.hands_left)
            A.add_discards(G_().round_resets.discards - G_().current_round.discards_left)
            CS.toast('Hands and discards refilled', G.C.BLUE, false)
        end, { sub = 'hands & discards' }),
    } })
end

local function build()
    return UI.col({
        UI.row({ round_section(), run_section(), slots_section() }, { align = 'tm', padding = 0.05 }),
        UI.row({ quick_actions() }, { padding = 0.05 }),
        UI.row({ UI.text('Tip: hold Shift while clicking a +/- button for 10x the step.', 0.26, UI.muted()) }, { padding = 0.02 }),
    }, { align = 'tm' })
end

CS.register_tab({
    id = 'run', label = 'Run', colour = function() return G.C.ORANGE end, order = 4, needs_run = true,
    build = build,
})
