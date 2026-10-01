# Task runner for the local dev loop. Run `make` or `make help` to list targets.
.PHONY: help install lint vendor readmes docs check all

# Every target uses one Python environment, chosen here: this
# checkout's .venv, else the active one, else, in the main checkout only, the system
# Python under UV_SYSTEM_PYTHON. Each uv install names it: uv skips .venv under
# UV_SYSTEM_PYTHON and, with both variables set, picks the system Python over VIRTUAL_ENV.
CHECKOUT_GIT_DIR := $(shell git rev-parse --absolute-git-dir 2>/dev/null)
ifneq ($(wildcard $(CURDIR)/.venv),)
  PYENV := $(CURDIR)/.venv
else ifneq ($(VIRTUAL_ENV),)
  PYENV := $(VIRTUAL_ENV)
endif
ifdef PYENV
  UV_TARGET := --python $(PYENV)
  export VIRTUAL_ENV := $(PYENV)
  export PATH := $(PYENV)/bin:$(PATH)
  unexport UV_SYSTEM_PYTHON
else ifneq ($(filter 1 true,$(UV_SYSTEM_PYTHON)),)
  # A linked worktree must not replace the main checkout's install in the system Python.
  ifeq ($(CHECKOUT_GIT_DIR),$(shell git rev-parse --path-format=absolute --git-common-dir 2>/dev/null))
    UV_TARGET := --system
  endif
endif
NO_ENV := No Python environment for this checkout: create one with `uv venv` or activate one (CONTRIBUTING.md, Setup)
UV_INSTALL = uv pip install $(or $(UV_TARGET),$(error $(NO_ENV)))

# Manifests: git-tracked only, so task worktrees and scratch copies never leak in.
# .devcontainer's are Liza's tools, which liza/tools.sh installs, only when enabled.
# src's are Feature payloads, which the Features install, never `make install`.
MANIFEST_EXCLUDES := $(foreach d,.worktrees .adversarial .liza .devcontainer src node_modules .venv venv .tox,':(exclude,glob)**/$(d)/**')
manifests = $(if $(CHECKOUT_GIT_DIR),$(shell git ls-files -- ':(glob)**/$(1)' $(MANIFEST_EXCLUDES)),$(wildcard $(1)))
NODE_DIRS = $(patsubst %/,%,$(dir $(call manifests,package.json)))
DEVCONTAINER := node_modules/.bin/devcontainer

help:  ## Show available targets
	@grep -E '^[a-zA-Z_-]+:.*?## ' $(MAKEFILE_LIST) | awk 'BEGIN{FS=":.*?## "}{printf "  %-12s %s\n", $$1, $$2}'

# pre-commit install refuses a checkout without git or with core.hooksPath set, which Liza
# sets in task worktrees.
install:  ## Install every tracked requirements file and Node manifest, then wire the pre-commit hook
	$(UV_INSTALL) $(foreach r,$(call manifests,requirements.txt),-r $(r))
	$(if $(NODE_DIRS),@command -v npm >/dev/null || { echo "npm not found; it installs: $(NODE_DIRS)" >&2; exit 1; })
	$(if $(NODE_DIRS),$(foreach d,$(NODE_DIRS),npm ci --ignore-scripts --prefix $(d) &&) true)
	@if ! git rev-parse --git-dir >/dev/null 2>&1; then :; \
	elif [ -n "$$(git config core.hooksPath)" ]; then echo "core.hooksPath is set; skipping pre-commit install"; \
	else pre-commit install; fi

lint:  ## Lint all files via pre-commit (codespell, shellcheck, markdownlint, lychee, actionlint, zizmor, check-jsonschema, hygiene)
	pre-commit run --all-files

# Only the copies a Feature already has: a helper change then bumps only the Features that
# ship it. Adding a helper to a Feature is a one-time cp.
vendor:  ## Refresh each Feature's copies of the lib/ helpers
	@for copy in src/*/*.sh; do \
		helper=lib/$${copy##*/}; [ ! -f "$$helper" ] || cp "$$helper" "$$copy"; \
	done

readmes:  ## Regenerate each Feature's README from its devcontainer-feature.json and NOTES.md
	$(if $(wildcard src/*/devcontainer-feature.json),$(DEVCONTAINER) features generate-docs -p src -n jartan-llc/enchantments --github-owner Jartan-LLC --github-repo enchantments)

docs: readmes  ## Regenerate the Feature READMEs, then build the docs site, warnings-as-errors
	sphinx-build -W -b html docs docs/_build/html

check:  ## Run every local check (lint, docs)
	$(MAKE) lint docs

all: check  ## Alias for `check`
