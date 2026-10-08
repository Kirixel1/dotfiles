-- Browse and search the Godot documentation without leaving Neovim.
--
-- `<Space>gd` opens a panel shaped like the keysearch one: rounded float, one
-- keystroke to move, printable characters type into the query, no normal-mode
-- layer to fight.
--
-- Two scopes share the panel. At the root it lists the six sections the site
-- itself presents -- About, Getting started, Manual, Engine details, Community
-- and Class reference -- and stepping into one lists its pages.
--
-- Typing filters whatever is on screen. At the root that means every entry the
-- Sphinx inventory holds, including the ~26,700 method and property anchors, so
-- `flip_h` reaches `Sprite2D.flip_h` even though no page is named after it;
-- inside a section the same query searches that section alone.
--
-- The index comes from `objects.inv`, Sphinx's machine-readable inventory. Page
-- text is the rendered HTML, converted to styled text in html.lua and coloured
-- from the site's own stylesheet by palette.lua. Both are cached under
-- stdpath('cache'), so this works offline after the first run.

local M = {}

local uv = vim.uv or vim.loop

-- The six sections the documentation presents, in the order its own navigation
-- lists them. Taken from that navigation rather than from the inventory's
-- directory names, because the two disagree: the manual is filed under
-- tutorials/ and shown as "Manual", the class reference under classes/ and shown
-- as "Class reference". Spelling them out here keeps the panel showing what the
-- site shows instead of what the filesystem underneath happens to be called.
local SECTIONS = {
    { title = 'About', prefix = 'about' },
    { title = 'Getting started', prefix = 'getting_started' },
    { title = 'Manual', prefix = 'tutorials' },
    { title = 'Engine details', prefix = 'engine_details' },
    { title = 'Community', prefix = 'community' },
    { title = 'Class reference', prefix = 'classes' },
}

local SECTION_TITLE = {}
for _, section in ipairs(SECTIONS) do
    SECTION_TITLE[section.prefix] = section.title
end

local opts = {
    --- Base of the documentation tree the inventory is taken from.
    base = 'https://docs.godotengine.org/en/latest/',
    --- Re-download the inventory after this many days.
    max_age_days = 7,
    --- Rows drawn before the list scrolls.
    max_rows = 14,
    --- Hide index entries that are not real pages.
    --- Turned off because the method and property anchors are the useful part.
    named_only = false,
}

local state = {
    entries = {},      -- every usable index entry
    by_section = {},   -- section name -> entries, for the browse blocks
    class_name = {},   -- inventory name -> display name
    scope = {},        -- stack of section names; empty means the root block list
    query = '',
    rows = {},
    sel = 1,
    offset = 0,
    buf = nil,
    win = nil,
    ns = nil,
    loading = false,
    busy = false,
}

local NS_ID = vim.api.nvim_create_namespace('godot_docs')

-- show_doc repaints while a page downloads, and it is defined before the
-- renderer below, so the name has to exist first.
local render

-- Same colours as the keysearch panel, so the two read as one control surface.
-- Renamed to GodotDocs* to keep the groups separate, but the values are
-- identical: prompt and match #ffdd33, selection #3c3836, section #7c6f64,
-- name #ebdbb2, rule #504945.
local HL = {
    prompt = { fg = '#ffdd33', bold = true },
    match = { fg = '#ffdd33', bold = true },
    sel = { bg = '#3c3836', bold = true },
    name = { fg = '#ebdbb2' },
    key = { fg = '#96a6c8' },
    section = { fg = '#7c6f64' },
    hint = { fg = '#7c6f64' },
    meta = { fg = '#7c6f64' },
    rule = { fg = '#504945' },
    none = { fg = '#928374' },
}

local function display_width(text)
    return vim.fn.strdisplaywidth(text)
end

local function clip(text, width)
    if display_width(text) <= width then
        return text
    end
    return vim.fn.strcharpart(text, 0, width - 1)
end

local function define_highlights()
    for name, def in pairs(HL) do
        vim.api.nvim_set_hl(0, 'GodotDocs' .. name:gsub('^%l', string.upper), def)
    end
    vim.api.nvim_set_hl(0, 'FloatBorder', { fg = '#7f8792' })
    vim.api.nvim_set_hl(0, 'FloatTitle', { fg = '#c8c8c8', bold = true })
end

--------------------------------------------------------------------------------
-- Cache
--------------------------------------------------------------------------------

local function cache_dir()
    return opts.cache or (vim.fn.stdpath('cache') .. '/godot-docs')
end

local function ensure_dir(path)
    vim.fn.mkdir(path, 'p')
    return path
end

local function file_age_days(path)
    local stat = uv.fs_stat(path)
    if not stat then
        return math.huge
    end
    -- luv reports mtime as {sec, nsec}, not a number.
    local mtime = type(stat.mtime) == 'table' and stat.mtime.sec or stat.mtime
    return (os.time() - mtime) / 86400
end

local function read_file(path)
    local fd = io.open(path, 'r')
    if not fd then
        return nil
    end
    local data = fd:read('*a')
    fd:close()
    return data
end

local function write_file(path, data)
    local fd = io.open(path, 'w')
    if not fd then
        return false
    end
    fd:write(data)
    fd:close()
    return true
end

--------------------------------------------------------------------------------
-- Fetching the inventory
--------------------------------------------------------------------------------

