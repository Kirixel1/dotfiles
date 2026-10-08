<p align="center">
  <h1 align="center">neovim config</h1>
</p>

You must have **neovim 0.12.0** or higher, because it uses native plugin loading via `vim.pack.add()`.
It's well documented and self-explanatory.

Some of the keymaps taked from [vim.rtorr.com](https://vim.rtorr.com/) and also constantly updating them when I explore new motions/commands with `:h/:help` or on the internet.

<p align="center">
  <h1 align="center">keymaps reference</h1>
</p>

## Leader Keymaps

<details>
    <summary>Click to see mappings</summary>

Leader key = `<Space>`

| Key          | Action                               | Description                        |
| -----        | --------                             | -------------                      |
| `<leader>pv` | `:Dired`                             | Opens dired file manager           |
| `<leader>sk` | `:ShowkeysToggle`                    | Toggle showkeys widget             |
| `<leader>O`  | `o<Esc>kO<Esc>j`                     | Add empty lines                    |
| `<leader>o`  | `init_selection`                     | Initialize incremental selection   |
| `<leader>i`  | `increment_node`                     | Incrementing initialized selection |
| `<leader>d`  | `decrement_node`                     | Decrementing initialized selection |
| `<leader>tc` | `tabclose`                           | Close tab                          |
| `<leader>to` | `tabnew`                             | Opens new tab                      |
| `<leader>ts` | `<cmd>lua MiniTrailspace.trim()<CR>` | Trim redundant spaces              |
| `<leader>mm` | `<cmd>MCstart<CR>`                   | Start multicursor mode             |
| `<leader>cm` | `<cmd>Compile<CR>`                   | Enters compilation mode            |
| `<leader>gf`  | `godot_dev.toggle`                    | Browse Godot project files     |
| `<leader>gd`  | `godot_docs.toggle`                   | Browse Godot documentation     |

</details>

## LSP

<details>
    <summary>Click to see mappings</summary>

| Key          | Action                                                                                      | Description                     |
| -----        | --------                                                                                    | -------------                   |
| `<leader>rn` | `vim.lsp.buf.rename`                                                                        | Rename                          |
| `K`          | `function() vim.lsp.buf.hover({ border = 'single', max_height = 25, max_width = 120 }) end` | Hover Documentation             |
| `<leader>d`  | `vim.diagnostic.open_float`                                                                 | Open Diagnostic Float           |
| `[d`         | `function() vim.diagnostic.jump({ count = -1, float = true }) end`                          | Previous Diagnostic             |
| `]d`         | `function() vim.diagnostic.jump({ count = 1, float = true }) end`                           | Next Diagnostic                 |
| `<leader>q`  | `vim.diagnostic.setqflist`                                                                  | Open Diagnostic Quickfix        |
| `gK`         | `vim.diagnostic.setqflist`                                                                  | Toggle diagnostic virtual_lines |

</details>

## Buffer Switching

<details>
    <summary>Click to see mappings</summary>

| Key   | Action     | Description     |
| ----- | --------   | -------------   |
| `gbn` | `:bnext`   | Next buffer     |
| `gbp` | `:bprev`   | Previous buffer |
| `gbd` | `:bdelete` | Delete buffer   |

</details>

## Improved scrolling & Search

<details>
    <summary>Click to see mappings</summary>

| Key     | Action    | Description                                |
| -----   | --------  | -------------                              |
| `<C-d>` | `<C-d>zz` | Scroll down and center cursor              |
| `<C-u>` | `<C-u>zz` | Scroll up and center cursor                |
| `n`     | `nzzzv`   | Next search result, center, open folds     |
| `N`     | `Nzzzv`   | Previous search result, center, open folds |

</details>

## Window Management

<details>
    <summary>Click to see mappings</summary>

| Key             | Description                                                        |
| -----           | -------------                                                      |
| `<C-w> l`       | Move cursor to left window                                         |
| `<C-w> j`       | Move cursor to below window                                        |
| `<C-w> k`       | Move cursor to above window                                        |
| `<C-w> h`       | Move cursor to right window                                        |
| `<C-w> x`       | Exchange current window with next one                              |
| `<C-w> H`       | Changes current window split state to right positon                |
| `<C-w> J`       | Changes current window split state to down positon                 |
| `<C-w> K`       | Changes current window split state to up positon                   |
| `<C-w> L`       | Changes current window split state to left positon                 |
| `<C-w> o`       | Closes all other windows except where cursor is                    |
| `<C-w> c(or q)` | Closes current window                                              |
| `<C-w>=`        | Make windows equally sized                                         |
| `<C-w> w`       | Move cursor to the focusable window below/right of the current one |
| `<C-w> v`       | Opens new window of the current buffer in the vertical split       |
| `<C-w> s`       | Opens new window of the current buffer in the horizontal split     |
| `<A-h>`         | Resize window right                                                |
| `<A-j>`         | Resize window down                                                 |
| `<A-k>`         | Resize window up                                                   |
| `<A-l>`         | Resize window left                                                 |

</details>

## Convenience

<details>
    <summary>Click to see mappings</summary>

| Key                 | Action                           | Description                             |
| -----               | --------                         | -------------                           |
| `<C-Enter>`         | `o<Esc>`                         | New line below without insert mode      |
| `<C-Backspace>`     | `O<Esc>`                         | New line above without insert mode      |
| `=wb`               | `MiniTrailspace.trim()` + `gg=G` | Reindent all & trim trailing whitespace |
| `<Esc>`             | `:nohlsearch`                    | Clear search highlight                  |

</details>

## Mini.nvim

<details>
    <summary>Click to see mappings</summary>

| Key                       | Mode          | Action                           |
| -----                     | ------        | --------                         |
| `gcc`                     | Normal        | Toggle comment (MiniComment)     |
| `gc`                      | Visual        | Toggle comment (MiniComment)     |
| `H`                       | Visual        | Move selection left (MiniMove)   |
| `L`                       | Visual        | Move selection right (MiniMove)  |
| `J`                       | Visual        | Move selection down (MiniMove)   |
| `K`                       | Visual        | Move selection up (MiniMove)     |
| `ga + character to align` | Visual/Normal | Align text by character to align |
| `gX`                      | Visual/Normal | Exchanging text regions          |

</details>

## Global

<details>
    <summary>Click to see mappings</summary>

| Key                     | Description                                                 |
| -----                   | -------------                                               |
| `:h[elp] keyword`       | open help for keyword                                       |
| `:sav[eas] file`        | save file as                                                |
| `:clo[se]`              | close current pane                                          |
| `:b[uffer] buffer_name` | edit buffer from the buffer list                            |
| `:fin[d] path_to_file`  | find file in 'path' and then :edit it. see also: 'findfunc' |
| `:ter[minal]`           | open a terminal window                                      |
| `K`                     | open man page for word under cursor                         |

</details>

## Macros

<details>
    <summary>Click to see mappings</summary>

| Key   | Description            |
| ----- | -------------          |
| `qa`  | record macro a         |
| `q`   | stop recording macro   |
| `@a`  | run macro a            |
| `@@`  | rerun last run macro   |
| `5@q` | repeat macro q 5 times |

</details>

## Cursor movement

<details>
    <summary>Click to see mappings</summary>

| Key           | Description                                                           |
| -----         | -------------                                                         |
| `h`           | move cursor left                                                      |
| `j`           | move cursor down                                                      |
| `k`           | move cursor up                                                        |
| `l`           | move cursor right                                                     |
| `gj`          | move cursor down (multi-line text)                                    |
| `gk`          | move cursor up (multi-line text)                                      |
| `H`           | move to top of screen                                                 |
| `M`           | move to middle of screen                                              |
| `L`           | move to bottom of screen                                              |
| `w`           | jump forwards to the start of a word                                  |
| `W`           | jump forwards to the start of a word (words can contain punctuation)  |
| `e`           | jump forwards to the end of a word                                    |
| `E`           | jump forwards to the end of a word (words can contain punctuation)    |
| `b`           | jump backwards to the start of a word                                 |
| `B`           | jump backwards to the start of a word (words can contain punctuation) |
| `ge`          | jump backwards to the end of a word                                   |
| `gE`          | jump backwards to the end of a word (words can contain punctuation)   |
| `%`           | move to matching character                                            |
| `0`           | jump to the start of the line                                         |
| `^`           | jump to the first non-blank character of the line                     |
| `$`           | jump to the end of the line                                           |
| `g_`          | jump to the last non-blank character of the line                      |
| `gg`          | go to the first line of the document                                  |
| `G`           | go to the last line of the document                                   |
| `5gg` or `5G` | go to line 5                                                          |
| `gd`          | move to local declaration                                             |
| `gD`          | move to global declaration                                            |
| `fx`          | jump to next occurrence of character x                                |
| `tx`          | jump to before next occurrence of character x                         |
| `Fx`          | jump to the previous occurrence of character x                        |
| `Tx`          | jump to after previous occurrence of character x                      |
| `;`           | repeat previous f, t, F or T movement                                 |
| `,`           | repeat previous f, t, F or T movement, backwards                      |
| `}`           | jump to next paragraph (or function/block, when editing code)         |
| `{`           | jump to previous paragraph (or function/block, when editing code)     |
| `zz`          | center cursor on screen                                               |
| `zt`          | position cursor on top of the screen                                  |
| `zb`          | position cursor on bottom of the screen                               |
| `Ctrl+e`      | move screen down one line (without moving cursor)                     |
| `Ctrl+y`      | move screen up one line (without moving cursor)                       |
| `Ctrl+b`      | move screen up one page (cursor to last line)                         |
| `Ctrl+f`      | move screen down one page (cursor to first line)                      |
| `Ctrl+i`      | go to newer cursor position in jump list                              |
| `Ctrl+o`      | go to older cursor position in jump list                              |

</details>

## Insert mode

<details>
    <summary>Click to see mappings</summary>

| Key               | Description                                                  |
| -----             | -------------                                                |
| `i`               | insert before the cursor                                     |
| `I`               | insert at the beginning of the line                          |
| `a`               | insert (append) after the cursor                             |
| `A`               | insert (append) at the end of the line                       |
| `o`               | append (open) a new line below the current line              |
| `O`               | append (open) a new line above the current line              |
| `ea`              | insert (append) at the end of the word                       |
| `Ctrl+h`          | delete the character before the cursor during insert mode    |
| `Ctrl+w`          | delete word before the cursor during insert mode             |
| `Ctrl+j`          | add a line break at the cursor position during insert mode   |
| `Ctrl+t`          | indent (move right) line one shiftwidth during insert mode   |
| `Ctrl+d`          | de-indent (move left) line one shiftwidth during insert mode |
| `Ctrl+n`          | insert (auto-complete) next match before the cursor          |
| `Ctrl+p`          | insert (auto-complete) previous match before the cursor      |
| `Ctrl+rx`         | insert the contents of register x                            |
| `Ctrl+ox`         | temporarily enter normal mode to issue one command x         |
| `Esc` or `Ctrl+c` | exit insert mode                                             |

</details>

## Editing

<details>
    <summary>Click to see mappings</summary>

| Key      | Description                                                  |
| -----    | -------------                                                |
| `r`      | replace a single character                                   |
| `R`      | replace more than one character, until Esc is pressed        |
| `J`      | join line below to the current one with one space in between |
| `gJ`     | join line below to the current one without space in between  |
| `gwip`   | reflow paragraph                                             |
| `g~`     | switch case up to motion                                     |
| `gu`     | change to lowercase up to motion                             |
| `gU`     | change to uppercase up to motion                             |
| `cc`     | change (replace) entire line                                 |
| `c$`     | change (replace) to the end of the line                      |
| `ciw`    | change (replace) entire word                                 |
| `cw`     | change (replace) to the end of the word                      |
| `s`      | delete character and substitute text (same as cl)            |
| `S`      | delete line and substitute text (same as cc)                 |
| `xp`     | transpose two letters (delete and paste)                     |
| `u`      | undo                                                         |
| `U`      | restore (undo) last changed line                             |
| `Ctrl+r` | redo                                                         |
| `.`      | repeat last command                                          |
| `Ctrl+a` | increases the number                                         |
| `Ctrl+x` | decreases the number                                         |

</details>

## Marking text (visual mode)

<details>
    <summary>Click to see mappings</summary>

| Key                    | Description                                       |
| -----                  | -------------                                     |
| `v`                    | start visual mode, mark lines, then do a command  |
| `V`                    | start linewise visual mode                        |
| `gv`                   | reselect previous selection                       |
| `o`                    | move to other end of marked area                  |
| `Ctrl+v`               | start visual block mode                           |
| `O`                    | move to other corner of block                     |
| `aw`                   | mark a word                                       |
| `ab`                   | a block with ()                                   |
| `aB`                   | a block with {}                                   |
| `at`                   | a block with <> tags                              |
| `ib`                   | inner block with ()                               |
| `iB`                   | inner block with {}                               |
| `it`                   | inner block with <> tags                          |
| `Esc` or `Ctrl+c`      | exit visual mode                                  |
| `Ctrl+v -> g+ctrl+a/x` | inc/decr sequence of numbers in visual block mode |

</details>

## Visual commands

<details>
    <summary>Click to see mappings</summary>

| Key  | Description                           |
| ---  | -------------                         |
| `>`  | shift text right                      |
| `<`  | shift text left                       |
| `y`  | yank (copy) marked text               |
| `d`  | delete marked text                    |
| `~`  | switch case                           |
| `u`  | change marked text to lowercase       |
| `U`  | change marked text to uppercase       |

</details>

## Registers

<details>
    <summary>Click to see mappings</summary>

| Key    | Description                              |
| -----  | -------------                            |
| `:reg` | show registers content                   |
| `"xy`  | yank into register x                     |
| `"xp`  | paste contents of register x             |
| `"+y`  | yank into the system clipboard register  |
| `"+p`  | paste from the system clipboard register |

</details>

## Cut and paste

<details>
    <summary>Click to see mappings</summary>

| Key           | Description                                                         |
| -----         | -------------                                                       |
| `yy`          | yank (copy) a line                                                  |
| `2yy`         | yank (copy) 2 lines                                                 |
| `yw`          | yank the characters of the word from cursor to start of next word   |
| `yiw`         | yank (copy) word under the cursor                                   |
| `yaw`         | yank word under the cursor and the space after or before it         |
| `y$`          | yank (copy) to end of line                                          |
| `p`           | put (paste) the clipboard after cursor                              |
| `P`           | put (paste) before cursor                                           |
| `gp`          | put after cursor and leave cursor after the new text                |
| `gP`          | put before cursor and leave cursor after the new text               |
| `dd`          | delete (cut) a line                                                 |
| `2dd`         | delete (cut) 2 lines                                                |
| `dw`          | delete the characters of the word from cursor to start of next word |
| `diw`         | delete (cut) word under the cursor                                  |
| `daw`         | delete word under the cursor and the space after or before it       |
| `:3,5d`       | delete lines starting from 3 to 5                                   |
| `:g/{pat}/d`  | delete all lines containing pattern                                 |
| `:g!/{pat}/d` | delete all lines not containing pattern                             |
| `d$`          | delete (cut) to the end of the line                                 |
| `x`           | delete (cut) character                                              |

</details>

## Indent text

<details>
    <summary>Click to see mappings</summary>

| Key    | Description                                       |
| -----  | -------------                                     |
| `>>`   | indent (move right) line one shiftwidth           |
| `<<`   | de-indent (move left) line one shiftwidth         |
| `>%`   | indent a block with () or {} (cursor on brace)    |
| `<%`   | de-indent a block with () or {} (cursor on brace) |
| `>ib`  | indent inner block with ()                        |
| `>at`  | indent a block with <> tags                       |
| `3==`  | re-indent 3 lines                                 |
| `=%`   | re-indent a block with () or {} (cursor on brace) |
| `=iB`  | re-indent inner block with {}                     |
| `gg=G` | re-indent entire buffer                           |
| `]p`   | paste and adjust indent to current line           |

</details>

## Exiting

<details>
    <summary>Click to see mappings</summary>

| Key              | Description                               |
| -----            | -------------                             |
| `:w`             | write (save) the file, but don't exit     |
| `:w !sudo tee %` | write out the current file using sudo     |
| `:wq` or `ZZ`    | write (save) and quit                     |
| `:q`             | quit (fails if there are unsaved changes) |
| `:q!` or `ZQ`    | quit and throw away unsaved changes       |
| `:wqa`           | write (save) and quit on all tabs         |

</details>

## Search and replace

<details>
    <summary>Click to see mappings</summary>

| Key              | Description                                                          |
| -----            | -------------                                                        |
| `/pattern`       | search for pattern                                                   |
| `?pattern`       | search backward for pattern                                          |
| `\vpattern`      | 'very magic' pattern: no escaping needed                             |
| `n`              | repeat search in same direction                                      |
| `N`              | repeat search in opposite direction                                  |
| `:%s/old/new/g`  | replace all old with new throughout file                             |
| `:%s/old/new/gc` | replace all old with new throughout file with confirmations          |
| `:noh`           | remove highlighting of search matches                                |
| `*`              | search forward for the occurrence of the word nearest to the cursor  |
| `#`              | same as "*", but search backward                                     |

</details>

## Tabs

<details>
    <summary>Click to see mappings</summary>

| Key              | Description                                           |
| -----            | -------------                                         |
| `:tabnew`        | open a file in a new tab                              |
| `Ctrl+wT`        | move the current split window into its own tab        |
| `gt`             | move to the next tab                                  |
| `gT`             | move to the previous tab                              |
| `#gt`            | move to tab number #                                  |
| `:tabm #`        | move current tab to the #th position (indexed from 0) |
| `:tabc`          | close the current tab and all its windows             |
| `:tabo`          | close all tabs except for the current one             |
| `:tabdo command` | run the command on all tabs                           |

</details>

## Different

<details>
    <summary>Click to see mappings</summary>

| Key                      | Description                                                                                                                       |
| -----                    | -------------                                                                                                                     |
| `zf`                     | manually define a fold up to motion                                                                                               |
| `zd`                     | delete fold under the cursor                                                                                                      |
| `za`                     | toggle fold under the cursor                                                                                                      |
| `zo`                     | open fold under the cursor                                                                                                        |
| `zc`                     | close fold under the cursor                                                                                                       |
| `zr`                     | reduce (open) all folds by one level                                                                                              |
| `zm`                     | fold more (close) all folds by one level                                                                                          |
| `zi`                     | toggle folding functionality                                                                                                      |
| `]c`                     | jump to start of next change                                                                                                      |
| `[c`                     | jump to start of previous change                                                                                                  |
| `do`                     | obtain (get) difference (from other buffer)                                                                                       |
| `dp`                     | put difference (to other buffer)                                                                                                  |
| `:diffthis`              | make current window part of diff                                                                                                  |
| `:dif`                   | update differences                                                                                                                |
| `:diffoff`               | switch off diff mode for current window                                                                                           |
| `:read[r] file.c`        | inserts the text from the file.c                                                                                                  |
| `:r !shell_command`      | inserts the output info from the shell_command                                                                                    |
| `:put x`                 | put the text from register x after the cursor                                                                                     |
| `:reg`                   | open register contents history                                                                                                    |
| `Ctrl+f in command mode` | opens additional buffer when you can continue to type commands with all the motions available                                     |
| `Ctrl+]`                 | jump to the definition of the keyword under the cursor. same as ":tag {name}", where {name} is the keyword under or after cursor. |
| `Ctrl+T`                 | jump to count older entry in the tag stack                                                                                        |
| `g]`                     | like ctrl-], but use ":tselect" instead of ":tag"                                                                                 |
| `gx`                     | opens the current filepath, URL                                                                                                   |
| `gf`                     | edit the file whose name is under or after the cursor. Mnemonic: "goto file"                                                      |

