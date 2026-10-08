-- The documentation's own colours.
--
-- Nothing here is picked by hand. docs.godotengine.org defines its palette as
-- CSS custom properties in _static/css/custom.css, in two blocks: the light one
-- the browser uses on a white page, and a dark one for the dark theme. The dark
-- block is the one applied, because this buffer is read inside a dark editor;
-- the light values would sit unreadably dark on that background.
--
-- Read at runtime rather than hardcoded so a change to the stylesheet is picked
-- up on the next refresh instead of having to be tracked here.

local M = {}

local uv = vim.uv or vim.loop

-- Properties actually used. Listing them keeps the parse from carrying the whole
-- stylesheet, base64 blobs included.
local WANTED = {
    ['body-color'] = true,
    ['content-background-color'] = true,
    ['link-color'] = true,
    ['link-color-hover'] = true,
    ['code-background-color'] = true,
    ['code-border-color'] = true,
    ['code-literal-color'] = true,
    ['highlight-default-color'] = true,
    ['highlight-keyword-color'] = true,
    ['highlight-literal-color'] = true,
    ['highlight-control-flow-keyword-color'] = true,
    ['highlight-number-color'] = true,
    ['highlight-function-color'] = true,
    ['highlight-function-declaration-color'] = true,
    ['highlight-global-function-color'] = true,
    ['highlight-string-color'] = true,
    ['highlight-comment-color'] = true,
    ['highlight-operator-color'] = true,
    ['highlight-base-type-color'] = true,
    ['highlight-decorator-color'] = true,
}

local light, dark = {}, {}
local loaded = false

local function cache_path()
    return vim.fn.stdpath('cache') .. '/godot-docs/custom.css'
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

-- The first definition of a property is the light block, the second the dark one.
local function parse_css(text)
    light, dark = {}, {}
    local seen = {}
    for name, value in text:gmatch('%-%-([%w%-]+)%s*:%s*([^;]+);') do
        if WANTED[name] then
            if not seen[name] then
                light[name] = value
                seen[name] = true
            else
                dark[name] = value
            end
        end
    end
end

-- `var(--other)` is used for a couple of properties; follow it once.
local function deref(vars, name)
    local value = vars[name]
    if not value then
        return nil
    end
    local ref = value:match('^%s*var%(%s*%-%-([%w%-]+)%s*%)')
    if ref and ref ~= name then
        return deref(vars, ref) or value
    end
    return value
end

local function to_hex(value, bg)
    if not value then
        return nil
    end
    value = value:gsub('^%s+', ''):gsub('%s+$', '')
    local hex = value:match('^#(%x+)$')
    if hex then
        if #hex == 3 then
            return ('#%s%s%s%s%s%s'):format(hex:sub(1, 1), hex:sub(1, 1), hex:sub(2, 2),
                hex:sub(2, 2), hex:sub(3, 3), hex:sub(3, 3))
        end
        if #hex >= 6 then
            return '#' .. hex:sub(1, 6)
        end
        return nil
    end
    local r, g, b, a = value:match('^rgba?%(([%d%.]+)%s*,%s*([%d%.]+)%s*,%s*([%d%.]+)%s*,?%s*([%d%.]*)%)')
    if not r then
        return nil
    end
    r, g, b = tonumber(r), tonumber(g), tonumber(b)
    a = a ~= '' and tonumber(a) or 1
    if a >= 1 then
        return ('#%02x%02x%02x'):format(r, g, b)
    end
    -- Neovim highlight attributes have no alpha channel, so a translucent colour
    -- has to be composited against the page background to look the same.
    local br, bg_, bb = bg:match('#(%x%x)(%x%x)(%x%x)')
    br, bg_, bb = tonumber(br, 16), tonumber(bg_, 16), tonumber(bb, 16)
    local function mix(c, under)
        return math.floor(c * a + under * (1 - a) + 0.5)
    end
    return ('#%02x%02x%02x'):format(mix(r, br), mix(g, bg_), mix(b, bb))
end

-- Background the translucent colours are composited against, and which block of
-- the stylesheet to prefer.
local function page_background()
    if vim.o.background == 'light' then
        return to_hex(deref(light, 'content-background-color') or '#fcfcfc', '#ffffff')
    end
    return to_hex(deref(dark, 'content-background-color') or '#2e3236', '#000000')
