#!/usr/bin/env python3
"""Register this git checkout in the GitNexus MCP registry.

GitNexus keys ``~/.gitnexus/registry.json`` by checkout path. A linked
worktree is a different path, so MCP ``list_repos`` / ``detect_changes``
report "repository not found" even when the primary checkout is indexed.

This script:

1. Resolves the current git toplevel (or every worktree with ``--all``).
2. If the checkout has no ``.gitnexus/``, junctions/symlinks the primary
   checkout's index into it. That is a register, not a re-analyze.
3. Runs ``npx gitnexus index`` so the worktree path appears in the registry.
4. Runs ``npx gitnexus analyze --index-only`` only when no sibling has an
   index.

    python scripts/ensure_gitnexus.py
    python scripts/ensure_gitnexus.py --all
"""

from __future__ import annotations

import argparse
import json
import os
import shutil
import subprocess
import sys
from pathlib import Path

SCRIPT_DIR = Path(__file__).resolve().parent
FALLBACK_PRIMARY = SCRIPT_DIR.parent
REGISTRY = Path.home() / ".gitnexus" / "registry.json"


def run_git(args: list[str], cwd: Path | None = None) -> str:
    proc = subprocess.run(
        ["git", *args],
        cwd=cwd,
        capture_output=True,
        text=True,
        check=False,
    )
    if proc.returncode != 0:
        raise SystemExit(
            proc.stderr.strip()
            or f"git {' '.join(args)} failed ({proc.returncode})"
        )
    return proc.stdout.strip()


def git_toplevel(cwd: Path | None = None) -> Path:
    return Path(run_git(["rev-parse", "--show-toplevel"], cwd=cwd))


def primary_checkout(cwd: Path | None = None) -> Path:
    common = Path(run_git(["rev-parse", "--git-common-dir"], cwd=cwd))
    if not common.is_absolute():
        base = cwd if cwd is not None else Path.cwd()
        common = (base / common).resolve()
    else:
        common = common.resolve()
    if common.name == ".git":
        return common.parent
    return FALLBACK_PRIMARY


def list_worktrees(cwd: Path | None = None) -> list[Path]:
    raw = run_git(["worktree", "list", "--porcelain"], cwd=cwd)
    out: list[Path] = []
    for line in raw.splitlines():
        if line.startswith("worktree "):
            out.append(Path(line[len("worktree ") :]))
    return out


def has_index(root: Path) -> bool:
    gn = root / ".gitnexus"
    if not gn.is_dir():
        return False
    return any(
        (gn / name).exists() for name in ("meta.json", "gitnexus.json", "lbug")
    )


def registry_paths() -> list[str]:
    if not REGISTRY.exists():
        return []
    try:
        data = json.loads(REGISTRY.read_text(encoding="utf-8"))
    except (OSError, json.JSONDecodeError):
        return []
    if not isinstance(data, list):
        return []
    return [
        str(entry.get("path", "")) for entry in data if isinstance(entry, dict)
    ]


def is_registered(root: Path) -> bool:
    target = os.path.normcase(str(root.resolve()))
    return any(
        os.path.normcase(path) == target for path in registry_paths() if path
    )


def link_index(src: Path, dest: Path) -> str:
    if dest.exists() or dest.is_symlink():
        return "exists"
    if sys.platform == "win32":
        proc = subprocess.run(
            ["cmd", "/c", "mklink", "/J", str(dest), str(src)],
            capture_output=True,
            text=True,
            check=False,
        )
        if proc.returncode != 0:
            raise SystemExit(
                (proc.stderr or proc.stdout).strip()
                or f"mklink /J failed for {dest}"
            )
        return "junction"
    dest.symlink_to(src, target_is_directory=True)
    return "symlink"


def npx_executable() -> str:
    # Windows: npx is npx.cmd; CreateProcess does not search PATHEXT for a bare name.
    names = ("npx.cmd", "npx") if sys.platform == "win32" else ("npx",)
    for name in names:
        found = shutil.which(name)
        if found:
            return found
    raise SystemExit("npx not found on PATH")


def run_npx(args: list[str], cwd: Path) -> None:
    proc = subprocess.run(
        [npx_executable(), "--yes", *args],
        cwd=cwd,
        check=False,
    )
    if proc.returncode != 0:
        raise SystemExit(
            f"npx {' '.join(args)} failed ({proc.returncode}) in {cwd}"
        )


def ensure_checkout(root: Path, primary: Path) -> str:
    root = root.resolve()
    primary = primary.resolve()
    if not has_index(root):
        if root != primary and has_index(primary):
            kind = link_index(primary / ".gitnexus", root / ".gitnexus")
            print(f"linked  {root}")
            print(f"  via {kind} -> {primary / '.gitnexus'}")
        else:
            print(f"analyze {root}  (no sibling index to share)")
            run_npx(
                ["gitnexus", "analyze", "--index-only", str(root)], cwd=root
            )
    if is_registered(root):
        print(f"ok      {root}")
        print("  already in registry")
        return str(root)
    print(f"index   {root}")
    run_npx(["gitnexus", "index", str(root)], cwd=root)
    print(f"repo    {root}")
    return str(root)


def parse_args(argv: list[str] | None = None) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--all",
        action="store_true",
        help="Register every linked worktree of this repository",
    )
    return parser.parse_args(argv)


def main(argv: list[str] | None = None) -> int:
    args = parse_args(argv)
    here = git_toplevel()
    primary = primary_checkout(here)
    targets = list_worktrees(here) if args.all else [here]
    for root in targets:
        if not root.exists():
            print(f"skip    {root}  (missing)")
            continue
        ensure_checkout(root, primary)
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
