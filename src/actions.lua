--- Everything that actually changes the game lives here, so tabs stay purely presentational.
local CS = Cardsharp
local A = {}
CS.A = A

--- Runs f with cheats bypassed (so e.g. "money lock" doesn't block our own -$ edits).
function A.bypass(f, ...)
    local prev = CS.bypass
    CS.bypass = true
    local ok, err = pcall(f, ...)
    CS.bypass = prev
    if not ok then error(err, 0) end
end

local function need_run()
    if CS.in_run() then return true end
    CS.warn('Start or continue a run first')
    return false
end

local function plural(n, word) return n .. ' ' .. word .. (n == 1 and '' or 's') end

-------------------------------------------------------------------------------
-- Spawning
-------------------------------------------------------------------------------
function A.spawn_modifiers()
    local s = CS.state.spawn
    local stickers = {}
    for k, v in pairs(s.stickers) do if v then stickers[#stickers + 1] = k end end
    table.sort(stickers)
    return { edition = (s.edition ~= 'none') and s.edition or nil, stickers = stickers }
end

local function shop_open()
    return CS.state_is('SHOP') and G.shop_jokers ~= nil and G.shop ~= nil
end

--- Runs started before a mod was installed lack that mod's poker hands and shop rates, and
--- crash as soon as the mod looks them up (e.g. Paperback at round end, or any shop restock).
--- Copy only the *missing* entries from a freshly built game object.
local BIG_HAND_FIELDS = { 'chips', 'mult', 's_chips', 's_mult', 'l_chips', 'l_mult', 'level' }
function A.repair_run()
    if not (G.GAME and G.GAME.hands) then return {} end
    local ok, fresh = pcall(G.init_game_object, G)
    if not ok or type(fresh) ~= 'table' then return {} end
    local sample = G.GAME.hands['High Card'] or select(2, next(G.GAME.hands))
    local wants_big = sample and type(sample.chips) ~= 'number'
    local fixed = {}
    for key, hand in pairs(fresh.hands or {}) do
        if G.GAME.hands[key] == nil then
            if wants_big then
                for _, f in ipairs(BIG_HAND_FIELDS) do
                    if type(hand[f]) == 'number' then hand[f] = CS.big(hand[f]) end
                end
            end
            G.GAME.hands[key] = hand
            fixed[#fixed + 1] = 'hand ' .. key
        end
    end
    for key, value in pairs(fresh) do
        if type(key) == 'string' and key:sub(-5) == '_rate' and G.GAME[key] == nil then
            G.GAME[key] = value
            fixed[#fixed + 1] = key
        end
    end
    if #fixed > 0 then CS.log('Repaired run (added missing): ' .. table.concat(fixed, ', ')) end
    local dropped = A.clean_used_marks()
    if dropped > 0 then fixed[#fixed + 1] = dropped .. ' stale "owned" marks' end
    return fixed
end

--- The game marks a card key as "used" while a copy exists, which keeps it out of shops and packs,
--- and clears the mark when the last copy is removed. Cardsharp 1.0 built its preview cards before
--- the game counted the menu as open, so previews could leave marks behind for the rest of a run.
--- Drop any mark that no card anywhere in play accounts for.
function A.clean_used_marks()
    local used = G.GAME and G.GAME.used_jokers
    if not used then return 0 end
    local present = {}
    for _, area in pairs(G) do
        if type(area) == 'table' and type(area.is) == 'function' and area.cards and area:is(CardArea) then
            for _, c in ipairs(area.cards) do
                local k = c.config and c.config.center and c.config.center.key
                if k then present[k] = true end
            end
        end
    end
    local dropped = {}
    for k in pairs(used) do
        local c = G.P_CENTERS[k]
        local set = c and c.set
        if c and not present[k] and set ~= 'Default' and set ~= 'Enhanced' and set ~= 'Edition' and set ~= 'Back' then
            used[k] = nil
            dropped[#dropped + 1] = k
        end
    end
    if #dropped > 0 then CS.log('Cleared stale used marks: ' .. table.concat(dropped, ', ')) end
    return #dropped
end

--- Some modpacks leave a consumable type's shop rate unset (nil), which crashes vanilla
--- create_card_for_shop on the next restock. Fill any gap with the type's own rate (or 0).
function A.ensure_shop_rates()
    if not (G.GAME and SMODS.ConsumableType) then return end
    for _, key in ipairs(SMODS.ConsumableType.ctype_buffer or SMODS.ConsumableType.obj_buffer or {}) do
        local field = key:lower() .. '_rate'
        if G.GAME[field] == nil then
            local ct = SMODS.ConsumableTypes[key]
            G.GAME[field] = (ct and ct.shop_rate) or 0
        end
    end
end

function A.add_to_shop(center, mods)
    if not shop_open() then CS.warn('Open the shop first to add items to it'); return false end
    local card = SMODS.create_card({
        key = center.key, area = G.shop_jokers, edition = mods.edition, no_edition = not mods.edition,
        stickers = mods.stickers, force_stickers = true,
    })
    create_shop_card_ui(card, card.ability.set, G.shop_jokers)
    G.shop_jokers:emplace(card)
    card:set_cost()
    card:juice_up(0.3, 0.3)
    return true
end

function A.redeem_voucher(key)
    local area = G.play
    local card = Card(area.T.x + area.T.w / 2 - G.CARD_W / 2, area.T.y + area.T.h / 2 - G.CARD_H / 2, G.CARD_W, G.CARD_H,
        G.P_CARDS.empty, G.P_CENTERS[key], { bypass_discovery_center = true, bypass_discovery_ui = true })
    card.cost = 0
    card:start_materialize()
    area:emplace(card)
    local shop_voucher = G.GAME.current_round.voucher
    -- Steamodded switches to SMODS_REDEEM_VOUCHER inside redeem(); the shop's buy flow restores
    -- the previous state afterwards, so we do the same.
    local prior_state = G.STATE
    -- Card:redeem charges self.cost; skip the "$0" popup.
    local real_ease = ease_dollars
    ease_dollars = function(mod, ...) if CS.num(mod) ~= 0 then return real_ease(mod, ...) end end
    local ok, err = pcall(card.redeem, card)
    ease_dollars = real_ease
    G.GAME.current_round.voucher = shop_voucher
    if G.STATE ~= prior_state then G.STATE = prior_state end
    G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.1, func = function()
        card:start_dissolve()
        if G.STATE == G.STATES.SMODS_REDEEM_VOUCHER then G.STATE = prior_state end
        return true
    end }))
    if not ok then error(err, 0) end
end

function A.open_booster(key)
    if not CS.state_is('SHOP', 'BLIND_SELECT') then
        CS.warn('Boosters open in the shop or at blind select (or switch to "To shop")')
        return false
    end
    CS.close()
    G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.2, func = function()
        local card = Card(G.play.T.x + G.play.T.w / 2 - G.CARD_W * 1.27 / 2, G.play.T.y + G.play.T.h / 2 - G.CARD_H * 1.27 / 2,
            G.CARD_W * 1.27, G.CARD_H * 1.27, G.P_CARDS.empty, G.P_CENTERS[key], { bypass_discovery_center = true, bypass_discovery_ui = true })
        card.cost = 0
        card.from_tag = true
        G.FUNCS.use_card({ config = { ref_table = card } })
        card:start_materialize()
        return true
    end }))
    return true
