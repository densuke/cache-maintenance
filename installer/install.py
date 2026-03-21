#!/usr/bin/env python3
"""cache-maintenance インストーラー CLI.

使い方:
    python3 installer/install.py install   [--dry-run]
    python3 installer/install.py uninstall [--dry-run]
    python3 installer/install.py status
"""

from __future__ import annotations

import argparse
import sys
from pathlib import Path

# installer/ ディレクトリを sys.path に追加（直接実行時のため）
sys.path.insert(0, str(Path(__file__).parent))

import launchd  # noqa: E402
from template import PlistConfig  # noqa: E402

# プロジェクトルートから相対パスでスクリプトを解決する
_PROJECT_ROOT = Path(__file__).parent.parent.resolve()
_DEFAULT_RUN_SH = _PROJECT_ROOT / "src" / "run.sh"
_DEFAULT_CONFIG_DIR = Path.home() / ".config" / "maintenance" / "config"
_DEFAULT_LOG_DIR = Path.home() / ".config" / "maintenance" / "logs"


def _build_cfg(args: argparse.Namespace) -> PlistConfig:
    return PlistConfig(
        label=launchd.LABEL,
        run_sh=_DEFAULT_RUN_SH,
        config_dir=_DEFAULT_CONFIG_DIR,
        log_dir=_DEFAULT_LOG_DIR,
        weekday=args.weekday,
        hour=args.hour,
    )


def cmd_install(args: argparse.Namespace) -> int:
    """install サブコマンド."""
    cfg = _build_cfg(args)

    if not cfg.run_sh.exists():
        print(f"Error: run.sh not found at {cfg.run_sh}", file=sys.stderr)
        return 1

    print(f"Installing cache-maintenance launchd job...")
    print(f"  run.sh:     {cfg.run_sh}")
    print(f"  config dir: {cfg.config_dir}")
    print(f"  log dir:    {cfg.log_dir}")
    print(f"  schedule:   weekday={cfg.weekday}, hour={cfg.hour}:00")

    launchd.install(cfg, dry_run=args.dry_run)
    return 0


def cmd_uninstall(args: argparse.Namespace) -> int:
    """uninstall サブコマンド."""
    launchd.uninstall(dry_run=args.dry_run)
    return 0


def cmd_status(_args: argparse.Namespace) -> int:
    """status サブコマンド."""
    launchd.status()
    return 0


def build_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(
        description="cache-maintenance launchd インストーラー",
        formatter_class=argparse.RawDescriptionHelpFormatter,
    )

    sub = parser.add_subparsers(dest="command", required=True)

    # install
    p_install = sub.add_parser("install", help="launchd ジョブを登録する")
    p_install.add_argument(
        "--dry-run",
        action="store_true",
        help="実際の変更を行わず内容だけ表示する",
    )
    p_install.add_argument(
        "--weekday",
        type=int,
        default=1,
        metavar="N",
        help="実行曜日 (1=月〜7=日, デフォルト: 1=月曜)",
    )
    p_install.add_argument(
        "--hour",
        type=int,
        default=3,
        metavar="H",
        help="実行時刻 (0-23, デフォルト: 3)",
    )
    p_install.set_defaults(func=cmd_install)

    # uninstall
    p_uninstall = sub.add_parser("uninstall", help="launchd ジョブを削除する")
    p_uninstall.add_argument(
        "--dry-run",
        action="store_true",
        help="実際の変更を行わず操作内容だけ表示する",
    )
    p_uninstall.set_defaults(func=cmd_uninstall)

    # status
    p_status = sub.add_parser("status", help="インストール状態を表示する")
    p_status.set_defaults(func=cmd_status)

    return parser


def main() -> None:
    parser = build_parser()
    args = parser.parse_args()
    sys.exit(args.func(args))


if __name__ == "__main__":
    main()
