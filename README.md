# Obsidian.nvim

A Neovim plugin for [Obsidian](https://obsidian.md), written in Lua.

This is for people who love the concept of Obsidian -- a simple, markdown-based notes app -- but love Neovim too much to stand typing characters into anything else.

## Features

- ▶️ Autocompletion for note references via [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) (triggered by typing `[[`)
- 🏃 Go to a note buffer with `gf` when cursor is on a reference
- 💅 Additional markdown syntax highlighting and concealing for references

### Commands

- `:ObsidianBacklinks` for getting a location list of references to the current buffer
- `:ObsidianToday` to create a new daily note
- `:ObsidianOpen` to open a note in the Obsidian app (only works on MacOS for now - [#4](https://github.com/epwalsh/obsidian.nvim/issues/4))
- `:ObsidianNew` to create a new note with a given title.

## Setup

### Requirements

- NeoVim >= 0.8.0 (this plugin uses `vim.fs`).
- If you want completion features (recommended) you'll also need [ripgrep](https://github.com/BurntSushi/ripgrep) to be installed and on your `$PATH`.
See [ripgrep#installation](https://github.com/BurntSushi/ripgrep) for install options.

### Install

Using `vim-plug`, for example:

```vim
Plug 'hrsh7th/nvim-cmp'       " optional, for completion
Plug 'godlygeek/tabular'      " optional, needed for 'preservim/vim-markdown'
Plug 'preservim/vim-markdown' " optional, recommended for syntax highlighting, folding, etc if you're not using nvim-treesitter
Plug 'epwalsh/obsidian.nvim'
```

To avoid unexpected breaking changes, you can also pin `Obsidian.nvim` to a specific release like this:

```vim 
Plug 'epwalsh/obsidian.nvim', { 'tag': 'v1.*' }
```

Always check the [CHANGELOG](./CHANGELOG.md) when upgrading.

### Minimal configuration

For a minimal configuration, just add:

```lua
require("obsidian").setup({
  dir = "~/my-vault",
  completion = {
    nvim_cmp = true, -- if using nvim-cmp, otherwise set to false
  }
})
```

❗ Note: you do **not** need to specify this plugin as an `nvim-cmp` "source".
Obsidian.nvim will set itself up as a source automatically when you enter a markdown buffer within your vault directory.

```lua
require("cmp").setup({
  sources = {
    { name = "obsidian" }, -- WRONG! Don't put this here. Obsidian configures itself for nvim-cmp
  },
})
```

### Advanced configuration

#### Customizing note paths and IDs

If you want to customize how the file names / unique IDs for new notes are created, set the configuration option `note_id_func` to your own function that takes an optional string (the title of the note) as input and returns a string representing a unique ID or file name / path (relative to your vault directory).

For example:

```lua
require("obsidian").setup({
  dir = "~/my-vault",
  note_id_func = function(title)
    -- Create note IDs in a Zettelkasten format with a timestamp and a suffix.
    local suffix = ""
    if title ~= nil then
      -- If title is given, transform it into valid file name.
      suffix = title:gsub(" ", "-"):gsub("[^A-Za-z0-9-]", ""):lower()
    else
      -- If title is nil, just add 4 random uppercase letters to the suffix.
      for _ in 1, 4 do
        suffix = suffix .. string.char(math.random(65, 90))
      end
    end
    return tostring(os.time()) .. "-" .. suffix
  end
})
```

In this case a note with the title "My new note" will given an ID that looks something like `1657296016-my-new-note`, and therefore the file name `1657296016-my-new-note.md`.
If you always want to put new notes in a particular subdirectory of your vault, use the option `notes_subdir`:

```lua
require("obsidian").setup({
  dir = "~/my-vault",
  notes_subdir = "notes",
})
```

The `notes_subdir` and `note_id_func` options are not mutually exclusive. You can use them both. For example, using a combination of both of the above settings, a new note called "My new note" will assigned a path like `notes/1657296016-my-new-note.md`.

#### Customizing daily notes path

If you want to customize where the daily notes are being stored, just set the `daily_notes.folder` option:

```lua
require("obsidian").setup({
  dir = "~/my-vault",
  daily_notes = {
    folder = "dailies",
  }
})
```

This option isn't mutually exclusive with the `notes_subdir` function; the `daily_notes.folder` path won't be appended to `notes_subdir`, so both paths will need to be relative to `dir`.

E.g., if you have your vault at `~/my-vault`, and want to save your notes under `~/my-vault/notes`, and your dailies under `~/my-vault/notes/dailies`, this is the right config:

```lua
require("obsidian").setup({
  dir = "~/my-vault",
  notes_subdir = "notes",
  daily_notes = {
    folder = "notes/dailies",
  }
})
```

#### Using nvim-treesitter

If you're using [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter/blob/master/README.md) and not [vim-markdown](https://github.com/preservim/vim-markdown), you'll probably want to enable `additional_vim_regex_highlighting` for markdown to benefit from Obsidian.nvim's extra syntax improvements:

```lua 
require("nvim-treesitter.configs").setup({
  ensure_installed = { "markdown", "markdown_inline", ... },
  highlight = {
    enable = true,
    additional_vim_regex_highlighting = { "markdown" },
  },
})
```
