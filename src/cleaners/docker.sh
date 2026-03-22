#!/usr/bin/env bash
# cleaners/docker.sh -- Docker のダングリングイメージ・ビルドキャッシュクリーンアップ
#
# 対象:
#   docker image prune -f   (ダングリングイメージ: どのコンテナにも紐付かないイメージ)
#   docker builder prune -f (BuildKit ビルドキャッシュ)
#
# 注意: 停止中のコンテナが参照するイメージは保護される（--all は使わない）
#
# 出力: "docker: <freed bytes>"
# DRY_RUN=1 のとき: 削除せず 0 バイトを報告する

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

# Docker の出力から解放バイト数を抽出する
# "Total reclaimed space: 1.234GB" のような行を処理する
_parse_docker_freed() {
    local output="$1"
    local size_str
    size_str=$(echo "$output" | grep -i "Total reclaimed space" | grep -oE '[0-9]+(\.[0-9]+)? ?(B|kB|MB|GB|TB)' | tail -1)
    [ -z "$size_str" ] && echo "0" && return 0

    local num unit
    num=$(echo "$size_str" | grep -oE '^[0-9]+(\.[0-9]+)?')
    unit=$(echo "$size_str" | grep -oE '[a-zA-Z]+$')

    case "$unit" in
        B)   echo "$num * 1" | bc | cut -d. -f1 ;;
        kB)  echo "$num * 1024" | bc | cut -d. -f1 ;;
        MB)  echo "$num * 1048576" | bc | cut -d. -f1 ;;
        GB)  echo "$num * 1073741824" | bc | cut -d. -f1 ;;
        TB)  echo "$num * 1099511627776" | bc | cut -d. -f1 ;;
        *)   echo "0" ;;
    esac
}

main() {
    if ! command -v docker >/dev/null 2>&1; then
        log "docker: not installed, skipping"
        echo "docker: 0 bytes"
        return 0
    fi

    # Docker daemon が起動しているか確認
    if ! docker info >/dev/null 2>&1; then
        log "docker: daemon not running, skipping"
        echo "docker: 0 bytes"
        return 0
    fi

    if [ "${DRY_RUN:-0}" = "1" ]; then
        # dry-run: 削除対象のサイズを表示のみ（実際には削除しない）
        log "[DRY RUN] would run: docker image prune -f"
        log "[DRY RUN] would run: docker builder prune -f"
        echo "docker: 0 bytes"
        return 0
    fi

    local total=0
    local out

    # ダングリングイメージの削除
    log "docker: running image prune"
    out=$(docker image prune -f 2>/dev/null || true)
    local img_freed
    img_freed=$(_parse_docker_freed "$out")
    total=$(( total + img_freed ))

    # ビルドキャッシュの削除
    log "docker: running builder prune"
    out=$(docker builder prune -f 2>/dev/null || true)
    local build_freed
    build_freed=$(_parse_docker_freed "$out")
    total=$(( total + build_freed ))

    log "docker: freed ${total} bytes"
    echo "docker: ${total} bytes"
}

main "$@"
