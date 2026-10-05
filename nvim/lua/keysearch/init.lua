-- Search the keymap tables in README.md by description.
--
-- `<Space>sb` opens a search bar. Typing filters the tables by what the mappings
-- *do*, not by what they are called, so "reindent" finds `=wb` and every other row
-- whose Description mentions it. Rows that share a description are kept adjacent
-- so the variants of one action are visible together, which is the common case:
-- the README maps several keys to the same thing (all of `<C-Enter>`, `o<Esc>`,
-- `O<Esc>` reindent-adjacent commands, the whole `<C-w> h/j/k/l` family).
--
-- `<CR>` runs the mapping. The README has no Action column in most tables, so the
-- Key column is fed as keys instead; where an Action column exists it is preferred.

local M = {}

local opts = {
    --- Markdown file holding the tables. Defaults to README.md next to init.lua.
    readme = nil,
    --- How many rows to show before scrolling.
    max_results = 12,
}

local state = {
    entries = {},
    results = {},
    sel = 1,
    offset = 0,
    rewriting = false,
    query = '',
    buf = nil,
    win = nil,
    ns = nil,
}

local NS_ID = vim.api.nvim_create_namespace('keysearch')

local HL = {
    prompt = { fg = '#ffdd33', bold = true },
    match = { fg = '#ffdd33', bold = true },
    sel = { bg = '#3c3836', bold = true },
    key = { fg = '#96a6c8' },
    action = { fg = '#7c6f64' },
    desc = { fg = '#ebdbb2' },
    section = { fg = '#7c6f64' },
    meta = { fg = '#7c6f64' },
    rule = { fg = '#504945' },
    none = { fg = '#928374' },
}

local function define_highlights()
    for name, def in pairs(HL) do
        vim.api.nvim_set_hl(0, 'KeySearch' .. name:gsub('^%l', string.upper), def)
    end
    vim.api.nvim_set_hl(0, 'FloatBorder', { fg = '#7f8792' })
    vim.api.nvim_set_hl(0, 'FloatTitle', { fg = '#c8c8c8', bold = true })
end

--------------------------------------------------------------------------------
-- README parsing
--------------------------------------------------------------------------------

