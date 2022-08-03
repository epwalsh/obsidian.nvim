.PHONY : test
test :
	nvim \
		--headless \
		--noplugin \
		-u test/minimal_init.vim \
		-c "PlenaryBustedDirectory test/obsidian/ { minimal_init = './test/minimal_init.vim' }"

.PHONY : lint
lint :
	luacheck lua --exclude-files='lua/deps/lua_yaml/*'
