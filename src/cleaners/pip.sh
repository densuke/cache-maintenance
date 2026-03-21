#!/usr/bin/env bash
# cleaners/pip.sh -- pip / uv キャッシュのクリーンアップ
#
# 出力: "pip: <freed bytes>"
# DRY_RUN=1 のとき: purge を実行せず 0 バイトを報告する

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

_clean_pip() {
    local pip_cache="$HOME/Library/Caches/pip"
    command -v pip3 >/dev/null 2>&1 || command -v pip >/dev/null 2>&1 || return 0
    [ -d "$pip_cache" ] || return 0

    if [ "${DRY_RUN:-0}" = "1" ]; then
        log "[DRY RUN] would run: pip cache purge (cache: $pip_cache)"
        echo "0"
        return 0
    fi

    local cmd
    cmd=$(command -v pip3 2>/dev/null || command -v pip)

    log "pip: cleaning $pip_cache"
    measure_freed "$pip_cache" "$cmd" cache purge -q
}

_clean_uv() {
    command -v uv >/dev/null 2>&1 || return 0

    local uv_cache
    uv_cache="$(uv cache dir 2>/dev/null)" || return 0
    [ -d "$uv_cache" ] || return 0

    if [ "${DRY_RUN:-0}" = "1" ]; then
        log "[DRY RUN] would run: uv cache clean (cache: $uv_cache)"
        echo "0"
        return 0
    fi

    log "uv: cleaning $uv_cache"
    measure_freed "$uv_cache" uv cache clean -q
}

main() {
    local total=0
    local f

    f=$(_clean_pip);  total=$(( total + f ))
    f=$(_clean_uv);   total=$(( total + f ))

    log "pip: freed ${total} bytes"
    echo "pip: ${total} bytes"
}

main "$@"