--- Split a markdown table row into cells, honouring the `\|` escape.
local function split_row(line)
    local inner = line:gsub('^%s*|', ''):gsub('|%s*$', '')
    local cells, current, escaped = {}, {}, false
    for i = 1, #inner do
        local ch = inner:sub(i, i)
        if escaped then
            current[#current + 1] = ch
            escaped = false
        elseif ch == '\\' then
            escaped = true
        elseif ch == '|' then
            cells[#cells + 1] = (table.concat(current):gsub('^%s+', ''):gsub('%s+$', ''))
            current = {}
        else
            current[#current + 1] = ch
        end
    end
    cells[#cells + 1] = (table.concat(current):gsub('^%s+', ''):gsub('%s+$', ''))
    return cells
end

--- Drop the backticks markdown wraps keys, commands and inline code in. Cells
--- such as `` `MiniTrailspace.trim()` + `gg=G` `` carry several, so stripping only
--- the outer pair leaves the inner ones visible in the list.
local function unquote(cell)
    if cell == nil then return nil end
    return (cell:gsub('`', ''))
end

local function is_separator(cells)
    for _, cell in ipairs(cells) do
        if not cell:match('^[%s:%-_|]*$') then return false end
    end
    return true
end

local function is_header(cells)
    local first = (cells[1] or ''):lower()
    return first == 'key' or first == 'keys' or first == 'mapping' or first == 'shortcut'
end

--- Read every markdown table row that looks like `Key | ... | Description`.
--- Handles both the 3-column tables (Key, Action, Description) and the 2-column
--- ones (Key, Description) that make up most of the file.
local function parse(path)
    local fd = io.open(path, 'r')
    if not fd then return {}, 'cannot read ' .. path end

    local entries, section, lineno = {}, nil, 0
    for line in fd:lines() do
        lineno = lineno + 1
        local heading = line:match('^#+%s+(.*)$')
        if heading then
            section = heading:gsub('%s*[%(%[].*$', ''):gsub('%s+$', '')
        elseif line:match('^%s*|') then
            local cells = split_row(line)
            if #cells >= 2 and not is_separator(cells) and not is_header(cells) then
                local key = unquote(cells[1])
                if key ~= '' then
                    local action, description
                    if #cells >= 3 then
                        action = unquote(cells[2])
                        description = unquote(cells[3])
                    else
                        description = unquote(cells[2])
                    end
                    -- A few tables have trailing empty columns.
                    description = (description or ''):gsub('%s*$', '')
                    if description == '' then
                        description = action or ''
                        action = nil
                    end
                    entries[#entries + 1] = {
                        section = section or 'General',
                        key = key,
                        action = action,
                        description = description,
                        line = lineno,
                    }
                end
            end
        end
    end
    fd:close()
    return entries, nil
end

--------------------------------------------------------------------------------
-- Matching
--------------------------------------------------------------------------------

local function positions_for(text, from, len)
    local list = {}
    for i = from, from + len - 1 do
        list[#list + 1] = i
    end
    return list
end

--- Fuzzy match `query` against `text`.
--- Returns score and matched column indices, or nil when there is no match.
--- Plain substring hits are preferred and boosted at word starts, because a
--- description like "Close tab" should rank above a stray subsequence match.
local function fuzzy(query, text)
    if query == '' then return 0, {} end
    local q, t = query:lower(), text:lower()

    local from, to = t:find(q, 1, true)
    if from then
        local score = 1000 - math.min(from, 400)
        if from == 1 then score = score + 200 end
        local before = from > 1 and t:sub(from - 1, from - 1) or ' '
        if before:match('[%s%(,%-%_/]') then score = score + 120 end
        return score, positions_for(t, from, to - from + 1)
    end

    local cursor, score, hits, streak = 1, 0, {}, 0
    for i = 1, #q do
        local ch = q:sub(i, i)
        local at = t:find(ch, cursor, true)
        if not at then return nil end
        streak = (at == cursor and i > 1) and (streak + 1) or 0
        score = score + 10 + streak * 6 - math.min(at - cursor, 12)
        local before = at > 1 and t:sub(at - 1, at - 1) or ' '
        if before:match('[%s%(,%-%_/]') then score = score + 18 end
        hits[#hits + 1] = at
        cursor = at + 1
    end
    -- A subsequence scattered across a long description can score zero or less
    -- once the gap penalty is applied. Returning it anyway padded every result
    -- list with unrelated rows: "LSP" matched 36 entries instead of the handful
    -- in the LSP section.
    if score <= 0 then return nil end
    return score, hits
end

--- Score one entry.
---
--- The description is the primary field, since the panel exists to search by what a
--- mapping *does*. The section is searchable too, so typing "LSP" or "Window
--- Management" pulls in that whole block of rows at once. The key and the action
--- still match, but rank below both.
---
--- Returns score, matched positions, and whether the section was what matched --
--- the caller uses that to drop the "(section)" suffix, which is redundant when
--- you searched for the section in the first place.
local function score_entry(entry, query)
    if query == '' then return 0, {}, false end

    local dscore, dhits = fuzzy(query, entry.description)
    local sscore, shits = fuzzy(query, entry.section)
    local kscore, khits = fuzzy(query, entry.key)
    local ascore, ahits
    if entry.action then
        ascore, ahits = fuzzy(query, entry.action)
    end

    local best, best_hits, via_section

    local function offer(score, hits, weight, is_section)
        if not score then return end
        local weighted = score * weight
        if best == nil or weighted > best then
            best, best_hits, via_section = weighted, hits, is_section or false
        end
    end

    offer(dscore, dhits, 1.0, false)
    -- A section hit is a deliberate "show me this block" request, so it gets a
    -- flat bonus and outranks everything instead of competing with description
    -- matches. Otherwise the wanted rows were interleaved with fuzzy noise.
    if sscore then
        offer(sscore + 2000, shits, 1.0, true)
    end
    offer(kscore, khits, 0.55, false)
    offer(ascore, ahits, 0.4, false)

    if best == nil then return nil end
    return best, best_hits or {}, via_section
end

local function search(query)
    if query == '' then
        local all = {}
        for i, entry in ipairs(state.entries) do
            all[#all + 1] = { entry = entry, index = i, hits = {}, section_hit = false }
        end
        return all
    end

    local scored = {}
    for i, entry in ipairs(state.entries) do
        local score, hits, section_hit = score_entry(entry, query)
        if score then
            scored[#scored + 1] = {
                entry = entry, index = i, score = score,
                hits = hits, section_hit = section_hit,
            }
        end
    end

    -- Sort by score, then by description, so every row sharing a description ends
    -- up next to its variants instead of scattered by key name.
    table.sort(scored, function(a, b)
        if a.score ~= b.score then return a.score > b.score end
        if a.entry.description ~= b.entry.description then
            return a.entry.description < b.entry.description
        end
        return a.index < b.index
    end)
    return scored
end

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

local function display_width(text)
    return vim.fn.strdisplaywidth(text)
end

local function pad(text, width)
    local pad_by = width - display_width(text)
    if pad_by <= 0 then return text end
    return text .. string.rep(' ', pad_by)
end

local function clip(text, width)
    if display_width(text) <= width then return text end
    return vim.fn.strcharpart(text, 0, width - 1)
end

local function render()
    if not state.buf or not vim.api.nvim_buf_is_valid(state.buf) then return end

    local query = state.query
    state.results = search(query)
    local count = #state.results
    if count == 0 then
        state.sel, state.offset = 1, 0
    else
        state.sel = math.min(state.sel, count)
        -- Scroll the slice so the selection stays visible, and never scroll past
        -- the end, otherwise rows past max_results are unreachable.
        local visible = math.min(opts.max_results, count)
        if state.sel <= state.offset then
            state.offset = state.sel - 1
        elseif state.sel > state.offset + visible then
            state.offset = state.sel - visible
        end
        state.offset = math.max(0, math.min(state.offset, count - visible))
    end

    -- Measure the float, not the editor: the float is narrower than columns-4
    -- once it hits its width cap, and the rule would then wrap.
    local inner = math.max(
        (state.win and vim.api.nvim_win_is_valid(state.win))
            and vim.api.nvim_win_get_width(state.win) or vim.o.columns - 4,
        40
    )

    local key_w, action_w = 8, 0
    for _, hit in ipairs(state.results) do
        key_w = math.max(key_w, math.min(display_width(hit.entry.key), 24))
        if hit.entry.action then
            action_w = math.max(action_w, math.min(display_width(hit.entry.action), 30))
        end
    end
    key_w = math.min(key_w + 2, math.max(inner - 20, 10))
    if action_w > 0 then action_w = math.min(action_w + 2, math.max(inner - key_w - 24, 0)) end

    -- Line 1 is the user's query and is never rewritten, so the cursor and the
    -- text stay put while results below change. Everything from line 2 on is
    -- rebuilt on each keystroke.
    local lines, marks = {}, {}
    local function mark(row, col_start, col_end, group)
        marks[#marks + 1] = { row, col_start, col_end, group }
    end

    local rule = string.rep('─', math.max(inner - 2, 1))
    lines[#lines + 1] = ' ' .. rule
    mark(1, 1, 1 + #rule, 'KeySearchRule')

    local total, count = #state.results, #state.results
    local first = state.offset + 1
    local last = math.min(count, state.offset + opts.max_results)
    for i = first, last do
        local hit = state.results[i]
        local entry = hit.entry
        local row = #lines + 1

        local key_text = clip(pad(entry.key, key_w), key_w)
        local action_text = action_w > 0 and entry.action and clip(pad(entry.action, action_w), action_w) or ''

        local prefix = string.format('%d. ', i)
        -- Byte offset of the description: extmark columns are byte based, and
        -- the line starts with a space that display_width(prefix) does not count.
        -- Leaving it off shifted every match one character left, so searching
        -- "cursor" lit up " curso" and dropped the trailing "r".
        local desc_col = 1 + #prefix + key_w + #action_text
        -- Redundant when the search was on the section name itself.
        local section_text = hit.section_hit and '' or ('  (' .. entry.section .. ')')
        -- Show the section only when the description does not need the columns;
        -- the description is what the user searched for, so it wins.
        local room = math.max(inner - desc_col - 2, 8)
        if display_width(entry.description) + 14 > room then
            section_text = ''
            room = math.max(inner - desc_col - 2, 8)
        end
        local desc_text = clip(entry.description, room)

        local line = ' ' .. prefix .. key_text .. action_text .. desc_text .. section_text
        lines[#lines + 1] = line

        local base = 1
        mark(row, base, base + #prefix, 'KeySearchMeta')
        mark(row, base + #prefix, base + #prefix + key_w, 'KeySearchKey')
        if #action_text > 0 then
            mark(row, base + #prefix + key_w, base + #prefix + key_w + #action_text, 'KeySearchAction')
        end
        mark(row, desc_col, desc_col + #desc_text, 'KeySearchDesc')
        mark(row, desc_col + #desc_text, #line, 'KeySearchSection')

        -- matched characters inside the description
        for _, at in ipairs(hit.hits or {}) do
            if at > 0 and at <= #desc_text then
                mark(row, desc_col + at - 1, desc_col + at, 'KeySearchMatch')
            end
        end

        if i == state.sel then
            mark(row, 0, #line, 'KeySearchSel')
        end
    end

    if count == 0 then
        local note = 'no keymap matches that description'
        lines[#lines + 1] = '   ' .. note
        mark(#lines, 3, 3 + #note, 'KeySearchNone')
    elseif count > opts.max_results then
        local note = string.format('%d-%d of %d', first, last, count)
        lines[#lines + 1] = '   ' .. note
        mark(#lines, 3, 3 + #note, 'KeySearchMeta')
    end

    local meta = string.format('%d/%d   <CR> run   <Tab> next   <C-u> clear   <Esc> quit',
        math.min(state.sel, count), count)
    lines[#lines + 1] = ' ' .. meta
    mark(#lines, 1, 1 + #meta, 'KeySearchMeta')

    vim.api.nvim_buf_clear_namespace(state.buf, NS_ID, 0, -1)
    vim.api.nvim_buf_set_lines(state.buf, 1, -1, false, lines)

    -- The '> ' marker is real text so the caret lands after it the way it does in
    -- :command-line. Only the hint is virtual text: as buffer content it became
    -- part of the query, and deleting it made it reappear and get searched for.
    -- No inline placeholder. It has to be virtual text (as buffer text it became
    -- part of the query) but any inline virtual text at column 2 blocked the
    -- caret from reaching column 2, so it sat at column 1 and the first
    -- character typed landed before the marker's space: "hello" became "h ello".
    -- The hint lives in the window title instead.

    -- Explicit start/end columns: with hl_eol or end_col = -1 this build places
    -- the extmark but paints nothing.
    for _, m in ipairs(marks) do
        vim.api.nvim_buf_set_extmark(state.buf, NS_ID, m[1], m[2], {
            end_col = m[3],
            hl_group = m[4],
        })
    end

    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_set_height(state.win, math.min(#lines + 1, math.max(vim.o.lines - 4, 8)))
        -- Stay on the prompt line, right after '> '. Never move onto a result row:
        -- it pulls the caret off the prompt, so the first character lands in the
        -- query and the rest land in the list, which the next render overwrites.
        pcall(vim.api.nvim_win_set_cursor, state.win, { 1, 2 + #state.query })
    end
end

--- Run an entry by feeding its Key column.
---
--- The Action column is deliberately not executed: the README writes it
--- descriptively, not literally. `init_selection` is really `tsis.init_selection`,
--- `Visual` and `Vim help` are modes and prose rather than commands, and
--- `MiniTrailspace.trim()` + `gg=G` is two commands in one cell. The Key column
--- is always a real key sequence, and feeding it lets Neovim resolve it through
--- the actual keymaps, so those ambiguities never come up.
-- The panel is a single-mode search bar, so the block cursor looked wrong: you
-- type into it like insert mode, so it should look like insert mode. 'guicursor'
-- is window-local in the option metadata but effectively global in 0.12.4, so the
-- normal-mode entry is rewritten while the panel is open and put back on close.
-- The insert-mode entry already is ver25, which is the stick.
local saved_guicursor = nil

local function show_stick_cursor()
    saved_guicursor = vim.o.guicursor
    local updated = saved_guicursor:gsub('n%-v%-c%-sm:block', 'n-v-c-sm:ver25')
    if updated == saved_guicursor then
        updated = 'n-v-c-sm:ver25,' .. saved_guicursor
    end
    pcall(function() vim.o.guicursor = updated end)
end

local function restore_cursor_shape()
    if saved_guicursor then
        pcall(function() vim.o.guicursor = saved_guicursor end)
        saved_guicursor = nil
    end
end

-- The prompt line carries one trailing space that is *not* part of the query.
--- A normal-mode caret cannot rest past the last character, so without a cell to
--- sit in it rendered one to the left of where it belonged -- typing "space" put
--- the stick before the "e". query_from_line strips it again.
local function prompt_text(query)
    return '> ' .. query .. ' '
end

local function query_from_line(line)
    if line:sub(1, 2) ~= '> ' then
        if line:sub(1, 1) == '>' then
            return vim.trim(line:sub(2))
        end
        return line
    end
    local text = line:sub(3)
    if text:sub(-1) == ' ' then text = text:sub(1, -2) end
    return text
end

local function set_prompt(query)
    vim.api.nvim_buf_set_lines(state.buf, 0, 1, false, { prompt_text(query) })
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        pcall(vim.api.nvim_win_set_cursor, state.win, { 1, 2 + #query })
    end
end

local function close()
    -- Leaving insert mode behind is jarring: the buffer you return to would be
    -- in insert mode with no visible reason.
    pcall(vim.cmd, 'stopinsert')
    restore_cursor_shape()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_close(state.win, true)
    end
    state.win, state.buf = nil, nil
end

--- Quit from a key mapping, once the mapping has given the keyboard back.
local function quit()
    vim.schedule(close)
end

--- Termcodes for an entry's Key column, ready for feedkeys.
local function keys_for(entry)
    local text = entry.key

    -- `<leader>` is documentation shorthand; feedkeys needs the real key.
    local leader = vim.g.mapleader
    if leader ~= nil then
        local ok, keys = pcall(vim.api.nvim_replace_termcodes, leader, true, false, true)
        if ok and keys ~= '' then
            text = text:gsub('<[lL]eader>', function() return keys end)
        end
    end

    return vim.api.nvim_replace_termcodes(text, true, false, true)
end

--- Close the panel and then run the entry.
---
--- Both halves are deferred with vim.schedule on purpose. Closing a float from
--- inside an insert-mode mapping happens while the mapping still owns the
--- keyboard: the window never went away, focus stayed on the search buffer, and
--- the keys were fed to a buffer that was about to disappear, so the mapping
--- never ran. Scheduling waits for insert mode to finish and the mapping to
--- return first.
local function run_and_close(entry)
    -- Leave insert mode first, and synchronously. The <CR> binding is insert-mode,
    -- so this runs while insert is still active; a merely *queued* <Esc> does not
    -- land before the window closes, and the payload then arrives as literal
    -- keystrokes and is typed into whatever buffer is current. 'x' is what makes
    -- the <Esc> execute now rather than sit in the typeahead.
    local leave = vim.api.nvim_replace_termcodes('<Esc>', true, false, true)
    pcall(vim.api.nvim_feedkeys, leave, 'nx', false)

    vim.schedule(function()
        close()
        if not entry then return end

        -- Second tick: in the same tick as nvim_win_close the keys were swallowed
        -- while focus was still moving back to the previous window.
        vim.schedule(function()
            -- Guard: if the panel is somehow still the current buffer, the payload
            -- would be typed into the search box instead of the file.
            if state.buf and vim.api.nvim_buf_is_valid(state.buf)
                and vim.api.nvim_get_current_buf() == state.buf
                and state.win and vim.api.nvim_win_is_valid(state.win)
            then
                pcall(vim.api.nvim_win_close, state.win, true)
            end

            local keys = keys_for(entry)
            if keys == '' then return end
            -- 'm' so the mapping fires, 'x' so the keys are actually consumed.
            -- Without 'x' they sat unprocessed in the typeahead; ':normal' does
            -- not work either, it bypasses the mapping.
            vim.api.nvim_feedkeys(keys, 'mtx', false)
        end)
    end)
end

--------------------------------------------------------------------------------
-- Window
--------------------------------------------------------------------------------


local function move(delta)
    local count = #state.results
    if count == 0 then return end
    state.sel = ((state.sel - 1 + delta) % count) + 1
    render()
end

function M.open()
    local path = opts.readme
    if not path then
        path = vim.fn.fnamemodify(vim.fn.stdpath('config'), ':p') .. '/README.md'
    end
    if vim.fn.filereadable(path) ~= 1 then
        vim.notify('keysearch: no README at ' .. path, vim.log.levels.ERROR)
        return
    end

    local entries, err = parse(path)
    if err then
        vim.notify('keysearch: ' .. err, vim.log.levels.ERROR)
        return
    end
    state.entries = entries

    define_highlights()
    state.query = ''
    state.sel = 1
    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].bufhidden = 'wipe'

    local width = math.min(math.max(vim.o.columns - 4, 40), 110)
    local height = math.min(#entries + 5, math.max(vim.o.lines - 6, 10))
    state.win = vim.api.nvim_open_win(state.buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = 1,
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' Control panel/Keymap search ',
        title_pos = 'center',
    })
    vim.wo[state.win].cursorline = false

    -- Insert mode only, like :command-line. There is no normal-mode layer to speak
    -- of: normal mode only exists for the moment before insert mode engages, and
    -- `i` / <C-c> are kept below purely as a way in and out if that ever fails.
    local function map(lhs, fn, desc)
        vim.keymap.set('i', lhs, fn,
            { buffer = state.buf, nowait = true, silent = true, desc = desc })
    end

    map('<CR>', function()
        local hit = state.results[state.sel]
        run_and_close(hit and hit.entry or nil)
    end, 'Run the selected keymap')

    map('<Esc>', quit, 'Quit')
    map('<C-c>', quit, 'Quit')
    map('<Tab>', function() move(1) end, 'Next match')
    map('<S-Tab>', function() move(-1) end, 'Previous match')
    map('<C-n>', function() move(1) end, 'Next match')
    map('<C-p>', function() move(-1) end, 'Previous match')
    map('<Down>', function() move(1) end, 'Next match')
    map('<Up>', function() move(-1) end, 'Previous match')
    map('<C-u>', function()
        state.query = ''
        state.sel = 1
        set_prompt('')
        render()
    end, 'Clear the search')

    -- Typing.
    --
    -- Printable characters are bound in normal mode as well, because entering
    -- insert mode on a fresh float never became reliable and every uncaught
    -- keystroke landed in the user's own buffer instead ('/' even started a
    -- search: "E486: Pattern not found"). Two mappings were tried instead --
    -- vim.on_key, and startinsert -- and both misfired; explicit bindings behave
    -- predictably and are what earlier versions of this plugin used successfully.
    --
    -- The cost is that this is the only mode: 'v' does not start visual mode and
    -- 'q' does not quit, so quit is <Esc> and clearing is <C-u>. In exchange every
    -- printable character is typeable, which is what the panel is for.
    local function type_char(ch)
        state.query = state.query .. ch
        state.sel = 1
        set_prompt(state.query)
        render()
    end

    for byte = 32, 126 do
        local ch = string.char(byte)
        vim.keymap.set('n', ch, function() type_char(ch) end, {
            buffer = state.buf, nowait = true, silent = true, desc = 'Type to search',
        })
    end

    vim.keymap.set('n', '<BS>', function()
        if state.query == '' then return end
        state.query = state.query:sub(1, -2)
        state.sel = 1
        set_prompt(state.query)
        render()
    end, { buffer = state.buf, nowait = true, silent = true, desc = 'Delete a character' })

    -- Normal-mode navigation and actions.
    vim.keymap.set('n', '<CR>', function()
        local hit = state.results[state.sel]
        run_and_close(hit and hit.entry or nil)
    end, { buffer = state.buf, nowait = true, silent = true, desc = 'Run the selected keymap' })
    vim.keymap.set('n', '<C-n>', function() move(1) end,
        { buffer = state.buf, nowait = true, silent = true, desc = 'Next match' })
    vim.keymap.set('n', '<C-p>', function() move(-1) end,
        { buffer = state.buf, nowait = true, silent = true, desc = 'Previous match' })
    vim.keymap.set('n', '<Down>', function() move(1) end,
        { buffer = state.buf, nowait = true, silent = true, desc = 'Next match' })
    vim.keymap.set('n', '<Up>', function() move(-1) end,
        { buffer = state.buf, nowait = true, silent = true, desc = 'Previous match' })
    vim.keymap.set('n', '<Tab>', function() move(1) end,
        { buffer = state.buf, nowait = true, silent = true, desc = 'Next match' })
    vim.keymap.set('n', '<S-Tab>', function() move(-1) end,
        { buffer = state.buf, nowait = true, silent = true, desc = 'Previous match' })
    vim.keymap.set('n', '<C-u>', function()
        state.query = ''
        state.sel = 1
        set_prompt('')
        render()
    end, { buffer = state.buf, nowait = true, silent = true, desc = 'Clear the search' })
    vim.keymap.set('n', '<Esc>', quit,
        { buffer = state.buf, nowait = true, silent = true, desc = 'Quit' })
    vim.keymap.set('n', '<C-c>', quit,
        { buffer = state.buf, nowait = true, silent = true, desc = 'Quit' })


    local function set_query(text)
        state.query = text
        state.sel = 1
        set_prompt(text)
        render()
    end

    -- Backspace rewrites the prompt line rather than editing it, so the '> '
    -- marker cannot be deleted by holding the key.
    vim.keymap.set('i', '<BS>', function()
        if state.query ~= '' then set_query(state.query:sub(1, -2)) end
    end, { buffer = state.buf, silent = true, desc = 'Delete a character' })

    vim.api.nvim_create_autocmd({ 'TextChanged', 'TextChangedI' }, {
        buffer = state.buf,
        group = vim.api.nvim_create_augroup('keysearch', { clear = true }),
        callback = function()
            if state.rewriting then return end
            local line = vim.api.nvim_buf_get_lines(state.buf, 0, 1, false)[1] or ''

            -- Recover the query from however the marker got damaged, then put the
            -- line back to '> ' .. query and return the caret to the end. Left
            -- alone, one keystroke at column 1 produced things like ">c ur": the
            -- character landed before the marker's space and the rest of the query
            -- was then searched as though the space were part of it.
            local query = query_from_line(line)

            if query ~= state.query then
                state.query = query
                state.sel = 1
            end

            local want = prompt_text(state.query)
            if line ~= want then
                state.rewriting = true
                vim.api.nvim_buf_set_lines(state.buf, 0, 1, false, { want })
                pcall(vim.api.nvim_win_set_cursor, state.win, { 1, 2 + #state.query })
                state.rewriting = false
            end

            render()
        end,
    })

    vim.api.nvim_buf_set_lines(state.buf, 0, -1, false, { prompt_text('') })
    show_stick_cursor()
    render()
    -- Deliberately no automatic insert mode. Feeding an 'i' to request it kept
    -- landing as a literal 'i' in the query whenever the timing was off, and with
    -- the typing fallback above, normal mode already accepts the whole query.
    -- Press i (or <C-i>) when you want insert mode instead.
end

function M.setup(user)
    opts = vim.tbl_deep_extend('force', opts, user or {})
end

return M
