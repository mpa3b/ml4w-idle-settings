#!/usr/bin/env python3
"""Read and patch the four hypridle listener timeouts without touching the rest
of hypridle.conf (comments, key bindings, other listeners stay as they are).

Usage:
    idleconf.py get
    idleconf.py set-many '{"dim": {"seconds": 300, "enabled": false}, ...}'

A disabled listener is commented out as a whole block, so it can be turned back
on without losing its timeout. The config path can be overridden with
HYPRIDLE_CONF, which is also used by the tests. Listeners are matched by their
on-timeout command, not by their position in the file.
"""

from __future__ import annotations

import json
import os
import re
import sys
import tempfile
from pathlib import Path

DEFAULT_CONF = Path.home() / ".config/hypr/hypridle.conf"
IDS = ("dim", "lock", "screenOff", "suspend")

# Order matters: a command is assigned to the first category that matches.
MATCHERS = (
    # The commented keyboard-backlight listener also calls brightnessctl, so
    # match the screen-backlight command specifically.
    ("dim", re.compile(r"brightnessctl\s+-s\s+set\s+\d", re.I)),
    ("lock", re.compile(r"lock-session|hyprlock", re.I)),
    ("screenOff", re.compile(r"dpms", re.I)),
    ("suspend", re.compile(r"systemctl\s+suspend|\bsuspend\b", re.I)),
)

LISTENER_START = re.compile(r"^(\s*)(#\s*)?listener\s*\{")
COMMENT_PREFIX = re.compile(r"^\s*#\s?")
TIMEOUT_LINE = re.compile(r"^(\s*timeout\s*=\s*)(\d+)(.*)$")
TIMEOUT_VALUE = re.compile(r"^timeout\s*=\s*(\d+)")
ON_TIMEOUT = re.compile(r"^on-timeout\s*=\s*(.*)$")
MINUTES_COMMENT = re.compile(r"(#\s*)(\d+)\s*min")


def config_path() -> Path:
    return Path(os.environ.get("HYPRIDLE_CONF", str(DEFAULT_CONF))).expanduser()


def parse(text: str) -> tuple[list[str], dict[str, dict]]:
    """Find every listener block, including ones commented out as a whole."""
    lines = text.splitlines()
    found: dict[str, dict] = {}
    i = 0
    while i < len(lines):
        start_match = LISTENER_START.match(lines[i])
        if not start_match:
            i += 1
            continue

        commented = start_match.group(2) is not None
        start = i
        depth = 1
        body: list[tuple[int, str]] = []
        end = len(lines) - 1
        i += 1
        while i < len(lines) and depth > 0:
            item = COMMENT_PREFIX.sub("", lines[i], count=1).strip() if commented else lines[i].strip()
            if item:
                if item.startswith("}"):
                    depth -= 1
                    if depth == 0:
                        end = i
                        break
                elif item.startswith("{"):
                    depth += 1
                else:
                    body.append((i, item))
            i += 1

        timeout_line = None
        seconds = None
        command = ""
        for index, item in body:
            match = TIMEOUT_VALUE.match(item)
            if match and timeout_line is None:
                timeout_line, seconds = index, int(match.group(1))
            match = ON_TIMEOUT.match(item)
            if match and not command:
                command = match.group(1)

        for category, pattern in MATCHERS:
            if pattern.search(command):
                if category not in found:
                    found[category] = {
                        "start": start,
                        "end": end,
                        "line": timeout_line,
                        "seconds": seconds,
                        "commented": commented,
                        "command": command,
                    }
                break
        i += 1

    return lines, found


def state(path: Path) -> dict:
    text = path.read_text(encoding="utf-8")
    _, found = parse(text)
    return {
        category: {
            "seconds": found.get(category, {}).get("seconds") or 0,
            "present": found.get(category, {}).get("line") is not None,
            "enabled": category in found and not found[category]["commented"],
        }
        for category in IDS
    }


def patched_line(line: str, seconds: int) -> str:
    match = TIMEOUT_LINE.match(line)
    if not match:
        raise ValueError(f"unexpected timeout line: {line!r}")
    # The stock config annotates timeouts in minutes ("# 8min."), the value
    # itself is in seconds. Keep those annotations true after a change.
    minutes = max(1, round(seconds / 60))
    tail = MINUTES_COMMENT.sub(lambda m: f"{m.group(1)}{minutes} min", match.group(3))
    return f"{match.group(1)}{seconds}{tail}"


def comment_line(line: str) -> str:
    stripped = line.lstrip()
    if not stripped:
        return line
    return line[:len(line) - len(stripped)] + "# " + stripped


def uncomment_line(line: str) -> str:
    return COMMENT_PREFIX.sub("", line, count=1)


def set_many(path: Path, values: dict) -> dict:
    if not isinstance(values, dict):
        raise ValueError("expected an object of timeout values")
    unknown = [key for key in values if key not in IDS]
    if unknown:
        raise ValueError(f"unknown timeout: {', '.join(unknown)}")

    # A value is either plain seconds (kept for scripted use) or
    # {"seconds": n, "enabled": bool}. The GUI always sends the latter.
    request = {}
    for key, value in values.items():
        if isinstance(value, dict):
            seconds = value.get("seconds")
            enabled = value.get("enabled", True)
        else:
            seconds, enabled = value, True
        if isinstance(seconds, bool) or not isinstance(seconds, int) or seconds < 1:
            raise ValueError(f"{key}: expected a positive number of seconds")
        if not isinstance(enabled, bool):
            raise ValueError(f"{key}: enabled must be true or false")
        request[key] = (seconds, enabled)

    text = path.read_text(encoding="utf-8")
    lines, found = parse(text)
    missing = [key for key in request if key not in found or found[key]["line"] is None]
    if missing:
        raise ValueError(f"no listener found for: {', '.join(missing)}")

    # Comment/uncomment whole blocks first; line numbers do not change.
    for key, (_, enabled) in request.items():
        block = found[key]
        transform = uncomment_line if enabled else comment_line
        if block["commented"] == enabled:
            for index in range(block["start"], block["end"] + 1):
                lines[index] = transform(lines[index])

    # A disabled block keeps its last timeout so re-enabling restores it.
    for key, (seconds, enabled) in request.items():
        if enabled:
            index = found[key]["line"]
            lines[index] = patched_line(lines[index], seconds)

    mode = path.stat().st_mode
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix=".hypridle-", text=True)
    try:
        with os.fdopen(fd, "w", encoding="utf-8") as handle:
            handle.write("\n".join(lines))
            if text.endswith("\n"):
                handle.write("\n")
            handle.flush()
            os.fsync(handle.fileno())
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    except BaseException:
        if os.path.exists(tmp):
            os.unlink(tmp)
        raise
    return state(path)


def main() -> int:
    if len(sys.argv) < 2:
        print(__doc__.strip(), file=sys.stderr)
        return 2

    try:
        path = config_path()
        command = sys.argv[1]
        if command == "get" and len(sys.argv) == 2:
            print(json.dumps(state(path)))
            return 0
        if command == "set-many" and len(sys.argv) == 3:
            print(json.dumps(set_many(path, json.loads(sys.argv[2]))))
            return 0
        print(__doc__.strip(), file=sys.stderr)
        return 2
    except (OSError, ValueError, json.JSONDecodeError) as error:
        print(f"idleconf: {error}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    raise SystemExit(main())
