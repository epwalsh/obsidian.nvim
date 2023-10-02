# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

### Added

- The `overwrite_mappings` option, which sets the mappings in the config even if they already exist

### Fixed

- Eliminated silent runtime errors on validation errors in note.from_lines 

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

- `plenary.nvim` is no longer required to be installed seperately. It's now bundled as a submodule.

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
