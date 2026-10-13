--- Core state, helpers and registries shared by every Cardsharp module.
local CS = Cardsharp
CS.VERSION = '1.0.1'

-------------------------------------------------------------------------------
-- Config
-------------------------------------------------------------------------------
CS.config = CS.mod.config or {}
CS.mod.config = CS.config
do
    local defaults = {
        hotkey = 'f1', hover_edit = true, dim = 2, close_on_spawn = false,
        cheats = {}, snapshots = {},
    }
    for k, v in pairs(defaults) do
        if CS.config[k] == nil then CS.config[k] = v end
    end
end

function CS.save_config()
    pcall(SMODS.save_mod_config, CS.mod)
end

-------------------------------------------------------------------------------
-- Session state (not persisted)
-------------------------------------------------------------------------------
CS.state = CS.state or {
    tab = 'spawn',
    spawn = {
        category = 'Joker', page = 1, search = '', mod = 'all', rarity = 'all',
        edition = 'none', stickers = {}, qty = 1, dest = 'inventory',
    },
    forge = {
        rank = 'Ace', suit = 'Spades', enhancement = 'none', seal = 'none', edition = 'none',
        qty = 1,
    },
    edit = { scope = 'selected', value_page = 1 },
    hands = { page = 1 },
    blinds = { page = 1 },
    tools = {},
    focus_card = nil,
}
CS.view = CS.view or {}

-------------------------------------------------------------------------------
-- Numbers (Talisman / Amulet safe)
-------------------------------------------------------------------------------
--- Plain Lua number from anything numeric. Amulet stores big values as FFI cdata,
--- Talisman as tables; both expose to_number.
function CS.num(x)
    local t = type(x)
    if t == 'number' then return x end
    if x == nil then return 0 end
    if type(to_number) == 'function' then
        local ok, v = pcall(to_number, x)
        if ok and type(v) == 'number' then return v end
    end
    if t == 'table' or t == 'cdata' then
        local ok, v = pcall(function() return x:to_number() end)
        if ok and type(v) == 'number' then return v end
    end
    return tonumber(x) or 0
end

--- True for plain numbers and big-number objects.
function CS.is_numeric(x)
    local t = type(x)
    if t == 'number' then return true end
    if t ~= 'table' and t ~= 'cdata' then return false end
    local ok, v = pcall(function() return x:to_number() end)
    if ok and type(v) == 'number' then return true end
    if type(to_number) == 'function' then
        local ok2, v2 = pcall(to_number, x)
        return ok2 and type(v2) == 'number'
    end
    return false
end

function CS.big(x)
    if type(to_big) == 'function' then
        local ok, v = pcall(to_big, x)
        if ok and v ~= nil then return v end
    end
    return x
end

function CS.fmt(x)
    if x == nil then return '-' end
    local ok, s = pcall(number_format, x)
    if ok and s ~= nil then return tostring(s) end
    return tostring(x)
end

function CS.clamp(v, lo, hi)
    if lo and v < lo then return lo end
    if hi and v > hi then return hi end
    return v
end

--- Holding Shift multiplies stepper buttons by 10.
function CS.step_mult()
    if love.keyboard.isDown('lshift', 'rshift') then return 10 end
    return 1
end

-------------------------------------------------------------------------------
-- Game state helpers
-------------------------------------------------------------------------------
function CS.in_run()
    return G.STAGE == G.STAGES.RUN and G.GAME ~= nil and G.jokers ~= nil and G.hand ~= nil and G.deck ~= nil
end

function CS.state_is(...)
    for i = 1, select('#', ...) do
        local name = select(i, ...)
        if G.STATES[name] and G.STATE == G.STATES[name] then return true end
    end
    return false
end

function CS.in_blind()
    return CS.in_run() and G.GAME.blind and G.GAME.facing_blind and G.GAME.blind.in_blind and true or false
end

function CS.card_alive(card)
    return card and not card.REMOVED and card.area ~= nil and card.ability ~= nil
end

function CS.is_playing_card(card)
    if not card or not card.ability then return false end
    if SMODS.is_playing_card then
        local ok, r = pcall(SMODS.is_playing_card, card)
        if ok then return r and true or false end
    end
    return card.ability.set == 'Default' or card.ability.set == 'Enhanced'
end

-------------------------------------------------------------------------------
-- Errors, dispatch, feedback
-------------------------------------------------------------------------------
function CS.log(msg)
    if sendInfoMessage then sendInfoMessage(tostring(msg), 'Cardsharp') else print('[Cardsharp] ' .. tostring(msg)) end
end

