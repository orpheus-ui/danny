# Everyday commands. `make help` lists them.
# xcodebuild uses every core; run one heavy target at a time (docs/engineering.md).

PROJECT   := Danny.xcodeproj
SCHEME    := Danny
DERIVED   := build/DerivedData
XCODEBUILD = xcodebuild -project $(PROJECT) -scheme $(SCHEME) -destination 'platform=macOS' \
             -derivedDataPath $(DERIVED) CODE_SIGNING_ALLOWED=NO
BEAUTIFY  := $(shell command -v xcbeautify >/dev/null && echo "| xcbeautify --quiet --disable-logging" || echo "")

.DEFAULT_GOAL := help
.PHONY: help bootstrap project format lint test build run check clean version changelog package

help: ## List the commands
	@grep -E '^[a-z-]+:.*## ' $(MAKEFILE_LIST) | awk -F':.*## ' '{printf "  make %-10s %s\n", $$1, $$2}'

bootstrap: ## First time: tools, git hooks, Xcode project
	brew bundle --file=Brewfile
	git config core.hooksPath .githooks
	./scripts/build-assets.sh
	$(MAKE) project

project: ## Regenerate Danny.xcodeproj from project.yml
	xcodegen generate --quiet

format: ## Format all Swift code
	swiftformat .

lint: ## Check formatting and lint (what CI runs)
	swiftformat --lint . --quiet
	swiftlint lint --strict --quiet

test: project ## Run the unit tests
	set -o pipefail && $(XCODEBUILD) test $(BEAUTIFY)

build: project ## Debug build
	set -o pipefail && $(XCODEBUILD) build $(BEAUTIFY)

run: build ## Build and launch the app
	open $(DERIVED)/Build/Products/Debug/Danny.app

check: lint test ## Everything CI checks, before you push

clean: ## Remove build output
	rm -rf build

version: ## Set the app version: make version V=0.2.0
	@[ -n "$(V)" ] || { echo "usage: make version V=x.y.z"; exit 1; }
	@echo "$(V)" | grep -Eq '^[0-9]+\.[0-9]+\.[0-9]+$$' || { echo "V must be x.y.z"; exit 1; }
	sed -i '' -E 's/^( *MARKETING_VERSION: )"[^"]*"/\1"$(V)"/' project.yml
	@echo "Version set to $(V). Next: make changelog V=$(V)"

changelog: ## Rewrite CHANGELOG.md for a release: make changelog V=0.2.0
	@[ -n "$(V)" ] || { echo "usage: make changelog V=x.y.z"; exit 1; }
	git cliff --tag "v$(V)" --output CHANGELOG.md

package: ## Local release build (unsigned unless DEVELOPER_ID is set) in build/release
	./scripts/fetch-dependencies.sh
	./scripts/release.sh build
	./scripts/release.sh sign
	./scripts/release.sh package
	./scripts/release.sh checksums
