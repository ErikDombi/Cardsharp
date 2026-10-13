--- Cards tab: forge playing cards with any rank, suit, enhancement, seal and edition.
local CS = Cardsharp
local UI, A = CS.UI, CS.A
local R, O = G.UIT.R, G.UIT.O

local ACCENT = function() return G.C.BLUE end
local LEFT_W = 12.2

local function suit_sprite(key, size)
    local s = SMODS.Suits[key]
    if not s or not s.ui_pos then return nil end
    local atlas = s[(G.SETTINGS.colourblind_option and 'hc' or 'lc') .. '_ui_atlas'] or ('ui_' .. (G.SETTINGS.colourblind_option and '2' or '1'))
    local ok, spr = pcall(SMODS.create_sprite, 0, 0, size, size, atlas, s.ui_pos)
    if not ok or not spr then return nil end
    spr.states.drag.can = false
    spr.states.hover.can = false
    spr.states.collide.can = false
    return { n = O, config = { object = spr } }
end

local function describe()
    local f = CS.state.forge
    local rank = f.rank == 'random' and 'Random rank' or CS.loc_or(f.rank, f.rank, 'ranks')
    local suit = f.suit == 'random' and 'random suit' or CS.loc_or(f.suit, f.suit, 'suits_plural')
    return ('%s of %s'):format(rank, suit)
end

