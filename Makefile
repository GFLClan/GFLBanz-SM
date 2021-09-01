CC := ${HOME}/sm/spcomp64
INCLUDE := -i addons/sourcemod/scripting/include
DEPS := $(shell find addons/sourcemod/scripting -name '*.sp' -or -name '*.inc')

.PHONY: all clean

all: gflbans-core

gflbans-core: $(DEPS)
	$(CC) addons/sourcemod/scripting/gflbans-core.sp $(INCLUDE) -o addons/sourcemod/plugins/gflbans-core.smx

clean: 
	rm -f addons/sourcemod/plugins/gflbans-core.smx
