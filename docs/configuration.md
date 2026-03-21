# 設定ファイルリファレンス

`~/Library/Caches/` 以下のどのディレクトリを削除するかは、テキストファイルのパターンで制御します。

## ファイルの場所

インストール後は `~/.config/maintenance/config/` に配置されます。
リポジトリ内の `config/` ディレクトリがデフォルト値のテンプレートです。

```
~/.config/maintenance/config/
├── caches.allow    # 削除してよいディレクトリのパターン
└── caches.deny     # 削除してはいけないディレクトリのパターン（allow より優先）
```

## 判定ロジック

各ディレクトリは以下の順序で評価されます。

```
~/Library/Caches/<name>/
         │
         ▼
  deny にマッチ？ ──Yes──► スキップ（削除しない）
         │No
         ▼
  allow にマッチ？ ──No───► スキップ（削除しない）
         │Yes
         ▼
  ガードプロセスが
  起動中？ ────────Yes──► スキップ（アプリ実行中）
         │No
         ▼
       削除
```

> **ポイント**: allow リストにないディレクトリは一切削除されません。
> 未知のディレクトリが削除されることはないので、初期状態は保守的です。

---

## caches.allow — 削除許可パターン

### 書式

```
<glob パターン>[TAB<ガードプロセス名>]
```

- 列の区切りは **タブ文字（`\t`）**
- ガードプロセス名は省略可能（省略時はプロセスチェックなし）
- `#` で始まる行はコメント、空行は無視

### glob パターン

`~/Library/Caches/` **直下のディレクトリ名**に対してマッチします。
bash の `case` 文と同じグロブ構文（`*`、`?`、`[...]`）が使えます。

| パターン例 | マッチ例 |
|-----------|---------|
| `com.google.Chrome` | `com.google.Chrome` のみ |
| `com.jetbrains.*` | `com.jetbrains.idea`、`com.jetbrains.goland` など |
| `io.nwjs.*` | `io.nwjs.xxx` など |

### ガードプロセス名

`pgrep -if <名前>` に渡す文字列です。大文字・小文字を区別しません。
起動中と判定された場合はそのディレクトリをスキップします。

| ガードプロセス名例 | 何をチェックするか |
|------------------|------------------|
| `Google Chrome` | プロセス名に "Google Chrome" を含む |
| `Electron` | Electron 製アプリ全般（VSCode など） |
| `Safari` | Safari |
| `java` | JVM（IntelliJ IDEA など） |
| `Spotify` | Spotify |

### 記述例

```
# ブラウザ（起動中はスキップ）
com.google.Chrome	Google Chrome
com.microsoft.Edge	Microsoft Edge
com.apple.Safari	Safari

# 開発ツール
com.microsoft.VSCode	Electron
com.jetbrains.*	java

# プロセスチェック不要（キャッシュだけのディレクトリ）
pip
uv
io.nwjs.*
```

### 新しいアプリを追加する方法

1. `~/Library/Caches/` で対象ディレクトリ名を確認する
2. `just dry-run` で削除予定を確認する
3. `caches.allow` に追記して再度 `just dry-run` で意図通りか確認する

```bash
# キャッシュディレクトリを一覧する
ls ~/Library/Caches/

# dry-run で確認
just dry-run
```

---

## caches.deny — 削除禁止パターン

### 書式

```
<glob パターン>
```

- タブ区切りの 2 列目（プロセス名）は不要
- `allow` にマッチしていても、`deny` にマッチするディレクトリは**削除されません**

### 使いどころ

- システムやクラウド同期に関わるディレクトリを誤って削除しないための安全装置
- `com.jetbrains.*` を allow に入れながら特定の製品だけ除外したい場合

### 記述例

```
# iCloud 関連（削除すると同期に影響する）
com.apple.bird
com.apple.cloudphotod
CloudKit

# システムキャッシュ
com.apple.nsservicescache
```

### deny の優先順位

`allow` と `deny` の両方にマッチするディレクトリは**必ず skip** されます。
たとえば `com.jetbrains.*` を allow に、`com.jetbrains.idea` を deny に書けば、
IntelliJ IDEA だけ除外して他の JetBrains 製品のキャッシュは削除できます。

---

## 環境変数

スクリプトの動作を環境変数で上書きできます。

| 変数名 | デフォルト値 | 説明 |
|--------|-------------|------|
| `DRY_RUN` | `0` | `1` にすると削除を行わずログだけ出力 |
| `MAINTENANCE_CONFIG_DIR` | `~/.config/maintenance/config` | パターンファイルのディレクトリ |
| `MAINTENANCE_LOG` | `~/.config/maintenance/logs/maintenance.log` | ログファイルのパス |

### 一時的に別の設定ファイルで実行する例

```bash
MAINTENANCE_CONFIG_DIR=/path/to/other/config just dry-run
```

### dry-run の実行

```bash
# 環境変数で指定する場合
DRY_RUN=1 bash src/run.sh

# just コマンドで実行する場合（推奨）
just dry-run
```

---

## launchd スケジュールのカスタマイズ

デフォルトは **毎週月曜日 午前 3:00** に実行します。
`just install-launchd` 実行前に変更するには、直接 `installer/install.py` を呼びます。

```bash
# 毎週土曜日（weekday=6）の午前 2 時に変更する例
python3 installer/install.py install --weekday 6 --hour 2
```

| オプション | 説明 | デフォルト |
|-----------|------|-----------|
| `--weekday N` | 実行曜日（1=月〜7=日） | `1`（月曜） |
| `--hour H` | 実行時刻（0〜23） | `3` |
| `--dry-run` | plist 内容を表示するだけで登録しない | — |

設定を変更したい場合は一度アンインストールして再登録します。

```bash
just uninstall-launchd
python3 installer/install.py install --weekday 6 --hour 2
```
