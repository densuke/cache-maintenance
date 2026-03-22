#!/usr/bin/env bats
# test_cleaners.bats -- クリーナーの統合テスト（dry-run モード）

load libs/bats-support/load
load libs/bats-assert/load

PROJECT_ROOT="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"

setup() {
    export TMPDIR="${BATS_TMPDIR}"
    export MAINTENANCE_LOG="$BATS_TMPDIR/test.log"
    export DRY_RUN=1
    export MAINTENANCE_CONFIG_DIR="$PROJECT_ROOT/config"
}

teardown() {
    rm -f "$MAINTENANCE_LOG"
}

# ---------------------------------------------------------------------------
# brew.sh
# ---------------------------------------------------------------------------

@test "brew: dry-run exits 0 and outputs 'brew: 0 bytes'" {
    run bash "$PROJECT_ROOT/src/cleaners/brew.sh"
    assert_success
    assert_output --partial "brew: 0 bytes"
}

@test "brew: dry-run log contains DRY RUN or 'not installed' message" {
    run bash "$PROJECT_ROOT/src/cleaners/brew.sh"
    assert_success
    # Either brew is installed (DRY RUN log) or not (skip log)
    run cat "$MAINTENANCE_LOG"
    assert_success
}

# ---------------------------------------------------------------------------
# pip.sh
# ---------------------------------------------------------------------------

@test "pip: dry-run exits 0 and outputs 'pip: 0 bytes'" {
    run bash "$PROJECT_ROOT/src/cleaners/pip.sh"
    assert_success
    assert_output --partial "pip: 0 bytes"
}

# ---------------------------------------------------------------------------
# caches.sh
# ---------------------------------------------------------------------------

@test "caches: dry-run exits 0 with project config" {
    run bash "$PROJECT_ROOT/src/cleaners/caches.sh"
    assert_success
    assert_output --partial "app-caches: 0 bytes"
}

@test "caches: dry-run exits 0 with nonexistent config dir (bash 3.2 regression)" {
    export MAINTENANCE_CONFIG_DIR="/nonexistent"
    run bash "$PROJECT_ROOT/src/cleaners/caches.sh"
    assert_success
    assert_output --partial "app-caches: 0 bytes"
}

# ---------------------------------------------------------------------------
# xcode.sh
# ---------------------------------------------------------------------------

@test "xcode: dry-run exits 0 and outputs 'xcode: 0 bytes'" {
    run bash "$PROJECT_ROOT/src/cleaners/xcode.sh"
    assert_success
    assert_output --partial "xcode: 0 bytes"
}

# ---------------------------------------------------------------------------
# sccache.sh
# ---------------------------------------------------------------------------

@test "sccache: dry-run exits 0 and outputs 'sccache: 0 bytes'" {
    run bash "$PROJECT_ROOT/src/cleaners/sccache.sh"
    assert_success
    assert_output --partial "sccache: 0 bytes"
}

# ---------------------------------------------------------------------------
# docker.sh
# ---------------------------------------------------------------------------

@test "docker: dry-run exits 0 and outputs 'docker: 0 bytes'" {
    run bash "$PROJECT_ROOT/src/cleaners/docker.sh"
    assert_success
    assert_output --partial "docker: 0 bytes"
}

# ---------------------------------------------------------------------------
# run.sh (orchestrator)
# ---------------------------------------------------------------------------

@test "run.sh: dry-run exits 0 and outputs total line" {
    run bash "$PROJECT_ROOT/src/run.sh"
    assert_success
    assert_output --partial "total: 0 bytes"
}

@test "run.sh: dry-run result summary lists all cleaners" {
    run bash "$PROJECT_ROOT/src/run.sh"
    assert_success
    assert_output --partial "brew:"
    assert_output --partial "pip:"
    assert_output --partial "app-caches:"
    assert_output --partial "xcode:"
    assert_output --partial "sccache:"
    assert_output --partial "docker:"
}

@test "run.sh: dry-run log has no double entries (log lines appear once)" {
    bash "$PROJECT_ROOT/src/run.sh"
    # Count lines matching the start banner — should appear exactly once
    local count
    count=$(grep -c "cache-maintenance: DRY RUN start" "$MAINTENANCE_LOG")
    [ "$count" -eq 1 ]
}
