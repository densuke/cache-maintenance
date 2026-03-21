# cache-maintenance justfile
#
# 使い方:
#   just lint          # shellcheck で全スクリプトをチェック
#   just test          # bats テストを実行
#   just dry-run       # dry-run でメンテナンスを実行（削除しない）
#   just run           # 実際にメンテナンスを実行
#   just install       # ~/.config/maintenance に設定を配置して launchd に登録
#   just uninstall     # launchd から削除して設定を消去

set shell := ["bash", "-euo", "pipefail", "-c"]

BATS        := "./tests/bats/libs/bats-core/bin/bats"
BATS_TESTS  := "./tests/bats"
SRC         := "./src"
CONFIG_DIR  := "$HOME/.config/maintenance"

# デフォルトターゲット: ヘルプを表示
default:
    @just --list

# shellcheck で全スクリプトをチェック
lint:
    @echo "=== shellcheck ==="
    shellcheck -x \
        {{SRC}}/run.sh \
        {{SRC}}/lib/common.sh \
        {{SRC}}/lib/config.sh \
        {{SRC}}/cleaners/brew.sh \
        {{SRC}}/cleaners/pip.sh \
        {{SRC}}/cleaners/caches.sh \
        {{SRC}}/cleaners/xcode.sh
    @echo "shellcheck: OK"

# bats テストを実行
test:
    @echo "=== bats tests ==="
    {{BATS}} {{BATS_TESTS}}/test_common.bats {{BATS_TESTS}}/test_config.bats

# lint + test まとめて実行
check: lint test

# dry-run モードでメンテナンスを実行（削除しない）
dry-run:
    DRY_RUN=1 bash {{SRC}}/run.sh

# 実際にメンテナンスを実行（削除する）
run:
    bash {{SRC}}/run.sh

# ~/.config/maintenance に設定を配置する
install:
    @echo "=== installing config ==="
    mkdir -p {{CONFIG_DIR}}/config
    mkdir -p {{CONFIG_DIR}}/logs
    cp -n config/caches.allow {{CONFIG_DIR}}/config/caches.allow || true
    cp -n config/caches.deny  {{CONFIG_DIR}}/config/caches.deny  || true
    @echo "Config installed to {{CONFIG_DIR}}/config/"
    @echo "Run 'just install-launchd' to register the launchd job"

# launchd に週次ジョブを登録する
install-launchd: install
    python3 installer/install.py install

# launchd から登録を削除する
uninstall-launchd:
    python3 installer/install.py uninstall

# 設定ごとアンインストール（launchd 含む）
uninstall: uninstall-launchd
    rm -rf {{CONFIG_DIR}}
    @echo "Uninstalled."
