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
gh auth setup-git

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

ensure_pr() {
  local repo="$1"
  local existing
  existing="$(gh pr list --repo "${repo}" --head "${BRANCH}" --json number --jq '.[0].number // empty')"
  if [[ -n "${existing}" ]]; then
    echo "${repo}: PR #${existing} already open"
    return 0
  fi
  if ! gh pr create --repo "${repo}" \
    --base main \
    --head "${BRANCH}" \
    --title "chore: sync agent docs from harness" \
    --body "$(cat <<EOF
Copies \`AGENTS.md\` and \`CLAUDE.md\` from [harness](https://github.com/RavindraTarunokusumo/harness) so agent workflow docs stay in sync.

This PR is opened automatically when those files change on \`harness\` \`main\`.
EOF
)"; then
    echo "failed to open PR in ${repo}" >&2
    return 1
  fi
}

for repo in "${REPOS[@]}"; do
  echo "::group::${repo}"
  dest="${work}/${repo##*/}"
  if ! gh repo clone "${repo}" "${dest}" -- --depth 1; then
    echo "failed to clone ${repo}" >&2
    failed=1
    echo "::endgroup::"
    continue
  fi

  if git -C "${dest}" fetch --depth 1 origin "${BRANCH}"; then
    if ! git -C "${dest}" checkout -B "${BRANCH}" FETCH_HEAD; then
      echo "failed to check out ${BRANCH} in ${repo}" >&2
      failed=1
      echo "::endgroup::"
      continue
    fi
  elif ! git -C "${dest}" checkout -B "${BRANCH}"; then
    echo "failed to create ${BRANCH} in ${repo}" >&2
    failed=1
    echo "::endgroup::"
    continue
  fi

  for file in "${FILES[@]}"; do
    cp "${ROOT}/${file}" "${dest}/${file}"
  done

  git -C "${dest}" add -- "${FILES[@]}"
  if git -C "${dest}" diff --cached --quiet; then
    echo "${repo} already matches harness"
  else
    git -C "${dest}" config user.name "github-actions[bot]"
    git -C "${dest}" config user.email "41898282+github-actions[bot]@users.noreply.github.com"
    git -C "${dest}" commit -m "${COMMIT_MSG}"
    if ! git -C "${dest}" push -u origin "${BRANCH}"; then
      echo "failed to push ${BRANCH} to ${repo}" >&2
      failed=1
      echo "::endgroup::"
      continue
    fi
  fi

  if ! ensure_pr "${repo}"; then
    failed=1
  fi
  echo "::endgroup::"
done

if [[ "${failed}" -ne 0 ]]; then
  exit 1
fi
