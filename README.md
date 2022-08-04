# Obsidian.nvim

A Neovim plugin for [Obsidian](https://obsidian.md), written in Lua.

## Features

- ▶️ Completion via [nvim-cmp](https://github.com/hrsh7th/nvim-cmp)

## In-progress

- [ ] Command for getting backlinks to current buffer

## Requirements

The plugin [plenary.nvim](https://github.com/nvim-lua/plenary.nvim) is required, and if you want completion features (recommended) you'll also need [ripgrep](https://github.com/BurntSushi/ripgrep) to be installed and on your `$PATH`.
See [ripgrep#installation](https://github.com/BurntSushi/ripgrep) for install options.

## Install

Using `vim-plug`, for example:

```vim
Plug 'nvim-lua/plenary.nvim'  " required
Plug 'hrsh7th/nvim-cmp'       " optional (for completion)
Plug 'epwalsh/obsidian.nvim'
```

## Configuration

For a minimal configuration, just add:

```lua
require("obsidian").setup({
  dir = "~/my-vault",
  completion = {
    nvim_cmp = true, -- if using nvim-cmp, otherwise set to false
  }
})
```

:exclamation: Note that you do **not** need to specify this plugin as an `nvim-cmp` "source".
Obsidian.nvim will set itself up as a source automatically when you enter a markdown buffer within your vault directory.

```lua
require("cmp").setup({
  sources = {
    { name = "obsidian" }, -- WRONG! Don't put this here. Obsidian configures itself for nvim-cmp
  },
})
```