-- The inventory is a short `#` header followed by a zlib stream. LuaJIT has no
-- zlib, so python3 does the inflate; only if it is missing does this fail, and
-- then the message says so rather than reporting an empty index.
local PY_INFLATE = [[
import sys, zlib
raw = open(sys.argv[1], 'rb').read()
best = None
for magic in (b'\x78\x9c', b'\x78\xda', b'\x78\x01'):
    at = raw.find(magic)
    if at != -1 and (best is None or at < best):
        best = at
if best is None:
    sys.exit('no zlib stream found')
data = zlib.decompressobj().decompress(raw[best:])
open(sys.argv[2], 'wb').write(data)
]]

local function run(cmd, on_done)
    vim.system(cmd, { text = true }, function(result)
        vim.schedule(function()
            on_done(result)
        end)
    end)
end

local function download_inventory(done)
    local dir = ensure_dir(cache_dir())
    local inv = dir .. '/objects.inv'
    local txt = dir .. '/objects.txt'

    if file_age_days(inv) < opts.max_age_days and file_age_days(txt) < opts.max_age_days then
        done(nil, true)
        return
    end

    run({ 'curl', '-fsSL', '--max-time', '60', opts.base .. 'objects.inv', '-o', inv }, function(res)
        if res.code ~= 0 then
            done('could not download objects.inv: ' .. (res.stderr or ''):gsub('%s+$', ''), false)
            return
        end
        run({ 'python3', '-c', PY_INFLATE, inv, txt }, function(res2)
            if res2.code ~= 0 then
                done('could not unpack the inventory (needs python3): '
                    .. (res2.stderr or ''):gsub('%s+$', ''), false)
                return
            end
            done(nil, true)
        end)
    end)
end

--------------------------------------------------------------------------------
-- Parsing the inventory
--------------------------------------------------------------------------------

-- Inventory lines are `name type priority url display`. Display is `-` when the
-- entry is only an anchor inside a page, which is what most method and property
-- entries are.
local function section_of(url)
    -- `*` not `-`: a lazy repeat would match the empty string and put every
    -- entry in one section.
    local path = url:match('^([^/#]+)') or url
    return (path:gsub('%.html$', ''))
end

-- `class_<cls>_method_<member>` and the property variant. The class part can hold
-- underscores, so the keyword is located rather than pattern-matched from the
-- right: taking whichever keyword comes first keeps `set_property` a method of
-- Node instead of a class called `node_method_set`.
local function split_member(name)
    local rest = name:match('^class_(.+)$')
    if not rest then
        return nil
    end
    -- The second return of find is an end index, not a length, so the keyword
    -- lengths are spelled out: skipping one character would leave
    -- `property_flip_h` sitting on the member name.
    local at_m = rest:find('_method_', 1, true)
    local at_p = rest:find('_property_', 1, true)
    local at, kind, skip
    if at_m and (not at_p or at_m < at_p) then
        at, kind, skip = at_m, 'method', 8
    elseif at_p then
        at, kind, skip = at_p, 'property', 10
    else
        return nil
    end
    local class = rest:sub(1, at - 1)
    local member = rest:sub(at + skip)
    if class == '' or member == '' then
        return nil
    end
    return 'class_' .. class, kind, member
end

-- The inventory expands to about 28,000 entries and re-deriving all of them from
-- the 4 MB decompressed text costs seconds on every open. Since only a handful of
-- fields per entry are ever used, they are written once to a tab-separated cache
-- next to the inventory and read back from then on: one split per line, no
-- pattern work per entry, no class-name resolution.
--
-- Field order is section, kind, display, url, bare alias, inventory name. The
-- bare alias and the inventory name are kept so searching behaves identically
-- whichever path loaded the index.
local INDEX_CACHE = 'index.tsv'

local function write_index_cache(entries)
    local parts = {}
    for _, e in ipairs(entries) do
        parts[#parts + 1] = table.concat({
            e.section or '',
            e.kind or '',
            ((e.display or ''):gsub('[\t\n]', ' ')),
            ((e.url or ''):gsub('[\t\n]', ' ')),
            e.bare or '',
            ((e.name or ''):gsub('[\t\n]', ' ')),
        }, '\t')
    end
    write_file(cache_dir() .. '/' .. INDEX_CACHE, table.concat(parts, '\n'))
end

