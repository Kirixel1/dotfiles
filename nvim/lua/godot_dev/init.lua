-- A file tree of a Godot project, in a floating window, without switching to Godot.
--
-- The GDScript language server (see the LSP section of init.lua) handles the
-- language side; this is only about picking a file without leaving the editor.
--
-- Deliberately no Godot-side half: asking a *running* editor to open a script
-- needs EditorInterface.edit_script(), callable only from an EditorPlugin in
-- res://addons. Edit in Neovim, and use Godot for running and inspecting.

local M = {}

local uv = vim.uv or vim.loop

-- Nerd Font glyphs. Font Awesome codepoints are used deliberately: they exist in
-- essentially every patched font, unlike the seti/devicon glyphs mini.icons
-- mocks (which is where the earlier "Godot" icon came from, and looked wrong).
-- Glyphs restricted to what Iosevka Fixed actually contains, checked with
-- `fc-list ':charset=<hex>' family`. It has no icon font and kitty does not fall
-- back to the system Font Awesome 6 for the Private Use Area, so the usual
-- nf-fa-* codepoints render as nothing here. These are all U+25xx/26xx shapes
-- that are present. Built with nr2char rather than \u{} escapes, which LuaJIT
-- does not support and silently turns into an empty string.
local function nf(codepoint)
    return vim.fn.nr2char(codepoint)
end

local ICON = {
    dir_open = nf(0x25be),   --
    dir_closed = nf(0x25b8), --
    file = nf(0x25ab),       --
    gd = nf(0x25c6),         --
    scene = nf(0x25cf),      --
    resource = nf(0x25aa),   --
    shader = nf(0x26a1),     --
    config = nf(0x2699),     --
}

-- Per-extension icon, keyed on the lower-cased extension.
local ICON_BY_EXT = {
    gd = ICON.gd,
    gdshader = ICON.shader,
    tscn = ICON.scene,
    scn = ICON.scene,
    tres = ICON.resource,
    res = ICON.resource,
    godot = ICON.config,
    cfg = ICON.config,
    import = ICON.config,
}

-- Highlight groups with explicit colours and no `link`: nvim_set_hl ignores every
-- other attribute when a link is present, so a link to a group the colourscheme
-- does not define renders as plain default foreground. Values are gruvbox, which is
-- what gruber-darker is built from.
local HL = {
    dir = { fg = '#95a99f' },
    gd = { fg = '#96a6c8' },
    scene = { fg = '#8ec07c' },
    resource = { fg = '#9e95c7' },
    shader = { fg = '#8ec07c' },
    config = { fg = '#cc8c3c' },
    file = { fg = '#e4e4e4' },
    current = { fg = '#ffdd33', bold = true },
    hint = { fg = '#7c6f64' },
}

local hl_defined = false

local function define_highlights()
    if hl_defined then
        return
    end
    hl_defined = true
    for name, def in pairs(HL) do
        vim.api.nvim_set_hl(0, 'GodotDev' .. name:upper(), def)
    end
    -- style = 'minimal' suppresses the theme's own FloatBorder, so the border
    -- has to be given a colour explicitly or it draws almost invisibly.
    vim.api.nvim_set_hl(0, 'FloatBorder', { fg = '#7f8792' })
    vim.api.nvim_set_hl(0, 'FloatTitle', { fg = '#c8c8c8', bold = true })
end

local EXT_GROUP = {
    gd = 'gd',
    gdshader = 'shader',
    tscn = 'scene',
    scn = 'scene',
    tres = 'resource',
    res = 'resource',
    godot = 'config',
    cfg = 'config',
}

local HINT = {
    '  <CR> open    <Tab> fold    A fold all    q close',
    '  j/k move     h/l level    a all files   r refresh',
}

local defaults = {
    -- Extensions listed in the tree. Order is preserved.
    filetypes = { 'gd', 'tscn', 'tres', 'gdshader', 'godot', 'cfg' },
    -- Show every file instead of only the extensions above.
    show_all_files = false,
    -- Start with everything expanded. Set false to collapse all folders at once.
    expand_all = false,
    mappings = {
        open = '<CR>',
        toggle = '<Tab>',
        toggle_all = 'A',
        up = 'k',
        down = 'j',
        parent = 'h',
        child = 'l',
        close = '<Esc>',
        refresh = 'r',
        toggle_hidden = 'a',
    },
    float = {
        width = 0.65,
        height = 0.65,
        border = 'single',
        title = ' Godot project files ',
    },
    notify = true,
}

local opts = vim.deepcopy(defaults)

