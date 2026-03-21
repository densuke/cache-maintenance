"""launchd plist テンプレート生成モジュール."""

from __future__ import annotations

import string
from dataclasses import dataclass
from pathlib import Path

PLIST_TEMPLATE = """\
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
  "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>$label</string>
    <key>ProgramArguments</key>
    <array>
        <string>/bin/bash</string>
        <string>$run_sh</string>
    </array>
    <key>StartCalendarInterval</key>
    <dict>
        <key>Weekday</key>
        <integer>$weekday</integer>
        <key>Hour</key>
        <integer>$hour</integer>
        <key>Minute</key>
        <integer>0</integer>
    </dict>
    <key>StandardOutPath</key>
    <string>$log_dir/stdout.log</string>
    <key>StandardErrorPath</key>
    <string>$log_dir/stderr.log</string>
    <key>EnvironmentVariables</key>
    <dict>
        <key>MAINTENANCE_CONFIG_DIR</key>
        <string>$config_dir</string>
        <key>MAINTENANCE_LOG</key>
        <string>$log_dir/maintenance.log</string>
    </dict>
</dict>
</plist>
"""


@dataclass(frozen=True)
class PlistConfig:
    """launchd plist の設定値."""

    label: str
    run_sh: Path
    config_dir: Path
    log_dir: Path
    # StartCalendarInterval: 1=Monday, 7=Sunday (launchd convention)
    weekday: int = 1
    hour: int = 3


def render(cfg: PlistConfig) -> str:
    """PlistConfig から plist XML 文字列を生成する."""
    return string.Template(PLIST_TEMPLATE).substitute(
        label=cfg.label,
        run_sh=str(cfg.run_sh),
        config_dir=str(cfg.config_dir),
        log_dir=str(cfg.log_dir),
        weekday=cfg.weekday,
        hour=cfg.hour,
    )
