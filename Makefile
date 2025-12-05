# ----------------------------
# Config
# ----------------------------

ROOT_DIR := $(CURDIR)
MDSDRV_DIR := $(ROOT_DIR)/MDSDRV
DEPS_DIR := $(MDSDRV_DIR)/deps
BIN_DIR := $(MDSDRV_DIR)/bin
OUT_DIR := $(MDSDRV_DIR)/out

NUM_CORES := $(shell nproc || sysctl -n hw.ncpu || echo 4)

# Pinned commits
MDSDRV_COMMIT := fefc7178579c59505f860e292e76af4a1857c6eb
SJASMPLUS_COMMIT := 9d18ee7575fefee97cd8866361770b44a2966a67
SJASMPLUS_LUABRIDGE_COMMIT := a08915f5c1703204467df99a62c6378e089c753a
SALVADOR_COMMIT := 1662b625a8dcd6f3f7e3491c88840611776533f5
CLOWNASM_COMMIT := 1a3f6c6a0253c98214d3a611f0fc20348185897f
CLOWNASM_CLOWNCOMMON_COMMIT := 37d1efd90725a7c30dce5f38ea14f1bc3c29a52f

# ----------------------------
# Top-level targets
# ----------------------------

.PHONY: all clone deps build copy clean

all: clone deps build copy

clone: $(MDSDRV_DIR)

deps: sjasmplus salvador clownasm

build: $(OUT_DIR)/mdssub.zx0 $(OUT_DIR)/mdsdrv.bin

copy:
	@echo "SHA256 (out/mdsdrv.bin): $$(sha256sum $(OUT_DIR)/mdsdrv.bin | cut -d' ' -f1)"
	cp $(OUT_DIR)/mdsdrv.bin $(ROOT_DIR)/mdsdrv.bin
	@echo "Copied mdsdrv.bin → $(ROOT_DIR)"

clean:
	rm -rf $(MDSDRV_DIR)
	rm -f $(ROOT_DIR)/mdsdrv.bin
	@echo "Removed MDSDRV directory and mdsdrv.bin"

# ----------------------------
# Clone MDSDRV
# ----------------------------

$(MDSDRV_DIR):
	git clone https://github.com/superctr/MDSDRV.git $@
	cd $@ && git checkout $(MDSDRV_COMMIT)

# ----------------------------
# Dependencies
# ----------------------------

sjasmplus: $(BIN_DIR)/sjasmplus
salvador: $(BIN_DIR)/salvador
clownasm: $(BIN_DIR)/clownassembler_asm68k

$(BIN_DIR):
	mkdir -p $@

# --- sjasmplus ---
$(DEPS_DIR)/sjasmplus:
	git clone https://github.com/garrettjwilke/sjasmplus $@
	cd $@ && git checkout $(SJASMPLUS_COMMIT)
	cd $@ && git submodule update --init LuaBridge
	cd $@/LuaBridge && git checkout $(SJASMPLUS_LUABRIDGE_COMMIT)

$(BIN_DIR)/sjasmplus: | $(DEPS_DIR)/sjasmplus $(BIN_DIR)
	$(MAKE) -C $(DEPS_DIR)/sjasmplus -j$(NUM_CORES)
	cp $(DEPS_DIR)/sjasmplus/sjasmplus $(BIN_DIR)/

# --- salvador ---
$(DEPS_DIR)/salvador:
	git clone https://github.com/emmanuel-marty/salvador.git $@
	cd $@ && git checkout $(SALVADOR_COMMIT)

$(BIN_DIR)/salvador: | $(DEPS_DIR)/salvador $(BIN_DIR)
	$(MAKE) -C $(DEPS_DIR)/salvador -j$(NUM_CORES)
	cp $(DEPS_DIR)/salvador/salvador $(BIN_DIR)/

# --- clownasm ---
$(DEPS_DIR)/clownassembler:
	git clone https://github.com/garrettjwilke/clownassembler $@
	cd $@ && git checkout $(CLOWNASM_COMMIT)
	cd $@ && git submodule update --init clowncommon
	cd $@/clowncommon && git checkout $(CLOWNASM_CLOWNCOMMON_COMMIT)

$(BIN_DIR)/clownassembler_asm68k: | $(DEPS_DIR)/clownassembler $(BIN_DIR)
	mkdir -p $(DEPS_DIR)/clownassembler/build
	cd $(DEPS_DIR)/clownassembler/build && cmake .. && cmake --build . --parallel $(NUM_CORES)
	cp $(DEPS_DIR)/clownassembler/build/clownassembler_asm68k $(BIN_DIR)/

# ----------------------------
# Build MDSDRV
# ----------------------------

$(OUT_DIR):
	mkdir -p $@

$(OUT_DIR)/mdssub.bin: | $(OUT_DIR)
	$(BIN_DIR)/sjasmplus MDSDRV/src/mdssub.z80 --raw=$@

$(OUT_DIR)/mdssub.zx0: $(OUT_DIR)/mdssub.bin
	$(BIN_DIR)/salvador $< $@

$(OUT_DIR)/mdsdrv.bin: $(OUT_DIR)/mdssub.zx0
	cd $(MDSDRV_DIR) && bin/clownassembler_asm68k /k /p /o ae- src/blob.68k,out/mdsdrv.bin