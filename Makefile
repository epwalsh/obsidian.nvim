TEST = test/obsidian
# This is where you have plenary installed locally. Override this at runtime if yours is elsewhere.
PLENARY = ~/.local/share/nvim/lazy/plenary.nvim/
MINIDOC = ~/.local/share/nvim/lazy/mini.doc/

.PHONY : all
all : style lint test

.PHONY : test
test :
	PLENARY=$(PLENARY) nvim \
		--headless \
		--noplugin \
		-u test/minimal_init.vim \
		-c "PlenaryBustedDirectory $(TEST) { minimal_init = './test/minimal_init.vim' }"

.PHONY: api-docs
api-docs :
	MINIDOC=$(MINIDOC) nvim \
		--headless \
		--noplugin \
		-u scripts/minimal_init.vim \
		-c "luafile scripts/generate_api_docs.lua" \
		-c "qa!"

.PHONY : lint
lint :
	luacheck .

.PHONY : style
style :
	stylua --check .

.PHONY : version
version :
	@nvim --headless -c 'lua print("v" .. require("obsidian").VERSION)' -c q 2>&1
