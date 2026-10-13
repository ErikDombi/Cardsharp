--- Spawn tab: browse every joker / consumable / voucher / booster / tag and click to spawn it.
local CS = Cardsharp
local UI, A = CS.UI, CS.A
local R, C, O = G.UIT.R, G.UIT.C, G.UIT.O

local GRID_W, GRID_H = 11.7, 6.45
local GEOM = {
    card = { cols = 7, rows = 3, scale = 0.72 },
    booster = { cols = 5, rows = 2, scale = 0.78 },
    tag = { cols = 10, rows = 5, size = 0.82 },
}

local function categories()
    local cats = {
        { id = 'Joker', label = CS.loc_or('Jokers', 'b_jokers'), colour = G.C.RED, kind = 'card', pool = G.P_CENTER_POOLS.Joker },
    }
    for _, key in ipairs(SMODS.ConsumableType.obj_buffer or {}) do
        if G.P_CENTER_POOLS[key] then
            cats[#cats + 1] = {
                id = key, label = CS.loc_or(key, 'b_' .. key:lower() .. '_cards'),
                colour = G.C.SECONDARY_SET[key] or G.C.PURPLE, kind = 'card', pool = G.P_CENTER_POOLS[key],
            }
        end
    end
    cats[#cats + 1] = { id = 'Voucher', label = CS.loc_or('Vouchers', 'b_vouchers'), colour = G.C.SECONDARY_SET.Voucher, kind = 'card', pool = G.P_CENTER_POOLS.Voucher }
    cats[#cats + 1] = { id = 'Booster', label = CS.loc_or('Booster Packs', 'b_booster_packs'), colour = G.C.BOOSTER, kind = 'booster', pool = G.P_CENTER_POOLS.Booster }
    cats[#cats + 1] = { id = 'Tag', label = CS.loc_or('Tags', 'b_tags'), colour = G.C.GREEN, kind = 'tag', pool = G.P_CENTER_POOLS.Tag }
    return cats
end

local function current_cat()
    local cats = categories()
    for _, c in ipairs(cats) do if c.id == CS.state.spawn.category then return c, cats end end
    CS.state.spawn.category = cats[1].id
    return cats[1], cats
end

local function mod_options(cat)
    local seen, ids = {}, {}
    for _, c in ipairs(cat.pool or {}) do
        local id = CS.mod_id(c)
        if not seen[id] then seen[id] = true; ids[#ids + 1] = id end
    end
    table.sort(ids, function(a, b)
        if a == 'vanilla' then return true elseif b == 'vanilla' then return false end
        return CS.mod_label(a):lower() < CS.mod_label(b):lower()
    end)
    local opts = { { key = 'all', label = 'All mods' } }
    for _, id in ipairs(ids) do opts[#opts + 1] = { key = id, label = CS.mod_label(id) } end
    return opts
end

local function rarity_options(cat)
    local seen, list = {}, {}
    for _, c in ipairs(cat.pool or {}) do
        local r = c.rarity
        if r ~= nil and not seen[r] then seen[r] = true; list[#list + 1] = r end
    end
    table.sort(list, function(a, b)
        if type(a) == type(b) then return tostring(a) < tostring(b) end
        return type(a) == 'number'
    end)
    local opts = { { key = 'all', label = 'All rarities' } }
    for _, r in ipairs(list) do opts[#opts + 1] = { key = r, label = CS.rarity_name(r) } end
    return opts
end

local function results(cat)
    local s = CS.state.spawn
    local q = (s.search or ''):lower():gsub('^%s+', ''):gsub('%s+$', '')
    local out = {}
    for _, c in ipairs(cat.pool or {}) do
        local keep = not (SMODS.hide_from_collection and SMODS.hide_from_collection(c))
        if keep and s.mod ~= 'all' and CS.mod_id(c) ~= s.mod then keep = false end
        if keep and cat.id == 'Joker' and s.rarity ~= 'all' and c.rarity ~= s.rarity then keep = false end
        if keep and q ~= '' then
            local name = CS.name_of(c):lower()
            if not name:find(q, 1, true) and not tostring(c.key):lower():find(q, 1, true) then keep = false end
        end
        if keep then out[#out + 1] = c end
    end
    return out
end

local function decorate(card, center, cat)
    if not (cat.id == 'Joker' or center.consumeable) then return end
    local mods = A.spawn_modifiers()
    if mods.edition then pcall(card.set_edition, card, mods.edition, true, true) end
    for _, st in ipairs(mods.stickers) do pcall(card.add_sticker, card, st, true) end
end

local function build_grid()
    local s = CS.state.spawn
    local cat = current_cat()
    local list = results(cat)
    local g = GEOM[cat.kind]
    local per = g.cols * g.rows
    local pages = math.max(1, math.ceil(#list / per))
    s.page = CS.clamp(s.page or 1, 1, pages)
    CS.view.spawn_count = #list
    CS.view.spawn_pages = pages
    local first = (s.page - 1) * per

    if #list == 0 then
        return UI.root({ UI.notice('No matches', { 'Nothing here fits your search and filters.' }) }, { minw = GRID_W, minh = GRID_H })
    end

    local rows = {}
    if cat.kind == 'tag' then
        for r = 1, g.rows do
            local cells = {}
            for c = 1, g.cols do
                local proto = list[first + (r - 1) * g.cols + c]
                if proto then
                    local tag = Tag(proto.key, true)
                    local tag_ui, sprite = tag:generate_UI(g.size)
                    sprite.states.click.can = true
                    sprite.click = function(self)
                        CS.safe(A.spawn, proto)
                        self:juice_up(0.3, 0.3)
                    end
                    cells[#cells + 1] = { n = C, config = { align = 'cm', padding = 0.1 }, nodes = { tag_ui } }
                end
            end
            rows[#rows + 1] = { n = R, config = { align = 'cm' }, nodes = cells }
        end
    else
        local size = cat.kind == 'booster' and 1.27 or 1
        local cw, ch = G.CARD_W * size * g.scale, G.CARD_H * size * g.scale
        local placed = 0
        for r = 1, g.rows do
            local area = CardArea(G.ROOM.T.x + 0.2 * G.ROOM.T.w / 2, G.ROOM.T.h, (g.cols + 0.25) * cw, ch,
                { card_limit = g.cols, type = 'title', highlight_limit = 0 })
            for c = 1, g.cols do
                local center = list[first + (r - 1) * g.cols + c]
                if center then
                    local card = Card(area.T.x + area.T.w / 2, area.T.y, cw, ch, G.P_CARDS.empty, center,
                        { bypass_discovery_center = true, bypass_discovery_ui = true, bypass_lock = true })
                    decorate(card, center, cat)
                    card.click = function(self)
                        CS.safe(A.spawn, center)
                        self:juice_up(0.4, 0.4)
                    end
                    card:start_materialize(nil, placed > 0)
                    area:emplace(card)
                    placed = placed + 1
                end
            end
            rows[#rows + 1] = { n = R, config = { align = 'cm', padding = 0.04, no_fill = true }, nodes = { { n = O, config = { object = area } } } }
        end
    end
    return UI.root({ UI.col(rows) }, { minw = GRID_W, minh = GRID_H })
end

local function rebuild_grid()
    UI.replace('cshp_spawn_grid', build_grid)
end

local function turn_page(d)
    local s = CS.state.spawn
    local pages = CS.view.spawn_pages or 1
    if pages <= 1 then return end
    s.page = s.page + d
    if s.page < 1 then s.page = pages elseif s.page > pages then s.page = 1 end
    CS.sfx('paper1', 0.9 + math.random() * 0.1, 0.5)
    rebuild_grid()
end

local function dest_labels(cat)
    if cat.id == 'Voucher' then return 'Redeem now', 'Add to shop' end
    if cat.id == 'Booster' then return 'Open now', 'Add to shop' end
    return 'My slots', 'The shop'
end

local function modifiers_panel(cat)
    local s = CS.state.spawn
    local reg = CS.registry()
    local nodes = {}
    local can_mod = cat.id == 'Joker' or (cat.kind == 'card' and cat.id ~= 'Voucher')

    local function label(t)
        return UI.row({ UI.text(t, 0.28, UI.muted()) }, { align = 'cl', padding = 0.02 })
    end

    local PW = 3.45
    if can_mod then
        local eds = { { key = 'none', label = 'None', colour = G.C.GREY } }
        for _, e in ipairs(reg.editions) do eds[#eds + 1] = e end
        nodes[#nodes + 1] = label('EDITION')
        nodes[#nodes + 1] = UI.row({ UI.radio(eds, s, 'edition', { per_row = 2, width = PW, h = 0.4, max_rows = 4, id = 'spawn_ed', on_change = rebuild_grid }) })
        local stickers = CS.stickers_for(cat.id)
        -- drop stickers that are no longer valid for this category
        for k in pairs(s.stickers) do
            if not CS.find(stickers, k) then s.stickers[k] = nil end
        end
        if #stickers > 0 then
            nodes[#nodes + 1] = label('STICKERS')
            nodes[#nodes + 1] = UI.row({ UI.multi(stickers, s.stickers, { per_row = 2, width = PW, h = 0.4, max_rows = 4, id = 'spawn_st_' .. cat.id, on_change = rebuild_grid }) })
        end
    end

    nodes[#nodes + 1] = label('AMOUNT')
    nodes[#nodes + 1] = UI.row({ UI.radio({
        { key = 1, label = '1' }, { key = 2, label = '2' }, { key = 5, label = '5' }, { key = 10, label = '10' },
    }, s, 'qty', { per_row = 4, width = PW, h = 0.4, colour = G.C.ORANGE }) })

    if cat.id ~= 'Tag' then
        local l1, l2 = dest_labels(cat)
        nodes[#nodes + 1] = label('SEND TO')
        nodes[#nodes + 1] = UI.row({ UI.radio({
            { key = 'inventory', label = l1 }, { key = 'shop', label = l2 },
        }, s, 'dest', { per_row = 2, width = PW, h = 0.4, colour = G.C.BLUE }) })
    end

    return UI.section({ title = 'SPAWN WITH', colour = cat.colour, w = 3.7, h = 7.55, align = 'tm', nodes = { UI.col(nodes, { align = 'tm' }) } })
end

local function build()
    local s = CS.state.spawn
    local cat, cats = current_cat()

    -- Left: categories
    local cat_items = {}
    for _, c in ipairs(cats) do cat_items[#cat_items + 1] = { key = c.id, label = c.label, colour = c.colour } end
    local left = UI.section({
        title = 'BROWSE', colour = cat.colour, w = 2.95, h = 7.55, align = 'tm',
        nodes = { UI.col({
            UI.radio(cat_items, s, 'category', {
                per_row = 1, w = 2.6, h = 0.46, scale = 0.32, max_rows = 11, id = 'spawn_cat',
                on_change = function()
                    s.page, s.mod, s.rarity = 1, 'all', 'all'
                    CS.refresh()
                end,
            }),
            UI.row({ UI.spacer(0.1, 0.25) }),
            UI.row({ UI.text('Click a card to spawn it.', 0.24, UI.muted()) }, { padding = 0.02 }),
            UI.row({ UI.text('Scroll to flip pages.', 0.24, UI.muted()) }, { padding = 0.02 }),
        }, { align = 'tm' }) },
    })

    -- Middle: search + filters, grid, pager
    local mod_opts = mod_options(cat)
    local valid = false
    for _, o in ipairs(mod_opts) do if o.key == s.mod then valid = true end end
    if not valid then s.mod = 'all' end

    local search = create_text_input({
        w = 3.3, h = 0.42, max_length = 18, all_caps = false, extended_corpus = true,
        prompt_text = 'Search by name...', ref_table = s, ref_value = 'search',
        colour = G.C.BLACK, hooked_colour = UI.tint(cat.colour, 0.6), text_scale = 0.32,
    })
    local filters = {
        search,
        UI.button({ label = 'x', w = 0.42, h = 0.42, scale = 0.32, colour = G.C.UI.BACKGROUND_INACTIVE,
            tooltip = { text = { 'Clear search' } },
            on_click = function() s.search = ''; s.page = 1; CS.refresh() end }),
        UI.spacer(0.12),
        UI.cycler({ options = mod_opts, w = 2.3, colour = cat.colour,
            get = function() return s.mod end,
            set = function(k) s.mod = k; s.page = 1; rebuild_grid() end }),
    }
    if cat.id == 'Joker' then
        filters[#filters + 1] = UI.spacer(0.08)
        filters[#filters + 1] = UI.cycler({ options = rarity_options(cat), w = 1.9, colour = cat.colour,
            get = function() return s.rarity end,
            set = function(k) s.rarity = k; s.page = 1; rebuild_grid() end })
    end

    local watcher = {
        n = C,
        config = { func = 'cshp_sync', cs_sync = function()
            if CS.view.spawn_last_search ~= s.search then
                local first = CS.view.spawn_last_search == nil
                CS.view.spawn_last_search = s.search
                if not first then s.page = 1; rebuild_grid() end
            end
        end },
        nodes = {},
    }
    CS.view.spawn_last_search = nil

    local middle = UI.col({
        UI.row(filters, { padding = 0.03 }),
        UI.row({ UI.slot('cshp_spawn_grid', build_grid, { minw = GRID_W, minh = GRID_H }) }),
        UI.row({
            UI.button({ label = '<', w = 0.6, h = 0.4, scale = 0.34, colour = cat.colour, on_click = function() turn_page(-1) end }),
            { n = C, config = { align = 'cm', minw = 4.2 }, nodes = {
                UI.live(function()
                    return ('Page %d / %d   -   %d result%s'):format(s.page, CS.view.spawn_pages or 1, CS.view.spawn_count or 0, (CS.view.spawn_count == 1) and '' or 's')
                end, 0.3, G.C.UI.TEXT_LIGHT),
            } },
            UI.button({ label = '>', w = 0.6, h = 0.4, scale = 0.34, colour = cat.colour, on_click = function() turn_page(1) end }),
            watcher,
        }, { padding = 0.02 }),
    }, { align = 'tm', minw = GRID_W + 0.2 })

    return UI.row({ left, middle, modifiers_panel(cat) }, { align = 'tm', padding = 0.06 })
end

CS.register_tab({
    id = 'spawn', label = 'Spawn', colour = function() return G.C.RED end, order = 1, needs_run = true,
    build = build,
    wheel = function(y) turn_page(y > 0 and -1 or 1) end,
})