local function read_index_cache()
    local text = read_file(cache_dir() .. '/' .. INDEX_CACHE)
    if not text then
        return nil
    end
    local entries, by_section = {}, {}
    for line in text:gmatch('[^\n]+') do
        local section, kind, display, url, bare, name =
            line:match('^([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t([^\t]*)\t(.*)$')
        if section and section ~= '' then
            local entry = {
                section = section,
                kind = kind or '',
                display = display or '',
                url = url or '',
                bare = bare ~= '' and bare or nil,
                name = name or '',
                type = '',
                cls = '',
            }
            entries[#entries + 1] = entry
            by_section[section] = by_section[section] or {}
            table.insert(by_section[section], entry)
        end
    end
    if #entries == 0 then
        return nil
    end
    return entries, by_section
end

-- Grouping is derived, never stored, so the cache stays the only copy of the
-- entry list and there is nothing to keep in step with it.
local function install(entries, by_section)
    state.entries = entries
    state.by_section = by_section or {}
    for _, section in ipairs(SECTIONS) do
        state.by_section[section.prefix] = state.by_section[section.prefix] or {}
    end
end

local function parse_inventory(text)
    local entries, by_section = {}, {}
    local class_name, seen_entry = {}, {}

    for line in text:gmatch('[^\n]+') do
        local name, kind, _prio, url, display = line:match('^(%S+)%s+(%S+)%s+(%S+)%s+(%S+)%s*(.*)$')
        if name and kind and url then
            -- The JavaScript shell docs are the only non-rst entries and are not
            -- something anyone opening the engine manual is looking for.
            local skip = kind:sub(1, 3) == 'js:'
                or display == 'Page not found'
                or display == 'Module code'
            local section = skip and nil or section_of(url)
            -- genindex, search, py-modindex, 404 and the front page are Sphinx's
            -- own machinery, not documentation, and none of them appears in the
            -- site's navigation. They are dropped here so a global search covers
            -- exactly the six sections the site offers.
            if section and SECTION_TITLE[section] then
                local is_named = display ~= '' and display ~= '-'
                if not is_named then
                    display = ''
                end
                -- Collected before the duplicate check: a page indexed as both
                -- std:doc and std:label must still register its class name even
                -- when only one of the two survives as a row.
                if is_named and name:match('^class_') then
                    class_name[name] = display
                end
                -- A page is indexed with and without an anchor, which would list
                -- it twice. Key on the path without the fragment plus the title,
                -- so two same-titled sections of one page still collapse but two
                -- pages that merely share a title ("Introduction") both survive.
                local key = is_named and (url:gsub('#.*$', '') .. '\0' .. display) or name
                if not seen_entry[key] then
                    seen_entry[key] = true
                    local entry = {
                        name = name,
                        type = kind,
                        url = url,
                        display = display,
                        section = section,
                    }
                    -- The member part is kept only as a search alias. It is not
                    -- shown: the row carries the inventory's own name, because
                    -- composing "Sprite2D.flip_h" here would be this panel
                    -- inventing a label the site does not use. Searching `flip_h`
                    -- still reaches the anchor, which is what the alias is for.
                    local _, _, member = split_member(name)
                    if member and not is_named then
                        entry.bare = member
                    end
                    table.insert(entries, entry)
                    by_section[section] = by_section[section] or {}
                    table.insert(by_section[section], entry)
                end
            end
        end
    end

    return entries, by_section, class_name
end

--------------------------------------------------------------------------------
-- URLs and page text
--------------------------------------------------------------------------------

local function page_url(entry)
    local path = entry.url:gsub('#.*$', '')
    while path:sub(1, 3) == '../' do
        path = path:sub(4)
    end
    path = path:gsub('index%.html$', '')
    if path == '' then
        path = 'index.html'
    end
    return opts.base .. path
end

-- The rendered page carries the whole navigation tree, which dwarfs the article.
local function warn(msg)
    vim.notify('godot_docs: ' .. msg, vim.log.levels.WARN)
end

-- open_path calls show_doc, which is defined further down.
local show_doc

-- href of every reference in a doc buffer, by line, so a cursor on one can be
-- followed. A page is plain text otherwise: there is nothing clickable to hover.
local doc_links = {}

-- A reference inside a page is written relative to that page's own directory and
-- not to the site root: a class page links to `class_node2d.html`, which sits
-- beside it under classes/. Joining against the page being read is what makes
-- following a reference work at all; joining against the root asked the site for
-- a file that does not exist.
local function resolve_href(base, href)
    if href:match('^%a[%w+.%-]*://') or href:match('^mailto:') then
        return href, 'external'
    end
    if href:sub(1, 1) == '#' then
        return base, 'anchor'
    end
    local dir = base:gsub('#.*$', ''):gsub('[^/]*$', '')
    local path = href:sub(1, 1) == '/' and href:gsub('^/', '') or (dir .. href)
    local parts = {}
    for segment in path:gmatch('[^/]+') do
        if segment == '..' then
            table.remove(parts)
        elseif segment ~= '.' then
            parts[#parts + 1] = segment
        end
    end
    return table.concat(parts, '/'), 'page'
end

-- Off-site references go to the desktop browser; on-site ones are loaded here, so
-- following a link inside the manual never leaves Neovim. Only http(s) is handed
-- to the browser: a page is allowed to contain any href at all, and handing an
-- arbitrary scheme to xdg-open would be its decision to make, not this one's.
local function open_url(url)
    if url:match('^https?://') then
        vim.fn.jobstart({ 'xdg-open', url }, { detach = true })
    else
        warn('refusing to open ' .. url)
    end
end

-- Ctrl-] and Ctrl-T over the underlined references, as :h CTRL-] works in the
-- manual. Underlined means the page's references: those are the only spans drawn
-- with an underline, and they are what the reader moves between.
--
-- Positions are recorded as they are left, so Ctrl-T walks back through them. A
-- page followed from a reference is recorded too, which is what makes returning
-- from a link work rather than just moving about one page.
local underlined = {}   -- buffer -> references, in reading order
local page_base = {}    -- buffer -> the inventory url of the page shown
local page_anchors = {} -- buffer -> id -> row, for references within one page
local jump_stack = {}

local function push_jump(win)
    local row, col = unpack(vim.api.nvim_win_get_cursor(win))
    local buf = vim.api.nvim_win_get_buf(win)
    jump_stack[#jump_stack + 1] = {
        buf = buf,
        name = vim.api.nvim_buf_get_name(buf),
        row = row,
        col = col,
    }
    if #jump_stack > 200 then
        table.remove(jump_stack, 1)
    end
