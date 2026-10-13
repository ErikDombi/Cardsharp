--- Tools tab: snapshots, seed & restarts, deck tools, profile unlocks and settings.
local CS = Cardsharp
local UI, A = CS.UI, CS.A
local R, C = G.UIT.R, G.UIT.C

local ACCENT = function() return CS.TOOLS_COLOUR end
CS.TOOLS_COLOUR = HEX('3f9e9b')

local function snapshot_row(i)
    local function meta() return CS.config.snapshots[i] end
    local function line1()
        local m = meta()
        if not m then return 'Empty slot' end
        return ('Ante %s  -  Round %s  -  $%s'):format(tostring(m.ante), tostring(m.round), tostring(m.dollars))
    end
    local function line2()
        local m = meta()
        if not m then return 'Nothing saved yet' end
        return ('%s  -  %s'):format(tostring(m.deck), tostring(m.when))
    end
    return UI.row({
        { n = C, config = { align = 'cm', minw = 0.55, minh = 0.85, r = 0.1, colour = ACCENT() }, nodes = { UI.text(tostring(i), 0.45) } },
        { n = C, config = { align = 'cl', minw = 3.0, maxw = 3.0, padding = 0.04 }, nodes = {
            { n = R, config = { align = 'cl' }, nodes = { UI.live(line1, 0.3, G.C.UI.TEXT_LIGHT, { maxw = 2.95 }) } },
            { n = R, config = { align = 'cl' }, nodes = { UI.live(line2, 0.24, UI.muted(), { maxw = 2.95 }) } },
        } },
        UI.button({ label = 'Save', w = 0.85, h = 0.55, scale = 0.3, colour = G.C.GREEN, enabled = A.can_snapshot,
            on_click = function() A.save_snapshot(i) end }),
        UI.button({ label = 'Load', w = 0.85, h = 0.55, scale = 0.3, colour = G.C.BLUE, enabled = function() return meta() ~= nil end,
            on_click = function() A.load_snapshot(i) end }),
        UI.confirm_button({ label = 'x', confirm_label = '?', w = 0.45, h = 0.55, scale = 0.3, colour = G.C.RED,
            enabled = function() return meta() ~= nil end, on_click = function() A.clear_snapshot(i) end }),
    }, { padding = 0.05, colour = G.C.L_BLACK, r = 0.1 })
end

