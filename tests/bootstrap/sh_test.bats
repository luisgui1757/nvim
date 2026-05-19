#!/usr/bin/env bats
# Coverage for bootstrap.sh: idempotency, backup, partial-recovery, dry-run.

setup() {
    REPO_ROOT="$(cd "$BATS_TEST_DIRNAME/../.." && pwd -P)"
    FAKE_HOME="$(mktemp -d)"
    export HOME="$FAKE_HOME"
    # bootstrap.sh writes into $HOME-derived paths only — no need to mock $LOCALAPPDATA etc.
}

teardown() {
    rm -rf "$FAKE_HOME"
}

run_bootstrap() {
    HOME="$FAKE_HOME" bash "$REPO_ROOT/bootstrap.sh" "$@"
}

@test "fresh install creates the expected symlinks" {
    run run_bootstrap
    [ "$status" -eq 0 ]
    [ -L "$FAKE_HOME/.config/nvim" ]
    [ "$(readlink "$FAKE_HOME/.config/nvim")" = "$REPO_ROOT/nvim" ]
    [ -L "$FAKE_HOME/.config/starship.toml" ]
    [ "$(readlink "$FAKE_HOME/.config/starship.toml")" = "$REPO_ROOT/starship/starship.toml" ]
    [ -L "$FAKE_HOME/.tmux.conf" ]
    [ -L "$FAKE_HOME/.zshrc" ]
}

@test "re-running is a no-op (idempotent)" {
    run run_bootstrap
    [ "$status" -eq 0 ]

    # Snapshot link targets
    pre_nvim=$(readlink "$FAKE_HOME/.config/nvim")
    pre_tmux=$(readlink "$FAKE_HOME/.tmux.conf")

    run run_bootstrap
    [ "$status" -eq 0 ]

    # Targets unchanged
    [ "$(readlink "$FAKE_HOME/.config/nvim")" = "$pre_nvim" ]
    [ "$(readlink "$FAKE_HOME/.tmux.conf")" = "$pre_tmux" ]

    # No new .bak files should appear
    bak_count=$(find "$FAKE_HOME" -name "*.bak.*" 2>/dev/null | wc -l | tr -d ' ')
    [ "$bak_count" = "0" ]
}

@test "non-symlink target is backed up before being replaced" {
    mkdir -p "$FAKE_HOME"
    echo "user-written" > "$FAKE_HOME/.zshrc"

    run run_bootstrap
    [ "$status" -eq 0 ]
    [ -L "$FAKE_HOME/.zshrc" ]

    # The original is preserved as .bak.<timestamp>
    bak=$(find "$FAKE_HOME" -maxdepth 1 -name ".zshrc.bak.*" | head -1)
    [ -n "$bak" ]
    [ "$(cat "$bak")" = "user-written" ]
}

@test "partial recovery: only missing links are added, existing correct ones untouched" {
    mkdir -p "$FAKE_HOME/.config"
    ln -s "$REPO_ROOT/nvim" "$FAKE_HOME/.config/nvim"

    pre_inode=$(stat -f %i "$FAKE_HOME/.config/nvim" 2>/dev/null || stat -c %i "$FAKE_HOME/.config/nvim")

    run run_bootstrap
    [ "$status" -eq 0 ]

    post_inode=$(stat -f %i "$FAKE_HOME/.config/nvim" 2>/dev/null || stat -c %i "$FAKE_HOME/.config/nvim")
    [ "$pre_inode" = "$post_inode" ]   # already-correct link not disturbed

    [ -L "$FAKE_HOME/.tmux.conf" ]      # missing link now in place
}

@test "--dry-run changes nothing on disk" {
    run run_bootstrap --dry-run
    [ "$status" -eq 0 ]
    [ ! -e "$FAKE_HOME/.config/nvim" ]
    [ ! -e "$FAKE_HOME/.tmux.conf" ]
    [ ! -e "$FAKE_HOME/.zshrc" ]
}

@test "missing git aborts with a clear error" {
    # Build a sandbox PATH without git but with the basics (ln, readlink, etc.)
    sandbox=$(mktemp -d)
    for cmd in bash ln readlink uname dirname date mkdir mv cat grep tr basename printf; do
        if path=$(command -v "$cmd"); then ln -s "$path" "$sandbox/$cmd"; fi
    done
    # Ensure pwsh is also absent so the optional pwsh branch is skipped.
    PATH="$sandbox" run bash "$REPO_ROOT/bootstrap.sh"
    [ "$status" -ne 0 ]
    [[ "$output" =~ "required command 'git'" ]]
}