local state = {
    win = nil,
    buf = nil,
    ns = nil,
    tree = nil,
    root = nil,
    -- Absolute directory paths that are currently collapsed.
    collapsed = {},
    -- Rendered, in order: { text = string, depth = int, node = table }
    lines = {},
    -- Reused across renders so an open folder stays open after a refresh.
    expanded = {},
    hint_start = nil,
    all_files = false,
}

local function warn(msg)
    vim.notify('godot_dev: ' .. msg, vim.log.levels.WARN)
end

--------------------------------------------------------------------------------
-- Project discovery
--------------------------------------------------------------------------------

-- Nearest directory at or above `path` that contains a project.godot file.
-- Derived from the buffer rather than the cwd, so it works from any subdirectory.
function M.root(path)
    path = path or vim.api.nvim_buf_get_name(0)
    if path == '' then
        path = vim.fn.getcwd()
    end
    return vim.fs.root(vim.fn.fnamemodify(path, ':p'), 'project.godot')
end

local function require_root()
    local root = M.root()
    if not root then
        warn('no project.godot above ' .. vim.fn.getcwd() .. ' (not a Godot project?)')
        return nil
    end
    return root
end

--------------------------------------------------------------------------------
-- Building the tree
--------------------------------------------------------------------------------

local function scan(root, only_matching)
    local patterns
    if only_matching then
        patterns = {}
        for _, ext in ipairs(opts.filetypes) do
            table.insert(patterns, '**/*.' .. ext)
        end
    else
        patterns = { '**/*' }
    end

    local seen, files = {}, {}
    for _, pattern in ipairs(patterns) do
        for _, path in ipairs(vim.fn.glob(root .. '/' .. pattern, true, true)) do
            local stat = uv.fs_stat(path)
            -- Skip directories, and anything inside .godot (import cache, sockets).
            if stat and stat.type == 'file' and not seen[path] and not path:find('/%.godot/', 1, true) then
                seen[path] = true
                table.insert(files, path)
            end
        end
    end
    table.sort(files)
    return files
end