</details>

## Documentation commands(Mostly multi repeat/search and replace/patterns topics)

<details>
    <summary>Click to see mappings</summary>

| Topic                      | Vim help                   | What it covers                                        |
| ---------------            | -----------------          | ----------------------------------------------------- |
| `:g` (global)              | `:help :g`                 | Pattern-based multi-line command execution            |
| `:normal`                  | `:help :normal`            | Execute Normal mode commands from command-line        |
| `:s` (substitut)           | `:help :s`                 | Search & replace syntax                               |
| Patterns                   | `:help pattern`            | All pattern related information                       |
| Character classes          | `:help /character-classes` | `\s`, `\d`, `\w`, `\a`, `\l`, `\u`, `\x`              |
| Multi items(pattern items) | `:help /multi`             | `*`, `\+`, `\=`, `\{n,m}`, `\{-}`                     |
| Groups & capture           | `:help /\(\)`              | What are the capture groups: `\(\)`                   |
| Backreferences             | `:help /\1`                | `\1` – `\9`                                           |
| Pattern atoms list         | `:help pattern-atoms`      | All pattern atoms by category (ordinary, multi, etc.) |
| Range syntax               | `:help range`              | Line ranges (`.`, `$`, `%`, `'<,'>`, etc.)            |
| Flags for `:s`             | `:help :s_flags`           | `g`, `c`, `i`, `I`, `n`, `e`, ...                     |
| Macros/registers           | `:help registers`          | Recording (`q`), replay (`@`), registers              |

