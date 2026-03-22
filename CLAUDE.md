# Claude Code 向け注意事項

## コミット前の必須作業

- **CHANGELOG.md を更新する** — 機能追加・バグ修正・設定変更はすべて冒頭に追記すること
- **lint を通す** — `just lint` (shellcheck) が通ることを確認すること
- **テストを通す** — `just test` (bats 35 件) が全パスすることを確認すること
- まとめて確認するには `just check` を使うと便利

## クリーナー追加・変更時のチェックリスト

`docs/architecture.md` の「新しいクリーナーを追加する手順」に詳細な手順があります。
最低限、以下を守ること:

1. `src/cleaners/<name>.sh` を作成
2. **DRY_RUN 対応必須** — `[ "${DRY_RUN:-0}" = "1" ]` で外部コマンドをガードする
3. stdout に `"<name>: N bytes"` 形式で1行出力する（run.sh の集計に使われる）
4. `src/run.sh` のクリーナーリストに追加する
5. `justfile` の `lint` ターゲットに追加する
6. `tests/bats/test_cleaners.bats` に dry-run テストを追加する

## bash 3.2 互換性（重要）

このプロジェクトは macOS の `/bin/bash`（bash 3.2）で動作する必要があります。
以下の bash 4.0+ 機能は**使用禁止**です:

| 禁止事項 | 理由 | 代替手段 |
|---------|------|---------|
| `mapfile` / `readarray` | bash 4.0+ のみ | `while IFS= read -r line; do ... done <<< "$(cmd)"` |
| 関数内で `< <(cmd)` を複数使い、その関数をループで繰り返し呼ぶ | bash 3.2 バグで SIGTRAP (exit 133) が発生 | `<<< "$(cmd)"` で代替 |

### 安全な配列の読み込みパターン（bash 3.2 互換）

```bash
# NG: mapfile (bash 4.0+)
mapfile -t arr < <(some_command)

# OK: while read + here-string
arr=()
while IFS= read -r line; do
    [ -n "$line" ] && arr+=("$line")
done <<< "$(some_command)"
```

### プロセス置換の注意点

```bash
# NG: 関数内に複数の < <(...) があり、その関数をループで呼ぶ（bash 3.2 SIGTRAP）
myfunc() {
    while read -r x; do :; done < <(cmd1)
    while read -r x; do :; done < <(cmd2)  # 2つ目が危険
}
for dir in ...; do myfunc; done   # ループで呼ぶとクラッシュ

# OK: here-string に変換
myfunc() {
    while read -r x; do :; done <<< "$(cmd1)"
    while read -r x; do :; done <<< "$(cmd2)"
}
```

## 設定ファイルの書式

`config/caches.allow` — タブ区切り: `<glob パターン>[TAB<ガードプロセス名>]`
`config/caches.deny`  — glob パターンのみ（プロセス名列不要）

詳細は `docs/configuration.md` を参照。

## テストの書き方

- テストはすべて `DRY_RUN=1` で実行する（実ファイルを削除しない）
- ログ出力（stderr）が `$output` に混入するため、`assert_output` は `--partial` を使う
- 新クリーナーの最低限テスト:

```bash
@test "<name>: dry-run exits 0 and outputs '<name>: 0 bytes'" {
    run bash "$PROJECT_ROOT/src/cleaners/<name>.sh"
    assert_success
    assert_output --partial "<name>: 0 bytes"
}
```
