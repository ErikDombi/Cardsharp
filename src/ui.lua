--- Cardsharp UI kit: small, consistent building blocks on top of Balatro's UIBox system.
--- Layout reminder: R children stack vertically, C/T/O/B children flow horizontally.
local CS = Cardsharp
local UI = {}
CS.UI = UI

local R, C, T, O, B = G.UIT.R, G.UIT.C, G.UIT.T, G.UIT.O, G.UIT.B

UI.W = 18.6  -- content area width
UI.H = 7.7   -- content area height

function UI.white() return G.C.UI.TEXT_LIGHT end
function UI.muted() return { 1, 1, 1, 0.55 } end
function UI.tint(col, amount) return mix_colours(col, G.C.BLACK, amount or 0.3) end

--- Readable text colour for a given background.
function UI.text_on(col)
    if not col then return G.C.UI.TEXT_LIGHT end
    local lum = 0.299 * (col[1] or 0) + 0.587 * (col[2] or 0) + 0.114 * (col[3] or 0)
    return lum > 0.68 and G.C.UI.TEXT_DARK or G.C.UI.TEXT_LIGHT
end

-------------------------------------------------------------------------------
-- Primitives
-------------------------------------------------------------------------------
function UI.text(str, scale, colour, extra)
    local cfg = { text = tostring(str), scale = scale or 0.34, colour = colour or G.C.UI.TEXT_LIGHT, shadow = true }
    if extra then for k, v in pairs(extra) do cfg[k] = v end end
    return UI.fit({ n = T, config = cfg })
end

--- The engine only honours maxw on containers; move it off a text node into a wrapper.
function UI.fit(tnode)
    local maxw = tnode.config.maxw
    if not maxw then return tnode end
    tnode.config.maxw = nil
    return { n = C, config = { align = 'cm', maxw = maxw }, nodes = { tnode } }
end

--- Text that re-reads `get()` every frame.
function UI.live(get, scale, colour, extra)
    local proxy = setmetatable({}, { __index = function()
        local ok, v = pcall(get)
        if ok and v ~= nil then return tostring(v) end
        return '-'
    end })
    local cfg = { ref_table = proxy, ref_value = 'v', scale = scale or 0.34, colour = colour or G.C.UI.TEXT_LIGHT, shadow = true }
    if extra then for k, v in pairs(extra) do cfg[k] = v end end
    return UI.fit({ n = T, config = cfg })
end

function UI.row(nodes, cfg)
    cfg = cfg or {}
    cfg.align = cfg.align or 'cm'
    return { n = R, config = cfg, nodes = nodes or {} }
end

--- Column container. Balatro only stacks R children vertically - an R placed after a C sibling
--- lands to its right - so when rows and non-rows are mixed, wrap the non-rows in rows.
function UI.col(nodes, cfg)
    cfg = cfg or {}
    cfg.align = cfg.align or 'cm'
    nodes = nodes or {}
    local has_row = false
    for _, n in ipairs(nodes) do if n.n == R then has_row = true break end end
    if has_row then
        for i, n in ipairs(nodes) do
            if n.n ~= R then nodes[i] = { n = R, config = { align = cfg.align }, nodes = { n } } end
        end
    end
    return { n = C, config = cfg, nodes = nodes }
end

function UI.spacer(w, h)
    return { n = B, config = { w = w or 0.1, h = h or 0.1 } }
end

