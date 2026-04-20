SHELL:=/usr/bin/env bash

.DEFAULT_GOAL:=help
PROJECT_NAME = "obsidian.nvim"
TEST = test/obsidian
# Depending on your setup you have to override the locations at runtime.
PLENARY = ~/.local/share/nvim/lazy/plenary.nvim/
MINIDOC = ~/.local/share/nvim/lazy/mini.doc/


################################################################################
##@ Developmment
.PHONY: chores
chores: style lint test ## Run all develoment tasks

.PHONY: test
test: $(PLENARY) ## Run unit tests
	PLENARY=$(PLENARY) nvim \
		--headless \
		--noplugin \
		-u test/minimal_init.vim \
		-c "PlenaryBustedDirectory $(TEST) { minimal_init = './test/minimal_init.vim' }"

$(PLENARY):
	git clone --depth 1 https://github.com/nvim-lua/plenary.nvim.git $(PLENARY)

.PHONY: api-docs
api-docs: $(MINIDOC) ## Generate API documentation with mini.doc
	MINIDOC=$(MINIDOC) nvim \
		--headless \
		--noplugin \
		-u scripts/minimal_init.vim \
		-c "luafile scripts/generate_api_docs.lua" \
		-c "qa!"

$(MINIDOC):
	git clone --depth 1 https://github.com/echasnovski/mini.doc $(MINIDOC)

.PHONY: lint
lint: ## Lint the code
	luacheck .

.PHONY: style
style:  ## format the code
	stylua --check .


################################################################################
##@ Helpers
.PHONY: version
version:  ## Print the obsidian.nvim version
	@nvim --headless -c 'lua print("v" .. require("obsidian").VERSION)' -c q 2>&1

.PHONY: help
help:  ## Display this help
	@echo "Welcome to $$(tput bold)${PROJECT_NAME}$$(tput sgr0) 🥳📈🎉"
	@echo ""
	@echo "To get started:"
	@echo "  >>> $$(tput bold)make chores$$(tput sgr0)"
	@awk 'BEGIN {FS = ":.*##"; printf "\033[36m\033[0m"} /^[a-zA-Z_-]+:.*?##/ { printf "  \033[36m%-15s\033[0m %s\n", $$1, $$2 } /^##@/ { printf "\n\033[1m%s\033[0m\n", substr($$0, 5) } ' $(MAKEFILE_LIST)
