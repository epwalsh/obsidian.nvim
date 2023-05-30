# Obsidian.nvim

A Neovim plugin for writing and navigating an [Obsidian](https://obsidian.md) vault, written in Lua.

Built for people who love the concept of Obsidian -- a simple, markdown-based notes app -- but love Neovim too much to stand typing characters into anything else.

*This plugin is not meant to replace Obsidian, but to complement it.* My personal workflow involves writing Obsidian notes in Neovim using this plugin, while viewing and reading them using the Obsidian app. That said, this plugin stands on its own as well. You don't necessarily need to use it alongside the Obsidian app.

## Features

- ▶️ Autocompletion for note references via [nvim-cmp](https://github.com/hrsh7th/nvim-cmp) (triggered by typing `[[`)
- 🏃 Go to a note buffer with `gf` when cursor is on a reference
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

![](https://user-images.githubusercontent.com/75107188/227362168-29ff9d4d-5b62-4aff-9442-21cd8c072d29.mp4)

## Setup

### Requirements

- NeoVim >= 0.8.0 (this plugin uses `vim.fs` which was only added in 0.8).
- If you want completion and search features (recommended) you'll also need [ripgrep](https://github.com/BurntSushi/ripgrep) to be installed and on your `$PATH`.
See [ripgrep#installation](https://github.com/BurntSushi/ripgrep) for install options.

Search functionality (e.g. via the `:ObsidianSearch` and `:ObsidianQuickSwitch` commands) also requires [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) or one of the `fzf` alternatives (see below).

### Install and configure

Using [`lazy.nvim`](https://github.com/folke/lazy.nvim), for example:

```lua
return {
  "epwalsh/obsidian.nvim",
  lazy = true,
  event = { "BufReadPre path/to/my-vault/**.md" },
  -- If you want to use the home shortcut '~' here you need to call 'vim.fn.expand':
  -- event = { "BufReadPre " .. vim.fn.expand "~" .. "/my-vault/**.md" },
  dependencies = {
    -- Required.
    "nvim-lua/plenary.nvim",

    -- Optional, for completion.
    "hrsh7th/nvim-cmp",

    -- Optional, for search and quick-switch functionality.
    "nvim-telescope/telescope.nvim",

    -- Optional, an alternative to telescope for search and quick-switch functionality.
    -- "ibhagwan/fzf-lua"

    -- Optional, another alternative to telescope for search and quick-switch functionality.
    -- "junegunn/fzf",
    -- "junegunn/fzf.vim"

    -- Optional, alternative to nvim-treesitter for syntax highlighting.
    "godlygeek/tabular",
    "preservim/vim-markdown",
  },
  opts = {
    dir = "~/my-vault",  -- no need to call 'vim.fn.expand' here

    -- Optional, if you keep notes in a specific subdirectory of your vault.
    notes_subdir = "notes",

    daily_notes = {
      -- Optional, if you keep daily notes in a separate directory.
      folder = "notes/dailies",
      -- Optional, if you want to change the date format for daily notes.
      date_format = "%Y-%m-%d"
    },

    -- Optional, completion.
    completion = {
      nvim_cmp = true,  -- if using nvim-cmp, otherwise set to false
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

    -- Optional, set to true if you don't want Obsidian to manage frontmatter.
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
      date_format = "%Y-%m-%d-%a",
      time_format = "%H:%M",
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
    use_advanced_uri = true,

    -- Optional, set to true to force ':ObsidianOpen' to bring the app to the foreground.
    open_app_foreground = false,

    -- Optional, by default commands like `:ObsidianSearch` will attempt to use
    -- telescope.nvim, fzf-lua, and fzf.nvim (in that order), and use the
    -- first one they find. By setting this option to your preferred
    -- finder you can attempt it first. Note that if the specified finder
    -- is not installed, or if it the command does not support it, the
    -- remaining finders will be attempted in the original order.
    finder = "telescope.nvim",
  },
  config = function(_, opts)
    require("obsidian").setup(opts)

    -- Optional, override the 'gf' keymap to utilize Obsidian's search functionality.
    -- see also: 'follow_url_func' config option above.
    vim.keymap.set("n", "gf", function()
      if require("obsidian").util.cursor_on_markdown_link() then
        return "<cmd>ObsidianFollowLink<CR>"
      else
        return "gf"
      end
    end, { noremap = false, expr = true })
  end,
}
```

**❗ Notes**

- Obsidian.nvim will set itself up as an nvim-cmp source automatically when you enter a markdown buffer within your vault directory, you do **not** need to specify this plugin as a cmp source manually.
- If you use `vim-markdown` you'll probably want to disable its frontmatter syntax highlighting (`vim.g.vim_markdown_frontmatter = 1`) which I've found doesn't work very well.
- The `notes_subdir` and `note_id_func` options are not mutually exclusive. You can use them both. For example, using a combination of both of the above settings, a new note called "My new note" will assigned a path like `notes/1657296016-my-new-note.md`.

### Templates support

To insert a template, run the command `:ObsidianTemplate`. This will open [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim) or one of the `fzf` alternatives and allow you to select a template from the templates folder. Select a template and hit `<CR>` to insert. Substitution of `{{date}}`, `{{time}}`, and `{{title}}` is supported. 

For example, with the following configuration

```lua
{
  -- other fields ...

  templates = {
      subdir = "my-templates-folder",
      date_format = "%Y-%m-%d-%a",
      time_format = "%H:%M"
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

### Using nvim-treesitter

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

## Known Issues 

### Configuring vault directory behind a link

If you are having issues with commands like `ObsidianOpen`, ensure that your vault is configured to use an absolute path rather than a link. If you must use a link in your configuration, make sure that the name of the vault is present in the file path of the link. For example:

```
Vault: ~/path/to/vault/parent/obsidian/
Link: ~/obsidian OR ~/parent
```