end

local function define()
    local bg = page_background()

    local function c(name)
        -- Dark first, light as the fallback: a property added to only one of the
        -- two blocks still resolves.
        return to_hex(deref(dark, name) or deref(light, name), bg)
    end

    local text = c('body-color') or '#ebdbb2'
    local link = c('link-color') or '#8cf'
    local literal = c('code-literal-color') or '#d68f8f'
    local code = c('highlight-default-color') or text

    -- Heading colours are the site's own text colour: the stylesheet sets no
    -- per-level colour, relying on size instead. Size is unavailable in a
    -- character grid, so the hierarchy is carried by weight and italic alone
    -- rather than by colours invented here.
    local groups = {
        GodotDocText = { fg = text },
        GodotDocBold = { fg = text, bold = true },
        GodotDocEm = { fg = text, italic = true },
        GodotDocBoldEm = { fg = text, bold = true, italic = true },
        GodotDocH1 = { fg = text, bold = true, underline = true },
        GodotDocH2 = { fg = text, bold = true },
        GodotDocH3 = { fg = text, bold = true, italic = true },
        GodotDocH4 = { fg = text, italic = true },
        GodotDocH5 = { fg = text, italic = true },
        GodotDocH6 = { fg = text, italic = true },
        GodotDocLink = { fg = link, underline = true },
        GodotDocLinkBold = { fg = link, underline = true, bold = true },
        GodotDocLiteral = { fg = literal },
        GodotDocLiteralBold = { fg = literal, bold = true },
        GodotDocRule = { fg = c('code-border-color') or '#888' },
        GodotDocBullet = { fg = c('code-border-color') or '#888' },

        -- Code tokens, straight from the stylesheet's highlight block.
        GodotDocCode = { fg = code },
        GodotDocCodeBg = { bg = c('code-background-color') },
        GodotDocKeyword = { fg = c('highlight-keyword-color') },
        GodotDocControl = { fg = c('highlight-control-flow-keyword-color') },
        GodotDocLiteral2 = { fg = c('highlight-literal-color') },
        GodotDocNumber = { fg = c('highlight-number-color') },
        GodotDocFunction = { fg = c('highlight-function-color') },
        GodotDocFuncDecl = { fg = c('highlight-function-declaration-color') },
        GodotDocGlobalFunc = { fg = c('highlight-global-function-color') },
        GodotDocString = { fg = c('highlight-string-color') },
        GodotDocComment = { fg = c('highlight-comment-color'), italic = true },
        GodotDocOperator = { fg = c('highlight-operator-color') },
        GodotDocBaseType = { fg = c('highlight-base-type-color') },
        GodotDocDecorator = { fg = c('highlight-decorator-color') },
        GodotDocError = { fg = c('highlight-keyword-color'), bold = true },
    }
    for name, def in pairs(groups) do
        vim.api.nvim_set_hl(0, name, def)
    end
end

local function ensure_css(done)
    if loaded then
        done()
        return
    end
    local path = cache_path()
    local text = read_file(path)
    if text then
        parse_css(text)
        loaded = true
        define()
        done()
        return
    end
    vim.fn.mkdir(vim.fn.stdpath('cache') .. '/godot-docs', 'p')
    vim.system({
        'curl', '-fsSL', '--max-time', '30',
        'https://docs.godotengine.org/en/latest/_static/css/custom.css',
        '-o', path,
    }, { text = true }, function()
        -- vim.system's callback is a fast event: reading an option there is an
        -- error, and define() reads 'background' to pick the colour block.
        vim.schedule(function()
            local body = read_file(path)
            if body then
                parse_css(body)
                loaded = true
            end
            -- Either way the groups are defined: without the stylesheet the page
            -- still renders, in whatever the fallbacks resolve to.
            define()
            if done then
                done()
            end
        end)
    end)
end

function M.load(done)
    ensure_css(done or function() end)
end

function M.refresh(done)
    vim.fn.delete(cache_path())
    loaded = false
    M.load(done)
end

return M
