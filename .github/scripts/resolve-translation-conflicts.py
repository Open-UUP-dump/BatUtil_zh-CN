#!/usr/bin/env python3
"""Resolve cherry-pick conflicts by keeping the upstream side.

The local branch contains translations and other local changes. When an
upstream commit conflicts with those local changes, the upstream version is
authoritative; local translation can be reapplied afterward. This prevents
mixing old local text with new upstream code.
"""

import re
import subprocess
import sys
from pathlib import Path

CONFLICT_RE = re.compile(
    r"<<<<<<< [^\r\n]*\r?\n(.*?)=======\r?\n(.*?)>>>>>>> [^\r\n]*\r?\n",
    re.DOTALL,
)


def main() -> int:
    result = subprocess.run(
        ["git", "diff", "--name-only", "--diff-filter=U"],
        check=True,
        capture_output=True,
        text=True,
    )
    files = [line for line in result.stdout.splitlines() if line.strip()]
    if not files:
        print("No unresolved files.")
        return 0

    for filename in files:
        path = Path(filename)
        # newline="" preserves the source file's CRLF/LF style.
        with path.open("r", encoding="utf-8", newline="") as handle:
            text = handle.read()

        def choose(match: re.Match) -> str:
            # Conflict markers are <<<<<<< ours, =======, >>>>>>> upstream.
            # Always keep the upstream side.
            return match.group(2)

        new_text = CONFLICT_RE.sub(choose, text)
        if "<<<<<<<" in new_text or ">>>>>>>" in new_text:
            print(f"Unresolved conflict remains in {filename}", file=sys.stderr)
            return 1
        with path.open("w", encoding="utf-8", newline="") as handle:
            handle.write(new_text)
        print(f"Resolved {filename} with upstream version")

    return 0


if __name__ == "__main__":
    raise SystemExit(main())
