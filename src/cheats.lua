--- Persistent cheats. Each one is a thin wrapper around a single game function.
local CS = Cardsharp

CS.CHEATS = {
    { key = 'inf_hands', title = 'Infinite Hands', desc = { 'Playing a hand never', 'uses one up' }, colour = 'BLUE' },
    { key = 'inf_discards', title = 'Infinite Discards', desc = { 'Discarding never', 'uses one up' }, colour = 'RED' },
    { key = 'money_lock', title = 'Money Lock', desc = { 'Your money can only', 'go up, never down' }, colour = 'MONEY' },
    { key = 'free_shop', title = 'Free Shop', desc = { 'Every shop item,', 'pack and voucher is $0' }, colour = 'GREEN' },
    { key = 'free_rerolls', title = 'Free Rerolls', desc = { 'Rerolling the shop', 'costs nothing' }, colour = 'GREEN' },
    { key = 'never_lose', title = 'Never Lose', desc = { 'Running out of hands', 'still beats the blind' }, colour = 'PURPLE' },
    { key = 'rigged_odds', title = 'Rigged Odds', desc = { 'Every "1 in X" roll hits', '(bad ones too, like Glass)' }, colour = 'CHANCE' },
    { key = 'no_debuffs', title = 'No Debuffs', desc = { 'Bosses and effects', "can't debuff your cards" }, colour = 'FILTER' },
}

function CS.cheat_on(key)
    return CS.config.cheats[key] and not CS.bypass
end

function CS.active_cheats()
    local n = 0
    for _, c in ipairs(CS.CHEATS) do if CS.config.cheats[c.key] then n = n + 1 end end
    return n
end

-------------------------------------------------------------------------------
-- Hooks (installed once, so the module can be hot-reloaded)
-------------------------------------------------------------------------------
if not CS._cheat_hooks then
    CS._cheat_hooks = true

    local ease_hands_ref = ease_hands_played
    function ease_hands_played(mod, ...)
        if CS.cheat_on('inf_hands') and CS.num(mod) < 0 then return end
        return ease_hands_ref(mod, ...)
    end

    local ease_discard_ref = ease_discard
    function ease_discard(mod, ...)
        if CS.cheat_on('inf_discards') and CS.num(mod) < 0 then return end
        return ease_discard_ref(mod, ...)
    end

    local ease_dollars_ref = ease_dollars
    function ease_dollars(mod, ...)
        if CS.cheat_on('money_lock') and CS.num(mod) < 0 then return end
        return ease_dollars_ref(mod, ...)
    end

    local set_cost_ref = Card.set_cost
    function Card:set_cost(...)
        local ret = set_cost_ref(self, ...)
        if CS.config.cheats.free_shop then self.cost = 0 end
        return ret
    end

    local reroll_cost_ref = calculate_reroll_cost
    function calculate_reroll_cost(...)
        local ret = reroll_cost_ref(...)
        if CS.config.cheats.free_rerolls and G.GAME and G.GAME.current_round then
            G.GAME.current_round.reroll_cost = 0
        end
        return ret
    end

    local end_round_ref = end_round
    function end_round(...)
        if CS.cheat_on('never_lose') and G.GAME and G.GAME.blind and CS.num(G.GAME.chips) < CS.num(G.GAME.blind.chips) then
            G.GAME.chips = G.GAME.blind.chips
            G.GAME.chips_text = number_format(G.GAME.chips)
        end
        return end_round_ref(...)
    end

    if SMODS.pseudorandom_probability then
        local prob_ref = SMODS.pseudorandom_probability
        function SMODS.pseudorandom_probability(...)
            local result = prob_ref(...)
            if CS.cheat_on('rigged_odds') then
                local last = SMODS.post_prob and SMODS.post_prob[#SMODS.post_prob]
                if last then last.result = true end
                return true
            end
            return result
        end
    end

end

-- Steamodded asks every mod's set_debuff(card); 'prevent_debuff' beats all debuff sources.
CS.mod.set_debuff = function(card)
    if CS.config.cheats.no_debuffs then return 'prevent_debuff' end
end

-------------------------------------------------------------------------------
-- Toggling
-------------------------------------------------------------------------------
local function refresh_costs()
    for _, v in pairs(G.I.CARD or {}) do
        if v.set_cost and v.ability then pcall(v.set_cost, v) end
    end
end

local function refresh_debuffs()
    if not (CS.in_run() and G.GAME.blind and SMODS.recalc_debuff) then return end
    local cards = {}
    for _, c in ipairs(G.playing_cards or {}) do cards[#cards + 1] = c end
    for _, c in ipairs(G.jokers.cards or {}) do cards[#cards + 1] = c end
    for _, c in ipairs(G.consumeables.cards or {}) do cards[#cards + 1] = c end
    for _, c in ipairs(cards) do pcall(SMODS.recalc_debuff, c) end
end

function CS.set_cheat(key, value)
    CS.config.cheats[key] = value and true or false
    CS.save_config()
    if CS.in_run() then
        if key == 'free_shop' then refresh_costs()
        elseif key == 'free_rerolls' then pcall(calculate_reroll_cost, true)
        elseif key == 'no_debuffs' then refresh_debuffs()
        end
    end
    local def
    for _, c in ipairs(CS.CHEATS) do if c.key == key then def = c end end
    CS.toast(('%s %s'):format(def and def.title or key, value and 'ON' or 'OFF'), value and G.C.GREEN or G.C.UI.TEXT_LIGHT, value and 'generic1' or 'cancel')
end

function CS.all_cheats_off()
    for _, c in ipairs(CS.CHEATS) do
        if CS.config.cheats[c.key] then
            CS.config.cheats[c.key] = false
        end
    end
    CS.save_config()
    if CS.in_run() then
        refresh_costs()
        pcall(calculate_reroll_cost, true)
        refresh_debuffs()
    end
    CS.toast('All cheats off', G.C.UI.TEXT_LIGHT, 'cancel')
end
