# Makefile — a discoverable façade over the existing entry points.
# ──────────────────────────────────────────────────────────────────────────────
# This adds NO logic: every target shells out to the real script (bin/*.sh,
# pre-commit), which stay the single source of truth. It exists so a newcomer can
# type `make` and see how to lint, test, audit, and sync — instead of grepping the
# README for bin/ paths. The audit (`make audit`) is the one gate; CI and
# pre-commit call the same bin/audit-core.sh, so `make audit` == green CI.
# ──────────────────────────────────────────────────────────────────────────────
.DEFAULT_GOAL := help
.PHONY: help audit test bench lint sync sync-dry hooks update-hooks

help: ## Show this help
	@echo "dotfiles-core — make targets:"
	@grep -E '^[a-z][a-zA-Z0-9_-]+:.*## ' $(MAKEFILE_LIST) \
		| sed -E 's/:.*## /\t/' | sort | awk -F'\t' '{printf "  \033[36m%-13s\033[0m %s\n", $$1, $$2}'

audit: ## Run the full Core audit (manifest, exec-bits, syntax, lint, behavioral) — the one gate
	@./bin/audit-core.sh

test: ## Run only the behavioral tests (load-order smoke + function units)
	@./bin/test-core.sh

bench: ## Benchmark Core's contribution to zsh startup (needs hyperfine; skips if absent)
	@./bin/bench-core.sh

lint: audit ## Alias for `audit` (the audit IS the lint+test gate)

sync: ## Subtree-pull Core into every OS repo (THE maintain button) — writes to sibling repos
	@./bin/sync-core.sh

sync-dry: ## Show what `sync` would do, touching nothing
	@./bin/sync-core.sh --dry-run

hooks: ## Install the pre-commit hooks into this clone
	@command -v pre-commit >/dev/null 2>&1 || { echo "pre-commit not found: pip install pre-commit"; exit 1; }
	@pre-commit install

update-hooks: ## Bump pinned pre-commit hook revisions (dependabot has no pre-commit ecosystem)
	@command -v pre-commit >/dev/null 2>&1 || { echo "pre-commit not found: pip install pre-commit"; exit 1; }
	@pre-commit autoupdate
