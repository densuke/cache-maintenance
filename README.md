# cache-maintenance

macOS の `~/Library/Caches` や Homebrew・pip・Xcode のキャッシュを安全に定期クリーンアップするツールキットです。

## 特徴

- **DRY RUN 対応** — すべての操作を削除前に確認できる
- **ガードプロセス機能** — 対象アプリが起動中の場合はスキップ
- **パターンファイルで制御** — `caches.allow` / `caches.deny` で対象を柔軟に指定
- **launchd 週次スケジュール** — インストール後は自動実行
- **shellcheck ゲート** — インストール前に静的解析を強制

## 必要なもの

| ツール | 用途 |
|--------|------|
| macOS 12+ | 動作環境 |
| [just](https://github.com/casey/just) | タスクランナー |
| [shellcheck](https://www.shellcheck.net/) | シェルスクリプト静的解析 |
| [bats-core](https://github.com/bats-core/bats-core) | テスト（開発時） |
| Python 3.9+ | launchd インストーラー（stdlib のみ使用） |

Homebrew でまとめてインストールできます:

```bash
brew bundle
```

## クイックスタート

```bash
# 1. まず dry-run で何が削除されるか確認する
just dry-run

# 2. lint + テストを実行して問題がないことを確認
just check

# 3. 設定ファイルを ~/.config/maintenance/ に配置
just install

# 4. launchd に週次ジョブを登録（毎週月曜 3:00 実行）
just install-launchd
```

## just コマンド一覧

```
just lint              shellcheck で全スクリプトをチェック
just test              bats テストを実行（35 テスト）
just check             lint + test をまとめて実行（コミット前に使う）
just dry-run           削除せず実行内容を確認
just run               実際にキャッシュをクリーンアップ
just install           設定ファイルを ~/.config/maintenance/ に配置（lint 付き）
just install-launchd   launchd に週次ジョブを登録（install も実行）
just uninstall-launchd launchd 登録だけ削除する
just uninstall         launchd 登録を削除し設定ディレクトリも消去
```

> `just` を引数なしで実行するとコマンド一覧が表示されます。

## クリーンアップ対象

| クリーナー | 対象 |
|-----------|------|
| `brew` | `brew cleanup --prune=all` |
| `pip` | `pip cache purge` / `uv cache clean` |
| `app-caches` | `~/Library/Caches/` 以下（パターンファイルで制御） |
| `xcode` | DerivedData 全削除、iOS/watchOS DeviceSupport（最新 2 世代を残す） |

## 設定ファイル

インストール後は `~/.config/maintenance/config/` にあります。

```
~/.config/maintenance/
├── config/
│   ├── caches.allow    # 削除許可パターン（アプリごとのガードプロセス付き）
│   └── caches.deny     # 削除禁止パターン（allow より優先）
└── logs/
    └── maintenance.log # 実行ログ
```

設定ファイルの詳細は [docs/configuration.md](docs/configuration.md) を参照してください。

## ログ

`~/.config/maintenance/logs/maintenance.log` に実行履歴が記録されます。

```
2026-03-22 03:00:00 | === cache-maintenance: MAINTENANCE start ===
2026-03-22 03:00:01 | brew: cleaning /Users/you/Library/Caches/Homebrew
2026-03-22 03:00:05 | brew: freed 524288000 bytes
2026-03-22 03:00:05 | app-caches: SKIP (running) com.google.Chrome [Google Chrome]
...
2026-03-22 03:00:10 | === total freed: 1.2 GiB ===
```

## アーキテクチャ

コード構成や新しいクリーナーの追加方法は [docs/architecture.md](docs/architecture.md) を参照してください。

## 改版履歴

[CHANGELOG.md](CHANGELOG.md) を参照してください。

## ライセンス

MIT
