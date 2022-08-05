.PHONY : all
all : style lint test

.PHONY : test
test :
	nvim \
		--headless \
		--noplugin \
		-u test/minimal_init.vim \
		-c "PlenaryBustedDirectory test/obsidian/ { minimal_init = './test/minimal_init.vim' }"

.PHONY : lint
lint :
	luacheck after lua --exclude-files='lua/deps/lua_yaml/*'

.PHONY : style
style :
	stylua --check lua/ after/ test/

.PHONY : version
version :
	@nvim --headless -c 'lua print("v" .. require("obsidian").VERSION)' -c q 2>&1
