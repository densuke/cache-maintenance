#!/usr/bin/env bash
# run.sh -- 全クリーナーを順次実行してサマリーを出力するオーケストレーター
#
# 使い方:
#   bash src/run.sh                  # 通常実行
#   DRY_RUN=1 bash src/run.sh        # dry-run（削除しない）
#
# 環境変数:
#   DRY_RUN              1 のとき全クリーナーが dry-run モードで動作（デフォルト: 0）
#   MAINTENANCE_LOG      ログファイルのパス
#   MAINTENANCE_CONFIG_DIR  設定ファイルディレクトリ

set -uo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/lib/common.sh
source "$SCRIPT_DIR/lib/common.sh"

# デフォルトの設定ディレクトリを export（未設定のクリーナーが参照できるよう）
# インストール済みなら ~/.config/maintenance/config、なければプロジェクト内の config/ を使う
_default_config_dir="$HOME/.config/maintenance/config"
if [ ! -d "$_default_config_dir" ] && [ -d "$SCRIPT_DIR/../config" ]; then
    _default_config_dir="$(cd "$SCRIPT_DIR/../config" && pwd)"
fi
export MAINTENANCE_CONFIG_DIR="${MAINTENANCE_CONFIG_DIR:-$_default_config_dir}"
unset _default_config_dir
export DRY_RUN="${DRY_RUN:-0}"

# _run_cleaner <name> <script_path>
# クリーナーを実行し、結果の行("name: N bytes")を返す
# 失敗しても処理を続ける（set -e を使わない理由）
_run_cleaner() {
    local name="$1"
    local script="$2"

    if [ ! -f "$script" ]; then
        log "ERROR: cleaner not found: $script"
        echo "${name}: 0 bytes"
        return
    fi

    local output exit_code
    # log() inside cleaners writes to MAINTENANCE_LOG directly via tee.
    # Redirecting stderr here would double-write those log lines.
    output=$(bash "$script" 2>/dev/null)
    exit_code=$?

    if [ "$exit_code" -ne 0 ]; then
        log "WARN: $name exited with code $exit_code"
    fi

    # クリーナーの stdout（"name: N bytes"）をそのまま返す
    echo "$output"
}

# _parse_bytes <line>
# "brew: 12345 bytes" のような行から数値を抽出する
_parse_bytes() {
    echo "$1" | grep -oE '[0-9]+' | head -1 || echo "0"
}

# _human_readable <bytes>
# バイト数を人間が読みやすい形式（KiB, MiB, GiB）に変換する
_human_readable() {
    local bytes="$1"
    if [ "$bytes" -ge 1073741824 ]; then
        printf "%.1f GiB" "$(echo "scale=1; $bytes / 1073741824" | bc)"
    elif [ "$bytes" -ge 1048576 ]; then
        printf "%.1f MiB" "$(echo "scale=1; $bytes / 1048576" | bc)"
    elif [ "$bytes" -ge 1024 ]; then
        printf "%.1f KiB" "$(echo "scale=1; $bytes / 1024" | bc)"
    else
        printf "%d bytes" "$bytes"
    fi
}

main() {
    local mode_label="MAINTENANCE"
    [ "${DRY_RUN}" = "1" ] && mode_label="DRY RUN"

    log "=== cache-maintenance: ${mode_label} start ==="

    local cleaners_dir="$SCRIPT_DIR/cleaners"
    local total=0
    local results=()

    # クリーナーを順次実行
    for cleaner in \
        "brew:${cleaners_dir}/brew.sh" \
        "pip:${cleaners_dir}/pip.sh" \
        "app-caches:${cleaners_dir}/caches.sh" \
        "xcode:${cleaners_dir}/xcode.sh"
    do
        local name="${cleaner%%:*}"
        local script="${cleaner#*:}"

        local line
        line=$(_run_cleaner "$name" "$script")
        results+=("$line")

        local bytes
        bytes=$(_parse_bytes "$line")
        total=$(( total + bytes ))
    done

    # サマリー出力
    log "=== results ==="
    for r in "${results[@]}"; do
        log "  $r"
    done

    local human
    human=$(_human_readable "$total")
    log "=== total freed: ${human} ==="

    # macOS 通知（dry-run のときは送らない）
    if [ "${DRY_RUN}" != "1" ] && command -v osascript >/dev/null 2>&1; then
        osascript -e "display notification \"${human} freed\" with title \"cache-maintenance\"" 2>/dev/null || true
    fi

    echo "total: ${total} bytes (${human})"
}

main "$@"
