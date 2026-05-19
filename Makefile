# Dotfiles test/lint entry point. Runs everything that can run on the
# current OS; sub-targets skip themselves with a clear message when the
# tool they depend on isn't installed.

.PHONY: test test-nvim test-shell test-starship test-tmux test-ghostty \
        test-bootstrap test-static lint install dryrun help

REPO := $(shell pwd)

help:
	@echo "Targets:"
	@echo "  install         — symlink configs into OS-appropriate paths"
	@echo "  dryrun          — print what install would do without changing anything"
	@echo "  test            — run all test sub-targets (skips what's not installed)"
	@echo "  test-nvim       — plenary busted suite under nvim --headless"
	@echo "  test-shell      — shellcheck + zsh smoke + Esc-binding regression"
	@echo "  test-starship   — render snapshot + perf budget (<25ms mean)"
	@echo "  test-tmux       — load + option assertions"
	@echo "  test-ghostty    — +validate-config + scheme grep (mac only)"
	@echo "  test-bootstrap  — bats coverage of bootstrap.sh idempotency"
	@echo "  test-static     — json/toml/yaml lint, editorconfig, invariants"
	@echo "  lint            — shellcheck everything"

install:
	@bash bootstrap.sh

dryrun:
	@bash bootstrap.sh --dry-run

test: test-static lint test-nvim test-shell test-starship test-tmux test-ghostty test-bootstrap
	@echo
	@echo "=== test summary: see individual sub-target output above ==="

test-nvim:
	@bash tests/nvim/run.sh

test-shell:
	@bash tests/shell/run_all.sh

test-starship:
	@bash tests/starship/run_all.sh

test-tmux:
	@bash tests/tmux/run_all.sh

test-ghostty:
	@bash tests/ghostty/run_all.sh

test-bootstrap:
	@bash tests/bootstrap/run.sh

test-static:
	@bash tests/static/run_all.sh

lint:
	@command -v shellcheck >/dev/null 2>&1 && shellcheck bootstrap.sh shells/zshrc tests/**/*.sh tests/*.sh 2>/dev/null || \
		echo "skipped: shellcheck not installed (brew install shellcheck)"
