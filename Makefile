TEST = test/obsidian
# This is where you have plenary installed locally. Override this at runtime if yours is elsewhere.
PLENARY = ~/.local/share/nvim/lazy/plenary.nvim/

.PHONY : all
all : style lint test

.PHONY : test
test :
	PLENARY=$(PLENARY) nvim \
		--headless \
		--noplugin \
		-u test/minimal_init.vim \
		-c "PlenaryBustedDirectory $(TEST) { minimal_init = './test/minimal_init.vim' }"

.PHONY : lint
lint :
	luacheck after lua

.PHONY : style
style :
	stylua --check lua/ after/ test/

.PHONY : version
version :
	@nvim --headless -c 'lua print("v" .. require("obsidian").VERSION)' -c q 2>&1
