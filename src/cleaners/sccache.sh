#!/usr/bin/env bash
# cleaners/sccache.sh -- Mozilla sccache キャッシュの LRU クリーンアップ
#
# 対象: ~/Library/Caches/Mozilla.sccache/
# 方針: atime が SCCACHE_MAX_AGE_DAYS 日以上前のファイルを削除する（デフォルト: 14日）
#
# 出力: "sccache: <freed bytes>"
# DRY_RUN=1 のとき: 削除せず 0 バイトを報告する

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

SCCACHE_DIR="${HOME}/Library/Caches/Mozilla.sccache"
SCCACHE_MAX_AGE_DAYS="${SCCACHE_MAX_AGE_DAYS:-14}"

main() {
    if [ ! -d "$SCCACHE_DIR" ]; then
        log "sccache: cache directory not found, skipping"
        echo "sccache: 0 bytes"
        return 0
    fi

    # 古いファイルの一覧を取得（atime が MAX_AGE_DAYS 日以上前）
    local old_files=()
    while IFS= read -r line; do
        [ -n "$line" ] && old_files+=("$line")
    done <<< "$(find "$SCCACHE_DIR" -type f -atime +"${SCCACHE_MAX_AGE_DAYS}" 2>/dev/null)"

    local count="${#old_files[@]}"

    if [ "$count" -eq 0 ]; then
        log "sccache: no files older than ${SCCACHE_MAX_AGE_DAYS} days, skipping"
        echo "sccache: 0 bytes"
        return 0
    fi

    if [ "${DRY_RUN:-0}" = "1" ]; then
        log "[DRY RUN] sccache: would remove ${count} files older than ${SCCACHE_MAX_AGE_DAYS} days"
        echo "sccache: 0 bytes"
        return 0
    fi

    log "sccache: removing ${count} files older than ${SCCACHE_MAX_AGE_DAYS} days"

    # 削除前後のサイズを比較して解放バイト数を計算
    local before after freed
    before=$(du -sk "$SCCACHE_DIR" 2>/dev/null | cut -f1)

    local f
    for f in "${old_files[@]}"; do
        [ -f "$f" ] && rm -f "$f"
    done

    after=$(du -sk "$SCCACHE_DIR" 2>/dev/null | cut -f1)
    after="${after:-0}"
    freed=$(( (before - after) * 1024 ))
    [ "$freed" -lt 0 ] && freed=0

    log "sccache: freed ${freed} bytes (${count} files removed)"
    echo "sccache: ${freed} bytes"
}

main "$@"
