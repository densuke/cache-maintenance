#!/usr/bin/env bats
# test_config.bats -- tests for src/lib/config.sh

load 'libs/bats-support/load'
load 'libs/bats-assert/load'

setup() {
    TEST_DIR="$(mktemp -d)"
    export MAINTENANCE_LOG="$TEST_DIR/test.log"
    export MAINTENANCE_CONFIG_DIR="$TEST_DIR/config"
    mkdir -p "$MAINTENANCE_CONFIG_DIR"
    export TEST_DIR

    SCRIPT_DIR="$(cd "$(dirname "$BATS_TEST_FILENAME")/../.." && pwd)"
    source "$SCRIPT_DIR/src/lib/common.sh"
    source "$SCRIPT_DIR/src/lib/config.sh"
}

teardown() {
    rm -rf "$TEST_DIR"
}

# ---------------------------------------------------------------------------
# read_patterns()
# ---------------------------------------------------------------------------

@test "read_patterns: returns patterns from file" {
    printf 'com.google.Chrome\ncom.spotify.client\n' > "$MAINTENANCE_CONFIG_DIR/caches.allow"
    run read_patterns caches.allow
    assert_success
    assert_output --partial "com.google.Chrome"
    assert_output --partial "com.spotify.client"
}

@test "read_patterns: skips comment lines" {
    printf '# this is a comment\ncom.google.Chrome\n' > "$MAINTENANCE_CONFIG_DIR/caches.allow"
    run read_patterns caches.allow
    assert_success
    refute_output --partial "# this is a comment"
    assert_output --partial "com.google.Chrome"
}

@test "read_patterns: skips blank lines" {
    printf 'com.google.Chrome\n\n\ncom.spotify.client\n' > "$MAINTENANCE_CONFIG_DIR/caches.allow"
    run read_patterns caches.allow
    assert_success
    assert_output --partial "com.google.Chrome"
    assert_output --partial "com.spotify.client"
    # 空行が含まれていないこと
    refute_output --regexp $'(^|\n)(\n|$)'
}

@test "read_patterns: returns nothing when file does not exist" {
    run read_patterns nonexistent.allow
    assert_success
    assert_output ""
}

# ---------------------------------------------------------------------------
# should_clean()
# ---------------------------------------------------------------------------

@test "should_clean: returns true for path matching allow pattern" {
    printf 'com.google.Chrome\n' > "$MAINTENANCE_CONFIG_DIR/caches.allow"
    : > "$MAINTENANCE_CONFIG_DIR/caches.deny"
    run should_clean "$TEST_DIR/cache/com.google.Chrome"
    assert_success
}

@test "should_clean: returns false for path not in allow list" {
    printf 'com.google.Chrome\n' > "$MAINTENANCE_CONFIG_DIR/caches.allow"
    : > "$MAINTENANCE_CONFIG_DIR/caches.deny"
    run should_clean "$TEST_DIR/cache/com.apple.unknown"
    assert_failure
}

@test "should_clean: deny overrides allow" {
    printf 'com.google.Chrome\n' > "$MAINTENANCE_CONFIG_DIR/caches.allow"
    printf 'com.google.Chrome\n' > "$MAINTENANCE_CONFIG_DIR/caches.deny"
    run should_clean "$TEST_DIR/cache/com.google.Chrome"
    assert_failure
}

@test "should_clean: glob pattern in allow matches correctly" {
    printf 'com.jetbrains.*\n' > "$MAINTENANCE_CONFIG_DIR/caches.allow"
    : > "$MAINTENANCE_CONFIG_DIR/caches.deny"
    run should_clean "$TEST_DIR/cache/com.jetbrains.idea"
    assert_success
}

@test "should_clean: glob pattern does not match unrelated entry" {
    printf 'com.jetbrains.*\n' > "$MAINTENANCE_CONFIG_DIR/caches.allow"
    : > "$MAINTENANCE_CONFIG_DIR/caches.deny"
    run should_clean "$TEST_DIR/cache/com.apple.Safari"
    assert_failure
}

# ---------------------------------------------------------------------------
# get_guard_process()
# ---------------------------------------------------------------------------

@test "get_guard_process: returns process name from allow file" {
    printf 'com.google.Chrome\tGoogle Chrome\n' > "$MAINTENANCE_CONFIG_DIR/caches.allow"
    result=$(get_guard_process "com.google.Chrome")
    assert_equal "$result" "Google Chrome"
}

@test "get_guard_process: returns empty string when no process column" {
    printf 'com.apple.Safari\n' > "$MAINTENANCE_CONFIG_DIR/caches.allow"
    result=$(get_guard_process "com.apple.Safari")
    assert_equal "$result" ""
}

@test "get_guard_process: returns empty string for unknown pattern" {
    printf 'com.google.Chrome\tGoogle Chrome\n' > "$MAINTENANCE_CONFIG_DIR/caches.allow"
    result=$(get_guard_process "com.unknown.app")
    assert_equal "$result" ""
}

# ---------------------------------------------------------------------------
# is_app_running()
# ---------------------------------------------------------------------------

@test "is_app_running: returns false for empty process name" {
    run is_app_running ""
    assert_failure
}

@test "is_app_running: returns false for nonexistent process" {
    run is_app_running "DefinitelyNotRunning_xyzzy_12345"
    assert_failure
}

@test "is_app_running: returns true for a known running process (bash itself)" {
    # bash は必ず実行中
    run is_app_running "bash"
    assert_success
}