end

function A.spawn_tag(key, qty)
    if not need_run() then return end
    qty = qty or 1
    for _ = 1, qty do
        local tag = Tag(key)
        if key == 'tag_orbital' then
            local hands = {}
            for _, h in ipairs(G.handlist) do
                if G.GAME.hands[h] and SMODS.is_poker_hand_visible(h) then hands[#hands + 1] = h end
            end
            tag.ability.orbital_hand = pseudorandom_element(hands, pseudoseed('cshp_orbital')) or 'High Card'
        end
        add_tag(tag)
    end
    CS.toast(('Added %s'):format(qty > 1 and (qty .. 'x ' .. CS.name_of(G.P_TAGS[key])) or CS.name_of(G.P_TAGS[key])), G.C.GREEN, 'generic1')
end

--- Spawns `center` using the current Spawn-tab modifiers.
function A.spawn(center, qty)
    if not need_run() then return end
    local s = CS.state.spawn
    qty = qty or s.qty or 1
    if center.set == 'Tag' then return A.spawn_tag(center.key, qty) end
    local mods = A.spawn_modifiers()
    local made = 0
    for _ = 1, qty do
        if center.set == 'Voucher' then
            if s.dest == 'shop' then
                if not shop_open() then CS.warn('Open the shop first to add items to it'); break end
                SMODS.add_voucher_to_shop(center.key)
            else
                A.redeem_voucher(center.key)
            end
        elseif center.set == 'Booster' then
            if s.dest == 'shop' then
                if not shop_open() then CS.warn('Open the shop first to add items to it'); break end
                SMODS.add_booster_to_shop(center.key)
            else
                if A.open_booster(center.key) then made = 1 end
                break
            end
        elseif s.dest == 'shop' then
            if not A.add_to_shop(center, mods) then break end
        else
            SMODS.add_card({
                key = center.key, edition = mods.edition, no_edition = not mods.edition,
                stickers = mods.stickers, force_stickers = true,
            })
        end
        made = made + 1
    end
    if made > 0 then
        local name = CS.name_of(center)
        local where = (s.dest == 'shop' and ' to the shop') or (center.set == 'Voucher' and ' (redeemed)') or ''
        CS.toast(('Spawned %s%s%s'):format(made > 1 and (made .. 'x ') or '', name, where), G.C.GREEN, false)
        CS.sfx('card1', 1.05, 0.6)
        if CS.config.close_on_spawn and center.set ~= 'Booster' then CS.close() end
    end
end

-------------------------------------------------------------------------------
-- Playing card forge
-------------------------------------------------------------------------------
function A.forge(dest, spec, list)
    if not need_run() then return end
    spec = spec or CS.state.forge
    local area = dest == 'hand' and G.hand or G.deck
    local redirected = false
    if dest == 'hand' and not CS.state_is('SELECTING_HAND') then
        area = G.deck
        redirected = true
    end
    list = list or {}
    if #list == 0 then
        for _ = 1, spec.qty or 1 do list[#list + 1] = { rank = spec.rank, suit = spec.suit } end
    end
    local made = {}
    for _, rs in ipairs(list) do
        local t = {
            set = 'Base', area = area, no_edition = true,
            rank = rs.rank ~= 'random' and rs.rank or nil,
            suit = rs.suit ~= 'random' and rs.suit or nil,
        }
        if spec.enhancement ~= 'none' then t.enhancement = spec.enhancement end
        if spec.edition ~= 'none' then t.edition = spec.edition end
        if spec.seal ~= 'none' then t.seal = spec.seal end
        made[#made + 1] = SMODS.add_card(t)
    end
    if playing_card_joker_effects and #made > 0 then pcall(playing_card_joker_effects, made) end
    if area == G.hand and G.hand.sort then pcall(G.hand.sort, G.hand) end
    CS.sfx('card1', 1.1, 0.6)
    local where = area == G.hand and 'your hand' or 'your deck'
    local msg = ('Added %s to %s'):format(plural(#made, 'card'), where)
    if redirected then msg = msg .. ' (not in a blind)' end
    CS.toast(msg, G.C.BLUE, false)
end

-------------------------------------------------------------------------------
-- Editing existing cards
-------------------------------------------------------------------------------
function A.focus_valid()
    return CS.card_alive(CS.state.focus_card)
end

function A.targets(scope)
    scope = scope or CS.state.edit.scope
    local out = {}
    if not CS.in_run() then return out end
    local function add_all(list) for _, c in ipairs(list or {}) do out[#out + 1] = c end end
    if scope == 'selected' then
        for _, area in ipairs({ G.jokers, G.consumeables, G.hand }) do
            if area and area.highlighted then add_all(area.highlighted) end
        end
    elseif scope == 'focus' then
        if A.focus_valid() then out[1] = CS.state.focus_card end
    elseif scope == 'hand' then add_all(G.hand.cards)
    elseif scope == 'jokers' then add_all(G.jokers.cards)
    elseif scope == 'consumables' then add_all(G.consumeables.cards)
    elseif scope == 'deck' then add_all(G.playing_cards)
    end
    return out
end

local function each(cards, filter, fn)
    local n = 0
    for _, c in ipairs(cards) do
        if CS.card_alive(c) and (not filter or filter(c)) then
            fn(c)
            n = n + 1
        end
    end
    return n
end

local function report(n, what, colour)
    if n == 0 then
        CS.warn('Nothing to change - pick a target with matching cards')
    else
        CS.toast(('%s on %s'):format(what, plural(n, 'card')), colour or G.C.PURPLE, false)
        CS.sfx('tarot1', 1.1, 0.5)
    end
end

function A.set_edition(cards, key)
    local quiet = #cards > 4
    local n = each(cards, nil, function(c)
        c:set_edition(key ~= 'none' and key or nil, true, quiet)
        if quiet then c:juice_up(0.2, 0.2) end
    end)
    local label = key == 'none' and 'Removed edition' or ('Set ' .. CS.name_of(G.P_CENTERS[key]))
    report(n, label)
end

function A.set_enhancement(cards, key)
    local center = key == 'none' and G.P_CENTERS.c_base or G.P_CENTERS[key]
    local n = each(cards, CS.is_playing_card, function(c)
        c:set_ability(center)
        c:juice_up(0.3, 0.3)
    end)
    report(n, key == 'none' and 'Removed enhancement' or ('Set ' .. CS.name_of(center)))
end

function A.set_seal(cards, key)
    local n = each(cards, CS.is_playing_card, function(c)
        c:set_seal(key ~= 'none' and key or nil, true, true)
        c:juice_up(0.3, 0.3)
    end)
    report(n, key == 'none' and 'Removed seal' or ('Set ' .. CS.seal_name(key)))
end

function A.has_sticker(c, key)
    if key == 'pinned' then return c.pinned and true or false end
    return c.ability and c.ability[key] and true or false
end

function A.toggle_sticker(cards, key)
    local all_have = #cards > 0
    for _, c in ipairs(cards) do
        if CS.card_alive(c) and not A.has_sticker(c, key) then all_have = false break end
    end
    local n = each(cards, nil, function(c)
        if all_have then c:remove_sticker(key) else c:add_sticker(key, true) end
        c:juice_up(0.2, 0.2)
    end)
    report(n, (all_have and 'Removed ' or 'Added ') .. CS.sticker_name(key))
end

function A.shift_rank(cards, d)
    local n = each(cards, CS.is_playing_card, function(c)
        SMODS.modify_rank(c, d)
        c:juice_up(0.3, 0.3)
    end)
    report(n, d > 0 and 'Rank up' or 'Rank down', G.C.BLUE)
end

function A.set_suit(cards, suit)
    local n = each(cards, CS.is_playing_card, function(c)
        SMODS.change_base(c, suit, nil)
        c:juice_up(0.3, 0.3)
    end)
    report(n, 'Changed suit', G.C.BLUE)
end

function A.set_rank(cards, rank)
    local n = each(cards, CS.is_playing_card, function(c)
        SMODS.change_base(c, nil, rank)
        c:juice_up(0.3, 0.3)
    end)
    report(n, 'Changed rank', G.C.BLUE)
end

function A.duplicate(cards)
    local made = {}
    each(cards, nil, function(c)
        local copy
        if CS.is_playing_card(c) then
            G.playing_card = (G.playing_card and G.playing_card + 1) or 1
            copy = copy_card(c, nil, nil, G.playing_card)
            copy:add_to_deck()
            G.deck.config.card_limit = G.deck.config.card_limit + 1
            table.insert(G.playing_cards, copy)
            local area = (c.area == G.hand) and G.hand or G.deck
            area:emplace(copy)
            made[#made + 1] = copy
        else
            copy = copy_card(c)
            copy:add_to_deck()
            local area = c.area
            if area ~= G.jokers and area ~= G.consumeables then
                area = c.ability.consumeable and G.consumeables or G.jokers
            end
            area:emplace(copy)
        end
        copy:start_materialize()
    end)
    if #made > 0 and playing_card_joker_effects then pcall(playing_card_joker_effects, made) end
    report(#cards, 'Duplicated', G.C.GREEN)
end

function A.destroy(cards)
    local list = {}
    each(cards, nil, function(c) list[#list + 1] = c end)
    if #list == 0 then return report(0) end
    if SMODS.destroy_cards then
        SMODS.destroy_cards(list, { bypass_eternal = true })
    else
        for _, c in ipairs(list) do c:start_dissolve() end
    end
    CS.toast(('Destroyed %s'):format(plural(#list, 'card')), G.C.RED, 'slice1')
end

function A.set_debuff(cards, on)
    local n = each(cards, nil, function(c)
        SMODS.debuff_card(c, on and true or nil, 'cardsharp')
        c:juice_up(0.2, 0.2)
    end)
    report(n, on and 'Debuffed' or 'Cleared debuff', on and G.C.RED or G.C.GREEN)
end

function A.flip(cards)
    local n = each(cards, nil, function(c) c:flip() end)
    report(n, 'Flipped', G.C.BLUE)
end

function A.add_sell_value(cards, d)
    local n = each(cards, nil, function(c)
        c.ability.extra_value = (c.ability.extra_value or 0) + d
        c:set_cost()
        c:juice_up(0.2, 0.2)
    end)
    report(n, ('Sell value %s$%d'):format(d >= 0 and '+' or '-', math.abs(d)), G.C.MONEY)
end

--- Numeric fields of a single card that are worth exposing for direct editing.
local ABILITY_FIELDS = {
    'mult', 'h_mult', 'x_mult', 'x_chips', 'h_x_mult', 'h_x_chips', 't_mult', 't_chips', 'h_chips', 'bonus',
    'perma_bonus', 'perma_mult', 'perma_x_mult', 'perma_h_chips', 'perma_h_mult', 'perma_p_dollars',
    'h_dollars', 'p_dollars', 'h_size', 'd_size', 'extra_value',
}
local DEFAULTS = { x_mult = 1, x_chips = 1, h_x_mult = 1, h_x_chips = 1 }

function A.value_fields(card)
    local out = {}
    if not CS.card_alive(card) then return out end
    local ab = card.ability
    local seen = {}
    for _, k in ipairs(ABILITY_FIELDS) do
        local v = ab[k]
        if CS.is_numeric(v) and CS.num(v) ~= (DEFAULTS[k] or 0) then
            out[#out + 1] = { label = k, tbl = ab, key = k }
            seen[k] = true
        end
    end
    if CS.is_numeric(ab.extra) then
        out[#out + 1] = { label = 'extra', tbl = ab, key = 'extra' }
    elseif type(ab.extra) == 'table' then
        local keys = {}
        for k, v in pairs(ab.extra) do
            if CS.is_numeric(v) then keys[#keys + 1] = k end
        end
        table.sort(keys, function(a, b) return tostring(a) < tostring(b) end)
        for _, k in ipairs(keys) do out[#out + 1] = { label = 'extra.' .. tostring(k), tbl = ab.extra, key = k } end
    end
    return out
end

function A.change_value(field, op, amount)
    local cur = field.tbl[field.key]
    local was_big = type(cur) ~= 'number'
    local v = CS.num(cur)
    if op == 'add' then v = v + amount
    elseif op == 'mul' then v = v * amount end
    if math.abs(v - math.floor(v + 0.5)) < 1e-9 then v = math.floor(v + 0.5) end
    field.tbl[field.key] = was_big and CS.big(v) or v
    local card = CS.state.edit.value_card
    if card and card.set_cost then pcall(card.set_cost, card) end
    if card and card.juice_up then card:juice_up(0.2, 0.2) end
end

-------------------------------------------------------------------------------
-- Run stats
-------------------------------------------------------------------------------
function A.add_money(d)
    if not need_run() or d == 0 then return end
    A.bypass(ease_dollars, d, true)
end

function A.set_money(v)
    if not need_run() then return end
    A.add_money(v - CS.num(G.GAME.dollars))
end

function A.add_hands(d)
    if not need_run() then return end
    local cur = G.GAME.current_round.hands_left
    d = math.max(d, 1 - cur)
    if d ~= 0 then A.bypass(ease_hands_played, d, true) end
end

function A.add_discards(d)
    if not need_run() then return end
    local cur = G.GAME.current_round.discards_left
    d = math.max(d, -cur)
    if d ~= 0 then A.bypass(ease_discard, d, true, true) end
end

function A.set_score(v)
    if not need_run() then return end
    G.GAME.chips = CS.big(math.max(0, v))
    G.GAME.chips_text = number_format(G.GAME.chips)
end

function A.set_blind_target(v)
    if not CS.in_blind() then return CS.warn('No blind is active right now') end
    G.GAME.blind.chips = CS.big(math.max(1, math.floor(v)))
    G.GAME.blind.chip_text = number_format(G.GAME.blind.chips)
    if G.HUD_blind then G.HUD_blind:recalculate() end
end

function A.add_ante(d)
    if not need_run() then return end
    d = math.max(d, 1 - CS.num(G.GAME.round_resets.ante))
    if d ~= 0 then ease_ante(d) end
end

function A.add_round(d)
    if not need_run() then return end
    d = math.max(d, -G.GAME.round)
    if d ~= 0 then ease_round(d) end
end

function A.resize(area, d, minimum)
    if not need_run() or not area then return end
    local cur = area.config.card_limit or 0
    d = math.max(d, (minimum or 0) - cur)
    if d ~= 0 then area:change_size(d) end
end

function A.add_shop_slots(d)
    if not need_run() then return end
    if not G.GAME.shop then return CS.warn('Shop data is not ready yet') end
    A.ensure_shop_rates()
    d = math.max(d, 1 - G.GAME.shop.joker_max)
    if d ~= 0 then change_shop_size(d) end
end

function A.add_reroll_cost(d)
    if not need_run() then return end
    G.GAME.round_resets.reroll_cost = math.max(0, (G.GAME.round_resets.reroll_cost or 5) + d)
    if G.GAME.round_resets.temp_reroll_cost then
        G.GAME.round_resets.temp_reroll_cost = math.max(0, G.GAME.round_resets.temp_reroll_cost + d)
    end
    calculate_reroll_cost(true)
end

-------------------------------------------------------------------------------
-- Round flow
-------------------------------------------------------------------------------
function A.win_blind()
    if not need_run() then return end
    if not CS.state_is('SELECTING_HAND') then
        return CS.warn('Win Blind works while you are choosing a hand to play')
    end
    CS.close()
    G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.15, func = function()
        G.GAME.chips = G.GAME.blind.chips
        G.STATE = G.STATES.HAND_PLAYED
        G.STATE_COMPLETE = true
        end_round()
        return true
    end }))
end

function A.win_run()
    if not need_run() then return end
    CS.close()
    G.E_MANAGER:add_event(Event({ trigger = 'after', delay = 0.2, func = function() win_game(); return true end }))
end

function A.reroll_shop()
    if not shop_open() then return CS.warn('Open the shop first') end
    A.ensure_shop_rates()
    G.GAME.current_round.free_rerolls = (G.GAME.current_round.free_rerolls or 0) + 1
    calculate_reroll_cost(true)
    G.FUNCS.reroll_shop()
    CS.toast('Rerolled the shop for free', G.C.GREEN, false)
end

function A.reroll_boss()
    if not (CS.state_is('BLIND_SELECT') and G.blind_select_opts) then return CS.warn('Boss rerolls work at blind select') end
    if G.CONTROLLER.locks.boss_reroll then return end
    local rerolled = G.GAME.round_resets.boss_rerolled
    G.from_boss_tag = true
    G.FUNCS.reroll_boss()
    G.GAME.round_resets.boss_rerolled = rerolled
    CS.toast('Rerolled the boss blind', G.C.GREEN, false)
end

function A.set_boss(key)
    if not need_run() then return end
    G.GAME.round_resets.blind_choices.Boss = key
    if CS.state_is('BLIND_SELECT') and G.blind_select_opts and G.blind_select_opts.boss and not G.CONTROLLER.locks.boss_reroll then
        local real_get_new_boss = get_new_boss
        get_new_boss = function(...)
            get_new_boss = real_get_new_boss
            return key
        end
        local rerolled = G.GAME.round_resets.boss_rerolled
        G.from_boss_tag = true
        G.FUNCS.reroll_boss()
        G.GAME.round_resets.boss_rerolled = rerolled
    end
    CS.toast(('%s is now this ante\'s boss'):format(CS.blind_name(G.P_BLINDS[key])), G.C.GREEN, false)
    CS.sfx('chips1', 0.8, 0.5)
end

function A.disable_boss()
    if not CS.in_blind() then return CS.warn('No blind is active right now') end
    if not G.GAME.blind.boss then return CS.warn('This is not a boss blind') end
    if G.GAME.blind.disabled then return CS.warn('This boss is already disabled') end
    G.GAME.blind:disable()
    CS.toast('Boss ability disabled', G.C.GREEN, false)
    CS.sfx('timpani', 1, 0.6)
end

-------------------------------------------------------------------------------
-- Poker hands
-------------------------------------------------------------------------------
function A.level_hand(hand, amount)
    if not need_run() then return end
    local h = G.GAME.hands[hand]
    if not h then return end
    amount = math.max(amount, 1 - CS.num(h.level))
    if amount == 0 then return end
    level_up_hand(nil, hand, true, amount)
end

function A.level_all(amount)
    if not need_run() then return end
    for _, hand in ipairs(G.handlist) do
        if G.GAME.hands[hand] then A.level_hand(hand, amount) end
    end
    CS.toast(amount > 0 and ('All hands +' .. amount .. ' levels') or 'Levels lowered', G.C.SECONDARY_SET.Planet, false)
    CS.sfx('tarot1', 0.9, 0.6)
end

function A.reset_hands()
    if not need_run() then return end
    for _, hand in ipairs(G.handlist) do
        local h = G.GAME.hands[hand]
        if h then A.level_hand(hand, 1 - CS.num(h.level)) end
    end
    CS.toast('All hands reset to level 1', G.C.SECONDARY_SET.Planet, false)
end

-------------------------------------------------------------------------------
-- Deck tools
-------------------------------------------------------------------------------
function A.draw(n)
    if not CS.state_is('SELECTING_HAND') then return CS.warn('Draw cards while choosing a hand') end
    local count = 0
    for _ = 1, n do
        if #G.deck.cards - count <= 0 then break end
        draw_card(G.deck, G.hand, 90, 'up', true)
        count = count + 1
    end
    if count == 0 then return CS.warn('Your deck is empty') end
    CS.toast(('Drew %s'):format(plural(count, 'card')), G.C.BLUE, false)
end

function A.recycle_discards()
    if not need_run() then return end
    local n = #G.discard.cards
    if n == 0 then return CS.warn('Your discard pile is empty') end
    G.FUNCS.draw_from_discard_to_deck()
    G.E_MANAGER:add_event(Event({ func = function() G.deck:shuffle('cshp_recycle'); return true end }))
    CS.toast(('Shuffled %s back into your deck'):format(plural(n, 'card')), G.C.BLUE, false)
end

function A.shuffle_deck()
    if not need_run() then return end
    G.deck:shuffle('cshp_shuffle' .. G.GAME.round_resets.ante .. math.random())
    CS.toast('Shuffled your deck', G.C.BLUE, 'cardSlide1')
end

-------------------------------------------------------------------------------
-- Snapshots (save states)
-------------------------------------------------------------------------------
A.SNAPSHOT_SLOTS = 3

function A.snapshot_path(i)
    return (G.SETTINGS.profile or 1) .. '/cardsharp_snapshot_' .. i .. '.jkr'
end

function A.can_snapshot()
    return CS.in_run() and CS.state_is('SELECTING_HAND', 'SHOP', 'BLIND_SELECT')
end

function A.save_snapshot(i)
    if not A.can_snapshot() then
        return CS.warn('Snapshots work while choosing a hand, in the shop, or at blind select')
    end
    save_run()
    local packed = STR_PACK(G.ARGS.save_run or G.culled_table)
    local compressed = love.data.compress('string', 'deflate', packed, 1)
    love.filesystem.write(A.snapshot_path(i), compressed)
    CS.config.snapshots[i] = {
        ante = G.GAME.round_resets.ante,
        round = G.GAME.round,
        dollars = CS.fmt(G.GAME.dollars),
        deck = (G.GAME.selected_back and G.GAME.selected_back.loc_name) or (G.GAME.selected_back and G.GAME.selected_back.name) or 'Deck',
        when = os.date('%b %d, %H:%M'),
    }
    CS.save_config()
    CS.toast(('Saved snapshot %d'):format(i), G.C.GREEN, 'coin3')
end

function A.load_snapshot(i)
    local path = A.snapshot_path(i)
    if not love.filesystem.getInfo(path) then return CS.warn('That slot is empty') end
    local raw = love.filesystem.read(path)
    local ok, str = pcall(love.data.decompress, 'string', 'deflate', raw)
    if not ok or not str then return CS.warn('That snapshot could not be read') end
    local t = STR_UNPACK(str)
    if type(t) ~= 'table' or not t.GAME then return CS.warn('That snapshot could not be read') end
    CS.close()
    G.FUNCS.start_run(nil, { savetext = t })
end

function A.clear_snapshot(i)
    love.filesystem.remove(A.snapshot_path(i))
    CS.config.snapshots[i] = nil
    CS.save_config()
    CS.toast(('Cleared snapshot %d'):format(i), G.C.UI.TEXT_LIGHT, 'cancel')
end

function A.restart_run(same_seed)
    if not need_run() then return end
    local args = { stake = G.GAME.stake }
    if same_seed then args.seed = G.GAME.pseudorandom.seed end
    if G.GAME.challenge then
        for _, ch in ipairs(G.CHALLENGES or {}) do
            if ch.id == G.GAME.challenge then args.challenge = ch break end
        end
    end
    G.GAME.viewed_back = nil
    CS.close()
    G.FUNCS.start_run(nil, args)
end

function A.copy_seed()
    if not need_run() then return end
    local seed = G.GAME.pseudorandom.seed
    if G.F_LOCAL_CLIPBOARD then G.CLIPBOARD = seed else love.system.setClipboardText(seed) end
    CS.toast('Copied seed ' .. seed, G.C.GREEN, 'coin3')
end

-------------------------------------------------------------------------------
-- Profile
-------------------------------------------------------------------------------
local function mark_all(unlock)
    for _, pool in ipairs({ G.P_CENTERS, G.P_BLINDS, G.P_TAGS, G.P_SEALS or {} }) do
        for _, v in pairs(pool) do
            if type(v) == 'table' and not v.demo and not v.wip then
                v.alerted = true
                v.discovered = true
                if unlock then v.unlocked = true end
            end
        end
    end
    if unlock then G.PROFILES[G.SETTINGS.profile].all_unlocked = true end
    pcall(set_profile_progress)
    pcall(set_discover_tallies)
    G:save_progress()
end

function A.unlock_all()
    mark_all(true)
    CS.toast('Everything is unlocked and discovered', G.C.GREEN, 'holo1')
end

function A.discover_all()
    mark_all(false)
    CS.toast('Everything is discovered', G.C.GREEN, 'holo1')
end
