# アーキテクチャ

## ディレクトリ構成

```
cache-maintenance/
├── Brewfile                    # 必要な Homebrew パッケージ
├── justfile                    # タスクランナー定義
├── README.md
├── config/                     # デフォルト設定テンプレート
│   ├── caches.allow            # 削除許可パターン（タブ区切り）
│   └── caches.deny             # 削除禁止パターン
├── docs/                       # ドキュメント
│   ├── architecture.md         # このファイル
│   └── configuration.md        # 設定ファイルリファレンス
├── installer/                  # Python インストーラー
│   ├── install.py              # CLI エントリーポイント（argparse）
│   ├── launchd.py              # launchctl 操作
│   └── template.py             # plist テンプレート生成
├── src/
│   ├── run.sh                  # オーケストレーター（全クリーナーを呼ぶ）
│   ├── lib/
│   │   ├── common.sh           # 共通ユーティリティ（log / safe_rm / measure_freed）
│   │   └── config.sh           # パターンファイル読み込み・削除判定
│   └── cleaners/
│       ├── brew.sh             # Homebrew キャッシュ
│       ├── pip.sh              # pip / uv キャッシュ
│       ├── caches.sh           # ~/Library/Caches（パターン制御）
│       └── xcode.sh            # Xcode DerivedData / DeviceSupport
└── tests/
    └── bats/
        ├── test_common.bats    # common.sh のユニットテスト（11 件）
        ├── test_config.bats    # config.sh のユニットテスト（15 件）
        └── test_cleaners.bats  # 各クリーナーの統合テスト（9 件）
```

---

## 処理フロー

```
just dry-run / just run
        │
        └─► src/run.sh
                │
                ├─► cleaners/brew.sh    ──► "brew: N bytes"
                ├─► cleaners/pip.sh     ──► "pip: N bytes"
                ├─► cleaners/caches.sh  ──► "app-caches: N bytes"
                └─► cleaners/xcode.sh   ──► "xcode: N bytes"
                        │
                        └─► 合計を集計してサマリー出力
                            macOS 通知（DRY_RUN=0 のみ）
```

各クリーナーは `stdout` に `"<name>: <bytes> bytes"` 形式で結果を返し、
ログは `stderr` に出力します（`src/lib/common.sh` の `log()` 関数）。
オーケストレーター（`run.sh`）は `stdout` だけを受け取り合計を計算します。

---

## 主要モジュールの説明

### src/lib/common.sh

全クリーナーから `source` されるユーティリティ集。

| 関数 | 説明 |
|------|------|
| `log <msg>` | タイムスタンプ付きでログファイルと stderr に出力 |
| `safe_rm <path>` | `DRY_RUN=1` のとき削除せずログだけ出す |
| `measure_freed <path> <cmd> [args...]` | コマンド実行前後のディスク使用量を比較し解放バイト数を返す |

#### measure_freed の動き

```bash
before = du -sk "$path"
<cmd> を実行
after  = du -sk "$path"
freed  = (before - after) * 1024   # KB→bytes
```

`DRY_RUN=1` のときはコマンドを実行せず `0` を返します。

---

### src/lib/config.sh

`~/Library/Caches` の各ディレクトリを削除してよいか判定します。

| 関数 | 説明 |
|------|------|
| `read_patterns <file>` | 設定ファイルを読み込み、コメント・空行を除いて出力 |
| `should_clean <path>` | deny にマッチしない かつ allow にマッチする場合 0 を返す |
| `get_guard_process <name>` | allow ファイルの 2 列目（ガードプロセス名）を返す |
| `is_app_running <pattern>` | `pgrep -if` でプロセスが起動中かどうかを返す |

> **bash 3.2 互換に注意**: macOS の `/bin/bash` は 3.2 と古いため、
> `should_clean` と `get_guard_process` 内の `while ... done < <(...)` は
> `<<< "$(cmd)"` に書き換えています。
> 複数の process substitution を関数内でループ使用すると SIGTRAP で落ちる
> bash 3.2 のバグを回避するためです。

---

### src/cleaners/

各クリーナーは独立したスクリプトで、単独でも実行できます。

```bash
DRY_RUN=1 bash src/cleaners/brew.sh
# brew: 0 bytes
```

