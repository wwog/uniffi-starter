# UniFFI starter — common tasks.
#
#   make dev          build + generate all bindings (the usual one)
#   make build        build the cdylib (release)      -> artifacts/
#   make bindings     generate all languages          -> bindings/
#   make test         run the Rust test suite
#   make xcframework  build an iOS/macOS XCFramework  -> artifacts/
#   make aar          assemble an Android AAR         -> artifacts/
#   make check-version verify uniffi versions match
#   make demo-python  / demo-swift / demo-kotlin : run a consuming demo
#   make clean        remove generated output
#
# Override the profile with:  make dev PROFILE=debug

SHELL := /bin/bash
PROFILE ?= release
export PROFILE

.DEFAULT_GOAL := dev

.PHONY: all dev build bindings test xcframework aar check-version \
        demo-python demo-swift demo-kotlin clean help

all: dev

dev:
	@scripts/dev.sh --$(PROFILE)

build:
	@scripts/build.sh --$(PROFILE)

bindings:
	@scripts/generate-bindings.sh --$(PROFILE)

test:
	@scripts/test.sh

xcframework:
	@scripts/build-xcframework.sh

# Assemble an AAR from prebuilt .so files:  make aar LIBS_DIR=./path
# (or omit LIBS_DIR to build the .so via cargo-ndk, which needs an NDK).
LIBS_DIR ?=
aar:
	@scripts/build-aar.sh $(if $(LIBS_DIR),--libs-dir $(LIBS_DIR),)

check-version:
	@scripts/check-version.sh

demo-python:
	@python3 demo/python/main.py

demo-swift:
	@demo/swift/build.sh

demo-kotlin:
	@demo/kotlin/run.sh

clean:
	rm -rf bindings artifacts
	@echo "cleaned bindings/ and artifacts/"

help:
	@sed -n '2,17p' $(MAKEFILE_LIST)
