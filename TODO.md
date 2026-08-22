# TODO.md

This file contains active or future work only.

Completed sessions must be moved to `docs/iterations/archive/`.

Rules:

- Every implementation task starts here.
- Each meaningful sub-item should become one commit.
- Mark completed sub-items with commit hash.
- Move completed sessions to archive after PR/merge.

## Backlog

## Session: GitNexus worktree registry — 2026-08-22

Ported from fractal-trading. Worktrees had no `~/.gitnexus/registry.json` entry, so MCP `detect_changes` / `list_repos` reported "repository not found" even when the primary checkout was indexed.

- [x] `scripts/ensure_gitnexus.py` — share the primary `.gitnexus/` (junction/symlink) and `gitnexus index` the current checkout
- [x] Preamble + docs: run ensure at session start; pass the absolute worktree path as `repo`

## Session: <Session Name> (<YYYY-MM-DD>)

- [ ] <sub-item 1>
- [ ] <sub-item 2>
- [ ] <sub-item 3>

## Future Backlog

- [ ] <future item>