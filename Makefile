NAME := go-template
PKG := github.com/justintout/$(NAME)

# Where to push the docker image.
REGISTRY ?= justintout

# Which architecture to build - see $(ALL_ARCH) for options.
ARCH ?= amd64

# This version-strategy uses git tags to set the version string
VERSION := $(shell cat VERSION)
GITCOMMIT := $(shell git rev-parse --short HEAD)
GITUNTRACKEDCHANGES := $(shell git status --porcelain --untracked-files=no)
ifneq ($(GITUNTRACKEDCHANGES),)
	GITCOMMIT := $(GITCOMMIT)-dirty
endif
CTIMEVAR=-X $(PKG)/vers.GITCOMMIT=$(GITCOMMIT) -X $(PKG)/vers.VERSION=$(VERSION)
GO_LDFLAGS=-ldflags "-w $(CTIMEVAR)"
GO_LDFLAGS_STATIC=-ldflags "-w $(CTIMEVAR) -extldflags -static"

GOOSARCHES = darwin/amd64 darwin/386 linux/arm linux/arm64 linux/amd64 linux/386 windows/amd64 windows/386

all: clean build test vet install ## runs clean, build, fmt, lint, test, staticcheck, vet, install

.PHONY: build
build: $(NAME) ## Builds dynamic executable or package 

$(NAME): *.go VERSION
	@echo "+ $@"
	go build -tags "$(BUILDTAGS)" ${GO_LDFLAGS} -o $(NAME) .
	
.PHONY: static
static: ## builds a static executable
	@echo "+ $@"
	CGO_ENABLED=0 go build \
		-tags "$(BUILDTAGS) static_build" \
		${GO_LDFLAGS_STATIC} -o $(NAME) .

.PHONY: fmt 
fmt: ## ensure files are fmt'd
	@echo "+ $@"
	@gofmt -s -l . | grep -v vendor | tee /dev/stderr

.PHONY: lint 
lint: ## make sure golint passes
	@echo "+ $@"
	@golint ./... | grep -v "vendor" | tee /dev/stderr

.PHONY: vet 
vet: ## make sure vet passes 
	@echo "+ $@"
	@go vet $(shell go list ./... | grep -v vendor) | tee /dev/stderr

.PHONY: go-test 
go-test: ## runs the go tests 
	@echo "+ $@"
	@go test -v -tags "$(BUILDTAGS) cgo" $(shell go list ./... | grep -v vendor)

.PHONY: go-test-cover 
go-test-cover: ## runs the go tests with coverage
	@echo "" > coverage.txt
	@for d in $(shell go list ./... | grep -v vendor); do \
		go test -race -coverprofile=profile.out -covermode=atomic "$d"; \
		if [ -f profile.out ]; then \
			cat profile.out >> coverage.txt; \
			rm profile.out; \
		fi; \
	done;

.PHONY: staticcheck 
staticcheck: ## make sure staticcheck passes
	@echo "+ $@"
	@staticcheck $(shell go list ./... | grep -v vendor | tee /dev/stderr)

.PHONY: test ## runs through lint,  go test, staticcheck, vet
test: lint go-test staticcheck vet

.PHONY: install
install: ## installs all the commands in the repo
	@echo "+ $@"
	go install -a -tags "$(BUILDTAGS)" ${GO_LDFLAGS} .

define buildpretty
mkdir -p $(BUILDDIR)/$(1)/$(2);
GOOS=$(1) GOARCH=$(2) CGO_ENABLED=0 go build \
	-o $(BUILDDIR)/$(1)/$(2)/$(NAME) \
	-a -tags "$(BUILDTAGS) static_build netgo" \
	-intallsuffix netgo ${GO_LDFLAGS_STATIC} ./...;
md5sum $(BUILDDIR)/$(1)/$(2)/$(NAME) > $(BUILDDIR)/$(1)/$(2)/$(NAME).md5;
shasum -a 256 $(BUILDDIR)/$(1)/$(2)/$(NAME) > $(BUILDDIR)/$(1)/$(2)/$(NAME).sha256;
endef

.PHONY: cross
cross: *.go VERSION ## builds cross-compiled binaries w/ dir structure (GOOS/GOARCH/bin)
	@echo "+ $@"
	$(foreach GOOSARCH,$(GOOSARCHES),$(call buildpretty,$(subst /,,$(dir $(GOOSARCH))),$(notdir $(GOOSARCH)))

.PHONY: bump-version
BUMP ?= patch
bump-version: ## bump the version file. BUMP can be (patch | minor | major)
	@go get github.com/justin/sembump
	$(eval NEW_VERSION $(shell sembump --kind $(BUMP) $(VERSION)))
	@echo "Bumping VERSION from $(VERSION) to $(NEW_VERSION)"
	echo $(NEW_VERSION) > VERSION
	@echo "Updating links to download binaries in README.md"
	sed -i s/$(VERSION)/$(NEW_VERSION)/g README.md
	git add VERSION README.md
	giut commit -vsam "Bump version to $(NEW_VERSION)"
	@echo "Run make tag to create and push the tag for the new version $(NEW_VERSION)"

.PHONY: bump-rc
BUMP := rc
bump-rc: ## bump the release candidtate version. VERSION must have a prerelease tag X.X.X-tag.number or X.X.X-number
	@go get github.com/justintout/sembump
	$(eval NEW_VERSION = $(shell sembump --kind rc $(VERSION)))
	echo $(NEW_VERSION) > VERSION
	@echo "Prerelease version incremented"
	git add VERSION
	git commit -vsam "Bump version to $(NEW_VERSION)"
	@echo "Run make tag to create and push the tag for the new version $(NEW_VERSION)"

.PHONY: release 
release: *.go VERSION ## Buld cross-compiled bins and name bin-GOOS-GOARCH
	@echo "+ $@"
	$(foreach GOOSARCH,$(GOOSARCHES)),$(call buildrelease,$(subst /,,$(dir $(GOOSARCH))),$(notdir $(GOOSARCH)))

.PHONY: tag
tag: ## create a new git tag based on VERSION to prelare a release
	git tag -a $(VERSION) -m "$(VESRION)"
	@echo "Run git push origin $(VERSION) to push new tag to GitHub and trigger a travis build."

.PHONY: AUTHORS
AUTHORS:
	@$(file >$@,# This file lists all individuals having contributed content to this repository.)
	@$(file >>$@,# For how it is generated, see `make AUTHORS`.)
	@echo "$(shell git log --format='\n%aN <%aE>' | LC_ALL=C.UTF-8 sort -uf") >> $@

.PHONY: clean
clean: ## clean any build binaries or packages 
	@echo "+ $@"
	$(RM) $(NAME)
	$(RM) -r $(BUILDDIR)

clean: bin-clean container-clean ## clean up binaries, containers, and docker bits 

container-clean: 
	@echo "+ $@"
	rm -rf .container-* .dockerfile-* .push-*

bin-clean:
	@echo "+ $@"
	$(RM) $(NAME)
	$(RM) -r $(BUILDDIR)

.PHONY: help 
help:
	@grep -E '^[a-zA-Z_-]+:.*?## .*$$' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*?## "}; {printf "\033[36m%-30s\033[0m %s\n", $$1, $$2}'
