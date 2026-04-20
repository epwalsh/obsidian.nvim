# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html) with respect to the public API, which currently includes the installation steps, dependencies, configuration, keymappings, commands, and other plugin functionality. At the moment this does _not_ include the Lua `Client` API, although in the future it will once that API stabilizes.

## Unreleased

### Added

- Added support `text/uri-list` to `ObsidianPasteImg`.

## [v3.10.0](https://github.com/obsidian-nvim/obsidian.nvim/releases/tag/v3.10.0) - 2025-04-12

### Added

- Added `opts.follow_img_func` option for customizing how to handle image paths.
- Added better handling for undefined template fields, which will now be prompted for.
- Added support for the [`snacks.picker`](https://github.com/folke/snacks.nvim/blob/main/docs/picker.md) picker
- Added support for the [`blink.cmp`](https://github.com/Saghen/blink.cmp) completion plugin.
- Added health check module
- Added a minimal sandbox script `minimal.lua`

### Changed

- Renamed `opts.image_name_func` to `opts.attachments.img_name_func`.
- Default to not activate ui render when `render-markdown.nvim` or `markview.nvim` is present
- `smart_action` shows picker for tags (`ObsidianTag`) when cursor is on a tag
- `ObsidianToggleCheckbox` now works with numbered lists
- `Makefile` is friendlier: self-documenting and automatically gets dependencies

### Fixed

- Fixed an edge case with collecting backlinks.
- Fixed typo in `ObsidianPasteImg`'s command description
- Fixed the case when `opts.attachments` is `nil`.
- Fixed bug where `ObsidianNewFromTemplate` did not respect `note_id_func`
- Fixed bug where parser treats "Nan" as a number instead of a string

## [v3.9.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.9.0) - 2024-07-11

### Added

- Added `:ObsidianTOC` command for loading the table of contents of the current note into a picker list.
- Added `:ObsidianNewFromTemplate` command. This command creates a new note from a template.

### Fixed

- Fixed bug where `opts.search_max_lines` was not propagated through some client methods.

## [v3.8.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.8.1) - 2024-06-26

### Fixed

- Removed duplicate suggestions in completion of references.

## [v3.8.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.8.0) - 2024-06-21

### Added

- Added relative to root markdown links as search pattern for backlinks.
- Added configuration option `daily_notes.default_tags` for customizing (or removing) the default tags given to new daily notes.

### Fixed

- Searching for notes by file name is case insensitive.

## [v3.7.14](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.7.14) - 2024-06-04

### Added

- Added config option `ui.max_file_length` to disable the UI for files with more than this many lines. Defaults to 5000.
- Added config option `search_max_lines` (defaults to 1000) for controlling the max number of lines read from disk from note files during certain searches.
- Added FreeBSD support to `ObsidianPasteImg` command.

### Changed

- Optimization: only show completions for blocks/anchors when prompted with `#`.

## [v3.7.13](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.7.13) - 2024-05-31

### Fixed

- Made workspace detection more robust.
- Fixed regression where frontmatter is updated in template files.
- Fixed finding backlinks with URL-encoded path references.
- Fixed using templates with frontmatter when `disable_frontmatter` is set to true. Previously the frontmatter would be removed when the template was inserted, now it will be kept unchanged.
- Add compatibility for NVIM 0.11.
- Fixed warnings when renaming a note using dry-run.
- Fixed handling check boxes with characters that have a special meaning in regular expressions (e.g. "?").
- `Client:create_note()` will always ensure the parent directory exists, even when not writing the note itself to disk, to avoid downstream issues (see #600).
- Identify `mailto:` links as URLs.

## [v3.7.12](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.7.12) - 2024-05-02

### Changed

- Renamed config field `templates.subdir` to `templates.folder` (`subdir` still supported for backwards compat).
- You can now use a templates folder outside of your vault.

## [v3.7.11](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.7.11) - 2024-04-30

### Added

- Added an optional line number argument for `util.toggle_checkbox()`, that defaults to the current line.

### Fixed

- Ensure toggle checkbox mapping uses checkbox configuration.
- Don't use last visual selection when in normal mode with `:ObsidianTags`.
- Fixed a normalization issue with windows paths.

## [v3.7.10](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.7.10) - 2024-04-19

### Fixed

- Fixed bug with OS detection introduced by 6ffd1964500d24c1adde3c88705b146d9c415207.

## [v3.7.9](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.7.9) - 2024-04-18

### Fixed

- Fixed an issue where template insertion occurred below the intended line, it now correctly inserts at the current line.
- Fixed `:ObsidianOpen` issue on WSL OS name identifier check with different release name case.
- Ensure ID of daily notes is always equal to the stem of the path.

### Changed

- Don't insert a default alias for daily notes when `daily_notes.alias_format` is `nil`.

## [v3.7.8](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.7.8) - 2024-04-09

### Fixed

- Fixed regression with toggle checkbox util/mapping.

## [v3.7.7](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.7.7) - 2024-04-05

### Fixed

- Removed excessive logging when running `:ObsidianToday` command with a defined template, resulting in cleaner output and a more streamlined user experience.

## [v3.7.6](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.7.6) - 2024-04-01

### Fixed

- Ensure fields transferred to new note when cloning from template.
- Fixed bug with YAML parser where it would fail to parse field names with spaces in them.
- Fixed bug with YAML parser where it would incorrectly identity comments.

### Added

- Added a smart action mapping on `<CR>`, that depends on the context. It will follow links or toggle checkboxes.

### Changed

- Added `order` field to `ui.checkboxes` config fields that determines the order in which the different checkbox characters are cycled through via `:ObsidianToggleCheckbox` and the smart action.

## [v3.7.5](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.7.5) - 2024-03-22

### Fixed

- Fixed bug with created new notes from `nvim-cmp` on Linux.

## [v3.7.4](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.7.4) - 2024-03-19

### Fixed

- Don't open picker for tags when there aren't any matches.
- Fixed overwriting frontmatter when creating daily note with template.
- Fixed default date format for the alias of daily notes.
- Made buffer open strategy more robust.

## [v3.7.3](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.7.3) - 2024-03-13

### Changed

- Add indicator to entries that don't exist yet in `:ObsidianDailies` picker list.

### Fixed

- Fixed `img_text_func` example in README.
- When following intra-note links, such as with a table of contents, load the note from the buffer to resolve anchor/block links instead of from file.

## [v3.7.2](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.7.2) - 2024-03-12

### Changed

- `:ObsidianNew` won't write the new note to disk, it will only populate the buffer.

### Fixed

- Fixed renaming when passing file path
- Make `Client:resolve_note` fall back to fuzzy matching when there are no exact matches.

## [v3.7.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.7.1) - 2024-03-09

### Fixed

- Fixed regression with `:ObsidianExtractNote`.
- Fixed regression of edge case when paths are passed to `:ObsidianNew`.
- Don't write frontmatter when frontmatter table is empty.

## [v3.7.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.7.0) - 2024-03-08

There's a lot of new features and improvements here that I'm really excited about 🥳 They've improved my workflow a ton and I hope they do for you too. To highlight the 3 biggest additions:

1. 🔗 Full support for header anchor links and block links! That means both for following links and completion of links. Various forms of anchor/block links are support. Here are a few examples:

   - Typical Obsidian-style wiki links, e.g. `[[My note#Heading 1]]`, `[[My note#Heading 1#Sub heading]]`, `[[My note#^block-123]]`.
   - Wiki links with a label, e.g. `[[my-note#heading-1|Heading 1 in My Note]]`.
   - Markdown links, e.g. `[Heading 1 in My Note](my-note.md#heading-1)`.

   We also support links to headers within the same note, like for a table of contents, e.g. `[[#Heading 1]]`, `[[#heading-1|Heading]]`, `[[#^block-1]]`.

2. 📲 A basic callback system to let you easily customize obisidian.nvim's behavior even more. There are currently 4 events: `post_setup`, `enter_note`, `pre_write_note`, and `post_set_workspace`. You can define a function for each of these in your config.
3. 🔭 Improved picker integrations (especially for telescope), particular for the `:ObsidianTags` command. See <https://github.com/epwalsh/obsidian.nvim/discussions/450> for a demo.

Full changelog below 👇

### Added

- Added a configurable callback system to further customize obsidian.nvim's behavior. Callbacks are defined through the `callbacks` field in the config:

  ```lua
  callbacks = {
    -- Runs at the end of `require("obsidian").setup()`.
    ---@param client obsidian.Client
    post_setup = function(client) end,

    -- Runs anytime you enter the buffer for a note.
    ---@param client obsidian.Client
    ---@param note obsidian.Note
    enter_note = function(client, note) end,

    -- Runs anytime you leave the buffer for a note.
    ---@param client obsidian.Client
    ---@param note obsidian.Note
    leave_note = function(client, note) end,

    -- Runs right before writing the buffer for a note.
    ---@param client obsidian.Client
    ---@param note obsidian.Note
    pre_write_note = function(client, note) end,

    -- Runs anytime the workspace is set/changed.
    ---@param client obsidian.Client
    ---@param workspace obsidian.Workspace
    post_set_workspace = function(client, workspace) end,
  }
  ```

- Added configuration option `note_path_func(spec): obsidian.Path` for customizing how file names for new notes are generated. This takes a single argument, a table that looks like `{ id: string, dir: obsidian.Path, title: string|? }`, and returns an `obsidian.Path` object. The default behavior is equivalent to this:

  ```lua
  ---@param spec { id: string, dir: obsidian.Path, title: string|? }
  ---@return string|obsidian.Path The full path to the new note.
  note_path_func = function(spec)
    local path = spec.dir / tostring(spec.id)
    return path:with_suffix ".md"
  end
  ```

- Added config option `picker.tag_mappings`, analogous to `picker.note_mappings`.
- Added `log` field to `obsidian.Client` for easier access to the logger.
- Added ability to follow anchor and block links.
- Added completion support for anchor and block links. Note that this requires you to update your `wiki_link_func` and `markdown_link_func` in your config to handle anchors and blocks. See the configuration example in the README.
- You can set `wiki_link_func` to a one of the following strings to use a builtin function:
  - `"use_alias_only"`, e.g. `[[Foo Bar]]`
  - `"prepend_note_id"`, e.g. `[[foo-bar|Foo Bar]]`
  - `"prepend_note_path"`, e.g. `[[foo-bar.md|Foo Bar]]`
  - `"use_path_only"`, e.g. `[[foo-bar.md]]`
- Added command `:ObsidianDailies` for opening a picker list of daily notes.

### Changed

- Renamed config option `picker.mappings` to `picker.note_mappings`.

### Fixed

- Fixed consistency in frontmatter between opening daily notes with or without a template
- Fixed issue with `:ObsidianOpen` on windows.
- Respect telescope.nvim themes configured by user.
- Make tags completion more efficient (less CPU time!).
- Added file/directory completion to image name prompt from `:ObsidianPasteImg`.
- Handle prompt cancellation gracefully.
- Fix lua diagnostic warnings about missing fields in the configuration.
- Made `Client:resolve_note()` more robust to when the search term is a file name.

## [v3.6.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.6.1) - 2024-02-28

### Added

- Added configuration option `attachments.confirm_img_paste: boolean` to allow users to control whether they are prompted for confirmation when pasting an image.

### Fixed

- Only show unique links in buffer with `:ObsidianLinks`.

## [v3.6.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.6.0) - 2024-02-27

Various bug fixes and Lua API improvements.

### Changed

- Deprecated `Client:new_note()` in favor of `Client:create_note()`.
- Changed API of `Client:apply_async()` to take a table of options in place of the 2nd and 3rd arguments.
- Changed API of `Note:save()` to take a table of options.

### Fixed

- Ignore things that looks like tags within code blocks.
- Fixed bug with pasting images.

## [v3.5.3](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.5.3) - 2024-02-25

### Fixed

- Fixed regression with cloning templates where a directory was created instead of a file.

## [v3.5.2](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.5.2) - 2024-02-25

### Fixed

- Fixed os selection in `ObsidianOpen` command.

## [v3.5.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.5.1) - 2024-02-24

Minor internal improvements.

## [v3.5.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.5.0) - 2024-02-23

### Added

- Added CI testing for Windows.

### Changed

- (internal) Replaced all uses of `plenary.path` with a custom `obsidian.path` class that stays more true to the Python pathlib API and should be more reliable across operating systems.

### Fixed

- If you have `new_notes_location="current_dir"` but you're not inside of a vault, the new note will be created in your vault instead of the current (buffer) directory.
- Fixed a regression where note titles were not considered for autocomplete when the title was not part of the frontmatter (only an H1 header).
- Escaped tags (e.g. `\#notatag`) will no longer come up in tag searches.

## [v3.4.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.4.1) - 2024-02-22

### Fixed

- Ensure old buffer is removed when renaming current note.

## [v3.4.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.4.0) - 2024-02-21

### Added

- Added client methods `Client:find_backlinks()` and `Client:find_backlinks_async()`.
- Added client method `Client:open_note()` for open a note in a buffer.

### Changed

- `:ObsidianBacklinks` and `:ObsidianTags` now open your preferred picker instead of a separate buffer.
- Improved `cmp_obsidian` doc/preview text.

### Fixed

- Fixed `:ObsidianExtractNote` when usual visual line selection ("V").
- Fixed "hsplit" open strategy.

## [v3.3.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.3.1) - 2024-02-18

### Fixed

- Fixed inserting templates when the templates directory structure is nested.

## [v3.3.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.3.0) - 2024-02-17

### Added

- Support for `file:/` and `file:///` Urls.
- Added configuration options `wiki_link_func` and `markdown_link_func` for customizing how links are formatted.

### Fixed

- Urls ending in `/` were not detected.
- Fixed small bug with toggle checkbox mapping where lines that started with a wiki link or md link were misclassified.

### Changed

- Config options `completion.prepend_note_id`, `completion.prepend_note_path`, and `completion.use_path_only` are now deprecated. Please use `wiki_link_func` and `markdown_link_func` instead.
- Moved configuration option `completion.preferred_link_style` to top-level `preferred_link_style`.
- Moved configuration option `completion.new_notes_location` to top-level `new_notes_location`.

## [v3.2.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.2.0) - 2024-02-13

### Added

- Added `:ObsidianLinks` command.
- Added `:ObsidianExtractNote` command.

### Fixed

- Improved how we get visual selection for certain commands.

## [v3.1.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.1.0) - 2024-02-12

### Added

- Added descriptions to all commands.

### Changed

- Major internal refactoring / improvements for how we integrate with pickers.
- Configuration option `finder` and `finder_mappings` have been consolidated into `picker = { name: string, mappings: { ... } }`.
- When `:ObsidianWorkspace` is called without any arguments, obsidian.nvim will open your picker to select a workspace to switch to.

### Fixed

- Resolve workspace path when behind symlinks.

### Removed

- Removed support for `fzf.vim` as a picker (`fzf-lua` is still supported).

## [v3.0.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v3.0.0) - 2024-02-09

⚠️ POTENTIALLY BREAKING CHANGES! PLEASE READ BELOW ⚠️

### Added

- Added support for "dynamic" workspaces where the workspace `path` field is a function instead of a `string` / `Path`. See [PR #366](https://github.com/epwalsh/obsidian.nvim/pull/366).

### Changed

- Changed behavior of workspace detection. When you have multiple workspaces configured, obsidian.nvim will now automatically switch workspaces when you open a buffer in a different workspace. See [PR #366](https://github.com/epwalsh/obsidian.nvim/pull/366).
- Various changes to the `Workspace` Lua API. See [PR #366](https://github.com/epwalsh/obsidian.nvim/pull/366).
- Changed the behavior of the default frontmatter function so it no longer automatically adds the title of the note as an alias. See the `note_frontmatter_func` example in the README if you want the old behavior.

### Removed

- Removed configuration option `detect_cwd`. This wasn't well-defined before and is no longer relevant with the new workspace detection behavior. See [PR #366](https://github.com/epwalsh/obsidian.nvim/pull/366).

### Fixed

- Fixed two bugs with creating new notes through `:ObsidianFollowLink` (and `gf`) where it wouldn't respect the `completion.new_notes_location` settings, and wouldn't respect paths in certain formats.

## [v2.10.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.10.0) - 2024-02-05

### Added

- Added note field `Note.title` to provide more useful info for `note_frontmatter_func`.
- Added client method `Client:format_link()` for creating markdown / wiki links.
- Added telescope action to insert a note link in certain finder scenarios.

### Fixed

- Fixed parsing header with trailing whitespace (<https://github.com/epwalsh/obsidian.nvim/issues/341#issuecomment-1925445271>).

## [v2.9.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.9.0) - 2024-01-31

### Added

- Added configuration option `image_name_func: (fun(): string)|?` for customizing the default image name/prefix when pasting images via `:ObsidianPasteImg`.
- Added client method `Client:current_note()` to get the note corresponding to the current buffer.
- Added client method `Client:list_tags()` for listing all tags in the vault, along with async version `Client:list_tags_async(callback: fun(tags: string[]))`.
- Added note method `Note.add_field(key: string, value: any)` to add/update an additional field in the frontmatter.
- Added note method `Note.get_field(key: string)`.
- Added note method `Note.save_to_buffer(bufnr: integer|?, frontmatter: table|?)` for saving the frontmatter to a buffer.

### Changed

- `:ObsidianTags` command can take a visual selection or look for a tag under the cursor instead of explicitly provided arguments.

## [v2.8.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.8.0) - 2024-01-26

### Added

- Added `:ObsidianTags` command.

### Changed

- Changed API of client methods `Client:find_tags()` and `Client:find_tags_async()`. The return value (or value passed to the callback) is now a list of objects representing the location of tags found. These objects have the following fields: `tag: string`, `path: string|Path`, `line: integer`.

### Fixed

- Fixed a YAML parsing issue with unquoted URLs in an array item.
- Fixed an issue on Windows when cloning a template into a new note. The root cause was this bug in plenary: <https://github.com/nvim-lua/plenary.nvim/issues/489>. We've added a work-around.

## [v2.7.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.7.1) - 2024-01-23

### Fixed

- Fixed powershell command for `:ObsidianPasteImg` in wsl
- Fixed bug with YAML parser that led to incorrectly parsing double-quoted strings with escaped quotes inside.

## [v2.7.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.7.0) - 2024-01-19

### Fixed

- Fixed fzf-lua implementation of insert template and linking.
- Fixed minor bug with `cmp_obsidian_new`.

### Added

- Added support for parsing single aliases specified as a string, not a list, in frontmatter. E.g. `aliases: foo` as opposed to `aliases: [foo]`. Though when the frontmatter is saved it will always be saved as a YAML list, so `aliases: foo` gets saved as `aliases: [foo]` (or equivalent).
- Added `Client` methods `Client:apply_async()` and `Client:apply_async_raw()`.

## [v2.6.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.6.1) - 2024-01-16

### Added

- Added extmarks that conceal "-", "\*", or "+" with "•" by default. This can turned off by setting `.ui.bullets` to `nil` in your config.

### Fixed

- Fixed bug with resolving the vault-relative path when the vault is behind a symlink.
- Fixed bug with completion after changing workspaces.

## [v2.6.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.6.0) - 2024-01-09

### Changed

- Creating new notes via `:ObsidianFollowLink` now matches the behavior of `:ObsidianLinkNew`, where the new note will be placed in the same directory as the current buffer note. This doesn't affect you if you use a flat directory structure for all of your notes.
- `:ObsidianRename` will prompt for the new title/ID/path if not given as an argument.

### Added

- `:ObsidianFollowLink` now takes an optional "open strategy" argument. For example `:ObsidianFollowLink vsplit` or `:ObsidianFollowLink vsp` opens the note in a vertical split.
- Added client method `Client:command(...)` for running commands directly. For example: `:lua require("obsidian").get_client():command("ObsidianNew", { args = "Foo" })`.
- Added vim docs for the Lua API. See `:help obsidian-api` or `:help obsidian.Client`.
- Added the option to create notes with a mapping from the telescope finder with `:ObsidianQuickSwitch` and `:ObsidianSearch`.
- Added client methods `Client:find_files()` and `Client:find_files_async()` for finding non-markdown files in the vault.

### Fixed

- Fixed bug with YAML encoder where strings with a colon followed by whitespace were not quoted.
- Parent directories are created when using a template (for example, for daily notes).
- Fixed bug with finder/picker in `:ObsidianLink` when current working directory is not vault root.
- `:ObsidianFollowLink` will now work when the link contains spaces encoded with "%20" (as they are in URLs) to match the behavior of the Obsidian app.

## [v2.5.3](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.5.3) - 2024-01-02

### Fixed

- Removed some errant print statements.

## [v2.5.2](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.5.2) - 2024-01-02

### Fixed

- Fixed bug with `Client:resolve_note()` that missed checking the parent directory of the current buffer.
- Made gathering backlinks work with links of different forms, like Markdown or Wiki with just an alias.

## [v2.5.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.5.1) - 2024-01-01

### Fixed

- Fixed a bug on Linux where we call a restricted function in an async context.
- Fixed bug with resolving relative path in vault when path is already relative.

## [v2.5.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.5.0) - 2023-12-30

### Added

- Added Lua API methods `Client:set_workspace(workspace: obsidian.Workspace)` and `Client:switch_workspace(workspace: string|obsidian.Workspace)`.
- Added the ability to override settings per workspace by providing the `overrides` field in a workspace definition. For example:

  ```lua
  require("obsidian").setup {
    workspaces = {
      {
        name = "personal",
        path = "~/vaults/personal",
      },
      {
        name = "work",
        path = "~/vaults/work",
        -- Optional, override certain settings.
        overrides = {
          notes_subdir = "notes",
        },
      },
    },

    -- ... other options ...
  }
  ```

### Fixed

- Made workspace API more robust.
- Template substitutions are done lazily and only generated once per line.
- Fixed search functionality with `fzf.vim` as a finder when the vault name contains characters that need to be escaped, such as spaces.
- Fixed a bug with ext marks for references inside of frontmatter.

## [v2.4.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.4.0) - 2023-12-19

### Added

- Added support for [Mini.Pick](https://github.com/echasnovski/mini.pick) as another alternative to telescope.nvim.

### Fixed

- Templates directory location follows the workspace now.
- Fixed bug with completion when `min_chars = 1` and you start typing an empty check box.

### Changed

- Replaced `Client.templates_dir` field with `Client:templates_dir()` function.
- `:ObsidianLink` will now open your finder when the initial search comes up empty or ambiguous.
- Improve logging when `client:vault_relative_path()` fails in `cmp_obsidian_new`.

## [v2.3.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.3.1) - 2023-12-03

### Added

- Added `Client:update_ui()` method.
- Assigned enum type `obsidian.config.OpenStrategy` to `config.open_notes_in`.
- `disable_frontmatter` now can be a function taking the filename of a note (relative to the vault root) to determine whether the note's frontmatter can be managed by obsidian.nvim or not.

### Changed

- `Client:daily_note_path()` now takes a datetime integer instead of an ID string.
- Template substitutions can now handle multiple lines, i.e. you can define custom substitutions that return a string with new line characters.
- The "vsplit" and "hsplit" open strategies for `config.open_notes_in` will now only open a vertical/horizontal split if the window is not already split.

### Fixed

- Fixed URL incorrect in README.md
- Fixed autocmd registration for workspaces.

## [v2.3.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.3.0) - 2023-11-28

### Added

- The command `:ObsidianFollowLink` and the default `gf` pass-through mapping will now follow links to local files that are not notes.
- Added documentation to completion items.

### Changed

- Changed API of `Client` search methods to take a class of options.
- Loading notes when gathering backlinks is now done concurrently.

### Fixed

- Made tags autocompletion more robust by ignoring anchor links (which look like tags) and searching case-insensitive.

## [v2.2.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.2.0) - 2023-11-23

### Added

- Added completion for tags.
- Added extmarks for tags.
- Added method `get_client()` to get the current obsidian client instance. For example: `:lua print(require("obsidian").get_client():new_note_id("Foo"))`
- Added client methods `find_tags()` and `find_tags_async()`.
- Added extmarks for inline highlighting, e.g. `==highlight this text!==`.

### Changed

- In the backlinks view you can now hit `<ENTER>` within a group to toggle the folding.
- `:ObsidianBacklinks` will now maintain focus to the current window.
- `:ObsidianBacklinks` will now respect the `sort_by` and `sort_reversed` configuration options.

### Fixed

- Removed UI update delay on `BufEnter`.
- Fixed completion bug ([#243](https://github.com/epwalsh/obsidian.nvim/issues/243))

## [v2.1.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.1.1) - 2023-11-20

### Fixed

- Fixed some edge cases with finding references via patterns.

## [v2.1.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.1.0) - 2023-11-18

**Highlights:**

Completion for markdown-style links in addition to Wiki links + more ways to customize how Wiki links are completed! 🔥
We also added support for pasting images into notes with the new command `:ObsidianPasteImg` 📷

### Added

- Added `:ObsidianPasteImg` for pasting images from the clipboard into notes. See the `attachments` configuration option for customizing the behavior of this command. Inspired by [md-img-paste.vim](https://github.com/ferrine/md-img-paste.vim) and [clipboard-image.nvim](https://github.com/ekickx/clipboard-image.nvim).
- Added `completion.prepend_note_path` and `completion.use_path_only` options (mutually exclusive with each other and `completion.prepend_note_id`).
- Added support for completing traditional markdown links instead of just wiki links.

### Changed

- Renamed `opts.ui.tick` to `opts.ui.update_debounce`, but the `tick` field will still be read for backwards compatibility.
- `:ObsidianOpen` will now open wiki links under the cursor instead of always opening the note of the current buffer.
- `:ObsidianBacklinks` will now show backlinks for the note of a wiki link under the cursor instead of always showing backlinks for the note of the current buffer.

### Fixed

- Ensure commands available across all buffers, not just note buffers in the vault.

## [v2.0.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v2.0.0) - 2023-11-16

**Highlights:**

The long awaited `:ObsidianRename` command is here along with big improvements to our syntax add-ons! Wiki links, external links, and checklists look much better now out-of-the-box and can be easily customized! 🥳

I recommend you use treesitter as a base markdown syntax highlighter, but obsidian.nvim is also compatible with traditional regex syntax highlighting.

### Added

- Added `:ObsidianRename` command.
- Added `:ObsidianTomorrow` command.
- Added optional offset to `:ObsidianToday` command. For example: `:ObsidianToday -1` to go to yesterday's daily note.
- Added configuration option `ui` for customizing obsidian.nvim's additional syntax highlighting and extmarks.
- Improved default additional syntax highlighting / concealing.
- Added default mapping `<leader>ch` for toggling check-boxes.

### Fixed

- Ensure additional syntax highlighting works with latest treesitter.

## [v1.16.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.16.1) - 2023-11-11

### Changed

- Refactored commands module, improved `:ObsidianCheck`.

### Fixed

- Fixed compatibility issue with older versions of Telescope.

## [v1.16.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.16.0) - 2023-11-10

Major internal refactoring to bring performance improvements through async execution of search/find functionality, and general robustness improvements. 🏎️🤠

### Added

- Added `obsidian.async` module for internal use.

### Changed

- Re-implemented the native Lua YAML parser (`obsidian.yaml.native`). This should be faster and more robust now.
- Re-implemented search/find functionality to utilize concurrency via `obsidian.async` and `plenary.async` for big performance gains.
- Made how run shell commands more robust, and we also log stderr lines now.
- Submodules imported lazily.
- Changes to internal module organization.

### Fixed

- Fixed a completion bug (#212).
- Fixed a bug where the frontmatter of daily note template would be overwritten upon inserting the template.
- Skip templates directory when searching for notes.
- Fixed a compatibility issue with the latest `fzf.vim` and made running finders more robust in general.

### Removed

- Removed the `overwrite_mappings` option.

## [v1.15.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.15.0) - 2023-10-20

### Added

- The `overwrite_mappings` option, which sets the mappings in the config even if they already exist
- Added support for multiple vaults (#128)
- Added command to switch between vaults (#60)
- Added configuration option `yaml_parser` (a string value of either "native" or "yq") to change the YAML parser.

### Fixed

- Eliminated silent runtime errors on validation errors in `note.from_lines`.
- Fixed parsing YAML boolean values in frontmatter.
- Fixed parsing implicit null values in YAML frontmatter.

## [v1.14.2](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.14.2) - 2023-09-25

### Fixed

- Updated recommendation for how to configure mappings.

## [v1.14.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.14.1) - 2023-09-22

### Fixed

- Added back missing `util.find()` function.

## [v1.14.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.14.0) - 2023-09-22

### Added

- Added config option `sort_by` to allow setting search result order by "path", "modified", "accessed", or "created".
- Added config option `sort_reversed` to allow setting search result sort reversed order. The default is `true`.
- Added an extra option for daily notes to allow changing the default title from "%B %-d, %Y" to other strings.
- Added a configuration option `daily_notes.template` for automatically using a specific template when creating a new daily note.
- Adding a configuration option `templates.substitutions` for defining custom template substitutions.

### Changed

- Minor change to the behavior of `:ObsidianNew`. The argument to this command can be in one of 3 different forms which determine the behavior of the command:
  1. A raw title without any path components, e.g. `:ObsidianNew Foo`. In this case the command will pass the title to the `note_id_func` and put the note in the default location.
  2. A title prefixed by a path component, e.g. `:ObsidianNew notes/Foo`. In this case the command will pass the title "Foo" to the `note_id_func` and put the note in the directory of the path prefix "notes/".
  3. An exact path, e.g. `:ObsidianNew notes/foo.md`. In this case the command will put the new note at the path given and the title will be inferred from the filename ("foo").

### Fixed

- A bug when following links when headers have a space.
- Fixed `ObsidianFollowLink` when the note path contains a block link (e.g. `[[foo#^Bar]]`).
- Fixed `:ObsidianOpen` doesn't work in WSL2
  - Use [wsl-open](https://gitlab.com/4U6U57/wsl-open)
- Improved completion start pattern to trigger anytime `[[` is typed.
- Fixed issue with parsing inline lists in YAML frontmatter when the items aren't wrapped in quotes.

## [v1.13.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.13.0) - 2023-08-24

### Added

- Added option `prepend_note_id` to allow disabling id generation for new notes.
- Added `mappings` configuration field.
- Added `open_notes_in` configuration field
- Added `backlinks` options to the config. The default is

  ```lua
  backlinks = {
    -- The default height of the backlinks pane.
    height = 10,
    -- Whether or not to wrap lines.
    wrap = true,
  },
  ```

### Changed

- (internal) Refactored daily note creation.
- obsidian.nvim will now automatically enable the 'gf' passthrough keybinding within your vault unless the 'gf' keybinding has already been overridden by you or another plugin or you override the 'mappings' configuration field.

### Fixed

- Fixed `template_pattern` not escaping special characters.
- Fixed new notes not getting passed args correctly
- Fixed `:ObsidianOpen` when note is in a subdirectory with the same name as the root vault directory.
- Fixed issue where `note_frontmatter_func` option was not used when creating new notes.

## [v1.12.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.12.0) - 2023-07-15

### Added

- Allow user to supply an argument to `ObsidianTemplate` to select a template.

### Changed

- Renamed Lua function `command.insert_template()` to `command.template()` and split the template insert script into a separate function `util.insert_template()`.
- Added `log_level` configuration option to suspend notifications.
- Added `completion.new_notes_location` configuration option to specify where newly created notes are placed in completion.

### Fixed

- Fixed creating new notes when the title of the note contains a path. Now that path will always be treated as relative to the vault, not the `notes_subdir`.
- Fixed `ObsidianFollowLink` when the note path contains a header link (e.g. `[[foo#Bar]]`).

## [v1.11.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.11.0) - 2023-06-09

### Added

- Added configuration option `daily_notes.date_format` (a string) to customize the date format of daily notes.

### Fixed

- Disabled managed frontmatter for files in the templates subdirectory.
- A bug when `disable_frontmatter` is ignored for `ObsidianToday` and `ObsidianYesterday`.
- A bug with `ObsidianTemplate` when using Telescope

## [v1.10.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.10.0) - 2023-05-11

### Added

- Report errors finding vault from `:ObsidianCheckHealth`.
- Added `finder` option for choosing a preferred finder backend.

### Fixed

- Removed annoying "skipped updating frontmatter" message on file write.

## [v1.9.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.9.0) - 2023-04-22

### Added

- Added `open_app_foreground` option to open Obsidian.app in foreground on macOS.
- Added `:ObsidianTemplate` to insert a template, configurable using a `templates` table passed to `setup()`.
- Added support for following links in markdown format
- Added `follow_url_func` option to customize behaviour of following URLs

### Changed

- Use `vim.notify` to echo log messages now.

### Fixed

- Gracefully handle invalid aliases / tags in frontmatter (i.e. values that aren't strings). We'll warn about them and ignore the invalid values.
- Fixed `nvim-cmp` completion for notes that have no `aliases` specified.
- `nvim-cmp` completion will search based on file names now too, not just contents.
- Fixed bug when `nvim-cmp` is not installed.
- Workaround error which prevented users from using `ObsidianOpen` when vault path was configured behind a link
- Detect URLs when following links and ignore them by default.

## [v1.8.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.8.0) - 2023-02-16

### Changed

- [`lua-yaml`](https://github.com/exosite/lua-yaml) no-longer bundled as a git submodule. Code from that project has been copied and modified into it's own Lua submodule of `obsidian`.
- (BREAKING) 'nvim-lua/plenary.nvim' is no-longer bundled, so must be explicitly installed (e.g. Plug 'nvim-lua/plenary.nvim' in your `init.nvim`).

### Fixed

- Fixed a bug where creating a new note with `nvim-cmp` completion
  would cause `nvim-cmp` to stop working.
- Fixed bug where `disable_frontmatter` setting would be ignored for `:ObsidianNew` command.

## [v1.7.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.7.0) - 2023-02-02

### Added

- Added support for [fzf-lua](https://github.com/ibhagwan/fzf-lua) as one of the possible fallbacks for the `:ObsidianQuickSwitch` command.
- Added `:ObsidianQuickSwitch` to fuzzy-find a note by name in telescope/fzf _a la_ <C-O> in Obsidian.
- Added support for [fzf-lua](https://github.com/ibhagwan/fzf-lua) as one of the possible fallbacks for the `:ObsidianSearch` command.
- Added `:ObsidianFollowLink` and companion function `util.cursor_on_markdown_link`
- Added `:ObsidianLink` and `:ObsidianLinkNew` commands.
- Added configuration option `disable_frontmatter` for frontmatter disabling
- Added line-navigation to `:ObsidianOpen` via the Obsidian Advanced URI plugin
- Added `:ObsidianYesterday` command to open/create the previous working day daily note

### Fixed

- Fixed bug with `Note.from_lines` where the given path would be modified in place to be relative to the root, which caused a bug in `:ObsidianFollowLink`.
- Completion for creating new notes via nvim-cmp is now aware of daily notes, so when you start typing todays date in the form of YYYY-MM-DD, you get a "Create new" completion option for today's daily note if it doesn't exist yet.
- Fixed bug where `:ObsidianOpen` blocked the NeoVim UI on Linux.
- `:ObsidianOpen` should now work on Windows.
- Fixed URL encoding of space characters for better compatibility with external applications.
- Made more robust to unexpected types in frontmatter.
- Fixed edge case where frontmatter consisting of exactly one empty field would raise an exception.
- Fixed `:ObsidianFollowLink` not creating a new note when following a dangling link; matches behavior in the official Obsidian app.
- Fixed handling spaces in configured vault directory.
- Fixed `:ObsidianFollowLink` not considering the vault's root directory.
- Fixed bug where the note ID in the YAML frontmatter wasn't updated after the file is renamed.
- Fixed `require` module name syntax; see #93 for explanation.

### Changed

- The new note completion source will now create the new note in the same directory as the current note, regardless of the `notes_subdir` setting.

## [v1.6.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.6.1) - 2022-10-17

### Fixed

- Ensured vault directory along with optional notes and daily notes subdirectories are added to vim's `path` so you can `gf` to files in those directories.

## [v1.6.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.6.0) - 2022-10-14

### Added

- Added support for arbitrary fields in YAML frontmatter.
- Added configuration option `note_frontmatter_func` for customizing the YAML frontmatter of your notes. This can be set to a function that takes a single argument - an `obsidian.Note` object - and returns a YAML-serializable table.

### Changed

- Added folding and custom highlighting to backlinks window, and fixed window height.
- When the title of a note is changed, the title will automatically be added to note's aliases in the frontmatter on save.

### Fixed

- Fixed autocomplete functionality to be less sensitive to case.
- Made YAML frontmatter dumping functionality more robust.

## [v1.5.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.5.0) - 2022-10-12

### Changed

- Improved `:ObsidianBacklinks` command to use its own buffer type instead of the location list.
  It's now more readable.
- Removed save on write for `:ObsidianNew` and `:ObsidianToday` ([#32](https://github.com/epwalsh/obsidian.nvim/pull/32)).

### Fixed

- `:ObsidianOpen` now works on Linux.

## [v1.4.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.4.0) - 2022-10-11

### Added

- Added `daily_notes` configuration options.
- Added `:ObsidianSearch` command (requires `fzf.vim` or `telescope.nvim`).

### Fixed

- Fixed a bug with `:ObsidianOpen` ([#19](https://github.com/epwalsh/obsidian.nvim/issues/19)).
- Fixed bug with creating a new note with `nvim-cmp` completion where full settings
  weren't taken into account.
- Fixed a bug with `:ObsidianBacklinks` where the paths were incorrect.

## [v1.3.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.3.0) - 2022-09-23

### Changed

- `plenary.nvim` is no longer required to be installed separately. It's now bundled as a submodule.

## [v1.2.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.2.1) - 2022-09-23

### Added

- Added setup configuration option `notes_subdir`. Use this if you want new notes to be put in a specific subdirectory of your vault.

### Changed

- Commands are no-longer setup lazily on `BufEnter` to a markdown file in your vault. Now they'll always be available.

## [v1.2.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.2.0) - 2022-09-22

### Added

- Added `:ObsidianNew` command for creating a new note with a given title.
- Added setup configuration option `note_id_func`, which can be set to a custom function for generating new note IDs. The function should take a single optional string argument, a title of the note, and return a string. The default method for generating new note IDs is to generate a Zettelkasten-like ID using a timestamp and some random letters.

## [v1.1.1](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.1.1) - 2022-08-22

### Fixed

- Fixed bug when creating new notes. Sometimes this would fail if `~/` wasn't expanded.
- Use HTTPS instead of SSH for `lua_yaml` git submodule.
- Fixed bug with `:ObsidianToday` command, which would fail if you weren't in a named buffer.

## [v1.1.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.1.0) - 2022-08-07

### Added

- Added `:ObsidianBacklinks` command for getting a location list of references to the current note.

### Fixed

- Fixed issue where completion wouldn't be triggered for "hashtag" form of a reference: `#[[...`
- Generalized syntax file so as to not override colorscheme.

## [v1.0.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v1.0.0) - 2022-08-05

### Added

- Added `:ObsidianOpen` command for opening a note in Obsidian (only works on MacOS for now).

## [v0.1.0](https://github.com/epwalsh/obsidian.nvim/releases/tag/v0.1.0) - 2022-08-05

### Added

- Initial plugin release
