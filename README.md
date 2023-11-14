# obsidian.nvim

A Neovim plugin for writing and navigating an [Obsidian](https://obsidian.md) vault, written in Lua.

Built for people who love the concept of Obsidian -- a simple, markdown-based notes app -- but love Neovim too much to stand typing characters into anything else.

*This plugin is not meant to replace Obsidian, but to complement it.* My personal workflow involves writing Obsidian notes in Neovim using this plugin, while viewing and reading them using the Obsidian app. That said, this plugin stands on its own as well. You don't necessarily need to use it alongside the Obsidian app.

## Table of contents

- 👉 [Features](#features)
  - [Commands](#commands)
  - [Demo](#demo)
- ⚙️ [Setup](#setup)
  - [System requirements](#system-requirements)
  - [Install and configure](#install-and-configure)
  - [Plugin dependencies](#plugin-dependencies)
  - [Configuration options](#configuration-options)
  - [Notes on configuration](#notes-on-configuration)
  - [Using templates](#using-templates)
- 🐞 [Known issues](#known-issues)
- ➕ [Contributing](#contributing)

## Features

- ▶️ Autocompletion for note references via [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) (triggered by typing `[[`)
- 🏃 Optional passthrough for `gf` to enable Obsidian links without interfering with existing functionality
- 💅 Additional markdown syntax highlighting and concealing for references

### Commands

- `:ObsidianOpen` to open a note in the Obsidian app.
  This command has one optional argument: the ID, path, or alias of the note to open. If not given, the note corresponding to the current buffer is opened.
- `:ObsidianNew` to create a new note.
  This command has one optional argument: the title of the new note.
- `:ObsidianQuickSwitch` to quickly switch to another note in your vault, searching by its name using [ripgrep](https://github.com/BurntSushi/ripgrep) with [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim), [fzf.vim](https://github.com/junegunn/fzf.vim), or [fzf-lua](https://github.com/ibhagwan/fzf-lua).
- `:ObsidianFollowLink` to follow a note reference under the cursor.
- `:ObsidianBacklinks` for getting a location list of references to the current buffer.
- `:ObsidianToday` to open/create a new daily note. This command also takes an optional offset in days, e.g. use `:ObsidianToday -1` to go to yesterday's note.
- `:ObsidianYesterday` to open/create the daily note for the previous working day.
- `:ObsidianTomorrow` to open/create the daily note for the next working day.
- `:ObsidianTemplate` to insert a template from the templates folder, selecting from a list using [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim), [fzf.vim](https://github.com/junegunn/fzf.vim), or [fzf-lua](https://github.com/ibhagwan/fzf-lua).
  See ["using templates"](#using-templates) for more information.
- `:ObsidianSearch` to search for notes in your vault using [ripgrep](https://github.com/BurntSushi/ripgrep) with [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim), [fzf.vim](https://github.com/junegunn/fzf.vim), or [fzf-lua](https://github.com/ibhagwan/fzf-lua).
  This command has one optional argument: a search query to start with.
- `:ObsidianLink` to link an in-line visual selection of text to a note.
  This command has one optional argument: the ID, path, or alias of the note to link to. If not given, the selected text will be used to find the note with a matching ID, path, or alias.
- `:ObsidianLinkNew` to create a new note and link it to an in-line visual selection of text.
  This command has one optional argument: the title of the new note. If not given, the selected text will be used as the title.
- `:ObsidianWorkspace` to switch to another workspace.
- (experimental) `:ObsidianRename` to rename the note of the current buffer or reference under the cursor, updating all backlinks across the vault. Since this command is still in alpha and could potentially write a lot of changes to your vault, I highly recommend committing the current state of your vault (if you're using version control) before running it. Alternatively you could do a dry-run first by appending "--dry-run" to the command, e.g. `:ObsidianRename new-id --dry-run`.

### Demo

[![See https://user-images.githubusercontent.com/75107188/227362168-29ff9d4d-5b62-4aff-9442-21cd8c072d29.mp4](https://user-images.githubusercontent.com/75107188/227362168-29ff9d4d-5b62-4aff-9442-21cd8c072d29.mp4)](https://user-images.githubusercontent.com/75107188/227362168-29ff9d4d-5b62-4aff-9442-21cd8c072d29.mp4)

## Setup

### System requirements

- NeoVim >= 0.8.0 (this plugin uses `vim.fs` which was only added in 0.8).
- If you want completion and search features (recommended) you'll need [ripgrep](https://github.com/BurntSushi/ripgrep) to be installed and on your `$PATH`.
  See [ripgrep#installation](https://github.com/BurntSushi/ripgrep) for install options.
- If you using WSL, you'll need [wsl-open](https://gitlab.com/4U6U57/wsl-open)

Search functionality (e.g. via the `:ObsidianSearch` and `:ObsidianQuickSwitch` commands) also requires [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) or one of the `fzf` alternatives (see [plugin dependencies](#plugin-dependencies) below).

### Install and configure

To configure obsidian.nvim you just need to call `require("obsidian").setup({ ... })` with the desired options.
Here are some examples using different plugin managers. The full set of [plugin dependencies](#plugin-dependencies) and [configuration options](#configuration-options) are listed below.

#### Using [`lazy.nvim`](https://github.com/folke/lazy.nvim)

```lua
return {
  "epwalsh/obsidian.nvim",
  version = "*",  -- recommended, use latest release instead of latest commit
  lazy = true,
  event = {
    -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand'.
    -- E.g. "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/**.md"
    "BufReadPre path/to/my-vault/**.md",
    "BufNewFile path/to/my-vault/**.md",
  },
  dependencies = {
    -- Required.
    "nvim-lua/plenary.nvim",

    -- see below for full list of optional dependencies 👇
  },
  opts = {
    workspaces = {
      {
        name = "personal",
        path = "~/vaults/personal",
      },
      {
        name = "work",
        path = "~/vaults/work",
      },
    },

    -- see below for full list of options 👇
  },
}
```

#### Using [`packer.nvim`](https://github.com/wbthomason/packer.nvim)

```lua
use({
  "epwalsh/obsidian.nvim",
  tag = "*",  -- recommended, use latest release instead of latest commit
  requires = {
    -- Required.
    "nvim-lua/plenary.nvim",

    -- see below for full list of optional dependencies 👇
  },
  config = function()
    require("obsidian").setup({
      workspaces = {
        {
          name = "personal",
          path = "~/vaults/personal",
        },
        {
          name = "work",
          path = "~/vaults/work",
        },
      },

      -- see below for full list of options 👇
    })
  end,
})
```

### Plugin dependencies

The only required plugin dependency is [plenary.nvim](https://github.com/nvim-lua/plenary.nvim), but there are a number of optional dependencies that enhance the obsidian.nvim experience:

- [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter): for base markdown syntax highlighting. See [syntax highlighting](#syntax-highlighting) for more details.
- [hrsh7th/nvim-cmp](https://github.com/hrsh7th/nvim-cmp): for completion of note references.
- [nvim-telescope/telescope.nvim](https://github.com/nvim-telescope/telescope.nvim): for search and quick-switch functionality.
- [ibhagwan/fzf-lua](https://github.com/ibhagwan/fzf-lua): an alternative to telescope for search and quick-switch functionality.
- [junegunn/fzf](https://github.com/junegunn/fzf) and [junegunn/fzf.vim](https://github.com/junegunn/fzf.vim): another alternative to telescope for search and quick-switch functionality.
- [godlygeek/tabular](https://github.com/godlygeek/tabular) and [preservim/vim-markdown](https://github.com/preservim/vim-markdown): matching rules, mappings, and an alternative to nvim-treesitter for syntax highlighting (see [syntax highlighting](#syntax-highlighting) for more details).

If you choose to use any of these you should include them in the "dependencies" or "requires" field of the obsidian.nvim plugin spec for your package manager.

### Configuration options

This is a complete list of all of the options that can be passed to `require("obsidian").setup()`:

```lua
{
  -- Optional, and for backward compatibility. Setting this will use it as the default workspace
  -- dir = "~/vaults/other",
  -- Optional, list of vault names and paths.
  workspaces = {
    {
      name = "personal",
      path = "~/vaults/personal",
    },
    {
      name = "work",
      path = "~/vaults/work",
    },
  },

  -- Optional, set to true to use the current directory as a vault; otherwise,
  -- the first workspace is opened by default
  detect_cwd = false,

  -- Optional, if you keep notes in a specific subdirectory of your vault.
  notes_subdir = "notes",

  -- Optional, set the log level for obsidian.nvim. This is an integer corresponding to one of the log
  -- levels defined by "vim.log.levels.*" or nil, which is equivalent to DEBUG (1).
  log_level = vim.log.levels.DEBUG,

  daily_notes = {
    -- Optional, if you keep daily notes in a separate directory.
    folder = "notes/dailies",
    -- Optional, if you want to change the date format for the ID of daily notes.
    date_format = "%Y-%m-%d",
    -- Optional, if you want to change the date format of the default alias of daily notes.
    alias_format = "%B %-d, %Y",
    -- Optional, if you want to automatically insert a template from your template directory like 'daily.md'
    template = nil
  },

  -- Optional, completion.
  completion = {
    -- If using nvim-cmp, otherwise set to false
    nvim_cmp = true,
    -- Trigger completion at 2 chars
    min_chars = 2,
    -- Where to put new notes created from completion. Valid options are
    --  * "current_dir" - put new notes in same directory as the current buffer.
    --  * "notes_subdir" - put new notes in the default notes subdirectory.
    new_notes_location = "current_dir",

    -- Whether to add the output of the node_id_func to new notes in autocompletion.
    -- E.g. "[[Foo" completes to "[[foo|Foo]]" assuming "foo" is the ID of the note.
    prepend_note_id = true
  },

  -- Optional, key mappings.
  mappings = {
    -- Overrides the 'gf' mapping to work on markdown/wiki links within your vault.
    ["gf"] = {
      action = function()
        return require("obsidian").util.gf_passthrough()
      end,
      opts = { noremap = false, expr = true, buffer = true },
    },
  },

  -- Optional, customize how names/IDs for new notes are created.
  note_id_func = function(title)
    -- Create note IDs in a Zettelkasten format with a timestamp and a suffix.
    -- In this case a note with the title 'My new note' will given an ID that looks
    -- like '1657296016-my-new-note', and therefore the file name '1657296016-my-new-note.md'
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
  end,

  -- Optional, set to true if you don't want obsidian.nvim to manage frontmatter.
  disable_frontmatter = false,

  -- Optional, alternatively you can customize the frontmatter data.
  note_frontmatter_func = function(note)
    -- This is equivalent to the default frontmatter function.
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

  -- Optional, for templates (see below).
  templates = {
    subdir = "templates",
    date_format = "%Y-%m-%d",
    time_format = "%H:%M",
    -- A map for custom variables, the key should be the variable and the value a function
    substitutions = {}
  },

  -- Optional, customize the backlinks interface.
  backlinks = {
    -- The default height of the backlinks pane.
    height = 10,
    -- Whether or not to wrap lines.
    wrap = true,
  },

  -- Optional, by default when you use `:ObsidianFollowLink` on a link to an external
  -- URL it will be ignored but you can customize this behavior here.
  follow_url_func = function(url)
    -- Open the URL in the default web browser.
    vim.fn.jobstart({"open", url})  -- Mac OS
    -- vim.fn.jobstart({"xdg-open", url})  -- linux
  end,

  -- Optional, set to true if you use the Obsidian Advanced URI plugin.
  -- https://github.com/Vinzent03/obsidian-advanced-uri
  use_advanced_uri = false,

  -- Optional, set to true to force ':ObsidianOpen' to bring the app to the foreground.
  open_app_foreground = false,

  -- Optional, by default commands like `:ObsidianSearch` will attempt to use
  -- telescope.nvim, fzf-lua, and fzf.vim (in that order), and use the
  -- first one they find. By setting this option to your preferred
  -- finder you can attempt it first. Note that if the specified finder
  -- is not installed, or if it the command does not support it, the
  -- remaining finders will be attempted in the original order.
  finder = "telescope.nvim",

  -- Optional, sort search results by "path", "modified", "accessed", or "created".
  -- The recommend value is "modified" and `true` for `sort_reversed`, which means, for example `:ObsidianQuickSwitch`
  -- will show the notes sorted by latest modified time
  sort_by = "modified",
  sort_reversed = true,

  -- Optional, determines whether to open notes in a horizontal split, a vertical split,
  -- or replacing the current buffer (default)
  -- Accepted values are "current", "hsplit" and "vsplit"
  open_notes_in = "current",

  -- Optional, configure additional syntax highlighting.
  syntax = {
    enable = true,  -- set to false to disable
    chars = {
      todo = "󰄱",  -- change to "☐" if you don't have a patched font
      done = "",  -- change to "✔" if you don't have a patched font
    }
  },

  -- Optional, set the YAML parser to use. The valid options are:
  --  * "native" - uses a pure Lua parser that's fast but potentially misses some edge cases.
  --  * "yq" - uses the command-line tool yq (https://github.com/mikefarah/yq), which is more robust
  --    but much slower and needs to be installed separately.
  -- In general you should be using the native parser unless you run into a bug with it, in which
  -- case you can temporarily switch to the "yq" parser.
  yaml_parser = "native",
}
```

### Notes on configuration

#### Completion

obsidian.nvim will set itself up as an nvim-cmp source automatically when you enter a markdown buffer within your vault directory, you do **not** need to specify this plugin as a cmp source manually.

#### Syntax highlighting

If you're using [nvim-treesitter](https://github.com/nvim-treesitter/nvim-treesitter/blob/master/README.md) you're configuration should include both "markdown" and "markdown_inline" sources:

```lua
require("nvim-treesitter.configs").setup({
  ensure_installed = { "markdown", "markdown_inline", ... },
  highlight = {
    enable = true,
  },
})
```

If you use `vim-markdown` you'll probably want to disable its frontmatter syntax highlighting (`vim.g.vim_markdown_frontmatter = 1`) which I've found doesn't work very well.

#### Note naming and location

The `notes_subdir` and `note_id_func` options are not mutually exclusive. You can use them both. For example, using a combination of both of the above settings, a new note called "My new note" will assigned a path like `notes/1657296016-my-new-note.md`.

#### `gf` passthrough

If you want the `gf` passthrough functionality but you've already overridden the `gf` keybinding, just change your `gf` mapping definition to something like this:

```lua
vim.keymap.set("n", "gf", function()
  if require("obsidian").util.cursor_on_markdown_link() then
    return "<cmd>ObsidianFollowLink<CR>"
  else
    return "gf"
  end
end, { noremap = false, expr = true })
```

Then make sure to comment out the `gf` keybinding in your obsidian.nvim config:

```lua
mappings = {
  -- ["gf"] = ...
},
```

Or alternatively you could map obsidian.nvim's follow functionality to a different key:

```lua
mappings = {
  ["fo"] = {
    action = function()
      return require("obsidian").util.gf_passthrough()
    end,
    opts = { noremap = false, expr = true, buffer = true },
  },
},
```

### Using templates

To insert a template, run the command `:ObsidianTemplate`. This will open [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) or one of the `fzf` alternatives and allow you to select a template from the templates folder. Select a template and hit `<CR>` to insert. Substitution of `{{date}}`, `{{time}}`, and `{{title}}` is supported.

For example, with the following configuration

```lua
{
  -- other fields ...

  templates = {
      subdir = "my-templates-folder",
      date_format = "%Y-%m-%d-%a",
      time_format = "%H:%M",
  },
}
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

You can also define custom template substitutions with the configuration field `templates.substitutions`. For example, to automatically substitute the template variable `{{yesterday}}` when inserting a template, you could add this to your config:

```lua
{
-- other fields ...
templates = {
  substitutions = {
    yesterday = function()
      return os.date("%Y-%m-%d", os.time() - 86400)
    end
  }
}
```

## Known Issues

### Configuring vault directory behind a link

If you are having issues with commands like `ObsidianOpen`, ensure that your vault is configured to use an absolute path rather than a link. If you must use a link in your configuration, make sure that the name of the vault is present in the file path of the link. For example:

```
Vault: ~/path/to/vault/parent/obsidian/
Link: ~/obsidian OR ~/parent
```

## Contributing

Please read the [CONTRIBUTING](https://github.com/epwalsh/obsidian.nvim/blob/main/.github/CONTRIBUTING.md) guide before submitting a pull request.
