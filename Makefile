SHELL := /bin/bash
.PHONY: build arch deb rpm all clean test lint fmt docker docker-build help

VERSION ?= latest
OUTPUT  ?= /tmp/amnezia-pkgs
TAR     ?=
PROFILE ?= default

build: arch       ## Build default target (Arch)

arch:             ## Build Arch package
	./build.sh -a --profile $(PROFILE) -o $(OUTPUT) $(if $(TAR),--tar $(TAR),) $(if $(filter-out latest,$(VERSION)),-v $(VERSION),)

deb:              ## Build Debian package
	./build.sh -d --profile $(PROFILE) -o $(OUTPUT) $(if $(TAR),--tar $(TAR),) $(if $(filter-out latest,$(VERSION)),-v $(VERSION),)

rpm:              ## Build RPM package
	./build.sh -r --profile $(PROFILE) -o $(OUTPUT) $(if $(TAR),--tar $(TAR),) $(if $(filter-out latest,$(VERSION)),-v $(VERSION),)

all:              ## Build all targets
	./build.sh --all --profile $(PROFILE) -o $(OUTPUT) $(if $(TAR),--tar $(TAR),) $(if $(filter-out latest,$(VERSION)),-v $(VERSION),)

parallel:         ## Build all targets in parallel
	./build.sh --all --parallel --profile $(PROFILE) -o $(OUTPUT) $(if $(TAR),--tar $(TAR),) $(if $(filter-out latest,$(VERSION)),-v $(VERSION),)

release:          ## Build all + sign + manifest
	./build.sh --all --sign --manifest --profile $(PROFILE) -o $(OUTPUT) $(if $(TAR),--tar $(TAR),) -v $(VERSION)

.PHONY: test
test:             ## Run test suite
	@if command -v bats &>/dev/null; then bats tests/; else echo "bats not found — install with: sudo pacman -S bats"; fi

lint:             ## Shellcheck all scripts
	shellcheck -x build.sh src/**/*.sh

fmt:              ## Format shell scripts with shfmt
	shfmt -w -i 4 -bn build.sh src/**/*.sh

clean:            ## Remove build artifacts
	rm -rf $(OUTPUT)
	rm -rf /tmp/amnezia-pkgs

docker-build:     ## Build Docker image
	docker build -t amnezia-packager .

docker: docker-build  ## Alias for docker-build

docker-run-arch:  ## Run Arch build in Docker
	docker run --rm -v $(OUTPUT):/output amnezia-packager ./build.sh -a -o /output $(if $(TAR),-v /$(TAR):/tmp/tar.tar --tar /tmp/tar.tar,)

check-deps:       ## Check required dependencies
	@for cmd in jq curl tar sudo; do \
		command -v $$cmd &>/dev/null || echo "Missing: $$cmd"; \
	done

help:             ## Show this help
	@grep -Eh '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | sort | \
		awk 'BEGIN {FS = ":.*## "}; {printf "\033[36m%-20s\033[0m %s\n", $$1, $$2}'