-- Folds an absolute-path list into a nested tree.
-- Directories first, then files, each group sorted case-insensitively.
local function build_tree(root, files)
    local tree = { name = '', path = root, type = 'dir', children = {} }

    for _, path in ipairs(files) do
        local rel = path:sub(#root + 2)
        local parts = {}
        for segment in rel:gmatch('[^/]+') do
            table.insert(parts, segment)
        end
        -- The last segment is the file name. A file at the project root has no
        -- '/' at all, so this split cannot be skipped or the name would be
        -- mistaken for a directory.
        local name = table.remove(parts)

        local node, prefix = tree, root
        for _, segment in ipairs(parts) do
            prefix = prefix .. '/' .. segment
            local child
            for _, candidate in ipairs(node.children) do
                if candidate.name == segment and candidate.type == 'dir' then
                    child = candidate
                    break
                end
            end
            if not child then
                child = { name = segment, path = prefix, type = 'dir', children = {} }
                table.insert(node.children, child)
            end
            node = child
        end
        table.insert(node.children, { name = name, path = path, type = 'file' })
    end

    -- Sort directories before files, then alphabetically.
    local function sort(node)
        table.sort(node.children, function(a, b)
            if a.type ~= b.type then
                return a.type == 'dir'
            end
            return a.name:lower() < b.name:lower()
        end)
        for _, child in ipairs(node.children) do
            if child.type == 'dir' then
                sort(child)
            end
        end
    end
    sort(tree)

    return tree
end

--------------------------------------------------------------------------------
-- Rendering
--------------------------------------------------------------------------------

local function count_files(node)
    if node.type == 'file' then
        return 1
    end
    local total = 0
    for _, child in ipairs(node.children) do
        total = total + count_files(child)
    end
    return total
end

-- Flattens the tree into visible lines, skipping the contents of collapsed
-- directories but keeping the directory row itself.
--
-- Each row carries the box-drawing pieces needed to draw it: `guides` is one
-- segment per ancestor level, and `connector` is this node's own elbow. A guide
-- is a vertical bar while that ancestor still has siblings below, which is what
-- makes the result read as a tree rather than a list.
-- Group for a row: directories get the folder colour, files get a colour per
-- extension, and the file already open in the buffer is highlighted as current.
local function row_group(child)
    if child.type == 'dir' then
        return 'DIR'
    end
    local ext = (child.name:match('%.([^.]+)$') or ''):lower()
    return EXT_GROUP[ext] or 'FILE'
end

local function flatten(node, guides, out, is_root)
    for index, child in ipairs(node.children) do
        local is_last = index == #node.children
        local is_open = child.type == 'file' or not state.collapsed[child.path]
        -- The root is an invisible anchor and is never drawn, so its children
        -- start flush left instead of carrying a guide segment.
        local guide = is_root and guides or guides .. (is_last and '  ' or '│ ')

        table.insert(out, {
            name = child.name,
            node = child,
            is_dir = child.type == 'dir',
            is_open = is_open,
            is_last = is_last,
            guides = guide,
            connector = is_last and '└── ' or '├── ',
            count = is_open and nil or count_files(child),
            group = row_group(child),
        })

        -- Only directories have children; files must not be recursed into.
        if child.type == 'dir' and is_open then
            flatten(child, guide, out, false)
        end
    end
end

local function icon_for(row)
    if row.is_dir then
        return row.is_open and ICON.dir_open or ICON.dir_closed
    end
    local ext = row.name:match('%.([^.]+)$')
    return ICON_BY_EXT[(ext or ''):lower()] or ICON.file
end

local function is_current_row(row)
    return row.node ~= nil
        and row.node.type == 'file'
        and row.node.path == state.current_file
end

-- Folders start collapsed on first open, so the tree is just the top level.
-- Only applied when the project changes; refresh keeps whatever the user opened.
local function collapse_dirs(node)
    for _, child in ipairs(node.children) do
        if child.type == 'dir' then
            state.collapsed[child.path] = true
            collapse_dirs(child)
        end
    end
end

local function render()
    local root = require_root()
    if not root then
        M.close()
        return
    end

    -- A refresh must not throw away which folders the user opened.
    local new_project = state.root ~= root
    if new_project then
        state.root = root
        state.collapsed = {}
    end
    state.tree = build_tree(root, scan(root, not state.all_files))
    if new_project and not opts.expand_all then
        collapse_dirs(state.tree)
    end

    state.lines = {}
    flatten(state.tree, '', state.lines, true)

    if #state.lines == 0 then
        state.lines = { { name = state.all_files and '(empty project)' or '(no matching files)' } }
    end

    define_highlights()
    state.current_file = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(0), ':p')

    local text = {}
    for i, row in ipairs(state.lines) do
        if row.node then
            local glyph = row.is_dir and (row.is_open and ICON.dir_open or ICON.dir_closed)
                or (ICON_BY_EXT[(row.name:match('%.([^.]+)$') or ''):lower()] or ICON.file)
            text[i] = row.guides .. row.connector .. glyph .. ' ' .. row.name
            if row.is_dir and not row.is_open then
                text[i] = text[i] .. ' (' .. tostring(row.count) .. ')'
            end
        else
            text[i] = row.name
        end
    end

    -- Hint block appended after the selectable rows so it can never be opened.
    local hint_start = #text + 1
    table.insert(text, '')
    for _, line in ipairs(HINT) do
        table.insert(text, line)
    end

    local buf = state.buf
    vim.bo[buf].modifiable = true
    vim.api.nvim_buf_clear_namespace(buf, state.ns, 0, -1)
    vim.api.nvim_buf_set_lines(buf, 0, -1, false, text)

    -- Explicit end_col is required: with hl_eol (or end_col = -1) this build
    -- places the extmark correctly but paints nothing at all.
    for i, row in ipairs(state.lines) do
        if row.node then
            local group = 'GodotDev' .. (is_current_row(row) and 'CURRENT' or row.group)
            vim.api.nvim_buf_set_extmark(buf, state.ns, i - 1, 0, {
                end_col = #text[i],
                hl_group = group,
            })
        end
    end
    for offset = hint_start, #text do
        vim.api.nvim_buf_set_extmark(buf, state.ns, offset - 1, 0, {
            end_col = #text[offset],
            hl_group = 'GodotDevHINT',
        })
    end

    vim.bo[buf].modifiable = false

    state.hint_start = hint_start
end

--------------------------------------------------------------------------------
-- Navigation
--------------------------------------------------------------------------------

local function current()
    return state.lines[vim.api.nvim_win_get_cursor(state.win)[1]]
end

function M.close()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        vim.api.nvim_win_close(state.win, true)
    end
    state.win, state.buf = nil, nil
end

