RUSTC ?= rustc
RUSTDOC ?= rustdoc
BUILD_DIR ?= ./build/
RUST_PATH ?= $(BUILD_DIR)
RUSTFLAGS ?= --opt-level=3 -g
RUSTTESTFLAGS ?= -L $(RUST_PATH)
REGEXP_LIB = $(BUILD_DIR)/.libregexp.timestamp
REGEXP_LIB_FILES = src/compile.rs src/lib.rs src/parse.rs src/re.rs \
									 src/unicode.rs src/vm.rs \
									 src/test/bench.rs src/test/macro.rs src/test/matches.rs \
									 src/test/mod.rs src/test/tests.rs
REGEXP_MACRO_LIB = $(BUILD_DIR)/.libregexp_macros.timestamp
REGEXP_MACRO_LIB_FILES = src/macro.rs
MOZILLA_RUST ?= $(HOME)/clones/rust

all: $(REGEXP_LIB) $(REGEXP_MACRO_LIB)

install:
	cargo-lite install

$(REGEXP_LIB): $(REGEXP_LIB_FILES)
	@mkdir -p $(BUILD_DIR)
	$(RUSTC) $(RUSTFLAGS) ./src/lib.rs --out-dir=$(BUILD_DIR)
	@touch $(REGEXP_LIB)

$(REGEXP_MACRO_LIB): $(REGEXP_LIB) $(REGEXP_MACRO_LIB_FILES)
	@mkdir -p $(BUILD_DIR)
	$(RUSTC) -L $(BUILD_DIR) $(RUSTFLAGS) ./src/macro.rs --out-dir=$(BUILD_DIR)
	@touch $(REGEXP_MACRO_LIB)

match-tests:
	./regexp-match-tests ./src/testdata/*.dat > ./src/test/matches.rs

unicode-tables:
	./regexp-unicode-tables > ./src/unicode.rs

docs: $(REGEXP_LIB_FILES) $(REGEXP_MACRO_LIB_FILES)
	rm -rf doc
	$(RUSTDOC) -L $(RUST_PATH) --test ./src/lib.rs
	$(RUSTDOC) -L $(RUST_PATH) ./src/lib.rs
	$(RUSTDOC) -L $(RUST_PATH) ./src/macro.rs
	# WTF is rustdoc doing?
	chmod 755 doc
	in-dir doc fix-perms
	rscp ./doc/* gopher:~/www/burntsushi.net/rustdoc/exp/

test: build/tests
	RUST_TEST_TASKS=1 RUST_LOG=regexp ./build/tests

build/tests: $(REGEXP_LIB) $(REGEXP_MACRO_LIB)
	rustc $(RUSTTESTFLAGS) -L $(RUST_PATH) --test src/lib.rs -o ./build/tests

bench: build/bench
	RUST_TEST_TASKS=1 RUST_LOG=regexp ./build/bench --bench

bench-perf: build/bench
	RUST_TEST_TASKS=1 RUST_LOG=regexp perf record -g --call-graph dwarf -s ./build/bench --bench

build/bench: src/test/bench.rs
	rustc $(RUSTFLAGS) -Z lto -L $(RUST_PATH) --test --cfg bench src/lib.rs -o ./build/bench

scratch: build/scratch
	RUST_TEST_TASKS=1 RUST_LOG=regexp ./build/scratch

build/scratch: $(REGEXP_MACRO_LIB) scratch.rs
	rustc -L $(BUILD_DIR) $(RUSTTESTFLAGS) scratch.rs -o ./build/scratch

ctags:
	ctags --recurse --options=ctags.rust --languages=Rust

clean:
	rm -rf ./build/* ./build/.*.timestamp

push:
	git push origin native
	git push github native

mozilla:
	rm -rf $(MOZILLA_RUST)/src/libregexp/*
	cp -a ./src/* $(MOZILLA_RUST)/src/libregexp/
	rm $(MOZILLA_RUST)/src/libregexp/macro.rs
	cp ./src/macro.rs $(MOZILLA_RUST)/src/libregexp_macros/lib.rs

