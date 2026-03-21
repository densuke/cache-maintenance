# cache-maintenance

macOS の `~/Library/Caches` 等を安全に定期クリーンアップするツールキット。

## 必要なもの

- macOS 12+
- [just](https://github.com/casey/just)
- [shellcheck](https://www.shellcheck.net/)
- [bats-core](https://github.com/bats-core/bats-core)
- [uv](https://docs.astral.sh/uv/) (Python インストーラー用)

## クイックスタート

```bash
# dry-run で確認
just dry-run

# lint + テスト
just check

# セットアップ (launchd 登録)
just setup
```

## 設定

`~/.config/maintenance/config/` 以下の設定ファイルを編集します。

- `caches.allow` — 削除許可パターン（パターン + ガードプロセス名）
- `caches.deny`  — 削除禁止パターン（allow より優先）

## 開発

```bash
just lint      # shellcheck
just test      # bats テスト
just dry-run   # 実際には削除しない実行確認
```