function CS.safe(f, ...)
    local args = { n = select('#', ...), ... }
    local ok, err = xpcall(function() return f(unpack(args, 1, args.n)) end, debug.traceback)
    if not ok then
        if sendErrorMessage then sendErrorMessage(tostring(err), 'Cardsharp') else print('[Cardsharp] ' .. tostring(err)) end
        CS.toast('Something went wrong - details are in the log', G.C.RED, 'cancel')
    end
    return ok, err
end

--- Every Cardsharp button routes through here and calls the closure stored on the node.
G.FUNCS.cshp_click = function(e)
    local f = e and e.config and e.config.cs_click
    if f then CS.safe(f, e) end
end

--- Per-frame sync hook: lets nodes restyle themselves from live game state.
G.FUNCS.cshp_sync = function(e)
    local f = e and e.config and e.config.cs_sync
    if not f then return end
    local ok, err = pcall(f, e)
    if not ok and not e.config.cs_sync_failed then
        e.config.cs_sync_failed = true
        CS.log('sync error: ' .. tostring(err))
    end
end

function CS.sfx(name, pitch, vol)
    if name == false then return end
    pcall(play_sound, name or 'generic1', pitch or 1, vol or 0.6)
end

--- Shows a message in the menu's status bar (and plays a sound).
function CS.toast(msg, colour, sound)
    CS.last_msg = msg
    CS.last_col = colour or G.C.UI.TEXT_LIGHT
    if sound ~= false then CS.sfx(sound or 'generic1', 1.1, 0.4) end
    if not CS.is_open or not CS.is_open() then return end
    local old = CS.view.status
    CS.view.status = DynaText({
        string = { msg }, colours = { CS.last_col }, shadow = true, silent = true,
        pop_in = 0, pop_in_rate = 6, scale = 0.36, maxw = 11,
    })
    if old then
        G.E_MANAGER:add_event(Event({
            trigger = 'after', delay = 0.2, timer = 'REAL', blockable = false, blocking = false,
            func = function() if old.remove then old:remove() end return true end,
        }))
    end
end

function CS.warn(msg) CS.toast(msg, G.C.FILTER, 'cancel') end

-------------------------------------------------------------------------------
-- Names
-------------------------------------------------------------------------------
CS._names = {}
CS._reg = nil

local function loc_or(fallback, ...)
    local ok, s = pcall(localize, ...)
    if ok and type(s) == 'string' and s ~= '' and s ~= 'ERROR' then return s end
    return fallback
end
CS.loc_or = loc_or

function CS.name_of(obj)
    if not obj then return '?' end
    local key = obj.key or obj.name or '?'
    local cached = CS._names[key]
    if cached then return cached end
    local n = loc_or(obj.name or key, { type = 'name_text', set = obj.set, key = key })
    CS._names[key] = n
    return n
end

function CS.blind_name(blind)
    return loc_or(blind.name or blind.key, { type = 'name_text', set = 'Blind', key = blind.key })
end

function CS.seal_name(key)
    return loc_or(key, key:lower() .. '_seal', 'labels')
end

function CS.sticker_name(key)
    return loc_or(key:gsub('^%l', string.upper), key, 'labels')
end

function CS.hand_name(hand)
    return loc_or(hand, hand, 'poker_hands')
end

function CS.rarity_name(r)
    local vanilla = { 'k_common', 'k_uncommon', 'k_rare', 'k_legendary' }
    if type(r) == 'number' then return loc_or(tostring(r), vanilla[r] or '') end
    return loc_or(tostring(r), 'k_' .. tostring(r):lower())
end

function CS.rarity_colour(r)
    return (G.C.RARITY and G.C.RARITY[r]) or G.C.JOKER_GREY
end

--- The mod that *added* an object (vanilla objects a mod merely took over stay 'vanilla').
function CS.mod_id(obj)
    local m = obj and obj.original_mod
    if not m or m.id == 'Steamodded' then return 'vanilla' end
    return m.id
end

CS.VANILLA_RANKS = { '2', '3', '4', '5', '6', '7', '8', '9', '10', 'Jack', 'Queen', 'King', 'Ace' }
CS.VANILLA_SUITS = { 'Spades', 'Hearts', 'Clubs', 'Diamonds' }

function CS.mod_label(id)
    if id == 'all' then return 'All mods' end
    if id == 'vanilla' then return 'Vanilla' end
    local m = SMODS.Mods and SMODS.Mods[id]
    return (m and (m.display_name or m.name)) or id
end

