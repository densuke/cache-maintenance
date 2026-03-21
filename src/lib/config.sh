#!/usr/bin/env bash
# config.sh -- パターンファイル読み込みと削除判定
#
# 使い方: source "$(dirname "$0")/../lib/config.sh"
#
# 環境変数:
#   MAINTENANCE_CONFIG_DIR  設定ファイルディレクトリ（デフォルト: ~/.config/maintenance/config）
#
# 設定ファイル形式 (caches.allow):
#   <glob パターン>[<TAB><プロセス名>]
#   # で始まる行はコメント、空行は無視

MAINTENANCE_CONFIG_DIR="${MAINTENANCE_CONFIG_DIR:-$HOME/.config/maintenance/config}"

# read_patterns <filename>
# 設定ファイルを読み込み、コメント行・空行を除いて1行ずつ stdout に出力する
read_patterns() {
    local file="$MAINTENANCE_CONFIG_DIR/$1"
    [ -f "$file" ] || return 0
    grep -v '^\s*#' "$file" | grep -v '^\s*$'
}

# should_clean <path>
# パスのベース名が allow リストにマッチし、かつ deny リストにマッチしない場合 0 を返す
#
# NOTE: bash 3.2 (macOS /bin/bash) bug: multiple process substitutions < <(...)
# inside a function called repeatedly from a loop trigger SIGTRAP (exit 133).
# Workaround: use here-string <<< "$(cmd)" instead of < <(cmd).
should_clean() {
    local target="$1"
    local name patterns
    name="$(basename "$target")"

    # deny チェック（マッチしたら削除しない）
    patterns="$(read_patterns caches.deny)" || true
    while IFS=$'\t' read -r pattern _rest; do
        [ -z "$pattern" ] && continue
        # shellcheck disable=SC2254
        case "$name" in
            $pattern) return 1 ;;
        esac
    done <<< "$patterns"

    # allow チェック（マッチしたら削除対象）
    patterns="$(read_patterns caches.allow)" || true
    while IFS=$'\t' read -r pattern _rest; do
        [ -z "$pattern" ] && continue
        # shellcheck disable=SC2254
        case "$name" in
            $pattern) return 0 ;;
        esac
    done <<< "$patterns"

    return 1
}

# get_guard_process <name>
# allow ファイルでパターンにマッチした行の2カラム目（プロセス名）を stdout に出力する
# 2カラム目がない場合は空文字を返す
#
# NOTE: same bash 3.2 workaround — use <<< instead of < <(...)
get_guard_process() {
    local name="$1"
    local pattern process_name patterns

    patterns="$(read_patterns caches.allow)" || true
    while IFS=$'\t' read -r pattern process_name _rest; do
        [ -z "$pattern" ] && continue
        # shellcheck disable=SC2254
        case "$name" in
            $pattern)
                echo "${process_name}"
                return 0
                ;;
        esac
    done <<< "$patterns"

    echo ""
}

# is_app_running <process_pattern>
# pgrep -if でプロセスが実行中かどうかを確認する
# 空文字が渡された場合は「実行中でない」(1) を返す
is_app_running() {
    local process_pattern="$1"
    [ -z "$process_pattern" ] && return 1
    pgrep -if "$process_pattern" >/dev/null 2>&1
}
