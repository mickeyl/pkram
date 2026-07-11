SHELL := /bin/bash

PKRAM := .build/debug/pkram
INSTALL_DIR := $(HOME)/.local/bin
MAN_DIR := $(HOME)/.local/share/man/man1

# Optional: point these at your own throwaway Papierkram objects to use the
# smoke targets. They are unset by default so the targets fail loudly rather
# than writing into somebody else's project.
TEST_COMPANY_ID ?=
TEST_PROJECT_ID ?=
TEST_TASK_ID ?=

.DEFAULT_GOAL := help

.PHONY: help
help: ## Show available targets.
	@awk 'BEGIN {FS = ":.*##"; printf "Targets:\n"} /^[a-zA-Z0-9_.-]+:.*##/ {printf "  %-18s %s\n", $$1, $$2}' $(MAKEFILE_LIST)

.PHONY: build
build: ## Build the CLI.
	swift build

.PHONY: test
test: ## Run unit tests.
	swift test

.PHONY: clean
clean: ## Remove SwiftPM build artifacts.
	swift package clean

.PHONY: install
install: build ## Install pkram into ~/.local/bin and create pk alias.
	mkdir -p "$(INSTALL_DIR)"
	install -m 0755 $(PKRAM) "$(INSTALL_DIR)/pkram"
	ln -sf pkram "$(INSTALL_DIR)/pk"
	$(MAKE) man

.PHONY: auth-check
auth-check: build ## Verify Papierkram authentication.
	$(PKRAM) auth check

.PHONY: config
config: build ## Show active local pkram config.
	$(PKRAM) config show

.PHONY: list-test-data
list-test-data: build ## List your configured test project and its tasks (needs TEST_*).
	@test -n "$(TEST_PROJECT_ID)" || { echo "Set TEST_PROJECT_ID (and optionally TEST_COMPANY_ID)."; exit 1; }
	@test -z "$(TEST_COMPANY_ID)" || $(PKRAM) projects list --company $(TEST_COMPANY_ID)
	$(PKRAM) tasks list --project $(TEST_PROJECT_ID)

.PHONY: entries-today
entries-today: build ## List today's entries for the test task (needs TEST_TASK_ID).
	@test -n "$(TEST_TASK_ID)" || { echo "Set TEST_TASK_ID."; exit 1; }
	$(PKRAM) entries list --from today --to today --task $(TEST_TASK_ID)

.PHONY: timer-example
timer-example: build ## Start a local test timer and print the dry-run payload.
	@test -n "$(TEST_TASK_ID)" || { echo "Set TEST_TASK_ID."; exit 1; }
	-$(PKRAM) timer cancel --force >/dev/null 2>&1
	$(PKRAM) timer start --task $(TEST_TASK_ID) --comment "pkram timer dry run"
	$(PKRAM) timer stop --dry-run
	$(PKRAM) timer cancel --force

.PHONY: man
man: ## Install the pkram(1) manpage into ~/.local/share/man.
	mkdir -p "$(MAN_DIR)"
	install -m 0644 man/pkram.1 "$(MAN_DIR)/pkram.1"

.PHONY: smoke
smoke: test auth-check ## Run non-destructive smoke checks.
