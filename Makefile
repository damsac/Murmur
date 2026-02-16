.DEFAULT_GOAL := help
SCHEME := Murmur
# Read APP_GROUP_IDENTIFIER from project.local.yml (required)
APP_GROUP := $(shell grep 'APP_GROUP_IDENTIFIER:' project.local.yml 2>/dev/null | awk '{print $$2}')
ENTITLEMENTS := Murmur/Murmur.entitlements

.PHONY: generate build test lint clean help

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
	@if ! grep -q 'APP_GROUP_IDENTIFIER' "$(ENTITLEMENTS)" 2>/dev/null; then \
		echo "ERROR: $(ENTITLEMENTS) missing App Group entitlement" >&2; \
		echo "Check project.yml entitlements.properties." >&2; \
		exit 1; \
	fi
	@echo "Project generated — entitlements validated."

build: generate ## Build for simulator (no code signing required)
	set -o pipefail && xcodebuild \
		-scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
		-configuration Debug \
		CODE_SIGN_IDENTITY=- \
		CODE_SIGNING_REQUIRED=NO \
		build 2>&1 | xcbeautify

test: generate ## Run unit tests on simulator
	set -o pipefail && xcodebuild \
		-scheme $(SCHEME) \
		-destination 'platform=iOS Simulator,name=iPhone 17 Pro,OS=latest' \
		-configuration Debug \
		CODE_SIGN_IDENTITY=- \
		CODE_SIGNING_REQUIRED=NO \
		test 2>&1 | xcbeautify

lint: ## Lint Swift sources
	swiftlint lint Murmur/

clean: ## Remove build artifacts
	xcodebuild clean -scheme $(SCHEME) 2>/dev/null || true
	rm -rf build/ DerivedData/

help: ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | \
		awk 'BEGIN {FS = ":.*?## "}; {printf "  \033[36m%-12s\033[0m %s\n", $$1, $$2}'