--- Stack nodes vertically (wraps any non-row node in a row).
function UI.stack(nodes, cfg)
    local rows = {}
    for _, n in ipairs(nodes) do
        if n.n == R then rows[#rows + 1] = n else rows[#rows + 1] = UI.row({ n }) end
    end
    return UI.col(rows, cfg)
end

--- Lay out inline nodes in rows of `per_row`.
function UI.flow(nodes, per_row, cfg)
    local rows, cur = {}, {}
    for _, n in ipairs(nodes) do
        cur[#cur + 1] = n
        if #cur >= per_row then
            rows[#rows + 1] = UI.row(cur, { padding = (cfg and cfg.gap) or 0.04 })
            cur = {}
        end
    end
    if #cur > 0 then rows[#rows + 1] = UI.row(cur, { padding = (cfg and cfg.gap) or 0.04 }) end
    local c = cfg or {}
    c.gap = nil
    return UI.col(rows, c)
end

-------------------------------------------------------------------------------
-- Buttons & chips
-------------------------------------------------------------------------------
--- Text config for a label that is either a string or a function returning a string.
local function label_cfg(label, scale, colour, maxw)
    if type(label) == 'function' then
        local proxy = setmetatable({}, { __index = function()
            local ok, v = pcall(label)
            return ok and tostring(v) or '-'
        end })
        return { ref_table = proxy, ref_value = 'v', scale = scale, colour = colour, shadow = true, maxw = maxw }
    end
    return { text = tostring(label), scale = scale, colour = colour, shadow = true, maxw = maxw }
end

--- a: label (string|fn), colour, w, h, scale, on_click, tooltip, enabled(fn), text_colour, id, sub
function UI.button(a)
    local col = a.colour or G.C.RED
    local w, h = a.w or 1.8, a.h or 0.5
    local text_col = a.text_colour or UI.text_on(col)
    local tcfg = label_cfg(a.label, a.scale or 0.34, text_col, nil)
    local label_rows = { { n = R, config = { align = 'cm', maxw = w - 0.12 }, nodes = { { n = T, config = tcfg } } } }
    if a.sub then
        local sub_col = text_col == G.C.UI.TEXT_DARK and { 0.2, 0.25, 0.27, 0.8 } or { 1, 1, 1, 0.75 }
        label_rows[2] = { n = R, config = { align = 'cm', maxw = w - 0.12 }, nodes = { UI.text(a.sub, (a.scale or 0.34) * 0.7, sub_col) } }
    end
    local cfg = {
        align = 'cm', minw = w, minh = h, padding = a.padding or 0.05, r = a.r or 0.08,
        hover = true, shadow = true, colour = col, button = 'cshp_click', cs_click = a.on_click,
        tooltip = a.tooltip, id = a.id,
    }
    if a.enabled then
        local inactive = G.C.UI.BACKGROUND_INACTIVE
        cfg.func = 'cshp_sync'
        cfg.cs_sync = function(e)
            local en = a.enabled() and true or false
            if en ~= e.config.cs_en then
                e.config.cs_en = en
                e.config.colour = en and col or inactive
                e.config.button = en and 'cshp_click' or nil
                e.config.shadow = en
                tcfg.colour = en and text_col or G.C.UI.TEXT_INACTIVE
            end
        end
    end
    return { n = C, config = cfg, nodes = { { n = R, config = { align = 'cm' }, nodes = label_rows } } }
end

--- A selectable pill. a: label, colour, selected(fn), on_click, w, h, scale, tooltip, prefix_node
function UI.chip(a)
    local col = a.colour or G.C.RED
    local off = a.off_colour or UI.tint(col, 0.28)
    local tcfg = label_cfg(a.label, a.scale or 0.3, { 1, 1, 1, 0.7 }, nil)
    local on_text = UI.text_on(col)
    local inner = {}
    if a.prefix_node then inner[#inner + 1] = a.prefix_node; inner[#inner + 1] = UI.spacer(0.05) end
    inner[#inner + 1] = { n = T, config = tcfg }
    local cfg = {
        align = 'cm', minw = a.w or 1.2, minh = a.h or 0.4, padding = 0.04, r = 0.08,
        hover = true, colour = off, button = 'cshp_click', cs_click = a.on_click,
        tooltip = a.tooltip, func = 'cshp_sync',
    }
    cfg.cs_sync = function(e)
        local sel = a.selected and a.selected() and true or false
        if sel ~= e.config.cs_sel then
            e.config.cs_sel = sel
            e.config.colour = sel and col or off
            e.config.shadow = sel
            e.config.outline = sel and 1 or nil
            e.config.outline_colour = sel and G.C.WHITE or nil
            tcfg.colour = sel and on_text or { 1, 1, 1, 0.7 }
        end
    end
    return { n = C, config = cfg, nodes = { { n = R, config = { align = 'cm', maxw = (a.w or 1.2) - 0.1 }, nodes = inner } } }
end

--- A button that needs a second click within 2.5s to fire.
function UI.confirm_button(a)
    local armed_until = 0
    local b = {}
    for k, v in pairs(a) do b[k] = v end
    local base_label = a.label
    b.label = function()
        if G.TIMERS.REAL < armed_until then return a.confirm_label or 'Click again' end
        return type(base_label) == 'function' and base_label() or base_label
    end
    b.on_click = function(e)
        if G.TIMERS.REAL < armed_until then
            armed_until = 0
            a.on_click(e)
        else
            armed_until = G.TIMERS.REAL + 2.5
            CS.sfx('cancel', 1.4, 0.4)
        end
    end
    return UI.button(b)
end

--- Grid of items that adapts to however many a modpack adds.
--- make(item, w, h) -> node. a: per_row, max_rows, width (total, chip width is derived), w, h, gap, id, start_index
--- When there are more items than per_row * max_rows, the grid pages with a small < n/m > control.
UI._group_seq = 0
function UI.group(items, make, a)
    a = a or {}
    local per_row = a.per_row or 6
    local gap = a.gap or 0.05
    local h = a.h or 0.42
    local paged = a.max_rows and #items > per_row * a.max_rows
    local nav_w = paged and 0.62 or 0
    local w = a.w or 1.2
    if a.width then w = math.max(0.4, (a.width - nav_w - gap * (per_row + 1)) / per_row) end

    if not paged then
        local nodes = {}
        for _, it in ipairs(items) do nodes[#nodes + 1] = make(it, w, h) end
        return UI.flow(nodes, per_row, { gap = gap })
    end

    if not a.id then UI._group_seq = UI._group_seq + 1 end
    local id = 'cshp_grp_' .. (a.id or tostring(UI._group_seq))
    local per_page = per_row * a.max_rows
    local pages = math.ceil(#items / per_page)
    CS.view.group_pages = CS.view.group_pages or {}
    if not CS.view.group_pages[id] then
        CS.view.group_pages[id] = a.start_index and math.ceil(a.start_index / per_page) or 1
    end
    local grid_w = per_row * w + gap * (per_row + 1)
    local grid_h = a.max_rows * h + gap * (a.max_rows + 1) + 0.04 * a.max_rows
    local function build_page()
        local p = CS.clamp(CS.view.group_pages[id] or 1, 1, pages)
        local nodes = {}
        for i = (p - 1) * per_page + 1, math.min(#items, p * per_page) do nodes[#nodes + 1] = make(items[i], w, h) end
        return UI.root({ UI.flow(nodes, per_row, { gap = gap }) }, { align = 'tl', minw = grid_w, minh = grid_h })
    end
    local function turn(d)
        local p = (CS.view.group_pages[id] or 1) + d
        if p < 1 then p = pages elseif p > pages then p = 1 end
        CS.view.group_pages[id] = p
        CS.sfx('paper1', 1.1, 0.35)
        UI.replace(id, build_page)
    end
    local nav = UI.col({
        UI.row({ UI.button({ label = '<', w = 0.52, h = 0.34, scale = 0.28, colour = G.C.UI.BACKGROUND_INACTIVE, on_click = function() turn(-1) end }) }),
        UI.row({ UI.live(function() return (CS.view.group_pages[id] or 1) .. '/' .. pages end, 0.24, UI.muted()) }, { padding = 0.03 }),
        UI.row({ UI.button({ label = '>', w = 0.52, h = 0.34, scale = 0.28, colour = G.C.UI.BACKGROUND_INACTIVE, on_click = function() turn(1) end }) }),
    }, { minw = nav_w })
    return UI.row({ UI.slot(id, build_page, { minw = grid_w, minh = grid_h, align = 'tl' }), nav }, { align = 'cl' })
end

local function index_of(items, key)
    for i, it in ipairs(items) do if it.key == key then return i end end
end

--- Radio group of chips bound to tbl[field].
--- items: list of {key, label, colour, tooltip, prefix_node}
function UI.radio(items, tbl, field, a)
    a = a or {}
    a.start_index = a.start_index or index_of(items, tbl[field])
    return UI.group(items, function(it, w, h)
        return UI.chip({
            label = it.label, colour = it.colour or a.colour, w = w, h = h, scale = a.scale,
            tooltip = it.tooltip, prefix_node = it.prefix_node and it.prefix_node() or nil,
            selected = function() return tbl[field] == it.key end,
            on_click = function()
                if tbl[field] == it.key and a.allow_none then tbl[field] = a.none_key else tbl[field] = it.key end
                if a.on_change then a.on_change(tbl[field]) end
            end,
        })
    end, a)
end

--- Toggle-set of chips bound to set-table tbl[key] = true.
function UI.multi(items, set, a)
    a = a or {}
    return UI.group(items, function(it, w, h)
        return UI.chip({
            label = it.label, colour = it.colour or a.colour, w = w, h = h, scale = a.scale, tooltip = it.tooltip,
            selected = function() return set[it.key] and true or false end,
            on_click = function()
                set[it.key] = (not set[it.key]) or nil
                if a.on_change then a.on_change(it.key, set[it.key]) end
            end,
        })
    end, a)
end

--- ON/OFF switch. a: get, set(bool), colour
function UI.switch(a)
    local col = a.colour or G.C.GREEN
    return UI.chip({
        label = '', w = a.w or 0.95, h = a.h or 0.42, colour = col, off_colour = G.C.UI.BACKGROUND_INACTIVE,
        selected = a.get,
        on_click = function() a.set(not a.get()) end,
        prefix_node = UI.live(function() return a.get() and 'ON' or 'OFF' end, 0.3, G.C.UI.TEXT_LIGHT),
    })
end

-------------------------------------------------------------------------------
-- Composite widgets
-------------------------------------------------------------------------------
--- A dark value well.
function UI.pill(get, colour, w, h, scale)
    return {
        n = C,
        config = { align = 'cm', minw = w or 1.3, minh = h or 0.42, r = 0.08, colour = G.C.BLACK, padding = 0.03, emboss = 0.03 },
        nodes = { UI.live(get, scale or 0.34, colour or G.C.UI.TEXT_LIGHT, { maxw = (w or 1.3) - 0.1 }) },
    }
end

--- Label | [-big][-small] [value] [+small][+big]
--- a: label, get, add(delta), steps {small,big}, colour, label_w, value_w, enabled, tooltip, buttons (custom list)
function UI.stepper(a)
    local s1, s2 = (a.steps or {})[1] or 1, (a.steps or {})[2] or 5
    local bcol = a.button_colour or G.C.UI.BACKGROUND_INACTIVE
    local function btn(label, f)
        return UI.button({ label = label, w = a.btn_w or 0.6, h = 0.4, scale = 0.28, colour = bcol, on_click = f, enabled = a.enabled })
    end
    local left, right = {}, {}
    if a.buttons then
        for i, b in ipairs(a.buttons) do
            local node = btn(b[1], b[2])
            if i <= math.floor(#a.buttons / 2) then left[#left + 1] = node else right[#right + 1] = node end
        end
    else
        left = {
            btn('-' .. CS.fmt(s2), function() a.add(-s2 * CS.step_mult()) end),
            btn('-' .. CS.fmt(s1), function() a.add(-s1 * CS.step_mult()) end),
        }
        right = {
            btn('+' .. CS.fmt(s1), function() a.add(s1 * CS.step_mult()) end),
            btn('+' .. CS.fmt(s2), function() a.add(s2 * CS.step_mult()) end),
        }
    end
    local nodes = {
        { n = C, config = { align = 'cl', minw = a.label_w or 1.9, tooltip = a.tooltip, hover = a.tooltip and true or nil }, nodes = {
            UI.text(a.label, 0.3, G.C.UI.TEXT_LIGHT, { maxw = (a.label_w or 1.9) - 0.05 }),
        } },
    }
    for _, n in ipairs(left) do nodes[#nodes + 1] = n end
    nodes[#nodes + 1] = UI.pill(a.get, a.colour, a.value_w or 1.25)
    for _, n in ipairs(right) do nodes[#nodes + 1] = n end
    return UI.row(nodes, { padding = 0.03 })
end

--- Compact option cycler: [<] label [>]
--- a: options {key,label}, get, set(key), w, colour, prefix
function UI.cycler(a)
    local function idx()
        local k = a.get()
        for i, o in ipairs(a.options) do if o.key == k then return i end end
        return 1
    end
    local function shift(d)
        if #a.options == 0 then return end
        local i = idx() + d
        if i < 1 then i = #a.options elseif i > #a.options then i = 1 end
        a.set(a.options[i].key)
    end
    local w = a.w or 2.4
    -- A C node (not R) so cyclers sit inline next to other controls.
    return UI.col({
        UI.button({ label = '<', w = 0.42, h = a.h or 0.42, scale = 0.32, colour = a.colour or G.C.RED, on_click = function() shift(-1) end }),
        {
            n = C,
            config = { align = 'cm', minw = w, minh = a.h or 0.42, r = 0.08, colour = G.C.BLACK, padding = 0.03 },
            nodes = { UI.live(function()
                local o = a.options[idx()]
                return (a.prefix or '') .. (o and o.label or '-')
            end, 0.3, G.C.UI.TEXT_LIGHT, { maxw = w - 0.1 }) },
        },
        UI.button({ label = '>', w = 0.42, h = a.h or 0.42, scale = 0.32, colour = a.colour or G.C.RED, on_click = function() shift(1) end }),
    }, { padding = 0.03 })
end

--- Titled dark panel. a: title, colour, nodes, w, h, align, padding, subtitle, row (bool)
function UI.section(a)
    local nodes = {}
    if a.title then
        local head = {
            { n = C, config = { minw = 0.08, minh = 0.28, r = 0.04, colour = a.colour or G.C.WHITE } },
            UI.spacer(0.08),
            UI.text(a.title, 0.32, G.C.UI.TEXT_LIGHT),
        }
        if a.subtitle then
            head[#head + 1] = UI.spacer(0.12)
            head[#head + 1] = UI.text(a.subtitle, 0.26, UI.muted())
        end
        -- full-width rows keep the title pinned top-left even when the body is narrow
        nodes[#nodes + 1] = { n = R, config = { align = 'cl', padding = 0.02, minw = a.w and (a.w - 0.2) or nil }, nodes = head }
    end
    nodes[#nodes + 1] = { n = R, config = { align = a.align or 'cm', padding = a.padding or 0.04, minw = a.w and (a.w - 0.2) or nil }, nodes = a.nodes or {} }
    return {
        n = a.row and R or C,
        config = { align = 'tm', padding = 0.1, r = 0.12, colour = a.bg or G.C.BLACK, minw = a.w, minh = a.h, emboss = 0.05 },
        nodes = nodes,
    }
end

--- Centered message for empty / unavailable states.
function UI.notice(title, lines, colour)
    local rows = { UI.row({ UI.text(title, 0.5, colour or G.C.UI.TEXT_LIGHT) }, { padding = 0.1 }) }
    for _, l in ipairs(lines or {}) do
        rows[#rows + 1] = UI.row({ UI.text(l, 0.32, UI.muted()) }, { padding = 0.03 })
    end
    return UI.col(rows, { padding = 0.2 })
end

--- Replaces the UIBox held by an O-node with a freshly built definition.
function UI.replace(id, build)
    if not G.OVERLAY_MENU then return end
    local holder = G.OVERLAY_MENU:get_UIE_by_ID(id)
    if not holder then return end
    local ok, def = xpcall(build, debug.traceback)
    if not ok or type(def) ~= 'table' then
        CS.log(ok and 'panel builder returned nothing' or def)
        def = { n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR }, nodes = { UI.notice('This panel failed to build', { 'Details are in the log.' }, G.C.RED) } }
    end
    -- Build the replacement before tearing down the old one, so a failure leaves the panel intact.
    local built, box = xpcall(function()
        return UIBox({ definition = def, config = { offset = { x = 0, y = 0 }, parent = holder, type = 'cm' } })
    end, debug.traceback)
    if not built then
        CS.log(box)
        CS.toast('That panel could not be rebuilt (see log)', G.C.RED, 'cancel')
        return
    end
    if holder.config.object then holder.config.object:remove() end
    holder.config.object = box
    holder.UIBox:recalculate()
end

--- An O-node slot whose contents can be swapped with UI.replace(id, ...).
function UI.slot(id, build, cfg)
    local ok, def = xpcall(build, debug.traceback)
    if not ok or type(def) ~= 'table' then
        CS.log(ok and 'panel builder returned nothing' or def)
        def = { n = G.UIT.ROOT, config = { align = 'cm', colour = G.C.CLEAR }, nodes = { UI.notice('This panel failed to build', { 'Details are in the log.' }, G.C.RED) } }
    end
    local node_cfg = { align = 'cm' }
    if cfg then for k, v in pairs(cfg) do node_cfg[k] = v end end
    return { n = C, config = node_cfg, nodes = {
        { n = O, config = { id = id, object = UIBox({ definition = def, config = { offset = { x = 0, y = 0 }, align = 'cm' } }) } },
    } }
end

function UI.root(nodes, cfg)
    cfg = cfg or {}
    cfg.align = cfg.align or 'cm'
    cfg.colour = cfg.colour or G.C.CLEAR
    return { n = G.UIT.ROOT, config = cfg, nodes = nodes }
end
