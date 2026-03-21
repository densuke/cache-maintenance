"""launchd plist 管理: インストール・アンインストール・ステータス確認."""

from __future__ import annotations

import subprocess
import sys
from pathlib import Path

from template import PlistConfig, render

LABEL = "com.cache-maintenance"
PLIST_NAME = f"{LABEL}.plist"


def plist_path() -> Path:
    """ユーザー LaunchAgents ディレクトリへの plist パスを返す."""
    return Path.home() / "Library" / "LaunchAgents" / PLIST_NAME


def is_installed() -> bool:
    """plist ファイルが存在するかどうかを返す."""
    return plist_path().exists()


def is_loaded() -> bool:
    """launchctl に読み込まれているかどうかを確認する."""
    result = subprocess.run(
        ["launchctl", "list", LABEL],
        capture_output=True,
        check=False,
    )
    return result.returncode == 0


def install(cfg: PlistConfig, dry_run: bool = False) -> None:
    """plist を生成して LaunchAgents に配置し launchctl load する.

    Args:
        cfg: plist 生成に使う設定値
        dry_run: True のとき実際の変更を行わず内容を表示する
    """
    dest = plist_path()
    content = render(cfg)

    if dry_run:
        print(f"[DRY RUN] would write: {dest}")
        print(content)
        print(f"[DRY RUN] would run: launchctl load {dest}")
        return

    dest.parent.mkdir(parents=True, exist_ok=True)

    if is_loaded():
        print(f"Unloading existing job: {LABEL}")
        subprocess.run(["launchctl", "unload", str(dest)], check=False)

    dest.write_text(content, encoding="utf-8")
    print(f"Written: {dest}")

    subprocess.run(["launchctl", "load", str(dest)], check=True)
    print(f"Loaded: {LABEL}")


def uninstall(dry_run: bool = False) -> None:
    """launchctl から削除し plist ファイルを消去する.

    Args:
        dry_run: True のとき実際の変更を行わず操作内容を表示する
    """
    dest = plist_path()

    if not is_installed():
        print(f"Not installed: {dest}", file=sys.stderr)
        return

    if dry_run:
        print(f"[DRY RUN] would run: launchctl unload {dest}")
        print(f"[DRY RUN] would remove: {dest}")
        return

    if is_loaded():
        subprocess.run(["launchctl", "unload", str(dest)], check=False)
        print(f"Unloaded: {LABEL}")

    dest.unlink()
    print(f"Removed: {dest}")


def status() -> None:
    """インストール状態を表示する."""
    dest = plist_path()
    installed = is_installed()
    loaded = is_loaded() if installed else False

    print(f"Plist:     {dest}")
    print(f"Installed: {'yes' if installed else 'no'}")
    print(f"Loaded:    {'yes' if loaded else 'no'}")