end

-- Following a reference, whichever way it was asked for. A reference to the same
-- page is a jump to a line on it; one to another page is a fetch; anything off
-- the site goes to the browser. Returns false when there is nowhere to go, so the
-- caller can say so rather than appearing to do nothing.
local function follow(win, buf, href)
    local target, kind = resolve_href(page_base[buf] or '', href)
    if kind == 'anchor' then
        local id = href:sub(2)
        local row = (page_anchors[buf] or {})[id]
        if not row then
            return false
        end
        push_jump(win)
        pcall(vim.api.nvim_win_set_cursor, win, { row + 1, 0 })
        vim.cmd('normal! zz')
        return true
    end
    push_jump(win)
    if kind == 'external' or target:sub(1, #opts.base) == opts.base then
        open_url(target)
    else
        show_doc({ url = target }, nil, win)
    end
    return true
end

-- The reference the cursor is sitting in, if any.
local function spot_at(spots, row, col)
    for _, spot in ipairs(spots) do
        if spot.row == row and col >= spot.first and col < spot.last then
            return spot
        end
    end
    return nil
end


local function jump_forward(win)
    local buf = vim.api.nvim_win_get_buf(win)
    local spots = underlined[buf]
    if not spots or #spots == 0 then
        vim.notify('godot_docs: this page has no references', vim.log.levels.INFO)
        return
    end
    local row, col = unpack(vim.api.nvim_win_get_cursor(win))

    -- On an underlined reference, go to it -- the same thing <CR> does, and what
    -- the manual means by jumping to a tag. Standing on "Node2D" and pressing
    -- <C-]> opens Node2D, rather than sliding along to the next underline.
    local here = spot_at(spots, row - 1, col)
    if here and here.href then
        if not follow(win, buf, here.href) then
            vim.notify('godot_docs: nothing to jump to from here', vim.log.levels.INFO)
        end
        return
    end

    local target
    for _, spot in ipairs(spots) do
        -- Strictly ahead of the cursor: a reference the cursor is sitting on, or
        -- has just been jumped to, must not count as the next one. With `>=` a
        -- jump lands on a reference and every later jump lands on the same one.
        if spot.row > row - 1 or (spot.row == row - 1 and spot.first > col) then
            target = spot
            break
        end
    end
    target = target or spots[1]
    push_jump(win)
    vim.api.nvim_win_set_cursor(win, { target.row + 1, target.first })
    vim.cmd('normal! zz')
end

