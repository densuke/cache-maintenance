#!/usr/bin/env bash
# cleaners/xcode.sh -- Xcode 関連の大容量キャッシュクリーンアップ
#
# 対象:
#   ~/Library/Developer/Xcode/DerivedData  (全削除)
#   ~/Library/Developer/Xcode/iOS DeviceSupport  (最新2世代を残して削除)
#   ~/Library/Developer/Xcode/watchOS DeviceSupport  (最新2世代を残して削除)
#
# 出力: "xcode: <freed bytes>"
# DRY_RUN=1 のとき: 削除せず 0 バイトを報告する

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

XCODE_BASE="$HOME/Library/Developer/Xcode"

# DerivedData を全削除する
_clean_derived_data() {
    local target="$XCODE_BASE/DerivedData"
    [ -d "$target" ] || { echo "0"; return 0; }

    if [ "${DRY_RUN:-0}" = "1" ]; then
        log "[DRY RUN] would remove: DerivedData"
        echo "0"
        return 0
    fi

    log "xcode: cleaning DerivedData"
    measure_freed "$target" safe_rm "$target"
}

# DeviceSupport ディレクトリ内の古い世代を削除する（最新 KEEP_GENERATIONS 世代を残す）
# $1: DeviceSupport ディレクトリのパス
# $2: 残す世代数（デフォルト: 2）
_clean_device_support() {
    local ds_dir="$1"
    local keep="${2:-2}"
    local freed=0

    [ -d "$ds_dir" ] || { echo "0"; return 0; }

    # バージョン番号でソートして古い順に取得し、末尾 keep 個以外を削除
    local total_count old_dirs
    total_count=$(find "$ds_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | wc -l | tr -d ' ')
    local remove_count=$(( total_count - keep ))
    if [ "$remove_count" -le 0 ]; then
        echo "0"
        return 0
    fi
    mapfile -t old_dirs < <(find "$ds_dir" -maxdepth 1 -mindepth 1 -type d 2>/dev/null | sort -V | head -n "$remove_count")

    if [ "${#old_dirs[@]}" -eq 0 ]; then
        echo "0"
        return 0
    fi

    local f
    for old_dir in "${old_dirs[@]}"; do
        [ -d "$old_dir" ] || continue
        if [ "${DRY_RUN:-0}" = "1" ]; then
            log "[DRY RUN] would remove DeviceSupport: $(basename "$old_dir")"
            continue
        fi
        log "xcode: removing old DeviceSupport: $(basename "$old_dir")"
        f=$(measure_freed "$old_dir" safe_rm "$old_dir")
        freed=$(( freed + f ))
    done

    echo "$freed"
}

main() {
    local total=0
    local f

    # Xcode がインストールされているかの簡易確認
    if [ ! -d "$XCODE_BASE" ]; then
        log "xcode: Xcode not found at $XCODE_BASE, skipping"
        echo "xcode: 0 bytes"
        return 0
    fi

    f=$(_clean_derived_data)
    total=$(( total + f ))

    f=$(_clean_device_support "$XCODE_BASE/iOS DeviceSupport")
    total=$(( total + f ))

    f=$(_clean_device_support "$XCODE_BASE/watchOS DeviceSupport")
    total=$(( total + f ))

    log "xcode: freed ${total} bytes"
    echo "xcode: ${total} bytes"
}

main "$@"