-------------------------------------------------------------------------------
-- Registries (built lazily - pools are complete only after mod injection)
-------------------------------------------------------------------------------
local EDITION_COLOURS = {
    e_foil = HEX('7aa7e0'),
    e_holo = HEX('e8608c'),
    e_negative = HEX('4b4e78'),
}
local ENH_COLOURS = {
    m_bonus = HEX('009dff'), m_mult = HEX('fe5f55'), m_wild = HEX('a46cd6'), m_glass = HEX('7fc8d8'),
    m_steel = HEX('8c9aa8'), m_stone = HEX('8a7a6a'), m_gold = HEX('e2b43f'), m_lucky = HEX('4bc292'),
}
local SEAL_COLOURS = { Gold = HEX('e2b43f'), Red = HEX('fe5f55'), Blue = HEX('009dff'), Purple = HEX('8867a5') }

function CS.registry()
    if CS._reg then return CS._reg end
    local R = {}

    R.editions = {}
    for _, v in ipairs(G.P_CENTER_POOLS.Edition or {}) do
        if v.key ~= 'e_base' then
            local col = EDITION_COLOURS[v.key] or (v.key == 'e_polychrome' and G.C.DARK_EDITION) or v.badge_colour or G.C.DARK_EDITION
            R.editions[#R.editions + 1] = { key = v.key, label = CS.name_of(v), colour = col }
        end
    end

    R.enhancements = {}
    for _, v in ipairs(G.P_CENTER_POOLS.Enhanced or {}) do
        local label = CS.name_of(v):gsub(' Card$', '')
        R.enhancements[#R.enhancements + 1] = { key = v.key, label = label, colour = ENH_COLOURS[v.key] or G.C.SECONDARY_SET.Enhanced }
    end

    R.seals = {}
    for _, v in ipairs(G.P_CENTER_POOLS.Seal or {}) do
        local key = v.key
        R.seals[#R.seals + 1] = { key = key, label = CS.seal_name(key):gsub(' Seal$', ''), colour = SEAL_COLOURS[key] or v.badge_colour or G.C.GOLD }
    end

    R.stickers = {}
    local sticker_order = (SMODS.Sticker and SMODS.Sticker.obj_buffer) or {}
    for _, key in ipairs(sticker_order) do
        local s = SMODS.Stickers[key]
        if s and not (SMODS.hide_from_collection and SMODS.hide_from_collection(s)) then
            local col = (key == 'eternal' and G.C.ETERNAL) or (key == 'perishable' and G.C.PERISHABLE)
                or (key == 'rental' and G.C.RENTAL) or (key == 'pinned' and G.C.GREY) or s.badge_colour or G.C.GREY
            R.stickers[#R.stickers + 1] = { key = key, label = CS.sticker_name(key), colour = col, sets = s.sets or { Joker = true } }
        end
    end

    -- Vanilla ranks high-to-low (A K Q ... 2), then any modded ranks by their full name.
    local vanilla_rank = {}
    for _, k in ipairs(CS.VANILLA_RANKS) do vanilla_rank[k] = true end
    R.ranks = {}
    for _, key in ipairs(SMODS.Rank.obj_buffer) do
        local r = SMODS.Ranks[key]
        if r then
            local modded = not vanilla_rank[key]
            R.ranks[#R.ranks + 1] = {
                key = key, rank = r, sort = r.sort_id or 0, modded = modded,
                label = modded and loc_or(key, key, 'ranks') or (r.shorthand or key),
            }
        end
    end
    table.sort(R.ranks, function(a, b)
        if a.modded ~= b.modded then return not a.modded end
        return a.sort > b.sort
    end)

    R.suits = {}
    for _, key in ipairs(SMODS.Suit.obj_buffer) do
        local s = SMODS.Suits[key]
        if s then R.suits[#R.suits + 1] = { key = key, label = loc_or(key, key, 'suits_plural'), suit = s } end
    end

    CS._reg = R
    return R
end

--- Stickers that apply to a given card set (e.g. 'Joker', or 'Default' for playing cards).
function CS.stickers_for(set)
    local out = {}
    for _, s in ipairs(CS.registry().stickers) do
        if s.sets[set] then out[#out + 1] = s end
    end
    return out
end

function CS.suit_colour(key)
    return (G.C.SUITS and G.C.SUITS[key]) or G.C.WHITE
end

function CS.find(list, key)
    for _, v in ipairs(list) do if v.key == key then return v end end
end

-------------------------------------------------------------------------------
-- Tab registry (tabs register themselves; the menu renders them in `order`)
-------------------------------------------------------------------------------
CS.TABS = {}
CS.TAB_BY_ID = {}

function CS.register_tab(def)
    CS.TABS[#CS.TABS + 1] = def
    CS.TAB_BY_ID[def.id] = def
    table.sort(CS.TABS, function(a, b) return (a.order or 99) < (b.order or 99) end)
end
