#!/usr/bin/env python3
"""Check exact identity of the master and both installed copies of optional methods.

Standard library only; read-only. Usage:
    python scripts/validate_optional_methods.py [repository-root]
"""
from __future__ import annotations

import hashlib
import sys
from pathlib import Path

METHODS = (
    "claim-check-log.md",
    "historical-bias-checklist.md",
    "source-comparison-matrix.md",
)
TARGETS = (
    "optional-methods",
    "skills/historian/references/optional-methods",
    "skills/historian-analyst/references/optional-methods",
)


def audit(root: Path) -> list[str]:
    problems: list[str] = []
    for name in METHODS:
        files = [root / sub / name for sub in TARGETS]
        missing = [p for p in files if not p.is_file()]
        for path in missing:
            problems.append(f"missing: {path.relative_to(root)}")
        if missing:
            continue
        digests = [hashlib.sha256(p.read_bytes()).hexdigest() for p in files]
        if len(set(digests)) != 1:
            for p, digest in zip(files, digests):
                problems.append(f"mismatch: {p.relative_to(root)} sha256={digest}")
    return problems


def main(argv: list[str]) -> int:
    root = Path(argv[1]).resolve() if len(argv) > 1 else Path(__file__).resolve().parents[1]
    if not root.is_dir():
        print(f"repository root missing: {root}")
        return 1
    problems = audit(root)
    for problem in problems:
        print(problem)
    if problems:
        print(f"Optional methods validation FAILED: {len(problems)} issue(s).")
        return 1
    print(f"Optional methods validation OK: {len(METHODS)} methods x {len(TARGETS)} locations.")
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
