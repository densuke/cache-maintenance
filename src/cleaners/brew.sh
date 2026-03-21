#!/usr/bin/env bash
# cleaners/brew.sh -- Homebrew キャッシュのクリーンアップ
#
# 出力: "brew: <freed bytes>"
# DRY_RUN=1 のとき: brew cleanup を実行せず 0 バイトを報告する

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

main() {
    if ! command -v brew >/dev/null 2>&1; then
        log "brew: not installed, skipping"
        echo "brew: 0 bytes"
        return 0
    fi

    local cache_dir
    cache_dir="$(brew --cache 2>/dev/null)"

    if [ -z "$cache_dir" ] || [ ! -d "$cache_dir" ]; then
        log "brew: cache directory not found, skipping"
        echo "brew: 0 bytes"
        return 0
    fi

    if [ "${DRY_RUN:-0}" = "1" ]; then
        log "[DRY RUN] would run: brew cleanup --prune=all (cache: $cache_dir)"
        echo "brew: 0 bytes"
        return 0
    fi

    log "brew: cleaning $cache_dir"

    local freed
    freed=$(measure_freed "$cache_dir" brew cleanup --prune=all -q)

    log "brew: freed ${freed} bytes"
    echo "brew: ${freed} bytes"
}

main "$@"
