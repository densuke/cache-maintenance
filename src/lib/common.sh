#!/usr/bin/env bash
# common.sh — 全クリーナーが共有するユーティリティ関数
#
# 使い方: source "$(dirname "$0")/../lib/common.sh"
#
# 環境変数:
#   DRY_RUN          1 のとき削除を行わずログのみ出力（デフォルト: 0）
#   MAINTENANCE_LOG  ログファイルのパス（デフォルト: ~/.config/maintenance/logs/maintenance.log）

MAINTENANCE_LOG="${MAINTENANCE_LOG:-$HOME/.config/maintenance/logs/maintenance.log}"

# ログディレクトリを保証する（source 時点で作成しない。log() 呼び出し時に遅延作成）
_ensure_log_dir() {
    local log_dir
    log_dir="$(dirname "$MAINTENANCE_LOG")"
    mkdir -p "$log_dir"
}

# log <message>
# タイムスタンプ付きでログファイルと stderr の両方に出力する
log() {
    _ensure_log_dir
    local msg
    msg="$(date '+%Y-%m-%d %H:%M:%S') | $*"
    echo "$msg" | tee -a "$MAINTENANCE_LOG" >&2
}

# safe_rm <path>
# DRY_RUN=1 のときは削除せずにログのみ出力する
# DRY_RUN が未設定または 0 のときは rm -rf を実行する
safe_rm() {
    local target="$1"
    [ -z "$target" ] && return 0

    if [ "${DRY_RUN:-0}" = "1" ]; then
        log "[DRY RUN] would remove: $target"
        return 0
    fi

    rm -rf "$target"
}

# measure_freed <path> <command> [args...]
# command を実行する前後の path のディスク使用量を比較し、
# 解放されたバイト数を stdout に出力する。
# DRY_RUN=1 のときはコマンドを実行せず 0 を返す。
measure_freed() {
    local target="$1"
    shift

    # 対象が存在しない場合は 0
    if [ ! -e "$target" ]; then
        echo "0"
        return 0
    fi

    # DRY_RUN=1 のときはコマンドを実行せず 0 を返す
    if [ "${DRY_RUN:-0}" = "1" ]; then
        # dry-run でもコマンド自体は呼び出す（safe_rm が内部でスキップする）
        "$@" 2>/dev/null
        echo "0"
        return 0
    fi

    local before after freed
    before=$(du -sk "$target" 2>/dev/null | cut -f1)
    "$@" 2>/dev/null
    after=$(du -sk "$target" 2>/dev/null | cut -f1)
    after="${after:-0}"
    freed=$(( (before - after) * 1024 ))
    # 負値（誤差）は 0 に丸める
    [ "$freed" -lt 0 ] && freed=0
    echo "$freed"
}