</details>

## File Managament(Dired)

<details>
    <summary>Click to see mappings</summary>

| Key                 | Description                                                    |
| ------------------- | ---------------------------------------------------            |
| `<CR>`              | Open the file or directory at the cursor.                      |
| `d`                 | Create new directories and files.                              |
| `M`                 | Mark directories and files (both in normal and visual mode).   |
| `C`                 | Copy files.                                                    |
| `X`                 | Move files.                                                    |
| `P`                 | Paste files in the current directory.                          |
| `D`                 | Delete directories and files (both in normal and visual mode). |
| `R`                 | Rename directories and files.                                  |
| `MD`                | Delete marked files.                                           |
| `MC`                | Copy marked files.                                             |
| `MX`                | Move marked files.                                             |
| `_`                 | Go to the parent directory.                                    |
| `-`                 | Go back to previous directory.                                 |
| `!`                 | Apply any command to directories/files under cursor.           |
| `&`                 | Apply any command to marked directories and files.             |
| `.`                 | Toggle show_hidden.                                            |
| `,`                 | Change sort_order.                                             |
| `c`                 | Toggle colors.                                                 |
| `*`                 | Toggle filetype icons.                                         |
| `(`                 | Toggle hiding/showing file details.                            |
| `q`                 | Quit the 'dired' interface.                                    |

