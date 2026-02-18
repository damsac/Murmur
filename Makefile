.DEFAULT_GOAL := help
SCHEME := Murmur
SIM_NAME := iPhone 17 Pro
DESTINATION := platform=iOS Simulator,name=$(SIM_NAME),OS=latest
BUNDLE_ID := $(shell grep 'PRODUCT_BUNDLE_IDENTIFIER_MURMUR:' project.local.yml 2>/dev/null | awk '{print $$2}')
APP_GROUP := $(shell grep 'APP_GROUP_IDENTIFIER:' project.local.yml 2>/dev/null | awk '{print $$2}')
ENTITLEMENTS := Murmur/Murmur.entitlements

CORE_DIR := Packages/MurmurCore
SWIFT_CLEAN := $(CORE_DIR)/swift-clean

.PHONY: help setup generate build test run lint clean
.PHONY: sim-boot sim-shutdown sim-list sim-screenshot
.PHONY: core-build core-test core-repl core-scenarios core-clean

## ── Setup ────────────────────────────────────────────

setup: ## First-time setup: check tools, copy config template
	@echo "Checking dev tools..."
	@command -v xcodegen >/dev/null 2>&1 || { echo "ERROR: xcodegen not found — run 'direnv allow'" >&2; exit 1; }
	@command -v swiftlint >/dev/null 2>&1 || { echo "ERROR: swiftlint not found — run 'direnv allow'" >&2; exit 1; }
	@command -v xcbeautify >/dev/null 2>&1 || { echo "ERROR: xcbeautify not found — run 'direnv allow'" >&2; exit 1; }
	@echo "All dev tools available."
	@if [ ! -f project.local.yml ]; then \
		cp project.local.yml.template project.local.yml; \
		echo "Created project.local.yml — edit it with your Team ID and settings."; \
	else \
		echo "project.local.yml already exists."; \
	fi

## ── App (Xcode) ──────────────────────────────────────

generate: ## Generate Xcode project from project.yml
	@if [ ! -f project.local.yml ]; then \
		echo "ERROR: project.local.yml not found. Run 'make setup' first." >&2; \
		exit 1; \
	fi
	@if [ -z "$(APP_GROUP)" ]; then \
		echo "ERROR: APP_GROUP_IDENTIFIER not set in project.local.yml" >&2; \
		exit 1; \
	fi
	xcodegen generate
	@if ! grep -q '$(APP_GROUP)' "$(ENTITLEMENTS)" 2>/dev/null; then \
		echo "ERROR: $(ENTITLEMENTS) missing App Group '$(APP_GROUP)'" >&2; \
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
	if [ -z "$$SIM_ID" ]; then echo "ERROR: Simulator '$(SIM_NAME)' not found" >&2; exit 1; fi && \
	xcrun simctl boot "$$SIM_ID" 2>/dev/null || true && \
	open -a Simulator && \
	APP_PATH=$$(xcodebuild -scheme $(SCHEME) -destination '$(DESTINATION)' -showBuildSettings 2>/dev/null \
		| grep ' BUILT_PRODUCTS_DIR' | awk '{print $$3}') && \
	xcrun simctl install "$$SIM_ID" "$$APP_PATH/$(SCHEME).app" && \
	xcrun simctl launch "$$SIM_ID" "$(BUNDLE_ID)" && \
	echo "Murmur running on $(SIM_NAME)."

lint: ## Lint Swift sources
	swiftlint lint Murmur/

clean: ## Remove Xcode build artifacts
	xcodebuild clean -scheme $(SCHEME) 2>/dev/null || true
	rm -rf build/ DerivedData/

## ── Simulator ────────────────────────────────────────

sim-boot: ## Boot the iOS simulator
	@SIM_ID=$$(xcrun simctl list devices available | grep '$(SIM_NAME) (' | head -1 | grep -oE '[0-9A-F-]{36}') && \
	if [ -z "$$SIM_ID" ]; then echo "ERROR: Simulator '$(SIM_NAME)' not found" >&2; exit 1; fi && \
	xcrun simctl boot "$$SIM_ID" 2>/dev/null || true && \
	open -a Simulator && \
	echo "Simulator booted: $(SIM_NAME) ($$SIM_ID)"

sim-shutdown: ## Shutdown all running simulators
	xcrun simctl shutdown all
	@echo "All simulators shut down."

sim-list: ## List available iOS simulators
	@xcrun simctl list devices available | grep -i iphone

sim-screenshot: ## Take a screenshot of the running simulator
	@mkdir -p screenshots
	@FILENAME="screenshots/sim-$$(date +%Y%m%d-%H%M%S).png" && \
	xcrun simctl io booted screenshot "$$FILENAME" && \
	echo "Screenshot saved: $$FILENAME"

## ── MurmurCore (SPM) ─────────────────────────────────

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

## ── Help ─────────────────────────────────────────────

help: ## Show available targets
	@echo ""
	@echo "  Murmur development commands"
	@echo "  ─────────────────────────────────────"
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-18s\033[0m %s\n", $$1, $$2}'
	@echo ""