local function col_snapshots()
    local rows = {}
    for i = 1, A.SNAPSHOT_SLOTS do rows[#rows + 1] = snapshot_row(i) end
    rows[#rows + 1] = UI.row({ UI.spacer(0.1, 0.1) })
    for _, line in ipairs({
        'A snapshot freezes your whole run - cards,',
        'money, shop, everything - so you can jump',
        'back to it later. Snapshots survive restarts.',
        'Take them while choosing a hand, in the',
        'shop, or at blind select.',
    }) do rows[#rows + 1] = UI.row({ UI.text(line, 0.25, UI.muted()) }, { align = 'cl', padding = 0.01 }) end
    return UI.section({ title = 'SNAPSHOTS', subtitle = 'save states', colour = ACCENT(), w = 6.2, h = 7.5, align = 'tm', nodes = { UI.col(rows, { align = 'tm' }) } })
end

local function col_run()
    local function b(label, sub, colour, f, enabled, confirm)
        local args = { label = label, sub = sub, colour = colour, w = 4.9, h = 0.58, scale = 0.32, enabled = enabled, on_click = f }
        return UI.row({ confirm and UI.confirm_button(args) or UI.button(args) }, { padding = 0.035 })
    end
    local function b2(l1, f1, l2, f2, colour, enabled)
        return UI.row({
            UI.button({ label = l1, w = 2.4, h = 0.5, scale = 0.3, colour = colour, enabled = enabled, on_click = f1 }),
            UI.spacer(0.1),
            UI.button({ label = l2, w = 2.4, h = 0.5, scale = 0.3, colour = colour, enabled = enabled, on_click = f2 }),
        }, { padding = 0.035 })
    end
    return UI.section({ title = 'RUN & DECK', colour = ACCENT(), w = 5.4, h = 7.5, align = 'tm', nodes = { UI.col({
        UI.row({
            { n = C, config = { align = 'cl', minw = 0.9 }, nodes = { UI.text('Seed', 0.3, UI.muted()) } },
            UI.pill(function() return CS.in_run() and G.GAME.pseudorandom.seed or '-' end, G.C.UI.TEXT_LIGHT, 2.2, 0.45, 0.34),
            UI.spacer(0.08),
            UI.button({ label = 'Copy', w = 1.3, h = 0.45, scale = 0.3, colour = G.C.BLUE, enabled = CS.in_run, on_click = A.copy_seed }),
        }, { padding = 0.04 }),
        b('Restart, same seed', 'same deck & stake', G.C.ORANGE, function() A.restart_run(true) end, CS.in_run, true),
        b('Restart, new seed', 'same deck & stake', G.C.ORANGE, function() A.restart_run(false) end, CS.in_run, true),
        UI.row({ UI.spacer(0.1, 0.12) }),
        UI.row({ UI.text('DECK', 0.28, UI.muted()) }, { align = 'cl', padding = 0.02 }),
        b2('Draw 1 card', function() A.draw(1) end, 'Draw 5 cards', function() A.draw(5) end, G.C.BLUE,
            function() return CS.state_is('SELECTING_HAND') end),
        b2('Recycle discards', A.recycle_discards, 'Shuffle deck', A.shuffle_deck, G.C.BLUE, CS.in_run),
        b('Repair this run', 'adds hands & shop odds from mods installed mid-run', G.C.GREEN, function()
            local fixed = A.repair_run()
            A.ensure_shop_rates()
            if #fixed == 0 then CS.toast('Nothing to repair - this run is healthy', G.C.GREEN, 'generic1')
            else CS.toast(('Repaired %d missing entr%s (see log)'):format(#fixed, #fixed == 1 and 'y' or 'ies'), G.C.GREEN, 'generic1') end
        end, CS.in_run),
        UI.row({ UI.spacer(0.1, 0.12) }),
        UI.row({ UI.text('Deck counts', 0.28, UI.muted()) }, { align = 'cl', padding = 0.02 }),
        UI.row({ UI.live(function()
            if not CS.in_run() then return '-' end
            return ('%d in deck  -  %d in hand  -  %d discarded  -  %d total'):format(#G.deck.cards, #G.hand.cards, #G.discard.cards, #G.playing_cards)
        end, 0.27, G.C.UI.TEXT_LIGHT, { maxw = 5.0 }) }, { padding = 0.03 }),
    }, { align = 'tm' }) } })
end

local function setting_row(label, node)
    return UI.row({
        { n = C, config = { align = 'cl', minw = 3.15 }, nodes = { UI.text(label, 0.3, G.C.UI.TEXT_LIGHT, { maxw = 3.1 }) } },
        { n = C, config = { align = 'cr', minw = 2.3 }, nodes = { node } },
    }, { padding = 0.04 })
end

local function col_profile()
    return UI.section({ title = 'PROFILE & SETTINGS', colour = ACCENT(), w = 5.9, h = 7.5, align = 'tm', nodes = { UI.col({
        UI.row({ UI.confirm_button({ label = 'Unlock everything', sub = 'jokers, decks, stakes, vouchers...', w = 5.4, h = 0.62, scale = 0.32,
            colour = G.C.RED, confirm_label = 'Click again to unlock all', on_click = A.unlock_all }) }, { padding = 0.04 }),
        UI.row({ UI.confirm_button({ label = 'Discover everything', sub = 'fills the collection', w = 5.4, h = 0.62, scale = 0.32,
            colour = G.C.ORANGE, confirm_label = 'Click again to discover all', on_click = A.discover_all }) }, { padding = 0.04 }),
        UI.row({ UI.text('These change your profile permanently.', 0.24, UI.muted()) }, { padding = 0.02 }),
        UI.row({ UI.spacer(0.1, 0.2) }),
        setting_row('Menu hotkey', UI.button({
            label = function() return CS.capturing and 'Press a key...' or string.upper(CS.config.hotkey or 'f1') end,
            w = 2.1, h = 0.45, scale = 0.3, colour = G.C.BLUE,
            tooltip = { text = { 'Click, then press the key you want.', 'Esc cancels.' } },
            on_click = function() CS.capturing = true; CS.sfx('generic1', 1.2, 0.4) end,
        })),
        setting_row('Hotkey over a card edits it', UI.switch({
            get = function() return CS.config.hover_edit end,
            set = function(v) CS.config.hover_edit = v; CS.save_config() end,
        })),
        setting_row('Close menu after spawning', UI.switch({
            get = function() return CS.config.close_on_spawn end,
            set = function(v) CS.config.close_on_spawn = v; CS.save_config() end,
        })),
        setting_row('Background', UI.radio({
            { key = 1, label = 'Light' }, { key = 2, label = 'Dim' }, { key = 3, label = 'Dark' },
        }, CS.config, 'dim', { per_row = 3, w = 0.7, h = 0.4, scale = 0.26, colour = ACCENT(), on_change = function()
            CS.save_config()
            CS.apply_dim()
        end })),
        UI.row({ UI.spacer(0.1, 0.25) }),
        UI.row({ UI.text('Cardsharp v' .. CS.VERSION, 0.26, UI.muted()) }, { padding = 0.02 }),
    }, { align = 'tm' }) } })
end

local function build()
    return UI.row({ col_snapshots(), col_run(), col_profile() }, { align = 'tm', padding = 0.05 })
end

CS.register_tab({
    id = 'tools', label = 'Tools', colour = function() return CS.TOOLS_COLOUR end, order = 8, needs_run = false,
    build = build,
})
