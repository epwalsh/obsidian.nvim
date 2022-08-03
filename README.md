# Obsidian.nvim

A Neovim plugin for [Obsidian](https://obsidian.md), written in Lua.

## Install

Using `vim-plug`, for example:

```vim
Plug 'nvim-lua/plenary.nvim'  " required dependency
Plug 'kkharji/sqlite.lua'     " required dependency (you'll also need sqlite3 installed)
Plug 'epwalsh/obsidian.nvim'
```

Obsidian.nvim also integrates directly with [`nvim-cmp`](https://github.com/hrsh7th/nvim-cmp) for completion.
Note that you do *not* need to specify this plugin an `nvim-cmp` "source".
Obsidian.nvim will set itself up as a source automatically when you enter a markdown buffer within your vault directory.

```lua
require("cmp").setup({
  sources = {
    { name = "obsidian" }, -- WRONG! Don't put this here
  },
})

```

## Configuration

For a minimal configuration, just add:

```lua
require("obsidian").setup({
  dir = "~/my-vault",
  completion = {
    nvim_cmp = true, -- if using nvim-cmp, other set to false
  }
})
```