</details>

## Multicursor

<details>
    <summary>Click to see mappings</summary>

| Key     | Description                                                                               |
| ---     | ---                                                                                       |
| `<Esc>` | Clear the selections and go back to normal mode                                           |
| `<C-c>` | Clear the selections and go back to normal mode                                           |
| `i`     | Enters insert mode                                                                        |
| `a`     | Enters append mode                                                                        |
| `e`     | Enters extend mode                                                                        |
| `c`     | Deletes the text inside selections and starts insert mode                                 |
| `n`     | `[count]` Finds the next match after the main selection                                   |
| `N`     | `[count]` Finds the previous match before the main selection                              |
| `<C-a>` | Creates selections for all the matches                                                    |
| `q`     | `[count]` Skips the current selection and finds the next one                              |
| `Q`     | `[count]` Skips the current selection and finds the previous one                          |
| `]`     | `[count]` Swaps the main selection with next selection                                    |
| `[`     | `[count]` Swaps the main selection with previous selection                                |
| `}`     | `[count]` Deletes the main selection and goes to next                                     |
| `{`     | `[count]` Deletes the main selection and goes to previous                                 |
| `<C-n>` | Creates a selection for the char under the cursor                                         |
| `j`     | `[count]` Creates a selection on the char below the cursor                                |
| `J`     | `[count]` Skips the current selection and Creates a selection on the char below           |
| `k`     | `[count]` Creates a selection on the char above the cursor                                |
| `K`     | `[count]` Skips the current selection and Creates a selection on the char above           |
| `r`     | Replaces the text inside selections with content of `unnamed register`                    |
| `p`     | Puts the text inside `unnamed register` before selections                                 |
| `P`     | Puts the text inside `unnamed register` after selections                                  |
| `y`     | Yanks the text inside selections to `unnamed register`                                    |
| `Y`     | Yanks the text from the start of selection till the end of the line to `unnamed register` |
| `yy`    | Yanks the line of selection to `unnamed register`                                         |
| `gu`    | changes selections case to lowercase                                                      |
| `gU`    | changes selections case to UPPERCASE                                                      |
| `z`     | Aligns selections by adding space before selections                                       |
| `Z`     | Aligns selections by adding space at the start of the line                                |
| `d`     | Deletes the text inside selections                                                        |
| `D`     | `count` Deletes the text from the start of selections till the end of the line            |
| `dd`    | `count` Deletes line of selections                                                        |
| `@`     | Executes a macro at the start of selections                                               |
| `.`     | Repeats last change at the start of selections                                            |
| `,`     | Clears All Selections except the main one                                                 |
| `:`     | Prompts for a normal command and Executes it at the start of selections                   |
| `u`     | Undo changes                                                                              |
| `<C-r>` | Redo changes                                                                              |

