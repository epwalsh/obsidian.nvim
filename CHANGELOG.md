# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

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
