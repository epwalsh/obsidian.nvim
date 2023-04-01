# Obsidian.nvim

A Neovim plugin for writing and navigating an [Obsidian](https://obsidian.md) vault, written in Lua.

Built for people who love the concept of Obsidian -- a simple, markdown-based notes app -- but love Neovim too much to stand typing characters into anything else.

*This plugin is not meant to replace Obsidian, but to complement it.* My personal workflow involves writing Obsidian notes in Neovim using this plugin, while viewing and reading them using the Obsidian app. That said, this plugin stands on its own as well. You don't necessarily need to use it alongside the Obsidian app.

## Features

- ▶️ Autocompletion for note references via [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) (triggered by typing `[[`)
- 🏃 Go to a note buffer with `gf` when cursor is on a reference (see: [Mapping `:ObsidianFollowLink` to `gf` with follow through](#mapping-obsidianfollowlink-to-gf-with-passthrough) for an even better `gf`)
- 💅 Additional markdown syntax highlighting and concealing for references

### Commands

- `:ObsidianBacklinks` for getting a location list of references to the current buffer.
- `:ObsidianToday` to create a new daily note.
- `:ObsidianYesterday` to open (eventually creating) the daily note for the previous working day.
- `:ObsidianOpen` to open a note in the Obsidian app.
  This command has one optional argument: the ID, path, or alias of the note to open. If not given, the note corresponding to the current buffer is opened.
- `:ObsidianNew` to create a new note.
  This command has one optional argument: the title of the new note.
- `:ObsidianSearch` to search for notes in your vault using [ripgrep](https://github.com/BurntSushi/ripgrep) with [fzf.vim](https://github.com/junegunn/fzf.vim), [fzf-lua](https://github.com/ibhagwan/fzf-lua) or [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim). 
  This command has one optional argument: a search query to start with.
- `:ObsidianQuickSwitch` to quickly switch to another notes in your vault, searching by its name using [fzf.vim](https://github.com/junegunn/fzf.vim), [fzf-lua](https://github.com/ibhagwan/fzf-lua) or [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim).
- `:ObsidianLink` to link an in-line visual selection of text to a note.
  This command has one optional argument: the ID, path, or alias of the note to link to. If not given, the selected text will be used to find the note with a matching ID, path, or alias.
- `:ObsidianLinkNew` to create a new note and link it to an in-line visual selection of text.
  This command has one optional argument: the title of the new note. If not given, the selected text will be used as the title.
- `:ObsidianFollowLink` to follow a note reference under the cursor.
- `:ObsidianTemplate` to insert a template from the templates folder, selecting from a list using [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) or one of the `fzf` alternatives.

### Demo

https://user-images.githubusercontent.com/75107188/227362168-29ff9d4d-5b62-4aff-9442-21cd8c072d29.mp4

## Setup

### Requirements

- NeoVim >= 0.8.0 (this plugin uses `vim.fs` which was only added in 0.8).
- If you want completion and search features (recommended) you'll also need [ripgrep](https://github.com/BurntSushi/ripgrep) to be installed and on your `$PATH`.
See [ripgrep#installation](https://github.com/BurntSushi/ripgrep) for install options.

Search functionality via the `:ObsidianSearch` and `:ObsidianQuickSwitch` command also requires either [fzf.vim](https://github.com/junegunn/fzf.vim) or [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim).

### Install

Using `vim-plug`, for example:

```vim
" (required)
Plug 'nvim-lua/plenary.nvim'

" (optional) for completion:
Plug 'hrsh7th/nvim-cmp'

" (optional) for :ObsidianSearch and :ObsidianQuickSwitch commands unless you use telescope:
Plug 'junegunn/fzf', { 'do': { -> fzf#install() } }
Plug 'junegunn/fzf.vim'

" (optional) another alternative for the :ObsidianSearch and :ObsidianQuickSwitch commands:
Plug 'ibhagwan/fzf-lua'

" (optional) for :ObsidianSearch and :ObsidianQuickSwitch commands if you prefer this over fzf.vim:
Plug 'nvim-telescope/telescope.nvim'

" (optional) recommended for syntax highlighting, folding, etc if you're not using nvim-treesitter:
Plug 'preservim/vim-markdown'
Plug 'godlygeek/tabular'  " needed by 'preservim/vim-markdown'

" (required)
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

❗ Note: you should only call `obsidian.setup(...)` once in your config. Calling it a second time will overwrite the settings from the first call,
so if you choose to use multiple of the examples below, make sure to merge the arguments in each `setup()` call into one.

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
      for _ = 1, 4 do
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

#### Customizing daily notes' date format

You can customize the file name of your daily notes by providing a date formatting function:

```lua
require("obsidian").setup({
  dir = "~/my-vault",
  daily_notes = {
    format_date = function(time)
      return os.date("%Y%m%d", time)  -- format: year, month and date
    end,
  }
})
```

#### Templates support

To insert a template, run the command `:ObsidianTemplate`. This will open [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) or one of the `fzf` alternatives and allow you to select a template from the templates folder. Select a template and hit `<CR>` to insert. Substitution of `{{date}}`, `{{time}}`, and `{{title}}` is supported. 

For example, with the following configuration

```lua
require("obsidian").setup({
  dir = "~/my-vault",
  templates = {
      subdir = "my-templates-folder",
      date_format = "%Y-%m-%d-%a",
      time_format = "%H:%M"
  }
})
```

and the file `~/my-vault/my-templates-folder/note template.md`:

```markdown
# {{title}}
Date created: {{date}}
```

creating the note `Configuring Neovim.md` and executing `:ObsidianTemplate` will insert
```markdown
# Configuring Neovim

Date created: 2023-03-01-Wed
```

above the cursor position.

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

#### Customizing the automatically generated YAML frontmatter

By default the auto-generated YAML frontmatter will just contain `id`, `aliases`, and `tags`, as well as any other fields you add manually. If you want to customize this behavior, set the configuration option `note_frontmatter_func` to a function that takes an `obsidian.Note` object and returns a table. Or if you want to disable this feature, just set `disable_frontmatter = true`.

For example, you can emulate the default functionality like this:

```lua
require("obsidian").setup({
  dir = "~/my-vault",
  note_frontmatter_func = function(note)
    local out = { id = note.id, aliases = note.aliases, tags = note.tags }
    -- `note.metadata` contains any manually added fields in the frontmatter.
    -- So here we just make sure those fields are kept in the frontmatter.
    if note.metadata ~= nil and require("obsidian").util.table_length(note.metadata) > 0 then
      for k, v in pairs(note.metadata) do
        out[k] = v
      end
    end
    return out
  end,
})
```

#### Mapping `:ObsidianFollowLink` to `gf` with passthrough

If you have notes in subdirectories of your vault, Neovim's default `gf` mapping might not be able to find the note corresponding to the reference under your cursor.
If that's the case you can map `gf` to the `:ObsidianFollowLink` command like this:

```lua
vim.keymap.set(
  "n",
  "gf",
  function()
    if require('obsidian').util.cursor_on_markdown_link() then
      return "<cmd>ObsidianFollowLink<CR>"
    else
      return "gf"
    end
  end,
  { noremap = false, expr = true}
)
```

The other benefit of doing this is that it will now work even if your cursor is on the enclosing brackets (`[[` or `]]`) or the alias part of a reference (the part after `|`).

#### Navigate to the current line when using `:ObsidianOpen`

If you have the [Obsidian Advanced URI](https://github.com/Vinzent03/obsidian-advanced-uri) plugin enabled, the Obsidian editor can automatically navigate to the same line in the current NeoVim buffer. For files that are already open, it will update the cursor position within Obsidian's editor. To enable this feature, add `use_advanced_uri = true` to the setup options. For example:
```lua
require("obsidian").setup({
  dir = "~/my-vault",
  use_advanced_uri = true
})
```

## Known Issues 

### Configuring vault directory behind a link

If you are having issues with commands like `ObsidianOpen`, ensure that your vault is configured to use an absolute path rather than a link. If you must use a link in your configuration, make sure that the name of the vault is present in the file path of the link. For example:

```
Vault: ~/path/to/vault/parent/obsidian/
Link: ~/obsidian OR ~/parent
```

