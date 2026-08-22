#!/usr/bin/env bash
# Copy canonical AGENTS.md / CLAUDE.md from this repo into listed consumers
# and open (or update) a PR in each. Requires GH_TOKEN with contents + PR
# write access to every target repo.
set -euo pipefail

ROOT="$(cd "$(dirname "$0")/.." && pwd)"
TARGETS="${ROOT}/docs/agent-docs-targets.json"
BRANCH="chore/sync-agent-docs-from-harness"
COMMIT_MSG="chore: sync AGENTS.md and CLAUDE.md from harness"

if [[ ! -f "${TARGETS}" ]]; then
  echo "missing ${TARGETS}" >&2
  exit 1
fi

if [[ -z "${GH_TOKEN:-${GITHUB_TOKEN:-}}" ]]; then
  echo "GH_TOKEN (or GITHUB_TOKEN) is required to open PRs in other repos" >&2
  exit 1
fi

export GH_TOKEN="${GH_TOKEN:-${GITHUB_TOKEN}}"

mapfile -t FILES < <(jq -r '.files[]' "${TARGETS}")
mapfile -t REPOS < <(jq -r '.repos[]' "${TARGETS}")

if [[ ${#FILES[@]} -eq 0 || ${#REPOS[@]} -eq 0 ]]; then
  echo "docs/agent-docs-targets.json must list files and repos" >&2
  exit 1
fi

for file in "${FILES[@]}"; do
  if [[ ! -f "${ROOT}/${file}" ]]; then
    echo "missing source file: ${file}" >&2
    exit 1
  fi
done

work="$(mktemp -d)"
trap 'rm -rf "${work}"' EXIT

failed=0

for repo in "${REPOS[@]}"; do
  echo "::group::${repo}"
  dest="${work}/${repo##*/}"
  if ! gh repo clone "${repo}" "${dest}" -- --depth 1; then
    echo "failed to clone ${repo}" >&2
    failed=1
    echo "::endgroup::"
    continue
  fi

  git -C "${dest}" checkout -B "${BRANCH}"

  changed=()
  for file in "${FILES[@]}"; do
    cp "${ROOT}/${file}" "${dest}/${file}"
    changed+=("${file}")
  done

  git -C "${dest}" add -- "${changed[@]}"
  if git -C "${dest}" diff --cached --quiet; then
    echo "${repo} already matches harness"
    echo "::endgroup::"
    continue
  fi

  git -C "${dest}" config user.name "github-actions[bot]"
  git -C "${dest}" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
  git -C "${dest}" commit -m "${COMMIT_MSG}"
  git -C "${dest}" push -u origin "${BRANCH}" --force

  existing="$(gh pr list --repo "${repo}" --head "${BRANCH}" --json number --jq '.[0].number // empty')"
  if [[ -n "${existing}" ]]; then
    echo "${repo}: updated existing PR #${existing}"
  else
    gh pr create --repo "${repo}" \
      --title "chore: sync agent docs from harness" \
      --body "$(cat <<EOF
Copies \`AGENTS.md\` and \`CLAUDE.md\` from [harness](https://github.com/RavindraTarunokusumo/harness) so agent workflow docs stay in sync.

This PR is opened automatically when those files change on \`harness\` \`main\`.
EOF
)"
  fi
  echo "::endgroup::"
done

if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi
