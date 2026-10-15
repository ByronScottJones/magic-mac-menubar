# Task runner for Magic. Run `make` for the target list.
.DEFAULT_GOAL := help
.PHONY: help deps build test lint app clean all default install

## This help screen
help:
	@printf "Available targets:\n\n"
	@awk '/^[a-zA-Z\-_0-9%:\\]+/ { \
		helpMessage = match(lastLine, /^## (.*)/); \
		if (helpMessage) { \
			helpCommand = $$1; \
			helpMessage = substr(lastLine, RSTART + 3, RLENGTH); \
			gsub("\\\\", "", helpCommand); \
			gsub(":+$$", "", helpCommand); \
			printf "  \x1b[32;01m%-35s\x1b[0m %s\n", helpCommand, helpMessage; \
		} \
	} \
	{ lastLine = $$0 }' $(MAKEFILE_LIST) | sort -u
	@printf "\n"

## Verify required tooling is installed
deps:
	@command -v swift >/dev/null || { echo "error: swift toolchain not found" >&2; exit 1; }

## Compile a debug build
build: deps
	swift build

## Run unit tests
test: deps
	swift test

## Lint shell scripts and Markdown
lint:
	shellcheck scripts/*.sh
	npx --yes markdownlint-cli2 '**/*.md' '#.git/**' '#.build/**' '#dist/**'

## Assemble dist/Magic.app (release build, ad-hoc signed)
app: deps
	./scripts/build-app.sh

## Install Magic.app into /Applications
install: app
	rm -rf /Applications/Magic.app
	cp -R dist/Magic.app /Applications/Magic.app

## Remove build outputs
clean:
	rm -rf .build dist

## Build, test, and assemble the app
all: build test app

## Default: build and test
default: build test
