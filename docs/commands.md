# Commands Reference

Document project commands for setup and any project-specific features.

## GitNexus

GitNexus registers each checkout path separately. A linked worktree is invisible to MCP until that path is in `~/.gitnexus/registry.json`.

```bash
# From the current checkout (primary or worktree)
python scripts/ensure_gitnexus.py

# Register every linked worktree of this repo
python scripts/ensure_gitnexus.py --all
```

If the worktree has no `.gitnexus/`, the script junctions/symlinks the primary checkout's index and runs `npx gitnexus index`. It only runs `npx gitnexus analyze --index-only` when no sibling index exists. Do not `gitnexus clean` from a worktree that shares the primary index.

After ensure, pass the absolute worktree path as `--repo` / MCP `repo`. The bare repository name is ambiguous when several checkouts are registered.
