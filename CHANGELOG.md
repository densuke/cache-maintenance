# CHANGELOG

このプロジェクトへの変更を日付・コミット順に記録します。

---

## 2026-03-22

### ドキュメント整備 `a2283cd`

- `README.md` を全面書き直し（特徴・クイックスタート・コマンド一覧・ログ例）
- `docs/configuration.md` 新規作成
  - `caches.allow` / `caches.deny` の書式・glob パターン・ガードプロセスリファレンス
  - 判定ロジックのフロー図
  - 環境変数一覧・launchd スケジュールカスタマイズ方法
- `docs/architecture.md` 新規作成
  - ディレクトリ構成・処理フロー・各モジュールの説明
  - 新しいクリーナーを追加する手順（npm を例に Step 1〜5）
  - bash 3.2 互換対応の注意書き

---

### Brewfile 追加・install ゲート強化 `3dd4510`

- `Brewfile` 新規作成（`just`・`shellcheck`・`bats-core` を宣言）
  - `brew bundle` で必要ツールを一括インストール可能に
- `just install` が実行前に `shellcheck` を強制実行するよう変更
  - lint 失敗時は設定ファイルのコピーを中断

---

### 統合テスト追加 `7b6f3d0`

- `tests/bats/test_cleaners.bats` 新規作成（9 件）
  - **brew** dry-run が exit 0 で `brew: 0 bytes` を返すことを確認
  - **pip** dry-run が exit 0 で `pip: 0 bytes` を返すことを確認
  - **app-caches** dry-run（プロジェクト config / 存在しない config dir）
  - **xcode** dry-run が exit 0 で `xcode: 0 bytes` を返すことを確認
  - **run.sh** dry-run: 全クリーナーの出力が含まれること、二重ログがないことを確認
- `justfile` の `test` ターゲットに `test_cleaners.bats` を追加（合計 35 件）

---

### Python インストーラー追加 `9ac155c`

- `installer/install.py` 新規作成（argparse CLI）
  - `install` / `uninstall` / `status` サブコマンド
  - `--dry-run` で plist 内容を確認してから登録可能
  - `--weekday N`（1=月〜7=日）・`--hour H` でスケジュールを指定
- `installer/launchd.py` 新規作成
  - `~/Library/LaunchAgents/com.cache-maintenance.plist` への配置
  - `launchctl load` / `unload` を制御
- `installer/template.py` 新規作成
  - `string.Template` で plist XML を生成（外部依存なし）

---

### justfile 追加 `0ce8c63`

- `justfile` 新規作成。以下のタスクを定義:
  - `lint` — shellcheck で全スクリプトを検査
  - `test` — bats テストを実行
  - `check` — lint + test をまとめて実行
  - `dry-run` — `DRY_RUN=1` でメンテナンスを実行（削除なし）
  - `run` — 実際にキャッシュを削除
  - `install` / `install-launchd` / `uninstall-launchd` / `uninstall`

---

### オーケストレーター追加・bash 3.2 バグ修正 `eb786fd`

- `src/run.sh` 新規作成
  - 全クリーナーを順次実行し、解放バイト数の合計をサマリー出力
  - `DRY_RUN=0` のとき macOS 通知を送信
  - `~/.config/maintenance/config` 未インストール時はプロジェクト内 `config/` をフォールバック
- **バグ修正: bash 3.2 SIGTRAP (exit 133)**
  - `src/lib/config.sh` の `should_clean()` / `get_guard_process()` で
    `< <(process_substitution)` を複数使用していたことが原因
  - macOS `/bin/bash`（version 3.2）では、関数内に process substitution が
    2 つ以上あり、その関数をループ内で繰り返し呼ぶと SIGTRAP が発生する
  - `<<< "$(cmd)"` へ書き換えることで解消
- **バグ修正: 二重ログ**
  - `_run_cleaner` の `2>>"$MAINTENANCE_LOG"` を `2>/dev/null` に変更
  - `log()` がすでに `tee -a` でファイルに書き込んでいるため、stderr の
    リダイレクトは不要だった

---

### Xcode クリーナー追加 `8603f09`

- `src/cleaners/xcode.sh` 新規作成
  - **DerivedData** — ビルド成果物を全削除
    - 対象: `~/Library/Developer/Xcode/DerivedData/`
  - **iOS DeviceSupport** — 最新 2 世代を残して古いものを削除
    - 対象: `~/Library/Developer/Xcode/iOS DeviceSupport/`
  - **watchOS DeviceSupport** — 最新 2 世代を残して古いものを削除
    - 対象: `~/Library/Developer/Xcode/watchOS DeviceSupport/`
  - Xcode 未インストール時はスキップ

---

### ~/Library/Caches クリーナー追加 `d11f10f`

- `src/cleaners/caches.sh` 新規作成
  - `caches.allow` / `caches.deny` のパターンで削除対象を制御
  - ガードプロセスが起動中のアプリはスキップ（例: Chrome 実行中は Chrome キャッシュを削除しない）
  - 対象: `~/Library/Caches/` 以下のディレクトリ（デフォルト設定）
    - Chrome、Edge、Safari、VSCode、JetBrains 系、Spotify、pip、uv など
    - iCloud 関連（bird、cloudphotod、CloudKit）は deny で保護
- `src/lib/common.sh` バグ修正: `measure_freed` が `DRY_RUN=1` のとき
  外部コマンドを実行しないよう修正

---

### pip / uv クリーナー追加 `316f8b2`

- `src/cleaners/pip.sh` 新規作成
  - **pip キャッシュ** — `pip cache purge` を実行
    - 対象: `~/Library/Caches/pip/`
    - pip3 / pip を自動検出
  - **uv キャッシュ** — `uv cache clean` を実行
    - 対象: `uv cache dir` の出力先（インストール済みの場合のみ）

---

### Homebrew クリーナー追加 `6faabe6`

- `src/cleaners/brew.sh` 新規作成
  - `brew cleanup --prune=all` を実行
  - キャッシュディレクトリを `brew --cache` で動的に取得
  - 対象: Homebrew のダウンロードキャッシュ（`~/Library/Caches/Homebrew/` など）
  - brew 未インストール時はスキップ

---

### 設定テンプレート・config.sh 追加 `1695d1c`

- `src/lib/config.sh` 新規作成
  - `read_patterns`・`should_clean`・`get_guard_process`・`is_app_running` を定義
- `config/caches.allow` 新規作成（デフォルトパターン）
  - ブラウザ: Chrome、Edge、Safari
  - 開発ツール: VSCode（Electron）、JetBrains 系（java）
  - メディア: Spotify
  - パッケージマネージャ: pip、uv
- `config/caches.deny` 新規作成（デフォルト保護パターン）
  - iCloud 関連: com.apple.bird、com.apple.cloudphotod、CloudKit
  - システム: com.apple.nsservicescache

---

### リポジトリ初期化・共通ライブラリ `68cdd30`

- プロジェクト初期化（`.gitignore`・`.gitmodules`・`README.md`）
- `src/lib/common.sh` 新規作成
  - `log()` — タイムスタンプ付きで `MAINTENANCE_LOG` と stderr に出力
  - `safe_rm()` — `DRY_RUN=1` のとき削除せずログのみ出力
  - `measure_freed()` — コマンド前後のディスク使用量を比較して解放バイト数を返す
- bats-core・bats-support・bats-assert を Git サブモジュールとして追加
- `tests/bats/test_common.bats` 新規作成（11 件）
