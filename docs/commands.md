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

## Agent docs sync

Canonical `AGENTS.md` and `CLAUDE.md` live in this repo. Listed consumers are in `docs/agent-docs-targets.json` (`fractal-trading`, `kamarai`).

On push to `main` that touches those files (or via **Actions → Sync agent docs → Run workflow**), `.github/workflows/sync-agent-docs.yml` copies them into each listed repo and opens or updates a PR on `chore/sync-agent-docs-from-harness`.

Required secret on `RavindraTarunokusumo/harness`: `HARNESS_SYNC_TOKEN` — a fine-grained PAT with **Contents: write** and **Pull requests: write** on every listed consumer. The default `GITHUB_TOKEN` cannot open PRs in other repos.

To add a consumer, append `owner/repo` to `docs/agent-docs-targets.json`.
