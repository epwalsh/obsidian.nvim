SRC = $(wildcard src/*.rs)
UNAME := $(shell uname)
TARGET = debug

ifeq ($(UNAME), Darwin)
TGT_EXT = dylib
else
TGT_EXT = so
endif

lua/obsidian.so : target/$(TARGET)/libobsidian.$(TGT_EXT) $(SRC)
	mkdir -p lua
	cp $< $@

target/debug/libobsidian.$(TGT_EXT) : $(SRC)
	cargo build

target/release/libobsidian.$(TGT_EXT) : $(SRC)
	cargo build --release
