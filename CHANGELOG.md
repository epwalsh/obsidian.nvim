# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## Unreleased

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
