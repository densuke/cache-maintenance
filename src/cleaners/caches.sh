#!/usr/bin/env bash
# cleaners/caches.sh -- ~/Library/Caches のパターンベースクリーンアップ
#
# 出力: "app-caches: <freed bytes>"
# DRY_RUN=1 のとき: 削除せず 0 バイトを報告する
# 設定: MAINTENANCE_CONFIG_DIR/caches.allow, caches.deny を参照する

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"
# shellcheck source=src/lib/config.sh
source "$SCRIPT_DIR/../lib/config.sh"

main() {
    local cache_root="$HOME/Library/Caches"
    local freed=0
    local skipped=0
    local f name guard

    if [ ! -d "$cache_root" ]; then
        log "app-caches: $cache_root not found, skipping"
        echo "app-caches: 0 bytes"
        return 0
    fi

    for dir in "$cache_root"/*/; do
        # ディレクトリでない場合はスキップ
        [ -d "$dir" ] || continue

        name="$(basename "$dir")"

        # allow/deny パターン判定
        if ! should_clean "$dir"; then
            continue
        fi

        # ガードプロセスチェック
        guard="$(get_guard_process "$name")"
        if is_app_running "$guard"; then
            log "app-caches: SKIP (running) $name [$guard]"
            skipped=$(( skipped + 1 ))
            continue
        fi

        if [ "${DRY_RUN:-0}" = "1" ]; then
            log "[DRY RUN] would remove: $name"
            continue
        fi

        log "app-caches: removing $name"
        f=$(measure_freed "$dir" safe_rm "$dir")
        freed=$(( freed + f ))
    done

    [ "$skipped" -gt 0 ] && log "app-caches: skipped ${skipped} entries (app running)"
    log "app-caches: freed ${freed} bytes"
    echo "app-caches: ${freed} bytes"
}

main "$@"
