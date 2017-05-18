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

BIN = $(LUA_CLIB_PATH)/log.so $(LUA_CLIB_PATH)/cjson.so start StressTest skynet

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

cjson/Makefile :
	git submodule update --init

$(LUA_CLIB_PATH)/cjson.so : cjson/Makefile | $(LUA_CLIB_PATH)
	cd 3rd/lua-cjson && $(MAKE) && cd -

start : common/luaclib_src/start.c
	$(CC) $(CFLAGS) $^ -o $@

StressTest : common/luaclib_src/StressTest.c
	$(CC) $(CFLAGS) -I$(LUA_INC_PATH) -L$(LUA_INC_PATH) $^ -o $@ -lpthread -llua -lm -ldl

install : all | $(PREFIX)
	cp -r etc $(PREFIX)
	cp -r common/luaclib $(PREFIX)/common
	cp -r common/lualib $(PREFIX)/common
	cp -r common/service $(PREFIX)/common
	cp 3rd/skynet/skynet $(PREFIX)/main
	cp -r 3rd/skynet/luaclib $(PREFIX)/3rd/skynet/
	cp -r 3rd/skynet/lualib $(PREFIX)/3rd/skynet/
	cp -r 3rd/skynet/service $(PREFIX)/3rd/skynet/
	cp start $(PREFIX)/
	cp StressTest $(PREFIX)/
	cp -r server $(PREFIX)
	cp 3rd/lua-cjson/cjson.so $(PREFIX)/common/luaclib/

$(PREFIX) :
	mkdir $(PREFIX)
	mkdir $(PREFIX)/common
	mkdir $(PREFIX)/server
	mkdir -p $(PREFIX)/3rd/skynet

clean :
	rm -rf $(LUA_CLIB_PATH)/*
	rm -rf $(PREFIX)
	rm -rf start
	rm -rf StressTest
	cd 3rd/skynet && $(MAKE) clean && cd -