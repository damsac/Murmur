.DEFAULT_GOAL := help
SCHEME := Murmur
SIM_NAME := iPhone 17 Pro
DESTINATION := platform=iOS Simulator,name=$(SIM_NAME),OS=latest
BUNDLE_ID := $(shell grep 'PRODUCT_BUNDLE_IDENTIFIER_MURMUR:' project.local.yml 2>/dev/null | awk '{print $$2}')
# Read APP_GROUP_IDENTIFIER from project.local.yml (required)
APP_GROUP := $(shell grep 'APP_GROUP_IDENTIFIER:' project.local.yml 2>/dev/null | awk '{print $$2}')
ENTITLEMENTS := Murmur/Murmur.entitlements

# MurmurCore local package (uses swift-clean to bypass Nix SDK)
CORE_DIR := Packages/MurmurCore
SWIFT_CLEAN := $(CORE_DIR)/swift-clean

.PHONY: generate build test run lint clean setup help
.PHONY: core-build core-test core-repl core-scenarios core-clean

generate: ## Generate Xcode project and validate entitlements
	@if [ ! -f project.local.yml ]; then \
		echo "ERROR: project.local.yml not found" >&2; \
		echo "Copy project.local.yml.template to project.local.yml and configure your settings" >&2; \
		exit 1; \
	fi
	@if [ -z "$(APP_GROUP)" ]; then \
		echo "ERROR: APP_GROUP_IDENTIFIER not set in project.local.yml" >&2; \
		echo "Set APP_GROUP_IDENTIFIER in project.local.yml (e.g., group.com.yourusername.murmur.shared)" >&2; \
		exit 1; \
	fi
	xcodegen generate
	@if ! grep -q '$(APP_GROUP)' "$(ENTITLEMENTS)" 2>/dev/null; then \
		echo "ERROR: $(ENTITLEMENTS) missing App Group identifier '$(APP_GROUP)'" >&2; \
		echo "Check project.yml entitlements.properties." >&2; \
		exit 1; \
	fi
	@echo "Project generated — entitlements validated."

build: generate ## Build for simulator
	set -o pipefail && xcodebuild \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		build 2>&1 | xcbeautify

test: generate ## Run unit tests on simulator
	set -o pipefail && xcodebuild \
		-scheme $(SCHEME) \
		-destination '$(DESTINATION)' \
		test 2>&1 | xcbeautify

run: build ## Build, install, and launch on simulator
	@SIM_ID=$$(xcrun simctl list devices available | grep '$(SIM_NAME) (' | head -1 | grep -oE '[0-9A-F-]{36}') && \
	if [ -z "$$SIM_ID" ]; then \
		echo "ERROR: Simulator '$(SIM_NAME)' not found" >&2; \
		exit 1; \
	fi && \
	xcrun simctl boot "$$SIM_ID" 2>/dev/null || true && \
	open -a Simulator && \
	APP_PATH=$$(xcodebuild -scheme $(SCHEME) -destination '$(DESTINATION)' -showBuildSettings 2>/dev/null \
		| grep ' BUILT_PRODUCTS_DIR' | awk '{print $$3}') && \
	xcrun simctl install "$$SIM_ID" "$$APP_PATH/$(SCHEME).app" && \
	xcrun simctl launch "$$SIM_ID" "$(BUNDLE_ID)" && \
	echo "Murmur running on $(SIM_NAME)."

lint: ## Lint Swift sources
	swiftlint lint Murmur/

clean: ## Remove build artifacts
	xcodebuild clean -scheme $(SCHEME) 2>/dev/null || true
	rm -rf build/ DerivedData/

setup: ## Configure git hooks and check tool availability
	@echo "Checking dev tools..."
	@command -v xcodegen >/dev/null 2>&1 || { echo "ERROR: xcodegen not found — enter the dev shell (direnv allow)" >&2; exit 1; }
	@command -v swiftlint >/dev/null 2>&1 || { echo "ERROR: swiftlint not found — enter the dev shell (direnv allow)" >&2; exit 1; }
	@command -v xcbeautify >/dev/null 2>&1 || { echo "ERROR: xcbeautify not found — enter the dev shell (direnv allow)" >&2; exit 1; }
	@echo "All dev tools available."
	@if [ -d .git ]; then \
		echo "Git hooks are managed by the Nix dev shell (shellHook)."; \
		echo "Run 'direnv allow' or 'nix develop' to install them."; \
	fi

## ── MurmurCore package ──────────────────────────────

core-build: ## Build MurmurCore package
	cd $(CORE_DIR) && $(CURDIR)/$(SWIFT_CLEAN) build

core-test: ## Run MurmurCore unit tests
	cd $(CORE_DIR) && $(CURDIR)/$(SWIFT_CLEAN) test

core-repl: core-build ## Run interactive REPL (record, text, list, etc.)
	$(CORE_DIR)/.build/debug/TranscriptionTest

core-scenarios: core-build ## Run LLM scenario tests (needs PPQ_API_KEY)
	cd $(CORE_DIR) && .build/debug/ScenarioRunner

core-clean: ## Clean MurmurCore build artifacts
	cd $(CORE_DIR) && $(CURDIR)/$(SWIFT_CLEAN) package clean

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-16s\033[0m %s\n", $$1, $$2}'
