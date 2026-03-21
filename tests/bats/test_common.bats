#!/usr/bin/env bats
# test_common.bats -- tests for src/lib/common.sh

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
    TEST_DIR="$(mktemp -d)"
    export MAINTENANCE_LOG="$TEST_DIR/test.log"
    export TEST_DIR

    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$SCRIPT_DIR/src/lib/common.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ---------------------------------------------------------------------------
# log()
# ---------------------------------------------------------------------------

@test "log: writes message to log file" {
    log "hello test"
    assert [ -f "$MAINTENANCE_LOG" ]
    run grep "hello test" "$MAINTENANCE_LOG"
    assert_success
}

@test "log: output includes timestamp format YYYY-MM-DD HH:MM:SS" {
    log "timestamp check"
    run grep -E "^[0-9]{4}-[0-9]{2}-[0-9]{2} [0-9]{2}:[0-9]{2}:[0-9]{2} \|" "$MAINTENANCE_LOG"
    assert_success
}

# ---------------------------------------------------------------------------
# safe_rm()
# ---------------------------------------------------------------------------

@test "safe_rm: removes file when DRY_RUN=0" {
    local target="$TEST_DIR/target_file"
    touch "$target"
    DRY_RUN=0 safe_rm "$target"
    assert [ ! -e "$target" ]
}

@test "safe_rm: does NOT remove file when DRY_RUN=1" {
    local target="$TEST_DIR/target_file"
    touch "$target"
    DRY_RUN=1 safe_rm "$target"
    assert [ -e "$target" ]
}

@test "safe_rm: logs dry-run message when DRY_RUN=1" {
    local target="$TEST_DIR/target_file"
    touch "$target"
    DRY_RUN=1 safe_rm "$target"
    run grep "DRY RUN" "$MAINTENANCE_LOG"
    assert_success
}

@test "safe_rm: removes file when DRY_RUN is unset" {
    local target="$TEST_DIR/target_file"
    touch "$target"
    unset DRY_RUN
    safe_rm "$target"
    assert [ ! -e "$target" ]
}

@test "safe_rm: removes directory recursively" {
    local target="$TEST_DIR/target_dir"
    mkdir -p "$target/subdir"
    touch "$target/subdir/file"
    DRY_RUN=0 safe_rm "$target"
    assert [ ! -e "$target" ]
}

@test "safe_rm: succeeds silently for nonexistent path" {
    run safe_rm "$TEST_DIR/nonexistent"
    assert_success
}

# ---------------------------------------------------------------------------
# measure_freed()
# ---------------------------------------------------------------------------

@test "measure_freed: returns non-negative bytes when DRY_RUN=0" {
    local target="$TEST_DIR/measure_dir"
    mkdir -p "$target"
    dd if=/dev/zero of="$target/file" bs=1024 count=1 2>/dev/null
    DRY_RUN=0
    result=$(measure_freed "$target" safe_rm "$target")
    assert [ "$result" -ge 0 ]
}

@test "measure_freed: returns 0 when DRY_RUN=1" {
    local target="$TEST_DIR/measure_dir"
    mkdir -p "$target"
    dd if=/dev/zero of="$target/file" bs=1024 count=1 2>/dev/null
    DRY_RUN=1
    result=$(measure_freed "$target" safe_rm "$target")
    assert_equal "$result" "0"
}

@test "measure_freed: returns 0 for nonexistent path" {
    result=$(measure_freed "$TEST_DIR/nonexistent" true)
    assert_equal "$result" "0"
}