local function move(delta)
    local n = math.max(#state.lines, 1)
    local row = vim.api.nvim_win_get_cursor(state.win)[1]
    vim.api.nvim_win_set_cursor(state.win, { math.min(math.max(row + delta, 1), n), 0 })
end

-- Jump to the nearest row at or above/below the cursor matching `pred`, so
-- movement skips over whole collapsed folders instead of landing inside them.
local function seek(pred, direction)
    local row = vim.api.nvim_win_get_cursor(state.win)[1]
    local function test(i)
        local candidate = state.lines[i]
        if candidate and candidate.node and pred(candidate) then
            vim.api.nvim_win_set_cursor(state.win, { i, 0 })
            return true
        end
        return false
    end
    -- Two loops rather than one with a signed step: a numeric for takes exactly
    -- start, limit, step.
    if direction > 0 then
        for i = row + 1, #state.lines do
            if test(i) then
                return true
            end
        end
    else
        for i = row - 1, 1, -1 do
            if test(i) then
                return true
            end
        end
    end
    return false
end

local function open_current()
    local row = current()
    M.close()
    if row and row.node and row.node.type == 'file' then
        vim.cmd.edit({ args = { vim.fn.fnameescape(row.node.path) } })
    end
end

local function toggle_current()
    local row = current()
    if not row or not row.is_dir then
        return
    end
    local keep = vim.api.nvim_win_get_cursor(state.win)[1]
    state.collapsed[row.node.path] = not state.collapsed[row.node.path]
    render()
    vim.api.nvim_win_set_cursor(state.win, { math.min(keep, #state.lines), 0 })
end

local function toggle_everything()
    local row = current()
    -- Decide from the folder under the cursor, so pressing it twice is a no-op
    -- flip rather than always meaning "open".
    local collapse = row and row.is_dir and row.is_open or false
    local function walk(node)
        if node.type == 'dir' then
            state.collapsed[node.path] = collapse and node.path ~= state.root or nil
            for _, child in ipairs(node.children) do
                walk(child)
            end
        end
    end
    walk(state.tree)
    render()
    vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
end

function M.toggle()
    if state.win and vim.api.nvim_win_is_valid(state.win) then
        M.close()
        return
    end
    if not require_root() then
        return
    end

    state.all_files = opts.show_all_files
    state.collapsed = opts.expand_all and {} or nil
    state.buf = vim.api.nvim_create_buf(false, true)
    state.ns = vim.api.nvim_create_namespace('godot_dev_tree')
    if not state.collapsed then
        state.collapsed = {}
    end
    render()

    local width = math.floor(vim.o.columns * opts.float.width)
    local height = math.floor(vim.o.lines * opts.float.height)
    state.win = vim.api.nvim_open_win(state.buf, true, {
        relative = 'editor',
        width = width,
        height = height,
        row = math.floor((vim.o.lines - height) / 2) - 1,
        col = math.floor((vim.o.columns - width) / 2),
        style = 'minimal',
        border = opts.float.border,
        title = opts.float.title,
        title_pos = 'center',
    })

    vim.wo[state.win].cursorline = true
    vim.wo[state.win].number = false
    vim.wo[state.win].relativenumber = false
    vim.wo[state.win].signcolumn = 'no'
    vim.wo[state.win].wrap = false
    -- Folding would fight the manual collapse above, and the text buffer opts
    -- you set globally already apply here.
    vim.wo[state.win].foldlevel = 99
    vim.wo[state.win].spell = false

    local map = opts.mappings
    local function bind(lhs, fn, desc)
        vim.keymap.set('n', lhs, fn, { buffer = state.buf, nowait = true, silent = true, desc = desc })
    end

    bind(map.open, open_current, 'open file')
    bind(map.toggle, toggle_current, 'expand/collapse folder')
    bind(map.toggle_all, toggle_everything, 'expand/collapse all folders')
    bind(map.up, function()
        move(-1)
    end, 'up')
    bind(map.down, function()
        move(1)
    end, 'down')
    bind(map.parent, function()
        seek(function(row)
            return row.guides == ''
        end, -1)
    end, 'go to top level')
    bind(map.child, function()
        seek(function(row)
            return row.is_dir and row.is_open
        end, 1)
    end, 'go to next folder')
    bind(map.refresh, function()
        render()
    end, 'refresh')
    bind(map.toggle_hidden, function()
        state.all_files = not state.all_files
        render()
        vim.api.nvim_win_set_cursor(state.win, { 1, 0 })
    end, 'show all files / only matching')
    bind(map.close, M.close, 'close')
    bind('q', M.close, 'close')
    vim.keymap.set('n', '<Esc>', M.close, { buffer = state.buf, nowait = true, silent = true })
end

--------------------------------------------------------------------------------
-- Entry point
--------------------------------------------------------------------------------

function M.setup(user)
    opts = vim.tbl_deep_extend('force', vim.deepcopy(defaults), user or {})
    vim.keymap.set('n', '<leader>gf', M.toggle, { desc = 'Godot: browse project files' })
end

return M
