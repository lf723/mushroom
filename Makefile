#自动区分平台
OS := $(shell uname)
ifeq ($(OS), $(filter $(OS), Darwin))
	PLAT=macosx
else 
	PLAT=linux
endif

.PHONY: all skynet clean install

SHARED := -fPIC --shared
LUA_CLIB_PATH ?= common/luaclib
PREFIX ?= bin
LUA_INC_PATH ?= 3rd/skynet/3rd/lua
CFLAGS = -g -O2 -Wall -std=gnu99 -lrt

BIN = $(LUA_CLIB_PATH)/log.so $(LUA_CLIB_PATH)/cjson.so $(LUA_CLIB_PATH)/protobuf.so start \
		tool/script/client/StressTest skynet 

all : skynet

skynet/Makefile :
	git submodule update --init

skynet : skynet/Makefile
	cd 3rd/skynet && $(MAKE) $(PLAT) && cd - && cp 3rd/skynet/skynet main

all : \
	$(foreach v, $(BIN), $(v))

$(LUA_CLIB_PATH) :
	mkdir $(LUA_CLIB_PATH)

$(LUA_CLIB_PATH)/log.so : common/luaclib_src/lua-log.c | $(LUA_CLIB_PATH)
	$(CC) $(CFLAGS) $(SHARED) -I./3rd/skynet/3rd/lua $^ -o $@

$(LUA_CLIB_PATH)/cjson.so : $(LUA_CLIB_PATH)
	cd 3rd/lua-cjson && $(MAKE)

$(LUA_CLIB_PATH)/protobuf.so : $(LUA_CLIB_PATH)
	cd 3rd/pbc/binding/lua53 && $(MAKE)

start : common/luaclib_src/start.c
	$(CC) $(CFLAGS) $^ -o $@

tool/script/client/StressTest : common/luaclib_src/StressTest.c
	$(CC) $(CFLAGS) -Wl,-E -I$(LUA_INC_PATH) -L$(LUA_INC_PATH) $^ -o $@ -llua -lpthread -lm -ldl 

install : all | $(PREFIX)
	cp -r etc $(PREFIX)
	cp -r common/luaclib $(PREFIX)/common
	cp -r common/lualib $(PREFIX)/common
	cp -r common/service $(PREFIX)/common
	cp 3rd/skynet/skynet $(PREFIX)/main
	cp -r 3rd/skynet/luaclib $(PREFIX)/3rd/skynet/
	cp -r 3rd/skynet/lualib $(PREFIX)/3rd/skynet/
	cp -r 3rd/skynet/service $(PREFIX)/3rd/skynet/
	cp -r 3rd/skynet/cservice $(PREFIX)/3rd/skynet/
	cp -r 3rd/lua-cjson/cjson.so $(PREFIX)/3rd/lua-cjson/cjson.so
	cp -r 3rd/pbc/binding/lua53/protobuf.so $(PREFIX)/3rd/pbc/binding/lua53/protobuf.so
	cp -r 3rd/pbc/binding/lua53/protobuf.lua $(PREFIX)/3rd/pbc/binding/lua53/protobuf.lua
	cp -r 3rd/pbc/binding/lua/protobuf.lua $(PREFIX)/3rd/pbc/binding/lua53/parser.lua
	cp start $(PREFIX)/
	cp StressTest $(PREFIX)/
	cp -r server $(PREFIX)

$(PREFIX) :
	mkdir $(PREFIX)
	mkdir $(PREFIX)/common
	mkdir $(PREFIX)/server
	mkdir -p $(PREFIX)/3rd/skynet
	mkdir -p $(PREFIX)/3rd/lua-cjson
	mkdir -p $(PREFIX)/3rd/pbc/binding/lua53

clean :
	rm -rf $(LUA_CLIB_PATH)/*
	rm -rf $(PREFIX)
	rm -rf start
	rm -rf tool/script/client/StressTest
	cd 3rd/skynet && $(MAKE) clean && cd -