</details>

<details>
    <summary>Insert, Append and Change mode</summary>

| Key         | Description                                                 |
| ---         | ---                                                         |
| `<Esc>`     | Returns to multicursor normal mode                          |
| `<C-c>`     | Returns to multicursor normal mode                          |
| `<BS>`      | Deletes the char before the selections                      |
| `<Del>`     | Deletes the char under the selections                       |
| `<Left>`    | Moves the selections one char Left                          |
| `<Up>`      | Moves the selections one line Up                            |
| `<Right>`   | Moves the selections one char Right                         |
| `<Down>`    | Moves the selections one line Down                          |
| `<C-Left>`  | Moves the selections one word Left                          |
| `<C-Right>` | Moves the selections one word Right                         |
| `<Home>`    | Moves the selections to start of line                       |
| `<End>`     | Moves the selections to end of line                         |
| `<CR>`      | Insert one line below the selections                        |
| `<C-j>`     | Insert one line below the selections                        |
| `<C-v>`     | Pastes the text from system clipboard                       |
| `<C-r>`     | Insert the contents of a register                           |
| `<C-w>`     | Deletes one word before the selections                      |
| `<C-BS>`    | Deletes one word before the selections                      |
| `<C-u>`     | Deletes from the start of selections till the start of line |

</details>

<details>
    <summary>Extend mode</summary>

Once you enter the Extend mode, you can expand or shrink your selections using Vim motions or Treesitter nodes.
At first, the left side of the selections stays put, and selections get extended from the right side.
But you can change which side of selections stay put by pressing `o`.

| Key     | Description                                                   |
| ---     | ---                                                           |
| `<Esc>` | Returns to multicursor normal mode                            |
| `c`     | Prompts user for a motion and performs it                     |
| `o`     | Toggles the anchor side                                       |
| `O`     | Toggles the anchor side                                       |
| `w`     | `[count]` word forward                                        |
| `e`     | `[count]` forward to end of word                              |
| `b`     | `[count]` word backward                                       |
| `h`     | `[count]` char left                                           |
| `j`     | `[count]` char down                                           |
| `k`     | `[count]` char up                                             |
| `l`     | `[count]` char right                                          |
| `t`     | Extends the selection to the parent of the selected node      |
| `r`     | Shrinks the selection to the first child of the selected node |
| `y`     | Shrinks the selection to the last child of the selected node  |
| `u`     | Undo Last selections extend or shrink                         |
| `$`     | `[count]` to end of line                                      |
| `^`     | To the first non-blank character of the line                  |

</details>