local function jump_back()
    local top = jump_stack[#jump_stack]
    if not top then
        return
    end
    table.remove(jump_stack)

    local function place()
        pcall(vim.api.nvim_win_set_cursor, 0, { top.row, top.col })
        vim.cmd('normal! zz')
    end

    -- Still on screen: go back to the window showing it.
    for _, w in ipairs(vim.api.nvim_list_wins()) do
        if vim.api.nvim_win_get_buf(w) == top.buf then
            vim.api.nvim_set_current_win(w)
            place()
            return
        end
    end
    -- Closed since, so its buffer is gone. Fetch the page again and return to the
    -- line that was left.
    local rel = top.name:gsub('^godot://', '')
    if rel == '' or rel == top.name then
        return
    end
    -- Already stored resolved, so it is passed straight through.
    show_doc({ url = rel }, function(newbuf)
        if newbuf then
            pcall(vim.api.nvim_win_set_cursor, 0, { top.row, top.col })
            vim.cmd('normal! zz')
        end
    end, vim.api.nvim_get_current_win())
end

show_doc = function(entry, done, win_hint)
    if state.busy then
        return
    end
    local dir = ensure_dir(cache_dir() .. '/pages')
    -- Keyed on the path alone: every method and property anchor on a page shares
    -- one document, and including the fragment would re-download it per anchor.
    local file = entry.url:gsub('#.*$', ''):gsub('[^%w%-_%.]', '_')
    local html_path = dir .. '/' .. file .. '.html'

    local NS_DOC = vim.api.nvim_create_namespace('godot_docs_doc')

    local function present(lines, marks, links, anchors)
        -- Where the page goes.
        --
        -- win_hint is the window the request was made from, captured at the moment
        -- <CR> was pressed. It cannot be the current window at this point: an
        -- uncached page is downloaded first, and by the time this runs the user
        -- has moved on, so "whatever is focused now" could be a floating window or
        -- an unrelated file.
        --
        -- A request made from a page navigates in that page's own window, so
        -- following a reference replaces it instead of stacking a split per click.
        -- A request made from the panel opens a new split. A fresh buffer either
        -- way, so no mark, reference or undo entry from the previous page survives.
        local win = nil
        if win_hint and vim.api.nvim_win_is_valid(win_hint) then
            local cfg = vim.api.nvim_win_get_config(win_hint)
            -- Never the panel: the page would be drawn inside the float.
            if cfg.relative == ''
                and vim.api.nvim_buf_get_name(vim.api.nvim_win_get_buf(win_hint)):match('^godot://')
            then
                win = win_hint
            end
        end
        if not win then
            vim.cmd('botright new')
            win = vim.api.nvim_get_current_win()
        end
        local buf = vim.api.nvim_create_buf(false, true)
        -- Plain text, not markdown: the structure is already rendered, and letting
        -- a markdown parser reinterpret it would double up every heading marker.
        if not pcall(vim.api.nvim_win_set_buf, win, buf) then
            -- Should not happen with the checks above, but a window that cannot
            -- take the buffer must not leave the reader with nothing.
            vim.cmd('botright new')
            win = vim.api.nvim_get_current_win()
            vim.api.nvim_win_set_buf(win, buf)
        end
        vim.bo[buf].filetype = 'godotdoc'
        vim.api.nvim_buf_set_lines(buf, 0, -1, false, lines)
        -- The lines were written by this plugin, not by the user, so the buffer is
        -- not modified and must not be left claiming to be. `E89: No write since
        -- last change` keys on that flag rather than on 'readonly', so without
        -- this every plain :bdelete fails -- including the gbd mapping -- and the
        -- buffer can only be closed with :bdelete!.
        vim.bo[buf].modified = false
        -- Still protected: 'nomodifiable' stops a stray keystroke rewriting the
        -- page, and 'readonly' stops :w from putting it on disk. Neither gets in
        -- the way of closing the buffer.
        vim.bo[buf].readonly = true
        vim.bo[buf].modifiable = false
        -- 'wipe', not 'hide': with 'hide' a deleted documentation buffer stays in
        -- the buffer list, unloaded but still listed, so :ls, gbn and gbp keep
        -- offering it. There is nothing to preserve in a page that can be
        -- re-downloaded, so it should leave the list when it is closed.
        vim.bo[buf].bufhidden = 'wipe'
        pcall(vim.api.nvim_buf_set_name, buf, 'godot://' .. (entry.url:gsub('#.*$', '')))
        vim.wo[win].wrap = true
        vim.wo[win].number = false
        vim.wo[win].relativenumber = false
        vim.wo[win].signcolumn = 'no'
        vim.wo[win].spell = false
        vim.wo[win].cursorline = false

        -- Namespace -1 clears every mark in the buffer, not just this plugin's.
        -- The split's buffer can still carry marks from whatever showed it before,
        -- and a leftover range paints the new text at someone else's coordinates.
        vim.api.nvim_buf_clear_namespace(buf, -1, 0, -1)
        for _, m in ipairs(marks or {}) do
            -- Explicit start and end columns: with hl_eol or end_col = -1 this
            -- build places the extmark but paints nothing.
            pcall(vim.api.nvim_buf_set_extmark, buf, NS_DOC, m[1], m[2], {
                end_col = m[3],
                hl_group = m[4],
            })
        end

        local map = {}
        for _, l in ipairs(links or {}) do
            map[l[1] + 1] = map[l[1] + 1] or {}
            table.insert(map[l[1] + 1], { col = l[2], href = l[4] })
        end
        doc_links[buf] = map

        -- The underlined spans are the references, in reading order, for <C-]>.
        -- Built from the link list rather than from the highlight ranges so each
        -- spot carries the address it points at, and from links so the two can
        -- never disagree about what is underlined.
        local spots = {}
        for _, l in ipairs(links or {}) do
            local last = spots[#spots]
            -- A reference drawn in two pieces (part bold) is one target; joining
            -- them keeps <C-]> from stopping halfway across a single word.
            if last and last.row == l[1] and last.href == l[4]
                and l[2] <= last.last and l[2] > last.first
            then
                last.last = math.max(last.last, l[3])
            else
                spots[#spots + 1] = { row = l[1], first = l[2], last = l[3], href = l[4] }
            end
        end
        table.sort(spots, function(a, b)
            if a.row ~= b.row then
                return a.row < b.row
            end
            return a.first < b.first
        end)
        underlined[buf] = spots
        page_base[buf] = entry.url
        page_anchors[buf] = anchors or {}
        vim.api.nvim_create_autocmd('BufWipeout', {
            buffer = buf,
            once = true,
            callback = function()
                underlined[buf] = nil
                page_base[buf] = nil
                page_anchors[buf] = nil
            end,
        })

        -- <CR> follows the reference under the cursor, the way the browser would.
        -- Off-site references open in the browser, on-site ones load in this
        -- split, so following a link inside the manual stays in Neovim.
        vim.keymap.set('n', '<CR>', function()
            local row, col = unpack(vim.api.nvim_win_get_cursor(win))
            local best
            for _, l in ipairs(map[row] or {}) do
                if col >= l.col and (not best or l.col > best.col) then
                    best = l
                end
            end
            if not best then
                vim.notify('godot_docs: no reference under the cursor', vim.log.levels.INFO)
                return
            end
            if not follow(win, buf, best.href) then
                vim.notify('godot_docs: nothing to open from here', vim.log.levels.INFO)
            end
        end, { buffer = buf, nowait = true, silent = true, desc = 'Follow the reference' })

        vim.keymap.set('n', '<C-]>', function()
            jump_forward(win)
        end, { buffer = buf, nowait = true, silent = true, desc = 'Next reference' })

        vim.keymap.set('n', '<C-T>', jump_back,
            { buffer = buf, nowait = true, silent = true, desc = 'Previous position' })

        for _, m in ipairs({ { '<Esc>', 'Close documentation' }, { 'q', 'Close documentation' } }) do
            vim.keymap.set('n', m[1], function()
                vim.api.nvim_win_close(win, true)
            end, { buffer = buf, nowait = true, silent = true, desc = m[2] })
        end
        -- Top of the page. A page shown in place of another keeps the cursor
        -- where the old one was left, so opening a page from halfway down looked
        -- exactly like nothing happening: same window, same scroll position, and
        -- different text somewhere above.
        pcall(vim.api.nvim_win_set_cursor, win, { 1, 0 })

        if done then
            done(buf)
        end
    end

    local function convert()
        local html = read_file(html_path)
        if not html or html == '' then
            vim.notify('godot_docs: nothing cached for ' .. entry.url, vim.log.levels.WARN)
            if done then done() end
            return
        end
        local lines, marks, links, anchors = require('godot_docs.html').render(
            require('godot_docs.html').extract_article(html))
        if not lines or #lines == 0 then
            vim.notify('godot_docs: page had no readable text: ' .. entry.url, vim.log.levels.WARN)
            if done then done() end
            return
        end
        present(lines, marks, links, anchors)
    end

    if uv.fs_stat(html_path) and file_age_days(html_path) < opts.max_age_days then
        convert()
        return
    end

    state.busy = true
    render()
    run({ 'curl', '-fsSL', '--max-time', '45', page_url(entry), '-o', html_path }, function(res)
        state.busy = false
        if res.code ~= 0 then
            vim.notify('godot_docs: could not download ' .. page_url(entry), vim.log.levels.ERROR)
            render()
            if done then
                done()
            end
            return
        end
        convert()
    end)
end

--------------------------------------------------------------------------------
-- Rows
--------------------------------------------------------------------------------

local function row_label(entry)
    if entry.display ~= '' then
        return entry.display
    end
    return entry.name
end

-- Everything on screen right now: the root blocks, one section's pages, or the
-- rows a query matched.
-- Several pages share a title: "Animation" is a class, a tutorial section and
-- part of two unrelated pages. A bare title is then ambiguous, so the directory
-- is appended, but only to the labels that are actually ambiguous on screen.
local function disambiguate(rows)
    local seen = {}
    for _, row in ipairs(rows) do
        local label = row.is_section and row.label or row_label(row)
        seen[label] = (seen[label] or 0) + 1
    end
    for _, row in ipairs(rows) do
        if not row.is_section and seen[row_label(row)] > 1 then
            row.hint = row.url:gsub('#.*$', ''):gsub('%.html$', ''):gsub('/index$', '')
        end
    end
end

local function compute_rows()
    if state.query ~= '' then
        local needle = state.query:lower()
        local hits = {}
        -- A section narrows the search to itself, which is what makes stepping
        -- into a block useful rather than just cosmetic.
        local pool = state.entries
        if #state.scope > 0 then
            pool = {}
            for _, section in ipairs(state.scope) do
                vim.list_extend(pool, state.by_section[section] or {})
            end
        end
        for _, entry in ipairs(pool) do
            local hay_label = row_label(entry):lower()
            local hay_section = entry.section:lower()
            local score
            if hay_label:sub(1, #needle) == needle then
                score = 1
            elseif entry.bare and entry.bare:lower() == needle then
                score = 2
            elseif hay_label:find(needle, 1, true) then
                score = 3
            elseif entry.bare and entry.bare:lower():find(needle, 1, true) then
                score = 4
            elseif hay_section:find(needle, 1, true) then
                score = 5
            elseif entry.name:lower():find(needle, 1, true) then
                score = 6
            end
            if score then
                entry.score = score
                table.insert(hits, entry)
            end
        end
        table.sort(hits, function(a, b)
            if a.score ~= b.score then
                return a.score < b.score
            end
            return row_label(a) < row_label(b)
        end)
        disambiguate(hits)
        return hits
    end

    if #state.scope == 0 then
        local rows = {}
        for _, section in ipairs(SECTIONS) do
            table.insert(rows, {
                is_section = true,
                section = section.prefix,
                label = section.title,
                count = #(state.by_section[section.prefix] or {}),
            })
        end
        return rows
    end

    local pool = {}
    for _, section in ipairs(state.scope) do
        vim.list_extend(pool, state.by_section[section] or {})
    end
    disambiguate(pool)
    return pool
end

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

local function scope_text()
    if #state.scope == 0 then
        return 'all sections'
    end
    local names = {}
    for _, prefix in ipairs(state.scope) do
        names[#names + 1] = SECTION_TITLE[prefix] or prefix
    end
    return table.concat(names, ' / ')
end

-- Byte offsets of every case-insensitive occurrence of the query, so the panel
-- can light up what matched inside a title.
local function query_hits(text)
    local hits = {}
    if state.query == '' then
        return hits
    end
    local from = 1
    while true do
        local at = text:lower():find(state.query:lower(), from, true)
        if not at then
            return hits
        end
        hits[#hits + 1] = at
        from = at + 1
    end
end

-- The '> ' marker is real text so the caret lands after it the way it does in
-- :command-line. Only the query is buffer text; the scope and count live in the
-- footer, because as inline virtual text they blocked the caret from reaching
-- column 2 and the first character typed landed before the marker's space.
local function set_prompt()
    if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
        return
    end
    local text = '> ' .. state.query .. ' '
    vim.api.nvim_buf_clear_namespace(state.buf, NS_ID, 0, 1)
    vim.api.nvim_buf_set_lines(state.buf, 0, 1, false, { text })
    vim.api.nvim_buf_set_extmark(state.buf, NS_ID, 0, 0, {
        end_col = #text,
        hl_group = 'GodotDocsPrompt',
    })
end

render = function()
    if not (state.buf and vim.api.nvim_buf_is_valid(state.buf)) then
        return
    end
    state.rows = compute_rows()
    local count = #state.rows
    if count == 0 then
        state.sel, state.offset = 1, 0
    else
        state.sel = math.min(state.sel, count)
        local visible = math.min(opts.max_rows, count)
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

    -- Line 1 is the query and is never rewritten, so the caret stays put while the
    -- rows below change on every keystroke.
    local lines, marks = {}, {}
    local function mark(row, col_start, col_end, group)
        marks[#marks + 1] = { row, col_start, col_end, group }
    end

    local rule = string.rep('\u{2500}', math.max(inner - 2, 1))
    lines[#lines + 1] = ' ' .. rule
    mark(1, 1, 1 + #rule, 'GodotDocsRule')

    local first = state.offset + 1
    local last = math.min(count, state.offset + opts.max_rows)
    for i = first, last do
        local entry = state.rows[i]
        local row = #lines + 1

        local prefix = string.format('%d. ', i)
        local label = entry.is_section and entry.label or row_label(entry)
        local room = math.max(inner - 1 - #prefix - 24, 12)
        local name_text = clip(label, room)

        -- The scope and the directory are only shown where the title leaves room;
        -- the title is what was searched for, so it wins the columns.
        local tail = ''
        if entry.is_section then
            tail = '  (' .. entry.count .. ')'
        elseif entry.hint and entry.hint ~= '' and #name_text < room - 4 then
            tail = '  (' .. entry.hint .. ')'
        end

        local line = ' ' .. prefix .. name_text .. tail
        lines[#lines + 1] = line

        local base = 1
        mark(row, base, base + #prefix, 'GodotDocsMeta')
        mark(row, base + #prefix, base + #prefix + #name_text, 'GodotDocsName')
        if #tail > 0 then
            mark(row, base + #prefix + #name_text, #line, 'GodotDocsSection')
        end

        for _, at in ipairs(query_hits(name_text)) do
            mark(row, base + #prefix + at - 1, base + #prefix + at, 'GodotDocsMatch')
        end

        if i == state.sel then
            mark(row, 0, #line, 'GodotDocsSel')
        end
    end

    if count == 0 then
        local note = state.query ~= '' and 'nothing matches that name' or 'nothing here'
        lines[#lines + 1] = '   ' .. note
        mark(#lines, 3, 3 + #note, 'GodotDocsNone')
    elseif count > opts.max_rows then
        local note = string.format('%d-%d of %d', first, last, count)
        lines[#lines + 1] = '   ' .. note
        mark(#lines, 3, 3 + #note, 'GodotDocsMeta')
    end

    local status = ''
    if state.loading then
        status = 'downloading index... '
    elseif state.busy then
        status = 'downloading page... '
    end
    local meta = string.format('%d/%d  [%s]  %s<CR> open  <Tab> next  <BS> back  <C-u> clear  <C-r> refetch  <Esc> quit',
        math.min(state.sel, count), count, scope_text(), status)
    lines[#lines + 1] = ' ' .. meta
    mark(#lines, 1, 1 + #meta, 'GodotDocsMeta')

    vim.api.nvim_buf_clear_namespace(state.buf, NS_ID, 0, -1)
    -- Row 0 is the query line, which render never touches.
    vim.api.nvim_buf_set_lines(state.buf, 1, -1, false, lines)

    -- Explicit start/end columns: with hl_eol or end_col = -1 this build places
    -- the extmark but paints nothing.
    for _, m in ipairs(marks) do
        vim.api.nvim_buf_set_extmark(state.buf, NS_ID, m[1], m[2], {
            end_col = m[3],
            hl_group = m[4],
        })
    end

    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_set_height(state.win,
            math.min(#lines + 1, math.max(vim.o.lines - 4, 8)))
        -- Stay on the prompt line. Moving onto a result row pulls the caret off
        -- the query, so the next character lands in the list and is overwritten.
        pcall(vim.api.nvim_win_set_cursor, state.win, { 1, 2 + #state.query })
    end
end

--------------------------------------------------------------------------------
-- Actions
--------------------------------------------------------------------------------

local function move(delta)
    if #state.rows == 0 then
        return
    end
    state.sel = state.sel + delta
    if state.sel < 1 then
        state.sel = 1
    elseif state.sel > #state.rows then
        state.sel = #state.rows
    end
    render()
end

local function type_char(ch)
    state.query = state.query .. ch
    state.sel = 1
    state.offset = 0
    set_prompt()
    render()
end

local function erase()
    if state.query ~= '' then
        state.query = state.query:sub(1, -2)
        state.sel = 1
        state.offset = 0
        set_prompt()
        render()
        return
    end
    -- An empty query is "back": out of a section, or to the root block list.
    if #state.scope > 0 then
        table.remove(state.scope)
        state.sel = 1
        state.offset = 0
        render()
    end
end

local function clear_query()
    state.query = ''
    state.sel = 1
    state.offset = 0
    set_prompt()
    render()
end

local quit

local function activate()
    local row = state.rows[state.sel]
    if not row then
        -- Silently doing nothing here reads as a broken panel, which is what a
        -- <CR> on an empty result list looks like from the outside.
        vim.notify('godot_docs: nothing to open -- the list is empty',
            vim.log.levels.INFO)
        return
    end
    if row.is_section then
        table.insert(state.scope, row.section)
        state.sel = 1
        state.offset = 0
        render()
        return
    end
    -- Opening a page closes the panel, the way running a keymap closes the
    -- keysearch one: the page is the destination, and a panel left floating over
    -- the document it just opened is in the way. Stepping into a section is
    -- navigation rather than a destination, so that keeps the panel open.
    --
    -- Closed before the page is shown, not after: show_doc opens its split on the
    -- current window, and the float would be the one it split.
    quit()
    -- Captured here, while it is still known: the window the panel was opened
    -- over is the one a reference should navigate, or the one a page should take
    -- a split from.
    show_doc(row, nil, vim.api.nvim_get_current_win())
end

quit = function()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_close(state.win, true)
    end
    state.buf, state.win = nil, nil
end

local function refetch()
    local dir = cache_dir()
    vim.fn.delete(dir .. '/objects.inv')
    vim.fn.delete(dir .. '/objects.txt')
    vim.fn.delete(dir .. '/' .. INDEX_CACHE)
    -- The index is memoised for the session, so the drop has to include it or the
    -- next open would keep serving the old one from memory.
    state.entries = {}
    state.by_section = {}
    vim.notify('godot_docs: inventory dropped, refetching on next open', vim.log.levels.INFO)
    quit()
end

--------------------------------------------------------------------------------
-- Panel
--------------------------------------------------------------------------------

local function load_index(done)
    -- Once per session. The index only changes when it is refetched, and parsing
    -- it is the expensive part, so a second open in the same session must not
    -- repeat it.
    if #state.entries > 0 then
        done()
        return
    end

    local entries, by_section = read_index_cache()
    if entries then
        install(entries, by_section)
        done()
        return
    end

    local function parse_from_disk()
        local text = read_file(cache_dir() .. '/objects.txt')
        if not text then
            return false
        end
        local parsed, parsed_sections, class_name = parse_inventory(text)
        if #parsed == 0 then
            return false
        end
        install(parsed, parsed_sections)
        state.class_name = class_name
        write_index_cache(parsed)
        return true
    end

    if parse_from_disk() then
        done()
        return
    end

    state.loading = true
    render()
    download_inventory(function(err)
        state.loading = false
        if err then
            vim.notify('godot_docs: ' .. err, vim.log.levels.ERROR)
            done()
            return
        end
        parse_from_disk()
        done()
    end)
end

function M.toggle()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        quit()
        return
    end

    define_highlights()
    state.query = ''
    state.scope = {}
    state.sel = 1
    state.offset = 0

    state.buf = vim.api.nvim_create_buf(false, true)
    vim.bo[state.buf].bufhidden = 'wipe'

    local width = math.min(math.max(vim.o.columns - 6, 44), 96)
    local height = math.min(opts.max_rows + 8, math.max(vim.o.lines - 6, 12))
    state.win = vim.api.nvim_open_win(state.buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = 1,
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = 'rounded',
        title = ' Godot documentation ',
        title_pos = 'center',
    })
    vim.wo[state.win].cursorline = false
    vim.wo[state.win].number = false
    vim.wo[state.win].relativenumber = false
    vim.wo[state.win].signcolumn = 'no'
    vim.wo[state.win].wrap = false
    vim.wo[state.win].spell = false

    local function map(lhs, fn, desc)
        vim.keymap.set('n', lhs, fn,
            { buffer = state.buf, nowait = true, silent = true, desc = desc })
    end

    map('<CR>', activate, 'Open the selected entry')
    map('<Esc>', quit, 'Close')
    map('<C-c>', quit, 'Close')
    map('<Tab>', function() move(1) end, 'Next row')
    map('<S-Tab>', function() move(-1) end, 'Previous row')
    map('<C-n>', function() move(1) end, 'Next row')
    map('<C-p>', function() move(-1) end, 'Previous row')
    map('<Down>', function() move(1) end, 'Next row')
    map('<Up>', function() move(-1) end, 'Previous row')
    map('<BS>', erase, 'Backspace, or leave the current section')
    map('<Left>', erase, 'Leave the current section')
    map('<C-u>', clear_query, 'Clear the search')
    map('<C-r>', refetch, 'Refetch the index')
    map('<C-g>', function()
        state.scope = {}
        state.query = state.query == '' and '' or state.query
        state.sel = 1
        state.offset = 0
        render()
        vim.notify('godot_docs: searching every entry', vim.log.levels.INFO)
    end, 'Search everything')

    -- Same reasoning as the keysearch panel: printable characters are bound in
    -- normal mode so a stray keystroke can never land in the buffer behind.
    for byte = 32, 126 do
        if byte ~= 27 and byte ~= 13 then
            local ch = string.char(byte)
            vim.keymap.set('n', ch, function() type_char(ch) end, {
                buffer = state.buf, nowait = true, silent = true, desc = 'Type to search',
            })
        end
    end

    set_prompt()
    load_index(function()
        if state.win and vim.api.nvim_win_is_valid(state.win) then
            render()
        end
    end)
end

function M.setup(user)
    opts = vim.tbl_deep_extend('force', vim.deepcopy(opts), user or {})
    -- The stylesheet is fetched once, in the background, and every group the
    -- renderer refers to is defined from it before a page is ever drawn.
    require('godot_docs.palette').load()
    vim.keymap.set('n', '<leader>gd', M.toggle, { desc = 'Godot: browse documentation' })
    vim.api.nvim_create_user_command('GodotDocs', M.toggle, { desc = 'Godot: browse documentation' })
end

return M
