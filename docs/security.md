# Security Review Threat Model

Used by the [Security Review](../AGENTS.md#security-review) workflow to classify a PR diff. Diff-scoped only. This file is the project-specific threat model: it lists which paths make a Grok `/security-review` **mandatory**, which surfaces to prioritize, and what that review does not replace.

Consumer repos should replace the placeholder paths below with their real attack surface. Do not scan the whole repository.

## Mandatory paths

A Grok `/security-review` of **the PR diff** is mandatory when the branch touches any of:

- HTTP / API request handlers and page routes
- Auth, sessions, rate limits, CORS, CSRF
- Secrets, credential loaders, logging of keys or tokens
- Persistence, raw SQL, migrations, tenant / mode isolation
- Deploy, CI secrets, SSH, or infrastructure wiring
- Frontend that interpolates API or user data (XSS / secrets in URLs)

## Priority surfaces

Same as the `/security-review` skill: auth, secret handling, injection, unsafe rendering, and any path that can move money, data, or credentials.

## What this does not replace

This review does not replace the project's automated tests, linters, or dependency auditors. Those stay as they are.