local function describe_mods()
    local f = CS.state.forge
    local parts = {}
    if f.enhancement ~= 'none' then parts[#parts + 1] = CS.name_of(G.P_CENTERS[f.enhancement]):gsub(' Card$', '') end
    if f.seal ~= 'none' then parts[#parts + 1] = CS.seal_name(f.seal) end
    if f.edition ~= 'none' then parts[#parts + 1] = CS.name_of(G.P_CENTERS[f.edition]) end
    if #parts == 0 then return 'No modifiers' end
    return table.concat(parts, '  -  ')
end

local function build_preview()
    local f = CS.state.forge
    local rank = SMODS.Ranks[f.rank] or SMODS.Ranks.Ace
    local suit = SMODS.Suits[f.suit] or SMODS.Suits.Spades
    local front = G.P_CARDS[suit.card_key .. '_' .. rank.card_key]
    local center = f.enhancement == 'none' and G.P_CENTERS.c_base or G.P_CENTERS[f.enhancement] or G.P_CENTERS.c_base
    local scale = 1.02
    local area = CardArea(G.ROOM.T.x, G.ROOM.T.h, G.CARD_W * scale * 1.15, G.CARD_H * scale,
        { card_limit = 1, type = 'title', highlight_limit = 0 })
    local card = Card(area.T.x, area.T.y, G.CARD_W * scale, G.CARD_H * scale, front, center,
        { bypass_discovery_center = true, bypass_discovery_ui = true })
    if f.edition ~= 'none' then pcall(card.set_edition, card, f.edition, true, true) end
    if f.seal ~= 'none' then pcall(card.set_seal, card, f.seal, true, true) end
    card.click = function(self) self:juice_up(0.6, 0.6); CS.sfx('card1', 1.2, 0.5) end
    card:start_materialize(nil, true)
    area:emplace(card)
    return UI.root({ { n = R, config = { align = 'cm' }, nodes = { { n = O, config = { object = area } } } } }, { minw = 3.2, minh = 2.95 })
end

local function refresh_preview() UI.replace('cshp_forge_preview', build_preview) end

local function heading(t)
    return UI.row({ UI.text(t, 0.28, UI.muted()) }, { align = 'cl', padding = 0.02 })
end

local function picker(title, items, field, per_row, max_rows, extra)
    local a = { per_row = per_row, max_rows = max_rows, width = LEFT_W - 0.2, h = 0.46, id = 'forge_' .. field, on_change = refresh_preview }
    if extra then for k, v in pairs(extra) do a[k] = v end end
    return UI.row({ UI.section({ title = title, colour = ACCENT(), w = LEFT_W, align = 'cl', nodes = {
        UI.radio(items, CS.state.forge, field, a),
    } }) }, { padding = 0.03 })
end

local function quick_set(kind)
    local f = CS.state.forge
    local list = {}
    if kind == 'suit' then
        for _, r in ipairs(CS.VANILLA_RANKS) do list[#list + 1] = { rank = r, suit = f.suit } end
    elseif kind == 'rank' then
        for _, s in ipairs(CS.VANILLA_SUITS) do list[#list + 1] = { rank = f.rank, suit = s } end
    elseif kind == 'deck' then
        for _, s in ipairs(CS.VANILLA_SUITS) do
            for _, r in ipairs(CS.VANILLA_RANKS) do list[#list + 1] = { rank = r, suit = s } end
        end
    else
        for _ = 1, 5 do list[#list + 1] = { rank = 'random', suit = 'random' } end
    end
    A.forge('deck', f, list)
end

local function build()
    local f = CS.state.forge
    local reg = CS.registry()

    local rank_items = {}
    for _, r in ipairs(reg.ranks) do rank_items[#rank_items + 1] = { key = r.key, label = r.label } end
    rank_items[#rank_items + 1] = { key = 'random', label = '?', colour = G.C.GREY, tooltip = { text = { 'Random rank' } } }

    local suit_items = {}
    for _, s in ipairs(reg.suits) do
        local key = s.key
        suit_items[#suit_items + 1] = {
            key = key, label = s.label, colour = CS.suit_colour(key),
            prefix_node = function() return suit_sprite(key, 0.3) end,
        }
    end
    suit_items[#suit_items + 1] = { key = 'random', label = 'Random', colour = G.C.GREY }

    local function with_none(list)
        local out = { { key = 'none', label = 'None', colour = G.C.GREY } }
        for _, v in ipairs(list) do out[#out + 1] = v end
        return out
    end

    local left = UI.col({
        picker('RANK', rank_items, 'rank', 15, 2, { colour = G.C.BLUE, scale = 0.36 }),
        picker('SUIT', suit_items, 'suit', 7, 2, { scale = 0.3 }),
        picker('ENHANCEMENT', with_none(reg.enhancements), 'enhancement', 9, 3),
        picker('SEAL', with_none(reg.seals), 'seal', 9, 2),
        picker('EDITION', with_none(reg.editions), 'edition', 9, 2),
    }, { align = 'tm' })

    local function qs(label, sub, kind)
        return UI.button({ label = label, sub = sub, w = 2.5, h = 0.56, scale = 0.31, colour = G.C.BLUE, on_click = function() quick_set(kind) end })
    end

    local right = UI.section({
        title = 'PREVIEW', colour = ACCENT(), w = 5.9, h = 7.55, align = 'tm',
        nodes = { UI.col({
            UI.row({ UI.slot('cshp_forge_preview', build_preview, { minw = 3.2, minh = 2.95 }) }, { padding = 0.02 }),
            UI.row({ UI.live(describe, 0.38, G.C.UI.TEXT_LIGHT, { maxw = 5.4 }) }, { padding = 0.02 }),
            UI.row({ UI.live(describe_mods, 0.27, UI.muted(), { maxw = 5.4 }) }, { padding = 0.02 }),
            heading('AMOUNT'),
            UI.row({ UI.radio({
                { key = 1, label = '1' }, { key = 2, label = '2' }, { key = 5, label = '5' }, { key = 10, label = '10' }, { key = 25, label = '25' },
            }, f, 'qty', { per_row = 5, width = 5.4, h = 0.4, colour = G.C.ORANGE }) }),
            UI.row({
                UI.button({ label = 'Add to hand', w = 2.6, h = 0.56, colour = G.C.BLUE,
                    enabled = function() return CS.state_is('SELECTING_HAND') end,
                    tooltip = { text = { 'Only while choosing a hand' } },
                    on_click = function() A.forge('hand', f) end }),
                UI.spacer(0.1),
                UI.button({ label = 'Add to deck', w = 2.6, h = 0.56, colour = G.C.GREEN,
                    on_click = function() A.forge('deck', f) end }),
            }, { padding = 0.04 }),
            heading('QUICK SETS  -  into your deck, with these modifiers'),
            UI.row({ qs('Full suit', '13 cards', 'suit'), UI.spacer(0.08), qs('Full rank', 'one per suit', 'rank') }, { padding = 0.03 }),
            UI.row({ qs('Standard deck', '52 cards', 'deck'), UI.spacer(0.08), qs('Random 5', 'any rank & suit', 'random') }, { padding = 0.03 }),
        }, { align = 'tm' }) },
    })

    return UI.row({ left, UI.spacer(0.05), right }, { align = 'tm', padding = 0.03 })
end

CS.register_tab({
    id = 'forge', label = 'Cards', colour = function() return G.C.BLUE end, order = 2, needs_run = true,
    build = build,
})
