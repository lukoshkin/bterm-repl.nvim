# REPL-like Extension for [Bterm](https://github.com/lukoshkin/bterm.nvim)

`bterm` plugin gives a quicker access to a terminal in Neovim.  
However, it does not allow sending lines of code to an interpreter open  
in `BottomTerm` instance. This REPL-like extension aims to bridge this gap.

## Features

- Written in pure Lua<br>(Ok, Neovim + Lua 🙃)

- Easy access to interpreter windows.  
  Open IPython, bash/zsh, or lua in a `BottomTerm` instance with just a keymap.

- Send code to execute it in an interpreter window.  
  Currently, execution in cells are available for `'python'`, `'sh'`,
  and `'lua'` buffers.<br>Line execution works for all buffers.

- Split code into sections with cell separators.  
  By default, they are `--#` and `#%%` for `'lua'` and `'python'` and `'sh'`
  buffers, respectively.<br>Quick navigation is possible using key mappings.

- Set the line separator to alter the way how copied lines are concatenated.  
  Swiftly switch between '\n' and your custom separators.

- Highlight cell separators with customizable colors.  
  One can specify color per `filetype`.

- Unlike "[vim-ipython](https://github.com/hanschen/vim-ipython-cell)
  \+ [vim-slime](https://github.com/jpalardy/vim-slime)" plugins combo,
  `bterm-repl` preserves<br>the content of the clipboard when sending code
  for the execution. Moreover, you<br>can send code from host to a docker
  container by properly choosing the line separator.

## Installation

With [**packer**](https://github.com/wbthomason/packer.nvim)

```lua
use {
  'lukoshkin/bterm-repl.nvim',
  requires = 'lukoshkin/bterm.nvim',
  config = function ()
    require'bottom-term'.setup()
    require'bottom-term-repl'.setup()
  end
}
```

## Mappings

_Standard mappings provided by the [bterm](https://github.com/lukoshkin/bterm.nvim) plugin:_

- `<A-t>` ─ toggle a terminal window &emsp;_(_`BottomTerm` _instance)._
- `<C-t>` ─ reverse the terminal orientation.
- `<A-c>` ─ terminate the terminal session.
- `:BottomTerm <cmd>` ─ execute a `<cmd>` in the terminal.

_Mappings available with the extension:_

- `<Space>l` ─ clear the interpreter screen
- `<Space>jn` ─ jump to the next cell
- `<Space>jp` ─ jump to the previous cell
- `<Space>00` ─ restart the interpreter session
- `<Space>x` ─ close all pyplot figures
- `<C-c><C-c>` ─ execute the current line in the interpreter window
- `<CR>` ─ execute a cell in the interpreter window
- `<Space><CR>` ─ execute a cell and jump to the next one
- `<Space>s` ─ toggle line separator to its second set value
- `<Leader>ss` ─ select interpreter for a new session
- `<Space>ip` ─ launch IPython in the interpreter window

## Customization

One can adjust to their needs by altering some of the defaults below.

```lua
use {
  'lukoshkin/bterm-repl.nvim',
    requires = 'lukoshkin/bterm.nvim',
    config = function ()
      require'bottom-term-repl'.setup {
        clipboard_occupation_time = 500,
        line_separators = { nil, '; \\\n', '; ', '' },
        cell_delimiters = {
          python = { '#%%', '# %%', '# In\\[\\(\\d\\+\\| \\)\\]:' },
          lua = { '--#' },
          sh = { '#%%' },
        },
        keys = {
          clear = '<Space>l',
          next_cell = '<Space>jn',
          prev_cell = '<Space>jp',
          restart = '<Space>00',
          close_xwins = '<Space>x',
          run_line = '<C-c><C-c>',
          run_cell = '<CR>',
          run_and_jump = '<Space><CR>',
          toggle_separator = '<Space>s',
          toggle_separator_backward = '<Space>S',
          select_session = '<Leader>ss',
          ipy_launch = '<Space>ip',
        },
        colors = {
          python = { bold = true, bg = '#306998', fg = '#FFD43B' },
          lua = { bold = true, bg = '#C5C5E1', fg = '#6B6BB3' },
          sh = { bold = true, bg = '#293137', fg = '#4EAA25' },
        }
      }
  end
}
```

`clipboard_occupation_time` - time after which the content of the clipboard
will be restored. If it is too short, the restored content will be sent to
IPython instead. Note that it is only valid for IPython and when the line
separator is set to `nil` (what is equivalent to `'\n'` in terms of the
implementation).

`gain_focus_time`: some commands (like `clear`) may require round trips to the
terminal window with a short switch to insert mode to gain focus at the current
log stream. Too short values of the option may be not enough to scroll down the
screen.

## Further Development

- [x] Add base functionality.
- [ ] Add more options for finer configuration.
- [x] Add line separator toggle (whether to join lines with '\n' or ';').
- [ ] Add demos: working in IPython; different filetypes; highlighting;
      toggling the separator.
