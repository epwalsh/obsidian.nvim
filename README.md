# Obsidian.nvim

A Neovim plugin for [Obsidian](https://obsidian.md), written in Rust using [nvim-oxi](https://github.com/noib3/nvim-oxi).

## Requirements

Only Mac OS and Linux are currently supported.
You will need to have `make` and `cargo` installed because your Neovim plugin manager will need to compile the binary.

## Install

Using `vim-plug`, for example:

```vim
Plug 'epwalsh/obsidian.nvim', { 'do': 'make TARGET=release' }
```

## Configuration

For a minimal configuration, just add:

```vim
lua require("obsidian")
```