**出力規約**:
- `stdout`: `"<name>: <bytes> bytes"` の 1 行（run.sh が集計に使う）
- `stderr`: `log()` によるログメッセージ

**DRY_RUN 対応規約**:
- 外部コマンドを呼ぶ前に `[ "${DRY_RUN:-0}" = "1" ] && ...` でガードする
- `measure_freed` は `DRY_RUN=1` のとき自動でスキップするが、
  `brew cleanup` や `pip cache purge` のような外部コマンドは
  **クリーナー側でも** 早期リターンしてから `measure_freed` を呼ぶ

---

## 新しいクリーナーを追加する手順

例として `npm` のキャッシュを削除するクリーナーを追加します。

### 1. クリーナースクリプトを作成

`src/cleaners/npm.sh` を作成します。

```bash
#!/usr/bin/env bash
# cleaners/npm.sh -- npm キャッシュのクリーンアップ
#
# 出力: "npm: <freed bytes>"
# DRY_RUN=1 のとき: 削除せず 0 バイトを報告する

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=src/lib/common.sh
source "$SCRIPT_DIR/../lib/common.sh"

main() {
    command -v npm >/dev/null 2>&1 || {
        log "npm: not installed, skipping"
        echo "npm: 0 bytes"
        return 0
    }

    local cache_dir
    cache_dir="$(npm config get cache 2>/dev/null)"
    [ -d "$cache_dir" ] || {
        log "npm: cache directory not found, skipping"
        echo "npm: 0 bytes"
        return 0
    }

    if [ "${DRY_RUN:-0}" = "1" ]; then
        log "[DRY RUN] would run: npm cache clean --force (cache: $cache_dir)"
        echo "npm: 0 bytes"
        return 0
    fi

    log "npm: cleaning $cache_dir"
    local freed
    freed=$(measure_freed "$cache_dir" npm cache clean --force)
    log "npm: freed ${freed} bytes"
    echo "npm: ${freed} bytes"
}

main "$@"
```

### 2. run.sh にクリーナーを追加

`src/run.sh` の `main()` 内のクリーナーリストに追加します。

```bash
for cleaner in \
    "brew:${cleaners_dir}/brew.sh" \
    "pip:${cleaners_dir}/pip.sh" \
    "npm:${cleaners_dir}/npm.sh" \    # ← 追加
    "app-caches:${cleaners_dir}/caches.sh" \
    "xcode:${cleaners_dir}/xcode.sh"
do
```

### 3. テストを追加

`tests/bats/test_cleaners.bats` に dry-run テストを追加します。

```bash
@test "npm: dry-run exits 0 and outputs 'npm: 0 bytes'" {
    run bash "$PROJECT_ROOT/src/cleaners/npm.sh"
    assert_success
    assert_output --partial "npm: 0 bytes"
}
```

### 4. lint とテストを実行

```bash
just check
```

### 5. justfile の lint ターゲットにスクリプトを追加

`justfile` の `lint` レシピに新しいスクリプトを追加します。

```
shellcheck -x \
    ...
    {{SRC}}/cleaners/npm.sh    # ← 追加
```

---

## インストーラーの仕組み

```
installer/
├── install.py      # argparse CLI (install / uninstall / status)
├── launchd.py      # launchctl load/unload / plist 配置
└── template.py     # string.Template で plist XML を生成
```

### launchd plist の配置先

```
~/Library/LaunchAgents/com.cache-maintenance.plist
```

`launchctl load` で登録すると、指定した曜日・時刻に自動実行されます。

### plist に設定される環境変数

plist の `EnvironmentVariables` セクションで以下が渡されます:

| 変数 | 値 |
|------|----|
| `MAINTENANCE_CONFIG_DIR` | `~/.config/maintenance/config` |
| `MAINTENANCE_LOG` | `~/.config/maintenance/logs/maintenance.log` |

---

## テスト構成

| ファイル | 対象 | テスト数 |
|---------|------|---------|
| `test_common.bats` | `lib/common.sh` の各関数 | 11 件 |
| `test_config.bats` | `lib/config.sh` の各関数 | 15 件 |
| `test_cleaners.bats` | 各クリーナー・run.sh（dry-run） | 9 件 |

すべて `DRY_RUN=1` で実行するため、テスト中に実際のファイルが削除されることはありません。

```bash
# テストのみ実行
just test

# lint + テストをまとめて実行
just check
```
